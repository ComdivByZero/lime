#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    cd "$1" && shift && /usr/bin/sudo -u $SUDO_USER "$@"
    exit $?
fi

THIS="$0"
MEMORY="$1"
TMP="$2"
shift 2

cgo() {
    local RET CMDS CGROUP PWD

    cgnew() {
        CGROUP=$(basename $(mktemp --dry-run --tmpdir=/sys/fs/cgroup lime_XXXXX))
        cgcreate -t "$SUDO_USER:$SUDO_USER" -g memory:$CGROUP
        cgset -r memory.max="$MEMORY" -r memory.swap.max=0 $CGROUP        
    }
    cgdel() {
        while [ -n "$(dd if=/sys/fs/cgroup/$CGROUP/cgroup.procs 2>/dev/null bs=1 count=1)" ]; do sleep 1; done
        cgdelete -g memory:$CGROUP
    }

    if [ -n "$TMP" ]; then
        PWD="$(pwd)"
        chown root:root $TMP/root/home
        mount --types overlay overlay --options lowerdir=/,upperdir=$TMP/root,workdir=$TMP/work $TMP/chroot
        for FS in proc sys dev run; do
            mount --rbind /$FS $TMP/chroot/$FS
        done
        mount --types tmpfs tmpfs $TMP/chroot/tmp &&
        chmod 1777 $TMP/chroot/tmp
        mount --bind "$PWD" $TMP/chroot"$PWD"

        cgnew
        cgexec -g memory:$CGROUP chroot --userspec $SUDO_USER:$SUDO_USER $TMP/chroot "$THIS" "$PWD" "$@"
        RET=$?
        cgdel

        umount --read-only "$TMP"/chroot"$PWD" && rmdir --parents $TMP/root"$PWD" 2>/dev/null
        for FS in tmp proc sys dev run ""; do
            umount --read-only $TMP/chroot/$FS 2>/dev/null
        done
    else
        cgnew
        cgexec -g memory:$CGROUP /usr/bin/sudo -u $SUDO_USER "$@"
        RET=$?
        cgdel
    fi
    return $RET
}

[ -n "$MEMORY" ] && [ -n "$*" ] && [ -n "$SUDO_USER" ] && cgo "$@"
