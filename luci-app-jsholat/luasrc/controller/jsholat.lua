module("luci.controller.jsholat", package.seeall)

function index()
    -- Entry utama untuk halaman jadwal sholat
   entry({"admin", "services", "jsholat"}, cbi("jsholat"), _("Jadwal Sholat"), 60)

    -- Entry untuk halaman pengaturan jadwal
    entry({"admin", "services", "jsholat", "setting"}, cbi("jsholat"), _("Pengaturan Jadwal"), 70)

    -- Entry untuk halaman lihat jadwal
    entry({"admin", "services", "jsholat", "jadwal"}, call("action_jadwal"), _("Lihat Jadwal"), 80)

    -- Entry untuk pembaruan jadwal via AJAX
    entry({"admin", "services", "jsholat", "update"}, call("action_update")).leaf = true
    
    -- Entry baru untuk halaman log service 
    entry({"admin", "services", "jsholat", "logs"}, call("action_logs"), _("Log Service"), 90)
    entry({"admin", "services", "jsholat", "logs", "tail"}, call("action_tail_log"))
    
    -- Enrty untuk mendapatkan data kota
    entry({"admin", "services", "jsholat", "get_cities"}, call("get_cities")).leaf = true
    entry({"admin", "services", "jsholat", "get_timezone"}, call("get_timezone")).leaf = true
    entry({"admin", "services", "jsholat", "get_init_data"}, call("get_init_data")).leaf = true
end

-- Fungsi menampilkan jadwal
function action_jadwal()
    -- Membaca nilai file_jadwal dari konfigurasi UCI
    local uci = luci.model.uci.cursor()
    local file_path = uci:get("jsholat", "schedule", "file_jadwal") or "/root/jsholat/jadwal.txt"

    -- Inisialisasi variabel untuk pesan error dan data jadwal
    local error_message = nil
    local jadwal = {}

    -- Coba buka file
    local file, err = io.open(file_path, "r")
    if not file then
        error_message = "File jadwal tidak ditemukan: " .. err
    else
        -- Baca isi file
        local content = file:read("*all")
        file:close()

        if content == "" then
            error_message = "File jadwal kosong"
        else
            -- Parsing isi file
            for line in content:gmatch("[^\r\n]+") do
                table.insert(jadwal, line)
            end

            if #jadwal == 0 then
                error_message = "Format file jadwal tidak sesuai"
            end
        end
    end

-- Dapatkan nama kota dari konfigurasi UCI untuk tampilan output "Terakhir diperbarui"
    -- Dapatkan nama kota dari konfigurasi UCI
    local cityName = uci:get("jsholat", "schedule", "city_label") or "Kota Tidak Diketahui"

-- Baca isi file last_updated.txt
-- Import library JSON (pastikan tersedia di OpenWRT/Luci)
local json
do
    local ok, mod = pcall(require, "luci.jsonc")
    if ok then
        json = mod
        json.decode = json.decode or json.parse  -- dukung parse di jsonc
    else
        json = require("luci.json")  -- fallback lama
    end
end

-- Fungsi untuk membaca file last_updated.txt (format JSON)
local function getLastUpdatedInfo()
    local file_path = "/usr/share/jsholat/last_updated.txt"
    local default = {
        last_updated = "Waktu tidak diketahui",
        data_source = "Sumber tidak tersedia"
    }

    -- 1. Buka file
    local file = io.open(file_path, "r")
    if not file then
        return default
    end

    -- 2. Baca konten file
    local content = file:read("*a")
    file:close()

    -- 3. Jika file kosong
    if #content == 0 then
        return default
    end

    -- 4. Parse JSON
    local success, data = pcall(json.decode, content)
    if not success or type(data) ~= "table" then
        return default
    end

    -- 5. Pastikan field yang diperlukan ada
    return {
        last_updated = data.last_updated or default.last_updated,
        data_source = data.data_source or default.data_source
    }
end

-- Dapatkan info terakhir update
local updateInfo = getLastUpdatedInfo()

