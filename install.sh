#!/bin/bash
# Install dotfiles in a devcontainer.
# Preferred approach is to have the HOME host environment share readonly with the container as /host_home
# Then install_from_host_home() can copy and filter as needed.
#
#  WARNING: if you're modifying the content of this repo INSIDE a container, don't rebuild the
#      container until it's committed and pushed!
#
#  SETUP:
#    - specify /host_home share in devcontainer.json:
#       "mounts": [ "source=${localEnv:HOME},target=/host_home,type=bind,readonly" ]
#    - Install `rsync` to the base image if it isn't already there
#    - User's settings.json needs these values:
#       "remote.containers.dotfiles.installCommand": "~/remote-containers-dotfiles/install.sh",
#       "remote.containers.dotfiles.repository": "https://github.com/Stabledog/remote-containers-dotfiles.git",
#       "remote.containers.dotfiles.targetPath": "~/remote-containers-dotfiles",
#
# TUNING:
#   - If the container environment has RCD_FLAGS defined, it will be a colon-delimited
#     string like "RCD_FLAGS=FLAG_A:FLAG_B", etc. which condition install behavior
#
#       protectBashrc:  Don't modify .bashrc
#

scriptName="remote-containers-dotfiles/install.sh"

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

rsync() {
    command -v rsync &>/dev/null || die "$scriptName depends on rsync, which is not installed in the container"
    command rsync "$@"
}

rcdFlagAll() {
    # Test a combination of one or more RCD_FLAGS elements.  If RCD_FLAGS=FOO2:FOO3, and
    # you call "rcdFlag FOO2", it will succeed.  "rcdFlag FOO1 FOO2" will fail because
    # FOO1 is not defined.
    for flagName; do
        [[ -z $RCD_FLAGS ]] && { false; return; }
        ( IFS=":"; command grep  -Eq "\<$1\>" <<< "${RCD_FLAGS}" ; ) || { false; return; }
    done
    true
}

rcdFlagAny() {
    # Test any-of-N RCD_FLAGS elements.  If RCD_FLAGS=FOO2:FOO3, and
    # you call "rcdFlag FOO2", it will succeed.  "rcdFlag FOO1 FOO2" will also succeed because
    # FOO2 is defined.
    for flagName; do
        [[ -z $RCD_FLAGS ]] && { false; return; }
        ( IFS=":"; command grep  -Eq "\<$1\>" <<< "${RCD_FLAGS}" ; ) || { true; return; }
    done
    false
}

taskrc_setup() {
    set -x
    [[ -x $HOME/.local/bin/taskrc-kit/setup.sh ]] && {
        (
            xdir=$(mktemp -d) \
            && cd $xdir \
            && cp -r $HOME/.local/bin/taskrc-kit ./
            && ./setup.sh
        )
    }
}

install_from_host_home() {
    # Assuming there's a /host_home share which gives us access to all the host's dotfiles:
    local host_home=/host_home
    cd ~ || die "Can't cd to ~"
    # We also might want to do maintenance on remote-containers-dotfiles from the host's copy:
    [[ -d $host_home/remote-containers-dotfiles ]] && {
        ( cd ~/remote-containers-dotfiles && git remote add host_home ${host_home}/remote-containers-dotfiles && git fetch host_home )
    }
    for dir_name in bin .local/bin/cdpp .local/bin/localhist my-home .local/bin/taskrc-kit .ssh .vim bb-cert; do
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
    taskrc_setup
    rcdFlagAll protectBashrc || {
        grep -Eq "^source ~/bin/bashrc-common" ~/.bashrc || {
            echo "source ~/bin/bashrc-common # Added by $scriptName" >> ~/.bashrc
        }
    }
    ln -sf bin/inputrc .inputrc
    ln -sf my-home/gitconfig .gitconfig
    mkdir -p ~/.vimtmp
    [[ -e ~/projects ]] || mkdir ~/projects

}

setup_bashrc_prefix() {
    [[ -d ${HOME}/bin ]] || return
    rcdFlagAll protectBashrc && return
    (
        echo "#!/bin/bash" $'\n' "echo ok" $'\n' > ~/bin/binfoo_path_test.sh
        command chmod +x ~/bin/binfoo_path_test.sh || die "Can't test ~/bin PATH presence:1"
        builtin source ~/.bashrc
        binfoo_path_test.sh &>/dev/null
        result=$?
        rm ~/bin/binfoo_path_test.sh &>/dev/null
        [[ $result == 0 ]] || {
            # ~/bin exists but is not on the PATH:
            tmpd=$(mktemp -d) || die "Can't fix ~/bin PATH presence: 2"
            echo 'PATH=${HOME}/bin:${PATH}  # Added by remote-containers-dotfiles/install.sh' > ${tmpd}/.bashrc || die 10992
            cat ~/.bashrc >> ${tmpd}/.bashrc || die 10993
            mv ${tmpd}/.bashrc ~/.bashrc || die "Failed fixing ~/bin PATH presence"
            echo 'We patched ~/.bashrc to add ~/bin to the path'
        }
    )
}

main() {
    [[ -d /host_home ]] && {
        install_from_host_home "$@"
        setup_bashrc_prefix "$@"
    }
}

[[ -z $sourceMe ]] &&  {

    echo "remote-containers-dotfiles/install.sh startup: args[$*]" | cout
    main "$@" | cout
}
