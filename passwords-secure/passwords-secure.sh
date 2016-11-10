#!/bin/bash
#
# Cas van der Weegen
# <vdweegen@protonmail.ch>
# 
# Description: Secure Storage of passwords in Non-Secure Places
#
# Licence:
#
# The MIT License (MIT)
# Copyright (c) 2015 Cas van der Weegen <vdweegen@protonmail.ch>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"),to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
# OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Generating keys:
#       openssl genrsa -out private_key.pem 2048
#       openssl rsa -in private_key.pem -out public_key.pem -outform PEM -pubout

PW_FILE="${HOME}/Dropbox/password-store.txt"
PRIV_KEY="${HOME}/.pwkeys/private_key.pem"
PUB_KEY="${HOME}/.pwkeys/public_key.pem"
for i in "$@"
do
case $i in
    -a=*|--add=*)
    ADD="${i#*=}"
    shift   # past argument=value
    ;;
    *)
            # unknown option
    ;;
esac
done

# Create empty file if doesn't exist
if [ ! -f "$PW_FILE" ];
then
    touch $PW_FILE
fi

# Some settings for printing
WIDTH=160
DIVIDER="$(yes = | head -${WIDTH} | tr -d "\n")"
HEADER="\n %-30s %-40s %-40s %-50s\n"
FORMAT=" %-30s %-40s %-40s %-50s\n"


if [ -z "$ADD" ];
then
    case $# in
        1)
            KEY="$(echo $1 | tr '[:upper:]' '[:lower:]' | openssl sha1 -md5 -hex)"
            KEY="${KEY#*= }"
            printf "$HEADER" "SECTION" "USERNAME" "PASSWORD" "DESCRIPTION"
            printf "%$WIDTH.${WIDTH}s\n" "$DIVIDER"
            cat $PW_FILE | grep $KEY | while read LINE
            do
                LINE=(${LINE//;/ })
                ENTRY="$(echo ${LINE[1]} | base64 --decode --ignore-garbage | openssl rsautl -decrypt -inkey "${PRIV_KEY}")"
                VALS=(${ENTRY// / })
                printf "$FORMAT" \
                "${VALS[0]}" "${VALS[1]}" "${VALS[2]}" "${VALS[3]//_/ }"
            done
        ;;
        *)
            echo "Wrong number of arguments passed"
            echo "You can add passwords by using -a=<name> or --add=<name>"
            echo "You can view password by specifying the secion name as argument"
            exit -1
        ;;
esac
else    
    echo "Adding password to section: ${ADD}"
    echo -n "Username:"
    read USERNAME
    echo -n "Password:"
    read -s PASSWORD
    echo
    echo -n "Extra description (optional):"
    read DESCRIPTION
    
    DESCRIPTION="${DESCRIPTION// /_}"
    
    # Convert section to md5 using OpenSSL, Make lowercase
    CADD="$(echo ${ADD} | tr '[:upper:]' '[:lower:]' | openssl sha1 -md5 -hex)"
    # Clean stdin message
    CADD="${CADD#*= }"
    # Construct entry to be stored
    ENTRY="${ADD} ${USERNAME} ${PASSWORD} ${DESCRIPTION}"
    
    # Do some cleaning
    unset USERNAME      # Cleanup
    unset PASSWORD      # Cleanup
    unset DESCRIPTION   # Cleanup
    unset ADD           # Cleanup
    
    # Encrypt the Entry
    CRYPT="$(echo ${ENTRY} | openssl rsautl -encrypt -inkey "${PUB_KEY}" -pubin | base64 --wrap=0)"
    unset ENTRY         # Cleanup
    
    # Finish up
    echo -e "${CADD};${CRYPT}" >> $PW_FILE    
    unset CRYPT         # Cleanup
    unset CADD          # Cleanup
    echo "Added password to storage"
fi
