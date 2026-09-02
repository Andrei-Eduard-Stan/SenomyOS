---
title: Performance and Benchmarks
category: System
category_order: 40
order: 10
summary: Live telemetry, five-minute retained history, guarded processes, and bounded Quick or Standard benchmark profiles.
---

# Performance and benchmarks

The Performance Dashboard opens from the Rail CPU, MEM, and UP group. It owns
Overview, CPU and GPU, Memory, Storage, Network, Processes, and Benchmarks.
Detailed power policy stays in Control Centre Power.

## Evidence model

- Synchronized live telemetry refreshes from bounded procfs and system tools.
- Five-minute rate history persists across dashboard close and Eww restart.
- Expensive inventory and process collectors run only while needed.
- Process actions and diagnostic tasks remain allowlisted and confirmed.

## Benchmark profiles

| Profile | Approximate time | Storage scratch | Intended use |
| --- | --- | --- | --- |
| Quick | 70 seconds | 256 MiB | First comparison and basic stability evidence |
| Standard | 210 seconds | 512 MiB | Sustained local evidence and richer report |

Both profiles cap workers and memory, avoid network and root, and stop on
unsafe low memory, low battery, or observed high temperature. Reports are
private Markdown and PDF artifacts with SHA-256 checksums and sanitized system
specification evidence.

```bash
scripts/benchmark-action.sh plan quick | jq .
scripts/benchmark-action.sh plan standard | jq .
```

Run workloads only from the confirmed Benchmark interface and keep the stop
control available. Continue to [[recovery|Shell recovery]] if the dashboard
cannot close.
