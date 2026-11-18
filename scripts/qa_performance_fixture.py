"""Private fake transports for actual PerformanceService UI tests."""
from pathlib import Path
import shutil

def performance_environment(shell,work,environment):
    fixture=Path(work)/"performance-fixture"
    transport=fixture/"transport"
    (transport/"scripts").mkdir(parents=True,exist_ok=True)
    backend=Path(shell)/"tests/fixtures/performance-workspace-backend.py"
    for name in ["performance-status.sh","performance-processes.sh","performance-process-detail.sh","performance-action.sh","benchmark-status.sh","benchmark-action.sh"]:
        destination=transport/"scripts"/name
        shutil.copy2(backend,destination)
        destination.chmod(0o755)
    return dict(environment,SENOMY_SOURCE_ROOT=str(transport),SENOMY_PERF_FIXTURE=str(fixture))
