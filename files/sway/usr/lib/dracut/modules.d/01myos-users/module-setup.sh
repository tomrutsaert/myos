#!/usr/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    # The early initramfs tools use /etc/passwd and /etc/group for name
    # resolution. On bootc/ostree systems Fedora's static system accounts live
    # under /usr/lib, so copy those databases into the initramfs /etc path to
    # avoid noisy "Unknown user/group" warnings from tmpfiles and udev.
    inst_simple /usr/lib/passwd /etc/passwd
    inst_simple /usr/lib/group /etc/group

    inst_simple /usr/lib/sysusers.d/basic.conf /usr/lib/sysusers.d/basic.conf
    inst_simple /usr/lib/sysusers.d/tpm2-tss.conf /usr/lib/sysusers.d/tpm2-tss.conf
}
