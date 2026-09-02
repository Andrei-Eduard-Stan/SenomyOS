#!/usr/bin/env bash

# Reload Eww through the SenomyOS state coordinator.

set -u

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec "$SCRIPT_DIR/surface-state.sh" reload
