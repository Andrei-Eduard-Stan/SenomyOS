#!/usr/bin/env python3
"""Compatibility entry point for the complete SenomyOS frame validator."""

from __future__ import annotations

from pathlib import Path
import runpy


runpy.run_path(
    str(Path(__file__).resolve().with_name("validate-frame-system.py")),
    run_name="__main__",
)
