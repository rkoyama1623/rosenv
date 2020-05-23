#!/bin/sh

# ROS Environnemt Manager
ROSENV_DIR=$HOME/.rosenv
rosenv() {
    if [ $# -lt 1 ]; then
        rosenv help
        return
    fi
    case $1 in
        "help")
            echo
            echo "ROS Environment Manager"
            echo
            echo "Usage:"
            echo "    rosenv help"
            echo "       Show this message"
            echo "    rosenv register|add <nickname> <path> <distro> [<parent-work-space>]"
            echo "       Register an existing ros workspace."
            echo "    rosenv remove|rm|unregister <nickname>"
            echo "       Remove a workspace from rosenv."
            echo "    rosenv list"
            echo "       List all the workspaces"
            echo "    rosenv use <nickname> [--devel|--install]"
            echo "       Switch to the workspace specifid by the nickname."
            echo "       If that environment is catkin workspace, you can"
            echo "       sppecify which setup file to use devel or install."
            echo "    rosenv use --install"
            echo "       Use install setup script with the current workspace."
            echo "    rosenv use --devel"
            echo "       Use devel setup script with the current workspace."
            echo "    rosenv use --default|--no-default"
            echo "       Set the current workspace as a default workspace."
            echo "       You can cancel this setting by specifying --no-default"
            echo "    rosenv update [<nickname>] [-jJOB_NUM]"
            echo "       Run \`rosws update\` or \`wstool update\` on the"
            echo "       current workspace. You can specify other workspace"
            echo "       <nickname>."
            echo "    rosenv install <nickname> <path> <distro> \
<rosinstall-file> [<rosinstall-file> <rosinstall-file> ...]"
            echo "       Checkout several repositories speicfied by the"
            echo "       rosinstall files and register that workspace to rosenv."
            echo "    rosenv get-version [<nickname>]"
            echo "       Show the version of the workspace"
            echo "    rosenv get-path [<nickname>]"
            echo "       Get the path of the workspace"
            echo "    rosenv get-parent-workspace [<nickname>]"
            echo "       Get the path of the parent workspace"
            echo "    rosenv list-nicknames"
            echo "       List all the workspaces's nickname"
            echo "    rosenv is-catkin <nickname>"
            echo "       return yes if the workspace is catkin workspace."
            echo "    rosenv distros"
            echo "       return a list of distribution supported by rosenv"
            echo
            echo "Example:"
            echo "    rosenv install jsk.hydro ~/ros/hydro hydro https://raw.github.com/jsk-ros-pkg/jsk_common/master/jsk.rosinstall"
            echo "    rosenv install jsk.groovy ~/ros/groovy groovy https://raw.github.com/jsk-ros-pkg/jsk_common/master/jsk.rosinstall"
            echo "    rosenv update jsk.hydro"
            echo "    rosenv update jsk.groovy"
            echo "    rosenv use jsk.hydro"
            ;;
        "distros")              # internal API
            echo "groovy hydro indigo"
            ;;
        "register" | "add")
            # nickname path version
            if [ $# -lt 4 ]; then
                rosenv help
                return
            fi
            local nickname
            local ws_path
            local version
            local parent_workspace
            nickname=$2
            ws_path=$3
            version=$4
            parent_workspace=$5
            if [ "$parent_workspace" != "" ]; then
                echo "  register $ws_path($version) as $nickname with parent $parent_workspace"
            else
                echo "  register $ws_path($version) as $nickname"
            fi
            # use node to read/write json file
            node <<EOF
var path = require('path');
var fs = require('fs');
if (!fs.existsSync("$ROSENV_DIR")) {
  fs.mkdirSync("$ROSENV_DIR");
}
var config = {};
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
}
config["$nickname"] = {
  path: "$ws_path",
  version: "$version",
  parent: "$parent_workspace"
};
fs.writeFileSync("$ROSENV_DIR/config.json", JSON.stringify(config, null, 4) + '\n');
EOF
            ;;
        "list")
            node <<EOF
var path = require('path');
var fs = require('fs');
var util = require('util');
function config_format(config) {
  if (config.parent) {
    return util.format('%s (%s) %s <= %s', key, config.version, config.path, config.parent);
  }
  else {
    return util.format('%s (%s) %s', key, config.version, config.path);
  }
}

