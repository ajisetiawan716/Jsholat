-- /usr/lib/lua/luci/model/cbi/jsholat.lua
-- Jsholat Luci Setting Management 
-- (C) 2025-2026 Jsholat - @ajisetiawan716

local m, s, o

m = Map("jsholat", "Pengaturan Jadwal Sholat")
m.title = translate("Pengaturan Jadwal Shalat")
m.description = translate("Untuk mengatur jadwal sholat dan mengatur suara adzan.<br><br>"..
"1. 🗓️ Pengaturan Jadwal: Untuk mengatur jadwal sholat berdasarkan nama kota/wilayah beserta durasi setiap jadwal diperbarui.<br>" ..
"2. 📊 Status Detail: Untuk melihat detail status aplikasi.<br>"..
"3. 👁️ Lihat Jadwal: Untuk melihat jadwal sholat saat ini.<br>"..
"4. 🔊 Pengaturan Suara: Untuk mengatur penyimpanan jadwal, mengatur suara adzan, tarhim/imsak, dan pengingat TTS.<br>"..
"5. ⚙️ Pengaturan Service: Untuk mengatur jalannya aplikasi pembaruan jadwal, pemutar suara waktu adzan, serta manajemen bot Telegram.<br>"..
[[<br/><br/><a href="https://github.com/ajisetiawan716" target="_blank">⚡ Powered by ajisetiawan716</a>]])

-- Load data kota dari JSON
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

local uci = luci.model.uci.cursor()
local city_data = {}
local city_timezone_map = {}

local file = io.open("/usr/share/jsholat/cities.json", "r")
if file then
    local content = file:read("*a")
    file:close()
    local status, data = pcall(json.decode, content)
    if status then
        city_data = data
        for prov, cities in pairs(city_data) do
            for _, city in ipairs(cities) do
                city_timezone_map[city.value] = city.timezone
            end
        end
    else
        m.description = m.description .. [[<br><div class="alert-message error">❌ Error parsing cities.json</div>]]
    end
else
    m.description = m.description .. [[<br><div class="alert-message error">❌ File cities.json tidak ditemukan</div>]]
end

-- ==================== SECTION SCHEDULE ====================
s = m:section(TypedSection, "schedule", "🗓️ Pengaturan Jadwal")
s.anonymous = true
s.addremove = false

-- Opsi untuk memilih sumber jadwal
local source = s:option(ListValue, "source", "🌐 Sumber Jadwal Sholat")
source:value("jadwalsholat", "📋 JadwalSholat.Org")
source:value("arina", "🟣 Arina.Id")
source:value("equranid", "📖 Equran.Id")
source:value("myquran", "🕌 MyQuran.com/Bimas Islam Kemenag")
source:value("aladhan", "🌍 Aladhan")
source:value("apiajimedia", "⚡ AjiMedia API")
source.default = "jadwalsholat"

-- Pilih provinsi
local provinsi_list = {}
for p in pairs(city_data) do
    table.insert(provinsi_list, p)
end
table.sort(provinsi_list)

prov = s:option(ListValue, "province", "📍 Provinsi")
for _, p in ipairs(provinsi_list) do
    prov:value(p)
end

-- Pilih kota
city = s:option(DummyValue, "city", "🏙️ Kota/Kabupaten")
city.template = "jsholat/city_select"
city.rmempty = true
city.forcewrite = false
city.datatype = "string"

-- Field tersembunyi untuk kota (value)
local city_hidden = s:option(Value, "city_value", "")
city_hidden.template = "cbi/value_hidden"
city_hidden.rmempty = false
city_hidden.forcewrite = false

-- Field tersembunyi untuk label dan timezone
local city_label = s:option(Value, "city_label", "")
city_label.template = "cbi/value_hidden"
city_label.rmempty = false
city_label.forcewrite = false

local tz_hidden = s:option(Value, "timezone_value", "")
tz_hidden.template = "cbi/value_hidden"
tz_hidden.rmempty = false
tz_hidden.forcewrite = false

-- Opsi untuk adjust Hijriyah
hijri_adjust = s:option(ListValue, "hijri_adjust", "📅 Koreksi Tanggal Hijriyah")
hijri_adjust:value("-2", "➖2 hari (koreksi mundur 2 hari)")
hijri_adjust:value("-1", "➖1 hari (koreksi mundur 1 hari)")
hijri_adjust:value("0", "0 (tanpa koreksi)")
hijri_adjust:value("1", "➕1 hari (koreksi maju 1 hari)")
hijri_adjust:value("2", "➕2 hari (koreksi maju 2 hari)")
hijri_adjust.default = "-1"
hijri_adjust.description = "Penyesuaian jika tanggal Hijriyah tampil lebih awal/lambat. Default: -1"

-- Opsi untuk negara
country = s:option(Value, "country", "🌏 Negara")
country.datatype = "string"
country.placeholder = "Contoh: Indonesia"
country.default = "Indonesia"
country.readonly = true

-- Opsi untuk metode perhitungan
method = s:option(ListValue, "method", "🧮 Metode Perhitungan")
method:value("20", "🇮🇩 KEMENAG RI")
method:value("2", "🇺🇸 ISNA")
method:value("3", "🌐 MWL")
method:value("4", "🇸🇦 Makkah")
method:value("5", "🇪🇬 Egypt")
method.default = "20"
method:depends("source","aladhan")

-- Opsi untuk interval pembaruan
interval = s:option(ListValue, "interval", "🔄 Pembaruan Jadwal")
interval:value("0", "❌ Tidak Otomatis")
interval:value("3600", "⏰ Setiap Jam") 
interval:value("86400", "📆 Setiap Hari")
interval:value("604800", "📅 Setiap Minggu")
interval:value("monthly_special", "🌙 Setiap Bulan")
interval.default = "3600"

interval.description = [[
<b>🔄 Pembaruan untuk Bulanan:</b><br>
• Tanggal 1 pukul 00:00 WIB<br>
• Bulan: Januari – Desember (setiap bulan)<br>
• Skrip dijalankan otomatis untuk tiap bulan pada awal hari pertama (tengah malam).
]]

