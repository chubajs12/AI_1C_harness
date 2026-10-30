# -*- coding: utf-8 -*-
"""Запуск refresh_graph_project без проблем с кавычками PowerShell.

    python scripts/mcp/refresh_graph_project.py <project_id> [operation_id] [mode]

Пример:
    python scripts/mcp/refresh_graph_project.py EnergyConf
    python scripts/mcp/refresh_graph_project.py RostviplastExt
"""
from __future__ import annotations

import json
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "mcp"))

from mcp_http import post, _host  # noqa: E402


def call_refresh(project_id: str, operation_id: str, mode: str, url: str) -> int:
    sid, _ = post(
        url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "refresh_graph_project.py", "version": "1"},
            },
        },
    )
    post(url, {"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    args = {"project_id": project_id, "operation_id": operation_id, "mode": mode}
    _, msgs = post(
        url,
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": "refresh_graph_project", "arguments": args},
        },
        sid,
        timeout=600,
    )
    rc = 0
    for m in msgs:
        if "result" in m:
            for c in m["result"].get("content", []):
                print(c.get("text", ""))
        elif "error" in m:
            print("ERROR", json.dumps(m["error"], ensure_ascii=False))
            rc = 1
    return rc


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    project_id = sys.argv[1]
    operation_id = sys.argv[2] if len(sys.argv) > 2 else str(uuid.uuid4())
    mode = sys.argv[3] if len(sys.argv) > 3 else "incremental"
    target = sys.argv[4] if len(sys.argv) > 4 else "http://127.0.0.1:8006/mcp/"
    url = target if target.startswith("http") else f"http://{_host()}:{target}/mcp"
    print(f"refresh_graph_project project_id={project_id} operation_id={operation_id} mode={mode}")
    return call_refresh(project_id, operation_id, mode, url)


if __name__ == "__main__":
    sys.exit(main())
