"""Проверка BSL-файла через 1c-syntax-checker-mcp (HTTP :8002, streamable HTTP MCP).

Использование: python syntaxcheck_file.py <файл.bsl> [имя_модуля.bsl]
Печатает отчет анализатора (TOON). Код возврата 0 - вызов прошел (ошибки смотреть в отчете).
Хост — MCP_HOST из config/project.env.local (по умолчанию 127.0.0.1).
"""
import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kitenv import mcp_host  # noqa: E402

HOST = mcp_host()
URL = f"http://{HOST}:8002/mcp"


def post(payload, session=None):
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    if session:
        headers["Mcp-Session-Id"] = session
    req = urllib.request.Request(URL, data=json.dumps(payload).encode("utf-8"), headers=headers)
    with urllib.request.urlopen(req, timeout=300) as resp:
        sid = resp.headers.get("Mcp-Session-Id") or session
        body = resp.read().decode("utf-8")
    data = None
    for line in body.splitlines():
        if line.startswith("data:"):
            data = json.loads(line[5:].strip())
    if data is None and body.strip():
        data = json.loads(body)
    return sid, data


def main():
    path = sys.argv[1]
    name = sys.argv[2] if len(sys.argv) > 2 else "Module.bsl"
    code = open(path, encoding="utf-8-sig").read()
    sid, _ = post({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2025-03-26", "capabilities": {},
        "clientInfo": {"name": "kit-syntaxcheck", "version": "1"}}})
    post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    _, data = post({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {
        "name": "syntaxcheck", "arguments": {"code": code, "file_name": name}}}, sid)
    for item in (data or {}).get("result", {}).get("content", []):
        if item.get("type") == "text":
            print(item["text"])
    if data and "error" in data:
        print(json.dumps(data["error"], ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
