# -*- coding: utf-8 -*-
"""Клиент MCP Vanessa Automation по HTTP (порт VANESSA_MCP_PORT, расширение client_mcp в TestManager).

    from va_mcp import init_session, call_tool, tc_alive, connect_main, masked
    s = init_session()
    print(masked(call_tool(s, "get_VanessaAutomation_state", {}, 60)))

Ответы MCP со списком профилей клиентов содержат строку запуска с паролем — печатать только через masked().
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kitenv import env, masked as _masked  # noqa: E402

CFG = env()
MCP_URL = f"http://127.0.0.1:{CFG['VANESSA_MCP_PORT']}/mcp"
MAIN_PROFILE = "Этот клиент"


def masked(text: str) -> str:
    return _masked(text, CFG)


def post(session: dict, obj: dict, timeout: float) -> list[dict]:
    session["id"] += 1
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": "2024-11-05",
    }
    if session.get("sid"):
        headers["Mcp-Session-Id"] = session["sid"]
    req = urllib.request.Request(MCP_URL, data=json.dumps(obj, ensure_ascii=False).encode("utf-8"),
                                 headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
        if sid:
            session["sid"] = sid
        raw = resp.read().decode("utf-8", "replace")
    msgs: list[dict] = []
    for line in raw.splitlines():
        if line.startswith("data: "):
            try:
                msgs.append(json.loads(line[6:]))
            except json.JSONDecodeError:
                pass
    if not msgs and raw.strip().startswith("{"):
        msgs.append(json.loads(raw))
    return msgs


def text_of(msgs: list[dict]) -> str:
    parts: list[str] = []
    for m in msgs:
        if "error" in m:
            parts.append(json.dumps(m["error"], ensure_ascii=False))
        res = m.get("result")
        if isinstance(res, dict):
            for c in res.get("content") or []:
                if isinstance(c, dict) and c.get("type") == "text":
                    parts.append(str(c.get("text", "")))
        elif res is not None:
            parts.append(str(res)[:4000])
    return "\n".join(parts)


def init_session(timeout: float = 30) -> dict:
    session = {"sid": None, "id": 0}
    post(session, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "kit-vanessa", "version": "1"}}},
        timeout)
    post(session, {"jsonrpc": "2.0", "method": "notifications/initialized"}, timeout)
    return session


def call_tool(session: dict, name: str, arguments: dict, timeout: float) -> str:
    return text_of(post(session, {"jsonrpc": "2.0", "id": session["id"] + 1, "method": "tools/call",
                                  "params": {"name": name, "arguments": arguments}}, timeout))


def tools_ready() -> bool:
    try:
        s = init_session(10)
        raw = json.dumps(post(s, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}, 15))
        return "run_scenario" in raw
    except Exception:  # noqa: BLE001
        return False


def tc_alive(wait_sec: int = 0) -> bool:
    """Клиент тестирования, поднятый start-tm-tc.ps1, жив: процесс 1cv8c своей базы с /TestClient и -TPort порта."""
    ib = f"{CFG['INFOBASE_SERVER']}/{CFG['INFOBASE_REF']}\"" if not CFG.get("INFOBASE_FILE") else CFG["INFOBASE_FILE"]
    ps = ("@(Get-CimInstance Win32_Process -Filter \"Name='1cv8c.exe'\" | Where-Object { $_.CommandLine -and "
          f"$_.CommandLine.Contains('{ib}') -and $_.CommandLine -match '/TestClient' -and "
          f"$_.CommandLine -match 'TPort\\s+{CFG['VANESSA_TC_PORT']}' }}).Count")
    deadline = time.time() + wait_sec
    while True:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout.strip()
        if out.isdigit() and int(out) > 0:
            return True
        if time.time() >= deadline:
            return False
        time.sleep(5)


def wait_tc_age(min_age_sec: int = 40) -> None:
    """Ждет, пока клиенту тестирования не исполнится min_age_sec секунд: после обновления базы клиент стартует дольше,
    подключение через 10-15 с после запуска не проходит, и Vanessa поднимает свой клиент из профиля без пароля."""
    ib = f"{CFG['INFOBASE_SERVER']}/{CFG['INFOBASE_REF']}\"" if not CFG.get("INFOBASE_FILE") else CFG["INFOBASE_FILE"]
    ps = ("$p = @(Get-CimInstance Win32_Process -Filter \"Name='1cv8c.exe'\" | Where-Object { $_.CommandLine -and "
          f"$_.CommandLine.Contains('{ib}') -and $_.CommandLine -match '/TestClient' -and "
          f"$_.CommandLine -match 'TPort\\s+{CFG['VANESSA_TC_PORT']}' }}); if ($p.Count -gt 0) {{ "
          "[int]((Get-Date) - ($p | Sort-Object CreationDate -Descending | Select-Object -First 1).CreationDate)"
          ".TotalSeconds }")
    out = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True).stdout.strip()
    if out.isdigit() and int(out) < min_age_sec:
        time.sleep(min_age_sec - int(out))


def connected(text: str) -> bool:
    return "не удалось" not in text and re.search(r"Статус:\s*подключен", text) is not None


def connect_main(timeout: float = 240) -> tuple[bool, str]:
    """Подключить TM к клиенту «Этот клиент». Только к живому клиенту: если его нет, Vanessa поднимет клиент сама из
    профиля — без пароля в профиле вход не пройдет, а несколько неудачных входов блокируют пользователя базы."""
    if not tc_alive(30):
        return False, "клиент тестирования не запущен — restart-vanessa.ps1"
    wait_tc_age(40)
    deadline = time.time() + 180
    while True:  # после рестарта MCP какое-то время отвечает «tool not found»
        try:
            out = call_tool(init_session(), "connect_test_client", {"profileName": MAIN_PROFILE}, timeout)
            if "tool not found" not in out:
                return connected(out), masked(out)
        except Exception as exc:  # noqa: BLE001
            out = str(exc)
        if time.time() > deadline:
            return False, masked(out)
        time.sleep(10)
