#!/usr/bin/env bash
#Muhammed Niyazi ALPAY
#https://niyazi.org
#admin@niyazi.org
while getopts d:c:i:s:h: option
do
case "${option}"
in
d) domainname=${OPTARG};;
c) defaultcert=${OPTARG};;
i) serverip=${OPTARG};;
s) staging=${OPTARG};;
h) help=${OPTARG};;
esac
done

letsencrypt()
{
	datenow=$(date '+%Y-%m-%d-%H-%M-%S')

	if [ -z ${staging} ]; then
		apiurl="https://acme-v02.api.letsencrypt.org/directory"
	else
		if [ ${staging} == "true" ]; then
			apiurl="https://acme-staging-v02.api.letsencrypt.org/directory"
		else
			apiurl="https://acme-v02.api.letsencrypt.org/directory"
		fi
	fi

	#creating certificate - start
	sh /root/.acme.sh/acme.sh --issue -d ${domainname} -d *.${domainname} -k 4096 --dns dns_cf --server ${apiurl} --force
	#creating certificate - end

	#installing certificate - start
	if [ -z ${defaultcert} ]; then
		/usr/sbin/plesk bin certificate -c "LetsEncrypt-$domainname-$datenow" -domain ${domainname} -key-file /root/.acme.sh/${domainname}/${domainname}.key -cert-file /root/.acme.sh/${domainname}/${domainname}.cer -cacert-file /root/.acme.sh/${domainname}/ca.cer
	else
		if [ -z ${defaultcert} == "true" ]; then
			/usr/sbin/plesk bin certificate -c "LetsEncrypt-$domainname-$datenow" -domain ${domainname} -default -key-file /root/.acme.sh/${domainname}/${domainname}.key -cert-file /root/.acme.sh/${domainname}/${domainname}.cer -cacert-file /root/.acme.sh/*.$domainname/ca.cer
			/usr/sbin/plesk bin server_pref -u -panel-certificate "LetsEncrypt-$domainname-$datenow" -certificate-repository ${domainname}
			/usr/sbin/plesk bin mailserver --set-certificate "LetsEncrypt-$domainname-$datenow" -certificate-repository ${domainname}
			/usr/sbin/plesk bin ipmanage -u ${serverip} -ssl_certificate "LetsEncrypt-*.$domainname-$datenow"
		else
			/usr/sbin/plesk bin certificate -c "LetsEncrypt-$domainname-$datenow" -domain ${domainname} -key-file /root/.acme.sh/${domainname}/${domainname}.key -cert-file /root/.acme.sh/${domainname}/${domainname}.cer -cacert-file /root/.acme.sh/${domainname}/ca.cer
		fi
	fi

	/usr/sbin/plesk bin subdomain -l | grep ${domainname} > site.txt

	while read line
	do
		if [ ${line} != "*.$domainname" ]; then
			echo ${line};
			/usr/sbin/plesk bin subscription -u ${line} -certificate-name "LetsEncrypt-$domainname-$datenow"
		fi
	done <site.txt
	rm -rf site.txt
	#installing certificate - end


	#removing old certificate - start
	/usr/sbin/plesk bin certificate -l -domain $domainname | grep "LetsEncrypt" | awk {'print $5'} | egrep -vi "Name|repository|LetsEncrypt-$domainname-$datenow" > old_certificate.txt

	while read certline
	do
		if [ -n ${certline} ]; then
			/usr/sbin/plesk bin certificate -r "$certline" -domain ${domainname}
		fi
	done < old_certificate.txt
	rm -rf old_certificate.txt
	#removing old certificate - end
}

setup()
{
if [ -f "/root/.acme.sh/acme.sh" ]
then
    if [ -f "/root/.acme.sh/account.conf" ]; then
	    letsencrypt
	else
	    read -p "Cloudflare Email Address: " cf_email
	    read -p "Clouflare API key:" cf_apikey
	    echo "
export CF_Key='$cf_apikey'
export CF_Email='$cf_email'
SAVED_CF_Key='$cf_apikey'
SAVED_CF_Email='$cf_email'" > /root/.acme.sh/account.conf
	    letsencrypt
	fi
else
	git clone https://github.com/Neilpang/acme.sh.git
	mv acme.sh .acme.sh
	read -p "Cloudflare Email Address: " cf_email
	read -p "Clouflare API key:" cf_apikey
	echo "
export CF_Key='$cf_apikey'
export CF_Email='$cf_email'
SAVED_CF_Key='$cf_apikey'
SAVED_CF_Email='$cf_email'" > /root/.acme.sh/account.conf
	letsencrypt
fi
}

ipcheck()
{
    /usr/sbin/plesk bin ipmanage -l | awk {'print $3'} | grep -vi "IP" | cut -d ":" -f 2 | cut -d "/" -f 1 > ip.txt
    IP=$(cat ip.txt | grep "$serverip")
    if [ -z ${IP} ]; then
     echo "$serverip IP address is not defined for this server"
     exit
    else
     echo "IP found"
    fi
    rm -rf ip.txt
}

help()
{
    echo "How to use?
    -d = Domain name
    -c = true/false - Default certificate for Plesk services. The -i parameter is also required for this parameter. Default value is false
    -i = Server IP address
    -s = true/false - Staging mode. Defauult value is false
    -h = Help menu"

}

if [ -z ${help} ]; then
    if [ -z ${domainname} ]; then
        help
    else
        if [ -z ${defaultcert} ]; then
            setup
        else
            if [ -z ${serverip} ]; then
                echo "Default Certificate is required for server IP. -i argument is required"
                exit
            else
                ipcheck
                setup
            fi
        fi
    fi
else
    help
    exit
fi

