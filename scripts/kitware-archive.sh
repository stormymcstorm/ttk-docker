#!/bin/sh

apt-get update

apt-get install --no-install-recommends -yqq  ca-certificates wget gpg

wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null

debian_code_name=$(cat /etc/debian_version)
case "$debian_code_name" in
    "11.7")
        release="focal"
        ;;
    "12.1")
        release="jammy"
        ;;
    *)
        echo "Unrecognized debian version $debian_code_name"
        exit 1
        ;;
esac

echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${release} main" > /etc/apt/sources.list.d/kitware.list