PORT_TIMEOUT=2
VPNGATE_API="http://www.vpngate.net/api/iphone/"

AUTH_FILE='vpnauth.txt'
CACHE_VPN='vpn.cache'
CACHE_TIMEOUT_DAYS=1

function mkauthfile(){
    if ! [ -s $AUTH_FILE ]; then
        echo "vpn" > $AUTH_FILE
        echo "vpn" >> $AUTH_FILE
    fi
}

function getcsv(){
    cache_expires=$(date -d "now - ${CACHE_TIMEOUT_DAYS} days" +%s)
    cache_date=$(date -r "$CACHE_VPN" +%s 2>/dev/null|| echo 0)
    if (( cache_date <= cache_expires )); then
        echo "Refeshing VPN list. This may take a while."
        curl -L -o $CACHE_VPN ${VPNGATE_API} 2>/dev/null
    fi
    egrep -v "[*#]" $CACHE_VPN
}

function decode(){
    echo "$1" | base64 -d 2>/dev/null
}

function check_port(){ 
    timeout  ${PORT_TIMEOUT}s /bin/bash -c "echo EOF > /dev/tcp/$1/$2" &>/dev/null || return 1
}

function check_vpn(){
    #OpenVPN config data
    local oconfig=$(decode $1)   

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
        vpn=($line)
        check_vpn ${vpn[14]}
        if check_vpn ${vpn[14]}; then
            mkauthfile
            open_config=$(decode ${vpn[14]})
            sed "s/#auth-user-pass/auth-user-pass ${AUTH_FILE}/g" <<< "$open_config" > ${vpn[0]}-${vpn[6]}.ovn
            echo "${vpn[0]}-${vpn[6]} : Working"
            exit 0
        else
            echo "${vpn[0]}-${vpn[6]} : Not Working"
        fi
    done <<< $(getcsv)
}

connect_vpn
