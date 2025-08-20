include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-jsholat
PKG_VERSION:=0.1.0
PKG_RELEASE:=20250819
PKG_MAINTAINER:=Aji Setiawan <email@ajisetiawan.my.id>

# LuCI metadata
LUCI_TITLE:=LuCI app for JSholat (adzan & jadwal sholat)
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-compat +luci-lib-jsonc +luci-lib-json \
	+python3 +python3-requests +python3-pillow \
	+alsa-utils +madplay

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/description
 LuCI app untuk JSholat, termasuk pemutaran adzan dan pengelolaan jadwal sholat.
endef

# Siapkan sumber ke builddir (struktur: $(PKG_BUILD_DIR)/root dan $(PKG_BUILD_DIR)/luasrc)
define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
endef

# Simpan file config saat upgrade/remove
define Package/$(PKG_NAME)/conffiles
/etc/config/jsholat
endef

# Backup config sebelum install (opsional)
define Package/$(PKG_NAME)/preinst
#!/bin/sh
[ -f /etc/config/jsholat ] && cp -f /etc/config/jsholat /tmp/jsholat.config.bak || true
exit 0
endef

# Post-install: bereskan permission, unduh assets (non-fatal), enable service, refresh LuCI
define Package/$(PKG_NAME)/postinst
#!/bin/sh
set -e

download_if_missing() {
  URL="$$1"; DEST="$$2"
  DIR="$$(dirname "$$DEST")"
  [ -d "$$DIR" ] || mkdir -p "$$DIR"

  if [ -s "$$DEST" ]; then
    echo "Lewati: $$(basename "$$DEST") sudah ada."
    return 0
  fi

  echo "Mengunduh $$(basename "$$DEST") ..."
  if command -v uclient-fetch >/dev/null 2>&1; then
    uclient-fetch -q -O "$$DEST" "$$URL" || true
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$$DEST" "$$URL" || true
  fi

  if [ ! -s "$$DEST" ]; then
    echo "Peringatan: gagal mengunduh $$URL (lanjut tanpa file ini)"
    rm -f "$$DEST"
  fi
}

# Bersihkan cache LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

# Set permission direktori LuCI (aman meski tidak ada)
chmod -R 755 /usr/lib/lua/luci/controller 2>/dev/null || true
chmod -R 755 /usr/lib/lua/luci/model/cbi 2>/dev/null || true
chmod -R 755 /usr/lib/lua/luci/view 2>/dev/null || true

# Siapkan folder data
mkdir -p /root/jsholat

# Unduh audio pendukung (non-fatal)
echo "Sedang mengunduh file pendukung..."
download_if_missing "https://raw.githubusercontent.com/ajisetiawan716/luci-app-jsholat/refs/heads/main/sounds/adzan.mp3"       "/root/jsholat/adzan.mp3"
download_if_missing "https://raw.githubusercontent.com/ajisetiawan716/luci-app-jsholat/refs/heads/main/sounds/adzan_subuh.mp3" "/root/jsholat/adzan_subuh.mp3"
download_if_missing "https://raw.githubusercontent.com/ajisetiawan716/luci-app-jsholat/refs/heads/main/sounds/tarhim.mp3"      "/root/jsholat/tarhim.mp3"
chmod 0644 /root/jsholat/*.mp3 2>/dev/null || true

# Pastikan skrip & init bisa dieksekusi (jaga-jaga)
chmod 0755 /usr/bin/jsholat /usr/bin/jadwal /usr/bin/jadwal-update.sh /usr/bin/jsholat-bot /usr/bin/jadwal-monthly 2>/dev/null || true
chmod 0755 /etc/init.d/jsholat /etc/init.d/jadwal /etc/init.d/jsholat-bot 2>/dev/null || true

# Enable & start services bila tersedia
for SVC in jsholat jadwal jsholat-bot; do
  if [ -x "/etc/init.d/$${SVC}" ]; then
    /etc/init.d/$${SVC} enable
    /etc/init.d/$${SVC} start || true
  fi
done

# Restart web & rpcd
/etc/init.d/uhttpd restart 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true

# Bersihkan cache LuCI lagi
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

exit 0
endef

# Stop services saat remove
define Package/$(PKG_NAME)/prerm
#!/bin/sh
for SVC in jsholat jadwal jsholat-bot; do
	[ -x "/etc/init.d/$${SVC}" ] && /etc/init.d/$${SVC} stop || true
done
# Restore backup config jika ada (opsional)
[ -f /tmp/jsholat.config.bak ] && mv -f /tmp/jsholat.config.bak /etc/config/jsholat || true
exit 0
endef

# Post-remove: tidak hapus data user
define Package/$(PKG_NAME)/postrm
#!/bin/sh
exit 0
endef

# Instalasi ke image root (pakai INSTALL_* agar permission terjamin)
define Package/$(PKG_NAME)/install
	# Direktori dasar
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config

	# LuCI sources (controller/, model/, view/, dll)
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/

	# Binaries / scripts
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jsholat $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jadwal $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jadwal-update.sh $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jsholat-bot $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jadwal-monthly $(1)/usr/bin/

	# init scripts
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/jsholat $(1)/etc/init.d/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/jadwal $(1)/etc/init.d/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/jsholat-bot $(1)/etc/init.d/

	# config
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/root/etc/config/jsholat $(1)/etc/config/
endef

# Gunakan luci.mk agar metadata LuCI diproses otomatis
include $(TOPDIR)/feeds/luci/luci.mk

# Build paket
$(eval $(call BuildPackage,$(PKG_NAME)))
