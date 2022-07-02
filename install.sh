#!/bin/bash
# Install dotfiles in a devcontainer.
# Preferred approach is to have the HOME host environment share readonly with the container as /host_home
# Then install_from_host_home() can copy and filter as needed.

#  HOWTO: specify /host_home share in devcontainer.json:
#       "mounts": [ "source=${localEnv:HOME},target=/host_home,type=bind,readonly" ]
#


cout() {
    sed 's%^%[remote-containers-dotfiles/install.sh]:%'
}

cerr() {
    sed 's%^%[remote-containers-dotfiles/install.sh]:%' >&2
}

die() {
    echo "ERROR: $*" | cerr
    exit 1
}

install_from_host_home() {
    # Assuming there's a /host_home share which gives us access to all the host's dotfiles:
    local host_home=/host_home
    cd ~ || die "Can't cd to ~"
    # We also might want to do maintenance on remote-containers-dotfiles from the host's copy:
    [[ -d $host_home/remote-containers-dotfiles ]] && {
        ( cd ~/remote-containers-dotfiles && git remote add host_home ${host_home}/remote-containers-dotfiles && git fetch host_home )
    }
    for dir_name in bin .local/bin/cdpp .local/bin/localhist my-home .ssh .vim; do
        (
            [[ -d $dir_name ]] || {
                mkdir -p $dir_name || die "Can't create ~/${dir_name}"
            }
            cd $dir_name || die "Can't cd to ~/${dir_name}"
            rsync -av ${host_home}/${dir_name}/ . || die "Can't rsync ${dir_name}"
        )
    done
    echo "source ~/bin/bashrc-common # Added by $scriptId" >> ~/.bashrc
    ln -sf bin/inputrc .inputrc
    ln -sf my-home/gitconfig .gitconfig

    [[ -f .local/bin/cdpp/setup.sh ]] && .local/bin/cdpp/setup.sh
    [[ -f .local/bin/localhist/setup.sh ]] && .local/bin/localhist/setup.sh

}

main() {
    [[ -d /host_home ]] && {
        install_from_host_home "$@"
    }
}

[[ -z $sourceMe ]] &&  {

    echo "remote-containers-dotfiles/install.sh startup: args[$*]" | cout
    main "$@" | cout
}
