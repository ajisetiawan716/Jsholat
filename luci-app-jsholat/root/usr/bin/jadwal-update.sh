#!/bin/sh
# Jadwal Updater Jsholat - Final Version
# (C) 2025 Jsholat - @ajisetiawan716

# ===== KONFIGURASI =====
LOG_FILE="/var/log/jsholat/jadwal-update.log"
LOG_TAG="jadwal-update"
MAX_LOG_SIZE=1048576  # 1MB
MAX_RETRIES=3
RETRY_DELAY=300  # 5 menit
JADWAL_FILE=$(uci get jsholat.setting.file_jadwal)
LAST_UPDATED_FILE="/usr/share/jsholat/last_updated.txt"
EXPIRY_THRESHOLD=$((36 * 3600))  # 36 jam
DEBUG_MODE=$(uci -q get jsholat.setting.debug_mode || echo "0")

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

add_timestamp() {
    while IFS= read -r line; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line"
    done
}

log() {
    rotate_log
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [Shell] $1" >> "$LOG_FILE"
    logger -t "$LOG_TAG" "$1"
}

# ===== FUNGSI VALIDASI =====

check_internet() {
    local timeout=3
    local ping_sites="google.com api.myquran.com aladhan.com"
    local curl_sites="https://google.com https://api.myquran.com/ https://api.aladhan.com/"
    
    log "Memeriksa koneksi internet..."
    
    # Coba dengan ping terlebih dahulu
    for site in $ping_sites; do
        if ping -c 1 -W "$timeout" "$site" >/dev/null 2>&1; then
            log "Koneksi tersedia via ping ke $site"
            return 0
        fi
    done
    
    # Fallback menggunakan curl jika ping gagal
    log "Ping gagal, mencoba fallback dengan curl..."
    
    for url in $curl_sites; do
        if curl --connect-timeout $timeout -s -I "$url" >/dev/null 2>&1; then
            log "Koneksi tersedia via curl ke $url"
            return 0
        fi
        [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Curl gagal ke $url"
    done
    
    log "ERROR: Semua tes koneksi (ping dan curl) gagal"
    return 1
}

check_jadwal_file() {
    [ ! -f "$JADWAL_FILE" ] && {
        log "ERROR: File jadwal tidak ditemukan: $JADWAL_FILE"
        return 1
    }

    [ ! -s "$JADWAL_FILE" ] && {
        log "ERROR: File jadwal kosong: $JADWAL_FILE"
        return 1
    }

    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: File jadwal valid"
    return 0
}

has_config_changed() {
    [ ! -f "$LAST_UPDATED_FILE" ] && return 0
    
    local current_source=$(uci get jsholat.setting.source)
    local current_city=$(uci get jsholat.setting.city_value | awk '{print tolower($0)}')
    
    local last_source_json=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
    local last_source
    
    case "$last_source_json" in
        "Jadwalsholat.org") last_source="jadwalsholat" ;;
        "Bimas Islam Kemenag/Api.MyQuran.com") last_source="myquran" ;;
        "Aladhan.com") last_source="aladhan" ;;
        "API AjiMedia") last_source="apiajimedia" ;;
        *) last_source="" ;;
    esac
    
    local last_city=$(jq -r '.location.city_value' "$LAST_UPDATED_FILE" 2>/dev/null | awk '{print tolower($0)}')
    
    [ -z "$last_source" ] || [ -z "$last_city" ] && return 0
    
    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Sumber UCI [$current_source] vs JSON [$last_source_json] -> Mapped [$last_source]"
    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Kota UCI [$current_city] vs JSON [$last_city]"
    
    [ "$current_source" != "$last_source" ] || [ "$current_city" != "$last_city" ]
}

