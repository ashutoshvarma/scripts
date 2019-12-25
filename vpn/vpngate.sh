#!/usr/bin/env bash
#: Title        : VPNGate connect script
#: Date         : 25-12-2019
#: Author       : Ashutosh Varma (ashutoshvarma11@live.com)
#  License      : MIT
#: Version      : 0.1
#: Description  : Connects to VPNGate community server using openvpn
#: NOTE         : It will kill all openvpn process before starting vpn.


PORT_TIMEOUT=2
VPNGATE_API="http://www.vpngate.net/api/iphone/"

OPENVPN_DIR="/etc/openvpn/client"
OPENVPN_CLIENT_SERVICE="openvpn-client"

AUTH_FILE=${OPENVPN_DIR}/'vpnauth'
UP_FILE=${OPENVPN_DIR}/'up.sh'
DOWN_FILE=${OPENVPN_DIR}/'down.sh'

CACHE_VPN='vpn.cache'
CACHE_TIMEOUT_DAYS=1

function _mkhelper_files(){
    _mkauthfile

    if ! [[ -s $UP_FILE ]] || ! [[ -x $UP_FILE ]]; then
        echo "$(_up_script)" | sudo tee $UP_FILE >/dev/null
        sudo chmod +x $UP_FILE
    fi

    if ! [[ -s $DOWN_FILE ]] || ! [[ -x $DOWN_FILE ]]; then
        echo "$(_down_script)" | sudo tee $DOWN_FILE >/dev/null
        sudo chmod +x $DOWN_FILE
    fi
}

function _mkauthfile(){
    if ! [[ -s $AUTH_FILE ]]; then
        printf "vpn\nvpn" | sudo tee $AUTH_FILE >/dev/null
    fi
}

function _up_script(){
    printf "%s \n" "#!/usr/bin/env bash"
    printf "%s \n" "echo \"Changing DNS in resolv.conf\""
    printf "%s \n" "mv -f /etc/resolv.conf /etc/resolv.conf.bak "
    printf "%s \n" "printf 'nameserver 1.0.0.1 \nnameserver 8.8.8.8' > /etc/resolv.conf "  
}

function _down_script(){
    printf "%s \n" "#!/usr/bin/env bash"
    printf "%s \n" "echo \"Restoring resolv.conf\""
    printf "%s \n" "mv -f /etc/resolv.conf.bak /etc/resolv.conf "
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


# Connects to VPNGate vpn using base64 encoded config file
# Parameters:
#   Single row of vpngate api csv as positional args
# Returns:
#   0 - Connected
#   1 - OpenVPN Error
#   2 - Cannot kill other openvpn process
function _connect_vpn(){
    local vpn=("$@")
    local open_config=$(_decode ${vpn[14]})
    local vpn_name=${vpn[0]}-${vpn[6]}
    local config_file=${OPENVPN_DIR}/${vpn_name}.conf

    # save openvpn config to /etc/openvpn/ (not using redirection cuz it will lead to permission error.)
    sed "s/#auth-user-pass/auth-user-pass ${AUTH_FILE//\//\\/}/g" <<< "$open_config" | sudo tee ${config_file} &>/dev/null
    # Add up and down scripts to fix DNS (should have use update-systemd-resolved but that would increase dependancies)
    printf "%s \n%s \n%s \n" "script-security 2" "up ${UP_FILE}" "down ${DOWN_FILE}" | sudo tee -a ${config_file} &>/dev/null

    if is_openvpn_running "$vpn_name";then
        kill_openvpn "$vpn_name" && return 2
    fi

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

}


function vpn(){
    while read -r line; do
        IFS="," 
        local vpn=($line)
        local vpn_name=${vpn[0]}-${vpn[6]}

        # Check VPN
        if _check_vpn ${vpn[14]}; then
            echo "'$vpn_name' : Working"
            echo "Trying to connect to ${vpn_name}."

            # Connecting to VPN
            _connect_vpn "${vpn[@]}"
            ec=$?
            if ((ec == 0)); then
                echo "Sucessuflly connected to $vpn_name."
                exit 0
            else
                ((ec == 1)) && { echo 'Failed to connect to "${vpn_name}".'; echo;}
                ((ec == 2)) && { echo "Cannot kill running OpenVPN process. Retry after killing all instances of openvpn"; exit 2; }
            fi
        else
            echo "${vpn_name} : Not Working"
        fi
    done <<< $(_getcsv)
}

_mkhelper_files
vpn