-- Format output untuk template
local lastUpdatedDisplay = string.format(
    "Terakhir diperbarui: <strong>%s</strong> | Sumber: <em>%s</em>",
    updateInfo.last_updated,
    updateInfo.data_source
)

    -- Dapatkan tanggal hari ini dalam format DD-MM-YYYY
    local today = os.date("%d-%m-%Y")

    -- Dapatkan bulan dan tahun dari tanggal hari ini
    local day, month, year = today:match("(%d+)-(%d+)-(%d+)")
    local monthNames = {
        "Januari", "Februari", "Maret", "April", "Mei", "Juni",
        "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    }
    local monthName = monthNames[tonumber(month)]

    -- Fungsi untuk memvalidasi format waktu (HH:MM)
    local function isValidTime(time)
        return time and time:match("^%d%d:%d%d$")
    end

    -- Fungsi untuk mendapatkan waktu sholat berikutnya
local function getNextPrayerTime()
    local now = os.time()
    local nextPrayerTime = nil
    local nextPrayerName = nil

    -- Loop melalui jadwal sholat untuk menemukan waktu sholat berikutnya
    for _, line in ipairs(jadwal) do
        local date, imsyak, subuh, dzuhur, ashar, maghrib, isya = line:match("(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)")
        if date == today then
            local prayerTimes = {
                {name = "Imsyak", time = imsyak},
                {name = "Subuh", time = subuh},
                {name = "Dzuhur", time = dzuhur},
                {name = "Ashar", time = ashar},
                {name = "Maghrib", time = maghrib},
                {name = "Isya", time = isya}
            }

            for _, prayer in ipairs(prayerTimes) do
                if isValidTime(prayer.time) then
                    local prayerTime = os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day), hour=tonumber(prayer.time:sub(1, 2)), min=tonumber(prayer.time:sub(4, 5)), sec=0})
                    if prayerTime > now then
                        if not nextPrayerTime or prayerTime < nextPrayerTime then
                            nextPrayerTime = prayerTime
                            nextPrayerName = prayer.name
                        end
                    end
                end
            end
        end
    end

    -- Jika tidak ada waktu sholat yang tersisa pada hari ini, cari waktu sholat pertama pada hari berikutnya
    if not nextPrayerTime then
        local tomorrow = os.date("%d-%m-%Y", os.time() + 86400) -- Tambah 1 hari (86400 detik)
        for _, line in ipairs(jadwal) do
            local date, imsyak, subuh, dzuhur, ashar, maghrib, isya = line:match("(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)")
            if date == tomorrow then
                local prayerTimes = {
                    {name = "Imsyak", time = imsyak},
                    {name = "Subuh", time = subuh},
                    {name = "Dzuhur", time = dzuhur},
                    {name = "Ashar", time = ashar},
                    {name = "Maghrib", time = maghrib},
                    {name = "Isya", time = isya}
                }

                for _, prayer in ipairs(prayerTimes) do
                    if isValidTime(prayer.time) then
                        local prayerTime = os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day) + 1, hour=tonumber(prayer.time:sub(1, 2)), min=tonumber(prayer.time:sub(4, 5)), sec=0})
                        if not nextPrayerTime or prayerTime < nextPrayerTime then
                            nextPrayerTime = prayerTime
                            nextPrayerName = prayer.name
                        end
                    end
                end
                break
            end
        end
    end

    return nextPrayerTime, nextPrayerName
end

    local nextPrayerTime, nextPrayerName = getNextPrayerTime()

    -- Render template dengan semua data yang diperlukan
    luci.template.render("jsholat/jadwal", {
        error_message = error_message,
        jadwal = jadwal,
        cityName = cityName,
        lastUpdated = lastUpdatedDisplay,
        today = today,
        monthName = monthName,
        year = year,
        nextPrayerTime = nextPrayerTime,
        nextPrayerName = nextPrayerName
    })
end

