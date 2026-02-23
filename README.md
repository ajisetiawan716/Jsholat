# **Jsholat / luci-app-jsholat**

`Jsholat` atau `luci-app-jsholat` adalah aplikasi penjadwal waktu sholat otomatis untuk perangkat OpenWrt (Router/STB/Mini PC Server) yang dilengkapi pemutar adzan, pengingat TTS, dukungan nuansa Ramadhan (Imsak & Sahur, dan notifikasi telegram), serta integrasi Telegram Bot untuk kontrol jarak jauh.

---

## **Fitur**

- **Jadwal Sholat Multi-Sumber**: Mendukung jadwal dari **JadwalSholat.Org**, **MyQuran API**, **Aladhan API**, **Arina.id, Equran.id** dan **AjiMedia API**.
- **Antarmuka LuCI Modern**: Pengaturan lengkap melalui GUI dengan pemilihan provinsi, kota/kabupaten, dan zona waktu otomatis.
- **Pengingat Waktu Sholat (TTS)**: Pengingat suara otomatis sebelum waktu sholat tiba dengan dukungan **Google TTS**, **Edge-TTS**, **eSpeak**, **Murf.ai**, dan **Gemini AI TTS**.
- **Adzan Otomatis**: Memutar file MP3 adzan (umum dan subuh) serta tarhim/imsak saat waktu tiba.
- **Bot Telegram Terintegrasi**: Kontrol penuh jadwal, pengaturan suara, alarm sahur, tarhim, dan monitoring melalui Telegram.
- **Alarm Sahur Ramadhan**: Pengingat bangun sahur dengan teks yang dapat dikustomisasi (hanya aktif saat Ramadhan) via bot Telegram.
- **Ayat Acak**: Mengirim ayat Al-Qur'an beserta terjemahan melalui notifikasi Telegram.
- **Status Detail & Monitoring**: Halaman status lengkap dengan informasi service, bot, memori sistem, dan jadwal hari ini.
- **Installer Otomatis (jsi)**: Script instalasi yang mengurus dependensi, driver soundcard, dan pemilihan versi paket (MAIN/DEV/Latest Release).
- **Logging Terpusat**: Log untuk service utama, penjadwal, bot Telegram dengan rotasi otomatis.

---

## Screenshot

### 1. Pengaturan Jadwal

![Screenshot JSHOLAT 1](docs\screenshot\Screenshots_1.png)

![Screenshot JSHOLAT 2](docs\screenshot\Screenshots_2.png)

![Screenshot JSHOLAT 3](docs\screenshot\Screenshots_3.png)

![Screenshot JSHOLAT 4](docs\screenshot\Screenshots_4.png)

![Screenshot JSHOLAT 5](docs\screenshot\Screenshots_5.png)

![Screenshot JSHOLAT 6](docs\screenshot\Screenshots_6.png)

---

### 2. Status Detail

![Screenshot JSHOLAT 7](docs\screenshot\Screenshots_7.png)

![Screenshot JSHOLAT 8](docs\screenshot\Screenshots_8.png)

![Screenshot JSHOLAT 9](docs\screenshot\Screenshots_9.png)

![Screenshot JSHOLAT 10](docs\screenshot\Screenshots_10.png)

---

### 3. Jadwal Bulanan

![Screenshot JSHOLAT 11](docs\screenshot\Screenshots_11.png)

---

### 4. Halaman Log

![Screenshot JSHOLAT 12](docs\screenshot\Screenshots_12.png)

![Screenshot JSHOLAT 13](docs\screenshot\Screenshots_13.png)

![Screenshot JSHOLAT 14](docs\screenshot\Screenshots_14.png)

---

## **Panduan Instalasi**

### **1. Persyaratan**

- Perangkat dengan OpenWrt terinstal (termasuk arsitektur seperti x86, ARM, MIPS).
- Koneksi internet untuk mengunduh file dan update jadwal.
- USB Soundcard (jika tidak ada soundcard internal) dan speaker.
- Paket-paket berikut akan diinstall otomatis oleh `jsi`:
  - `madplay` / `mpg123` (pemutar MP3)
  - `alsa-utils` (tools audio)
  - `python3`, `python3-pip`, `jq`, `curl`, `luci-lib-jsonc`
  - **Pillow** (via pip) untuk generate gambar jadwal bulanan
  - **Edge-TTS** (via pip) untuk suara reminder/pengingat dari Microst
  - **Gemini AI TTS** untuk suara natural TTS berbasis AI dari Google. (via API key)

### **2. Langkah-Langkah Instalasi**

#### **a. Download Installer (jsi)**

```bash
wget --no-check-certificate -q "https://github.com/ajisetiawan716/Jsholat/raw/refs/heads/main/jsi" \
  -O /usr/bin/jsi && chmod +x /usr/bin/jsi && clear && /usr/bin/jsi
```

> Catatan: jalankan dengan perintah `jsi` di terminal.

#### **b. Proses Instalasi via jsi**

