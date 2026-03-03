#!/bin/bash
# Jadwal Updater Jsholat
# (C) 2025-2026 Jsholat - @ajisetiawan716

# ===== KONFIGURASI =====
LOG_FILE="/var/log/jsholat/jadwal-update.log"
LOG_TAG="jadwal-update"
MAX_LOG_SIZE=1048576  # 1MB
MAX_RETRIES=3
RETRY_DELAY=300  # 5 menit
JADWAL_FILE=$(uci get jsholat.schedule.file_jadwal)
LAST_UPDATED_FILE="/usr/share/jsholat/last_updated.txt"
EXPIRY_THRESHOLD=$((36 * 3600))  # 36 jam
DEBUG_MODE=$(uci -q get jsholat.service.debug_mode || echo "0")

# ===== FUNGSI UTILITAS =====

init() {
    [ -d "/var/log/jsholat" ] || mkdir -p "/var/log/jsholat"
    touch "$LOG_FILE"
}

rotate_log() {
    [ $(stat -c%s "$LOG_FILE") -gt "$MAX_LOG_SIZE" ] && {
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
    }
}

# Fungsi untuk output ke stdout (real-time) dan log
output() {
    local line="$1"
    echo "$line"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $line" >> "$LOG_FILE"
}

# Fungsi untuk log saja (tanpa stdout)
log() {
    rotate_log
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [Shell] $1" >> "$LOG_FILE"
    logger -t "$LOG_TAG" "$1"
}

# ===== FUNGSI VALIDASI =====

check_jadwal_file() {
    [ ! -f "$JADWAL_FILE" ] && {
        output "ERROR: File jadwal tidak ditemukan: $JADWAL_FILE"
        return 1
    }

    [ ! -s "$JADWAL_FILE" ] && {
        output "ERROR: File jadwal kosong: $JADWAL_FILE"
        return 1
    }

    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: File jadwal valid"
    return 0
}

has_config_changed() {
    [ ! -f "$LAST_UPDATED_FILE" ] && return 0
    
    local current_source=$(uci get jsholat.schedule.source)
    local current_city_raw=$(uci get jsholat.schedule.city_value)
    
    local current_city=$(echo "$current_city_raw" | \
        awk '{print tolower($0)}' | \
        sed -e 's/\.//g' -e 's/+/ /g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//')
    
    local last_source_json=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
    local last_source=""
    local last_city_raw=""
    local last_city=""
    
    case "$last_source_json" in
        "Jadwalsholat.org"|"JadwalSholat.org"|"jadwalsholat.org"|"jadwalsholat") 
            last_source="jadwalsholat"
            ;;
        "Bimas Islam Kemenag/Api.MyQuran.com"|"MyQuran"|"myquran"|"Api.MyQuran.com") 
            last_source="myquran"
            ;;
        "Aladhan.com"|"Aladhan"|"aladhan"|"aladhan.com") 
            last_source="aladhan"
            ;;
        "API AjiMedia"|"AjiMedia"|"apiajimedia"|"api ajimedia") 
            last_source="apiajimedia"
            ;;
        "Arina.Id"|"arina.id"|"arina"|"arina.Id") 
            last_source="arina"
            ;;
        "Equran.Id"|"Equran.id"|"equran.Id"|"equran.id"|"equranid"|"equran")
            last_source="equranid"
            ;;
        *)  
            last_source="$current_source"
            ;;
    esac
    
    last_city_raw=$(jq -r '.location.city_value // .location.city // ""' "$LAST_UPDATED_FILE" 2>/dev/null)
    
    last_city=$(echo "$last_city_raw" | \
        awk '{print tolower($0)}' | \
        sed -e 's/\.//g' -e 's/+/ /g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//')
    
    if [ "$current_source" != "$last_source" ]; then
        return 0
    fi
    
    if [ "$current_city" != "$last_city" ]; then
        return 0
    fi
    
    return 1
}

