Build steps:

#. Install lzop (required for building the kernel)
#. Setup `Harmattan Platform SDK <http://harmattan-dev.nokia.com/docs/library/html/guide/html/Developer_Library_Alternative_development_environments_Platform_SDK_user_guide_Installing_Harmattan_Platform_SDK.html>`_
#. Get `N9 kernel source <http://harmattan-dev.nokia.com/pool/harmattan-beta3/free/k/kernel/kernel_2.6.32-20113701.10+0m6.tar.gz>`_
#. Get `wireless-compat source <http://linuxwireless.org/download/compat-wireless-2.6/compat-wireless-2011-12-18.tar.bz2>`_
#. Get BlueZ tree with latest LE development::

        git clone -b integration-v3 git://git.infradead.org/users/vcgomes/bluez.git

#. build bluez, kernel and modules::

        ./build_for_n9.sh

All done! Files built:

- kernel: kernel-2.6.32/build/arch/arm/boot/zImage
- kernel modules: kernel-modules.tar
- bluez: bluez-bin.tar

TODO:

- generate .deb for kernel modules and bluez
- document how to boot into the built kernel
