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
    
    -- Entry untuk mendapatkan data kota
    entry({"admin", "services", "jsholat", "get_cities"}, call("get_cities")).leaf = true
    entry({"admin", "services", "jsholat", "get_timezone"}, call("get_timezone")).leaf = true
    entry({"admin", "services", "jsholat", "get_init_data"}, call("get_init_data")).leaf = true
    
    -- Entry untuk mendapatkan status 
    entry({"admin", "services", "jsholat", "status_json"}, call("get_status_json"), nil).leaf = true
end

-- Fungsi menampilkan jadwal
function action_jadwal()
    -- Load library JSON
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

    -- Membaca nilai file_jadwal dari konfigurasi UCI
    local uci = luci.model.uci.cursor()
    local file_path = uci:get("jsholat", "schedule", "file_jadwal") or "/root/jsholat/jadwal.txt"
    
    -- Path untuk file JSON jadwal
    local json_file_path = "/root/jsholat/jadwal.json"

    -- Inisialisasi variabel
    local error_message = nil
    local jadwal = {}
    local jadwal_json = {}

    -- Fungsi untuk konversi DD-MM-YYYY ke YYYY-MM-DD
    local function convertToISODate(date_str)
        if date_str and date_str:match("%d%d%-%d%d%-%d%d%d%d") then
            local day, month, year = date_str:match("(%d%d)-(%d%d)-(%d%d%d%d)")
            return string.format("%04d-%02d-%02d", year, month, day)
        end
        return date_str
    end

    -- Fungsi untuk format tampilan (DD-MM-YYYY)
    local function formatDateForDisplay(date_str)
        if date_str and date_str:match("%d%d%d%d%-%d%d%-%d%d") then
            local year, month, day = date_str:match("(%d%d%d%d)-(%d%d)-(%d%d)")
            return string.format("%02d-%02d-%04d", day, month, year)
        elseif date_str and date_str:match("%d%d%-%d%d%-%d%d%d%d") then
            return date_str
        end
        return date_str
    end

	-- Coba baca file JSON
	local json_file = io.open(json_file_path, "r")
	if json_file then
		local json_content = json_file:read("*a")
		json_file:close()
		
		if json_content and json_content ~= "" then
			local success, json_data = pcall(json.decode, json_content)
			if success and type(json_data) == "table" then
				-- FILTER: Hanya ambil data yang valid (bukan nil dan punya gregorian_date)
				jadwal_json = {}
				for _, entry in ipairs(json_data) do
					if entry and type(entry) == "table" and entry.gregorian_date then
						table.insert(jadwal_json, entry)
					end
				end
				
				-- Konversi data JSON ke format baris untuk kompatibilitas
				for _, entry in ipairs(jadwal_json) do
					if entry.gregorian_date then
						-- entry.gregorian_date sudah dalam format DD-MM-YYYY
						local display_date = entry.gregorian_date
						local imsyak = entry.imsyak or "-"
						local subuh = entry.subuh or "-"
						local dzuhur = entry.dzuhur or "-"
						local ashar = entry.ashar or "-"
						local maghrib = entry.maghrib or "-"
						local isya = entry.isya or "-"
						
						local line = string.format("%s %s %s %s %s %s %s", 
							display_date, imsyak, subuh, dzuhur, ashar, maghrib, isya)
						table.insert(jadwal, line)
					end
				end
			else
				-- Log error parsing JSON
				luci.sys.exec("logger -t jsholat 'Error parsing JSON: " .. tostring(json_content):gsub("'", "'\\''") .. "'")
			end
		end
	end

    -- Dapatkan nama kota dari konfigurasi UCI
    local cityName = uci:get("jsholat", "schedule", "city_label") or "Kota Tidak Diketahui"

    -- Fungsi untuk membaca file last_updated.txt
    local function getLastUpdatedInfo()
        local file_path = "/usr/share/jsholat/last_updated.txt"
        local default = {
            last_updated = "Waktu tidak diketahui",
            data_source = "Sumber tidak tersedia"
        }

        local file = io.open(file_path, "r")
        if not file then
            return default
        end

        local content = file:read("*a")
        file:close()

        if #content == 0 then
            return default
        end

        local success, data = pcall(json.decode, content)
        if not success or type(data) ~= "table" then
            return default
        end

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

    -- Dapatkan tanggal hari ini dengan format yang SESUAI dengan JSON
    local today_display = os.date("%d-%m-%Y")  -- Format DD-MM-YYYY untuk display dan komparasi
    local today_iso = os.date("%Y-%m-%d")      -- Format ISO untuk keperluan lain

    -- Dapatkan bulan dan tahun
    local day, month, year = today_display:match("(%d+)-(%d+)-(%d+)")
    local monthNames = {
        "Januari", "Februari", "Maret", "April", "Mei", "Juni",
        "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    }
    local monthName = monthNames[tonumber(month)] or ""

    -- Tambahkan nama hari ke jadwal_json
    local days = {"Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}
    if jadwal_json and #jadwal_json > 0 then
        for _, entry in ipairs(jadwal_json) do
            if entry.gregorian_date then
                local d, m, y = entry.gregorian_date:match("(%d+)-(%d+)-(%d+)")
                local timestamp = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d)})
                local wday = tonumber(os.date("%w", timestamp))
                if wday == 0 then wday = 7 end
                entry.day_name = days[wday]
            end
        end
    end

    -- Fungsi validasi waktu
    local function isValidTime(time)
        return time and time:match("^%d%d:%d%d$")
    end

    -- Fungsi mendapatkan waktu sholat berikutnya dari JSON (DD-MM-YYYY)
    local function getNextPrayerTimeFromJSON()
        local now = os.time()
        local nextPrayerTime = nil
        local nextPrayerName = nil
        
        -- today_display adalah DD-MM-YYYY
        local today_display = os.date("%d-%m-%Y")
        
        -- Parse tanggal hari ini
        local current_day, current_month, current_year = today_display:match("(%d+)-(%d+)-(%d+)")
        current_day = tonumber(current_day)
        current_month = tonumber(current_month)
        current_year = tonumber(current_year)
        
        -- Cari entri hari ini (format DD-MM-YYYY)
        local today_entry = nil
        for _, entry in ipairs(jadwal_json) do
            if entry.gregorian_date == today_display then
                today_entry = entry
                break
            end
        end
        
        if today_entry then
            local prayerTimes = {
                {name = "Imsyak", time = today_entry.imsyak},
                {name = "Subuh", time = today_entry.subuh},
                {name = "Dzuhur", time = today_entry.dzuhur},
                {name = "Ashar", time = today_entry.ashar},
                {name = "Maghrib", time = today_entry.maghrib},
                {name = "Isya", time = today_entry.isya}
            }
            
            for _, prayer in ipairs(prayerTimes) do
                if isValidTime(prayer.time) then
                    local hour = tonumber(prayer.time:sub(1, 2))
                    local minute = tonumber(prayer.time:sub(4, 5))
                    local prayerTime = os.time({
                        year = current_year,
                        month = current_month,
                        day = current_day,
                        hour = hour,
                        min = minute,
                        sec = 0
                    })
                    if prayerTime > now then
                        if not nextPrayerTime or prayerTime < nextPrayerTime then
                            nextPrayerTime = prayerTime
                            nextPrayerName = prayer.name
                        end
                    end
                end
            end
        end
        
        -- Cari besok jika tidak ada
        if not nextPrayerTime then
            local tomorrow = os.date("%d-%m-%Y", os.time() + 86400)
            local tomorrow_entry = nil
            
            for _, entry in ipairs(jadwal_json) do
                if entry.gregorian_date == tomorrow then
                    tomorrow_entry = entry
                    break
                end
            end
            
            if tomorrow_entry then
                local tomorrow_day, tomorrow_month, tomorrow_year = tomorrow:match("(%d+)-(%d+)-(%d+)")
                tomorrow_day = tonumber(tomorrow_day)
                tomorrow_month = tonumber(tomorrow_month)
                tomorrow_year = tonumber(tomorrow_year)
                
                local prayerTimes = {
                    {name = "Imsyak", time = tomorrow_entry.imsyak},
                    {name = "Subuh", time = tomorrow_entry.subuh},
                    {name = "Dzuhur", time = tomorrow_entry.dzuhur},
                    {name = "Ashar", time = tomorrow_entry.ashar},
                    {name = "Maghrib", time = tomorrow_entry.maghrib},
                    {name = "Isya", time = tomorrow_entry.isya}
                }
                
                for _, prayer in ipairs(prayerTimes) do
                    if isValidTime(prayer.time) then
                        local hour = tonumber(prayer.time:sub(1, 2))
                        local minute = tonumber(prayer.time:sub(4, 5))
                        local prayerTime = os.time({
                            year = tomorrow_year,
                            month = tomorrow_month,
                            day = tomorrow_day,
                            hour = hour,
                            min = minute,
                            sec = 0
                        })
                        if not nextPrayerTime or prayerTime < nextPrayerTime then
                            nextPrayerTime = prayerTime
                            nextPrayerName = prayer.name
                        end
                    end
                end
            end
        end
        
        return nextPrayerTime, nextPrayerName
    end

    -- Fungsi mendapatkan waktu sholat berikutnya dari teks (legacy)
    local function getNextPrayerTimeLegacy()
        local now = os.time()
        local nextPrayerTime = nil
        local nextPrayerName = nil
        local today_display = os.date("%d-%m-%Y")

        for _, line in ipairs(jadwal) do
            local date, imsyak, subuh, dzuhur, ashar, maghrib, isya = line:match("(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)")
            if date == today_display then
                local d, m, y = date:match("(%d+)-(%d+)-(%d+)")
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
                        local hour = tonumber(prayer.time:sub(1, 2))
                        local minute = tonumber(prayer.time:sub(4, 5))
                        local prayerTime = os.time({
                            year = tonumber(y),
                            month = tonumber(m),
                            day = tonumber(d),
                            hour = hour,
                            min = minute,
                            sec = 0
                        })
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

        if not nextPrayerTime then
            local tomorrow = os.date("%d-%m-%Y", os.time() + 86400)
            for _, line in ipairs(jadwal) do
                local date, imsyak, subuh, dzuhur, ashar, maghrib, isya = line:match("(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)")
                if date == tomorrow then
                    local d, m, y = date:match("(%d+)-(%d+)-(%d+)")
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
                            local hour = tonumber(prayer.time:sub(1, 2))
                            local minute = tonumber(prayer.time:sub(4, 5))
                            local prayerTime = os.time({
                                year = tonumber(y),
                                month = tonumber(m),
                                day = tonumber(d),
                                hour = hour,
                                min = minute,
                                sec = 0
                            })
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

    -- Tentukan waktu sholat berikutnya
    local nextPrayerTime, nextPrayerName
    if jadwal_json and #jadwal_json > 0 then
        nextPrayerTime, nextPrayerName = getNextPrayerTimeFromJSON()
    else
        nextPrayerTime, nextPrayerName = getNextPrayerTimeLegacy()
    end

    -- Pastikan data yang dikirim ke template valid
    local template_data = {
        error_message = error_message,
        jadwal = jadwal or {},
        jadwal_json = jadwal_json or {},
        cityName = cityName or "",
        lastUpdated = lastUpdatedDisplay or "",
        today = today_display or "",          -- DD-MM-YYYY untuk display
        today_iso = today_iso or "",          -- YYYY-MM-DD untuk ISO
        monthName = monthName or "",
        year = year or "",
        nextPrayerTime = nextPrayerTime,
        nextPrayerName = nextPrayerName or ""
    }

    -- Render template
    luci.template.render("jsholat/jadwal", template_data)
