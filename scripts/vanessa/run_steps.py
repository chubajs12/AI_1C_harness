# -*- coding: utf-8 -*-
"""Микрокомандный прогон: список шагов (JSON) выполняется по одному, после каждого — вердикт и короткий итог.

    python run_steps.py <шаги.json>                  # весь проход (вайп и подготовка — первые шаги файла)
    python run_steps.py <шаги.json> --from A-30      # с шага (данные предыдущих шагов должны быть)
    python run_steps.py <шаги.json> --only A-40      # один шаг
    python run_steps.py <шаги.json> --until P-06     # до шага включительно (стенд для показа)
    python run_steps.py <шаги.json> --dry-run        # показать план
    python run_steps.py <шаги.json> --shots <каталог>  # цветные скриншоты по маркерам «# СКРИН: id | подпись»
    python run_steps.py <шаги.json> --continue-on-fail

Формат шагов (пример — steps.example.json), пути — относительно файла шагов:
    {"id": "P-01", "kind": "ob",      "target": "bsl/wipe.bsl"}         MCP 1С execute_code; PASS, если Результат —
                                                                          структура с ok = Истина
    {"id": "C-01", "kind": "check",   "target": "bsl/check.bsl", "stage": "after_post"}   то же, в тексте BSL
                                                                          "&ЭТАП" (или &ЭТАП) -> "after_post"
    {"id": "R-00", "kind": "restart"}                                     свежая пара TM+TC (restart-vanessa.ps1)
    {"id": "R-01", "kind": "connect"}                                     подключить «Этот клиент» (только к живому)
    {"id": "F-01", "kind": "feature", "target": "features/01.feature", "timeout": 300, "connect": false}
    {"id": "X-01", "kind": "python",  "target": "my_check.py", "args": ["--x"]}   код возврата 0 = PASS

Правила (AGENTS.md п. 6): вайп перед полным прогоном; документы — только через UI (фичи); данные — проверками
MCP 1С; первый FAIL останавливает прогон (если не --continue-on-fail) — чинить по одному; после правки самой фичи
прогонять только ее (--only), после правки кода продукта — весь проход. Итог — таблица PASS/FAIL по шагам, отчеты
фич — в VANESSA_REPORTS/runs.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "mcp1c"))
from mcp1c import run_code  # noqa: E402
from run_feature import run as run_feature_once  # noqa: E402
from va_mcp import CFG, call_tool, connect_main, init_session  # noqa: E402

SHOT = re.compile(r"^\s*#\s*СКРИН:\s*(\S+?)\s*\|\s*(.+?)\s*$")
PY = sys.executable


def ob_step(path: Path, stage: str | None) -> bool:
    code = path.read_text(encoding="utf-8-sig")
    if stage is not None:
        code = code.replace('"&ЭТАП"', f'"{stage}"').replace("&ЭТАП", f'"{stage}"')
    try:
        data = run_code(code, timeout=600, retries=1)
    except RuntimeError as exc:
        print(f"    ошибка 1С: {str(exc)[:800]}", flush=True)
        return False
    print("    " + json.dumps(data, ensure_ascii=False)[:1500], flush=True)
    return isinstance(data, dict) and data.get("ok") is True


def feature_step(path: Path, connect: bool, timeout: float, shots: Path | None) -> bool:
    if shots and any(SHOT.match(line) for line in path.read_text(encoding="utf-8-sig").splitlines()):
        return feature_with_shots(path, connect, timeout, shots)
    verdict, text = run_feature_once(path, connect, timeout)
    report = Path(CFG["VANESSA_REPORTS"]) / "runs"
    report.mkdir(parents=True, exist_ok=True)
    (report / f"{path.stem}.txt").write_text(f"{text}\nVERDICT={verdict}\n", encoding="utf-8")
    for line in text.splitlines():
        if line.startswith(("STEPS_OK", "ELAPSED")) or "**Failed**" in line or "Текст ошибки" in line:
            print("    " + line[:500], flush=True)
    return verdict == "PASS"


def split_parts(path: Path) -> list[tuple[str | None, tuple[str, str] | None]]:
    """Делит фичу по маркерам «# СКРИН: id | подпись»: (текст части, снимок после нее). Первая часть — с полным
    «Контекстом», следующие — только с активизацией клиента: экран продолжается с места предыдущей части."""
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    first = next(i for i, line in enumerate(lines) if line.strip().startswith("Сценарий:"))
    header = lines[:first]
    ctx = next((i for i, line in enumerate(header) if line.strip().startswith("Контекст:")), None)
    short = (header[:ctx + 1] + [line for line in header if "активизирую TestClient" in line] + [""]
             if ctx is not None else header)
    parts: list[tuple[str | None, tuple[str, str] | None]] = []
    st = {"name": "", "buf": [], "n": 0, "ctx_done": False}

    def flush(shot):
        steps = [line for line in st["buf"] if line.strip() and not line.strip().startswith("#")]
        text = None
        if steps:
            st["n"] += 1
            head = short if st["ctx_done"] else header
            text = "\n".join(head + [f"  Сценарий: {st['name']} (часть {st['n']})"] + st["buf"]) + "\n"
            st["ctx_done"] = True
        if text or shot:
            parts.append((text, shot))
        st["buf"] = []

    for line in lines[first:]:
        if line.strip().startswith("Сценарий:"):
            flush(None)
            st["name"] = line.strip().split(":", 1)[1].strip()
            continue
        m = SHOT.match(line)
        if m:
            flush((m.group(1), m.group(2)))
            continue
        st["buf"].append(line)
    flush(None)
    return parts


def take_shot(shot: tuple[str, str], shots: Path, manifest: list) -> bool:
    """Цветной снимок основного окна клиента; диалоги 1С (отдельные окна ОС) накладываются по центру, как на экране."""
    shot_id, caption = shot
    session = init_session()
    listing = call_tool(session, "get_window_list_os", {}, 60)
    titles = [m.group(1).strip() for m in re.finditer(r"(?m)^\s*-(.+)$", listing)]
    main = [t for t in titles if t.startswith("1С:")] or titles[:1]
    dialogs = list(reversed([t for t in titles if t not in main]))  # от активного: накладывать в обратном порядке
    file_name = shots / f"{shot_id}.png"
    file_name.unlink(missing_ok=True)
    if main:
        call_tool(session, "get_window_screenshot_os",
                  {"window_title": main[0], "color_mode": "color", "file_name": str(file_name)}, 90)
    ok = file_name.exists()
    if ok and dialogs:
        try:
            from PIL import Image  # noqa: PLC0415
            image = Image.open(file_name).convert("RGB")
            for title in dialogs:
                part = shots / f"{shot_id}_dlg.png"
                call_tool(session, "get_window_screenshot_os",
                          {"window_title": title, "color_mode": "color", "file_name": str(part)}, 90)
                if part.exists():
                    dlg = Image.open(part).convert("RGB")
                    image.paste(dlg, (max(0, (image.width - dlg.width) // 2), max(0, (image.height - dlg.height) // 2)))
                    part.unlink()
            image.save(file_name)
        except ImportError:
            print("    (нет Pillow — диалоги не наложены: pip install pillow)", flush=True)
    manifest.append({"id": shot_id, "caption": caption, "window": main[0] if main else "", "dialogs": dialogs,
                     "file": str(file_name), "ok": ok})
    (shots / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"    скрин {shot_id}: {'OK' if ok else 'нет файла'}", flush=True)
    return ok


MANIFEST: list = []


def feature_with_shots(path: Path, connect: bool, timeout: float, shots: Path) -> bool:
    parts_dir = Path(CFG["VANESSA_REPORTS"]) / "parts"
    parts_dir.mkdir(parents=True, exist_ok=True)
    for n, (text, shot) in enumerate(split_parts(path), 1):
        if text:
            part = parts_dir / f"{path.stem}_p{n:02d}.feature"
            part.write_text(text, encoding="utf-8")
            verdict, out = run_feature_once(part, connect and n == 1, timeout)
            if verdict != "PASS":
                print("    " + "\n    ".join(line for line in out.splitlines() if "**Failed**" in line)[:1500], flush=True)
                return False
        if shot and not take_shot(shot, shots, MANIFEST):
            return False
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("steps")
    ap.add_argument("--from", dest="start", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--until", default="")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--continue-on-fail", action="store_true")
    ap.add_argument("--shots", default="")
    a = ap.parse_args()
    steps_file = Path(a.steps).resolve()
    base = steps_file.parent
    steps = json.loads(steps_file.read_text(encoding="utf-8-sig"))
    ids = [s["id"] for s in steps]
    if a.only:
        steps = [s for s in steps if s["id"] == a.only]
    elif a.start:
        steps = steps[ids.index(a.start):]
    if a.until:
        steps = steps[:[s["id"] for s in steps].index(a.until) + 1]
    shots = Path(a.shots) if a.shots else None
    if shots:
        shots.mkdir(parents=True, exist_ok=True)
    if a.dry_run:
        for s in steps:
            print(f"{s['id']:8} {s['kind']:8} {s.get('target', '')}")
        return 0

    results: list[tuple[str, str, float]] = []
    for s in steps:
        kind, target = s["kind"], s.get("target", "")
        print(f"\n===== {s['id']} {kind} {Path(target).name if target else ''} =====", flush=True)
        t0 = time.time()
        if kind in ("ob", "check"):
            ok = ob_step(base / target, s.get("stage"))
        elif kind == "restart":
            ok = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                                 str(HERE / "restart-vanessa.ps1")]).returncode == 0
        elif kind == "connect":
            ok, out = connect_main()
            print("    " + out[:400], flush=True)
        elif kind == "feature":
            ok = feature_step(base / target, s.get("connect", False), float(s.get("timeout", 300)), shots)
        elif kind == "python":
            ok = subprocess.run([PY, str(base / target), *s.get("args", [])]).returncode == 0
        else:
            print(f"    неизвестный вид шага {kind}", flush=True)
            ok = False
        dt = time.time() - t0
        results.append((s["id"], "PASS" if ok else "FAIL", dt))
        print(f"VERDICT {s['id']} = {'PASS' if ok else 'FAIL'} ({dt:.0f} с)", flush=True)
        if not ok and not a.continue_on_fail:
            break

    print("\n===== ИТОГ =====", flush=True)
    print("| Шаг | Итог | Время, с |\n|-----|------|----------|")
    for sid, verdict, dt in results:
        print(f"| {sid} | {'✓' if verdict == 'PASS' else '✗'} {verdict} | {dt:.0f} |")
    passed = sum(1 for _, v, _ in results if v == "PASS")
    print(f"PASS {passed}/{len(results)} (запланировано {len(steps)})", flush=True)
    return 0 if passed == len(steps) else 1


if __name__ == "__main__":
    raise SystemExit(main())
