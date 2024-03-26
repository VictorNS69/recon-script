#! /bin/bash

# TODO: use domain_list.txt instead of one single domain as input

# Just some colors
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)

# Banner
echo "
                               _     
                              | |    
  ___  ____ _____ ____     ___| |__  
 /___)/ ___|____ |  _ \   /___)  _ \ 
|___ ( (___/ ___ | | | |_|___ | | | |
(___/ \____)_____|_| |_(_|___/|_| |_|
                                     
"

DOMAIN=$1
OUT_DIR=$(readlink -f "$2")

# Checking if input exists
if [ "$#" -ne 2 ]
then
	echo "Please provide only two arguments. Domain and output directory"
	echo "Example usage: ./scan.sh domain.com /home/myuser/hacking/domain.com/scan"
	exit 1
fi

# Check for tools
for tool in nmap nuclei
do
	command -v ${tool} >/dev/null 2>&1 || { echo >&2 "This script requires ${tool} but it's not installed. Aborting."; exit 1; }
done

# sudo needed for nmap
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Run the script as sudo (Nmap will need it)"
    exit
fi

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

# nmap ports
mkdir -p ${OUT_DIR}/nmap
sudo nmap -p- --open -sS --min-rate 3000 -v -n -Pn -oN ${OUT_DIR}/nmap_ports_${DOMAIN}.txt ${DOMAIN}

# nmap scripts/recon
sudo nmap -Pn -sCV -p $(cat ${OUT_DIR}/nmap_ports_${DOMAIN}.txt | grep open | sed '1d' | awk -F '/' '{print $1}' | tr '\n' ',' | sed '$ s/.$//') -oN ${OUT_DIR}/nmap_${DOMAIN}.txt ${DOMAIN} 

# UDP scan (only 100 ports)
nmap -Pn -sU --min-rate 3000 --open --top-ports 100 -oN ${OUT_DIR}/nmap_udp_${DOMAIN}.txt ${DOMAIN}

# nuclei
nuclei -u ${DOMAIN} -rl 350 -c 10 -nmhe -o ${OUT_DIR}/nuclei_${DOMAIN}.txt
printf "${GREEN}Script complete! Happy hunting! ${NORMAL}\n"
exit 0
