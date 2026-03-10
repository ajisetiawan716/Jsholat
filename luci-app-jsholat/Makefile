include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-jsholat
PKG_VERSION:=0.1.8
PKG_RELEASE:=20260310
PKG_MAINTAINER:=Aji Setiawan <email@ajisetiawan.my.id>

LUCI_TITLE:=LuCI app for JSholat (adzan & jadwal sholat)
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-compat +luci-lib-jsonc +luci-lib-json \
	+python3 +python3-requests \
	+alsa-utils +jq +madplay +mpg123

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/description
 LuCI app untuk JSholat, termasuk pemutaran adzan,
 pengelolaan jadwal sholat, serta manajemen via bot Telegram.
endef


# ================================
# Build
# ================================
define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)/
endef

define Build/Configure
endef

define Build/Compile
endef

# Config file dipertahankan
define Package/$(PKG_NAME)/conffiles
/etc/config/jsholat
endef

# Post-install
define Package/$(PKG_NAME)/postinst
#!/bin/sh

# Bersihkan cache LuCI
rm -f /tmp/luci-indexcache /tmp/luci-modulecache/* 2>/dev/null || true

# Pastikan direktori data ada
mkdir -p /root/jsholat 2>/dev/null || true

# Pastikan executable
chmod 0755 /usr/bin/jsholat 2>/dev/null || true
chmod 0755 /usr/bin/jadwal 2>/dev/null || true
chmod 0755 /usr/bin/jadwal-update.sh 2>/dev/null || true
chmod 0755 /usr/bin/jsholat-bot 2>/dev/null || true
chmod 0755 /usr/bin/jadwal-monthly 2>/dev/null || true
chmod 0755 /usr/bin/fix-hda 2>/dev/null || true
chmod 0755 /usr/share/jsholat/bot-checker.sh 2>/dev/null || true

chmod 0755 /etc/init.d/jsholat 2>/dev/null || true
chmod 0755 /etc/init.d/jadwal 2>/dev/null || true
chmod 0755 /etc/init.d/jsholat-bot 2>/dev/null || true
chmod 0755 /etc/init.d/fix-hda 2>/dev/null || true

# Jalankan uci-defaults jika ada
if [ -d /etc/uci-defaults ]; then
	for f in /etc/uci-defaults/*; do
		[ -f "$$f" ] && sh "$$f"
	done
fi

# Enable service (tanpa paksa start keras)
for SVC in jsholat jadwal jsholat-bot; do
	if [ -x "/etc/init.d/$$SVC" ]; then
		/etc/init.d/$$SVC enable
		/etc/init.d/$$SVC start 2>/dev/null || true
	fi
done

exit 0
endef

# Pre-remove
define Package/$(PKG_NAME)/prerm
#!/bin/sh
for SVC in jsholat jadwal jsholat-bot; do
	[ -x "/etc/init.d/$$SVC" ] && /etc/init.d/$$SVC stop || true
done
exit 0
endef

# Install files
define Package/$(PKG_NAME)/install

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/share/jsholat
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/uci-defaults

	# LuCI
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/

	# Scripts
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jsholat $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jadwal $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jadwal-update.sh $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jsholat-bot $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/jadwal-monthly $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/bin/fix-hda $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/share/jsholat/bot-checker.sh $(1)/usr/share/jsholat

	# init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/jsholat $(1)/etc/init.d/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/jadwal $(1)/etc/init.d/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/jsholat-bot $(1)/etc/init.d/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/init.d/fix-hda $(1)/etc/init.d/

	# uci-defaults
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/uci-defaults/50-jsholat $(1)/etc/uci-defaults/
endef


include $(TOPDIR)/feeds/luci/luci.mk
$(eval $(call BuildPackage,$(PKG_NAME)))