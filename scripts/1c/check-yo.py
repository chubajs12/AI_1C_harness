# -*- coding: utf-8 -*-
"""Проверка буквы «ё/Ё» в сырцах 1С перед Load (AGENTS.md п. 1.6).

    python check-yo.py <каталог или файл...>     # код 1 — найдена ё вне комментариев BSL / в XML
    python check-yo.py --self-test               # встроенные кейсы

В модулях *.bsl «ё/Ё» допустима только в комментариях (// и /* */). В строковых литералах, идентификаторах и прочем
коде — запрещена. В *.xml (метаданные, синонимы, строки) — запрещена везде.
"""
from __future__ import annotations

import sys
from pathlib import Path

YO = "\u0451\u0401"


def strip_bsl_comments(text: str) -> str:
    """Убрать комментарии BSL; строковые литералы сохранить для проверки."""
    out: list[str] = []
    i = 0
    n = len(text)
    state = "code"
    while i < n:
        ch = text[i]
        if state == "code":
            if ch == "/" and i + 1 < n and text[i + 1] == "/":
                state = "line_comment"
                i += 2
                continue
            if ch == "/" and i + 1 < n and text[i + 1] == "*":
                state = "block_comment"
                i += 2
                continue
            if ch == '"':
                state = "string"
                out.append(ch)
                i += 1
                continue
            out.append(ch)
            i += 1
        elif state == "line_comment":
            if ch == "\n":
                state = "code"
                out.append("\n")
            i += 1
        elif state == "block_comment":
            if ch == "*" and i + 1 < n and text[i + 1] == "/":
                state = "code"
                i += 2
                continue
            if ch == "\n":
                out.append("\n")
            i += 1
        elif state == "string":
            out.append(ch)
            if ch == '"':
                if i + 1 < n and text[i + 1] == '"':
                    out.append('"')
                    i += 2
                    continue
                state = "code"
            i += 1
    return "".join(out)


def yo_hits(text: str) -> list[tuple[int, str]]:
    lines = text.split("\n")
    hits: list[tuple[int, str]] = []
    for no, line in enumerate(lines, 1):
        if any(c in YO for c in line):
            hits.append((no, line.strip()))
    return hits


def check_bsl(path: Path, raw: str) -> list[tuple[int, str]]:
    return yo_hits(strip_bsl_comments(raw))


def check_xml(raw: str) -> list[tuple[int, str]]:
    return yo_hits(raw)


def iter_targets(args: list[str]) -> list[Path]:
    paths: list[Path] = []
    for arg in args:
        p = Path(arg)
        if p.is_dir():
            paths.extend(sorted(p.rglob("*.bsl")))
            paths.extend(sorted(p.rglob("*.xml")))
        elif p.is_file():
            paths.append(p)
    return paths


def check_path(path: Path) -> list[tuple[int, str]]:
    raw = path.read_bytes().decode("utf-8-sig", errors="replace").replace("\r\n", "\n")
    suf = path.suffix.lower()
    if suf == ".bsl":
        return check_bsl(path, raw)
    if suf == ".xml":
        return check_xml(raw)
    return []


def self_test() -> int:
    ok = True

    def assert_pass(label: str, hits: list[tuple[int, str]]) -> None:
        nonlocal ok
        if hits:
            ok = False
            print(f"FAIL {label}: {hits}", file=sys.stderr)

    sample = Path(__file__).with_name("_check_yo_sample.bsl")
    sample.write_text("// комментарий: устанавливаем её\nX = 1;\n", encoding="utf-8")
    assert_pass("comment-only", check_path(sample))
    sample.write_text('X = "ё";\n', encoding="utf-8")
    if not check_path(sample):
        ok = False
        print("FAIL string-literal: expected hit", file=sys.stderr)
    sample.write_text("/* блок: её */ X = 1;\n", encoding="utf-8")
    assert_pass("block-comment", check_path(sample))
    sample.unlink(missing_ok=True)

    inline = 'A = 1; // её в хвосте\nB = "ok";\n'
    assert_pass("trailing-line-comment", check_bsl(Path("x.bsl"), inline))

    code_yo = "Процедура Тест()\n\t// норм\n\tСообщить(\"е\");\nКонецПроцедуры\n"
    assert_pass("code-clean", check_bsl(Path("x.bsl"), code_yo))

    if ok:
        print("check-yo self-test: OK")
        return 0
    return 1


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        return self_test()
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    failed = False
    for path in iter_targets(sys.argv[1:]):
        hits = check_path(path)
        if hits:
            failed = True
            print(f"{path}:", file=sys.stderr)
            for no, line in hits[:20]:
                print(f"  {no}: {line}", file=sys.stderr)
            if len(hits) > 20:
                print(f"  ... ещё {len(hits) - 20}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