1. Jalankan `jsi` di terminal.
2. Pilih **opsi 1** untuk menginstall semua dependensi dan file pendukung (MP3 adzan, tarhim, intro/outro reminder).
3. Pilih **opsi 2** untuk mendeteksi dan menginstall driver soundcard secara otomatis (membuat konfigurasi audio `/etc/asound.conf`).
4. Pilih **opsi 3** untuk menginstall paket **luci-app-jsholat**:
   - **a)** dari URL/file lokal
   - **b)** dari branch MAIN*
   - **c)** dari branch DEV*
   - **d)** dari **Latest Release (GitHub) - Recommended**
5. Setelah install selesai bersihkan cache LuCi (Opsional).

#### **c. Restart Service Web**

```bash
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart
```

#### **d. Verifikasi Instalasi**

- Buka LuCI (mis. `http://192.168.1.1`), masuk ke menu **Services → Jadwal Sholat**.

- Cek status semua service:
  
  ```bash
  /etc/init.d/jsholat status
  /etc/init.d/jadwal status
  /etc/init.d/jsholat-bot status
  ```

- Atau cek status via menu monitoring di LuCi menu atau menu `Status Detail.`

#### **e. Konfigurasi Awal di LuCI**

1. **Pilih Provinsi & Kota/Kabupaten**: Sistem akan otomatis mengisi zona waktu.
2. **Pilih Sumber Jadwal**: `JadwalSholat.Org`, `MyQuran API`, `Aladhan API`,  `Arina.id, Equran.id` atau `AjiMedia API`. (Rekomendasi pilih `JadwalSholat.Org`)
3. **Atur Koreksi Hijriyah (jika perlu)**: Penyesuaian -2 hingga +2 hari.
4. **Atur Volume dan Mixer Device**: `amixer` control (Master, PCM, Speaker).
5. **Pilih Metode TTS**: Google, Edge-TTS, eSpeak, Murf.ai, atau Gemini AI.
6. **Aktifkan Reminder**: Durasi sebelum adzan (5,10,15 menit), jumlah pengulangan, interval.
7. **Atur Tarhim Imsyak**:
   - `ramadhan_only`: Tarhim selalu diputar, TTS reminder **hanya saat Ramadhan**.
   - `always`: Tarhim dan TTS reminder diputar **setiap hari**.
