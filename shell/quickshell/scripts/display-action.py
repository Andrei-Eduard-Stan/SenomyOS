#!/usr/bin/env python3
"""Stable CLI entry point for Senomy's display and workspace manager."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from display_core import main

if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
