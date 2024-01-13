#!/bin/bash

MEMORY="$1"
TMP="$2"
shift 2
CMD=("$@")

PWD="$(pwd)"

cgo() {
    local ret CMDS CGROUP

    if [ -n "$TMP" ]; then
        mount $(df / | awk 'END{print $1}') $TMP/root
        for FS in /proc /sys /dev /run; do
            mount --rbind $FS $TMP/root$FS
        done

        mount --types tmpfs tmpfs $TMP/root/tmp &&
        chmod 1777 $TMP/root/tmp

        mount --bind $TMP/home $TMP/root/home &&
        mount --bind "$PWD" $TMP/root"$PWD"
    fi

    CGROUP=$(basename $(mktemp --dry-run --tmpdir=/sys/fs/cgroup lime_XXXXX))
    cgcreate -t "$SUDO_USER:$SUDO_USER" -g memory:$CGROUP
    cgset -r memory.max="$MEMORY" -r memory.swap.max=0 $CGROUP

    if [ -n "$TMP" ]; then
        printf -v CMDS '%q ' "${CMD[@]}"
        cgexec -g memory:$CGROUP chroot $TMP/root bash -c "cd $PWD; exec /usr/bin/sudo -u $SUDO_USER $CMDS"
        ret=$?
    else
        cgexec -g memory:$CGROUP /usr/bin/sudo -u $SUDO_USER "${CMD[@]}"
        ret=$?
    fi

    while [ -n "$(dd if=/sys/fs/cgroup/$CGROUP/cgroup.procs 2>/dev/null bs=1 count=1)" ]; do sleep 1; done
    cgdelete -g memory:$CGROUP

    if [ -n "$TMP" ]; then
        umount --read-only $TMP/root"$PWD" && rmdir --parents "$TMP/root$PWD" 2>/dev/null
        for FS in /home /tmp /proc /sys /dev /run ""; do
            umount --read-only "$TMP"/root"$FS" 2>/dev/null
        done
    fi

    return $ret
}

if [ -n "$MEMORY" ] && [ -n "$CMD" ] && [ -n "$SUDO_USER" ]; then
    cgo
    exit $?
else
    exit 1
fi
