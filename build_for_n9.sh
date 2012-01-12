#!/bin/bash
set -e -u

function apply_patch()
{
    p=$1; shift
    if ! patch --dry-run -t $@ < $p | grep -q '^Reversed.*patch detected'; then
        patch -r- $@ < $p
    fi
}

SBOX=$(readlink -f /scratchbox)
export PATH=/usr/lib/ccache:$SBOX/compilers/cs2009q3-eglibc2.10-armv7-hard/bin:$PATH
export CROSS_COMPILE=arm-none-linux-gnueabi-
export ARCH=arm

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

ksrc=$PWD/kernel-2.6.32
test -d $ksrc || tar -xvzf kernel_2.6.32-20113701.10+0m6.tar.gz
apply_patch kernel-disable_aegis.patch -d $ksrc -p0
apply_patch kernel-disable_bt.patch -d $ksrc -p0
mkdir -p $ksrc/build
sed -i '/^CONFIG_LOCALVERSION=/s/=.*/="-dfl61-20113701-le"/' \
    $ksrc/arch/arm/configs/rm581_defconfig
#test -f $ksrc/build/.config || make -C $ksrc O=$ksrc/build rm581_defconfig
make -C $ksrc O=$ksrc/build rm581_defconfig
make -C $ksrc -j2 O=$ksrc/build zImage modules
make -C $ksrc O=$ksrc/build INSTALL_MOD_PATH=$tmp_dir modules_install

mod_dir=$(cd $tmp_dir && ls -d lib/modules/*)

# compile compat-wireless (for bluetooth backport)
compat=compat-wireless-2012-01-09
test -d $compat || tar -xvjf $compat.tar.bz2
apply_patch compat-wireless-n9-adaptation.patch -d $compat -p1
apply_patch compat-bluetooth_updates.patch -d $compat -p1
apply_patch compat-wireless-enable_mgmt_le.patch -d $compat -p1
(cd $compat && ./scripts/driver-select bt)
export KLIB=$tmp_dir/$mod_dir
make -C $compat
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
make -j2
make DESTDIR=$tmp_dir/bluez-bin install
EOF

fakeroot tar -C $tmp_dir/bluez-bin/opt -cvf bluez-bin.tar bluez
