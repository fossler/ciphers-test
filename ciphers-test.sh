#!/usr/bin/env bash

# SOURCE: http://superuser.com/questions/109213/how-do-i-list-the-ssl-tls-cipher-suites-a-particular-website-offers

# OpenSSL requires the port number.
SERVER="owa.record.ch:443"
DELAY=1
ciphers=$(openssl ciphers 'ALL:eNULL' | sed -e 's/:/ /g')


echo "Obtaining cipher list from $(openssl version)."

for cipher in ${ciphers[@]}
do
echo -n Testing $cipher...
result=$(echo -n | openssl s_client -cipher "$cipher" -connect $SERVER 2>&1)
if [[ "$result" =~ ":error:" ]] ; then
  error=$(echo -n $result | cut -d':' -f6)
  echo NO \($error\)
else
  if [[ "$result" =~ "Cipher is ${cipher}" || "$result" =~ "Cipher    :" ]] ; then
    echo YES
  else
    echo UNKNOWN RESPONSE
    echo $result
  fi
fi
sleep $DELAY
done


###################################################################################################################


DOMAINS=(
'record.ch 443'
'owa.record.ch 443'
'smtp.agta-record.com 993'
)

function check_ssl_cert()
{
    host=$1
    port=$2
    proto=$3

    if [ -n "$proto" ]
    then
        starttls="-starttls $proto"
    else
        starttls=""
    fi

    cert=`openssl s_client -servername $host -host $host -port $port -showcerts $starttls -prexit </dev/null 2>/dev/null |
              sed -n '/BEGIN CERTIFICATE/,/END CERT/p' |
              openssl x509 -text 2>/dev/null`
    end_date=`echo "$cert" | sed -n 's/ *Not After : *//p'`

    end_date_seconds=`date '+%s' --date "$end_date"`
    now_seconds=`date '+%s'`
    end_date=$(echo "($end_date_seconds-$now_seconds)/24/3600" | bc)

    issue_dn=`echo "$cert" | sed -n 's/ *Issuer: *//p'`
    issuer=`echo $issue_dn | sed -n 's/.*CN=*//p'`

    serial=`echo "$cert" | openssl x509 -serial -noout`
    serial=`echo $serial | sed -n 's/.*serial=*//p'`

    printf "| %30s | %5s | %-13s | %-40s | %-50s |\n" "$host" "$port" "$end_date" "$serial" "${issuer:0:50}"
}


printf "%s\n" "+--------------------------------------------------------------------------------------------------------------------------------------------------------+"
printf "| %30s | %5s | %-13s | %-40s | %-50s |\n" "Domain" "Port" "Expire (days)" "Serial" "Issuer"
printf "%s\n" "|--------------------------------|-------|---------------|------------------------------------------|----------------------------------------------------|"
for domain in "${DOMAINS[@]}"; do
    check_ssl_cert $domain
done
printf "%s\n" "+--------------------------------------------------------------------------------------------------------------------------------------------------------+"

exit