file_jadwal = s:option(Value, "file_jadwal", "📁 File Jadwal")
file_jadwal.datatype = "file"
file_jadwal.placeholder = "/root/jsholat/jadwal.txt"

-- Tombol untuk menjalankan pembaruan manual
button = s:option(Button, "_button", "")
button.inputtitle = "🔄 Perbarui Jadwal Sekarang"
button.inputstyle = "apply"
button:depends("source", "jadwalsholat")
button:depends("source", "aladhan")
button:depends("source", "myquran")
button:depends("source", "apiajimedia")

output = s:option(DummyValue, "_output", "📋 Output Pembaruan")
output.template = "jsholat/output"

-- ==================== SECTION SOUND ====================
s2 = m:section(TypedSection, "sound", "🔊 Pengaturan Suara")
s2.anonymous = true
s2.addremove = false

-- Opsi untuk mengaktifkan/menonaktifkan suara adzan
sound_enabled = s2:option(ListValue, "sound_enabled", "🕌 Aktifkan Suara Adzan")
sound_enabled:value("1", "✅ Aktif")
sound_enabled:value("0", "❌ Nonaktif")
sound_enabled.default = "1"
sound_enabled.description = "Mengaktifkan atau menonaktifkan pemutaran suara adzan"

-- Opsi untuk kontrol volume hardware
volume_control = s2:option(ListValue, "volume_control", "🎚️ Mode Kontrol Volume")
volume_control:value("hardware", "🔊 Gunakan Volume Sistem (amixer)")
volume_control:value("none", "🔇 Tidak Ada Kontrol Volume")
volume_control.default = "hardware"
volume_control:depends("sound_enabled", "1")

-- Opsi level volume untuk hardware
volume_level = s2:option(ListValue, "volume_level", "🔊 Level Volume (0-100%)")
for i=0,10 do
    volume_level:value(tostring(i*10), tostring(i*10).."%")
end
volume_level.default = "60"
volume_level:depends("volume_control", "hardware")

-- Opsi mixer device (untuk hardware volume)
mixer_device = s2:option(ListValue, "mixer_device", "🎛️ Nama Device Audio")
mixer_device:value("Speaker", "📢 Speaker")
mixer_device:value("PCM", "💿 PCM")
mixer_device:value("Master", "🎵 Master")
mixer_device.description = "Contoh: PCM, Master, Speaker (Default: Speaker)"
mixer_device:depends("volume_control", "hardware")

-- Opsi metode TTS
tts_method = s2:option(ListValue, "tts_method", "🤖 Metode Text-to-Speech (TTS)")
tts_method:value("gemini", "🤖 Gemini AI TTS") 
tts_method:value("google", "🌐 Google Translate")
tts_method:value("edge", "📘 Edge-TTS")
tts_method:value("espeak", "🗣️ eSpeak")
tts_method:value("murf", "🎙️ Murf.ai") 
tts_method.default = "google"
tts_method.description = "Metode yang digunakan untuk suara pengingat sholat"

-- ==================== GEMINI AI TTS SETTINGS ====================
-- API Key Gemini
gemini_api_key = s2:option(Value, "gemini_api_key", "🔑 API Key Gemini AI")
gemini_api_key.datatype = "string"
gemini_api_key.password = true
gemini_api_key.placeholder = "Masukkan API key Gemini AI (mulai dengan AIza...)"
gemini_api_key.description = [[
Dapatkan API key dari Google AI Studio: <a href="https://aistudio.google.com/app/apikey" target="_blank">disini.</a>]]

-- Model Gemini TTS
gemini_model = s2:option(ListValue, "gemini_model", "🧠 Model Gemini TTS")
gemini_model.datatype = "string"

gemini_model:value("gemini-2.5-flash-preview-tts", "Gemini 2.5 Flash (Preview TTS) ⚡ Cepat & Ringan")
gemini_model:value("gemini-2.5-pro-preview-tts", "Gemini 2.5 Pro (Preview TTS) 🧠 Lebih Natural & Stabil")

gemini_model.default = "gemini-2.5-flash-preview-tts"
gemini_model.description = "Pilih model Gemini yang digunakan untuk Text-to-Speech"


-- Voice Gemini TTS (30 Voice Lengkap dengan Gender)
gemini_voice = s2:option(ListValue, "gemini_voice", "🎤 Voice Gemini TTS")
gemini_voice.description = "Pilih karakter suara untuk Gemini TTS (👨 Pria / 👩 Wanita)"

-- ===== VOICE PRIA (16) =====
gemini_voice:value("Puck", "👨 Puck - Upbeat (Bersemangat)")
gemini_voice:value("Charon", "👨 Charon - Informative (Informatif)")
gemini_voice:value("Fenrir", "👨 Fenrir - Excitable (Bersemangat)")
gemini_voice:value("Achird", "👨 Achird - Friendly (Ramah)")
gemini_voice:value("Zubenelgenubi", "👨 Zubenelgenubi - Casual (Santai)")
gemini_voice:value("Algieba", "👨 Algieba - Smooth (Halus)")
gemini_voice:value("Alnilam", "👨 Alnilam - Firm (Tegas)")
gemini_voice:value("Orus", "👨 Orus - Firm (Tegas)")
gemini_voice:value("Enceladus", "👨 Enceladus - Breathy (Berhembus)")
gemini_voice:value("Iapetus", "👨 Iapetus - Clear (Jelas)")
gemini_voice:value("Umbriel", "👨 Umbriel - Easy-going (Santai)")
gemini_voice:value("Algenib", "👨 Algenib - Gravelly (Berat)")
gemini_voice:value("Rasalgethi", "👨 Rasalgethi - Informative (Informatif)")
gemini_voice:value("Schedar", "👨 Schedar - Even (Tenang/Stabil)")
gemini_voice:value("Sadachbia", "👨 Sadachbia - Lively (Ceria)")
gemini_voice:value("Sadaltager", "👨 Sadaltager - Knowledgeable (Berpengetahuan)")

