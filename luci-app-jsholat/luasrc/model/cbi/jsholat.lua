-- /usr/lib/lua/luci/model/cbi/jsholat.lua

local m, s, o

m = Map("jsholat", "Pengaturan Jadwal Sholat")
m.title = translate("Pengaturan Jadwal Shalat")
m.description = translate("Untuk mengatur jadwal sholat dan mengatur suara adzan.<br><br>"..
"1. Pengaturan Jadwal: Untuk mengatur jadwal sholat berdasarkan nama kota/wilayah beserta durasi setiap jadwal diperbarui.<br>" ..
"2. Lihat Jadwal: Untuk melihat jadwal sholat saat ini.<br>"..
"3. Pengaturan Suara: Untuk mengatur penyimpanan jadwal, mengatur suara adzan.<br>"..
"4. Pengaturan Service: Untuk mengatur jalannya aplikasi pembaruan jadwal dan pemutar suara waktu adzan.<br>"..
[[<br/><br/><a href="https://github.com/ajisetiawan716" target="_blank">Powered by ajisetiawan716</a>]])

-- Load data kota dari JSON
-- Load modul JSON (luci.jsonc diutamakan, fallback ke luci.json)
local json
do
    local ok, mod = pcall(require, "luci.jsonc")
    if ok then
        json = mod
        -- Gunakan parse jika decode tidak tersedia
        json.decode = json.decode or json.parse
    else
        json = require("luci.json")  -- fallback lama
    end
end

local uci = luci.model.uci.cursor()
local city_data = {}
local city_value = {}
local city_timezone_map = {}

local file = io.open("/usr/share/jsholat/cities.json", "r")
if file then
    local content = file:read("*a")
    file:close()
    local status, data = pcall(json.decode, content)
    if status then
        city_data = data
        -- Bangun mapping timezone
        for prov, cities in pairs(city_data) do
            for _, city in ipairs(cities) do
                city_timezone_map[city.value] = city.timezone
            end
        end
    else
        m.description = m.description .. [[<br><div class="alert-message error">Error parsing cities.json</div>]]
    end
else
    m.description = m.description .. [[<br><div class="alert-message error">File cities.json tidak ditemukan</div>]]
end


-- Section untuk pengaturan jadwal
s = m:section(TypedSection, "global", "Pengaturan Jadwal")
s.anonymous = true
s.addremove = false

-- Opsi untuk memilih sumber jadwal
local source = s:option(ListValue, "source", "Sumber Jadwal Sholat")
source:value("jadwalsholat", "JadwalSholat.Org")
source:value("myquran", "Bimas Islam Kemenag/MyQuran.com")
source:value("aladhan", "Aladhan")
source:value("apiajimedia", "AjiMedia API")
source.default = "jadwalsholat"

-- Pilih provinsi
local provinsi_list = {}
for p in pairs(city_data) do
    table.insert(provinsi_list, p)
end
table.sort(provinsi_list)

prov = s:option(ListValue, "province", "Provinsi")
for _, p in ipairs(provinsi_list) do
    prov:value(p)
end

-- Pilih kota
city = s:option(ListValue, "city", "Kota/Kabupaten")
city.template = "jsholat/city_select"
city.rmempty = false
city.forcewrite = true
city.datatype = "string"

-- Field tersembunyi untuk kota (value)
local city_hidden = s:option(Value, "city_value", "")
city_hidden.template = "cbi/value_hidden"
city_hidden.rmempty = false

-- Field tersembunyi untuk label dan timezone
local city_label = s:option(Value, "city_label", "")
city_label.template = "cbi/value_hidden"
city_label.rmempty = false

local tz_hidden = s:option(Value, "timezone_value", "")
tz_hidden.template = "cbi/value_hidden"
tz_hidden.rmempty = false


-- Opsi untuk negara
country = s:option(Value, "country", "Negara")
country.datatype = "string"
country.placeholder = "Contoh: Indonesia"
country.default = "Indonesia"
country.readonly = true

-- Opsi untuk metode perhitungan
method = s:option(ListValue, "method", "Metode Perhitungan")
method:value("20", "KEMENAG RI")
method:value("2", "ISNA")
method:value("3", "MWL")
method:value("4", "Makkah")
method:value("5", "Egypt")
method.default = "20"
method:depends("source","aladhan")

-- Opsi untuk interval pembaruan
interval = s:option(ListValue, "interval", "Pembaruan Jadwal")
interval:value("0", "Tidak Otomatis")
interval:value("3600", "Setiap Jam") 
interval:value("86400", "Setiap Hari")
interval:value("604800", "Setiap Minggu")
interval:value("monthly_special", "Setiap Bulan")
interval.default = "3600"

interval.description = [[
<b>Pembaruan untuk Bulanan:</b><br>
• Tanggal 1 pukul 00:00 WIB<br>
• Bulan: Januari – Desember (setiap bulan)<br>
• Skrip dijalankan otomatis untuk tiap bulan pada awal hari pertama (tengah malam).
]]


