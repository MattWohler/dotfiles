#!/bin/sh
#
# wildefyr - 2016 (c) MIT
# standalone groups script
# focus.sh is presumed to be contrib's version
#
# with a few modifications

ARGS="$@"

GROUPSDIR=${GROUPSDIR:-/tmp/groups}
test ! -d $GROUPSDIR && mkdir -p $GROUPSDIR

usage() {
    cat >&2 << EOF
Usage: $(basename $0) [-a wid group] [-fc wid] [-shmtTuz group] [-rlhq]
    -a | --add:    Add wid to the given group.
    -f | --find:   Outputs wid if it was not found in a group.
    -c | --clean:  Clean wid from all groups.
    -h | --hide:   Hide given group.
    -s | --show:   Show given group.
    -m | --map:    Show given group, but hide other active groups.
    -z | --cycle:  Cycle through windows in the given group.
    -t | --toggle: Toggle given group.
    -T | --smart:  Jump to group; if on a group window, hide the group.
    -u | --unmap:  Unmap given group.
    -r | --reset:  Reset all groups.
    -l | --list:   List all groups.
    -q | --quiet:  Suppress all textual output.
    -h | --help:   Show this help.
EOF

    test $# -eq 0 || exit $1
}

intCheck() {
    test $1 -ne 0 2> /dev/null
    test $? -ne 2 || return 1
}

widCheck() {
    case "$1" in
        0x*)
            return 0
            ;;
        *)
            printf '%s\n' "Please enter a valid window id." >&2
            exit 1
            ;;
    esac
}

