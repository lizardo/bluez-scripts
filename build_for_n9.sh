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
test -d $ksrc || tar -xvzf kernel_2.6.32-20113701.10+0m6.tar.gz
export QUILT_PATCHES=$PWD/kernel-patches
cd $ksrc
if quilt unapplied; then
    quilt push -a
fi
cd -
mkdir -p $ksrc/build
sed -i '/^CONFIG_LOCALVERSION=/s/=.*/="-dfl61-20113701-le"/' \
    $ksrc/arch/arm/configs/rm581_defconfig
#test -f $ksrc/build/.config || make -C $ksrc O=$ksrc/build rm581_defconfig
make -C $ksrc O=$ksrc/build rm581_defconfig
make -C $ksrc -j$NJOBS O=$ksrc/build zImage modules
make -C $ksrc O=$ksrc/build INSTALL_MOD_PATH=$tmp_dir modules_install

mod_dir=$(cd $tmp_dir && ls -d lib/modules/*)

# compile compat-wireless (for bluetooth backport)
compat=$(egrep -o 'compat-wireless-[0-9-]{10}' README.rst)
test -d $compat || tar -xvjf $compat.tar.bz2
export QUILT_PATCHES=$PWD/compat-wireless-patches
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

fakeroot tar -C $tmp_dir/lib/modules -cvf kernel-modules.tar $(basename $mod_dir)

(cd bluez/ && git archive --format=tar --prefix=bluez/ HEAD) | tar -C $tmp_dir -xvf -
sb-conf se HARMATTAN_ARMEL
cat << EOF | scratchbox -s
set -e -u
cd $tmp_dir/bluez
./bootstrap-configure --prefix=/opt/bluez --sysconfdir=/opt/bluez/etc \
    --localstatedir=/opt/bluez/var --enable-maemo6 --disable-capng \
    --disable-maintainer-mode --with-time=timed
make -j$NJOBS
make DESTDIR=$tmp_dir/bluez-bin install
mkdir -p $tmp_dir/bluez-bin/opt/bluez/etc/bluetooth
sed 's/^AttributeServer = false/AttributeServer = true/' src/main.conf > \
    $tmp_dir/bluez-bin/opt/bluez/etc/bluetooth/main.conf
cp proximity/proximity.conf $tmp_dir/bluez-bin/opt/bluez/etc/bluetooth/
EOF

fakeroot tar -C $tmp_dir/bluez-bin/opt -cvf bluez-bin.tar bluez
