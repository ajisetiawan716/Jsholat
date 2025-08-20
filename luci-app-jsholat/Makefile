include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-jsholat
PKG_VERSION:=0.1.0
PKG_RELEASE:=20250820
PKG_MAINTAINER:=Aji Setiawan <email@ajisetiawan.my.id>

# LuCI metadata
LUCI_TITLE:=LuCI app for JSholat (adzan & jadwal sholat)
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-compat +luci-lib-jsonc +luci-lib-json \
	+python3 +python3-requests \
	+alsa-utils +madplay +mpg123

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/description
 LuCI app untuk JSholat, termasuk pemutaran adzan dan pengelolaan jadwal sholat.
endef

# --- Build stages (copy tree sumber) ---
define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
endef

# --- Config file yang dipertahankan ---
define Package/$(PKG_NAME)/conffiles
/etc/config/jsholat
endef

# --- Preinst: backup config (opsional) ---
define Package/$(PKG_NAME)/preinst
#!/bin/sh
[ -f /etc/config/jsholat ] && cp -f /etc/config/jsholat /tmp/jsholat.config.bak || true
exit 0
endef

# --- Postinst: TANPA download aset, ash-safe ---
define Package/$(PKG_NAME)/postinst
#!/bin/sh
set -e

# Bersihkan cache LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

# Pastikan direktori data ada (tanpa file MP3)
mkdir -p /root/jsholat 2>/dev/null || true

# Set permission direktori/file LuCI (aman walau tidak ada)
chmod -R 755 /usr/lib/lua/luci/controller 2>/dev/null || true
chmod -R 755 /usr/lib/lua/luci/model/cbi 2>/dev/null || true
chmod -R 755 /usr/lib/lua/luci/view 2>/dev/null || true

# Pastikan skrip & init bisa dieksekusi
chmod 0755 /usr/bin/jsholat /usr/bin/jadwal /usr/bin/jadwal-update.sh /usr/bin/jsholat-bot /usr/bin/jadwal-monthly 2>/dev/null || true
chmod 0755 /etc/init.d/jsholat /etc/init.d/jadwal /etc/init.d/jsholat-bot 2>/dev/null || true

# Enable & start services (fallback via sh kalau belum +x)
for SVC in jsholat jadwal jsholat-bot; do
  if [ -f "/etc/init.d/$${SVC}" ]; then
    if [ -x "/etc/init.d/$${SVC}" ]; then
      /etc/init.d/$${SVC} enable
      /etc/init.d/$${SVC} start || true
    else
      sh /etc/init.d/$${SVC} enable
      sh /etc/init.d/$${SVC} start || true
    fi
  fi
done

# Restart web & rpcd (non-fatal)
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart 2>/dev/null || true
[ -x /etc/init.d/rpcd ]   && /etc/init.d/rpcd restart   2>/dev/null || true

# Bersihkan cache LuCI lagi
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

exit 0
endef

# --- Prerm: stop services & restore backup config ---
define Package/$(PKG_NAME)/prerm
#!/bin/sh
for SVC in jsholat jadwal jsholat-bot; do
	[ -x "/etc/init.d/$${SVC}" ] && /etc/init.d/$${SVC} stop || true
done
[ -f /tmp/jsholat.config.bak ] && mv -f /tmp/jsholat.config.bak /etc/config/jsholat || true
exit 0
endef

# --- Postrm: tidak hapus data user ---
define Package/$(PKG_NAME)/postrm
#!/bin/sh
exit 0
endef

# --- Install files (gunakan INSTALL_* agar permission terjamin) ---
define Package/$(PKG_NAME)/install
	# Direktori dasar
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config

	# LuCI sources
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

# Proses metadata LuCI & build package
include $(TOPDIR)/feeds/luci/luci.mk
$(eval $(call BuildPackage,$(PKG_NAME)))
