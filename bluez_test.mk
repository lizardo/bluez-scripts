#!/usr/bin/make -f
# "All in one" script for various BlueZ development tasks

SHELL = /bin/bash
PATH := /usr/lib/ccache:$(PATH)
export PATH

PREFIX = /opt/bluez
BLUEZ_SRC = $(HOME)/trees/bluez.git
KSRC = $(HOME)/trees/linux.git
VM_LIST = vmprecise
MAX_JOBS = 4
GIT_BASE = upstream/master
GLIB_PREFIX = /opt/glib
DBUS_CONF = /etc/dbus-1/system.d/bluetooth.conf

all:
	@echo -e \\nAvailable targets:\\n
	@sed -n '/^all:/d; s/^\([^#_][^:]*\):$$/\t\1/p' $(lastword $(MAKEFILE_LIST))
	@echo

build:
	git clean -dfx && ctags -R
#	PKG_CONFIG_PATH=$(GLIB_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
	./bootstrap-configure \
		--prefix=$(PREFIX) \
		--sysconfdir=$(PREFIX)/etc \
		--localstatedir=$(PREFIX)/var \
		--disable-systemd $(extra_flags)
	make -j$(MAX_JOBS)

build_gcov:
	PATH=$(subst /usr/lib/ccache:,,$(PATH)) CFLAGS="--coverage -g" LDFLAGS="--coverage" \
		make -f $(lastword $(MAKEFILE_LIST)) build extra_flags=--disable-optimization

install:
	make -f $(lastword $(MAKEFILE_LIST)) tmpdir=`mktemp -d /tmp/bluez.XXXXXXXXXX` _$@

_install:
	make DESTDIR=$(tmpdir) install
	install -D -m644 src/bluetooth.conf $(tmpdir)$(PREFIX)/etc/dbus-1/system.d/bluetooth.conf
	test ! -d $(GLIB_PREFIX)/lib || cp -a $(GLIB_PREFIX)/lib/* $(tmpdir)$(PREFIX)/lib
	# write a suppressions file for valgrind
	@echo "\
	{ sup2 Memcheck:Free fun:free fun:__libc_freeres fun:_Exit } \
	" | tr ' ' '\n' > $(tmpdir)$(PREFIX)/etc/bluetoothd.sup
#	{ sup1 Memcheck:Param capget(data) fun:capget fun:capng_clear } \
#	{ sup3 Memcheck:Param ioctl(generic) fun:ioctl fun:init_known_adapters } \
#	{ sup4 Memcheck:Param ioctl(generic) fun:ioctl fun:device_event fun:io_stack_event } \
#	{ sup5 Memcheck:Param ioctl(generic) fun:ioctl fun:adapter_remove fun:manager_remove_adapter } \
#	{ sup6 Memcheck:Param ioctl(generic) fun:ioctl fun:start_adapter fun:init_adapter } \
#	{ sup7 Memcheck:Param ioctl(generic) fun:ioctl fun:hciops_restore_powered fun:adapter_remove fun:manager_remove_adapter } \
#	{ sup8 Memcheck:Param ioctl(generic) fun:ioctl fun:hciops_set_powered fun:set_mode fun:set_powered } \
#	{ sup9 Memcheck:Param ioctl(generic) fun:ioctl fun:set_mode fun:set_discoverable fun:set_powered }
	# helper script to run bluetoothd under valgrind
	@echo -e "#!/bin/sh\nset -e -u\n\
	rm -rf $(PREFIX)/var/lib/bluetooth\nmkdir -p $(PREFIX)/var/lib/bluetooth\n\
	env G_SLICE=always-malloc valgrind --track-fds=yes --leak-check=full \
	--suppressions=$(PREFIX)/etc/bluetoothd.sup $(PREFIX)/libexec/bluetooth/bluetoothd -n -d \"\$$@\" 2>&1 | \
	tee -i /tmp/bluetooth.log" > $(tmpdir)$(PREFIX)/bin/run_bluetoothd.sh
	chmod 755 $(tmpdir)$(PREFIX)/bin/run_bluetoothd.sh
	$(foreach vm,$(VM_LIST),rsync -a --progress --delete $(tmpdir)$(PREFIX)/ root@$(vm):$(PREFIX)/;)
	rm -rf $(tmpdir)
	@$(foreach vm,$(VM_LIST),ssh -q ubuntu@$(vm) sh -c '"diff -q $(PREFIX)$(DBUS_CONF) $(DBUS_CONF) || \
	sudo cp -v $(PREFIX)$(DBUS_CONF) $(DBUS_CONF)"';)

test_build:
	git diff $(GIT_BASE)..HEAD | $(KSRC)/scripts/checkpatch.pl \
		--no-signoff --ignore INITIALISED_STATIC,NEW_TYPEDEFS,VOLATILE,CAMELCASE --show-types --mailback -
	git test-sequence $(GIT_BASE).. 'git clean -dfx && ./bootstrap-configure --disable-systemd && make -j$(MAX_JOBS)'
	make distcheck

bdaddr:
	@$(foreach vm,$(VM_LIST),ssh root@$(vm) $(PREFIX)/sbin/hciconfig;)

#flash_st:
#	$(foreach vm,$(VM_LIST),cat $(SCRIPTS)/run_st_macro_file.py | ssh -qt root@$(vm) python - /dev/ttyUSB2 /root/ST_PG2.0.bin;)

reboot poweroff:
	@$(foreach vm,$(VM_LIST),ssh -qt root@$(vm) $@;)

define _kpkg
linux-image-`cat $(KSRC)/build/include/config/kernel.release`_`cat $(KSRC)/build/include/config/kernel.release`-`cat $(KSRC)/build/.version`_i386.deb
endef

install_kernel:
	rm -f $(KSRC)/*.deb
	make -C $(KSRC) --quiet O=build oldnoconfig
	make -C $(KSRC) --quiet -j$(MAX_JOBS) O=build deb-pkg
	$(foreach vm,$(VM_LIST),scp $(KSRC)/$(_kpkg) root@$(vm):/tmp && ssh -qt root@$(vm) sh -c "'dpkg -i /tmp/$(_kpkg)'";)

lcov:
	lcov --capture --directory $(BLUEZ_SRC) --base-directory $(BLUEZ_SRC) --output-file $(BLUEZ_SRC)/lcov.info --test-name bluez
	genhtml $(BLUEZ_SRC)/lcov.info --output-directory $(BLUEZ_SRC)/lcov --title "BlueZ coverage" --show-details --legend --prefix $(BLUEZ_SRC)
	#firefox $(BLUEZ_SRC)/lcov/index.html

#pair:
#	@expect -c '\
#	set timeout -1;\
#	spawn ssh -t root@$(vm2) $(PREFIX)/bin/simple-agent hci0;\
#	expect "Agent registered\r";\
#	spawn ssh -t root@$(vm1) $(PREFIX)/bin/simple-agent hci0 $(bdaddr2);\
#	expect "Release\r";\
#	expect -re "New device (.*)\r";\
#	spawn ssh root@$(vm2) $(PREFIX)/bin/test-device -i hci0 trusted $(bdaddr1) yes;\
#	expect eof'

.PHONY: lcov
