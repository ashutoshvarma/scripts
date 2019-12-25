#!/bin/bash

# Template script for NetworkManager-dispatcher
# Note:-
# Make sure that NetworkManager-dispatcher.service is enabled
# Place the script in /etc/NetworkManager/dispatcher.d/. Do not symlink.
# Script must be owned by root, otherwise the dispatcher will not execute them.
#   => chown root:root /etc/NetworkManager/dispatcher.d/10-script.sh
# Make sure it has right permissions, 755.
# Read more at https://wiki.archlinux.org/index.php/NetworkManager#Network_services_with_NetworkManager_dispatcher


IF=$1
STATUS=$2   # up down 

case "$2" in
    up)
    /path/to/login.py username password -o /path/to/log
    ;;
    *)
    ;;
esac


