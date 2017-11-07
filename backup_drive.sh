#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "usage: backup_drive.sh USER@DESTINATION_HOSTNAME /path/to/source /path/to/destination"
    exit 1
fi

DESTINATION=$1
SRC_PATH=$2
DEST_PATH=$3

trap "exit" INT
set -e

function set_prev() {
    prev=$(ssh ${DESTINATION} 'set -e && snapshots=('${DEST_PATH}'/*) && echo ${snapshots[${#snapshots[@]}-1]}')
}

set_prev

if [ "$prev" == "${DEST_PATH}/*" ]; then
    echo "No existing backups. Creating dummy directory."
    ssh ${DESTINATION} mkdir ${DEST_PATH}/$(date -Iseconds)
    set_prev
fi

prev_exists=$(ssh ${DESTINATION} 'if [ -d "'$prev'" ]; then echo 1; else echo 0; fi')

if [ "$prev_exists" == "0" ]; then
    echo "Existing backup directory $prev does not exist."
    exit 1
fi


echo "Doing incremental backup based on snapshot from ${prev}"

read -p "Source: ${SRC_PATH} Destination: ${DEST_PATH} link-dest: ${prev} Continue (y/N)? " confirm
if [ "$confirm" != "y" ]; then
    echo "Aborting"
    exit 1
fi

rsync -az --no-i-r --info=progress2 --human-readable -e ssh --link-dest="${prev}" "${SRC_PATH}/"  "${DESTINATION}:${DEST_PATH}/0_current/"

ssh "${DESTINATION}" "cd ${DEST_PATH} && mv 0_current $(date -Iseconds)"

exit 0
