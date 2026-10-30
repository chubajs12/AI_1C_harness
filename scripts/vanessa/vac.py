# -*- coding: utf-8 -*-
"""Одна микрокоманда Vanessa: вызов любого инструмента MCP Vanessa, вывод без паролей.

    python vac.py <инструмент> '<json аргументов>' [таймаут]
    python vac.py --list

Примеры:
    python vac.py get_VanessaAutomation_state '{}'
    python vac.py manage_test_client_profiles '{"action":"get_list"}'
    python vac.py connect_test_client '{"profileName":"Этот клиент"}'
    python vac.py get_window_list_testclient '{}'
    python vac.py get_form_analysis '{"format":"elements"}'      # дерево элементов активной формы (имена для шагов)
    python vac.py get_form_analysis '{"format":"gherkin"}'       # состояние формы готовыми шагами Gherkin
    python vac.py search_for_steps_by_keywords '{"search_name":"перехожу к строке","limit":10}'
    python vac.py manage_form_elements '{"action":"click_button","element_name":"ФормаЗаписать"}'
    python vac.py run_scenario '{"filePath":"F:\\\\...\\\\01.feature","mode":"reloadAndRun"}' 300
    python vac.py get_test_results '{}'
    python vac.py get_window_screenshot_os '{"window_title":"<заголовок>","color_mode":"color","file_name":"F:\\\\shot.png"}'
Все инструменты и параметры — docs/04a_Vanessa_MCP_инструменты.md.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from va_mcp import call_tool, init_session, masked, post  # noqa: E402


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    s = init_session()
    if sys.argv[1] == "--list":
        for m in post(s, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}, 60):
            for t in m.get("result", {}).get("tools", []):
                print(f"{t['name']}: {(t.get('description') or '').splitlines()[0][:150] if t.get('description') else ''}")
        return 0
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    timeout = float(sys.argv[3]) if len(sys.argv) > 3 else 120
    print(masked(call_tool(s, sys.argv[1], args, timeout)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
