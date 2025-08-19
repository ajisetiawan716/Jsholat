#!/bin/sh

LOG_FILE="/var/log/jsholat-watchdog.log"
PROCESS_NAME="/usr/bin/jsholat-bot"
SERVICE_NAME="jsholat-bot"
MAX_SIZE=51200  # 50 KB

log() {
    MSG="$1"
    TIMESTAMP="$(date): $MSG"

    # Tampilkan ke terminal tanpa timestamp
    echo "$MSG"

    # Tulis ke file log dengan timestamp
    echo "$TIMESTAMP" >> "$LOG_FILE"

    # Kirim ke syslog dengan timestamp dari logger
    logger -t jsholat-watchdog "$MSG"
}

# Fungsi untuk membatasi ukuran log
check_log_size() {
    if [ -f "$LOG_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null)
        if [ "$FILE_SIZE" -ge "$MAX_SIZE" ]; then
            MSG="Log file exceeded 50 KB, resetting..."
            echo "$MSG"
            echo "$(date): $MSG" > "$LOG_FILE"
            logger -t jsholat-watchdog "$MSG"
        fi
    fi
}

# Tampilkan pesan bahwa script mulai berjalan
log "============================================"
log "Starting jsholat-watchdog script..."
log "Monitoring process: $PROCESS_NAME"
log "Log file: $LOG_FILE"
log "============================================"

# Jalankan pemeriksaan ukuran log
check_log_size

# Cek apakah proses jsholat-bot berjalan
pgrep -f "$PROCESS_NAME" > /dev/null
if [ $? -ne 0 ]; then
    log "[$SERVICE_NAME] not running, attempting restart..."

    # Restart service
    log "Executing: /etc/init.d/$SERVICE_NAME restart"
    /etc/init.d/$SERVICE_NAME start >> "$LOG_FILE" 2>&1

    # Tunggu sebentar dan periksa ulang
    sleep 2
    pgrep -f "$PROCESS_NAME" > /dev/null
    if [ $? -ne 0 ]; then
        log "[$SERVICE_NAME] restart failed!"
    else
        log "[$SERVICE_NAME] restarted successfully."
    fi
else
    log "[$SERVICE_NAME] is running normally."
fi

log "jsholat-watchdog script completed its check."