end

-- Fungsi untuk menjalankan update jadwal dari tombol
function action_update()
    local uci = luci.model.uci.cursor()
    if not uci then
        local err_msg = "Gagal memuat konfigurasi UCI"
        luci.http.prepare_content("text/plain")
        luci.http.write(err_msg)
        return
    end

    -- Fungsi logging ke file
    local function log_to_file(msg, source)
        source = source or "Lua"
        local logfile = io.open("/var/log/jsholat/jadwal-update.log", "a")
        if logfile then
            logfile:write(string.format("[%s] [%s] %s\n", 
                os.date("%Y-%m-%d %H:%M:%S"), source, msg))
            logfile:close()
        end
    end

    local function log_error(msg)
        log_to_file("[ERROR] "..msg)
        return msg
    end

    local function restart_jsholat_service()
        log_to_file("Memulai restart service jsholat...", "Service")
        
        local handle = io.popen("/etc/init.d/jsholat restart >/dev/null 2>&1; echo $?")
        local exit_code = handle:read("*a"):match("%d+") or "1"
        handle:close()
        
        local proc_handle = io.popen("pgrep -f 'jsholat' | wc -l 2>/dev/null")
        local proc_count = tonumber(proc_handle:read("*a")) or 0
        proc_handle:close()
        
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

    if not ({aladhan=true, jadwalsholat=true, myquran=true, apiajimedia=true})[source] then
        response = response .. log_error("Sumber tidak valid: "..source) .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    response = response .. "Memulai update jadwal...\n"
    log_to_file("Memulai update jadwal...")
    response = response .. "Menggunakan Sumber: " .. source .. "\n"
    log_to_file("Memulai update dari sumber: "..source)

    local script_path = "/usr/bin/jadwal"
    local script_exists = nixio.fs.access(script_path, "r")
    
    log_to_file("Script path: " .. script_path)
    log_to_file("File exists: " .. tostring(script_exists))
    
    if not script_exists then
        response = response .. log_error("Script tidak ditemukan di: " .. script_path) .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    local handle, err
    if source == "aladhan" then
        handle, err = io.popen("/usr/bin/jadwal run 2>&1")
    else
        handle, err = io.popen("/usr/bin/jadwal run " .. source .. " 2>&1")
    end
    
    if not handle then
        response = response .. log_error("Gagal membuat proses: " .. (err or "unknown")) .. "\n"
        luci.http.prepare_content("text/plain")
        luci.http.write(response)
        return
    end

    local output = handle:read("*a")
    handle:close()
    
    response = response .. output
    log_to_file("Output script: " .. output)
    
    if output:match("berhasil") or output:match("success") then
        local success, restart_msg = restart_jsholat_service()
        response = response .. restart_msg .. "\n"
    end

    response = response .. "\nUpdate jadwal selesai\n"
    log_to_file("Update jadwal selesai")
    
    luci.http.prepare_content("text/plain")
    luci.http.write(response)
