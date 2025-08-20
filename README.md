# **Jsholat / luci-app-jsholat**

`Jsholat` atau `luci-app-jsholat` adalah aplikasi **OpenWrt** yang menyediakan fitur jadwal sholat dengan notifikasi suara adzan. Aplikasi ini dapat menggunakan `madplay` atau `mpg123` untuk memainkan file MP3 adzan dan memiliki skrip untuk memperbarui jadwal sholat secara manual: `jadwal`, `jadwal-monthly`, dan `jadwal-update.sh`.

---

## **Fitur**

- Menampilkan jadwal sholat di antarmuka **LuCI**.
- Memainkan suara adzan saat waktu sholat tiba.
- Memperbarui jadwal sholat secara manual menggunakan perintah `jadwal-update.sh`.
- Service otomatis untuk menjalankan aplikasi saat boot.

---

## **Screenshot**

![Screenshot JSHOLAT 1](https://github.com/user-attachments/assets/945a2dbb-a271-4568-81f3-60d16c7c8716)
![Screenshot JSHOLAT 2](https://github.com/user-attachments/assets/3140d347-e3cb-4976-9e57-f67bfcd63e43)
![Screenshot JSHOLAT 3](https://github.com/user-attachments/assets/4188fb22-5733-4a4e-b0b1-2ebcacc5b373)

---

## **Panduan Instalasi**

### **1. Persyaratan**

- Perangkat dengan OpenWrt terinstal.
- Koneksi internet untuk mengunduh file dari GitHub.
- Paket pendukung: `madplay`, `mpg123`, `alsa-utils`, `luci-lib-jsonc`, `python3`, `python3-pip`.
- (Opsional) `pip3 install pillow` bila butuh Pillow untuk fitur gambar (mis. jadwal bulanan).
- USB Soundcard (tidak perlu jika ada soundcard internal).
- Speaker.

### **2. Langkah-Langkah Instalasi**

#### **a. Download Paket**

```bash
wget --no-check-certificate -q "https://github.com/ajisetiawan716/luci-app-jsholat/raw/refs/heads/main/jsi" \
  -O /usr/bin/jsi && chmod +x /usr/bin/jsi && clear && /usr/bin/jsi
```

> Catatan: gunakan `/usr/bin/jsi` (atau ketik `jsi` langsung) — jangan `bash jsi`.

#### **b. Install Paket**

1. Jalankan:
   ```bash
   jsi
   ```
2. Pilih opsi 1 untuk update **dependensi** dan install file pendukung, pilih 2 untuk install Jsholat.
3. (Alternatif manual) pastikan semua dependensi terinstal:
   ```bash
   opkg update
   opkg install madplay mpg123 alsa-utils luci-lib-jsonc python3 python3-pip
   pip3 install pillow
   ```

#### **c. Restart Service Web**

```bash
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart
```

#### **d. Verifikasi Instalasi**

- Buka LuCI (mis. `http://192.168.1.1`), pastikan menu **Services → Jsholat** muncul.
- Cek status service:
  ```bash
  /etc/init.d/jsholat status
  /etc/init.d/jadwal status
  /etc/init.d/jsholat-bot status
  ```

#### **e. Instalasi Bot Telegram**

- Di LuCI → Services → Jsholat, masukkan **bot token** dan **chat_id**.
- Simpan (Save) dan Apply.

#### **f. Konfigurasi Speaker**

1. Pastikan `alsa-utils` terpasang:
   ```bash
   opkg list-installed | grep alsa-utils
   ```
2. (Opsional) Tes suara:
   ```bash
   speaker-test -D default -t sine -f 1000 -l 1
   ```

---

## **Cara Menggunakan**

### **1. Memperbarui Jadwal Sholat Secara Manual**

- Terminal:
  ```bash
  jadwal-update.sh
  ```
- Melalui LuCI: menu **Perbarui Jadwal** di aplikasi **Jsholat**.
- Melalui Bot Telegram: kirim perintah `/update`.

### **2. Memeriksa Jadwal Sholat**

- Di LuCI → Jsholat.
- Bot Telegram: `/jadwal` (hari ini), `/jdwlbulan` (satu bulan).

### **3. Memainkan Suara Adzan**

- Adzan otomatis diputar saat waktunya. Pastikan file MP3 ada di **`/root/jsholat`**.

---

## **Struktur File Aplikasi**

```
/usr/bin/
├── jsholat          # Script utama pemutar adzan
├── jsholat-bot      # Script bot Telegram Jsholat
├── jadwal           # Update jadwal sholat (harian)
├── jadwal-monthly   # Update jadwal sholat bulanan (Python)
└── jadwal-update.sh # Update jadwal dgn pengecekan

/etc/init.d/
├── jsholat          # Service Jsholat
├── jsholat-bot      # Service Bot Telegram Jsholat
└── jadwal           # Service update jadwal

/root/jsholat/
├── adzan.mp3        # Adzan umum
├── adzan_subuh.mp3  # Adzan subuh
└── tahrim.mp3       # Tarhim (menjelang subuh)

/usr/lib/lua/luci/
├── controller/      # Controller LuCI
├── model/cbi/       # Model CBI untuk konfigurasi
└── view/            # View LuCI

/usr/share/jsholat/  # (Jika ada) file pendukung bersama
```

> Catatan: gunakan `/usr/share/jsholat/` untuk aset “share”, bukan di dalam `/usr/lib/lua/luci/`.

---

## **Cara Uninstall**

1. Jalankan `jsi`, pilih **opsi 4** (uninstall).
2. Hapus sisa file (jika ada):
   ```bash
   rm -f /usr/bin/jsholat /usr/bin/jsholat-bot /usr/bin/jadwal /usr/bin/jadwal-monthly /usr/bin/jadwal-update.sh
   rm -f /etc/init.d/jsholat /etc/init.d/jsholat-bot /etc/init.d/jadwal
   rm -rf /root/jsholat
   rm -rf /usr/share/jsholat
   ```

---

## **Catatan**

- Pastikan perangkat tersambung internet saat `jadwal-update.sh`.
- Jika adzan tidak terdengar, cek ALSA dan pastikan `madplay`/`mpg123` terinstal.

---

## **Lisensi**

Aplikasi ini dilisensikan di bawah [Lisensi MIT](LICENSE).

---

**Berkontribusi**: Buka [Issues](https://github.com/ajisetiawan716/Jsholat/issues) atau ajukan Pull Request.

---

## **Credits**

- Jsholat (Original Script) — [Mikodemos Ragil](https://fb.com/mikodemos.ragil)
- Mesin Adzan OpenWrt (Inspired) — [Hanyasebuahpengalaman](https://hanyasebuahpengalaman.wordpress.com/2019/05/04/mesin-adzan-imsak-quran-30-juz-setiap-malam-auto-play-openwrt/) / [Khadafi Husein](https://www.facebook.com/groups/openwrt/permalink/2743751135665893/?app=fbl)
