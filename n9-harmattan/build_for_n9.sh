#!/bin/bash
set -e -u

SBOX=$(readlink -f /scratchbox)
NJOBS=16
export PATH=/usr/lib/ccache:$SBOX/compilers/cs2009q3-eglibc2.10-armv7-hard/bin:$PATH
export CROSS_COMPILE=arm-none-linux-gnueabi-
export ARCH=arm

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

ksrc=$PWD/kernel-2.6.32
test -d $ksrc || tar -xzf $(egrep -o 'kernel_2.6.32-.*\.tar\.gz' README.rst)
export QUILT_PATCHES=$PWD/kernel-patches
cd $ksrc
if quilt unapplied; then
    quilt push -a
fi
cd -
mkdir -p $ksrc/build
sed -i '/^CONFIG_LOCALVERSION=/s/=.*/="-ble"/' \
    $ksrc/arch/arm/configs/rm581_defconfig
#test -f $ksrc/build/.config || make -C $ksrc O=$ksrc/build rm581_defconfig
make -C $ksrc O=$ksrc/build rm581_defconfig
make -C $ksrc -j$NJOBS O=$ksrc/build zImage modules
make -C $ksrc O=$ksrc/build INSTALL_MOD_PATH=$tmp_dir modules_install

mod_dir=$(cd $tmp_dir && ls -d lib/modules/*)

# compile compat-wireless (for bluetooth backport)
compat=$(egrep -o 'compat-wireless-[0-9-]{10}' README.rst)
test -d $compat || tar -xjf $compat.tar.bz2
export QUILT_PATCHES=$PWD/compat-wireless-patches
test -d $compat/drivers/bluetooth/hci_h4p || cp -a $ksrc/drivers/bluetooth/hci_h4p/ $compat/drivers/bluetooth
cd $compat
if quilt unapplied; then
    quilt push -a
fi
./scripts/driver-select bt
cd -
export KLIB=$tmp_dir/$mod_dir
make -C $compat -j$NJOBS
make -C $compat KMODPATH_ARG="INSTALL_MOD_PATH=$tmp_dir" install-modules

# fix modules.dep (otherwise device cannot load modules!)
sed -r -i -e "s,^(kernel|updates)/,/$mod_dir/\1/,g" \
    -e "s, (kernel|updates)/, /$mod_dir/\1/,g" \
    $tmp_dir/$mod_dir/modules.dep

# remove unnecessary symlinks
rm $tmp_dir/$mod_dir/{build,source}

fakeroot tar -C $tmp_dir/lib/modules -cf kernel-modules.tar $(basename $mod_dir)

(cd bluez/ && git archive --format=tar --prefix=bluez/ HEAD) | tar -C $tmp_dir -xf -
sb-conf se HARMATTAN_ARMEL
cat << EOF | scratchbox -s
set -e -u
cd $tmp_dir/bluez
./bootstrap-configure --prefix=/opt/bluez --sysconfdir=/opt/bluez/etc \
    --localstatedir=/opt/bluez/var --disable-maintainer-mode
make -j$NJOBS
make DESTDIR=$tmp_dir/bluez-bin install
mkdir -p $tmp_dir/bluez-bin/opt/bluez/etc/bluetooth

cat > $tmp_dir/bluez-bin/opt/bluez/etc/bluetooth/main.conf << "_EOF_"
[General]
DisablePlugins = network,hal
Name = Nokia N9
Class = 0x00020c
DiscoverableTimeout = 0
PairableTimeout = 0
PageTimeout = 10240
DiscoverSchedulerInterval = 0
InitiallyPowered = true
RememberPowered = false
ReverseServiceDiscovery = true
NameResolving = true
DebugKeys = false

# GATT specific
AutoConnectTimeout = 60
EnableGatt = true
_EOF_

cp profiles/proximity/proximity.conf $tmp_dir/bluez-bin/opt/bluez/etc/bluetooth/
cp tools/btmgmt $tmp_dir/bluez-bin/opt/bluez/bin
EOF

fakeroot tar -C $tmp_dir/bluez-bin/opt -cf bluez-bin.tar bluez
