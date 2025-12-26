module("luci.controller.jsholat", package.seeall)

function index()
    -- Entry utama untuk halaman jadwal sholat
   entry({"admin", "services", "jsholat"}, cbi("jsholat"), _("Jadwal Sholat"), 60)

    -- Entry untuk halaman pengaturan jadwal
    entry({"admin", "services", "jsholat", "setting"}, cbi("jsholat"), _("Pengaturan Jadwal"), 50)
    
    -- Entry untuk halaman status detail
    entry({"admin", "services", "jsholat", "status_detail"}, template("jsholat/status_detail"), _("Status Detail"), 70)

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
    
    -- Entry untuk mendapatkan status 
    entry({"admin", "services", "jsholat", "status_json"}, call("get_status_json"), nil).leaf = true
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

    -- Cek dan persiapkan script path
    local script_path = "/usr/bin/jadwal"
    local script_exists = nixio.fs.access(script_path, "r")
    
    -- Debug: Log informasi file
    log_to_file("Script path: " .. script_path)
    log_to_file("File exists: " .. tostring(script_exists))
    
    if not script_exists then
        response = response .. log_error("Script tidak ditemukan di: " .. script_path) .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    -- Cek permission (gunakan sh -c untuk menjalankan)
    local handle, err
    if source == "aladhan" then
        -- Untuk aladhan (default), jalankan tanpa parameter source
        log_to_file("Menjalankan: /usr/bin/jadwal run")
        handle, err = io.popen("/usr/bin/jadwal run 2>&1")
    else
        -- Untuk sumber lain, tambahkan parameter
        log_to_file("Menjalankan: /usr/bin/jadwal run " .. source)
        handle, err = io.popen("/usr/bin/jadwal run " .. source .. " 2>&1")
    end
    
    if not handle then
        response = response .. log_error("Gagal membuat proses: " .. (err or "unknown")) .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    -- Baca output
    local output = handle:read("*a")
    handle:close()
    
    -- Tambahkan output ke response
    response = response .. output
    
    -- Log output ke file
    log_to_file("Output script: " .. output)
    
    -- Restart jika berhasil
    if output:match("berhasil") or output:match("success") then
        local success, restart_msg = restart_jsholat_service()
        response = response .. restart_msg .. "\n"
    end

    response = response .. "\nUpdate jadwal selesai\n"
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
        city = uci:get("jsholat", "schedule", "city_value") or "",  
        city_label = uci:get("jsholat", "schedule", "city_label") or "",
        timezone = uci:get("jsholat", "schedule", "timezone_value") or "WIB" 
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
    
    -- Format response yang konsisten
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

