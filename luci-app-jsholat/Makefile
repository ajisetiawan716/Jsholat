include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-jsholat
PKG_VERSION:=0.1.0
PKG_RELEASE:=beta
PKG_MAINTAINER:=Aji Setiawan <email@ajisetiawan.my.id>

# LuCI metadata
LUCI_TITLE:=LuCI app for JSholat (adzan & jadwal sholat)
LUCI_PKGARCH:=all
# Tambah/kurangi sesuai kebutuhan paketmu
LUCI_DEPENDS:=+luci-compat +luci-lib-jsonc +luci-lib-json \
	+python3 +python3-requests +python3-pillow \
	+alsa-utils +madplay

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

# (Opsional) deskripsi paket "gaya OpenWrt classic"
define Package/$(PKG_NAME)/description
 LuCI app untuk JSholat, termasuk pemutaran adzan dan pengelolaan jadwal sholat.
endef

# Siapkan konten builddir dari tree sumber (root/ dan luasrc/)
define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)/

	# Pastikan permission skrip & init benar sebelum diinstall
	[ -d "$(PKG_BUILD_DIR)/root/usr/bin" ] && chmod 0755 \
		$(PKG_BUILD_DIR)/root/usr/bin/jsholat \
		$(PKG_BUILD_DIR)/root/usr/bin/jadwal \
		$(PKG_BUILD_DIR)/root/usr/bin/jadwal-update.sh \
		$(PKG_BUILD_DIR)/root/usr/bin/jsholat-bot \
		$(PKG_BUILD_DIR)/root/usr/bin/jadwal-monthly || true

	[ -d "$(PKG_BUILD_DIR)/root/etc/init.d" ] && chmod 0755 \
		$(PKG_BUILD_DIR)/root/etc/init.d/jsholat \
		$(PKG_BUILD_DIR)/root/etc/init.d/jadwal \
		$(PKG_BUILD_DIR)/root/etc/init.d/jsholat-bot || true
endef

define Build/Configure
endef

define Build/Compile
endef

# File konfigurasi yang dipertahankan saat upgrade/remove
define Package/$(PKG_NAME)/conffiles
/etc/config/jsholat
endef

# Backup config sebelum install (opsional, kalau kamu butuh)
define Package/$(PKG_NAME)/preinst
#!/bin/sh
[ -f /etc/config/jsholat ] && cp -f /etc/config/jsholat /tmp/jsholat.config.bak || true
exit 0
endef

# Post-install: pakai skripmu (diringkas & dirapikan sedikit)
define Package/$(PKG_NAME)/postinst
#!/bin/sh
set -e

# ==== Helper: unduh hanya jika belum ada ====
download_if_missing() {
	URL="$1"; DEST="$2"
	DIR="\$$(dirname "\$$DEST")"
	[ -d "\$$DIR" ] || mkdir -p "\$$DIR"
	if [ -s "\$$DEST" ]; then
		echo "Lewati: \$$(basename "\$$DEST") sudah ada."; return 0
	fi
	echo "Mengunduh \$$(basename "\$$DEST") ..."
	if wget -q -O "\$$DEST" "\$$URL"; then
		[ -s "\$$DEST" ] || { echo "Gagal: file kosong."; rm -f "\$$DEST"; exit 1; }
	else
		echo "Gagal mengunduh: \$$URL"; rm -f "\$$DEST"; exit 1
	fi
}

# Bersihkan cache LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

# Permission untuk direktori LuCI
chmod -R 755 /usr/lib/lua/luci/controller 2>/dev/null || true
chmod -R 755 /usr/lib/lua/luci/model/cbi 2>/dev/null || true
chmod -R 755 /usr/lib/lua/luci/view 2>/dev/null || true

# Siapkan folder data
mkdir -p /root/jsholat

# Unduh audio pendukung (skip kalau sudah ada)
echo "Sedang mengunduh file pendukung..."
download_if_missing "https://raw.githubusercontent.com/ajisetiawan716/luci-app-jsholat/refs/heads/main/sounds/adzan.mp3"       "/root/jsholat/adzan.mp3"
download_if_missing "https://raw.githubusercontent.com/ajisetiawan716/luci-app-jsholat/refs/heads/main/sounds/adzan_subuh.mp3" "/root/jsholat/adzan_subuh.mp3"
download_if_missing "https://raw.githubusercontent.com/ajisetiawan716/luci-app-jsholat/refs/heads/main/sounds/tarhim.mp3"      "/root/jsholat/tarhim.mp3"

chmod 0644 /root/jsholat/*.mp3 2>/dev/null || true

# Pastikan skrip bisa dieksekusi
chmod 0755 /usr/bin/jsholat /usr/bin/jadwal /usr/bin/jadwal-update.sh /usr/bin/jsholat-bot /usr/bin/jadwal-monthly 2>/dev/null || true

# Enable & start services bila tersedia
for SVC in jsholat jadwal jsholat-bot; do
	if [ -f "/etc/init.d/\$${SVC}" ]; then
		/etc/init.d/\$${SVC} enable
		/etc/init.d/\$${SVC} start || true
	fi
done

# Restart web & rpcd
/etc/init.d/uhttpd restart 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true

# Bersihkan cache LuCI lagi
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

exit 0
endef

# Pre-remove: stop services
define Package/$(PKG_NAME)/prerm
#!/bin/sh
for SVC in jsholat jadwal jsholat-bot; do
	[ -x "/etc/init.d/\$${SVC}" ] && /etc/init.d/\$${SVC} stop || true
done
# Restore backup config jika ada (opsional)
[ -f /tmp/jsholat.config.bak ] && mv -f /tmp/jsholat.config.bak /etc/config/jsholat || true
exit 0
endef

# Post-remove: optional cleanup ringan
define Package/$(PKG_NAME)/postrm
#!/bin/sh
# Jangan hapus /root/jsholat biar file audio user tetap ada
exit 0
endef

# Instalasi ke image root
define Package/$(PKG_NAME)/install
	# Buat direktori target utama
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/usr/share
	$(INSTALL_DIR) $(1)/www

	# Copy seluruh tree root/* sesuai struktur source
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/

	# Pastikan file LuCI berpindah ke path yang benar
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
endef

# Gunakan luci.mk agar metadata LuCI (menu, index, dsb) diproses otomatis
include $(TOPDIR)/feeds/luci/luci.mk

# Build paket
$(eval $(call BuildPackage,$(PKG_NAME)))
