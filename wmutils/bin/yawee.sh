#!/bin/sh

while IFS=: read ev wid; do
    case $1 in
        -d|--debug) printf '%s\n' "$ev $wid $(pfw)" ;;
    esac

    if wattr o "$wid"; then
        continue;
    fi

    case $ev in

        # window creation
        16) ! wattr "$wid" || {
                corner_mh.sh md "$wid" "$(pfw)"
            }
            ;;

        #17)
        #    ~/bin/windows-fyrefree.sh -q -c "$(pfw)"
        #    ;;

        # mapping requests (show window)
        19) ! wattr "$wid" ||  {
                vroum.sh "$wid" &
            }
            ;;

        # focus prev window when hiding(unmapping)/deleting focused window
        18)
            #(wattr "$(pfw)" && ! wattr m "$(pfw)") || {
            wattr $(pfw) || {
                vroum.sh prev 2>/dev/null
            }
            ;;

        4)
            if [ "$wid" != "$(pfw)" ] && wattr "$wid"; then
                vroum.sh "$wid" &
            fi
            ;;
        #7) wattr o $wid || vroum.sh $wid ;;
    esac
done

