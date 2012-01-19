#!/bin/bash
set -e -u

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

mkdir -p $tmp_dir/bluez-le/{DEBIAN,opt,lib/modules,etc/init/xsession,etc/dbus-1}

cp bluetoothd-le.conf $tmp_dir/bluez-le/etc/init/xsession/
cp system-local.conf $tmp_dir/bluez-le/etc/dbus-1/

tar -C $tmp_dir/bluez-le/opt -xf bluez-bin.tar
tar -C $tmp_dir/bluez-le/lib/modules -xf kernel-modules.tar

cp DEBIAN.control $tmp_dir/bluez-le/DEBIAN/control
echo "Installed-Size: $(du -k -s $tmp_dir/bluez-le | awk '{print $1}')" >> $tmp_dir/bluez-le/DEBIAN/control

cat > $tmp_dir/bluez-le/DEBIAN/preinst << "EOF"
#!/bin/sh -e

if ! accli -I | grep -q '^Current mode: normal'; then
    echo "ERROR: This package should be installed on normal mode (i.e. with signed kernel)." >&2
    exit 1
fi

exit 0
EOF
chmod 755 $tmp_dir/bluez-le/DEBIAN/preinst

fakeroot dpkg -b $tmp_dir/bluez-le bluez-le_armel.deb
