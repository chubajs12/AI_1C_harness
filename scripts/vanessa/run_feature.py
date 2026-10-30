# -*- coding: utf-8 -*-
"""Прогон ОДНОЙ фичи через MCP Vanessa — базовая «микрокоманда» тестирования.

    python run_feature.py <файл.feature> [--timeout 240] [--no-connect] [--report <каталог>]

Порядок: (connect_test_client «Этот клиент», только к живому клиенту) -> run_scenario(filePath, reloadAndRun) ->
get_test_results (шаги со статусами) -> вердикт. Пока идет run_scenario, каждые 30 с печатается «идет N с» — при
запуске в фоне агент видит, что прогон жив, и дает статус в чат. Таймаут = FAIL.
Вердикт берется из результатов по шагам (лог побеждает «Success» MCP): PASS только если ни один шаг не Failed.
Отчет — <VANESSA_REPORTS>/runs/<имя фичи>.txt. Код возврата 0 — PASS.
reloadAndRun перечитывает фичу с диска: после правки .feature старый текст шагов не гоняется.
"""
from __future__ import annotations

import argparse
import re
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from va_mcp import CFG, call_tool, connect_main, init_session, masked  # noqa: E402

FAIL_RE = re.compile(r"были ошибки|Failed|не выполнен|ACTION_FAILED|Результат прохождения сценария: Failed", re.I)


def run(path: Path, connect: bool, timeout: float) -> tuple[str, str]:
    lines: list[str] = []
    if connect:
        ok, out = connect_main()
        lines.append(f"CONNECT {'OK' if ok else 'FAIL'}: {out[:600]}")
        if not ok:
            return "FAIL", "\n".join(lines)
    result: dict = {}

    def worker():
        try:
            result["out"] = call_tool(init_session(), "run_scenario",
                                      {"filePath": str(path), "mode": "reloadAndRun"}, timeout)
        except Exception as exc:  # noqa: BLE001
            result["err"] = f"MCP_TIMEOUT_OR_ERR={exc}"

    t0 = time.time()
    th = threading.Thread(target=worker, daemon=True)
    th.start()
    while th.is_alive():
        th.join(30)
        if th.is_alive():
            print(f"  ... {path.name}: идет {time.time() - t0:.0f} с", flush=True)
    out = result.get("out") or result.get("err", "")
    lines.append(f"ELAPSED_S={time.time() - t0:.1f}")
    lines.append("MCP_OUT_BEGIN\n" + masked(out)[:8000] + "\nMCP_OUT_END")
    if "err" in result or re.search(r'"code":\s*-32|ACTION_FAILED', out):
        # сценарий не запущен (нет файла, ошибка MCP): get_test_results вернул бы результаты ПРОШЛОГО сценария
        steps = "(сценарий не выполнялся — результаты шагов не запрашивались)"
    else:
        try:
            steps = call_tool(init_session(), "get_test_results", {}, 60)
        except Exception as exc:  # noqa: BLE001
            steps = f"get_test_results: {exc}"
    lines.append("TEST_RESULTS_BEGIN\n" + masked(steps) + "\nTEST_RESULTS_END")
    if "err" in result:
        verdict = "FAIL"
    elif "**Failed**" in steps or FAIL_RE.search(out):
        verdict = "FAIL"
    elif re.search(r"Success|успешно", out + steps, re.I):
        verdict = "PASS"
    else:
        verdict = "UNKNOWN"
    passed = len(re.findall(r"\*\*Success\*\*", steps))
    total = re.search(r"## Шаги \((\d+)\)", steps)
    lines.append(f"STEPS_OK={passed}/{total.group(1) if total else '?'}")
    return verdict, "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("feature")
    ap.add_argument("--timeout", type=float, default=240)
    ap.add_argument("--no-connect", action="store_true")
    ap.add_argument("--report", default="")
    a = ap.parse_args()
    path = Path(a.feature).resolve()
    verdict, text = run(path, not a.no_connect, a.timeout)
    report_dir = Path(a.report) if a.report else Path(CFG["VANESSA_REPORTS"]) / "runs"
    report_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / f"{path.stem}.txt").write_text(f"{text}\nVERDICT={verdict}\n", encoding="utf-8")
    for line in text.splitlines():
        if line.startswith(("CONNECT", "ELAPSED", "STEPS_OK")) or "**Failed**" in line or "Текст ошибки" in line:
            print("  " + line[:500], flush=True)
    print(f"VERDICT={verdict} {path.name}", flush=True)
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
