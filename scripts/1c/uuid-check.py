# -*- coding: utf-8 -*-
"""Проверка UUID в XML-выгрузке конфигурации/расширения перед загрузкой (AGENTS.md п. 1.4).

    python uuid-check.py <каталог выгрузки>          # проверка, код 1 — есть ошибки
    python uuid-check.py <каталог выгрузки> --fix    # заменить фиктивные UUID на uuid4 (одинаково во всех файлах)

Ошибки:
- фиктивные/псевдо-последовательные UUID (a1b2c3d4-…, 00000000-…, 12345678-…, одна цифра подряд) — так пишут модели,
  когда «придумывают» объект; платформа их примет, но при следующем клонировании они совпадут;
- один и тот же uuid="…" у двух разных элементов выгрузки (скопированный объект/форма/реквизит с образца).
Дубли --fix не исправляет: какой из двух объектов «настоящий», решает человек (обычно меняется копия).
"""
from __future__ import annotations

import re
import sys
import uuid
from collections import defaultdict
from pathlib import Path

UUID_RE = re.compile(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
UUID_ATTR = re.compile(r'\buuid="([0-9a-fA-F-]{36})"')
FAKE_PREFIXES = ("a1b2c3d4", "b2c3d4e5", "c3d4e5f6", "d4e5f6a7", "e5f6a7b8", "f6a7b8c9", "12345678", "abcdef01",
                 "aaaaaaaa", "deadbeef")


def is_fake(u: str) -> bool:
    ul = u.lower()
    if ul == "00000000-0000-0000-0000-000000000000":
        return False  # пустая ссылка — законное значение
    if ul.startswith(FAKE_PREFIXES):
        return True
    hexes = ul.replace("-", "")
    if len(set(hexes)) <= 2:  # 11111111-1111-…, 0000…0001
        return True
    return bool(re.fullmatch(r"0{20,}[0-9a-f]{1,12}", hexes))


def scan(root: Path):
    fakes: dict[str, set[str]] = defaultdict(set)
    owners: dict[str, list[str]] = defaultdict(list)
    for p in root.rglob("*.xml"):
        if ".code-index" in p.parts:
            continue
        text = p.read_text(encoding="utf-8-sig", errors="replace")
        rel = str(p.relative_to(root))
        for m in UUID_RE.finditer(text):
            if is_fake(m.group(0)):
                fakes[m.group(0).lower()].add(rel)
        if p.name == "ConfigDumpInfo.xml":
            continue
        for m in UUID_ATTR.finditer(text):
            owners[m.group(1).lower()].append(rel)
    dups = {u: files for u, files in owners.items() if len(files) > 1}
    return fakes, dups


def fix(root: Path, fakes: dict[str, set[str]]) -> int:
    mapping = {u: str(uuid.uuid4()) for u in fakes}
    changed = 0
    for p in root.rglob("*.xml"):
        raw = p.read_bytes()
        bom = raw.startswith(b"\xef\xbb\xbf")
        text = raw.decode("utf-8-sig")
        new = UUID_RE.sub(lambda m: mapping.get(m.group(0).lower(), m.group(0)), text)
        if new != text:
            p.write_bytes((b"\xef\xbb\xbf" if bom else b"") + new.encode("utf-8"))
            changed += 1
            print(f"исправлен {p.relative_to(root)}")
    return changed


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    root = Path(sys.argv[1])
    fakes, dups = scan(root)
    if "--fix" in sys.argv[2:] and fakes:
        print(f"фиктивных UUID: {len(fakes)}, файлов изменено: {fix(root, fakes)}")
        fakes, dups = scan(root)
    for u, files in sorted(fakes.items()):
        print(f"FAIL фиктивный UUID {u}: {', '.join(sorted(files)[:5])}")
    for u, files in sorted(dups.items()):
        print(f"FAIL один uuid у нескольких элементов {u}: {', '.join(files[:5])}")
    if fakes or dups:
        return 1
    print(f"OK UUID: фиктивных нет, повторов нет ({root})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
