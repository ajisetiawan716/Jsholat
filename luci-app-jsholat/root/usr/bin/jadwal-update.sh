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
    
    # Tampilkan ke stdout (akan ditangkap bot)
    echo "$line"
    
    # Tulis ke log dengan timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $line" >> "$LOG_FILE"
    
    # Flush stdout agar segera dikirim
    # (hanya bash, di sh mungkin tidak perlu)
    # >&2 echo "" > /dev/null
}

# Fungsi untuk log saja (tanpa stdout)
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
    
    output "Memeriksa koneksi internet..."
    
    # Coba dengan ping terlebih dahulu
    for site in $ping_sites; do
        if ping -c 1 -W "$timeout" "$site" >/dev/null 2>&1; then
            output "Koneksi tersedia via ping ke $site"
            return 0
        fi
    done
    
    # Fallback menggunakan curl jika ping gagal
    output "Ping gagal, mencoba fallback dengan curl..."
    
    for url in $curl_sites; do
        if curl --connect-timeout $timeout -s -I "$url" >/dev/null 2>&1; then
            output "Koneksi tersedia via curl ke $url"
            return 0
        fi
        [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Curl gagal ke $url"
    done
    
    output "ERROR: Semua tes koneksi (ping dan curl) gagal"
    return 1
}

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
    
    # ===== NORMALISASI KOTA CURRENT =====
    # Ubah "Kab. Brebes" → "kab brebes" (tanpa titik, tanpa plus, lowercase)
    local current_city=$(echo "$current_city_raw" | \
        awk '{print tolower($0)}' | \
        sed -e 's/\.//g' -e 's/+/ /g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//')
    
    local last_source_json=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
    local last_source=""
    local last_city_raw=""
    local last_city=""
    
    # ===== MAPPING SUMBER =====
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
    
    # ===== AMBIL NILAI KOTA DARI JSON =====
    last_city_raw=$(jq -r '.location.city_value // .location.city // ""' "$LAST_UPDATED_FILE" 2>/dev/null)
    
    # ===== NORMALISASI KOTA LAST =====
    # Ubah "Kab.+Brebes" → "kab brebes" (tanpa plus, lowercase)
    last_city=$(echo "$last_city_raw" | \
        awk '{print tolower($0)}' | \
        sed -e 's/\.//g' -e 's/+/ /g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//')
    
    # Debug info
    [ "$DEBUG_MODE" = "1" ] && {
        log "DEBUG: === HAS_CONFIG_CHANGED (NORMALIZED) ==="
        log "DEBUG: UCI Source: $current_source"
        log "DEBUG: JSON Source: $last_source_json → Mapped: $last_source"
        log "DEBUG: UCI City Raw: $current_city_raw"
        log "DEBUG: JSON City Raw: $last_city_raw"
        log "DEBUG: UCI City Norm: $current_city"
        log "DEBUG: JSON City Norm: $last_city"
    }
    
    # ===== KOMPARASI =====
    if [ "$current_source" != "$last_source" ]; then
        [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Sumber BERUBAH: '$last_source' → '$current_source'"
        return 0
    fi
    
    if [ "$current_city" != "$last_city" ]; then
        [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Kota BERUBAH: '$last_city' → '$current_city'"
        return 0
    fi
    
    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Konfigurasi TIDAK BERUBAH"
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

    # Konversi format tanggal
    local reformatted_date=$(echo "$last_updated" | 
        awk -F'[- :]' '{printf "%s-%s-%s %s:%s:%s", $3, $2, $1, $4, $5, $6}')

    if ! last_epoch=$(date -d "$reformatted_date" +%s 2>/dev/null); then
        output "Gagal parsing tanggal: $last_updated (setelah dikonversi ke: $reformatted_date)"
        return 0
    fi

    local now_epoch=$(date +%s)
    local age=$((now_epoch - last_epoch))
    local interval=$(uci get jsholat.schedule.interval 2>/dev/null || echo "3600")

    # Handle monthly_special interval
    if [ "$interval" = "monthly_special" ]; then
        local last_month=$(date -d "@$last_epoch" +%m)
        local current_month=$(date +%m)		
        [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Interval monthly_special - Last: $last_month, Current: $current_month"
		
        [ "$last_month" != "$current_month" ] && {
            output "Jadwal kedaluwarsa (Pembaruan bulanan diperlukan)"
            return 0
        }
    else
        # Handle numeric interval
        local expiry_threshold=${EXPIRY_THRESHOLD:-$interval}
        [ "$age" -gt "$expiry_threshold" ] && {
            output "Jadwal kedaluwarsa. Usia: $(($age/3600)) jam (> $(($expiry_threshold/3600)) jam)"
            return 0
        }
    fi
    
    [ "$DEBUG_MODE" = "1" ] && log "DEBUG: Jadwal masih valid"
    return 1
}

# ===== FUNGSI UPDATE UTAMA =====

run_update() {
    local source_override="$1"
    local source="${source_override:-$(uci get jsholat.schedule.source || echo "aladhan")}"

    output "Memulai update dari sumber: $source"

    # Eksekusi jadwal dan proses output secara real-time
    # Menggunakan stdbuf untuk menonaktifkan buffering jika tersedia
    if command -v stdbuf >/dev/null 2>&1; then
        stdbuf -oL -eL jadwal run 2>&1 | while IFS= read -r line; do
            if [ -n "$line" ]; then
                output "$line"
                log "$line"
            fi
        done
        exit_code=${PIPESTATUS[0]}
    else
        # Fallback tanpa stdbuf
        jadwal run 2>&1 | while IFS= read -r line; do
            if [ -n "$line" ]; then
                output "$line"
                log "$line"
            fi
        done
        exit_code=${PIPESTATUS[0]}
    fi

    if [ $exit_code -ne 0 ]; then
        output "ERROR: Gagal eksekusi script (Exit Code: $exit_code)"
        return 1
    fi

    if ! check_jadwal_file; then
        output "ERROR: File jadwal tidak valid setelah update"
        return 1
    fi

    output "Update data jadwal berhasil"
    return 0
}

run_update_with_retry() {
    # Pertama cek apakah jadwal masih valid dan tidak ada perubahan konfigurasi
    if check_jadwal_file && ! is_jadwal_expired && ! has_config_changed; then
        local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE")
        local last_source=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_city=$(jq -r '.location.city' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_province=$(jq -r '.location.province' "$LAST_UPDATED_FILE" 2>/dev/null)
        
        output "Jadwal masih valid (Terakhir diupdate: $last_updated), Sumber: $last_source, Kota: $last_city, Provinsi: $last_province"
        log "Jadwal masih valid (Terakhir diupdate: $last_updated)"
        log "Konfigurasi sumber/kota tidak berubah"
        
        # Return status khusus untuk kasus jadwal masih valid
        return 2
    fi

    # Jika jadwal kedaluwarsa atau ada perubahan konfigurasi, lanjutkan dengan update
    local update_reason=""
    if is_jadwal_expired; then
        local last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE")
        local interval_info=""
        
        # Tambahan info interval khusus
        if [ "$(uci get jsholat.schedule.interval 2>/dev/null)" = "monthly_special" ]; then
            interval_info=" (Pembaruan bulanan)"
        fi
        
        update_reason="Jadwal kedaluwarsa${interval_info} (Terakhir diupdate: $last_updated)"
    fi

    if has_config_changed; then
        local current_source=$(uci get jsholat.schedule.source)
        local current_city=$(uci get jsholat.schedule.city_value)
        local last_source=$(jq -r '.data_source' "$LAST_UPDATED_FILE" 2>/dev/null)
        local last_city=$(jq -r '.location.city_value' "$LAST_UPDATED_FILE" 2>/dev/null)
        
        update_reason="$update_reason, Konfigurasi berubah: Sumber [$last_source → $current_source], Kota [$last_city → $current_city]"
    fi

    if ! check_jadwal_file; then
        update_reason="$update_reason, File jadwal tidak valid"
    fi

    log "Memulai update karena: ${update_reason#, }"
    output "Memulai update karena: ${update_reason#, }"

    # Cek koneksi internet sebelum mencoba update
    if ! check_internet; then
        if check_jadwal_file; then
            last_updated=$(jq -r '.last_updated' "$LAST_UPDATED_FILE" 2>/dev/null || echo "unknown")
            log "Menggunakan jadwal terakhir: $last_updated"
            output "INFO: Menggunakan jadwal terakhir - $last_updated"
            return 0
        else
            log "ERROR: Tidak ada koneksi dan tidak ada jadwal valid"
            output "ERROR: Tidak bisa mendapatkan jadwal (offline dan tidak ada cadangan)"
            return 1
        fi
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
    
    if [ "$DEBUG_MODE" = "1" ]; then
        # Debug mode: tampilkan output
        if /etc/init.d/jsholat restart 2>&1 | while IFS= read -r line; do
            [ -n "$line" ] && output "$line"
        done; then
            output "Service berhasil di-restart"
            log "Service berhasil di-restart"
            return 0
        else
            output "ERROR: Gagal restart service"
            log "ERROR: Gagal restart service"
            return 1
        fi
    else
        # Normal mode: sembunyikan output
        if /etc/init.d/jsholat restart >/dev/null 2>&1; then
            output "Service berhasil di-restart"
            log "Service berhasil di-restart"
            return 0
        else
            output "ERROR: Gagal restart service"
            log "ERROR: Gagal restart service"
            return 1
        fi
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
        output "Proses update berhasil"
        log "Proses update berhasil"
        restart_service
        ;;
    1)  # Update gagal
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
    2)  # Jadwal masih valid
        #output "Tidak perlu update - jadwal masih valid"
        log "Tidak perlu update - jadwal masih valid"
        ;;
    *)  # Unknown status
        output "ERROR: Status tidak dikenali"
        log "ERROR: Status tidak dikenali"
        ;;
esac

#output "Proses update selesai"
log "Proses update selesai"