findWid() {
    wid="$1"
    widCheck "$wid"

    # if wid is found in a group, return the group
    for group in $(find $GROUPSDIR/*.? 2> /dev/null); do
        grep -q "$wid" "$group" && {
            printf '%s\n' "$group"
            return 0
        }
    done

    return 1
}

cleanWid() {
    cleanWid="$1"

    # if it doesn't exist in a group, exit
    widInGroups=$(findWid "$cleanWid")
    test -z "$widInGroups" && return 1

    # make sure the wid is mapped to the screen
    mapw -m "$cleanWid"

    # clean the wid from the group, works for the same wid in multiple groups
    for group in $widInGroups; do
        buffer=$(grep -wv "$cleanWid" "$group")
        test -z "$buffer" 2> /dev/null && {
            cleanGroupNum=$(printf '%s\n' "$group" | rev | cut -d'.' -f 1 | rev)
            unmapGroup $cleanGroupNum 2>&1 > /dev/null
        } || {
            printf '%s\n' "$buffer" > "$group"
        }
    done

    printf '%s\n' "$cleanWid cleaned!"
}

unmapGroup() {
    unmapGroupNum=$1
    intCheck $unmapGroupNum || return 1

    test -f "$GROUPSDIR/group.${unmapGroupNum}" && {
        # make the group visible
        showGroup $unmapGroupNum

        # clean group from the active file
        test -f "$GROUPSDIR/active" && {
            buffer=$(grep -wv $unmapGroupNum "$GROUPSDIR/active")
            test -z "$buffer" 2> /dev/null && {
                rm -f "$GROUPSDIR/active"
            } || {
                printf '%s\n' "$buffer" > "$GROUPSDIR/active"
            }
        }

        # clean group from the inactive file
        test -f "$GROUPSDIR/inactive" && {
            buffer=$(grep -wv $unmapGroupNum "$GROUPSDIR/inactive")
            test -z "$buffer" 2> /dev/null && {
                rm -f "$GROUPSDIR/active"
            } || {
                printf '%s\n' "$buffer" > "$GROUPSDIR/inactive"
            }
        }

        rm -f $GROUPSDIR/group.${unmapGroupNum}
        printf '%s\n' "group ${unmapGroupNum} cleaned!"
    } || {
        printf '%s\n' "group ${unmapGroupNum} does not exist!" >&2
    }
}

toggleWidGroup() {
    addWid="$(printf "$1" | cut -d\  -f 1)"
    addGroupNum=$(printf '%s' "$1" | cut -d\  -f 2)

    widCheck "$addWid"
    intCheck $addGroupNum || return 1

    # this is a dummy wid X11 will return when no window is focused
    test "$addWid" = "0x00000001" && {
        printf '%s\n' "Please enter a valid window id." >&2
        return 1
    }

    # get the current group the wid belongs to - if it does
    currentGroup="$(findWid "$addWid")"
    currentGroup=$(printf '%s\n' "$currentGroup" | rev | cut -d'.' -f 1 | rev)

    # return if it already exists in the given group
    test ! -z $currentGroup && {
        test $addGroupNum -eq $currentGroup && {
            printf '%s\n' "Window id ($addWid) alrady exists in ${currentGroup}!"
            return 0
        }
    }

    cleanWid "$addWid"

    # hide wid if group is curently hidden
    test -f "$GROUPSDIR/inactive" && {
        while read -r inactive; do
            test $inactive -eq $addGroupNum && {
                mapw -u "$addWid"
                break
            }
        done < "$GROUPSDIR/inactive"
    }

    # add group to active if group doesn't exist
    test ! -f "$GROUPSDIR/group.${addGroupNum}" && {
        printf '%s\n' "$addGroupNum" >> "$GROUPSDIR/active"
    }

    # add wid to the group file
    printf '%s\n' "$addWid" >> "$GROUPSDIR/group.${addGroupNum}"
    printf '%s\n' "$addWid added to ${addGroupNum}!"
}

hideGroup() {
    hideGroupNum=$1
    intCheck $hideGroupNum || return 1

    test -f "$GROUPSDIR/group.$hideGroupNum" && {
        # return if group is already inactive
        test -f "$GROUPSDIR/inactive" && {
            grep -qw $hideGroupNum "$GROUPSDIR/inactive" && return 1
        }

        # add the group to the inactive file
        printf '%s\n' "$hideGroupNum" >> "$GROUPSDIR/inactive"

        # clean the group from the active file
        test -f "$GROUPSDIR/active" && {
            buffer=$(grep -wv $hideGroupNum "$GROUPSDIR/active")
            test ! -z "$buffer" && {
                printf '%s\n' "$buffer" > "$GROUPSDIR/active"
            } || {
                rm -f "$GROUPSDIR/active"
            }
        }

        # hide all windows in group and set the border to inactive just to be safe
        while read -r addWid; do
            mapw -u $addWid
            chwb -s $BW -c $INACTIVE $addWid
        done < "$GROUPSDIR/group.${hideGroupNum}"

        printf '%s\n' "group ${hideGroupNum} hidden!"
    }
}

showGroup() {
    showGroupNum=$1
    intCheck $showGroupNum || return 1

    test -f "$GROUPSDIR/group.$showGroupNum" && {
        # return if group is already active
        test -f "$GROUPSDIR/active" && {
            grep -qw $showGroupNum "$GROUPSDIR/active" && return 1
        }

        # add the group to the active file
        printf '%s\n' "$showGroupNum" >> "$GROUPSDIR/active"

        # clean the group from the inactive file
        test -f "$GROUPSDIR/inactive" && {
            buffer="$(grep -wv $showGroupNum "$GROUPSDIR/inactive")"
            test ! -z "$buffer" && {
                printf '%s\n' "$buffer" > "$GROUPSDIR/inactive"
            } || {
                rm -f "$GROUPSDIR/inactive"
            }
        }

        # show all windows in group and place them at the top of window stack
        while read -r showWid; do
            mapw -m $showWid
        done < "$GROUPSDIR/group.${showGroupNum}"

        # focus the top window in the group
        focusWid="$(head -n 1 < "$GROUPSDIR/group.${showGroupNum}")"
        vroum.sh "$focusWid"

        printf '%s\n' "group ${showGroupNum} visible!"
    }
}

# show given group and hide all others - could be used for workspaces
mapGroup() {
    mapGroupNum=$1
    intCheck $mapGroupNum || return 1

    test -f "$GROUPSDIR/active" && {
        # hide all other groups listed in the active file
        while read -r active; do
            test $mapGroupNum -ne $active && {
                hideGroup $active
            }
        done < "$GROUPSDIR/active"

        while read -r active; do
            test $active -eq $mapGroupNum && {
                activeFlag=true
                break
            }
        done < "$GROUPSDIR/active"

        # return user input if the group was NOT already on the screen
        test "$activeFlag" != "true" && {
            showGroup $mapGroupNum
        } || {
            showGroup $mapGroupNum > /dev/null
        }
    } || {
        # we know it's the only group existing and it's inactive
        showGroup $mapGroupNum
    }
}

# simple group toggle
toggleGroup() {
    toggleGroupNum=$1
    intCheck $toggleGroupNum || return 1

    # find out if the group is active
    test -f "$GROUPSDIR/active" && {
        while read -r active; do
            test $active -eq $toggleGroupNum && {
                activeFlag=true
                break
            }
        done < "$GROUPSDIR/active"
    }

    # hide or show group
    test "$activeFlag" = "true" && {
        hideGroup $toggleGroupNum
    } || {
        showGroup $toggleGroupNum
    }
}

smartToggleGroup() {
    toggleGroupNum=$1
    intCheck $toggleGroupNum || return 1

    # find out if the group is active
    test -f "$GROUPSDIR/active" && {
        while read -r active; do
            test $active -eq $toggleGroupNum && {
                activeFlag=true
                break
            }
        done < "$GROUPSDIR/active"
    }

    test "$activeFlag" = "true" && {
        test $(wc -l < "$GROUPSDIR/group.${toggleGroupNum}") -eq 1 && {
            wid="$(cat "$GROUPSDIR/group.${toggleGroupNum}")"
            test "$(pfw)" = "$wid" && {
                # hide group as we are already on the first window in group
                hideGroup $toggleGroupNum
                return 0
            } || {
                # focus first window in group if we are NOT on a window in group
                vroum.sh "$wid"
                return 0
            }
        } || {
            # hide group if we are on a window in group
            hideGroup $toggleGroupNum
            return 0
        }
    } || {
        # show group as we know it has to inactive
        showGroup $toggleGroupNum
    }
}

cycleGroup() {
    #cycleGroupNum=$1

    # get the current group the wid belongs to - if it does
    currentGroup="$(findWid "$(pfw)")"
    cycleGroupNum=$(printf '%s\n' "$currentGroup" | rev | cut -d'.' -f 1 | rev)
    #echo "$cycleGroupNum"

    intCheck $cycleGroupNum || return 1

    # find out if the group is active
    test -f "$GROUPSDIR/active" && {
        while read -r active; do
            test $active -eq $cycleGroupNum && {
                activeFlag=true
                break
            }
        done < "$GROUPSDIR/active"
    }

    # show group if group is not active
    test "$activeFlag" != "true" && {
        showGroup $cycleGroupNum
    }

    # focus next window in group or if at the bottom of stack go to first window
    wid="$(sed "0,/^$(pfw)$/d" < "$GROUPSDIR/group.${cycleGroupNum}")"
    test -z "$wid" && wid="$(head -n 1 < "$GROUPSDIR/group.${cycleGroupNum}")"
    vroum.sh "$wid"
}

resetGroups() {
    # map all groups to the screen
    test -f "$GROUPSDIR/inactive" && {
        while read -r resetGroupNum; do
            showGroup $resetGroupNum
        done < "$GROUPSDIR/inactive"
    }

    # clean the group directory
    rm -f $GROUPSDIR/*
}

# list all windows in groups in a friendly-ish format
listGroups() {
    for group in $(find $GROUPSDIR/*.? 2> /dev/null); do
        printf '%s\n' "$(printf '%s' ${group} | rev | cut -d'/' -f 1 | rev):"
        printf '%s\n' "$(cat ${group})"
    done
}

main() {
    for arg in $@; do
        case "$arg" in -?|--*) ADDFLAG=false ;; esac
        test "$ADDFLAG" = "true" && ADDSTRING="${ADDSTRING}${arg} "
        case "$arg" in -a|--add) ADDFLAG=true ;; esac
    done

    test ! -z "$ADDSTRING" && {
        toggleWidGroup "$ADDSTRING" && exit 0
    }

    for arg in $@; do
        case "$arg" in
            -m|--map)    MAPFLAG=true    ;;
            -s|--show)   SHOWFLAG=true   ;;
            -h|--hide)   HIDEFLAG=true   ;;
            -f|--find)   FINDFLAG=true   ;;
            -c|--clean)  CLEANFLAG=true  ;;
            -u|--unmap)  UNMAPFLAG=true  ;;
            -z|--cycle)  CYCLEFLAG=true  ;;
            -t|--toggle) TOGGLEFLAG=true ;;
            -T|--smart)  SMARTFLAG=true  ;;
            -r|--reset)  resetGroups     ;;
            -l|--list)   listGroups      ;;
        esac

        test "$MAPFLAG"    = "true" && mapGroup "$arg"         && exit 0
        test "$SHOWFLAG"   = "true" && showGroup "$arg"        && exit 0
        test "$HIDEFLAG"   = "true" && hideGroup "$arg"        && exit 0
        test "$CYCLEFLAG"  = "true" && cycleGroup "$arg"       && exit 0
        test "$CLEANFLAG"  = "true" && cleanWid "$arg"         && exit 0
        test "$UNMAPFLAG"  = "true" && unmapGroup "$arg"       && exit 0
        test "$TOGGLEFLAG" = "true" && toggleGroup "$arg"      && exit 0
        test "$SMARTFLAG"  = "true" && smartToggleGroup "$arg" && exit 0
        test "$FINDFLAG"   = "true" && {
            findWid "$arg" && exit 0 || exit 1
            FINDFLAG=false
        }

    done
}

test $# -eq 0 && usage 1

for arg in $ARGS; do
    case "$arg" in
        -q|--quiet)       QUIETFLAG=true ;;
        h|help|-h|--help) usage 0        ;;
    esac
done

test "$QUIETFLAG" = "true" && {
    main $ARGS 2>&1 > /dev/null
} || {
    main $ARGS
}
