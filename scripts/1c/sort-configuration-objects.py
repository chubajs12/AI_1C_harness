# -*- coding: utf-8 -*-
"""Сортировка объектов в составе конфигурации/расширения по имени по возрастанию (как «Сортировка метаданных» в
Конфигураторе: по имени, по возрастанию) - правило пользователя: наши объекты во всех проектах сортируются.

    python sort-configuration-objects.py <каталог выгрузки> [--check]

В <ChildObjects> Configuration.xml объекты каждого вида упорядочиваются по имени без учета регистра; порядок видов не
меняется. Подсистемы не сортируются: их порядок задает порядок разделов в интерфейсе (пользователь их не сортирует).
Кодировка (BOM) и переводы строк сохраняются. --check - только сообщить, без записи (код 1, если есть несортированные).
Вызывается из designer.ps1 перед каждой загрузкой расширения из XML.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

KEEP_ORDER = {"Subsystem"}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cfg = Path(sys.argv[1]) / "Configuration.xml"
    check = "--check" in sys.argv[2:]
    raw = cfg.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    nl = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(nl)
    start = next(i for i, l in enumerate(lines) if l.strip() == "<ChildObjects>")
    end = next(i for i in range(start, len(lines)) if lines[i].strip() == "</ChildObjects>")
    item = re.compile(r"^\s*<(\w+)>([^<]+)</\1>\s*$")
    block = lines[start + 1:end]
    assert all(item.match(l) for l in block), "в составе есть строки не вида <Вид>Имя</Вид>"
    kinds = [item.match(l).group(1) for l in block]
    out, i, changed = [], 0, []
    while i < len(block):
        j = i
        while j < len(block) and kinds[j] == kinds[i]:
            j += 1
        group = block[i:j]
        if kinds[i] not in KEEP_ORDER:
            ordered = sorted(group, key=lambda l: item.match(l).group(2).lower())
            if ordered != group:
                changed.append(f"{kinds[i]} ({len(group)})")
            group = ordered
        out += group
        i = j
    assert len(set(kinds)) == len([k for n, k in enumerate(kinds) if n == 0 or kinds[n - 1] != k]), \
        "объекты одного вида в составе не подряд"
    if not changed:
        print("[sort] состав уже отсортирован по имени")
        return 0
    if check:
        print("[sort] не по алфавиту: " + ", ".join(changed))
        return 1
    lines[start + 1:end] = out
    cfg.write_bytes((b"\xef\xbb\xbf" if bom else b"") + nl.join(lines).encode("utf-8"))
    print("[sort] отсортировано по имени: " + ", ".join(changed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