is_jadwal_expired() {
    [ ! -f "$LAST_UPDATED_FILE" ] && {
        log "File last_updated.txt tidak ditemukan"
        return 0
    }

    if ! jq -e . "$LAST_UPDATED_FILE" >/dev/null 2>&1; then
        log "File last_updated.txt bukan JSON valid"
        return 0
    fi

    local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE" 2>/dev/null)
    [ -z "$last_updated" ] && {
        log "Field last_updated tidak ditemukan"
        return 0
    }

    # Konversi format tanggal
    local reformatted_date=$(echo "$last_updated" | 
        awk -F'[- :]' '{printf "%s-%s-%s %s:%s:%s", $3, $2, $1, $4, $5, $6}')

    if ! last_epoch=$(date -d "$reformatted_date" +%s 2>/dev/null); then
        log "Gagal parsing tanggal: $last_updated (setelah dikonversi ke: $reformatted_date)"
        return 0
    fi

    local now_epoch=$(date +%s)
    local age=$((now_epoch - last_epoch))
    local interval=$(uci get jsholat.setting.interval 2>/dev/null || echo "3600")

    # Handle monthly_special interval
    if [ "$interval" = "monthly_special" ]; then
        local last_month=$(date -d "@$last_epoch" +%m)
        local current_month=$(date +%m)		
        [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Interval monthly_special - Last: $last_month, Current: $current_month"
		
        [ "$last_month" != "$current_month" ] && {
            log "Jadwal kedaluwarsa (Pembaruan bulanan diperlukan)"
            return 0
        }
    else
        # Handle numeric interval
        local expiry_threshold=${EXPIRY_THRESHOLD:-$interval}
        [ "$age" -gt "$expiry_threshold" ] && {
            log "Jadwal kedaluwarsa. Usia: $(($age/3600)) jam (> $(($expiry_threshold/3600)) jam)"
            return 0
        }
    fi
    
    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Jadwal masih valid"
    return 1
}

# ===== FUNGSI UPDATE UTAMA =====

run_update() {
    local source_override="$1"
    local source="${source_override:-$(uci get jsholat.setting.source || echo "aladhan")}"

    log "Memulai update dari sumber: $source"

    # Eksekusi dengan timestamp dan tangkap output
    output=$(jadwal 2>&1)
    exit_code=$?

    # 1. Tampilkan output ke console TANPA timestamp
    echo "$output" | add_timestamp | sed -E 's/^\[[0-9-]+ [0-9:]+\] //'
    # 2. Simpan ke log DENGAN timestamp baru
    echo "$output" | while IFS= read -r line; do
        [ -n "$line" ] && log "$line"
    done

    if [ $exit_code -ne 0 ]; then
        log "ERROR: Gagal eksekusi script (Exit Code: $exit_code)"
        return 1
    fi

    if echo "$output" | grep -qi "error\|tidak ada koneksi internet\|gagal\|failed"; then
        log "ERROR: Terdeteksi pesan error dalam output"
        return 1
    fi

    if ! check_jadwal_file; then
        log "ERROR: File jadwal tidak valid setelah update"
        return 1
    fi

    log "Update data jadwal berhasil"
    return 0
}

run_update_with_retry() {
    # Pertama cek apakah jadwal masih valid dan tidak ada perubahan konfigurasi
    if check_jadwal_file && ! is_jadwal_expired && ! has_config_changed; then
        local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE")
        local last_source=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_city=$(jq -r '.location.city' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_province=$(jq -r '.location.province' "$LAST_UPDATED_FILE" 2>/dev/null)
        
        echo "Jadwal masih valid (Terakhir diupdate: $last_updated), Sumber: $last_source, Kota: $last_city, Provinsi: $last_province"
        log "Jadwal masih valid (Terakhir diupdate: $last_updated)"
        log "Konfigurasi sumber/kota tidak berubah"
        
        # Tambahan debug info untuk interval
        [ "$DEBUG_MODE" = "1" ] && {
            local interval=$(uci get jsholat.setting.interval 2>/dev/null || echo "default")
            log "DEBUG: Interval setting: $interval"
        }
        
        # Return status khusus untuk kasus jadwal masih valid
        return 2
    fi

    # Jika jadwal kedaluwarsa atau ada perubahan konfigurasi, lanjutkan dengan update
    local update_reason=""
    if is_jadwal_expired; then
        local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE")
        local interval_info=""
        
        # Tambahan info interval khusus
        if [ "$(uci get jsholat.setting.interval 2>/dev/null)" = "monthly_special" ]; then
            interval_info=" (Pembaruan bulanan)"
        fi
        
        update_reason="Jadwal kedaluwarsa${interval_info} (Terakhir diupdate: $last_updated)"
    fi

    if has_config_changed; then
        local current_source=$(uci get jsholat.setting.source)
        local current_city=$(uci get jsholat.setting.city_value)
        local last_source=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_city=$(jq -r '.location.city_value' "$LAST_UPDATED_FILE" 2>/dev/null)
        
        update_reason="$update_reason, Konfigurasi berubah: Sumber [$last_source → $current_source], Kota [$last_city → $current_city]"
    fi

    if ! check_jadwal_file; then
        update_reason="$update_reason, File jadwal tidak valid"
    fi

    log "Memulai update karena: ${update_reason#, }"

    # Cek koneksi internet sebelum mencoba update
    if ! check_internet; then
        if check_jadwal_file; then
            last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE" 2>/dev/null || echo "unknown")
            log "Menggunakan jadwal terakhir: $last_updated"
            echo "INFO: Menggunakan jadwal terakhir - $last_updated"
            return 0
        else
            log "ERROR: Tidak ada koneksi dan tidak ada jadwal valid"
            echo "ERROR: Tidak bisa mendapatkan jadwal (offline dan tidak ada cadangan)"
            return 1
        fi
    fi

    local attempt=1
    while [ "$attempt" -le "$MAX_RETRIES" ]; do
        log "Percobaan update ke-$attempt"
        
        if run_update; then
            log "Update berhasil pada percobaan ke-$attempt"
            return 0
        fi
        
        [ $attempt -lt $MAX_RETRIES ] && {
            log "Menunggu $RETRY_DELAY detik sebelum mencoba lagi..."
            sleep "$RETRY_DELAY"
        }
        attempt=$((attempt+1))
    done

    log "GAGAL: Update tidak berhasil setelah $MAX_RETRIES percobaan"
    return 1
}

restart_service() {
    log "Memulai restart service jsholat..."
    if /etc/init.d/jsholat restart 2>&1 | add_timestamp; then
        log "Service berhasil di-restart"
        return 0
    else
        log "ERROR: Gagal restart service"
        return 1
    fi
}

# ===== MAIN EXECUTION =====
init
log "Memulai update jadwal"

# Langsung cek status jadwal terlebih dahulu
run_update_with_retry
exit_code=$?

case $exit_code in
    0)  # Update berhasil
        log "Proses update berhasil"
        restart_service
        ;;
    1)  # Update gagal
        if check_jadwal_file; then
            last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE" 2>/dev/null || echo "unknown")
            log "Menggunakan jadwal terakhir: $last_updated"
            echo "WARNING: Menggunakan jadwal terakhir karena gagal update - $last_updated"
        else
            log "ERROR: Tidak ada jadwal yang valid"
            echo "ERROR: Tidak ada jadwal yang valid tersedia"
            exit 1
        fi
        ;;
    2)  # Jadwal masih valid
        log "Tidak perlu update - jadwal masih valid"
        ;;
    *)  # Unknown status
        log "ERROR: Status tidak dikenali"
        ;;
esac

log "Proses update selesai"