if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  for (var key in config) {
    if (key.toString() == "$ROSENV_CURRENT".toString()) {
      console.log(util.format('\u001b[36m* %s\u001b[m', config_format(config[key])));
    }
    else {
      console.log(util.format('  %s', config_format(config[key])));
    }
  }
}
else {
  console.log("no env is registered");
}
EOF
            ;;
        "list-nicknames")       # internal command
            local onelinep
            if [ "$1" = "--oneline" ]; then
                onelinep=true
            else
                onelinep=false
            fi
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  var split = ' ';
  if ($onelinep) {
    split = '\n';
  }
  var strs = [];
  for (var key in config) {
    strs.push(key);
  }
  console.log(strs.join(split));
}
EOF
            ;;
        "get-nickname")
            echo $ROSENV_CURRENT
            ;;
        "get-parent-workspace")
            local nickname
            if [ $# = 1 ]; then
                nickname=$ROSENV_CURRENT
            elif [ $# = 2 ]; then
                nickname=$2
            else
                rosenv help
                return 2
            fi
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  if (config.hasOwnProperty("$nickname")) {
    if (config["$nickname"].parent) {
       console.log(config["$nickname"].parent);
    }
    else {
       console.log('none')
    }
  }
}
EOF
            ;;
        "get-path")             # internal command
            local nickname
            if [ $# = 1 ]; then
                nickname=$ROSENV_CURRENT
            elif [ $# = 2 ]; then
                nickname=$2
            else
                rosenv help
                return 2
            fi
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  if (config.hasOwnProperty("$nickname")) {
    console.log(config["$nickname"].path);
  }
}
EOF
            ;;
        "get-version")             # internal command
            local nickname
            if [ $# = 1 ]; then
                nickname=$ROSENV_CURRENT
            elif [ $# = 2 ]; then
                nickname=$2
            else
                rosenv help
                return 2
            fi
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  if (config.hasOwnProperty("$nickname")) {
    console.log(config["$nickname"].version);
  }
}
EOF
            ;;
        "rm" | "remove" | "unregister")
            local nickname
            nickname=$2
            node <<EOF
