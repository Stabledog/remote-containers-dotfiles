#!/bin/bash
# Install dotfiles in a devcontainer.
# Preferred approach is to have the HOME host environment share readonly with the container as /host_home
# Then install_from_host_home() can copy and filter as needed.

#  HOWTO: specify /host_home share in devcontainer.json:
#       "mounts": [ "source=${localEnv:HOME},target=/host_home,type=bind,readonly" ]
#

die() {
    echo "ERROR: $*" >&2
    exit 1
}

install_from_host_home() {
    # Assuming there's a /host_home share which gives us access to all the host's dotfiles:
    local host_home=/host_home
    cd ~ || die "Can't cd to ~"
    for dir_name in bin .local/bin/cdpp .local/bin/localhost; do
        (
            [[ -d $dir_name ]] || {
                mkdir -p $dir_name || die "Can't create ~/${dir_name}"
            }
            cd $dir_name || die "Can't cd to ~/${dir_name}"
            rsync -av ${host_home}/${dir_name}/ . || die "Can't rsync ${dir_name}"
        )
    done
    [[ -d ~/bin ]] || {
        mkdir ~/bin  || die "Can't create ~/bin"
    }
}

main() {
    [[ -d /host_home ]] && {
        install_from_host_home "$@"
    }
}

[[ -z $sourceMe ]] &&  {
    echo "remote-containers-dotfiles/install.sh startup: args[$*]"
    main "$@"
}
