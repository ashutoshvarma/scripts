PORT_TIMEOUT=2
VPNGATE_API="http://www.vpngate.net/api/iphone/"

OPENVPN_DIR="/etc/openvpn/client"
OPENVPN_CLIENT_SERVICE="openvpn-client"

AUTH_FILE=${OPENVPN_DIR}/'vpnauth'
CACHE_VPN='vpn.cache'
CACHE_TIMEOUT_DAYS=1

function _mkauthfile(){
    if ! [ -s $AUTH_FILE ]; then
        # echo "vpn" > $AUTH_FILE
        # echo "vpn" >> $AUTH_FILE
        printf "vpn\nvpn" | sudo tee $AUTH_FILE >/dev/null
    fi
}

function _getcsv(){
    local cache_expires=$(date -d "now - ${CACHE_TIMEOUT_DAYS} days" +%s)
    local cache_date=$(date -r "$CACHE_VPN" +%s 2>/dev/null|| echo 0)
    if (( cache_date <= cache_expires )); then
        # Redirect 1 to 2 because in coonect_vpn we use commant substitition
        # Which capture this msg also
        echo "Refeshing VPN list. This may take a while." 1>&2
        curl -# -L -o $CACHE_VPN ${VPNGATE_API} 
    fi
    egrep -v "[*#]" $CACHE_VPN
}

function _decode(){
    echo "$1" | base64 -d 2>/dev/null
}

function check_port(){ 
    timeout  ${PORT_TIMEOUT}s /bin/bash -c "echo EOF > /dev/tcp/$1/$2" &>/dev/null || return 1
}

function _check_vpn(){
    #OpenVPN config data
    local oconfig=$(_decode $1)   

    # Get the hostname and port line ("remote <host> <port> /r/n")                       
    IFS=" " read -a host_port <<< $(grep -Po "^remote\s+.+" <<< "$oconfig")
    local hostname=${host_port[1]}
    local port=${host_port[2]//$'\r'}   #Remove the '\r' at ending
    unset IFS

    # Ignore UDP VPNs
    if egrep "^proto tcp" <<< "$oconfig" &>/dev/null; then
        check_port $hostname $port || return 1
    else
        return 1
    fi
}

function kill_openvpn(){
    sudo killall -SIGINT openvpn
    # sudo systemctl stop ${OPENVPN_CLIENT_SERVICE}@"$1" 
}

function is_openvpn_running(){
    pgrep openvpn || return 1
    # sudo systemctl status ${OPENVPN_CLIENT_SERVICE}@"$1" --no-pager
}

function _connect_vpn(){
    local vpn=("$@")
    local open_config=$(_decode ${vpn[14]})
    local vpn_name=${vpn[0]}-${vpn[6]}
    local config_file=${OPENVPN_DIR}/${vpn_name}.conf


    # save openvpn config to /etc/openvpn/ (not using redirection cuz it will lead to permission error.)
    sed "s/#auth-user-pass/auth-user-pass ${AUTH_FILE//\//\\/}/g" <<< "$open_config" | sudo tee ${config_file} &>/dev/null
    
    if is_openvpn_running "$vpn_name";then
        kill_openvpn "$vpn_name" && (echo "Cannot kill running OpenVPN process. Retry after killing all instances of openvpn"; exit 1)
    else
        echo NOVPN RUNNING
    fi

    echo "Trying to connect to ${vpn_name}."

    sudo systemctl start ${OPENVPN_CLIENT_SERVICE}@${vpn_name}

    # Our Logic to Test if OpenVPN connects sucessfully:_
    # - Check every n seconds for openvpn service status, if not running 
    #   then it must have failed. 
    # - If even after N seconds it is running then it must have succeded.
    #NOTE:- This is an extremely bad logic, CHANGE IT.
    for i in {1..4}; do
        if ! is_openvpn_running; then
            return 1
        fi
        sleep 1.5s
        echo i
    done
    return 0

    # if is_openvpn_running; then
    #     echo "Connected to ${vpn_name}."
    # else
    #     echo "Failed to Connect to ${vpn_name}"
    #     return 1
    # fi
}


function vpn(){
    while read -r line; do
        IFS="," 
        local vpn=($line)
        if _check_vpn ${vpn[14]}; then
            echo "${vpn[0]}-${vpn[6]} : Working"
            _connect_vpn "${vpn[@]}" && exit 0
        else
            echo "${vpn[0]}-${vpn[6]} : Not Working"
        fi
    done <<< $(_getcsv)
}

_mkauthfile
vpn
