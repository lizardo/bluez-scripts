#!/bin/bash
set -e -u

tmp_dir=$(mktemp -d)
trap "rm -rf $tmp_dir" EXIT

echo "Extracting upstream kernel..." >&2
(cd ~/trees/linux.git && git archive --format=tar --prefix=linux-git/ vcgomes/integration-v3) \
    | tar -C $tmp_dir -xf -

compat=compat-wireless-2011-12-18
echo "Extracting $compat.tar.bz2..." >&2
tar -C $tmp_dir -xf ~/Downloads/$compat.tar.bz2 

for p in 08-rename-config-options.patch 16-bluetooth.patch \
        31-backport-sk_add_backlog.patch; do
    patch --no-backup-if-mismatch -r- -tp1 -d $tmp_dir/linux-git < $tmp_dir/$compat/patches/$p || true
done

for d in net/bluetooth include/net/bluetooth; do
    (cd $tmp_dir && diff -x Kconfig -x sco.h -x bnep -x cmtp -Naur $compat/$d linux-git/$d || true)
done > compat-bluetooth_updates.patch