-- Fungsi untuk menjalankan update jadwal dari tombol
function action_update()
    local uci = luci.model.uci.cursor()
    if not uci then
        local err_msg = "Gagal memuat konfigurasi UCI"
        log_error(err_msg)
        luci.http.prepare_content("text/plain")
        luci.http.write(err_msg)
        return
    end

    -- Fungsi logging ke file (dengan timestamp)
    local function log_to_file(msg, source)
        source = source or "Lua"
        local logfile = io.open("/var/log/jsholat/jadwal-update.log", "a")
        if logfile then
            logfile:write(string.format("[%s] [%s] %s\n", 
                os.date("%Y-%m-%d %H:%M:%S"), source, msg))
            logfile:close()
        end
    end

    -- Fungsi error handling
    local function log_error(msg)
        log_to_file("[ERROR] "..msg)
        return msg -- Return pesan asli untuk output CLI
    end

    -- Fungsi restart service (output CLI bersih)
    local function restart_jsholat_service()
        log_to_file("Memulai restart service jsholat...", "Service")
        
        -- Eksekusi dan ambil exit code
        local handle = io.popen("/etc/init.d/jsholat restart >/dev/null 2>&1; echo $?")
        local exit_code = handle:read("*a"):match("%d+") or "1"
        handle:close()
        
        -- Verifikasi proses
        local proc_handle = io.popen("pgrep -f 'jsholat' | wc -l 2>/dev/null")
        local proc_count = tonumber(proc_handle:read("*a")) or 0
        proc_handle:close()
        
        -- Log hasil
        log_to_file(string.format("Hasil restart - Exit: %s, Proses: %d", exit_code, proc_count), "Service")
        
        if exit_code == "0" and proc_count > 0 then
            log_to_file("Service berhasil di-restart", "Service")
            return true, "Service jsholat direstart"
        else
            return false, log_error("Gagal restart service jsholat")
        end
    end

    -- Main Process
    local response = ""
    local source = uci:get("jsholat", "schedule", "source") or "aladhan"
    source = source:lower():gsub("[^%w]", "")

    -- Validasi sumber
    if not ({aladhan=true, jadwalsholat=true, myquran=true, apiajimedia=true})[source] then
        response = response .. log_error("Sumber tidak valid: "..source) .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    -- Eksekusi update
    response = response .. "Memulai update jadwal...\n"
    log_to_file("Memulai update jadwal...")
    response = response .. "Menggunakan Sumber: " .. source .. "\n"
    log_to_file("Memulai update dari sumber: "..source)

    local script = "/usr/bin/jadwal"
    if not nixio.fs.access(script, "x") then
        response = response .. log_error("Script tidak dapat dijalankan") .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    local handle = io.popen(script.." "..source.." 2>&1")
    if handle then
        -- Output langsung ke response (tanpa log tag)
        for line in handle:lines() do
            response = response .. line .. "\n"
            log_to_file(line, "Script") -- Log ke file dengan timestamp
        end
        handle:close()
        
        -- Restart jika berhasil
        if response:match("berhasil") or response:match("success") then
            local success, restart_msg = restart_jsholat_service()
            response = response .. restart_msg .. "\n"
        end
    else
        response = response .. log_error("Gagal menjalankan script") .. "\n"
    end

    response = response .. "Update jadwal selesai\n"
    log_to_file("Update jadwal selesai")
    
    luci.http.prepare_content("text/plain")
    luci.http.write(response)
end
-------------
-- Fungsi baru untuk menampilkan log service
function action_logs()
    local log_files = {
        {
            name = "Service Jadwal",
            path = "/var/log/jsholat/jadwal.log",
            desc = "Log dari service /etc/init.d/jadwal"
        },
        {
            name = "Service Jsholat",
            path = "/var/log/jsholat/service.log",
            desc = "Log dari service jsholat"
        },
        {
            name = "Cron Job Jadwal",
            path = "/var/log/jsholat/jadwal-update.log",
            desc = "Log eksekusi cron job"
        },
        {
            name = "Service Bot Telegram",
            path = "/var/log/jsholat/bot.log",
            desc = "Log dari service jsholat-bot"
        }
    }

    local function tail_log(filepath, lines)
        lines = lines or 100
        local handle = io.popen("tail -n " .. lines .. " " .. filepath .. " 2>/dev/null")
        if not handle then return "Gagal membaca log." end
        local result = handle:read("*a")
        handle:close()
        return result or ""
    end

    local logs_data = {}
    for _, log in ipairs(log_files) do
        local content = tail_log(log.path, 100)
        logs_data[log.name] = {
            path = log.path,
            desc = log.desc,
            content = content
        }
    end

    luci.template.render("jsholat/logs", {
        logs = logs_data,
        errors = {} 
    })