var path = require('path');
var fs = require('fs');
if (fs.existsSync("$ROSENV_DIR/config.json")) {
  config = JSON.parse(fs.readFileSync("$ROSENV_DIR/config.json", "utf-8"));
  delete config["$nickname"];
fs.writeFileSync("$ROSENV_DIR/config.json", JSON.stringify(config, null, 4) + '\n');
}
EOF
            ;;
        "is-catkin")
            local ws_path
            local nickname
            nickname=$2
            ws_path=$(rosenv get-path $nickname)
            if [ -e $ws_path/src ]; then
                echo yes
            fi
            ;;
        "packages")
            # list up all the packages which includes package does not compiled
            # yet even-when you use catkin-tools
            local packages
            local package_xmls
            ws_path=$(rosenv get-path $nickname)
            package_xmls=$(find $ws_path/src -name package.xml -prune |
                xargs -n 1 dirname | xargs -n 1 basename)
            echo $package_xmls
            ;;
        "use")
            local nickname
            local develp
            local installp
            local defaultp
            # parsing argument
            nickname=$ROSENV_CURRENT
            shift               # dispose 'use' argument
            while [ $# -gt 0 ]; do
                case "$1" in
                    "--install") installp=true;;
                    "--devel") develp=true;;
                    "--default") defaultp=true;;
                    "--no-default") defaultp=false;;
                    *) nickname=$1;;
                esac
                shift
            done
            if [ "`rosenv get-version $nickname`" = "" ]; then
                echo $nickname is not registered yet
                return 1
            else
                local ws_path
                local sh_path
                ws_path=$(rosenv get-path $nickname)
                if [ -e $ws_path/src ]; then
                    # catkin
                    if [ "$installp" = "true" ]; then
                        echo -e "\e[36mswitching to $nickname:install (catkin)\e[m"
                        sh_path=$ws_path/install/setup.`basename $SHELL`
                    else
                        echo -e "\e[36mswitching to $nickname:devel (catkin)\e[m"
                        sh_path=$ws_path/devel/setup.`basename $SHELL`
                    fi
                else
                    # rosbuild
                    echo -e "\e[36mswitching to $nickname (rosbuild)\e[m"
                    sh_path=$ws_path/setup.`basename $SHELL`
                fi
                if [ ! -e "$sh_path" ]; then
                    echo "$sh_path is not yet available. \
(not yet catkin build is called?)"
                    if [ "$(rosenv get-parent-workspace $nickname)" = "none" ]; then
                        sh_path="/opt/ros/$(rosenv get-version $nickname)/setup.$(basename $SHELL)"
                    else
                        sh_path="$(rosenv get-parent-workspace $nickname)/setup.$(basename $SHELL)"
                    fi
                    echo "automatically source $sh_path"
                fi
                source $sh_path
                export ROSENV_CURRENT=$nickname
                export ROS_WORKSPACE=$ws_path
                # check rosenv_use_hook is defined or not
                type rosenv_use_hook > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    rosenv_use_hook
                fi
                #rospack profile > /dev/null

                if [ "$defaultp" = "true" ]; then
                    if [ "$installp" = "true" ]; then
                        echo $nickname:install > $ROSENV_DIR/version
                    else
                        echo $nickname:devel > $ROSENV_DIR/version
                    fi
                elif [ "$defaultp" = "false" ]; then
                    if [ -e $ROSENV_DIR/version ]; then
                        echo -e "\e[33mDo not use $(cat $ROSENV_DIR/version) as default \e[m"
                        rm $ROSENV_DIR/version
                    fi
                fi
            fi
            ;;
        "update")
            # update [nickname] [-jJOB_NUM]
            local nickname
            local pjobs
            if [ $# != 1 -a $# != 2 -a $# != 3 ]; then
                rosenv help
                return 2
            fi
            shift               # dispose 'update'
            nickname=$ROSENV_CURRENT
            while [ $# -gt 0 ]; do
                case "$1" in
                    -j*) pjobs=$1;;
                    *) nickname=$1
                esac
                shift
            done
            if [ "$(rosenv is-catkin $nickname)" = "yes" ] ; then
                (cd $(rosenv get-path $nickname)/src > /dev/null && rosenv use $nickname && wstool update $pjobs)
                while [ $? != 0 ]; do
                    sleep 1
                    (cd $(rosenv get-path $nickname)/src > /dev/null && rosenv use $nickname && wstool update $pjobs)
                done
            else
                (cd $(rosenv get-path $nickname) > /dev/null && rosenv use $nickname && rosws update $pjobs)
                while [ $? != 0 ]; do
                    sleep 1
                    (cd $(rosenv get-path $nickname) > /dev/null && rosenv use $nickname && rosws update $pjobs)
                done
            fi
            ;;
        "install")
            # install nickname path distro rosinstall-file [rosinstall-file2 rosinstall-file3 ...]
            # parse argument
            local nickname
            local directory
            local directory_parent
            local rosinstall_files
            local distro
            local wscmd
            wscmd=wstool
            if [ $# -lt 5 ]; then
                rosenv help
                return 1
            fi
            nickname=$2
            directory=$3
            directory_parent=$3
            distro=$4
            shift; shift; shift; shift;
            while [ $# -gt 0 ]; do
                case "$1" in
                    "--rosbuild") wscmd=rosws;;
                    *) rosinstall_files="$1 $rosinstall_files";;
                esac
                shift
            done
            if [ $wscmd = "wstool" ]; then
                directory=$directory/src
            fi
            mkdir -p $directory
            (cd $directory > /dev/null && $wscmd init)
            if [ $wscmd = rosws ]; then
                (cd $directory > /dev/null && $wscmd merge /opt/ros/$distro/.rosinstall)
            else
                (cd $directory > /dev/null && catkin_init_workspace)
            fi
            for rosinstall_file in `echo $rosinstall_files`
            do
                if [ -e $rosinstall_file ]; then
                    local abspath
                    abspath=$(cd $(dirname $rosinstall_file) > /dev/null && pwd)/$(basename $rosinstall_file)
                    (cd $directory > /dev/null && $wscmd merge file://$abspath)
                else
                    (cd $directory > /dev/null && $wscmd merge $rosinstall_file)
                fi
            done
            rosenv register $nickname $directory_parent $distro
            ;;
        *)
            rosenv help
            return 3
            ;;
    esac
}