-- ===== VOICE WANITA (14) =====
gemini_voice:value("Zephyr", "👩 Zephyr - Bright (Cerah)")
gemini_voice:value("Kore", "👩 Kore - Firm (Tegas)")
gemini_voice:value("Leda", "👩 Leda - Youthful (Muda)")
gemini_voice:value("Aoede", "👩 Aoede - Breezy (Ringan)")
gemini_voice:value("Callirrhoe", "👩 Callirrhoe - Easy-going (Santai)")
gemini_voice:value("Autonoe", "👩 Autonoe - Bright (Cerah)")
gemini_voice:value("Despina", "👩 Despina - Smooth (Halus)")
gemini_voice:value("Erinome", "👩 Erinome - Clear (Jelas)")
gemini_voice:value("Gacrux", "👩 Gacrux - Mature (Dewasa/Berwibawa)")
gemini_voice:value("Laomedeia", "👩 Laomedeia - Upbeat (Bersemangat)")
gemini_voice:value("Achernar", "👩 Achernar - Soft (Lembut)")
gemini_voice:value("Pulcherrima", "👩 Pulcherrima - Forward (Tegas/Maju)")
gemini_voice:value("Vindemiatrix", "👩 Vindemiatrix - Gentle (Lembut)")
gemini_voice:value("Sulafat", "👩 Sulafat - Warm (Hangat)")

-- Default voice
gemini_voice.default = "Leda"

-- ==================== MURF.AI SETTINGS ====================
-- Opsi API Key Murf.ai
murf_api_key = s2:option(Value, "murf_api_key", "🔑 API Key Murf.ai")
murf_api_key.datatype = "string"
murf_api_key.password = true
murf_api_key.placeholder = "Masukkan API key Murf.ai"
murf_api_key.description = "Dibutuhkan untuk menggunakan Murf.ai TTS"

-- ==================== EDGE-TTS SETTINGS (BARU) ====================
-- Voice Edge-TTS
edge_voice = s2:option(ListValue, "edge_voice", "🎤 Voice Edge-TTS")
edge_voice:value("id-ID-ArdiNeural", "🗣️ Ardi (Indonesia - Pria)")
edge_voice:value("id-ID-GadisNeural", "👩 Gadis (Indonesia - Wanita)")
edge_voice:value("jv-ID-DimasNeural", "👨‍🦰 Dimas (Jawa - Pria)")
edge_voice:value("jv-ID-SitiNeural", "👩‍🦰 Siti (Jawa - Wanita)")
edge_voice.default = "id-ID-ArdiNeural"
edge_voice.description = "Pilih voice untuk Edge-TTS"

-- ==================== REMINDER SETTINGS ====================
-- Opsi untuk mengaktifkan/menonaktifkan suara reminder
reminder_sound_enabled = s2:option(ListValue, "reminder_sound_enabled", "⏰ Aktifkan Suara Pengingat (TTS)")
reminder_sound_enabled:value("1", "✅ Aktif")
reminder_sound_enabled:value("0", "❌ Nonaktif")
reminder_sound_enabled.default = "0"
reminder_sound_enabled.description = "Mengaktifkan suara pengingat menggunakan TTS sebelum waktu sholat"

-- Opsi untuk pengingat sebelum waktu sholat
reminder_before = s2:option(ListValue, "reminder_before", "⏱️ Durasi Pengingat Sebelum Sholat")
reminder_before:value("0", "❌ Nonaktif")
for i=5,15,5 do
    reminder_before:value(tostring(i), tostring(i).." menit")
end
reminder_before.default = "15"
reminder_before.description = "Waktu pengingat sebelum masuk waktu sholat (0 = nonaktif)"

-- Opsi jumlah pengulangan reminder
reminder_repeat_count = s2:option(ListValue, "reminder_repeat_count", "🔁 Jumlah Pengulangan Pengingat")
for i=1,5 do
    reminder_repeat_count:value(tostring(i), tostring(i).." kali")
end
reminder_repeat_count.default = "3"
reminder_repeat_count.description = "Jumlah pengulangan suara pengingat"
reminder_repeat_count:depends("reminder_before", "5")
reminder_repeat_count:depends("reminder_before", "10")
reminder_repeat_count:depends("reminder_before", "15")

-- Opsi interval pengulangan reminder
reminder_repeat_interval = s2:option(ListValue, "reminder_repeat_interval", "⏲️ Interval Pengulangan")
reminder_repeat_interval:value("3", "3 detik")
reminder_repeat_interval:value("5", "5 detik")
reminder_repeat_interval:value("7", "7 detik")
reminder_repeat_interval:value("10", "10 detik")
reminder_repeat_interval:value("15", "15 detik")
reminder_repeat_interval.default = "5"
reminder_repeat_interval.description = "Jeda waktu antar pengulangan suara pengingat"
reminder_repeat_interval:depends("reminder_before", "5")
reminder_repeat_interval:depends("reminder_before", "10")
reminder_repeat_interval:depends("reminder_before", "15")

-- ==================== TARHIM (IMSAK) SETTINGS ====================
-- Opsi untuk mengaktifkan/menonaktifkan suara tarhim
tarhim_enabled = s2:option(ListValue, "tarhim_enabled", "🌙 Aktifkan Suara Tarhim/Imsak")
tarhim_enabled:value("1", "✅ Aktif")
tarhim_enabled:value("0", "❌ Nonaktif")
tarhim_enabled.default = "0"
tarhim_enabled.description = "Mengaktifkan pemutaran suara tarhim pada waktu imsak"

-- Opsi mode tarhim
tarhim_mode = s2:option(ListValue, "tarhim_mode", "📅 Mode Pemutaran Tarhim")
tarhim_mode:value("ramadhan_only", "🌙 Tarhim selalu diputar, TTS reminder HANYA saat Ramadhan")
tarhim_mode:value("always", "📆 Selalu (Setiap Hari, termasuk TTS reminder)")
tarhim_mode.default = "ramadhan_only"
tarhim_mode.description = [[
<b>Penjelasan Mode:</b><br>
• <b>ramadhan_only</b>: Tarhim selalu diputar setiap hari, namun suara TTS reminder imsyak hanya aktif saat Ramadhan<br>
• <b>always</b>: Tarhim dan TTS reminder imsyak selalu diputar setiap hari
]]
tarhim_mode:depends("tarhim_enabled", "1")