8. **Masukkan Token dan Chat ID Bot Telegram** (dapatkan dari [@BotFather](https://t.me/botfather)).
9. **Simpan (Save & Apply)**.

#### **f. Konfigurasi Bot Telegram**

Setelah token dan chat ID dimasukkan, service `jsholat-bot` akan berjalan secara otomatis.

- Mulai bot dengan perintah `/start`. Bot akan secara otomatis menambahkan perintah bot.

- Daftar lengkap perintah bot:
  
  ```
  /start - 🚀 Mulai bot dan menu utama
  /jadwal - 🕌 Jadwal sholat hari ini
  /jdwlbulan - 📅 Jadwal sholat bulan ini
  /statusbot - 🤖 Status detail bot
  /status - 📊 Status singkat pengaturan
  /lokasi - 📍 Lihat lokasi saat ini
  /setlokasi - 🔍 Cari dan ubah lokasi
  /setjadwal - 🌐 Ganti sumber jadwal
  /sethijri - 📆 Koreksi tanggal Hijriyah
  /update - 🔄 Update jadwal sholat
  /setvolume - 🔊 Atur volume suara
  /detectaudio - 🎛️ Deteksi mixer audio
  /reminder - 🔔 Atur pengingat sholat
  /sahur - 🌙 Atur alarm sahur Ramadhan
  /settts - 🗣️ Pilih metode TTS
  /gemini - 🤖 Konfigurasi Gemini TTS
  /tarhim - 🎵 Atur tarhim imsyak
  /ayat - 📖 Atur ayat acak
  /control - 🎮 Kontrol service
  /setupbot - 🤖 Atur profil bot (nama, foto, bio)
  /help - ❓ Bantuan daftar perintah
  ```

#### **g. Tes Suara**

- **Tes speaker**: `speaker-test -D default -t sine -f 1000 -l 1` di terminal, atau `via Bot`: `/detectaudio`, lalu pilih "🎧 Tes Suara".
- **Tes TTS via bot**: `/settts` pilih metode TTS, lalu `/reminder` aktifkan suara pilih durasi pengingat sebelum waktu sholat, lalu `/reminder` pilih "🎧 Test TTS".
- **Tes adzan**: Tunggu hingga waktu sholat atau putar manual dengan `madplay /root/jsholat/adzan.mp3`.
- **Tes Sahur**: Pilih `/sahur` pada menu bot, pilih "🎧 Tes Suara".

---

## **Cara Mengupdate & Monitoring**

### **Update Jadwal**

- **Manual di LuCI**: Klik tombol **"Perbarui Jadwal Sekarang"**.
- **Bot Telegram**: Kirim perintah `/update`.
- **CLI**: `jadwal-update.sh`

### **Monitoring via LuCI**

- **Halaman Status Detail**: `Services → Jadwal Sholat → Status Detail`.
  - Menampilkan status service jsholat & bot, uptime, penggunaan memori.
  - Menampilkan jadwal hari ini, sholat berikutnya, dan countdown real-time.
  - Informasi konfigurasi TTS (Gemini, Edge-TTS, Murf.AI), Tarhim, dan Sahur.
  - Memory usage dengan progress bar yang diupdate setiap 5 detik.
- **Halaman Log**: `Services → Jadwal Sholat → Log Service`.
  - Menampilkan log `service.log` dan `bot.log` dengan auto-refresh.

---

## **Cara Uninstall**

1. Jalankan `jsi`, pilih **opsi 4** (uninstall).

2. Hapus sisa direktori jika masih ada:
   
   ```bash
   rm -rf /root/jsholat /usr/share/jsholat /var/log/jsholat
   rm -f /etc/config/jsholat
   ```

---

## **Struktur File Aplikasi**

```
/usr/bin/
├── jsholat              # Script utama pemutar adzan & reminder
├── jsholat-bot          # Script bot Telegram
├── jadwal-update.sh     # Update jadwal multi-source (JSON)
├── jadwal-monthly       # Generator gambar jadwal bulanan (Python)

/etc/init.d/
├── jsholat              # Service Jsholat (pemutar)
├── jsholat-bot          # Service Bot Telegram
└── jadwal               # Service penjadwal update

/root/jsholat/           # File audio default
├── adzan.mp3            # Adzan umum
├── adzan_subuh.mp3      # Adzan subuh
└── tarhim.mp3           # Tarhim (menjelang imsyak)

/usr/share/jsholat/      # Data bersama
├── cities.json          # Database kota & provinsi
├── last_updated.txt     # Info update terakhir (JSON)
├── sounds/              # Audio intro/outro reminder
│   ├── in_reminder.mp3
│   └── out_reminder.mp3
└── sahur-reminder.txt   # Teks custom alarm sahur

/usr/lib/lua/luci/
├── controller/jsholat.lua          # Controller LuCI
├── model/cbi/jsholat.lua           # Model CBI untuk konfigurasi
└── view/jsholat/                   # View
    ├── city_select.htm
    ├── output.htm
    ├── status_detail.htm
    ├── logs.htm
    └── jadwal.htm

/var/log/jsholat/        # Log files
├── service.log
└── bot.log
```

---

## **Lisensi**

Aplikasi ini dilisensikan di bawah [Lisensi APACHE](LICENSE).

---

**Berkontribusi**: Buka [Issues](https://github.com/ajisetiawan716/Jsholat/issues) atau ajukan Pull Request.

---

## **Credits**

### **Pengembang & Kontributor**

- [Mikodemos Ragil](https://fb.com/mikodemos.ragil) — **Jsholat (Original Script)** 
- [Aji Setiawan](https://github.com/ajisetiawan716) — **Rewrite & Pengembangan Lanjutan** 
- [Hanyasebuahpengalaman](https://hanyasebuahpengalaman.wordpress.com/2019/05/04/mesin-adzan-imsak-quran-30-juz-setiap-malam-auto-play-openwrt/) / [Khadafi Husein](https://www.facebook.com/groups/openwrt/permalink/2743751135665893/?app=fbl) — **Inspirasi Mesin Adzan OpenWrt**

### **Sumber Data Jadwal Sholat**

- **[JadwalSholat.Org](https://jadwalsholat.org)** — Data jadwal sholat untuk wilayah Indonesia.
- **[MyQuran API](https://api.myquran.com)** — Layanan API dari MyQuran yang menyediakan jadwal sholat, data Al-Qur'an (termasuk ayat acak) dan Kalender Hijriyah.
- **[Aladhan API](https://aladhan.com/prayer-times-api)** — API jadwal sholat internasional dengan berbagai metode perhitungan.
- **[AjiMedia API](https://api.ajimedia.my.id)** — API jadwal sholat untuk wilayah Indonesia (sumber data internal).

### **Layanan Text-to-Speech (TTS)**

- **[Google Translate TTS](https://translate.google.com)** — Layanan TTS gratis dari Google (tidak memerlukan API key).
- **[Edge-TTS (Microsoft)](https://github.com/rany2/edge-tts)** — Layanan TTS premium dari Microsoft Edge, diakses melalui library Python `edge-tts`.
- **[eSpeak](https://espeak.sourceforge.net)** — Mesin TTS sintesis suara ringan dan offline untuk OpenWrt.
- **[Murf.ai](https://murf.ai)** — Layanan TTS berkualitas tinggi dengan suara profesional (memerlukan API key).
- **[Gemini AI TTS (Google)](https://ai.google.dev/gemini-api/docs/text-to-speech)** — Teknologi TTS berbasis AI dari Google dengan berbagai pilihan voice premium (memerlukan API key dari Google AI Studio).

### **Teknologi & Library Pendukung**

- **Pillow (PIL)** — Library Python untuk pemrosesan gambar (digunakan untuk generate jadwal bulanan).
- **jq** — Parser JSON untuk command-line (digunakan di berbagai script).
- **madplay / mpg123** — Pemutar audio MP3 untuk OpenWrt.
- **ALSA (Advanced Linux Sound Architecture)** — Sistem suara pada Linux/OpenWrt.

---