catmake() {
    local catkin_pkg
    local sh_file
    if [ "$(rosenv get-parent-workspace)" = "none" ]; then
        sh_file=/opt/ros/$(rosenv get-version $ROSENV_CURRENT)/setup.$(basename $SHELL)
    else
        sh_file=$(rosenv get-parent-workspace)/setup.$(basename $SHELL)
    fi
    (
        cd $(rosenv get-path $ROSENV_CURRENT) > /dev/null &&
        source $sh_file &&
        echo ++ catkin build $@ -DCMAKE_BUILD_TYPE=RelWithDebInfo
        catkin build $@ -DCMAKE_BUILD_TYPE=RelWithDebInfo
    )
    rosenv use
}

catmakeone() {
    catmake $@ --start-with $@
}

wsinfo_current_branch() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || \
  ref=$(git rev-parse --short HEAD 2> /dev/null) || return
  branch=${ref#refs/heads/}
  if [ "$branch" = "master" -o \
      "$branch" = "hydro-devel" -o \
      "$branch" = "groovy-devel" -o \
      "$branch" = "indigo-devel" ]; then
      echo $branch
  else
      echo -e "\e[1;31m $branch \e[m"
  fi
}

# only zsh
catclean() {
    local ws_path
    local pkg_path
    local build_path
    ws_path=$(rosenv get-path)
    pkg_path=$(rospack find $1)
    build_path=${ws_path}/build/$1
    devel_share_path=${ws_path}/devel/share/$1
    devel_lib_path=${ws_path}/devel/lib/$1
    devel_install_path=${ws_path}/devel/install/$1
    python_path=${ws_path}/devel/lib/python2.7/dist-packages/$1
    echo -e "\e[1;31m cleaning ${build_path}\e[m"
    echo -e "\e[1;31m cleaning ${devel_share_path}\e[m"
    echo -e "\e[1;31m cleaning ${devel_lib_path}\e[m"
    echo -e "\e[1;31m cleaning ${devel_install_path}\e[m"
    echo -e "\e[1;31m cleaning ${python_path}\e[m"
    rm -rf ${build_path} ${devel_share_path} ${devel_lib_path} ${devel_install_path} ${python_path}
}

wsinfo() {
    # a function to show the branch information of workspace
    # only supports git
    local ws_path
    ws_path=$(rosenv get-path)
    dirs=$(find $ws_path -name .git)
    for d in $(echo $dirs)
    do
        (cd $(dirname $d) > /dev/null && echo -n ${$(dirname $d)#$ws_path/} '==> ' &&
         wsinfo_current_branch)
    done
}

# completion
if [ $(basename $SHELL) = "zsh" ]; then
    _rosenv() {
        local _1st_arguments
        _1st_arguments=(
            "help":"show help"
            "register":"register a workspace"
            "list":"list of the workspaces"
            "list-nicknames":"only list up the nicknames of the workspaces"
            "get-nickname":"show current workspace"
            "get-path":"get the path to the workspace"
            "get-parent-workspace":"get the parent workspace path. if not specified, returns none"
            "get-version":"get the ROS distro version of the workspace"
            "remove":"remove the workspace"
            "is-catkin":"return yes if the workspace is catkin"
            "use":"switch the workspace"
            "update":"update the workspace"
            "install":"set up a workspace"
            "packages":"list all the packeges in workspace"
        )
        _arguments '*:: :->ocommand'
        if ((CURRENT == 1)); then
            _describe -t commands "rosenv commands" _1st_arguments;
            return
        fi
        case "$words[1]" in
            "register" | "add")
                if ((CURRENT == 3)); then
                    _files
                elif ((CURRENT == 4)); then
                    _values "distros" $(rosenv distros)
                elif ((CURRENT == 5)); then
                    _files
                fi
                ;;
            "remove" | "rm" | "unregister")
                if ((CURRENT == 2)); then
                    _values "workspaces" $(rosenv list-nicknames)
                fi
                ;;
            "list" | "packages")
                # do nothing
                ;;
            "use")
                _values "workspaces" $(rosenv list-nicknames) --install --devel --default --no-default
                ;;
            "update")
                _values "workspaces" $(rosenv list-nicknames)
                ;;
            "install")
                if ((CURRENT == 3)); then
                    _files
                elif ((CURRENT == 4)); then
                    _values "distro" $(rosenv distros)
                elif ((CURRENT != 2)); then
                    _files
                fi
                ;;
            "get-path" | "get-version" | "is-catkin" | "get-parent-workspace")
                _command_args=$(rosenv list-nicknames)
                _values "args" `echo $_command_args`
                ;;

        esac

    }
    compdef _rosenv rosenv