-- Tombol untuk menjalankan pembaruan manual
button = s:option(Button, "_button", "")
button.inputtitle = "Perbarui Jadwal Sekarang"
button.inputstyle = "apply"
button:depends("source", "jadwalsholat")
button:depends("source", "aladhan")
button:depends("source", "myquran")
button:depends("source", "apiajimedia")

output = s:option(DummyValue, "_output", "Output Pembaruan")
output.template = "jsholat/output"

-- Section untuk pengaturan file suara
s2 = m:section(TypedSection, "global", "Pengaturan File Suara")
s2.anonymous = true
s2.addremove = false

-- Opsi untuk mengaktifkan/menonaktifkan suara adzan
sound_enabled = s2:option(ListValue, "sound_enabled", "Aktifkan Suara Adzan")
sound_enabled:value("1", "Aktif")
sound_enabled:value("0", "Nonaktif")
sound_enabled.default = "1"
sound_enabled.description = "Mengaktifkan atau menonaktifkan pemutaran suara adzan"

-- Opsi untuk kontrol volume hardware
volume_control = s2:option(ListValue, "volume_control", "Mode Kontrol Volume")
volume_control:value("hardware", "Gunakan Volume Sistem (amixer)")
volume_control:value("none", "Tidak Ada Kontrol Volume")
volume_control.default = "hardware"
volume_control:depends("sound_enabled", "1")

-- Opsi level volume untuk hardware
volume_level = s2:option(ListValue, "volume_level", "Level Volume (0-100%)")
for i=0,10 do
    volume_level:value(tostring(i*10), tostring(i*10).."%")  -- Perbaikan: konversi ke string
end
volume_level.default = "80"
volume_level:depends("volume_control", "hardware")

-- Opsi mixer device (untuk hardware volume)
mixer_device = s2:option(Value, "mixer_device", "Nama Device Audio")
mixer_device.default = "Speaker"
mixer_device.placeholder = "Contoh: PCM, Master, Speaker"
mixer_device.description = "Contoh: PCM, Master, Speaker (Default: Speaker)"
mixer_device:depends("volume_control", "hardware")

file_jadwal = s2:option(Value, "file_jadwal", "File Jadwal")
file_jadwal.datatype = "file"
file_jadwal.placeholder = "/root/jsholat/jadwal.txt"

sound_adzan = s2:option(Value, "sound_adzan", "File Suara Adzan")
sound_adzan.datatype = "file"
sound_adzan.placeholder = "/root/jsholat/adzan.mp3"

sound_adzan_shubuh = s2:option(Value, "sound_adzan_shubuh", "File Suara Adzan Subuh")
sound_adzan_shubuh.datatype = "file"
sound_adzan_shubuh.placeholder = "/root/jsholat/adzan_subuh.mp3"

sound_adzan_imsy = s2:option(Value, "sound_adzan_imsy", "File Suara Imsak")
sound_adzan_imsy.datatype = "file"
sound_adzan_imsy.placeholder = "/root/jsholat/tahrim.mp3"

-- Opsi untuk pengingat sebelum waktu sholat
reminder_before = s2:option(ListValue, "reminder_before", "Pengingat Sebelum Sholat")
for i=5,15 do
    reminder_before:value(i, tostring(i).." menit")
end
reminder_before.default = "5"
reminder_before.description = "Waktu pengingat sebelum masuk waktu sholat"

lihat_jadwal = s2:option(Button, "_jadwal", "Lihat Jadwal")
lihat_jadwal.inputtitle = "Lihat Jadwal Sholat"
lihat_jadwal.inputstyle = "view"
function lihat_jadwal.write(self, section)
    luci.http.redirect(luci.dispatcher.build_url("admin/services/jsholat/jadwal"))
end

-- Section untuk pengaturan service
s3 = m:section(TypedSection, "global", "Pengaturan Service")
s3.anonymous = true
s3.addremove = false


-- Opsi untuk mengaktifkan/menonaktifkan service
service_enabled = s3:option(ListValue, "service", "Status Service Jsholat")
service_enabled:value("1", "Aktif")
service_enabled:value("0", "Nonaktif")
service_enabled.default = "1"

function service_enabled.write(self, section, value)
    self.map:set(section, "service", value)
    if value == "0" then
        os.execute("/etc/init.d/jsholat stop >/dev/null 2>&1")
    else
        os.execute("/etc/init.d/jsholat start >/dev/null 2>&1")
    end
end

-- Opsi untuk mengaktifkan/menonaktifkan notifikasi Telegram
telegram_enabled = s3:option(ListValue, "telegram_enabled", "Notifikasi Telegram")
telegram_enabled:value("1", "Aktif")
telegram_enabled:value("0", "Nonaktif")
telegram_enabled.default = "1"

