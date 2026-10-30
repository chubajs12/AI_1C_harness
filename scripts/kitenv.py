# -*- coding: utf-8 -*-
"""Параметры проекта для Python-скриптов комплекта: config/project.env.local (из project.env.example).

    from kitenv import env, kit_root, masked
    cfg = env()                      # dict ключ -> значение
    cfg = env(r"F:\\...\\other.env")  # другой файл параметров
"""
from __future__ import annotations

import os
import re
from pathlib import Path

KIT_ROOT = Path(__file__).resolve().parents[1]


def kit_root() -> Path:
    return KIT_ROOT


def env(path: str | Path | None = None) -> dict[str, str]:
    # KIT_ENV_FILE — другой файл параметров (вторая база, проверки комплекта)
    p = Path(path or os.environ.get("KIT_ENV_FILE") or KIT_ROOT / "config" / "project.env.local")
    if not p.exists():
        raise SystemExit(f"Нет файла параметров {p}: скопируйте config/project.env.example в project.env.local и заполните")
    vals: dict[str, str] = {}
    for line in p.read_text(encoding="utf-8-sig").splitlines():
        if line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        vals[k.strip()] = v.strip()
    vals["ENV_FILE"] = str(p)
    return vals


def mcp1c_url(cfg: dict[str, str]) -> str:
    """Адрес MCP 1С базы: http://127.0.0.1:<MCP1C_PORT>/<MCP1C_APP>/hs/mcp (приложение по умолчанию — имя базы)."""
    if cfg.get("MCP1C_URL"):
        return cfg["MCP1C_URL"]
    app = cfg.get("MCP1C_APP") or cfg.get("INFOBASE_REF") or cfg.get("PROJECT")
    return f"http://127.0.0.1:{cfg.get('MCP1C_PORT') or 8095}/{app}/hs/mcp"


def mcp_host(cfg: dict[str, str] | None = None) -> str:
    """Хост общих MCP: MCP_HOST из параметров проекта, без файла параметров — 127.0.0.1 (одна машина)."""
    cfg = cfg if cfg is not None else _safe_env()
    return cfg.get("MCP_HOST") or "127.0.0.1"


def masked(text: str, cfg: dict[str, str] | None = None) -> str:
    """Убирает пароли из вывода (строки запуска 1С в ответах MCP содержат /P"...")."""
    text = re.sub(r'/P"[^"]*"', '/P"***"', text)
    cfg = cfg if cfg is not None else _safe_env()
    for key in ("PASS",):
        if cfg.get(key):
            text = text.replace(cfg[key], "***")
    return text


def _safe_env() -> dict[str, str]:
    try:
        return env()
    except SystemExit:
        return {}