-- ==================== SAHUR SETTINGS ====================
sahur_enabled = s2:option(ListValue, "sahur_enabled", "🌙 Aktifkan Alarm Sahur Ramadhan")
sahur_enabled:value("1", "✅ Aktif")
sahur_enabled:value("0", "❌ Nonaktif")
sahur_enabled.default = "0"
sahur_enabled.description = "Mengaktifkan alarm pengingat sahur.<br>Hanya berjalan selama bulan Ramadhan."

sahur_time = s2:option(Value, "sahur_time", "⏰ Waktu Sahur")
sahur_time.datatype = "string"
sahur_time.placeholder = "Contoh: 02:30"
sahur_time.default = "02:30"
sahur_time:depends("sahur_enabled", "1")
sahur_time.description = [[
Menentukan waktu alarm sahur (format 24 jam HH:MM).<br><br>

<b>Contoh:</b> 02:30 (pukul 02 lewat 30 menit)<br>
• Alarm hanya aktif selama bulan Ramadhan<br>
• Zona waktu mengikuti pengaturan lokasi sistem<br><br>

<b>📝Pengaturan Teks Custom:</b><br>
Atur pesan melalui bot Telegram:<br>
<code>/sahur</code> → Pilih "Atur Teks Pengingat"<br><br>

<b>Placeholder yang tersedia:</b><br>
• <code>{time}</code> → Waktu sahur<br>
• <code>{timezone}</code> → Zona waktu<br>
• <code>{location}</code> → Lokasi lengkap
]]

-- Opsi file suara tarhim
sound_adzan_imsy = s2:option(Value, "sound_adzan_imsy", "🎵 File Suara Imsak/Tarhim")
sound_adzan_imsy.datatype = "file"
sound_adzan_imsy.placeholder = "/root/jsholat/tarhim.mp3"
sound_adzan_imsy:depends("tarhim_enabled", "1")

-- Opsi file suara adzan reguler
sound_adzan = s2:option(Value, "sound_adzan", "🎵 File Suara Adzan")
sound_adzan.datatype = "file"
sound_adzan.placeholder = "/root/jsholat/adzan.mp3"

-- Opsi file suara adzan subuh
sound_adzan_shubuh = s2:option(Value, "sound_adzan_shubuh", "🎵 File Suara Adzan Subuh")
sound_adzan_shubuh.datatype = "file"
sound_adzan_shubuh.placeholder = "/root/jsholat/adzan_subuh.mp3"

-- ==================== SECTION SERVICE ====================
s3 = m:section(TypedSection, "service", "⚙️ Pengaturan Service")
s3.anonymous = true
s3.addremove = false

-- Opsi untuk mengaktifkan/menonaktifkan service
service_enabled = s3:option(ListValue, "service", "🔄 Status Service Jsholat")
service_enabled:value("1", "✅ Aktif")
service_enabled:value("0", "❌ Nonaktif")
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
telegram_enabled = s3:option(ListValue, "telegram_enabled", "📱 Notifikasi Telegram")
telegram_enabled:value("1", "✅ Aktif")
telegram_enabled:value("0", "❌ Nonaktif")
telegram_enabled.default = "1"

-- Opsi untuk token bot Telegram
telegram_bot_token = s3:option(Value, "telegram_bot_token", "🔑 Token Bot Telegram")
telegram_bot_token.datatype = "string"
telegram_bot_token.password = true
telegram_bot_token.placeholder = "Masukkan token bot Telegram"
telegram_bot_token:depends("telegram_enabled", "1")

-- Opsi untuk chat ID Telegram
telegram_chat_id = s3:option(Value, "telegram_chat_id", "👤 Chat ID Telegram")
telegram_chat_id.datatype = "string"
telegram_chat_id.placeholder = "Masukkan chat ID Telegram"
telegram_chat_id:depends("telegram_enabled", "1")

-- Opsi untuk debug mode
debug_mode = s3:option(ListValue, "debug_mode", "🐛 Mode Debug")
debug_mode:value("1", "✅ Aktif")
debug_mode:value("0", "❌ Nonaktif")
debug_mode.default = "0"
debug_mode.description = "Mode debug untuk logging lebih detail"

-- Opsi untuk ayat enabled
ayat_enabled = s3:option(ListValue, "ayat_enabled", "📖 Notifikasi Ayat")
ayat_enabled:value("1", "✅ Aktif")
ayat_enabled:value("0", "❌ Nonaktif")
ayat_enabled.default = "0"
ayat_enabled.description = "Mengaktifkan notifikasi ayat Al-Quran"

-- Fungsi untuk memeriksa nilai interval jadwal
function check_interval()
    local handle = io.popen("uci get jsholat.schedule.interval")
    local interval = tonumber(handle:read("*a"))
    handle:close()
    return interval
end

-- Tombol untuk restart service jadwal
restart_jadwal = s3:option(Button, "_restart_jadwal", "🔄 Restart Service Jadwal")
restart_jadwal.inputtitle = "🔄 Restart Service Jadwal"
restart_jadwal.inputstyle = "apply"

function restart_jadwal.write(self, section)
    os.execute("/etc/init.d/jadwal restart")
    restart_jadwal_msg.value = "✅ Service Jadwal telah di-restart pada " .. os.date("%Y-%m-%d %H:%M:%S")
end

restart_jadwal_msg = s3:option(DummyValue, "_restart_jadwal_msg", "📋 Pesan Restart Jadwal")
restart_jadwal_msg.value = "⏳ Belum ada perintah restart..."

-- Tombol untuk restart service jsholat
restart_jsholat = s3:option(Button, "_restart_jsholat", "🔄 Restart Service Jsholat")
restart_jsholat.inputtitle = "🔄 Restart Service Jsholat"
restart_jsholat.inputstyle = "apply"
function restart_jsholat.write(self, section)
    os.execute("/etc/init.d/jsholat restart")
    restart_jsholat_msg.value = "✅ Service Jsholat telah di-restart pada " .. os.date("%Y-%m-%d %H:%M:%S")
