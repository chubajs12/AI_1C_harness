# -*- coding: utf-8 -*-
"""VAParams.json для MCP-режима Vanessa из параметров проекта (VANESSA_VAPARAMS).

    python make_vaparams.py            # записать (UTF-8 с BOM, как ждет VA)
    python make_vaparams.py --print    # показать без пароля

Профиль клиента тестирования «Этот клиент» — тонкий клиент своей базы на VANESSA_TC_PORT. Пароль пользователя
базы попадает в файл (файл в git не попадает): с ним Vanessa может поднять клиент сама и не блокирует пользователя
неудачными входами. VAParams читается только при старте TestManager — после правки нужен restart-vanessa.ps1.
Ключи сверены с рабочими файлами Energy; лог ошибок — ИмяКаталогаЛогОшибок (опечатка КаталогВыгрузкиЛогОшибок
в Energy полтора дня вызывала модалку «Не указано имя файла лога» и вешала очередь фич).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kitenv import env, masked  # noqa: E402


def build(cfg: dict) -> dict:
    reports = Path(cfg["VANESSA_REPORTS"])
    if cfg.get("INFOBASE_FILE"):
        ib = f'File="{cfg["INFOBASE_FILE"]}";'
    else:
        ib = f'Srvr="{cfg["INFOBASE_SERVER"]}";Ref="{cfg["INFOBASE_REF"]}";'
    client = {
        "Имя": "Этот клиент",
        "Синоним": "Этот клиент",
        "ПутьКИнфобазе": ib,
        "ДопПараметры": f'/N"{cfg["USER"]}" /P"{cfg["PASS"]}"',
        "ТипКлиента": "Тонкий",
        "ИмяКомпьютера": "localhost",
        "ПортЗапускаТестКлиента": str(cfg["VANESSA_TC_PORT"]),
    }
    return {
        "КаталогФич": cfg["VANESSA_FEATURES"],
        "КаталогПроекта": cfg["VANESSA_ROOT"],
        "ИспользоватьКомпонентуVanessaExt": True,
        "ЗапускатьКлиентТестированияСМаксимизированнымОкном": True,
        "ВыполнятьШагиАссинхронно": False,
        "ОстановкаПриВозникновенииОшибки": False,
        "ПриВозникновенииОшибкиОстанавливатьВсеСеансыTestClient": False,
        "ВыгружатьСтатусВыполненияСценариевВФайл": True,
        "ПутьКФайлуДляВыгрузкиСтатусаВыполненияСценариев": str(reports / "BuildStatus.log"),
        "ДелатьОтчетВФорматеjUnit": True,
        "КаталогВыгрузкиjUnit": str(reports / "junit"),
        "ДелатьЛогВыполненияСценариевВТекстовыйФайл": True,
        "ИмяФайлаЛогВыполненияСценариев": str(reports / "vanessa-run.log"),
        "ДелатьЛогОшибокВТекстовыйФайл": True,
        "ИмяКаталогаЛогОшибок": str(reports / "errors"),
        # MCP-режим: TestManager живет между фичами, клиент не закрывается
        "ЗавершитьРаботуСистемы": False,
        "ЗакрытьTestClientПослеРаботы": False,
        "ТаймаутЗапуска1С": 120,
        # оба ключа: без ДанныеКлиентовТестирования менеджер берет сохраненную таблицу профилей пользователя базы,
        # общую для всех пар под этим пользователем (с портом клиента чужой пары)
        "КлиентыТестирования": [client],
        "ДанныеКлиентовТестирования": [client],
    }


def main() -> int:
    cfg = env()
    data = build(cfg)
    text = json.dumps(data, ensure_ascii=False, indent=2)
    if "--print" in sys.argv:
        print(masked(text, cfg))
        return 0
    out = Path(cfg["VANESSA_VAPARAMS"])
    out.parent.mkdir(parents=True, exist_ok=True)
    for d in ("junit", "errors", "runs"):
        (Path(cfg["VANESSA_REPORTS"]) / d).mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8-sig")
    print(f"записан {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