-- Fungsi untuk mendapatkan status detail
function get_status_json()
    local uci = require("luci.model.uci").cursor()
    local json
    do
        local ok, mod = pcall(require, "luci.jsonc")
        if ok then
            json = mod
            json.decode = json.decode or json.parse
            json.encode = json.encode or json.stringify
        else
            json = require("luci.json")
        end
    end
    local nixio = require("nixio")

    -- konversi ke boolean
    local function to_bool(v)
        if v == true or v == false then return v end
        if type(v) == "number" then return v ~= 0 end
        if type(v) ~= "string" then return false end
        return v == "1" or v:lower() == "true"
    end

    -- konversi ke number
    local function to_number(v)
        if type(v) == "number" then return v end
        if type(v) ~= "string" then return nil end
        return tonumber(v)
    end

    -- humanize detik -> hari/jam/menit/detik
    local function humanize_seconds(sec)
        sec = tonumber(sec) or 0
        if sec <= 0 then return "0 detik" end

        local days = math.floor(sec / 86400)
        local hours = math.floor((sec % 86400) / 3600)
        local mins = math.floor((sec % 3600) / 60)
        local secs = sec % 60

        local parts = {}
        if days > 0 then table.insert(parts, days .. " hari") end
        if hours > 0 then table.insert(parts, hours .. " jam") end
        if mins > 0 then table.insert(parts, mins .. " menit") end
        if secs > 0 then table.insert(parts, secs .. " detik") end

        return table.concat(parts, " ")
    end

    -- konversi HH:MM atau HH:MM:SS -> detik
    local function time_to_seconds(t)
        local h, m, s = t:match("(%d+):(%d+):?(%d*)")
        return (tonumber(h) or 0) * 3600
             + (tonumber(m) or 0) * 60
             + (tonumber(s) or 0)
    end

    -- baca jsholat info
    local handle = io.popen("jsholat info 2>/dev/null")
    local raw = ""
    if handle then
        raw = handle:read("*a") or ""
        handle:close()
    end

    local status_data = {}
    local ok, parsed = pcall(function() return json.decode(raw) end)
    if ok and type(parsed) == "table" then
        status_data = parsed
    else
        status_data = {
            services = {},
            config = {},
            location = {},
            schedule = {},
            next_prayer = {},
            system = {},
            status = { last_update = os.date("%Y-%m-%d %H:%M:%S") }
        }
    end

    -- normalize services.jsholat
    status_data.services = status_data.services or {}
    local s = status_data.services.jsholat or {}
    s.enabled = to_bool(s.enabled)
    s.running = to_bool(s.running)
    s.pid = to_number(s.pid) or 0
    s.uptime = to_number(s.uptime) or 0
    if not s.uptime_human then s.uptime_human = humanize_seconds(s.uptime) end
    s.start_time = s.start_time or ""
    status_data.services.jsholat = s

    -- normalize services.jsholat-bot
    local b = status_data.services["jsholat-bot"] or {}
    b.running = to_bool(b.running)
    b.pid = to_number(b.pid) or 0
    b.memory_mb = to_number(b.memory_mb) or nil
    b.uptime = to_number(b.uptime) or 0
    if not b.uptime_human then b.uptime_human = humanize_seconds(b.uptime) end
    b.configured = to_bool(b.configured)
    b.telegram_notifications = to_bool(b.telegram_notifications or b.telegram_enabled or (status_data.config and status_data.config.telegram_enabled))
    status_data.services["jsholat-bot"] = b

    -- normalize config
    status_data.config = status_data.config or {}
    status_data.config.telegram_enabled = to_bool(status_data.config.telegram_enabled)
    status_data.config.telegram_configured = to_bool(status_data.config.telegram_configured)
    status_data.config.sound = to_bool(status_data.config.sound)
    status_data.config.volume = to_number(status_data.config.volume) or 0
    status_data.config.ayat = to_bool(status_data.config.ayat)
    status_data.config.reminder = to_number(status_data.config.reminder) or 0
    status_data.config.debug = to_bool(status_data.config.debug)

    -- location & schedule defaults
    status_data.location = status_data.location or {}
    status_data.location.city = status_data.location.city or status_data.location.name or ""
    status_data.location.province = status_data.location.province or ""
    status_data.location.date = status_data.location.date or os.date("%d-%m-%Y")
    status_data.location.timezone = status_data.location.timezone or "WIB"

    status_data.schedule = status_data.schedule or {}
    status_data.schedule.today = status_data.schedule.today or os.date("%d-%m-%Y")
    status_data.schedule.imsyak = status_data.schedule.imsyak or "-"
    status_data.schedule.subuh = status_data.schedule.subuh or "-"
    status_data.schedule.dzuhur = status_data.schedule.dzuhur or "-"
    status_data.schedule.ashar = status_data.schedule.ashar or "-"
    status_data.schedule.maghrib = status_data.schedule.maghrib or "-"
    status_data.schedule.isya = status_data.schedule.isya or "-"

    -- next_prayer normalization
    status_data.next_prayer = status_data.next_prayer or {}
    status_data.next_prayer.name = status_data.next_prayer.name or ""
    status_data.next_prayer.time = status_data.next_prayer.time or ""

    -- hitung seconds_left real-time
    local current_time = os.date("%H:%M:%S")
    if status_data.next_prayer.time ~= "" then
        local now_sec = time_to_seconds(current_time)
        local next_sec = time_to_seconds(status_data.next_prayer.time)
        local diff = next_sec - now_sec
        if diff < 0 then diff = diff + 86400 end  -- lewat tengah malam
        status_data.next_prayer.seconds_left = diff
        status_data.next_prayer.minutes_left = math.floor(diff / 60)
        status_data.next_prayer.minutes_left_human = humanize_seconds(diff)
    else
        status_data.next_prayer.seconds_left = 0
        status_data.next_prayer.minutes_left = 0
        status_data.next_prayer.minutes_left_human = "0 detik"
    end

    -- system normalization
    status_data.system = status_data.system or {}
    status_data.system.current_time = status_data.system.current_time or os.date("%H:%M:%S")
    status_data.system.uptime = to_number(status_data.system.uptime) or 0
    if not status_data.system.uptime_human then status_data.system.uptime_human = humanize_seconds(status_data.system.uptime) end
    
    -- memory normalization
    if status_data.system and status_data.system.memory then
        local mem = status_data.system.memory
        mem.total_kb = to_number(mem.total_kb) or 0
        mem.total_mb = to_number(mem.total_mb) or 0
        mem.used_kb = to_number(mem.used_kb) or 0
        mem.used_mb = to_number(mem.used_mb) or 0
        mem.available_kb = to_number(mem.available_kb) or 0
        mem.available_mb = to_number(mem.available_mb) or 0
        mem.used_percent = to_number(mem.used_percent) or 0
        mem.human_readable = mem.human_readable or ""
        
        -- Tambahkan formatted human readable jika tidak ada
        if not mem.formatted then
            mem.formatted = string.format(
                "Terpakai: %d MB / %d MB (%d%%)",
                mem.used_mb,
                mem.total_mb,
                mem.used_percent
            )
        end
    end

    if status_data.system.jsholat_log then
        status_data.system.jsholat_log.lines = to_number(status_data.system.jsholat_log.lines) or 0
    end
    if status_data.system.bot_log then
        status_data.system.bot_log.lines = to_number(status_data.system.bot_log.lines) or 0
    end

    status_data.status = status_data.status or {}
    status_data.status.last_update = status_data.status.last_update or os.date("%Y-%m-%d %H:%M:%S")

    luci.http.prepare_content("application/json")
    luci.http.write_json(status_data)
end
