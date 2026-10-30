# -*- coding: utf-8 -*-
"""Прямой вызов инструмента любого MCP по HTTP (streamable), когда коннектор сессии агента не подключился, а сервер жив:

    python mcp_http.py <порт|url> <инструмент> '<json аргументов>'
    python mcp_http.py <порт|url> --list

Примеры:
    python mcp_http.py 8002 syntaxcheck '{"code":"Процедура А() КонецПроцедуры","file_name":"Module.bsl"}'
    python mcp_http.py 8061 search_function '{"query":"ПриЗаписи","repo":"ext"}'
    python mcp_http.py http://127.0.0.1:8006/mcp/ list_graph_projects '{}'     # граф — адрес со слэшем на конце
Адрес портом — на хосте MCP_HOST из config/project.env.local (по умолчанию 127.0.0.1).
"""
import json
import sys
import urllib.request
from pathlib import Path


def _host():
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from kitenv import mcp_host
    return mcp_host()


def post(url, payload, sid=None, timeout=300):
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    if sid:
        headers["Mcp-Session-Id"] = sid
    req = urllib.request.Request(url, json.dumps(payload, ensure_ascii=False).encode("utf-8"), headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8", "replace")
        sid = resp.headers.get("Mcp-Session-Id") or sid
    # SSE: событие — строки «data:» до пустой строки (JSON может быть разбит на несколько строк)
    events, buf = [], []
    for line in body.splitlines():
        if line.startswith("data:"):
            buf.append(line[5:].lstrip())
        elif not line.strip() and buf:
            events.append("\n".join(buf))
            buf = []
    if buf:
        events.append("\n".join(buf))
    if not events and body.strip():
        events = [body]
    return sid, [json.loads(e) for e in events if e.strip()]


def main():
    target = sys.argv[1]
    url = target if target.startswith("http") else f"http://{_host()}:{target}/mcp"
    sid, _ = post(url, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "kit-mcp-http", "version": "1"}}})
    post(url, {"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    if sys.argv[2] == "--list":
        _, msgs = post(url, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}, sid)
        for m in msgs:
            for t in m.get("result", {}).get("tools", []):
                print(t["name"])
        return 0
    args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
    _, msgs = post(url, {"jsonrpc": "2.0", "id": 2, "method": "tools/call",
                         "params": {"name": sys.argv[2], "arguments": args}}, sid)
    rc = 0
    for m in msgs:
        if "result" in m:
            for c in m["result"].get("content", []):
                print(c.get("text", ""))
        elif "error" in m:
            print("ERROR", json.dumps(m["error"], ensure_ascii=False))
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
