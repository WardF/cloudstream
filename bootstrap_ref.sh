#!/bin/bash
# File adapted from https://medium.com/dot-debug/running-chrome-in-a-docker-container-a55e7f4da4a8
# Based on: http://www.richud.com/wiki/Ubuntu_Fluxbox_GUI_with_x11vnc_and_Xvfb

readonly G_LOG_I='[INFO]'
readonly G_LOG_W='[WARN]'
readonly G_LOG_E='[ERROR]'

main() {
    launch_xvfb
    #launch_window_manager
    run_vnc_server
    run_novnc
}

launch_xvfb() {
    echo ""
    echo "Launching XVFB"
    echo ""
    # Set defaults if the user did not specify envs.
    export DISPLAY=${XVFB_DISPLAY:-:1}
    local screen=${XVFB_SCREEN:-0}
    local resolution=${XVFB_RESOLUTION:-${SIZEW}x${SIZEH}x24}
    local timeout=${XVFB_TIMEOUT:-5}

    # Start and wait for either Xvfb to be fully up or we hit the timeout.
    Xvfb ${DISPLAY} -screen ${screen} ${resolution} &
    local loopCount=0
    until xdpyinfo -display ${DISPLAY} > /dev/null 2>&1
    do
        loopCount=$((loopCount+1))
        sleep 1
        if [ ${loopCount} -gt ${timeout} ]
        then
            echo "${G_LOG_E} xvfb failed to start."
            exit 1
        fi
    done
}

launch_window_manager() {
    echo ""
    echo "Launching Window Manager"
    echo ""

    local timeout=${XVFB_TIMEOUT:-5}

    # Start and wait for either fluxbox to be fully up or we hit the timeout.
    fluxbox &
    local loopCount=0
    until wmctrl -m > /dev/null 2>&1
    do
        loopCount=$((loopCount+1))
        sleep 1
        if [ ${loopCount} -gt ${timeout} ]
        then
            echo "${G_LOG_E} fluxbox failed to start."
            exit 1
        fi
    done
}

run_vnc_server() {
    echo ""
    echo "Launching VNC Server"
    echo ""
    local passwordArgument='-nopw'

    if [ -n "${USEPASS}" ]
    then
        local passwordFilePath="${HOME}/x11vnc.pass"
        if ! x11vnc -storepasswd "${USEPASS}" "${passwordFilePath}"
        then
            echo "${G_LOG_E} Failed to store x11vnc password."
            exit 1
        fi
        passwordArgument=-"-rfbauth ${passwordFilePath}"
        echo "${G_LOG_I} The VNC server will ask for a password."
    else
        echo "${G_LOG_W} The VNC server will NOT ask for a password."
    fi

    x11vnc -display ${DISPLAY} -forever ${passwordArgument} &
   
}

run_novnc() {
    echo ""
    echo "Launching noVNC"
    echo ""
    cd ${BUNDLEDIR}/noVNC/utils && openssl req -new -x509 -days 365 -nodes -out self.pem -keyout self.pem -batch
    cd $HOME
    ${BUNDLEDIR}/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 &


}

control_c() {
    echo ""
    exit
}

trap control_c SIGINT SIGTERM SIGHUP

###
# If HELP environmental variable is non-empty,
# cat the README file and exit.
#
# Start with checking for the CLOUDSTREAM readme, which is default.
# Then, assuming it will be named README[.md/.txt], cat other
# README file which might have been copied in. Finally, print
# out the version file.
#
###
if [ "x${HELP}" != "x" ]; then

    if [ -e "${BUNDLEDIR}/CLOUDSTREAM_README.md" ]; then
        cat "${BUNDLEDIR}/CLOUDSTREAM_README.md"
    fi
    echo ""

    if [ -e "$README_FILE" ]; then
      cat "$README_FILE"
    fi
    echo ""

    if [ "${BUNDLEDIR}/VERSION.md" ]; then
        cat "${BUNDLEDIR}/VERSION.md"
    fi

    exit
fi


if [ "x${COPYRIGHT}" != "x" ]; then
  if [ -e "${BUNDLEDIR}/COPYRIGHT_CLOUDSTREAM.md" ]; then
    cat "${BUNDLEDIR}/COPYRIGHT_CLOUDSTREAM.md"
  fi
  echo ""

  if [ -e "${COPYRIGHT_FILE}" ]; then
    cat "${COPYRIGHT_FILE}"
  fi

  exit

fi

###
# Print out the version file.
###
if [ "x${VERSION}" != "x" ]; then
    cat VERSION.md
    echo ""
    exit
fi

###
# Determine if we're using SSL Only.
###
SSLOP=""
if [ "x${SSLONLY}" == "xTRUE" ]; then
    SSLOP="--ssl-only"
fi

echo ""
echo ""
echo "================================"
cat VERSION.md
echo "================================"
echo ""
echo ""

main

if [ -f ${BUNDLEDIR}/start.sh ]; then
    echo ""
    echo "start.sh script detected.  Running start.sh"
    echo ""
    ${BUNDLEDIR}/start.sh
fi

wait $!

exit
