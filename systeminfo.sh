#!/bin/bash
echo "Collecting system information. Please wait..."

FILE_NAME="systeminfo.txt"
[ -e FILE_NAME ] && rm file

exec > /dev/null 2>&1

# Check if Debian/RedHat based
if [ -e /etc/debian_version ]; then
    DEB_BASED=true
    apt install sysstat -y
elif [ -e /etc/redhat-release ]; then
    RH_BASED=true
    yum install sysstat -y
else
    UNKNOWN_BASE=true
fi

# Check if systemd. Not perfect.
if [[ "SYSTEMD" = *"$(strings /sbin/init | awk 'match($0, /(upstart|systemd|sysvinit)/) { print toupper(substr($0, RSTART, RLENGTH));exit; }')"* ]]; then
    SYSTEMD_BASED=true
fi

# Initial iptables-save.
iptables-save

exec > $FILE_NAME 2>&1

echo "===== CPU ====="
mpstat
printf "\n"
top -bn 1 | head
echo "--------------------"
printf "\n"

echo "===== MEMORY ====="
vmstat -sS M
printf "\n"

top -bn 1 -o %MEM | head
echo "--------------------"
printf "\n"

echo "===== netstat ====="
ss -tulpn | column
echo "--------------------"
printf "\n"

echo "===== df ====="
df -BM
printf "\n"
df -i
echo "--------------------"
printf "\n"

echo "===== network ====="
ip r
printf "\n"
ip a
echo "--------------------"
printf "\n"

echo "===== iptables ====="
iptables-save
echo "--------------------"
printf "\n"

if ! [ $UNKNOWN_BASE ]; then
    echo "===== Apache ====="
    if [ $DEB_BASED ]; then
        if [ $SYSTEMD_BASED ]; then
            systemctl status apache2 | cat
        else
            service apache2 status | cat
        fi
    fi  
    if [ $RH_BASED ]; then
        if [ $SYSTEMD_BASED ]; then
            systemctl status httpd | cat
        else
            service httpd status | cat
        fi
    fi
    echo "--------------------"
    printf "\n"

    echo "===== nginx ====="
    if [ $SYSTEMD_BASED ]; then
        systemctl status nginx | cat
    else
        service nginx status | cat
    fi
    echo "--------------------"
    printf "\n"

    echo "===== MySQL ====="    
    if [ $DEB_BASED ]; then
        if [ $SYSTEMD_BASED ]; then
            systemctl status mysql | cat
        else
            service mysql status | cat
        fi
    fi  
    if [ $RH_BASED ]; then
        if [ $SYSTEMD_BASED ]; then
            systemctl status mysqld | cat
        else
            service mysqld status | cat
        fi
    fi
    echo "--------------------"
    printf "\n"

    echo "===== PHP ====="
    if [ $SYSTEMD_BASED ]; then
        systemctl status php-fpm | cat
    else
        service php-fpm status | cat
    fi
    echo "--------------------"
    printf "\n"
fi

echo "===== ps ====="
ps -aux
echo "--------------------"
printf "\n"

echo "===== syslog ====="
tail -100 /var/log/syslog
echo "--------------------"
printf "\n"


function format_JSON() {
    sed -e 's/\\/\\\\/g' \
    -e 's/$/\\n/g' \
    -e 's/"/\\"/g' \
    -e 's/\t/\\t/g' \
    | tr -d "\n"
}

CONTENT=
if [ -f "${FILE_NAME}" ]; then
    CONTENT="\"$(format_JSON < "${FILE_NAME}")\""
fi

# Output to tty again.
exec 1> /dev/tty

echo "Collection complete. Uploading data anonymously to GitHub..."
echo "{\"public\": \"false\", \"files\": {\"${FILE_NAME}\": {\"content\": ${CONTENT}}}}" \
    | curl  --silent -X POST -H 'Content-Type: application/json' -d @- https://api.github.com/gists \
    | grep "html_url" \
    | head -n 1 \
    | sed '{;s/"//g;s/,$//;s/\s\shtml_url/URL/;}' >&1

# Check if gist was successful
if [ ${PIPESTATUS[2]} -ne 0 ]; then
    echo "ERROR: Failed to upload files. Please view $FILE_NAME" >&1
    exit 1
else
    rm -rf $FILE_NAME
fi