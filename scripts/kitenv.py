# -*- coding: utf-8 -*-
"""Параметры проекта для Python-скриптов комплекта: config/project.env.local (из project.env.example).

    from kitenv import env, kit_root, masked
    cfg = env()                      # dict ключ -> значение
    cfg = env(r"F:\\...\\other.env")  # другой файл параметров
"""
from __future__ import annotations

import json
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
    return merge_ports_from_registry(vals)


def _ports_registry_path(cfg: dict[str, str]) -> Path:
    if cfg.get("HARNESS_PORTS_REGISTRY"):
        return Path(cfg["HARNESS_PORTS_REGISTRY"])
    root = Path(cfg["HARNESS_ROOT"]) if cfg.get("HARNESS_ROOT") else KIT_ROOT
    yaml_path = root / "config" / "ports-registry.yaml"
    if yaml_path.is_file():
        return yaml_path
    return root / "config" / "ports-registry.json"


def _load_ports_registry(path: Path) -> dict | None:
    if not path.is_file():
        return None
    if path.suffix.lower() in (".yaml", ".yml"):
        import yaml

        return yaml.safe_load(path.read_text(encoding="utf-8-sig"))
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        return None


def merge_ports_from_registry(cfg: dict[str, str]) -> dict[str, str]:
    path = _ports_registry_path(cfg)
    reg = _load_ports_registry(path)
    if not reg:
        return cfg
    proj = cfg.get("PROJECT")
    projects = reg.get("projects") or {}
    if not proj or proj not in projects:
        return cfg
    p = projects[proj]
    mapping = {
        "VANESSA_MCP_PORT": "vanessa_mcp_port",
        "VANESSA_TC_PORT": "vanessa_tc_port",
        "CODE_INDEX_PORT": "code_index_port",
        "MCP1C_APP": "mcp1c_app",
        "GRAPH_PROJECT_CONF": "graph_project_conf",
        "GRAPH_PROJECT_EXT": "graph_project_ext",
    }
    for env_key, reg_key in mapping.items():
        if reg_key in p and p[reg_key] is not None:
            cfg[env_key] = str(p[reg_key])
    shared = reg.get("shared") or {}
    mcp1c = shared.get("mcp1c_iis") or {}
    if mcp1c.get("port") is not None:
        cfg["MCP1C_PORT"] = str(mcp1c["port"])
    if shared.get("mcp_host") and not cfg.get("MCP_HOST"):
        cfg["MCP_HOST"] = str(shared["mcp_host"])
    cfg["HARNESS_PORTS_REGISTRY"] = str(path)
    cfg["HARNESS_PORTS_REGISTRY_PROJECT"] = proj
    return cfg


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
