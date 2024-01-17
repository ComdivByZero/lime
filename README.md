# lime
**Lim**ited **e**xecution of command in GNU/Linux.
Restrict maximum memory usage and home directory access.

## Usage

    # limit memory by 1 GiB, access to the current directory only
    lime  cmd arg1 arg2 ...

    # limit memory by 4 GiB, access to the current directory only
    lime 4G  make all

    # limit memory by 128 MiB, unrestricted access to directories
    lime / 128M  find ~ -name "*.png"

## Install

    /usr/bin/sudo apt install cgroup-tools debootstrap trash-cli

    git clone https://github.com/ComdivByZero/lime.git --depth 1 && cd lime &&
    /usr/bin/sudo sh -c 'P=/usr/local; R=/etc/sudoers.d/lime
    cp lime $P/bin/
    cp lime_backend.sh $P/lib/
    echo "%sudo ALL=(root) NOPASSWD: $P/lib/lime_backend.sh" >> $R
    chmod 0440 $R
    visudo --check'
