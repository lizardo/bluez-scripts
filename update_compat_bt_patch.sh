#!/bin/bash
set -e -u

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

echo "Extracting upstream kernel..." >&2
(cd linux && git archive --format=tar --prefix=linux-git/ integration) \
    | tar -C $tmp_dir -xf -

compat=$(egrep -o 'compat-wireless-[0-9-]{10}' README.rst)
echo "Extracting $compat.tar.bz2..." >&2
tar -C $tmp_dir -xf $compat.tar.bz2

patch -p1 -d $tmp_dir/$compat < compat-wireless-patches/pending-updates.patch

export QUILT_PATCHES=$tmp_dir/compat-patches
for p in 01-netdev.patch 14-device-type.patch 16-bluetooth.patch 21-capi-proc_fops.patch \
	25-multicast-list_head.patch 46-use_other_workqueue.patch; do
    cd $tmp_dir/linux-git
    quilt import $tmp_dir/$compat/patches/$p
    quilt push
    cd -
done

for d in net/bluetooth include/net/bluetooth; do
    (cd $tmp_dir && diff -x Kconfig -x "*.orig" -x Makefile -x .pc -Naurp $compat/$d linux-git/$d || true)
done > compat-wireless-patches/updates.patch
