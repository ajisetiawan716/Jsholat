

---

# **Jsholat / luci-app-jsholat**

`Jsholat` atau `luci-app-jsholat` adalah aplikasi OpenWRT yang menyediakan fitur jadwal sholat dengan notifikasi suara adzan. Aplikasi ini menggunakan `madplay` untuk memainkan file MP3 adzan dan memiliki dua skrip untuk memperbarui jadwal sholat secara manual: `jadwal` dan `jadwal2`.

---

## **Fitur**

- Menampilkan jadwal sholat di antarmuka Luci.
- Memainkan suara adzan saat waktu sholat tiba.
- Memperbarui jadwal sholat secara manual menggunakan perintah jadwal-update.sh.
- Service otomatis untuk menjalankan aplikasi saat boot.

---

## **Screenshot**

![Screenshot JSHOLAT 1](https://github.com/user-attachments/assets/945a2dbb-a271-4568-81f3-60d16c7c8716)
![Screenshot JSHOLAT 2](https://github.com/user-attachments/assets/3140d347-e3cb-4976-9e57-f67bfcd63e43)
![Screenshot JSHOLAT 3](https://github.com/user-attachments/assets/4188fb22-5733-4a4e-b0b1-2ebcacc5b373)

---
## **Panduan Instalasi**

### **1. Persyaratan**

- Perangkat dengan OpenWRT terinstal.
- Koneksi internet untuk mengunduh file dari GitHub.
- Paket pendukung: `madplay`,`alsa-utils`,`mpg123`,`luci-lib-json`,`luci-lib-jsonc`,`python3`,`pip pillow`.
- USB Soundcard (tidak perlu jika ada soundcard internal)
- Speaker

### **2. Langkah-Langkah Instalasi**

#### **a. Download Paket**

1. Buka terminal di perangkat OpenWRT.
2. Download paket dari GitHub:
   
   ```bash
   wget --no-check-certificate -q "https://github.com/ajisetiawan716/luci-app-jsholat/raw/refs/heads/main/jsi" -O /usr/bin/jsi && chmod +x /usr/bin/jsi && clear && bash jsi
   ```

#### **b. Install Paket**

1. Install paket menggunakan perintah `jsi`:
   
   ```bash
   jsi
   ```
2. Pilih opsi 1 untuk update dependi dan install file pendukung, pilih 2 untuk install Jsholat.
3. Pastikan semua dependensi terinstal:
   
   ```bash
   opkg update
   opkg install madplay alsa-utils luci-lib-json luci-lib-json mpg123 python3
   pip3 install pillow
   ```

#### **c. Restart Service**

1. Restart service `uhttpd` dan `rpcd`:
   
   ```bash
   /etc/init.d/uhttpd restart
   /etc/init.d/rpcd restart
   ```

#### **d. Verifikasi Instalasi**

1. Buka antarmuka Luci di browser (biasanya di `http://192.168.1.1`).
2. Pastikan aplikasi `jsholat` muncul di menu Luci > Services. Dan pastikan ada menu Jadwal Sholat.
3. Periksa status service:
   
   ```bash
   /etc/init.d/jsholat status
   /etc/init.d/jadwal status
   /etc/init.d/jsholat-bot status
   ```

---

#### **e. Instalasi Bot Telegram**

1. Buka antarmuka Luci di browser (biasanya di `http://192.168.1.1`).
2. Pastikan aplikasi `jsholat` muncul di menu Luci > Services. Dan pastikan ada menu Jadwal Sholat.
3. Masukkan bot id dan token bot pada masing-masing kolom.
4. Simpan pengaturan dengan klik Save dan klik Apply.


## **Cara Menggunakan**

### **1. Memperbarui Jadwal Sholat Secara Manual**

Untuk memperbarui jadwal sholat secara manual, jalankan salah satu opsi berikut:

1. Menggunakan perintah `jadwal-update.sh` untuk update melalui terminal:
  
  ```bash
  jadwal-update.sh
  ```

2. Menggunakan menu `Perbarui Jadwal` pada menu luci aplikasi `Jsholat`.
3. Menggunakan bot menu dengan perintah `/update` pada bot Telegram.


### **2. Memeriksa Jadwal Sholat**

- Untuk melihat jadwal sholat yang sudah diperbarui, buka antarmuka Luci dan navigasikan ke menu `jsholat`.
- Bisa juga melalui bot telegram melalui perintah `/jadwal` untuk melihat jadwal sholat hari ini, dan perintah `/jdwlbulan` untuk melihat jadwal selama satu bulan

### **3. Memainkan Suara Adzan**

- Suara adzan akan otomatis diputar saat waktu sholat tiba. Pastikan file MP3 adzan (`adzan.mp3`) ada di `/root/jsholat`.

---

## **Struktur File Aplikasi**

Berikut adalah struktur file aplikasi yang diinstal:

```
/usr/bin/
├── jsholat          # Script utama untuk memainkan adzan
├── jsholat-bot      # Script untuk bot telegram Jsholat
├── jadwal           # Script untuk memperbarui jadwal sholat
├── jadwal-monthly   # Script python untuk memperbarui jadwal sholat bulanan
└── jadwal-update.sh # Script untuk memperbarui jadwal sholat dengan pengecekan

/etc/init.d/
├── jsholat          # Service untuk menjalankan aplikasi jsholat
├── jsholat-bot      # Service untuk menjalankan aplikasi Bot Telegram Jsholat
└── jadwal           # Service untuk memperbarui jadwal sholat

/root/jsholat/
├── adzan.mp3        # File suara adzan
├── adzan_subuh.mp3  # File suara adzan subuh
└── tarhim.mp3       # File suara tarhim (menjelang subuh)

/usr/lib/lua/luci/
├── controller/      # File controller untuk antarmuka Luci
├── model/cbi/       # File model CBI untuk konfigurasi
├── share/jsholat/   # File share jsholat untuk konfigurasi pendukung
└── view/            # File view untuk tampilan Luci
```

---

## **Cara Uninstall**

1. Hapus paket menggunakan perintah `jsi`:
   
   ```bash
   jsi
   ```
2. Pilih opsi 4.
3. Hapus file yang tidak terhapus otomatis (jika ada):
   
   ```bash
   rm -rf /usr/bin/jsholat /usr/bin/jadwal /usr/bin/jadwal2 /etc/init.d/jsholat /etc/init.d/jadwal /usr/share/sounds/adzan.mp3
   ```

---

## **Catatan**

- Pastikan perangkat memiliki koneksi internet saat menjalankan perintah `jadwal` atau `jadwal2` untuk memperbarui jadwal sholat.
- Jika suara adzan tidak terdengar, periksa konfigurasi ALSA dan pastikan `madplay` terinstal dengan benar.

---

## **Lisensi**

Aplikasi ini dilisensikan di bawah [Lisensi MIT](LICENSE).

---

Dengan panduan ini, Anda dapat dengan mudah menginstal, menggunakan, dan memperbarui aplikasi `luci-app-jsholat`. 

---

**Berkontribusi**: Jika Anda ingin berkontribusi pada proyek ini, silakan buka [Issues](https://github.com/ajisetiawan716/luci-app-jsholat/issues) atau ajukan Pull Request.

---
## **Credits**

- Jsholat (Original Script) - [Mikodemos Ragil](https://fb.com/mikodemos.ragil)
- Mesin Adzan OpenWRT (Inspired) - [Hanyasebuahpengalaman](https://hanyasebuahpengalaman.wordpress.com/2019/05/04/mesin-adzan-imsak-quran-30-juz-setiap-malam-auto-play-openwrt/) / [Khadafi Husein](https://www.facebook.com/groups/openwrt/permalink/2743751135665893/?app=fbl)

---
