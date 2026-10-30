# -*- coding: utf-8 -*-
"""Клиент MCP 1С — основной канал агента в живую базу: выполнить BSL или запрос, получить метаданные.

Сервер — HTTP-сервис расширения MCP_Сервер (github.com/vladimir-kharin/1c_mcp) на IIS:
http://127.0.0.1:<MCP1C_PORT>/<MCP1C_APP>/hs/mcp (publish-mcp.ps1), вход — Basic USER/PASS из config/project.env.local
(пароль не печатается). Клиентского процесса 1С нет: каждый вызов выполняется на сервере 1С в сеансе публикации.
Инструменты execute_code и execute_query дает расширение MCP_ВыполнениеКода (docs/03a).

    python mcp1c.py <файл.bsl>                    # execute_code, печатает значение переменной «Результат» (JSON)
    python mcp1c.py --code "Результат = 1;"        # то же для строки кода
    python mcp1c.py --query "ВЫБРАТЬ ПЕРВЫЕ 5 Т.Ссылка ИЗ Справочник.Валюты КАК Т"   # строки результата (JSON)
    python mcp1c.py --tool list_metadata_objects '{"metaType":"Catalogs","nameMask":"Валют"}'
    python mcp1c.py --list                         # инструменты сервера
    python mcp1c.py --status                       # UP <адрес> <сервер> (код 0) или ошибка (код 1)
    python mcp1c.py --headers                      # JSON заголовка Authorization (headersHelper в .mcp.json клиента)

    from mcp1c import run_code, run_file, run_query, call_tool
    data = run_file(Path("bsl/wipe.bsl"))

Код BSL выполняется оператором Выполнить() на сервере: результат — в переменной «Результат» (структуры, массивы,
примитивы, таблицы значений — в JSON). Ошибка 1С — RuntimeError с текстом и строкой кода. Повтор при сетевом отказе и
при 503 (пул публикации остановлен на время UpdateDB) — только для читающего кода: run_code(..., retries=3) по
умолчанию; для пишущего кода передавайте retries=1.
"""
from __future__ import annotations

import base64
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kitenv import env, mcp1c_url  # noqa: E402

_CFG: dict[str, str] | None = None


def cfg() -> dict[str, str]:
    global _CFG
    if _CFG is None:
        _CFG = env()
    return _CFG


def url() -> str:
    return mcp1c_url(cfg())


def auth_header() -> str:
    c = cfg()
    token = base64.b64encode(f"{c['USER']}:{c['PASS']}".encode("utf-8")).decode()
    return "Basic " + token


def rpc(method: str, params: dict | None = None, timeout: float = 600) -> dict:
    """Один запрос JSON-RPC. Сервер без состояния: initialize перед tools/call не нужен."""
    body = {"jsonrpc": "2.0", "id": 1, "method": method}
    if params is not None:
        body["params"] = params
    req = urllib.request.Request(
        url(), json.dumps(body, ensure_ascii=False).encode("utf-8"),
        {"Content-Type": "application/json; charset=utf-8", "Accept": "application/json",
         "Authorization": auth_header()}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            res = json.loads(resp.read().decode("utf-8-sig"))
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code} {url()}: {e.read().decode('utf-8', 'replace')[:2000]}") from None
    if "error" in res:
        raise RuntimeError(json.dumps(res["error"], ensure_ascii=False)[:1500])
    return res["result"]


def call_tool(name: str, arguments: dict, timeout: float = 600) -> str:
    """Текст ответа инструмента; ошибка инструмента (isError) — RuntimeError с текстом 1С."""
    res = rpc("tools/call", {"name": name, "arguments": arguments}, timeout)
    text = "\n".join(c.get("text", "") for c in res.get("content", []))
    if res.get("isError"):
        raise RuntimeError(text[:3000])
    return text


def list_tools() -> list[str]:
    return [t["name"] for t in rpc("tools/list", {}, 60)["tools"]]


def _retryable(exc: Exception) -> bool:
    return isinstance(exc, OSError) or str(exc).startswith("HTTP 503")


def run_code(code: str, timeout: float = 600, retries: int = 3):
    """execute_code: значение «Результат» или RuntimeError с текстом ошибки 1С."""
    for attempt in range(retries):
        try:
            data = json.loads(call_tool("execute_code", {"code": code}, timeout))
            if isinstance(data, dict) and not data.get("success", True):
                raise RuntimeError(str(data.get("error") or data)[:1500])
            return data.get("data", data) if isinstance(data, dict) else data
        except (OSError, RuntimeError) as exc:
            if not _retryable(exc) or attempt == retries - 1:
                raise
            time.sleep(10)


def run_file(path: Path, timeout: float = 600, retries: int = 3):
    return run_code(Path(path).read_text(encoding="utf-8-sig"), timeout, retries)


def run_query(query: str, params: dict | None = None, limit: int = 0, timeout: float = 600):
    """execute_query: список строк (словари). limit=0 — все строки."""
    args: dict = {"query": query, "limit": limit}
    if params:
        args["params"] = params
    raw = call_tool("execute_query", args, timeout)
    try:
        obj = json.loads(raw)
    except ValueError:
        return raw
    return obj.get("data", obj) if isinstance(obj, dict) else obj


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    if args[0] == "--headers":
        print(json.dumps({"Authorization": auth_header()}))
    elif args[0] == "--status":
        try:
            info = rpc("initialize", {"protocolVersion": "2025-03-26", "capabilities": {},
                                      "clientInfo": {"name": "kit-mcp1c", "version": "1"}}, 60)
            print("UP", url(), info.get("serverInfo"))
        except (OSError, RuntimeError) as exc:
            print("DOWN", url(), str(exc)[:300])
            return 1
    elif args[0] == "--list":
        print("\n".join(list_tools()))
    elif args[0] == "--code":
        print(json.dumps(run_code(args[1], retries=1), ensure_ascii=False, indent=1))
    elif args[0] == "--query":
        print(json.dumps(run_query(args[1]), ensure_ascii=False, indent=1))
    elif args[0] == "--tool":
        print(call_tool(args[1], json.loads(args[2]) if len(args) > 2 else {}))
    else:
        print(json.dumps(run_file(Path(args[0]), retries=1), ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
