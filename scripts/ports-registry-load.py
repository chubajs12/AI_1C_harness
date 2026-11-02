# -*- coding: utf-8 -*-
"""Load config/ports-registry.yaml (canonical) or .json to stdout as JSON."""
from __future__ import annotations

import json
import sys
from pathlib import Path

KIT_ROOT = Path(__file__).resolve().parents[1]


def load(path: Path | None = None) -> dict:
    if path is None:
        yaml_path = KIT_ROOT / "config" / "ports-registry.yaml"
        json_path = KIT_ROOT / "config" / "ports-registry.json"
        path = yaml_path if yaml_path.is_file() else json_path
    if not path.is_file():
        raise SystemExit(f"ports registry not found: {path}")
    if path.suffix.lower() in (".yaml", ".yml"):
        import yaml

        return yaml.safe_load(path.read_text(encoding="utf-8-sig"))
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> int:
    p = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    data = load(p)
    json.dump(data, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
