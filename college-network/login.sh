#!/usr/bin/bash
#: Title        : login
#: Date         : 05-10-2019
#: Author       : Ashutosh Varma
#: License      : MIT
#: Version      : 1.0
#: Description  : Personal script to login into college network
#: NOTE         : NONE

#login 
LOGIN_URL="http://172.16.16.16:8090/login.xml"
VERBOSE=""

MAX_TIMEOUT='6'
CONNECTION_TIMEOUT='5'

#UNIX Timestamp, seconds from 1 Jan 1970 till now.
epoch_time="date +%s"

function _curl_post(){
    data="mode=191&username=${1}&password=${2}&a=$(${epoch_time})&producttype=0"

    curl -i ${VERBOSE} -m ${MAX_TIMEOUT} --connect-timeout ${CONNECTION_TIMEOUT} -d $data\
    -H "Host: 172.16.16.16:8090"\
    -H "Connection: keep-alive"\
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)"\
    -H "Content-Type: application/x-www-form-urlencoded"\
    -H "Origin: http://172.16.16.16:8090"\
    -H "Referer: http://172.16.16.16:8090/httpclient.html"\
    -H "Accept-Encoding: gzip, deflate"\
    -H "Accept-Language: en-IN,en-US;q=0.9,en;q=0.8"\
    "$LOGIN_URL" 2>/dev/null
    # echo $#
}


function login(){
    if msg=$(echo $(_curl_post "$1" "$2") | grep -Po "(?<=<message><!\[CDATA\[)(.+?)(?=]]><\/message>)"); then
        echo "$msg"
    else
        echo "[ERROR]: Cannot connect to the login portal. Check network connection."
        echo "Info: Your MAC might be blacklisted, so try changing that."
    fi
}


if [[ $# -gt 1 ]]; then
    login $1 $2
else
    echo "Usage:-"
    echo "login.sh USERNAME PASSWORD"
fi

