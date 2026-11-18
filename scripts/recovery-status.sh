#!/usr/bin/env bash

# Report whether the last-known-good SenomyOS shell archive is internally
# intact. This helper never extracts or overwrites live configuration.
set -u
export LC_ALL=C

readonly STATE_ROOT="${SENOMY_RECOVERY_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/recovery}"
readonly ARCHIVE="$STATE_ROOT/senomyos-shell.tar.gz"
readonly CHECKSUM="$STATE_ROOT/senomyos-shell.sha256"
readonly VALIDATED_AT="$STATE_ROOT/validated-at"
printf -v observed_at '%(%s)T' -1

available=false
checksum_valid=false
archive_valid=false
validated_at=0
size_bytes=0
entry_count=0

if [[ -r "$ARCHIVE" && -r "$CHECKSUM" ]]; then
  available=true
  (cd "$STATE_ROOT" && sha256sum -c "$(basename "$CHECKSUM")" >/dev/null 2>&1) && checksum_valid=true
  tar -tzf "$ARCHIVE" >/dev/null 2>&1 && archive_valid=true
  size_bytes="$(stat -c %s "$ARCHIVE" 2>/dev/null || printf 0)"
  entry_count="$(tar -tzf "$ARCHIVE" 2>/dev/null | wc -l)"
fi
if [[ -r "$VALIDATED_AT" ]]; then
  candidate="$(<"$VALIDATED_AT")"
  [[ "$candidate" =~ ^[0-9]+$ ]] && validated_at="$candidate"
fi

jq -nc --argjson at "$observed_at" --arg root "$STATE_ROOT" \
  --argjson available "$available" --argjson checksum_valid "$checksum_valid" \
  --argjson archive_valid "$archive_valid" --argjson validated_at "$validated_at" \
  --argjson size_bytes "$size_bytes" --argjson entry_count "$entry_count" '
  {schema_version:1,ok:true,source:"senomy-recovery",observed_at:$at,
    data:{available:$available,checksum_valid:$checksum_valid,archive_valid:$archive_valid,
      validated_at:$validated_at,size_bytes:$size_bytes,entry_count:$entry_count,root:$root,
      automatic_restore:false},error:null}'
