#!/usr/bin/env python3
"""Discover physical whole block devices without partitions or virtual stacks."""
import json
from pathlib import Path
result = []
for device in Path("/sys/class/block").glob("*"):
    try:
        if not (device / "partition").exists() and "/virtual/" not in str(device.resolve()):
            result.append(device.name)
    except OSError:
        continue
print(json.dumps(sorted(result)))
