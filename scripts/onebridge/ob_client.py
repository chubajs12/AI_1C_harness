# -*- coding: utf-8 -*-
"""Клиент OneBridge по HTTP (MCP streamable HTTP): выполнить BSL или запрос в живой базе проекта.

ЗАПАСНОЙ вариант (docs/09). Основной канал — MCP 1С, scripts/mcp1c/mcp1c.py; при DB_CHANNEL=onebridge mcp1c.py сам
передает вызовы сюда, поэтому скрипты комплекта импортируют mcp1c, а не этот модуль.

    python ob_client.py <файл.bsl>                 # execute_code, печатает значение переменной «Результат» (JSON)
    python ob_client.py --code "Результат = 1;"     # то же для строки кода
    python ob_client.py --query "ВЫБРАТЬ ПЕРВЫЕ 5 Ссылка ИЗ Справочник.Валюты"
    python ob_client.py --tool get_metadata '{"meta_type":"Catalog","name_mask":"Валют*"}'
    python ob_client.py --list                       # инструменты OneBridge
    (--port N — другой порт; по умолчанию ONEBRIDGE_PORT из config/project.env.local)

    from ob_client import run_code, run_file, run_query
    data = run_file(port, Path("bsl/wipe.bsl"))

Код BSL выполняется на сервере через Выполнить(): результат — в переменной «Результат» (структуры, массивы,
примитивы сериализуются в JSON). Повтор при сетевом отказе (WinError 10054/10055 при нехватке памяти хоста) — только
для читающего кода: run_code(..., retries=3) по умолчанию; для пишущего кода передавайте retries=1.
"""
from __future__ import annotations

import json
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kitenv import env  # noqa: E402


def default_port() -> int:
    return int(env()["ONEBRIDGE_PORT"])


def _mcp(url: str, payload: dict, sid: str | None = None, timeout: float = 600):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": "2024-11-05",
    }
    if sid:
        headers["Mcp-Session-Id"] = sid
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.headers.get("Mcp-Session-Id") or sid, resp.read().decode("utf-8", "replace")


def _parse(raw: str) -> dict:
    # ответ — SSE (строки data:, JSON может быть разбит на несколько строк) или голый JSON
    parts = [line[5:].lstrip() for line in raw.splitlines() if line.startswith("data:")]
    return json.loads("\n".join(parts) if parts else raw)


def _session(port: int) -> tuple[str, str | None]:
    url = f"http://127.0.0.1:{port}/mcp"
    sid, _ = _mcp(url, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "kit-ob-client", "version": "1"}}})
    _mcp(url, {"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    return url, sid


def call_tool(port: int, name: str, arguments: dict, timeout: float = 600) -> str:
    url, sid = _session(port)
    _, raw = _mcp(url, {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                        "params": {"name": name, "arguments": arguments}}, sid, timeout)
    res = _parse(raw)
    if "error" in res:
        raise RuntimeError(json.dumps(res["error"], ensure_ascii=False)[:1500])
    return "".join(c.get("text", "") for c in res["result"].get("content", []))


def list_tools(port: int) -> list[str]:
    url, sid = _session(port)
    _, raw = _mcp(url, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}, sid, 60)
    return [t["name"] for t in _parse(raw)["result"]["tools"]]


def run_code(port: int, code: str, timeout: float = 600, retries: int = 3):
    """execute_code: возвращает значение «Результат» или бросает RuntimeError с текстом ошибки 1С."""
    for attempt in range(retries):
        try:
            data = json.loads(call_tool(port, "execute_code", {"code": code}, timeout))
            if not data.get("success", True):
                raise RuntimeError(str(data.get("error") or data)[:1500])
            return data.get("data", data)
        except OSError:
            if attempt == retries - 1:
                raise
            time.sleep(10)


def run_file(port: int, path: Path, timeout: float = 600, retries: int = 3):
    return run_code(port, Path(path).read_text(encoding="utf-8-sig"), timeout, retries)


def run_query(port: int, query: str, params: dict | None = None, timeout: float = 600):
    args = {"query": query}
    if params:
        args["params"] = params
    return call_tool(port, "execute_query", args, timeout)


def main() -> int:
    args = sys.argv[1:]
    port = None
    if "--port" in args:
        i = args.index("--port")
        port = int(args[i + 1])
        del args[i:i + 2]
    port = port or default_port()
    if not args:
        print(__doc__)
        return 2
    if args[0] == "--list":
        print("\n".join(list_tools(port)))
    elif args[0] == "--code":
        print(json.dumps(run_code(port, args[1], retries=1), ensure_ascii=False, indent=1))
    elif args[0] == "--query":
        print(run_query(port, args[1]))
    elif args[0] == "--tool":
        print(call_tool(port, args[1], json.loads(args[2]) if len(args) > 2 else {}))
    else:
        print(json.dumps(run_file(port, Path(args[0]), retries=1), ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
