#!/bin/bash

# Color
Cyan="\e[0;49;36m"

# Banner
echo -e "${Cyan}
                       _      _             
     /\               | |    (_)            
    /  \    _ __  ___ | |__   _ __   __ ___ 
   / /\ \  | '__|/ __|| '_ \ | |\ \ / // _ |
  / ____ \ | |  | (__ | | | || | \ V /|  __/
 /_/    \_\|_|   \___||_| |_||_|  \_/  \___|
                                                                                       
     
                                      
Get all the URLS From Waybackurls, urlfinder, waymore, Gau, Gau-Plus & Katana

${STOP}"

domain=$1

if [ $# -lt 1 ]; then
    echo "+---------------------------------------+"
    echo "|  Usage: ./`basename $0` <target.tld> 	|" 
    echo "|  Eg:    ./archive.sh google.com       |"
    echo "+---------------------------------------+"
    exit 1
fi


if [ "$1" == "-h" ] ; then
    echo "This is Help Menu"
    echo 
    echo "+---------------------------------------+"
    echo "|  Usage: ./`basename $0` <target.tld> 	|" 
    echo "|  Eg:    ./archive.sh google.com       |"
    echo "+---------------------------------------+"
    exit 0
fi

archive(){
mkdir -p output/$domain
echo "output/$domain directory is created ✅"

## tools is started

echo "gau is started"
gau --o output/$domain/gau.txt $domain
printf "Total gau urls          :  $(wc -l output/$domain/gau.txt)\n"
echo "GAU ✅" 
echo "waybackurls is started"
echo "$domain" | waybackurls > output/$domain/waybackurls.txt
printf "Total waybackurls urls  :  $(wc -l output/$domain/waybackurls.txt)\n"
echo "WAYBACKURLS ✅"
echo "gau-plus is started"
gauplus $domain > output/$domain/plus_gau.txt 
printf "Total GAU-PLUS urls     :  $(wc -l output/$domain/plus_gau.txt)\n"
echo "GAU-PLUS ✅"
echo "katana is started"
echo https://$domain | katana -silent > output/$domain/katana.txt
printf "Total KATANA urls     :  $(wc -l output/$domain/katana.txt)\n"
echo "KATANA ✅"

echo "urlfinder"
urlfinder -d $domain -o output/$domain/urlfinder.txt
printf "Total urlfinder      :  $(wc -l output/$domain/urlfinder.txt)\n"
echo "urlfinder ✅"

echo "waymore  is started"
waymore -i $domain  -mode U -oU output/$domain/waymore.txt
printf "Total waymore urls     :  $(wc -l output/$domain/waymore.txt)\n"
echo "waymore ✅"

# merging files
cat output/$domain/gau.txt output/$domain/urlfinder.txt  output/$domain/waymore.txt output/$domain/waybackurls.txt output/$domain/plus_gau.txt output/$domain/katana.txt > output/$domain/allfiles.txt
printf "Total aLL urls          :  $(wc -l output/$domain/allfiles.txt)\n"
cat output/$domain/allfiles.txt | sort -u > output/$domain/uniq-urls.txt
printf "Total uniq urls         :  $(wc -l output/$domain/uniq-urls.txt)\n"


### making custom wordlist


echo "creating custom wordlists"
cat output/$domain/uniq-urls.txt | sed 's/\(?\|&\|;\).*//;s/\//RMSED/3;s/.*RMSED//;s/\//\n/g' | anew -q output/$domain/custom-wordlist.txt
printf "Custom Wordlist         :  $(wc -l output/$domain/custom-wordlist.txt)\n"
echo "Created custom wordlists ✅"

### getting 80:443 urls

echo "httpx started 80:443"
cat output/$domain/uniq-urls.txt | httpx -silent > output/$domain/80:443-urls.txt
printf "Total 80:443-urls    :  $(wc -l output/$domain/80:443-urls.txt)\n"

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
## all data

printf "Total gau urls          :  $(wc -l output/$domain/gau.txt)\n"
printf "Total waybackurls urls  :  $(wc -l output/$domain/waybackurls.txt)\n"
printf "Total GAU-PLUS urls     :  $(wc -l output/$domain/plus_gau.txt)\n"
printf "Total Total KATANA urls :  $(wc -l output/$domain/katana.txt)\n"
printf "Total waymore urls     :  $(wc -l output/$domain/waymore.txt)\n"
printf "Total urlfinder      :  $(wc -l output/$domain/urlfinder.txt)\n"
printf "Total all urls          :  $(wc -l output/$domain/allfiles.txt)\n"
printf "Total uniq urls         :  $(wc -l output/$domain/uniq-urls.txt)\n"
printf "Total 80:443-urls       :  $(wc -l output/$domain/80:443-urls.txt)\n"
printf "Custom Wordlist lines   :  $(wc -l output/$domain/custom-wordlist.txt)\n"

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

}
archive
