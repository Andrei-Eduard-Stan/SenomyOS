---
title: Performance and Benchmarks
category: System
category_order: 40
order: 10
summary: Shared bounded session telemetry, guarded diagnostics and benchmarks.
---

# Performance and benchmarks

Open Performance from the Rail CPU/MEM/UP telemetry. Its current routes include
Overview, CPU, GPU, Memory, Storage, Network, Processes, Services, Diagnostics,
Console, Reports and Benchmarks. Detailed energy policy remains in Settings Power.

CPU/memory/network history uses the shared session sampler and retains up to
15 minutes in memory while panels are closed. Available views select a history
window. A shell restart begins a new collection epoch. Missing sensors, gaps and
warm-up are unavailable values, never fabricated zeroes.

Expensive inventory/process collection runs only when needed. Process/service
actions, diagnostics and workloads use existing allowlists, exact targets and
confirmation. A diagnostic field is not an unrestricted shell. Reports retain
source, units and freshness and remain local/private.

Quick and Standard benchmark plans can be inspected without starting a workload:

```bash
scripts/benchmark-action.sh plan quick | jq .
scripts/benchmark-action.sh plan standard | jq .
```

Run a workload only through its reviewed Benchmark flow; keep Stop available.
A score or short resource snapshot does not certify hardware reliability.
Continue to [[recovery|Shell recovery]] if the surface cannot close.