elif [ $(basename $SHELL) = "bash" ]; then
    _rosenv() {
        arg="${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=()
        # the first argument
        if [[ $COMP_CWORD == 1 ]]; then
            COMPREPLY=($(compgen -W "help register list list-nicknames \
get-nicknames get-path get-version remove is-catkin use update install packages" \
                    -- ${arg}))
        else
            case ${COMP_WORDS[1]} in
                register | add)
                    if [[ $COMP_CWORD == 3 ]]; then
                        COMPREPLY=($(compgen -o filenames -A file -- ${arg}))
                    elif [[ $COMP_CWORD == 4 ]]; then
                        COMPREPLY=($(compgen -W "$(rosenv distros)" -- ${arg}))
                    elif [[ $COMP_CWORD == 5 ]]; then
                        COMPREPLY=($(compgen -o filenames -A file -- ${arg}))
                    fi
                    ;;
                # the comemnd which requires only one argument
                # and which is one of the nicknames
                get-path | get-version | remove | rm | unregister | is-catkin | get-parent-workspace)
                    if [[ $COMP_CWORD == 2 ]]; then
                        COMPREPLY=($(compgen -W "$(rosenv list-nicknames)"\
                            -- ${arg}))
                    fi
                    ;;
                update)
                    if [[ $COMP_CWORD == 2 ]]; then
                        COMPREPLY=($(compgen -W "$(rosenv list-nicknames)"\
                            -- ${arg}))
                    fi
                    ;;
                use)
                    COMPREPLY=($(compgen -W "$(rosenv list-nicknames)\
 --install --devel --default --no-default" -- ${arg}))
                    ;;
                install)
                    if [[ $COMP_CWORD == 3 ]]; then
                        COMPREPLY=($(compgen -o filenames -A file -- ${arg}))
                    elif [[ $COMP_CWORD == 4 ]]; then
                        COMPREPLY=($(compgen -W "$(rosenv distros)" -- ${arg}))
                    elif [[ $COMP_CWORD -ge 5 ]]; then
                        COMPREPLY=($(compgen -o filenames -A file -- ${arg}))
                    fi
                    ;;
            esac
        fi
    }
    complete -F "_rosenv" "rosenv"
fi

if [ $(basename $SHELL) = "zsh" ]; then
    _catmake() {
        local options
        options="build --force-cmake --start-with --cmake-args --make-args \
`rosenv packages | cut -f1 -d' '`"
        reply=(${=options})
    }
    compctl -K "_catmake" "catmake"
    _catmakeone() {
        local options
        options="`rospack list | cut -f1 -d' '`"
        reply=(${=options})
    }
    compctl -K "_catmakeone" "catmakeone"
elif [ $(basename $SHELL) = "bash" ]; then
    _catmake() {
        arg="${COMP_WORDS[COMP_CWORD]}"
        local options
        options="install test clean -h -C --source --build --force-cmake --no-color \
--pkg --only-pkg-with-deps --cmake-args --make-args \
`rospack list | cut -f1 -d' '`"
        COMPREPLY=($(compgen -W "$options" -- ${arg}))
    }
    complete -F "_catmake" "catmake"
fi

if [ $(basename $SHELL) = "zsh" ]; then
    _catclean() {
        local options
        options="$(rospack list | cut -f1 -d' ')"
        reply=(${=options})
    }
    compctl -K "_catclean" "catclean"
fi

if [ -e $ROSENV_DIR/version ]; then
    nickname=$(sed -E 's/([^:]+):([^:]*)/\1/' $ROSENV_DIR/version)
    script=$(sed -E 's/([^:]+):([^:]*)/\2/' $ROSENV_DIR/version)
    if [ $script = "install" ]; then
        rosenv use $nickname --install >/dev/null
    else
        rosenv use $nickname >/dev/null
    fi
fi
