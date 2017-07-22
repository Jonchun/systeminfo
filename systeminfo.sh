#!/bin/bash
FILE_NAME="systeminfo.txt"
[ -e FILE_NAME ] && rm file

exec > $FILE_NAME 2>/dev/null

# Check if Debian/RedHat based
if [ -e /etc/debian_version ]; then
    DEB_BASED=true
elif [ -e /etc/redhat-release ]; then
    RH_BASED=true
else
    UNKNOWN_BASE=true
fi

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

echo "===== ip ====="
ip r
printf "\n"
ip a
echo "--------------------"
printf "\n"

if ! [ $UNKNOWN_BASE ]; then
    echo "===== Apache ====="
    if [ $DEB_BASED ]; then
        service apache2 status | cat
    fi  
    if [ $RH_BASED ]; then
        service httpd status | cat
    fi
    echo "--------------------"
    printf "\n"

    echo "===== nginx ====="
    service nginx status | cat
    echo "--------------------"
    printf "\n"

    echo "===== MySQL ====="    
    if [ $DEB_BASED ]; then
        service mysql status | cat
    fi  
    if [ $RH_BASED ]; then
        service mysqld status | cat
    fi
    echo "--------------------"
    printf "\n"

    echo "===== PHP ====="
    service php-fpm status | cat
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

function format_file_as_JSON_string() {
    sed -e 's/\\/\\\\/g' \
    -e 's/$/\\n/g' \
    -e 's/"/\\"/g' \
    -e 's/\t/\\t/g' \
    | tr -d "\n"
}

USER=
FILENAME=
FILE=$FILE_NAME
CONTENT=
DESCRIPTION=
PUBLIC="false"
# Here we treat the argument as a file on the local system
if [ -f "${FILE}" ]; then
    if [ -z "${FILENAME}" ]; then
    # Strip everything but the filename (/usr/test.txt -> test.txt)
    FILENAME="\"$(basename "${FILE}")\""
    fi
    CONTENT="\"$(format_file_as_JSON_string < "${FILE}")\""
fi

exec 1> /dev/tty

echo "{${DESCRIPTION}\"public\": ${PUBLIC}, \"files\": {${FILENAME}: {\"content\": ${CONTENT}}}}" \
    | curl --silent -X POST -H 'Content-Type: application/json' -d @- https://api.github.com/gists \
    | grep "html_url" \
    | head -n 1 \
    | sed '{;s/"//g;s/,$//;s/\s\shtml_url/URL/;}' >&1

rm -rf $FILE_NAME
# If we could not find the html_url in the response, then we have to tell the
# user that the http request failed and that his/her gist was not posted
if [ ${PIPESTATUS[2]} -ne 0 ]; then
    echo "ERROR: gist failed to post, script exiting..." >&1
    exit 1
fi