end

restart_jsholat_msg = s3:option(DummyValue, "_restart_jsholat_msg", "📋 Pesan Restart Jsholat")
restart_jsholat_msg.value = "⏳ Belum ada perintah restart..."

-- Status service jadwal (LANGSUNG di sini, tanpa template terpisah)
status_jadwal = s3:option(DummyValue, "_status_jadwal", "📊 Status Service Jadwal")
status_jadwal.rawhtml = true

function status_jadwal.cfgvalue(self)
    local running = false
    local enabled = false
    
    -- Cek status service
    local handle = io.popen("/etc/init.d/jadwal status 2>&1")
    if handle then
        local output = handle:read("*a"):lower()
        handle:close()
        running = (output:find("running") ~= nil)
    end
    
    -- Cek apakah service enabled
    enabled = (os.execute("test -f /etc/rc.d/S*jadwal") == 0)
    
    -- Bangun HTML
    local html = '<div style="margin-bottom:5px;">'
    
    if running then
        html = html .. '<span class="label label-success" style="padding:4px 8px;">✅ BERJALAN</span>'
    else
        html = html .. '<span class="label label-danger" style="padding:4px 8px;">❌ TIDAK BERJALAN</span>'
    end
    
    html = html .. ' <span style="margin:0 5px;">|</span> '
    
    if enabled then
        html = html .. '<span class="label label-success" style="padding:4px 8px;">✅ ENABLED</span>'
    else
        html = html .. '<span class="label label-warning" style="padding:4px 8px;">⚠️ DISABLED</span>'
    end
    
    html = html .. '</div>'
    
    return html
end

-- Status service jsholat (versi tanpa sys)
status_jsholat = s3:option(DummyValue, "_status_jsholat", "📊 Status Service Jsholat")
status_jsholat.rawhtml = true

function status_jsholat.cfgvalue(self)
    local running = false
    local enabled = false
    local pid = ""
    local uptime_info = ""
    
    -- Cek status service
    local handle = io.popen("/etc/init.d/jsholat status 2>&1")
    if handle then
        local output = handle:read("*a"):lower()
        handle:close()
        running = (output:find("running") ~= nil) or (output:find("berjalan") ~= nil)
    end
    
    -- Cek apakah service enabled
    enabled = (os.execute("test -f /etc/rc.d/S*jsholat") == 0)
    
    -- Dapatkan PID jika berjalan
    if running then
        local pid_handle = io.popen("pgrep -f '/usr/bin/jsholat run' | head -1")
        if pid_handle then
            pid = pid_handle:read("*a"):gsub("\n", "")
            pid_handle:close()
            
            if pid and pid ~= "" then
                local start_handle = io.popen("stat -c %Y /proc/" .. pid .. " 2>/dev/null")
                if start_handle then
                    local start_time = start_handle:read("*a"):gsub("\n", "")
                    start_handle:close()
                    
                    if start_time and start_time ~= "" then
                        local now = os.time()
                        local uptime = now - tonumber(start_time)
                        local days = math.floor(uptime / 86400)
                        local hours = math.floor((uptime % 86400) / 3600)
                        local minutes = math.floor((uptime % 3600) / 60)
                        
                        uptime_info = string.format('<br><small style="color:#666;">Uptime: %d hari %d jam %d menit</small>', 
                            days, hours, minutes)
                    end
                end
            end
        end
    end
    
    -- Bangun HTML
    local html = '<div style="margin-bottom:5px;">'
    
    if running then
        html = html .. '<span class="label label-success" style="padding:4px 8px;">✅ BERJALAN</span>'
        if pid ~= "" then
            html = html .. ' <small style="color:#666;">(PID: ' .. pid .. ')</small>'
        end
    else
        html = html .. '<span class="label label-danger" style="padding:4px 8px;">❌ TIDAK BERJALAN</span>'
    end
    
    html = html .. ' <span style="margin:0 5px;">|</span> '
    
    if enabled then
        html = html .. '<span class="label label-success" style="padding:4px 8px;">✅ ENABLED</span>'
    else
        html = html .. '<span class="label label-warning" style="padding:4px 8px;">⚠️ DISABLED</span>'
    end
    
    html = html .. uptime_info .. '</div>'
    
    return html
end

-- Status service bot Telegram (versi tanpa luci.sys)
status_bot_tg = s3:option(DummyValue, "_status_bot_tg", "🤖 Status Service Bot Telegram")
status_bot_tg.rawhtml = true

function status_bot_tg.cfgvalue(self)
    local running = false
    local enabled = false
    local configured = false
    
    -- Cek status service
    local handle = io.popen("/etc/init.d/jsholat-bot status 2>&1")
    if handle then
        local output = handle:read("*a"):lower()
        handle:close()
        running = (output:find("running") ~= nil)
    end
    
    -- Cek apakah service enabled
    enabled = (os.execute("test -L /etc/rc.d/S*jsholat-bot") == 0)
    
    -- Cek apakah bot terkonfigurasi (punya token dan chat_id)
    local token_handle = io.popen("uci -q get jsholat.service.telegram_bot_token || echo ''")
    local token = token_handle:read("*a"):gsub("\n", "")
    token_handle:close()
    
    local chat_handle = io.popen("uci -q get jsholat.service.telegram_chat_id || echo ''")
    local chat_id = chat_handle:read("*a"):gsub("\n", "")
    chat_handle:close()
    
    configured = (token ~= "" and chat_id ~= "")
    
    -- Dapatkan info tambahan
    local pid_info = ""
    if running then
        local pid_handle = io.popen("pgrep -f '/usr/bin/jsholat-bot' | head -1")
        local pid = pid_handle:read("*a"):gsub("\n", "")
        pid_handle:close()
        
        if pid and pid ~= "" then
            pid_info = ' <small style="color:#666;">(PID: ' .. pid .. ')</small>'
        end
    end
    
    -- Bangun HTML (sama seperti di atas)
    local html = '<div style="margin-bottom:5px;">'
    
    if running then
        html = html .. '<span class="label label-success" style="padding:4px 8px;">✅ BERJALAN</span>' .. pid_info
    else
        html = html .. '<span class="label label-danger" style="padding:4px 8px;">❌ TIDAK BERJALAN</span>'
    end
    
    html = html .. '<br><div style="margin-top:5px;">'
    
    if enabled then
        html = html .. '<span class="label label-success" style="padding:3px 6px; font-size:11px;">✅ ENABLED</span>'
    else
        html = html .. '<span class="label label-warning" style="padding:3px 6px; font-size:11px;">⚠️ DISABLED</span>'
    end
    
    html = html .. ' '
    
    if configured then
        html = html .. '<span class="label label-success" style="padding:3px 6px; font-size:11px;">🔑 TERKONFIGURASI</span>'
    else
        html = html .. '<span class="label label-warning" style="padding:3px 6px; font-size:11px;">⚠️ BELUM DIKONFIGURASI</span>'
    end
    
    html = html .. '</div></div>'
    
    return html