end

-- Fungsi untuk menampilkan log service
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
    
    if not province or province == "" then
        response.message = "Provinsi tidak dipilih"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    local file, err = io.open("/usr/share/jsholat/cities.json", "r")
    if not file then
        response.message = "File cities.json tidak ditemukan: " .. tostring(err)
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    local content = file:read("*a")
    file:close()
    
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
    
    if not data[province] then
        response.message = "Provinsi '" .. province .. "' tidak ditemukan"
        http.prepare_content("application/json")
        http.write_json(response)
        return
    end
    
    response.cities = {}
    for _, city_data in ipairs(data[province]) do
        table.insert(response.cities, {
            value = city_data.value,
            label = city_data.label
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

-- =============================================
-- FUNGSI GET_STATUS_JSON 
-- =============================================
function get_status_json()
    -- =============================================
    -- 1. LOAD MODULE DENGAN FALLBACK
    -- =============================================
    local json
    local has_jsonc, jsonc = pcall(require, "luci.jsonc")
    if has_jsonc then
        json = jsonc
        json.decode = json.decode or json.parse
        json.encode = json.encode or json.stringify
    else
        local has_json, old_json = pcall(require, "luci.json")
        if has_json then
            json = old_json
        else
            json = {
                encode = function(t) 
                    local function encode_value(v)
                        local t = type(v)
                        if t == "string" then
                            return '"' .. v:gsub('"', '\\"') .. '"'
                        elseif t == "number" or t == "boolean" then
                            return tostring(v)
                        elseif t == "table" then
                            return encode_table(v)
                        else
                            return '""'
                        end
                    end
                    
                    local function encode_table(tbl)
                        local is_array = true
                        for k in pairs(tbl) do
                            if type(k) ~= "number" then
                                is_array = false
                                break
                            end
                        end
                        
                        if is_array then
                            local parts = {}
                            for _, v in ipairs(tbl) do
                                table.insert(parts, encode_value(v))
                            end
                            return "[" .. table.concat(parts, ",") .. "]"
                        else
                            local parts = {}
                            for k, v in pairs(tbl) do
                                table.insert(parts, '"' .. k .. '":' .. encode_value(v))
                            end
                            return "{" .. table.concat(parts, ",") .. "}"
                        end
                    end
                    
                    return encode_table(t)
                end,
                decode = function(s) return {} end
            }
        end
    end
    
    -- Load modules dengan fallback
    local sys
    local has_sys, sys_mod = pcall(require, "luci.sys")
    if has_sys then
        sys = sys_mod
    else
        sys = {
            exec = function(cmd)
                local handle = io.popen(cmd .. " 2>/dev/null")
                local result = handle:read("*a")
                handle:close()
                return result:gsub("[\n\r]+$", "")
            end
        }
    end
    
    local uci
    local has_uci, uci_mod = pcall(require, "luci.model.uci")
    if has_uci then
        uci = uci_mod.cursor()
    else
        uci = {
            get = function(section, option)
                local cmd = "uci -q get " .. section .. "." .. option
                local handle = io.popen(cmd)
                local result = handle:read("*a")
                handle:close()
                return result:gsub("[\n\r]+$", "")
            end
        }
    end
    
    local nixio
    local has_nixio, nixio_mod = pcall(require, "nixio")
    if has_nixio then
        nixio = nixio_mod
    else
        nixio = {
            fs = {
                stat = function(path)
                    local handle = io.popen("test -f '" .. path .. "' && stat -c '%Y' '" .. path .. "' 2>/dev/null || echo '0'")
                    local mtime = handle:read("*a"):gsub("[\n\r]+$", "")
                    handle:close()
                    if mtime and mtime ~= "0" then
                        local mtime_num = tonumber(mtime)
                        if mtime_num then
                            return { mtime = mtime_num }
                        end
                    end
                    return nil
                end
            }
        }
    end
    
    -- =============================================
    -- 2. FUNGSI HELPER
    -- =============================================
    
    -- Fungsi konversi ke boolean
    local function to_boolean(value)
        if value == nil then return false end
        if type(value) == "boolean" then return value end
        if type(value) == "number" then return value ~= 0 end
        if type(value) == "string" then
            local lower = value:lower()
            if lower == "1" or lower == "true" or lower == "yes" or lower == "on" then
                return true
            end
            return false
        end
        return false
    end
    
    -- Fungsi safe_tonumber
    local function safe_tonumber(value, default)
        if value == nil then return default or 0 end
        if type(value) == "number" then return value end
        if type(value) == "string" then
            -- Hapus semua karakter kecuali digit, titik, dan minus
            local cleaned = value:gsub("[^%d%.%-]", "")
            if cleaned == "" or cleaned == "." or cleaned == "-" then 
                return default or 0 
            end
            -- Pastikan tidak ada titik ganda
            if cleaned:match("%.%.") then
                return default or 0
            end
            -- Pastikan minus hanya di awal
            if cleaned:match("%-") and not cleaned:match("^%-") then
                return default or 0
            end
            local num = tonumber(cleaned)
            if num then return num end
        end
        return default or 0
    end
    
    -- File operations
    local function file_exists(path)
        if not path or path == "" then return false end
        local cmd = "test -f '" .. path .. "' && echo 1 || echo 0"
        local result = sys.exec(cmd):gsub("\n", "")
        return result == "1"
    end
    
    local function get_file_size(path)
        if not file_exists(path) then return "0" end
        local cmd = "du -h '" .. path .. "' 2>/dev/null | cut -f1"
        return sys.exec(cmd):gsub("\n", "") or "0"
    end
    
    local function get_file_lines(path)
        if not file_exists(path) then return 0 end
        local cmd = "wc -l < '" .. path .. "' 2>/dev/null"
        local lines = sys.exec(cmd):gsub("\n", "")
        return safe_tonumber(lines, 0)
    end
    
    -- Format functions
    local function format_seconds(seconds)
        local num = safe_tonumber(seconds, 0)
        if num <= 0 then return "0 detik" end
        
        local days = math.floor(num / 86400)
        local hours = math.floor((num % 86400) / 3600)
        local minutes = math.floor((num % 3600) / 60)
        local secs = num % 60
        
        local parts = {}
        if days > 0 then table.insert(parts, days .. " hari") end
        if hours > 0 then table.insert(parts, hours .. " jam") end
        if minutes > 0 then table.insert(parts, minutes .. " menit") end
        if secs > 0 and days == 0 and hours == 0 then
            table.insert(parts, secs .. " detik")
        end
        
        return #parts > 0 and table.concat(parts, " ") or "0 detik"
    end
    
    -- =============================================
    -- 4. FUNGSI PROCCESS STATUS
    -- =============================================
    
    -- Fungsi untuk mendapatkan semua PID yang cocok dengan pattern
    local function get_all_pids(pattern)
        local cmd = "pgrep -f '" .. pattern .. "' 2>/dev/null | tr '\n' ' '"
        local pids_str = sys.exec(cmd):gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if pids_str == "" then return {} end
        
        local pids = {}
        for pid in pids_str:gmatch("%d+") do
            table.insert(pids, safe_tonumber(pid, 0))
        end
        return pids
    end
    
    -- Fungsi untuk membaca command line proses
    local function get_process_cmdline(pid)
        local pid_num = safe_tonumber(pid, 0)
        if pid_num <= 0 then return "" end
        
        local cmdline_file = "/proc/" .. pid_num .. "/cmdline"
        local f = io.open(cmdline_file, "r")
        if f then
            local cmdline = f:read("*a"):gsub("\0", " ")
            f:close()
            return cmdline
        end
        return ""
    end
    
    -- Fungsi untuk mendapatkan PID yang valid dengan pattern fleksibel
    local function get_valid_pid(patterns)
        -- patterns bisa string atau table of strings
        local pattern_list = {}
        if type(patterns) == "string" then
            pattern_list = { patterns }
        else
            pattern_list = patterns
        end
        
        -- Kumpulkan semua PID dari semua pattern
        local all_pids = {}
        for _, pattern in ipairs(pattern_list) do
            local pids = get_all_pids(pattern)
            for _, pid in ipairs(pids) do
                all_pids[pid] = true
            end
        end
        
        -- Konversi ke array dan urutkan descending
        local pid_array = {}
        for pid in pairs(all_pids) do
            table.insert(pid_array, pid)
        end
        table.sort(pid_array, function(a, b) return a > b end)
        
        -- Cek setiap PID dengan kill -0
        for _, pid in ipairs(pid_array) do
            local kill_check = sys.exec("kill -0 " .. pid .. " 2>/dev/null && echo 1 || echo 0"):gsub("\n", "")
            if kill_check == "1" then
                return pid
            end
        end
        
        return 0
    end
    
    -- Fungsi untuk mengecek apakah proses berjalan
    local function is_process_running(pid)
        if not pid or pid <= 0 then return false end
        local kill_check = sys.exec("kill -0 " .. pid .. " 2>/dev/null && echo 1 || echo 0"):gsub("\n", "")
        return kill_check == "1"
    end
    
    -- Fungsi untuk mendapatkan uptime proses
    local function get_process_uptime(pid)
        local pid_num = safe_tonumber(pid, 0)
        if pid_num <= 0 then return 0, "" end
        
        if not is_process_running(pid_num) then
            return 0, ""
        end
        
        local proc_dir = "/proc/" .. pid_num
        local dir_check = sys.exec("test -d " .. proc_dir .. " && echo 1 || echo 0"):gsub("\n", "")
        
        if dir_check == "1" then
            local start_time_str = sys.exec("stat -c %Y " .. proc_dir .. " 2>/dev/null || echo 0"):gsub("\n", "")
            local start_time = safe_tonumber(start_time_str, 0)
            
            if start_time > 0 then
                local now = os.time()
                local uptime = now - start_time
                local start_date = os.date("%Y-%m-%d %H:%M:%S", start_time)
                return uptime, start_date
            end
        end
        
        return 0, ""
    end
    
    local function get_process_memory(pid)
        local pid_num = safe_tonumber(pid, 0)
        if pid_num <= 0 then return 0 end
        local cmd = "grep VmRSS /proc/" .. pid_num .. "/status 2>/dev/null | awk '{print $2}'"
        local mem_kb = sys.exec(cmd):gsub("\n", "")
        return math.floor(safe_tonumber(mem_kb, 0) / 1024)
    end
    
    -- =============================================
    -- 5. AMBIL KONFIGURASI DASAR (DENGAN BOOLEAN)
    -- =============================================
    
    -- Service enabled
    local service_enabled_val = sys.exec("uci -q get jsholat.service.service || echo 1"):gsub("\n", "")
    local service_enabled = to_boolean(service_enabled_val)
    
    -- Bot config
    local bot_token = sys.exec("uci -q get jsholat.service.telegram_bot_token || echo ''"):gsub("\n", "")
    local bot_chat_id = sys.exec("uci -q get jsholat.service.telegram_chat_id || echo ''"):gsub("\n", "")
    local bot_enabled_val = sys.exec("uci -q get jsholat.service.telegram_enabled || echo 1"):gsub("\n", "")
    local bot_enabled = to_boolean(bot_enabled_val)
    
    -- Sound config
    local adzan_file = sys.exec("uci -q get jsholat.sound.sound_adzan || echo ''"):gsub("\n", "")
    local adzan_subuh_file = sys.exec("uci -q get jsholat.sound.sound_adzan_shubuh || echo ''"):gsub("\n", "")
    local imsyak_file = sys.exec("uci -q get jsholat.sound.sound_adzan_imsy || echo ''"):gsub("\n", "")
    
    local sound_enabled_val = sys.exec("uci -q get jsholat.sound.sound_enabled || echo 1"):gsub("\n", "")
    local sound_enabled = to_boolean(sound_enabled_val)
    local volume_control = sys.exec("uci -q get jsholat.sound.volume_control || echo hardware"):gsub("\n", "")
    local volume_level = safe_tonumber(sys.exec("uci -q get jsholat.sound.volume_level || echo 80"):gsub("\n", ""), 80)
    local mixer_device = sys.exec("uci -q get jsholat.sound.mixer_device || echo PCM"):gsub("\n", "")
    
    -- Reminder config
    local minutes_before = safe_tonumber(sys.exec("uci -q get jsholat.sound.reminder_before || echo 5"):gsub("\n", ""), 5)
    local reminder_sound_enabled_val = sys.exec("uci -q get jsholat.sound.reminder_sound_enabled || echo 0"):gsub("\n", "")
    local reminder_sound_enabled = to_boolean(reminder_sound_enabled_val)
    local tts_method = sys.exec("uci -q get jsholat.sound.tts_method || echo google"):gsub("\n", "")
    local murf_api_key = sys.exec("uci -q get jsholat.sound.murf_api_key || echo ''"):gsub("\n", "")
    local gemini_api_key = sys.exec("uci -q get jsholat.sound.gemini_api_key || echo ''"):gsub("\n", "")
    local gemini_model = sys.exec("uci -q get jsholat.sound.gemini_model || echo gemini-2.5-flash-preview-tts"):gsub("\n", "")
    local gemini_voice = sys.exec("uci -q get jsholat.sound.gemini_voice || echo Leda"):gsub("\n", "")
    local edge_voice = sys.exec("uci -q get jsholat.sound.edge_voice || echo id-ID-ArdiNeural"):gsub("\n", "")
    local repeat_count = safe_tonumber(sys.exec("uci -q get jsholat.sound.reminder_repeat_count || echo 3"):gsub("\n", ""), 3)
    local repeat_interval = safe_tonumber(sys.exec("uci -q get jsholat.sound.reminder_repeat_interval || echo 5"):gsub("\n", ""), 5)
    
    -- Other configs
    local ayat_enabled_val = sys.exec("uci -q get jsholat.service.ayat_enabled || echo 1"):gsub("\n", "")
    local ayat_enabled = to_boolean(ayat_enabled_val)
    local debug_enabled_val = sys.exec("uci -q get jsholat.service.debug_mode || echo 0"):gsub("\n", "")
    local debug_enabled = to_boolean(debug_enabled_val)
    
    -- Sahur enabled
    local sahur_enabled_val = sys.exec("uci -q get jsholat.sound.sahur_enabled || echo 0"):gsub("\n", "")
    local sahur_enabled = to_boolean(sahur_enabled_val)
    local sahur_time = sys.exec("uci -q get jsholat.sound.sahur_time || echo '02:30'"):gsub("\n", "")
    
    -- Tarhim enabled
    local tarhim_enabled_val = sys.exec("uci -q get jsholat.sound.tarhim_enabled || echo 0"):gsub("\n", "")
    local tarhim_enabled = to_boolean(tarhim_enabled_val)
    local tarhim_mode = sys.exec("uci -q get jsholat.sound.tarhim_mode || echo ramadhan_only"):gsub("\n", "")
    
    -- =============================================
    -- 6. FUNGSI CEK EDGE-TTS
    -- =============================================
    
    local function is_edge_installed()
        local checks = {
            "test -f /usr/bin/edge-tts",
            "test -f /usr/local/bin/edge-tts",
            "command -v edge-tts >/dev/null 2>&1",
            "which edge-tts >/dev/null 2>&1",
            "pip show edge-tts >/dev/null 2>&1",
            "pip3 show edge-tts >/dev/null 2>&1"
        }
        
        for _, cmd in ipairs(checks) do
            local result = sys.exec(cmd .. " && echo 1 || echo 0"):gsub("\n", "")
            if result == "1" then
                return true
            end
        end
        return false
    end
    
    -- =============================================
    -- 7. CEK RAMADHAN
    -- =============================================
    
    -- Cek Ramadhan
    local ramadhan_now = false
    local hijri_cache = "/tmp/jsholat_cache/hijri_date_cache.json"
    if file_exists(hijri_cache) then
        local f = io.open(hijri_cache, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local month = content:match('"month"%s*:%s*(%d+)')
            if month then
                ramadhan_now = (safe_tonumber(month, 0) == 9)
            end
        end
    end
    
    -- =============================================
    -- 8. UPDATE STATUS SERVICE & BOT
    -- =============================================
    
    -- Service jsholat - coba berbagai pattern
    local jsholat_pid = get_valid_pid({
        "/usr/bin/jsholat run",
        "jsholat run",
        "bash.*jsholat run",
        "sh.*jsholat run"
    })
    local jsholat_running = is_process_running(jsholat_pid)
    local jsholat_uptime = 0
    local jsholat_start = ""
    
    if jsholat_running and jsholat_pid > 0 then
        jsholat_uptime, jsholat_start = get_process_uptime(jsholat_pid)
    else
        jsholat_pid = 0
    end
    
    local service_data = {
        name = "jsholat",
        version = "1.7.9",
        description = "Jadwal Sholat dan Pemutar Adzan Otomatis",
        enabled = service_enabled,          -- boolean
        running = jsholat_running,          -- boolean
        pid = jsholat_pid,
        uptime = jsholat_uptime,
        uptime_human = format_seconds(jsholat_uptime),
        start_time = jsholat_start,
        log_file = "/var/log/jsholat/service.log",
        log_size = get_file_size("/var/log/jsholat/service.log"),
        log_lines = get_file_lines("/var/log/jsholat/service.log")
    }
    
    -- Bot jsholat - coba berbagai pattern
    local bot_pid = get_valid_pid({
        "/usr/bin/jsholat-bot",
        "jsholat-bot",
        "python.*jsholat-bot",
        "python3.*jsholat-bot",
        "node.*jsholat-bot",
        "bash.*jsholat-bot"
    })
    local bot_running = is_process_running(bot_pid)
    local bot_uptime = 0
    local bot_start = ""
    local bot_memory = 0
    
    if bot_running and bot_pid > 0 then
        bot_uptime, bot_start = get_process_uptime(bot_pid)
        bot_memory = get_process_memory(bot_pid)
    else
        bot_pid = 0
    end
    
    local bot_data = {
        name = "jsholat-bot",
        version = "2.7",
        enabled = bot_enabled,                               -- boolean
        running = bot_running,                               -- boolean
        configured = (bot_token ~= "" and bot_chat_id ~= ""), -- boolean
        pid = bot_pid,
        uptime = bot_uptime,
        uptime_human = format_seconds(bot_uptime),
        start_time = bot_start,
        memory_mb = bot_memory,
        log_file = "/var/log/jsholat/bot.log",
        log_size = get_file_size("/var/log/jsholat/bot.log"),
        log_lines = get_file_lines("/var/log/jsholat/bot.log"),
        has_token = (bot_token ~= ""),                        -- boolean
        has_chat_id = (bot_chat_id ~= "")                     -- boolean
    }
    
    -- =============================================
    -- 9. BENTUK KONFIGURASI DATA (DENGAN BOOLEAN)
    -- =============================================
    
    local sound_data = {
        enabled = sound_enabled,                              -- boolean
        volume_control = volume_control,
        volume_level = volume_level,
        mixer_device = mixer_device,
        adzan_file = adzan_file,
        adzan_subuh_file = adzan_subuh_file,
        imsyak_file = imsyak_file,
        adzan_exists = file_exists(adzan_file),               -- boolean
        adzan_subuh_exists = file_exists(adzan_subuh_file),   -- boolean
        imsyak_exists = file_exists(imsyak_file)              -- boolean
    }
    
    local reminder_data = {
        enabled = (minutes_before > 0),                       -- boolean
        minutes_before = minutes_before,
        sound_enabled = reminder_sound_enabled,               -- boolean
        tts_method = tts_method,
        repeat_count = repeat_count,
        repeat_interval = repeat_interval,
        murf_configured = (murf_api_key ~= ""),               -- boolean
        gemini_configured = (gemini_api_key ~= ""),           -- boolean
        gemini_model = gemini_model,
        gemini_voice = gemini_voice,
        edge_configured = is_edge_installed(),                -- boolean
        edge_voice = edge_voice,
        in_reminder_exists = file_exists("/usr/share/jsholat/sounds/in_reminder.mp3"),      -- boolean
        out_reminder_exists = file_exists("/usr/share/jsholat/sounds/out_reminder.mp3")     -- boolean
    }
    
    local sahur_reminder_file = "/usr/share/jsholat/sahur-reminder.txt"
    
    local sahur_data = {
        enabled = sahur_enabled,                              -- boolean
        time = sahur_time,
        custom_text_exists = file_exists(sahur_reminder_file), -- boolean
        custom_text_preview = (function()
            if file_exists(sahur_reminder_file) then
                local f = io.open(sahur_reminder_file, "r")
                if f then
                    local content = f:read("*l") or ""
                    f:close()
                    if #content > 50 then
                        content = content:sub(1, 50) .. "..."
                    end
                    return content
                end
            end
            return ""
        end)(),
        reminder_minutes = minutes_before,
        tts_method = tts_method
    }
    
    local tarhim_data = {
        enabled = tarhim_enabled,                             -- boolean
        mode = tarhim_mode,
        file = imsyak_file,
        file_exists = file_exists(imsyak_file),               -- boolean
        is_ramadhan_now = ramadhan_now,                       -- boolean
        tts_imsyak_behavior = (function()
            if not tarhim_enabled then return "tarhim_disabled" end
            if tarhim_mode == "always" then return "always" end
            if ramadhan_now then return "active_ramadhan" else return "inactive_non_ramadhan" end
        end)(),
        description = (function()
            if not tarhim_enabled then return "Tarhim nonaktif, notifikasi Telegram tetap berjalan" end
            if tarhim_mode == "always" then return "Tarhim selalu diputar setiap hari (termasuk TTS reminder)" end
            if ramadhan_now then return "Tarhim diputar, TTS reminder AKTIF (sedang Ramadhan)"
            else return "Tarhim diputar, TTS reminder NONAKTIF (bukan Ramadhan)" end
        end)()
    }
    
    local config_data = {
        telegram = {
            enabled = bot_enabled,                             -- boolean
            configured = (bot_token ~= "" and bot_chat_id ~= ""), -- boolean
            has_token = (bot_token ~= ""),                     -- boolean
            has_chat_id = (bot_chat_id ~= "")                  -- boolean
        },
        sound = sound_data,
        reminder = reminder_data,
        sahur = sahur_data,
        tarhim = tarhim_data,
        ayat = { 
            enabled = ayat_enabled                             -- boolean
        },
        debug = { 
            enabled = debug_enabled                            -- boolean
        }
    }
    
    -- =============================================
    -- 10. DATA LOKASI
    -- =============================================
    
    local location_data = {
        city = sys.exec("uci -q get jsholat.schedule.city_label || echo 'Tidak Diketahui'"):gsub("\n", ""),
        province = sys.exec("uci -q get jsholat.schedule.province || echo 'Tidak Diketahui'"):gsub("\n", ""),
        latitude = sys.exec("uci -q get jsholat.schedule.latitude || echo ''"):gsub("\n", ""),
        longitude = sys.exec("uci -q get jsholat.schedule.longitude || echo ''"):gsub("\n", ""),
        timezone = sys.exec("uci -q get jsholat.schedule.timezone_value || echo 'WIB'"):gsub("\n", ""),
        hijri_adjustment = safe_tonumber(sys.exec("uci -q get jsholat.schedule.hijri_adjust || echo -1"):gsub("\n", ""), -1)
    }
    
    -- =============================================
    -- 11. PARSE JADWAL SHOLAT
    -- =============================================
    
    local schedule_file = sys.exec("uci -q get jsholat.schedule.file_jadwal || echo ''"):gsub("\n", "")
    local schedule_source = sys.exec("uci -q get jsholat.schedule.source || echo 'unknown'"):gsub("\n", "")
    
    -- Source alias
    local source_alias = schedule_source
    if schedule_source == "jadwalsholat" then
        source_alias = "JadwalSholat.org"
    elseif schedule_source == "aladhan" then
        source_alias = "AlAdhan API"
    elseif schedule_source == "arina" then
        source_alias = "Arina.Id"
    elseif schedule_source == "myquran" then
        source_alias = "MyQuran API"
    elseif schedule_source == "apiajimedia" then
        source_alias = "AjiMedia API"
    end
    
    -- Tanggal
    local today = os.date("%d-%m-%Y")
    local day_names = {"Ahad", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"}
    local day_name = day_names[tonumber(os.date("%w")) + 1] or os.date("%A")
    
    local month_names = {"Januari", "Februari", "Maret", "April", "Mei", "Juni", 
                         "Juli", "Agustus", "September", "Oktober", "November", "Desember"}
    local month_name = month_names[tonumber(os.date("%m"))] or os.date("%B")
    local full_gregorian = os.date("%d") .. " " .. month_name .. " " .. os.date("%Y")
    
    -- Hijri date
    local hijri_date = ""
    if file_exists(hijri_cache) then
        local f = io.open(hijri_cache, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local day = content:match('"day"%s*:%s*(%d+)')
            local monthName = content:match('"monthName"%s*:%s*"([^"]+)"')
            local year = content:match('"year"%s*:%s*"([^"]+)"')
            if day and monthName and year then
                hijri_date = day .. " " .. monthName .. " " .. year
            end
        end
    end
    
    -- Parse jadwal
    local times = {
        imsyak = "-", subuh = "-", dzuhur = "-", 
        ashar = "-", maghrib = "-", isya = "-"
    }
    local file_format = "unknown"
    local file_valid = false
    
    if file_exists(schedule_file) then
        local cmd = "jq -r --arg t '" .. today .. "' '.[] | select(.gregorian_date==$t) | [.imsyak, .subuh, .dzuhur, .ashar, .maghrib, .isya] | @tsv' '" .. schedule_file .. "' 2>/dev/null"
        local result = sys.exec(cmd):gsub("\n", "")
        
        if result and result ~= "" then
            local parts = {}
            for part in result:gmatch("%S+") do
                table.insert(parts, part)
            end
            if #parts >= 6 then
                times.imsyak = parts[1] or "-"
                times.subuh = parts[2] or "-"
                times.dzuhur = parts[3] or "-"
                times.ashar = parts[4] or "-"
                times.maghrib = parts[5] or "-"
                times.isya = parts[6] or "-"
                file_format = "json"
                file_valid = true
            end
        end
    end
    
    -- Last updated
    local last_updated = "Tidak diketahui"
    local last_updated_file = "/usr/share/jsholat/last_updated.txt"
    if file_exists(last_updated_file) then
        local f = io.open(last_updated_file, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local updated = content:match('"last_updated"%s*:%s*"([^"]+)"')
            if updated then
                last_updated = updated
            else
                local simple_date = content:match("(%d+-%d+-%d+ %d+:%d+:%d+)")
                if simple_date then
                    last_updated = simple_date
                else
                    simple_date = content:match("(%d+-%d+-%d+)")
                    if simple_date then
                        last_updated = simple_date
                    end
                end
            end
        end
    end
    
    local schedule_data = {
        date = {
            gregorian = today,
            gregorian_full = full_gregorian,
            hijri = hijri_date,
            day_name = day_name
        },
        source = {
            id = schedule_source,
            name = source_alias
        },
        file = {
            path = schedule_file,
            format = file_format,
            valid = file_valid,           -- boolean
            last_updated = last_updated
        },
        times = times
    }
    
    -- =============================================
    -- 12. NEXT PRAYER
    -- =============================================
	
	local next_prayer_data = {
		name = "",
		time = "",
		minutes_left = 0,
		minutes_left_human = "0 detik",
		timestamp = ""
	}

	if file_valid then
		-- Baca file JSON untuk mendapatkan data lengkap
		local json_file_path = "/root/jsholat/jadwal.json"
		local jadwal_json = {}
		
		local json_file = io.open(json_file_path, "r")
		if json_file then
			local json_content = json_file:read("*a")
			json_file:close()
			
			if json_content and json_content ~= "" then
				local success, json_data = pcall(json.decode, json_content)
				if success and type(json_data) == "table" then
					-- Filter data valid
					for _, entry in ipairs(json_data) do
						if entry and type(entry) == "table" and entry.gregorian_date then
							table.insert(jadwal_json, entry)
						end
					end
				end
			end
		end
		
		-- Fungsi baru untuk next prayer dengan data JSON
		local function get_next_prayer_from_json(jadwal_json)
			if not jadwal_json or #jadwal_json == 0 then
				return nil
			end
			
			local now = os.time()
			local today = os.date("%d-%m-%Y")
			local tomorrow = os.date("%d-%m-%Y", now + 86400)
			
			-- Parse tanggal hari ini
			local cur_day, cur_month, cur_year = today:match("(%d+)-(%d+)-(%d+)")
			cur_day = tonumber(cur_day)
			cur_month = tonumber(cur_month)
			cur_year = tonumber(cur_year)
			
			local next_time = nil
			local next_name = nil
			local next_time_str = nil
			
			-- Cari di hari ini dulu
			local today_entry = nil
			for _, entry in ipairs(jadwal_json) do
				if entry.gregorian_date == today then
					today_entry = entry
					break
				end
			end
			
			if today_entry then
				local prayers = {
					{name = "Imsyak", time = today_entry.imsyak},
					{name = "Subuh", time = today_entry.subuh},
					{name = "Dzuhur", time = today_entry.dzuhur},
					{name = "Ashar", time = today_entry.ashar},
					{name = "Maghrib", time = today_entry.maghrib},
					{name = "Isya", time = today_entry.isya}
				}
				
				for _, p in ipairs(prayers) do
					if p.time and p.time ~= "-" and p.time:match("%d%d:%d%d") then
						local h = tonumber(p.time:sub(1, 2))
						local m = tonumber(p.time:sub(4, 5))
						local prayer_time = os.time({
							year = cur_year,
							month = cur_month,
							day = cur_day,
							hour = h,
							min = m,
							sec = 0
						})
						
						if prayer_time > now then
							if not next_time or prayer_time < next_time then
								next_time = prayer_time
								next_name = p.name
								next_time_str = p.time
							end
						end
					end
				end
			end
			
			-- Jika tidak ada di hari ini, ambil Imsyak besok
			if not next_time then
				local tomorrow_entry = nil
				for _, entry in ipairs(jadwal_json) do
					if entry.gregorian_date == tomorrow then
						tomorrow_entry = entry
						break
					end
				end
				
				if tomorrow_entry and tomorrow_entry.imsyak and tomorrow_entry.imsyak ~= "-" then
					local h = tonumber(tomorrow_entry.imsyak:sub(1, 2))
					local m = tonumber(tomorrow_entry.imsyak:sub(4, 5))
					local tom_day, tom_month, tom_year = tomorrow:match("(%d+)-(%d+)-(%d+)")
					
					next_time = os.time({
						year = tonumber(tom_year),
						month = tonumber(tom_month),
						day = tonumber(tom_day),
						hour = h,
						min = m,
						sec = 0
					})
					next_name = "Imsyak (besok)"
					next_time_str = tomorrow_entry.imsyak
				end
			end
			
			-- Format hasil
			if next_time then
				local diff = next_time - now
				if diff < 0 then diff = 0 end
				
				local minutes = math.floor(diff / 60)
				local hours = math.floor(diff / 3600)
				local mins = math.floor((diff % 3600) / 60)
				
				local diff_text = ""
				if hours > 0 then
					diff_text = string.format("%d jam %d menit", hours, mins)
				elseif minutes > 0 then
					diff_text = string.format("%d menit", minutes)
				else
					diff_text = string.format("%d detik", diff)
				end
				
				return {
					name = next_name,
					time = next_time_str,
					minutes_left = minutes,
					minutes_left_human = diff_text,
					timestamp = os.date("%Y-%m-%d %H:%M:%S", next_time)
				}
			end
			
			return nil
		end
		
		-- Panggil fungsi baru
		local next_prayer = get_next_prayer_from_json(jadwal_json)
		if next_prayer then
			next_prayer_data = next_prayer
		end
	end
    
	-- =============================================
	-- 13. DATA SISTEM (DENGAN FORMAT GB)
	-- =============================================

	-- Uptime sistem
	local system_uptime = 0
	local uptime_file = io.open("/proc/uptime", "r")
	if uptime_file then
		local content = uptime_file:read("*a")
		uptime_file:close()
		local uptime_str = content:match("^([%d%.]+)")
		system_uptime = safe_tonumber(uptime_str, 0)
	end

	-- Memory info
	local mem_total = 0
	local mem_available = 0
	local mem_file = io.open("/proc/meminfo", "r")
	if mem_file then
		for line in mem_file:lines() do
			if line:match("^MemTotal:") then
				local value = line:match("(%d+)")
				mem_total = safe_tonumber(value, 0)
			elseif line:match("^MemAvailable:") then
				local value = line:match("(%d+)")
				mem_available = safe_tonumber(value, 0)
			end
		end
		mem_file:close()
	end

	local mem_used = mem_total - mem_available
	if mem_used < 0 then mem_used = 0 end

	local mem_percent = 0
	if mem_total > 0 then
		mem_percent = math.floor((mem_used * 100) / mem_total)
	end

	-- ===== FORMAT MEMORY DALAM MB DAN GB =====
	local mem_human = ""
	local mem_human_gb = ""  -- Format dalam GB
	local mem_human_detailed = ""  -- Format detail dengan MB dan GB

	if mem_total > 0 then
		-- Konversi ke MB
		local used_mb = math.floor(mem_used / 1024)
		local total_mb = math.floor(mem_total / 1024)
		
		-- Format standar MB
		mem_human = used_mb .. " MB / " .. total_mb .. " MB (" .. mem_percent .. "%)"
		
		-- ===== FORMAT GB =====
		-- Konversi ke GB dengan 2 desimal
		local used_gb = mem_used / (1024 * 1024)
		local total_gb = mem_total / (1024 * 1024)
		
		-- Format dengan 2 desimal
		mem_human_gb = string.format("%.2f GB / %.2f GB (%.0f%%)", used_gb, total_gb, mem_percent)
		
		-- Format detail (MB dan GB)
		mem_human_detailed = string.format("%.2f GB (%d MB) / %.2f GB (%d MB) (%d%%)", 
			used_gb, used_mb, total_gb, total_mb, mem_percent)
	end

	-- Tambahkan juga format dalam KB untuk keperluan lain
	local mem_kb_used = mem_used
	local mem_kb_total = mem_total
	local mem_kb_available = mem_available

	-- Load average
	local load_1, load_5, load_15 = "0.00", "0.00", "0.00"
	local load_file = io.open("/proc/loadavg", "r")
	if load_file then
		local content = load_file:read("*a")
		load_file:close()
		local l1, l5, l15 = content:match("^([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
		if l1 then load_1 = l1 end
		if l5 then load_5 = l5 end
		if l15 then load_15 = l15 end
	end

	-- Hostname
	local hostname = "unknown"
	local hostname_file = io.open("/proc/sys/kernel/hostname", "r")
	if hostname_file then
		hostname = hostname_file:read("*a"):gsub("[\n\r]+$", "")
		hostname_file:close()
		if hostname == "" then hostname = "unknown" end
	end

	-- Kernel dan architecture
	local kernel = sys.exec("uname -r 2>/dev/null"):gsub("\n", "")
	if kernel == "" then kernel = "unknown" end

	local arch = sys.exec("uname -m 2>/dev/null"):gsub("\n", "")
	if arch == "" then arch = "unknown" end

	local system_data = {
		current_time = os.date("%H:%M"),
		current_datetime = os.date("%Y-%m-%d %H:%M:%S"),
		uptime = system_uptime,
		uptime_human = format_seconds(system_uptime),
		hostname = hostname,
		kernel = kernel,
		architecture = arch,
		memory = {
			-- Data dalam KB (untuk kompatibilitas)
			total_kb = mem_total,
			total_mb = math.floor(mem_total / 1024),
			used_kb = mem_used,
			used_mb = math.floor(mem_used / 1024),
			available_kb = mem_available,
			available_mb = math.floor(mem_available / 1024),
			used_percent = mem_percent,
			
			-- Format lama (MB)
			human_readable = mem_human,
			
			-- ===== FORMAT BARU DALAM GB =====
			-- Format GB sederhana
			human_readable_gb = mem_human_gb,
			
			-- Format GB dengan detail
			human_readable_detailed = mem_human_detailed,
			
			-- Data mentah dalam GB (untuk perhitungan di frontend)
			total_gb = mem_total / (1024 * 1024),
			used_gb = mem_used / (1024 * 1024),
			available_gb = mem_available / (1024 * 1024),
			
			-- Data dalam MB (untuk fleksibilitas)
			total_mb_float = mem_total / 1024,
			used_mb_float = mem_used / 1024,
			available_mb_float = mem_available / 1024,
			
			-- Status apakah memori > 1GB (untuk menentukan format display)
			is_large_memory = (mem_total > (1024 * 1024))  -- true jika > 1GB
		},
		load_average = {
			["1min"] = load_1,
			["5min"] = load_5,
			["15min"] = load_15
		}
	}
    
    -- =============================================
    -- 14. GABUNGKAN SEMUA DATA
    -- =============================================
    
    local status_data = {
        service = service_data,
        bot = bot_data,
        config = config_data,
        location = location_data,
        schedule = schedule_data,
        next_prayer = next_prayer_data,
        system = system_data,
        status = {
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            healthy = (service_data.running == true)  -- boolean
        }
    }
    
    -- =============================================
    -- 15. CACHE DAN RESPONSE
    -- =============================================
    
    -- Simpan ke cache
    local cache_file = "/tmp/luci-jsholat-cache.json"
    local cache_f = io.open(cache_file, "w")
    if cache_f then
        cache_f:write(json.encode(status_data))
        cache_f:close()
    end
    
    -- Kirim response
    luci.http.prepare_content("application/json")
    luci.http.write_json(status_data)
end