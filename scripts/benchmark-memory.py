#!/usr/bin/env python3
"""Bounded native memory-write workload used by the SenomyOS benchmark."""

from __future__ import annotations

import argparse
import ctypes
import json
import os
import tempfile
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mib", type=int, required=True)
    parser.add_argument("--seconds", type=int, required=True)
    parser.add_argument("--result", type=Path, required=True)
    args = parser.parse_args()

    if not 64 <= args.mib <= 2048:
        parser.error("--mib must be between 64 and 2048")
    if not 1 <= args.seconds <= 120:
        parser.error("--seconds must be between 1 and 120")

    byte_count = args.mib * 1024 * 1024
    buffer = bytearray(byte_count)
    address = ctypes.addressof(ctypes.c_char.from_buffer(buffer))
    libc = ctypes.CDLL(None)
    libc.memset.argtypes = (ctypes.c_void_p, ctypes.c_int, ctypes.c_size_t)
    libc.memset.restype = ctypes.c_void_p

    started = time.monotonic()
    deadline = started + args.seconds
    passes = 0
    while time.monotonic() < deadline:
        libc.memset(address, passes & 0xFF, byte_count)
        passes += 1
    elapsed = max(time.monotonic() - started, 0.001)
    touched_bytes = passes * byte_count
    result = {
        "allocated_mib": args.mib,
        "passes": passes,
        "elapsed_seconds": round(elapsed, 3),
        "write_mib_per_second": round((touched_bytes / 1048576) / elapsed, 1),
        "verification_byte": int(buffer[(passes * 4096) % byte_count]),
    }

    args.result.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(prefix=".memory-", suffix=".json", dir=args.result.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(result, handle, separators=(",", ":"))
            handle.write("\n")
        os.chmod(temporary, 0o600)
        os.replace(temporary, args.result)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