end

-- Fungsi untuk menampilkan status cron job jadwal
cron_status = s3:option(DummyValue, "_cron_status", "⏰ Status Cronjob Jadwal")
cron_status.rawhtml = true

function cron_status.cfgvalue(self)
    local cmd = "/usr/bin/jadwal-update.sh"
    local cron_job = luci.sys.exec("crontab -l 2>/dev/null | grep '"..cmd.."'")
    
    if cron_job and #cron_job > 0 then
        return '<span class="label label-success">✅ AKTIF</span>'
    else
        return '<span class="label label-danger">❌ NONAKTIF</span>'
    end
end

-- ==================== STATUS TARHIM ====================
-- Status fitur tarhim dengan deskripsi yang jelas
status_tarhim = s3:option(DummyValue, "_status_tarhim", "🌙 Fitur Suara Tarhim/Imsak")
status_tarhim.rawhtml = true
status_tarhim.description = "Menampilkan status aktif/nonaktif dan konfigurasi pemutaran suara tarhim"

function status_tarhim.cfgvalue(self)
    local enabled = uci:get("jsholat", "sound", "tarhim_enabled") or "0"
    local mode = uci:get("jsholat", "sound", "tarhim_mode") or "ramadhan_only"
    local reminder_time = uci:get("jsholat", "sound", "reminder_before") or "15"
    local reminder_sound = uci:get("jsholat", "sound", "reminder_sound_enabled") or "0"
    local sound_file = uci:get("jsholat", "sound", "sound_adzan_imsy") or ""
    
    if enabled == "1" then
        -- Tentukan teks mode dan warna
        local mode_text = ""
        local mode_color = ""
        local tts_reminder_status = ""
        
        if mode == "ramadhan_only" then
            mode_text = "🌙 Tarhim selalu diputar, TTS reminder HANYA Ramadhan"
            mode_color = "#ff9800"
            
            -- Info TTS reminder berdasarkan status
            if reminder_sound == "1" then
                tts_reminder_status = '<div style="margin-top:8px; padding:8px 12px; background:#e8f5e9; border-left:4px solid #4caf50; border-radius:3px;">' ..
                    '<span style="color:#2e7d32;">🔊 <strong>Info TTS Reminder Imsyak:</strong> ' ..
                    '<span style="font-weight:bold;">HANYA AKTIF SAAT RAMADHAN</span> (sesuai mode yang dipilih)</span></div>'
            else
                tts_reminder_status = '<div style="margin-top:8px; padding:8px 12px; background:#fff3e0; border-left:4px solid #ff9800; border-radius:3px;">' ..
                    '<span style="color:#e65100;">⚠️ <strong>Catatan:</strong> Suara TTS reminder sedang ' ..
                    '<span style="font-weight:bold;">NONAKTIF</span>. Aktifkan di "Suara Pengingat (TTS)" jika ingin menggunakan</span></div>'
            end
        else -- always
            mode_text = "📆 Selalu diputar setiap hari (termasuk TTS reminder)"
            mode_color = "#2196f3"
            
            if reminder_sound == "1" then
                tts_reminder_status = '<div style="margin-top:8px; padding:8px 12px; background:#e8f5e9; border-left:4px solid #4caf50; border-radius:3px;">' ..
                    '<span style="color:#2e7d32;">🔊 <strong>Info TTS Reminder Imsyak:</strong> ' ..
                    '<span style="font-weight:bold;">AKTIF SETIAP HARI</span> (sesuai mode always)</span></div>'
            else
                tts_reminder_status = '<div style="margin-top:8px; padding:8px 12px; background:#fff3e0; border-left:4px solid #ff9800; border-radius:3px;">' ..
                    '<span style="color:#e65100;">⚠️ <strong>Catatan:</strong> Suara TTS reminder sedang ' ..
                    '<span style="font-weight:bold;">NONAKTIF</span>. Aktifkan di "Suara Pengingat (TTS)" jika ingin menggunakan</span></div>'
            end
        end
        
        -- Cek file suara
        local file_status = ""
        local file_color = ""
        
        if sound_file and sound_file ~= "" then
            -- Cek apakah file benar-benar ada di sistem
            local fs = require "nixio.fs"
            if fs.access(sound_file) then
                file_status = "✅ " .. sound_file
                file_color = "#4caf50"
            else
                file_status = "⚠️ " .. sound_file .. " (file tidak ditemukan)"
                file_color = "#ff9800"
            end
        else
            file_status = "⚠️ Belum diatur (akan menggunakan file default jika ada)"
            file_color = "#ff9800"
        end
        
        return string.format(
            '<div style="margin-bottom:8px;">' ..
            '<span class="label label-success" style="font-size:13px; padding:5px 10px;">✅ TARHIM AKTIF</span>' ..
            '<span style="margin-left:12px; font-weight:bold;">Mode:</span> ' ..
            '<span style="color:%s; font-weight:bold; background:#f0f0f0; padding:3px 8px; border-radius:3px;">%s</span></div>' ..
            '<div style="margin-bottom:8px; padding-left:5px;">' ..
            '<span style="font-weight:bold;">⏰ Waktu Mulai Tarhim:</span> ' ..
            '<span style="color:#2196f3; font-weight:bold; background:#e3f2fd; padding:3px 8px; border-radius:3px;">%s menit</span> ' ..
            '<span style="color:#666;">sebelum waktu Imsak</span></div>' ..
            '<div style="margin-bottom:8px; padding-left:5px;">' ..
            '<span style="font-weight:bold;">🔊 File Suara Tarhim:</span> ' ..
            '<span style="color:%s; background:#f5f5f5; padding:3px 8px; border-radius:3px;">%s</span></div>' ..
            '%s', -- tempat untuk tts_reminder_status
            mode_color, mode_text, reminder_time, file_color, file_status, tts_reminder_status
        )
    else
        return string.format(
            '<div style="margin-bottom:8px;">' ..
            '<span class="label label-danger" style="font-size:13px; padding:5px 10px;">❌ TARHIM NONAKTIF</span>' ..
            '<span style="margin-left:12px; color:#666;">Fitur tarhim/imsak sedang tidak diaktifkan</span></div>' ..
            '<div style="margin-top:8px; padding:8px 12px; background:#fff3cd; border-left:4px solid #ffc107; border-radius:3px;">' ..
            '<span style="color:#856404;">💡 <strong>Tips:</strong> Aktifkan opsi ' ..
            '"<span style="font-weight:bold;">🌙 Aktifkan Suara Tarhim/Imsak</span>" di bagian ' ..
            '<span style="font-weight:bold;">🔊 Pengaturan Suara</span> untuk menggunakan fitur ini</span></div>' ..
            '<div style="margin-top:8px; padding:8px 12px; background:#e8eaf6; border-left:4px solid #3f51b5; border-radius:3px;">' ..
            '<span style="color:#1a237e;">📌 <strong>Catatan:</strong> Notifikasi Telegram Imsyak tetap dikirim meskipun tarhim nonaktif</span></div>'
        )
    end
