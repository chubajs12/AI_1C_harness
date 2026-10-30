# -*- coding: utf-8 -*-
"""Компиляция текстов запросов модулей BSL на живой базе через MCP 1С (execute_code): каждый строковый литерал, начинающийся с
ВЫБРАТЬ/SELECT, передается в Новый Запрос(Текст).НайтиПараметры() — платформа разбирает запрос, но не выполняет.

    python check-query-texts.py <файл.bsl> [<файл.bsl> ...] [--sub &Подстановка=ИСТИНА ...]

Зачем: ни 1c-syntax-checker-mcp, ни CheckModules тексты запросов не разбирают. В Energy так прошли в загрузку
псевдоним «КАК Есть» (зарезервированное слово — «Ожидается имя») и УПОРЯДОЧИТЬ ПО полю ПРЕДСТАВЛЕНИЕ(...).
--sub — фрагменты, которые модуль подставляет в текст через СтрЗаменить (не параметры запроса).
База — из параметров проекта (MCP 1С). Код возврата 1 — есть запросы с ошибкой.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mcp1c"))
from mcp1c import run_code  # noqa: E402


def query_literals(text: str, subs: dict[str, str]):
    """Строковые литералы BSL (с продолжением строк «|»), начинающиеся с ВЫБРАТЬ/SELECT."""
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        m = re.search(r'"((?:ВЫБРАТЬ|SELECT)\b.*)$', lines[i], re.I)
        if not m:
            i += 1
            continue
        start = i + 1
        parts = []
        rest = m.group(1)
        while True:
            end = re.search(r'(?<!")"(?!")', rest)  # конец литерала — кавычка, не удвоенная
            if end:
                parts.append(rest[:end.start()])
                break
            parts.append(rest)
            i += 1
            if i >= len(lines):
                break
            rest = re.sub(r"^\s*\|", "", lines[i].rstrip("\r"))
        q = "\n".join(parts).replace('""', '"')
        for k, v in subs.items():
            q = q.replace(k, v)
        yield start, q
        i += 1


def main() -> int:
    args = sys.argv[1:]
    subs: dict[str, str] = {}
    files = []
    it = iter(args)
    for a in it:
        if a == "--sub":
            k, v = next(it).split("=", 1)
            subs[k] = v
        else:
            files.append(a)
    queries = []
    for f in files:
        text = Path(f).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        for line, q in query_literals(text, subs):
            queries.append((f, line, q))
    if not queries:
        print("[queries] нет текстов запросов")
        return 0
    bsl = ["Тексты = Новый Массив;"]
    for _, _, q in queries:
        bsl.append('Тексты.Добавить("' + q.replace('"', '""').replace("\n", "\n|") + '");')
    bsl.append("""Ошибки = Новый Массив;
Для Номер = 0 По Тексты.ВГраница() Цикл
	Попытка
		Запрос = Новый Запрос(Тексты[Номер]);
		Запрос.НайтиПараметры();
	Исключение
		Ошибки.Добавить(Формат(Номер, "ЧН=0; ЧГ=") + "|" + КраткоеПредставлениеОшибки(ИнформацияОбОшибке()));
	КонецПопытки;
КонецЦикла;
Результат = Ошибки;""")
    errors = run_code("\n".join(bsl))
    for e in errors or []:
        n, msg = e.split("|", 1)
        f, line, _ = queries[int(n)]
        print(f"[queries] ОШИБКА {Path(f).name}:{line}: {msg}")
    print(f"[queries] проверено запросов: {len(queries)}, ошибок: {len(errors or [])}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
