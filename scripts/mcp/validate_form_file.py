"""Проверка Form.xml через 1c-forms-mcp (HTTP :8011, validate_form) - большие формы без вставки в чат.

Использование: python validate_form_file.py <Form.xml>
Печатает {valid, errors, warnings}. Код возврата 0 - форма валидна.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import syntaxcheck_file as mcp  # noqa: E402

mcp.URL = f"http://{mcp.HOST}:8011/mcp"


def main():
    xml = open(sys.argv[1], encoding="utf-8-sig").read()
    sid, _ = mcp.post({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2025-03-26", "capabilities": {},
        "clientInfo": {"name": "kit-validate-form", "version": "1"}}})
    mcp.post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    _, data = mcp.post({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {
        "name": "validate_form", "arguments": {"xml_content": xml}}}, sid)
    text = "".join(i.get("text", "") for i in (data or {}).get("result", {}).get("content", []))
    print(text)
    try:
        return 0 if json.loads(text).get("valid") else 1
    except Exception:  # noqa: BLE001
        return 1


if __name__ == "__main__":
    sys.exit(main())