end

-- ==================== STATUS SAHUR ====================
-- Status fitur alarm sahur
status_sahur = s3:option(DummyValue, "_status_sahur", "🌙 Status Alarm Sahur Ramadhan")
status_sahur.rawhtml = true

function status_sahur.cfgvalue(self)
    local enabled = uci:get("jsholat", "sound", "sahur_enabled") or "0"
    local waktu = uci:get("jsholat", "sound", "sahur_time") or "02:30"
    local reminder_file = "/usr/share/jsholat/sahur-reminder.txt"
    local tts_method = uci:get("jsholat", "sound", "tts_method") or "google"
    local timezone = uci:get("jsholat", "schedule", "timezone_value") or "WIB"
    
    -- Cek status Ramadhan dari file cache
    local is_ramadhan_now = false
    local hijri_cache = "/tmp/jsholat_cache/hijri_date_cache.json"
    
    -- Gunakan io.open untuk membaca file cache
    local file = io.open(hijri_cache, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        -- Parse JSON sederhana untuk mendapatkan bulan
        -- Cari pola "month": X atau "month":X
        local month_match = content:match('"month"%s*:%s*(%d+)')
        if month_match then
            local month = tonumber(month_match)
            if month == 9 then
                is_ramadhan_now = true
            end
        end
        
        -- Fallback: cek apakah ada kata "Ramadhan" di monthName
        if not is_ramadhan_now then
            local month_name = content:match('"monthName"%s*:%s*"([^"]+)"')
            if month_name and month_name:find("Ramadhan") then
                is_ramadhan_now = true
            end
        end
    end
    
    -- Format status Ramadhan dengan HTML
    local ramadhan_status = ""
    if is_ramadhan_now then
        ramadhan_status = '<span style="color:#4caf50; font-weight:bold;">🌙 SEDANG RAMADHAN</span>'
    else
        ramadhan_status = '<span style="color:#ff9800;">📅 BUKAN RAMADHAN</span>'
    end
    
    if enabled == "1" then
        -- Cek apakah ada teks custom
        local custom_text = "❌ Tidak ada"
        local custom_file = io.open(reminder_file, "r")
        if custom_file then
            custom_file:close()
            custom_text = "✅ Ada (gunakan /sahur di bot untuk preview)"
        end
        
        -- Konversi metode TTS ke nama yang lebih user-friendly
        local tts_name = ""
        if tts_method == "google" then
            tts_name = "Google TTS"
        elseif tts_method == "edge" then
            tts_name = "Edge-TTS"
        elseif tts_method == "espeak" then
            tts_name = "eSpeak (Offline)"
        elseif tts_method == "murf" then
            tts_name = "Murf.ai"
        elseif tts_method == "gemini" then
            tts_name = "Gemini AI"
        else
            tts_name = tts_method
        end
        
        return string.format(
            '<div style="margin-bottom:8px;">' ..
            '<span class="label label-success" style="font-size:13px; padding:5px 10px;">✅ SAHUR AKTIF</span>' ..
            '<span style="margin-left:12px; font-weight:bold;">Waktu Eksekusi:</span> ' ..
            '<span style="color:#2196f3; font-weight:bold; background:#e3f2fd; padding:3px 8px; border-radius:3px;">Tepat pukul %s %s</span></div>' ..
            '<div style="margin-bottom:8px; padding-left:5px;">' ..
            '<span style="font-weight:bold;">🗣️ Metode TTS:</span> %s<br>' ..
            '<span style="font-weight:bold;">📝 Teks Custom:</span> %s<br>' ..
            '<span style="font-weight:bold;">🌙 Status Ramadhan:</span> %s</div>' ..
            '<div style="margin-top:8px; padding:8px 12px; background:#e8f5e9; border-left:4px solid #4caf50; border-radius:3px;">' ..
            '<span style="color:#2e7d32;">💡 <strong>Info:</strong> Alarm sahur akan berbunyi TEPAT pada jam yang diatur ' ..
            '(bukan X menit sebelumnya) pada bulan Ramadhan. Teks dapat disesuaikan melalui bot Telegram dengan perintah <strong>/sahur</strong>.</span></div>',
            waktu, timezone,
            tts_name,
            custom_text,
            ramadhan_status
        )
    else
        return string.format(
            '<div style="margin-bottom:8px;">' ..
            '<span class="label label-warning" style="font-size:13px; padding:5px 10px;">❌ SAHUR NONAKTIF</span></div>' ..
            '<div style="margin-top:8px; padding:8px 12px; background:#fff3e0; border-left:4px solid #ff9800; border-radius:3px;">' ..
            '<span style="color:#e65100;">💡 <strong>Tips:</strong> Aktifkan alarm sahur di menu <strong>🔊 Pengaturan Suara</strong> ' ..
            'untuk mendapatkan pengingat bangun sahur selama bulan Ramadhan.</span></div>' ..
            '<div style="margin-top:8px; padding:8px 12px; background:#e8eaf6; border-left:4px solid #3f51b5; border-radius:3px;">' ..
            '<span style="color:#1a237e;">📌 <strong>Info:</strong> Alarm hanya aktif saat bulan Ramadhan dan akan ' ..
            'menggunakan teks custom yang diatur melalui bot Telegram (perintah <strong>/sahur</strong>).</span></div>' ..
            '<div style="margin-top:8px; padding:8px 12px; background:#f3e5f5; border-left:4px solid #9c27b0; border-radius:3px;">' ..
            '<span style="color:#4a148c;">🔍 <strong>Status Ramadhan saat ini:</strong> %s</span></div>',
            ramadhan_status
        )
    end
end

-- ==================== STATUS DETAIL FITUR ====================
-- Status TTS Gemini
status_gemini = s3:option(DummyValue, "_status_gemini", "🤖 Status Gemini AI TTS")
status_gemini.rawhtml = true

function status_gemini.cfgvalue(self)
    local api_key = uci:get("jsholat", "sound", "gemini_api_key") or ""
    local voice = uci:get("jholat", "sound", "gemini_voice") or "Leda"
    local model = uci:get("jsholat", "sound", "gemini_model") or "gemini-2.5-flash-preview-tts"
    
    if api_key and api_key ~= "" then
        -- Mask API key (tampilkan hanya 4 karakter pertama dan terakhir)
        local masked_key = ""
        if #api_key > 8 then
            masked_key = string.sub(api_key, 1, 4) .. "..." .. string.sub(api_key, -4)
        else
            masked_key = "********"
        end
        
        return string.format(
            '<div style="margin-bottom:5px;">' ..
            '<span class="label label-success" style="font-size:12px; padding:3px 8px;">✅ GEMINI TERKONFIGURASI</span></div>' ..
            '<div style="margin-top:5px; padding-left:5px;">' ..
            '<span style="font-weight:bold;">🔑 API Key:</span> %s<br>' ..
            '<span style="font-weight:bold;">🎤 Voice:</span> %s<br>' ..
            '<span style="font-weight:bold;">🧠 Model:</span> %s</div>',
            masked_key, voice, model
        )
    else
        return '<span class="label label-warning">⚠️ BELUM DIKONFIGURASI</span>'
    end
end

-- Status Edge-TTS
status_edge = s3:option(DummyValue, "_status_edge", "📘 Status Edge-TTS")
status_edge.rawhtml = true

function status_edge.cfgvalue(self)
    local voice = uci:get("jsholat", "sound", "edge_voice") or "id-ID-ArdiNeural"
    
    -- Konversi voice ke nama yang mudah dibaca
    local voice_name = ""
    if voice == "id-ID-ArdiNeural" then
        voice_name = "🗣️ Ardi (Indonesia - Pria)"
    elseif voice == "id-ID-GadisNeural" then
        voice_name = "👩 Gadis (Indonesia - Wanita)"
    elseif voice == "jv-ID-DimasNeural" then
        voice_name = "👨‍🦰 Dimas (Jawa - Pria)"
    elseif voice == "jv-ID-SitiNeural" then
        voice_name = "👩‍🦰 Siti (Jawa - Wanita)"
    else
        voice_name = voice
    end
    
    return string.format(
        '<div><span style="font-weight:bold;">🎤 Voice:</span> %s</div>',
        voice_name
    )
end

-- Status pengulangan reminder
status_repeat = s3:option(DummyValue, "_status_repeat", "🔁 Status Pengulangan Reminder")
status_repeat.rawhtml = true

function status_repeat.cfgvalue(self)
    local repeat_count = uci:get("jsholat", "sound", "reminder_repeat_count") or "3"
    local repeat_interval = uci:get("jsholat", "sound", "reminder_repeat_interval") or "5"
    local reminder_before = uci:get("jsholat", "sound", "reminder_before") or "15"
    
    if reminder_before == "0" then
        return '<span class="label label-default">⚙️ REMINDER NONAKTIF</span>'
    else
        return string.format(
            '<div><span style="font-weight:bold;">🔁 Pengulangan:</span> %s kali<br>' ..
            '<span style="font-weight:bold;">⏲️ Interval:</span> %s detik</div>',
            repeat_count, repeat_interval
        )
    end
end

-- Fungsi validasi untuk provinsi dan kota
function city.write(self, section, value)
    -- Ambil nilai dari field hidden yang dibuat oleh JavaScript
    local city_val = luci.http.formvalue("cbid.jsholat.schedule.city_value") or value
    local label_val = luci.http.formvalue("cbid.jsholat.schedule.city_label") or ""
    local tz_val = luci.http.formvalue("cbid.jsholat.schedule.timezone_value") or "WIB"
    
    -- Pastikan hanya single value
    if type(city_val) == "table" then
        city_val = city_val[1] or value
    end
    if type(label_val) == "table" then
        label_val = label_val[1] or ""
    end
    if type(tz_val) == "table" then
        tz_val = tz_val[1] or "WIB"
    end
    
    -- Log untuk debugging
    os.execute(string.format("logger -t jsholat 'City write - city: %s, label: %s, tz: %s'", 
        tostring(city_val), tostring(label_val), tostring(tz_val)))
    
    return true
end

function m.on_save(self)
    os.execute("/etc/init.d/jsholat restart >/dev/null 2>&1")
    return true
end

return m