end

-- Fungsi inisiasi dari config
function get_init_data()
    local uci = require("luci.model.uci").cursor()
    local response = {
        province = uci:get("jsholat", "schedule", "province") or "",
        city = uci:get("jsholat", "schedule", "city_value") or "",  -- ← GUNAKAN city_value BUKAN city
        city_label = uci:get("jsholat", "schedule", "city_label") or "",
        timezone = uci:get("jsholat", "schedule", "timezone_value") or "WIB"  -- ← GUNAKAN timezone_value
    }
    
    -- Clean up invalid values
    if response.city == "-" or response.city == "" then
        response.city = ""
    end
    
    if response.city_label == "-" or response.city_label == "" then
        response.city_label = ""
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(response)
end

-- Fungsi untuk mendapatkan data kota
function get_cities()
    local http = require("luci.http")
    local province = http.formvalue("province")
    local response = { cities = {}, status = "error", message = "" }
    
    -- Load JSON library dengan fallback
    local json
    do
        local ok, mod = pcall(require, "luci.jsonc")
        if ok then
            json = mod
            json.decode = json.decode or json.parse
        else
            json = require("luci.json")
        end
    end
    
    -- Validasi input
    if not province or province == "" then
        response.message = "Provinsi tidak dipilih"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    -- Baca file JSON
    local file, err = io.open("/usr/share/jsholat/cities.json", "r")
    if not file then
        response.message = "File cities.json tidak ditemukan: " .. tostring(err)
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    local content = file:read("*a")
    file:close()
    
    -- Parse JSON dengan error handling
    local success, data = pcall(json.decode, content)
    if not success then
        response.message = "Error parsing JSON: " .. tostring(data)
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    if not data or type(data) ~= "table" then
        response.message = "Data JSON tidak valid"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    -- Cek apakah provinsi ada
    if not data[province] then
        response.message = "Provinsi '" .. province .. "' tidak ditemukan"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    -- ✅ PERBAIKAN: Format response yang konsisten
    response.cities = {}
    for _, city_data in ipairs(data[province]) do
        table.insert(response.cities, {
            value = city_data.value,
            label = city_data.label
            -- Hanya kirim value dan label saja
        })
    end
    
    response.status = "success"
    response.message = "Berhasil mengambil " .. #response.cities .. " kota"
    
    http.prepare_content("application/json")
    http.write_json(response)
end

-- Fungsi untuk mendapatkan timezone
function get_timezone()
    local http = require("luci.http")
    local city = http.formvalue("city")
    local response = { timezone = "WIB", city_label = "", status = "success" }
    
    -- Load JSON library dengan fallback (SAMA SEPERTI get_cities)
    local json
    do
        local ok, mod = pcall(require, "luci.jsonc")
        if ok then
            json = mod
            json.decode = json.decode or json.parse
        else
            json = require("luci.json")
        end
    end
    
    if not city or city == "" then
        response.status = "error"
        response.message = "Kota tidak dipilih"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    local file, err = io.open("/usr/share/jsholat/cities.json", "r")
    if not file then
        response.status = "error"
        response.message = "File cities.json tidak ditemukan: " .. tostring(err)
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    local content = file:read("*a")
    file:close()
    
    -- Parse JSON dengan error handling
    local success, data = pcall(json.decode, content)
    if not success then
        response.status = "error"
        response.message = "Error parsing JSON: " .. tostring(data)
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    if not data or type(data) ~= "table" then
        response.status = "error"
        response.message = "Data JSON tidak valid"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    -- Cari kota di semua provinsi
    local found = false
    for prov, cities in pairs(data) do
        for _, c in ipairs(cities) do
            if c.value == city then
                response.timezone = c.timezone or "WIB"
                response.city_label = c.label or c.name or "Unknown"
                found = true
                break
            end
        end
        if found then break end
    end
    
    if not found then
        response.status = "error"
        response.message = "Kota '" .. city .. "' tidak ditemukan"
    end
    
    http.prepare_content("application/json")
    http.write_json(response)
end
