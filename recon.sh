#! /bin/bash

# TODO: use domain_list.txt instead of one single domain as input

# Just some colors
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)

# Banner
echo "
 ______    _______  _______  _______  __    _        _______  __   __ 
|    _ |  |       ||       ||       ||  |  | |      |       ||  | |  |
|   | ||  |    ___||       ||   _   ||   |_| |      |  _____||  |_|  |
|   |_||_ |   |___ |       ||  | |  ||       |      | |_____ |       |
|    __  ||    ___||      _||  |_|  ||  _    | ___  |_____  ||       |
|   |  | ||   |___ |     |_ |       || | |   ||   |  _____| ||   _   |
|___|  |_||_______||_______||_______||_|  |__||___| |_______||__| |__|
"

DOMAIN=$1
OUT_DIR=$(readlink -f "$2")

# Checking if input exists
if [ "$#" -ne 2 ]
then
	echo "Please provide only two arguments. Domain and output directory"
	echo "Example usage: ./recon.sh domain.com /home/myuser/hacking/domain.com/recon"
	exit 1
fi

# Check for tools
for tool in anew assetfinder dnsenum haktrails subfinder nmap sublist3r amass chromium aquatone httpx knockpy # dnsx
do
	command -v ${tool} >/dev/null 2>&1 || { echo >&2 "This script requires ${tool} but it's not installed. Aborting."; exit 1; }
done

# Checking output directory
if [[ ! -d "${OUT_DIR}" ]]
then
	echo "The directory \"${OUT_DIR}\" does not exist"
	mkdir -p "${OUT_DIR}"
	if [ $? -ne 0 ]
	then
		echo "Error creating "${OUT_DIR}" directory"
		echo "Exiting"
		exit 1
	else
		echo "Directory "${OUT_DIR}" created"
	fi
elif [[ ! -w "${OUT_DIR}" ]]
then
	echo "You have no write access in "${OUT_DIR}""
	echo "Exiting"
	exit 1
else
	echo "Directory "${OUT_DIR}" exists"
fi

# assetfinder
assetfinder -subs-only ${DOMAIN} > ${OUT_DIR}/assetfinder.txt
cat ${OUT_DIR}/assetfinder.txt | anew ${OUT_DIR}/all_sub.txt

# haktrails subdomains
echo ${DOMAIN} | haktrails  subdomains -o list | tee -a ${OUT_DIR}/haktrails-subdomains.txt
cat ${OUT_DIR}/haktrails-subdomains.txt | anew ${OUT_DIR}/all_sub.txt

# haktrails associateddomains
echo ${DOMAIN} | haktrails  associateddomains -o list | tee -a ${OUT_DIR}/haktrails-associateddomains.txt
cat ${OUT_DIR}/haktrails-associateddomains.txt | anew ${OUT_DIR}/all_sub.txt

# subfinder
subfinder -silent -all -nW -d ${DOMAIN} -oI -o ${OUT_DIR}/subfinder.txt
cat ${OUT_DIR}/subfinder.txt | awk -F ',' '{print $1}' | anew ${OUT_DIR}/all_sub.txt

# sublist3r
sublist3r -d ${DOMAIN} -o ${OUT_DIR}/sublist3r.txt
cat ${OUT_DIR}/sublist3r.txt | anew ${OUT_DIR}/all_sub.txt

# amass
amass enum -d ${DOMAIN} -o ${OUT_DIR}/amass_enum.txt -nocolor
cat ${OUT_DIR}/amass_enum.txt | grep FQDN | awk '{print $1}' |  anew ${OUT_DIR}/all_sub.txt

# knockpy
mkdir -p ${OUT_DIR}/knockpy_tmp
knockpy ${DOMAIN} -o ${OUT_DIR}/knockpy_tmp
knockpy --csv ${OUT_DIR}/knockpy_tmp/*
cat ${OUT_DIR}/knockpy_tmp/*.csv  | awk -F ';' '{print $3}' | anew ${OUT_DIR}/all_sub.txt
mv ${OUT_DIR}/knockpy_tmp/*json ${OUT_DIR}/knockpy.json
mv ${OUT_DIR}/knockpy_tmp/*csv ${OUT_DIR}/knockpy.csv
rmdir ${OUT_DIR}/knockpy_tmp

# dnsenum
# without --noreverse, tool is kinda slow
dnsenum --nocolor --enum ${DOMAIN} --subfile ${OUT_DIR}/dnsenum_sub.txt --noreverse | tee -a ${OUT_DIR}/dnsenum.txt
#cat ${OUT_DIR}/dnsenum.txt | grep ${DOMAIN} | awk '{print $1}' | grep ${DOMAIN} | tr -d '_' | sed 's/\.$//' | anew ${OUT_DIR}/all_sub.txt 
cat ${OUT_DIR}/dnsenum_sub.txt | awk -v DOMAIN=${DOMAIN} '{print $1"."DOMAIN}' | anew ${OUT_DIR}/all_sub.txt
# IP file that dnsenum generates
if [[ -f "*_ips.txt" ]]; then
	mv *_ips.txt ${OUT_DIR}/dnsenum_ips.txt
fi



# dnsx
# TODO:Not working as expected. Check Wordlist
#dnsx -d ${DOMAIN} -o ${OUT_DIR}/dnsx.txt -w ~/Hacking/tools/SecLists/Discovery/DNS/dns-Jhaddix.txt

# aquatone
mkdir -p ${OUT_DIR}/aquatone
cat ${OUT_DIR}/all_sub.txt | aquatone -silent -out ${OUT_DIR}/aquatone/ -ports large

# alias (subdomain takeover)
for sub in $(cat ${OUT_DIR}/all_sub.txt); do host ${sub} | grep "is an alias"  >> ${OUT_DIR}/aliases.txt ; done

# httpx web ports
cat ${OUT_DIR}/aquatone/aquatone_urls.txt ${OUT_DIR}/all_sub.txt | sed -r 's/http[s]*:\/\///g' | sort -u |  httpx -silent -ports 66,80,81,443,445,457,1080,1100,1241,1352,1433,1434,1521,1944,2301,3000,3128,3306,4000,4001,4002,4100,5000,5432,5800,5801,5802,6346,6347,7001,7002,8000,8080,8100,8443,8888,30821 -status-code -cdn -cname -ip -fr -cl -td -o ${OUT_DIR}/httpx.txt

# nmap full
#mkdir -p ${OUT_DIR}/nmap
#for sub in $(cat ${OUT_DIR}/all_sub.txt) ; do nmap -Pn --top-ports 1000 -o ${OUT_DIR}/nmap/nmap_${sub}.txt ${sub}; done

# nmap vuln
# TODO: Check if this script is worth it here, maybe move to vuln_scan.sh?
#for sub in $(cat ${OUT_DIR}/all_sub.txt) ; do nmap -Pn --top-ports 1000 --script "vuln" -o ${OUT_DIR}/nmap/nmap_vuln_${sub}.txt ${sub}; done

printf "${GREEN}Script complete! Happy hunting! ${NORMAL}\n"
exit 0
