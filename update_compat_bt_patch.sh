#!/bin/bash
set -e -u

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

echo "Extracting upstream kernel..." >&2
(cd ~/trees/linux.git && git archive --format=tar --prefix=linux-git/ vcgomes/integration-v5) \
    | tar -C $tmp_dir -xf -

compat=compat-wireless-2012-01-09
echo "Extracting $compat.tar.bz2..." >&2
tar -C $tmp_dir -xf $compat.tar.bz2

for p in 01-netdev.patch 14-device-type.patch 16-bluetooth.patch 21-capi-proc_fops.patch \
	25-multicast-list_head.patch 46-use_other_workqueue.patch; do
    patch --no-backup-if-mismatch -r- -tp1 -d $tmp_dir/linux-git < $tmp_dir/$compat/patches/$p || true
done

for d in net/bluetooth include/net/bluetooth; do
    (cd $tmp_dir && diff -x Kconfig -x "*.orig" -x Makefile -Naur $compat/$d linux-git/$d || true)
done > compat-bluetooth_updates.patch
