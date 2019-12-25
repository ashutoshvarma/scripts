#!/usr/bin/env python3
"""
Exit Codes:- 
    0 - Sucessfully SIGN IN.
    1 - Connection Error
    2 - Invalid Username/Password
    3 - Max Limit Reached
    4 - Login API connection problem
    5 - Unknown Response from Login API

   -1 - Python version is lower than 3.6
   -2 - Requests module not installed
"""

__author__ = "Ashutosh Varma"
__copyright__ = "Copyright 2019, Ashutosh Varma"
__license__ = "MIT"


import sys
import re
from os import linesep
from time import time, localtime, strftime
import argparse

# Check for python version.
# f-strings are introduced in 3.6.
if not (sys.version_info.major >= 3 and sys.version_info.minor >= 6):
    print("ERROR: Script is only compatible with python 3.6 or higher")
    exit(-1)

try:
    import requests
except ModuleNotFoundError:
    print("Error: Cannot import requests module.")
    exit(-2)


# Constants
headers = {
    "Host": "172.16.16.16:8090",
    "Connection": "keep-alive",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.16 Safari/537.36",
    "Content-Type": "application/x-www-form-urlencoded",
    "Accept": "*/*",
    "Origin": "http://172.16.16.16:8090",
    "Referer": "http://172.16.16.16:8090/httpclient.html",
    "Accept-Encoding": "gzip, deflate",
    "Accept-Language": "en-IN,en-US;q=0.9,en;q=0.8"
}

login_url = "http://172.16.16.16:8090/login.xml"
# logout_url = "http://172.16.16.16:8090/logout.xml"


xml_search_str = {
    "sucess": "LIVE",
    "failed": "Login failed. Invalid user name/password",
    "max_limit": "You have reached the maximum login limit",
    "logout": "signed out",
    "connection_problem": "Unable to access auth service"
}

LOG_PATH = None

# Utilts


def time_milli() -> int:
    return int(time() * 1000)


def log(msg, type="INFO", stdout=True, file=LOG_PATH) -> None:
    if not file:
        file = LOG_PATH
    ctime = strftime("%a, %d %b %Y %H:%M:%S", localtime())
    msg = f"{ctime}: [{type.upper()}] {msg} {linesep}"
    if stdout:
        print(msg, end="")
    if file:
        try:
            with open(file, 'a+') as logf:
                logf.write(msg)
        except:
            log(f"Cannot Write logs to file {file}.", "ERROR")


def scrap_xml_msg(xml: str) -> str:
    re_msg = re.compile(r"(?<=<message><!\[CDATA\[)(.+?)(?=]]><\/message>)")
    m = re_msg.search(xml)
    if m:
        return m.string
    else:
        return ""


def req_login(username: str, password: str, producttype: int = 0) -> requests.Response:
    payload = f"mode=191&username={username}&password={password}&a={time_milli()}&producttype=0"
    return requests.post(login_url, data=payload, headers=headers)


def login(username: str, password: str, verbose: bool):
    try:
        resp = req_login(username, password, verbose)
    except:
        log("Cannot connect to the login portal. Check network connection.", "error")
        log("Your MAC might be blacklisted, so try changing that.", "info")
        exit(1)
    else:
        if resp.status_code == 200:
            response_xml = resp.text
            # Check for sucessful login
            if xml_search_str['sucess'] in response_xml:
                log(f"Sign IN Sucessful. Username-{username}", "success")
                exit(0)
            elif xml_search_str['failed'] in response_xml:
                log(xml_search_str['failed'] +
                    f". Username-{username}", "error")
                exit(2)
            elif xml_search_str['max_limit'] in response_xml:
                log(xml_search_str['max_limit'] +
                    f". Username-{username}", "error")
                exit(3)
            elif xml_search_str['connection_problem'] in response_xml:
                log(xml_search_str['connection_problem'] +
                    f". Username-{username}", "error")
                exit(4)
            else:
                msg = scrap_xml_msg(response_xml)
                if msg:
                    log(msg, "error")
                else:
                    log(f"ERROR: Unkown Error Occurred with Username-{username}. ResponseXML:-" +
                        linesep + response_xml, "error")
                exit(5)
        else:
            log("Cannot Connect to login portal. Status-Code: " +
                resp.status_code, "error")


def parseargs():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Python Script for logging into GGSIPU college network.",
        epilog=__doc__)
    parser.add_argument(
        "username", type=str, help="Your username. Usually it is your 11 digit roll no.")
    parser.add_argument("password", type=str, help="Password to login with.")

    parser.add_argument("-o", "--log", type=str,
                        help="Path of Log file.", metavar="logfile")
    parser.add_argument("-v", "--verbose", action="store_true")

    return parser.parse_args()


if __name__ == "__main__":
    args = parseargs()
    LOG_PATH = args.log
    login(args.username, args.password, args.verbose)