is_jadwal_expired() {
    [ ! -f "$LAST_UPDATED_FILE" ] && {
        output "File last_updated.txt tidak ditemukan"
        return 0
    }

    if ! jq -e . "$LAST_UPDATED_FILE" >/dev/null 2>&1; then
        output "File last_updated.txt bukan JSON valid"
        return 0
    fi

    local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE" 2>/dev/null)
    [ -z "$last_updated" ] && {
        output "Field last_updated tidak ditemukan"
        return 0
    }

    local reformatted_date=$(echo "$last_updated" | \
        awk -F'[- :]' '{printf "%s-%s-%s %s:%s:%s", $3, $2, $1, $4, $5, $6}')

    if ! last_epoch=$(date -d "$reformatted_date" +%s 2>/dev/null); then
        output "Gagal parsing tanggal: $last_updated"
        return 0
    fi

    local now_epoch=$(date +%s)
    local age=$((now_epoch - last_epoch))
    local interval=$(uci get jsholat.schedule.interval 2>/dev/null || echo "3600")

    # Handle monthly_special interval
    if [ "$interval" = "monthly_special" ]; then

        # >>> MODIFIED: Gunakan month & year dari JSON (lebih presisi & aman lintas tahun)
        local last_month=$(jq -r '.month' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_year=$(jq -r '.year' "$LAST_UPDATED_FILE" 2>/dev/null)

        local current_month=$(date +%m | sed 's/^0//')
        local current_year=$(date +%Y)

        [ "$DEBUG_MODE" = "1" ] && \
            log "DEBUG: Interval monthly_special - Last: $last_month/$last_year, Current: $current_month/$current_year"

        if [ "$last_month" != "$current_month" ] || [ "$last_year" != "$current_year" ]; then
            output "Jadwal kedaluwarsa (Pembaruan bulanan diperlukan)"
            return 0
        fi

        return 1
    fi
    
    local expiry_threshold=${EXPIRY_THRESHOLD:-$interval}
    [ "$age" -gt "$expiry_threshold" ] && {
        output "Jadwal kedaluwarsa. Usia: $(($age/3600)) jam"
        return 0
    }

    return 1
}

# ===== FUNGSI UPDATE UTAMA =====

run_update() {
    local source_override="$1"
    local source="${source_override:-$(uci get jsholat.schedule.source || echo "aladhan")}"

    output "Memulai update dari sumber: $source"

    if jadwal run; then

        if ! check_jadwal_file; then
            output "ERROR: File jadwal tidak valid setelah update"
            return 1
        fi

        # >>> NEW: Validasi bulan isi jadwal.json (Anti race GitHub/Arina)
        local first_date=$(jq -r '.[0].gregorian_date // empty' "$JADWAL_FILE" 2>/dev/null)

        if [ -n "$first_date" ]; then
            local file_month=$(echo "$first_date" | cut -d'-' -f2 | sed 's/^0//')
            local file_year=$(echo "$first_date" | cut -d'-' -f3)

            local current_month=$(date +%m | sed 's/^0//')
            local current_year=$(date +%Y)

            if [ "$file_month" != "$current_month" ] || [ "$file_year" != "$current_year" ]; then
                output "ERROR: Data jadwal belum sesuai bulan berjalan ($file_month/$file_year)"
                return 1
            fi
        fi

        output "Update data jadwal berhasil"
        return 0
    fi

    output "ERROR: Gagal eksekusi script"
    return 1
}

run_update_with_retry() {

    if check_jadwal_file && ! is_jadwal_expired && ! has_config_changed; then
        local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE")
        local last_source=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_city=$(jq -r '.location.city' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_province=$(jq -r '.location.province' "$LAST_UPDATED_FILE" 2>/dev/null)
        
        output "Jadwal masih valid (Terakhir diupdate: $last_updated), Sumber: $last_source, Kota: $last_city, Provinsi: $last_province"
        log "Jadwal masih valid (Terakhir diupdate: $last_updated)"
        log "Konfigurasi sumber/kota tidak berubah"
        return 2
    fi

    local attempt=1
    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        output "Percobaan update ke-$attempt"
        log "Percobaan update ke-$attempt"
        
        if run_update; then
            output "Update berhasil pada percobaan ke-$attempt"
            log "Update berhasil pada percobaan ke-$attempt"
            return 0
        fi
        
        [ $attempt -lt $MAX_RETRIES ] && {
            output "Menunggu $RETRY_DELAY detik sebelum mencoba lagi..."
            log "Menunggu $RETRY_DELAY detik sebelum mencoba lagi..."
            sleep "$RETRY_DELAY"
        }
        attempt=$((attempt+1))
    done

    output "GAGAL: Update tidak berhasil setelah $MAX_RETRIES percobaan"
    log "GAGAL: Update tidak berhasil setelah $MAX_RETRIES percobaan"
    return 1
}

restart_service() {
    output "Memulai restart service jsholat..."
    log "Memulai restart service jsholat..."
    
    if /etc/init.d/jsholat restart >/dev/null 2>&1; then
        output "Service berhasil di-restart"
        log "Service berhasil di-restart"
        return 0
    else
        output "ERROR: Gagal restart service"
        log "ERROR: Gagal restart service"
        return 1
    fi
}

# ===== MAIN EXECUTION =====
init
log "Memulai update jadwal"

run_update_with_retry
exit_code=$?

case $exit_code in
    0)
        output "Proses update berhasil"
        log "Proses update berhasil"
        restart_service
        ;;
    1)
        if check_jadwal_file; then
            last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE" 2>/dev/null || echo "unknown")
            output "Menggunakan jadwal terakhir: $last_updated"
            output "WARNING: Menggunakan jadwal terakhir karena gagal update - $last_updated"
            log "Menggunakan jadwal terakhir: $last_updated"
        else
            output "ERROR: Tidak ada jadwal yang valid tersedia"
            log "ERROR: Tidak ada jadwal yang valid"
            exit 1
        fi
        ;;
    2)
        log "Tidak perlu update - jadwal masih valid"
        ;;
    *)
        output "ERROR: Status tidak dikenali"
        log "ERROR: Status tidak dikenali"
        ;;
esac

log "Proses update selesai"