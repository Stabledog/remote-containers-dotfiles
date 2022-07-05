#!/bin/bash
# Install dotfiles in a devcontainer.
# Preferred approach is to have the HOME host environment share readonly with the container as /host_home
# Then install_from_host_home() can copy and filter as needed.

#  SETUP:
#    - specify /host_home share in devcontainer.json:
#       "mounts": [ "source=${localEnv:HOME},target=/host_home,type=bind,readonly" ]
#    - User's settings.json needs these values:
#       "remote.containers.dotfiles.installCommand": "~/remote-containers-dotfiles/install.sh",
#       "remote.containers.dotfiles.repository": "https://github.com/Stabledog/remote-containers-dotfiles.git",
#       "remote.containers.dotfiles.targetPath": "~/remote-containers-dotfiles",
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
    for dir_name in bin .local/bin/cdpp .local/bin/localhist my-home .ssh .vim bb-cert; do
        (
            [[ -e ${host_home}/${dir_name} ]] || exit 0
            [[ -d $dir_name ]] || {
                mkdir -p $dir_name || die "Can't create ~/${dir_name}"
            }
            cd $dir_name || die "Can't cd to ~/${dir_name}"
            chmod u+w *
            rsync -av ${host_home}/${dir_name}/ . || die "Can't rsync ${dir_name}"
        )
    done
    for file_name in .cdpprc .localhistrc; do
        [[ -e ${host_home}/${file_name} ]] || continue
        cp ${host_home}/${file_name} ~/${file_name}
    done
    grep -Eq "^source ~/bashrc-common" ~/.bashrc || {
        echo "source ~/bin/bashrc-common # Added by $scriptId" >> ~/.bashrc
    }
    ln -sf bin/inputrc .inputrc
    ln -sf my-home/gitconfig .gitconfig
    [[ -e ~/projects ]] || mkdir ~/projects

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
