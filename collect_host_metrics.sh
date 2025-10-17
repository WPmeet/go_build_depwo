cat > /tmp/collect_host_metrics.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BROKER="$(hostname)"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="/tmp/host_metrics_${BROKER}_${TS}"
mkdir -p "$OUT_DIR"
log(){ echo "[$(date +%H:%M:%S)] $*"; }

# ---- sampling knobs ----
TOP_SECONDS=30
NET_SECONDS=30
IO_INTERVAL=2
IO_SAMPLES=10
VMSTAT_SECONDS=30

log "Collecting host metrics on ${BROKER}"
log "Output -> ${OUT_DIR}"

# CPU
log "CPU: top ${TOP_SECONDS}s"
if command -v top >/dev/null 2>&1; then
  top -b -d 1 -n "$TOP_SECONDS" > "${OUT_DIR}/cpu_top_${TS}.txt"
else
  echo "top not found" > "${OUT_DIR}/cpu_top_${TS}.txt"
fi

# Network
log "Network: ${NET_SECONDS}s (iftop or sar)"
if command -v iftop >/dev/null 2>&1; then
  (sudo -n iftop -t -s "$NET_SECONDS" || iftop -t -s "$NET_SECONDS") > "${OUT_DIR}/network_iftop_${TS}.txt" 2>&1 || true
elif command -v sar >/dev/null 2>&1; then
  sar -n DEV 1 "$NET_SECONDS" > "${OUT_DIR}/network_sar_${TS}.txt"
else
  echo "Neither iftop nor sar found" > "${OUT_DIR}/network_${TS}.txt"
fi

# Disk I/O
log "Disk I/O: iostat ${IO_INTERVAL}s x${IO_SAMPLES}, iotop sample"
if command -v iostat >/dev/null 2>&1; then
  iostat -xm "$IO_INTERVAL" "$IO_SAMPLES" > "${OUT_DIR}/io_iostat_${TS}.txt"
else
  echo "iostat not found (install sysstat)" > "${OUT_DIR}/io_iostat_${TS}.txt"
fi
if command -v iotop >/dev/null 2>&1; then
  (sudo -n iotop -b -d 1 -n "$IO_SAMPLES" | head -200 || iotop -b -d 1 -n "$IO_SAMPLES" | head -200) > "${OUT_DIR}/io_iotop_${TS}.txt" 2>&1 || true
else
  echo "iotop not found" > "${OUT_DIR}/io_iotop_${TS}.txt"
fi

# Memory + vmstat
log "Memory + vmstat ${VMSTAT_SECONDS}s"
{
  echo "------ free -h ------"
  command -v free >/dev/null 2>&1 && free -h || echo "free not found"
  echo
  echo "------ vmstat 1 ${VMSTAT_SECONDS} ------"
  command -v vmstat >/dev/null 2>&1 && vmstat 1 "$VMSTAT_SECONDS" || echo "vmstat not found"
} > "${OUT_DIR}/memory_vmstat_${TS}.txt"

# /proc snapshots
cat /proc/meminfo > "${OUT_DIR}/proc_meminfo_${TS}.txt" 2>/dev/null || true
cat /proc/diskstats > "${OUT_DIR}/proc_diskstats_${TS}.txt" 2>/dev/null || true

# Package
ARCHIVE="/tmp/${BROKER}_host_metrics_${TS}.tar.gz"
log "Packaging -> ${ARCHIVE}"
tar -czf "$ARCHIVE" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"

log "Done."
echo "Folder:  $OUT_DIR"
echo "Archive: $ARCHIVE"
EOF
