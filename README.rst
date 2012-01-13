Building BlueZ, kernel and modules for N9
=========================================

#. Install lzop (required for building the kernel).
#. Setup `Harmattan Platform SDK <http://harmattan-dev.nokia.com/docs/library/html/guide/html/Developer_Library_Alternative_development_environments_Platform_SDK_user_guide_Installing_Harmattan_Platform_SDK.html>`_.
#. Get `N9 kernel source <http://harmattan-dev.noki.a.com/pool/harmattan-beta3/free/k/kernel/kernel_2.6.32-20113701.10+0m6.tar.gz>`_. Save the tarball onto the same directory as the "build_for_n9.sh" script.
#. Get `wireless-compat source <http://linuxwireless.org/download/compat-wireless-2.6/compat-wireless-2012-01-09.tar.bz2>`_. Save the tarball onto the same directory as "build_for_n9.sh".
#. Get BlueZ tree with latest LE development::

        git clone -b new-messages-v2 git://git.infradead.org/users/vcgomes/bluez.git

This tree should also be on the same directory as "build_for_n9.sh".

#. build bluez, kernel and modules::

        ./build_for_n9.sh

All done! Files built:

- kernel: kernel-2.6.32/build/arch/arm/boot/zImage
- kernel modules: kernel-modules.tar
- bluez: bluez-bin.tar

Building a .deb package and installing on the N9
================================================

Run this command to build a .deb from kernel-modules.tar and bluez-bin.tar::

        ./create_deb_for_n9.sh

This will generate a bluez-le_armel.deb file. Install this package on the N9 by
making it available somewhere over HTTP, enabling installation from non-Store
sources:

Settings > Applications > Installations > Allow installations from non-Store sources

Download the package using the Web Browser, and install it by opening the file
on the "Transfers" window.

Booting the custom kernel on N9
===============================

To boot the custom kernel (without flashing it), run::

        sudo flasher -k kernel-2.6.32/build/arch/arm/boot/zImage -l -b

You can alternatively flash it permanently, but this is not recommended because
you may need to flash the entire device again to restore to a "pristine" state.

As long as any Aegis protected files are not touched (including not installing
anything while booting the custom kernel), you can return to the official
kernel just by rebooting the device.