-- Opsi untuk token bot Telegram
telegram_bot_token = s3:option(Value, "telegram_bot_token", "Token Bot Telegram")
telegram_bot_token.datatype = "string"
telegram_bot_token.password = false
telegram_bot_token.placeholder = "Masukkan token bot Telegram"
telegram_bot_token:depends("telegram_enabled", "1")

-- Opsi untuk chat ID Telegram
telegram_chat_id = s3:option(Value, "telegram_chat_id", "Chat ID Telegram")
telegram_chat_id.datatype = "string"
telegram_chat_id.placeholder = "Masukkan chat ID Telegram"
telegram_chat_id:depends("telegram_enabled", "1")

-- Fungsi untuk memeriksa nilai interval jadwal
function check_interval()
    local handle = io.popen("uci get jsholat.setting.interval")
    local interval = tonumber(handle:read("*a"))
    handle:close()
    return interval
end

-- Definisikan pesan konfirmasi di awal
restart_jadwal_msg = s3:option(DummyValue, "_restart_jadwal_msg", "Pesan Restart Jadwal")
restart_jadwal_msg.value = "Belum ada perintah.."

-- Cek nilai interval sebelum membuat tombol
if check_interval() ~= 0 then
    -- Tombol untuk restart service jadwal
    restart_jadwal = s3:option(Button, "_restart_jadwal", "Restart Service Jadwal")
    restart_jadwal.inputtitle = "Restart Service Jadwal"
    restart_jadwal.inputstyle = "apply"

    function restart_jadwal.write(self, section)
        os.execute("/etc/init.d/jadwal restart")
        restart_jadwal_msg.value = "Service Jadwal telah di-restart pada " .. os.date("%Y-%m-%d %H:%M:%S")
    end
else
    restart_jadwal_msg.value = "Restart jadwal dinonaktifkan"
end

-- Tombol untuk restart service jsholat
restart_jsholat = s3:option(Button, "_restart_jsholat", "Restart Service Jsholat")
restart_jsholat.inputtitle = "Restart Service Jsholat"
restart_jsholat.inputstyle = "apply"
function restart_jsholat.write(self, section)
    os.execute("/etc/init.d/jsholat restart")
    restart_jsholat_msg.value = "Service Jsholat telah di-restart pada " .. os.date("%Y-%m-%d %H:%M:%S")
end

-- Pesan konfirmasi
restart_jsholat_msg = s3:option(DummyValue, "_restart_jsholat_msg", "Pesan Restart Jsholat")
restart_jsholat_msg.value = "Belum ada perintah.."

-- Status service jadwal
status_jadwal = s3:option(DummyValue, "_status_jadwal", "Status Service Jadwal")
status_jadwal.template = "jsholat/status_jadwal"
status_jadwal.description = "Status: "

-- Status service jsholat
status_jsholat = s3:option(DummyValue, "_status_jsholat", "Status Service Jsholat")
status_jsholat.template = "jsholat/status_jsholat"
status_jsholat.description = "Status: "

-- Fungsi untuk menampilkan status cron job jadwal
cron_status = s3:option(DummyValue, "_cron_status", "Status Cronjob Jadwal")
cron_status.rawhtml = true

function cron_status.cfgvalue(self)
    local cmd = "/usr/bin/jadwal-update.sh"
    local cron_job = luci.sys.exec("crontab -l | grep '"..cmd.."'")
    
    if cron_job and #cron_job > 0 then
        return '<span class="label label-success">AKTIF</span>'
    else
        return '<span class="label label-danger">NONAKTIF</span>'
    end
end

-- Opsi untuk debug mode
debug_mode = s3:option(ListValue, "debug_mode", "Mode Debug")
debug_mode:value("1", "Aktif")
debug_mode:value("0", "Nonaktif")
debug_mode.default = "0"
debug_mode.description = "Mode debug untuk logging lebih detail"

-- Fungsi validasi untuk provinsi dan kota
-- Gantikan seluruh bagian on_save dan on_apply dengan ini:


-- Hapus seluruh manipulasi UCI langsung dari fungsi city.write
-- Fungsi khusus untuk menangani perubahan kota
-- Ganti seluruh fungsi city.write dengan ini:
function city.write(self, section, value)
    -- Dapatkan nilai terbaru dari form
    local city_val = luci.http.formvalue("cbid.jsholat."..section..".city_value") or value
    local province_val = luci.http.formvalue("cbid.jsholat."..section..".province")
    local tz_val = luci.http.formvalue("cbid.jsholat."..section..".timezone_value")
    local label_val = luci.http.formvalue("cbid.jsholat."..section..".city_label")

    -- Simpan semua nilai sekaligus
    self.map:set(section, "city", city_val)
    self.map:set(section, "city_label", label_val)
    self.map:set(section, "timezone", tz_val)
    
    return true
end

-- Ganti m.on_save dengan ini:
function m.on_save(self)
    -- Restart service setelah simpan
    os.execute("/etc/init.d/jsholat restart >/dev/null 2>&1")
    return true
end

return m