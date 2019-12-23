PORT_TIMEOUT=2
VPNGATE_API="http://www.vpngate.net/api/iphone/"

AUTH_FILE=$(pwd)'/vpnauth.txt'
OPENVPN_DIR="/etc/openvpn"

CACHE_VPN='vpn.cache'
CACHE_TIMEOUT_DAYS=1

function _mkauthfile(){
    if ! [ -s $AUTH_FILE ]; then
        echo "vpn" > $AUTH_FILE
        echo "vpn" >> $AUTH_FILE
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


function connect_vpn(){
    while read -r line; do
        IFS="," 
        local vpn=($line)
        if _check_vpn ${vpn[14]}; then
            _mkauthfile
            local open_config=$(_decode ${vpn[14]})
            # save openvpn config to /etc/openvpn/ (not using redirection cuz it will lead to permission error.)
            sed "s/#auth-user-pass/auth-user-pass ${AUTH_FILE//\//\\/}/g" <<< "$open_config" | sudo tee ${OPENVPN_DIR}/${vpn[0]}-${vpn[6]}.ovn &>/dev/null
            echo "${vpn[0]}-${vpn[6]} : Working"
            exit 0
        else
            echo "${vpn[0]}-${vpn[6]} : Not Working"
        fi
    done <<< $(_getcsv)
}

connect_vpn
