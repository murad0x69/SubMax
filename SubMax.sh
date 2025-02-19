#!/bin/bash

# Function to display usage instructions
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -d <domain>       Scan a single domain.
  -l <list_file>    Scan domains listed in the specified file (default: list.txt).
  -h, --help        Display this help message and exit.

Note:
  - Either -d or -l must be specified.
  - They are mutually exclusive.
EOF
}

# Parse command-line options
DOMAIN=""
LIST_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d)
            DOMAIN="$2"
            shift 2
            ;;
        -l)
            LIST_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Ensure that either -d or -l is provided, but not both
if [[ -n "$DOMAIN" && -n "$LIST_FILE" ]]; then
    echo "❌ Please specify only one of -d or -l."
    usage
    exit 1
fi

if [[ -z "$DOMAIN" && -z "$LIST_FILE" ]]; then
    echo "❌ Please specify either -d <domain> or -l <list_file>."
    usage
    exit 1
fi

# If a list file is provided, check if it exists. Otherwise, use default "list.txt"
if [[ -n "$LIST_FILE" ]]; then
    if [ ! -f "$LIST_FILE" ]; then
        echo "❌ File '$LIST_FILE' not found. Please provide a valid file."
        exit 1
    fi
fi

# Check for required tools
for tool in subfinder subdominator assetfinder curl amass findomain github-subdomains gau haktrails gitlab-subdomains cero httpx jq; do
    if ! command -v "$tool" &>/dev/null; then
        echo "❌ $tool is not installed. Please install it."
        exit 1
    fi
done

# Function that performs passive subdomain enumeration for a single domain
subdomain() {
    local domain="$1"
    local OUTPUT_DIR="output_passive_subdomains/$domain"
    mkdir -p "$OUTPUT_DIR" 2>/dev/null

    echo "========================================"
    echo "Starting enumeration for: $domain"
    echo "========================================"
    
    # Run subfinder
    echo "🔁 Running subfinder..."
    subfinder -d "$domain" -all -recursive -o "$OUTPUT_DIR/subfinder.txt" 2>>error.log &
    PID1=$!

    # Run subdominator
    echo "🔁 Running subdominator..."
    subdominator -d "$domain" -o "$OUTPUT_DIR/subdominator.txt" 2>>error.log &
    PID2=$!

    # Run assetfinder
    echo "🔁 Running assetfinder..."
    assetfinder -subs-only "$domain" > "$OUTPUT_DIR/assetfinder.txt" 2>>error.log &
    PID3=$!

    # Run riddler.io query
    echo "🔁 Querying riddler.io..."
    curl -s "https://riddler.io/search/exportcsv?q=pld:$domain" \
         | grep -Po "(([\w.-]*)\.([\w]*)\.([A-z]))\w+" \
         | sort -u > "$OUTPUT_DIR/riddler.txt" 2>>error.log &
    PID4=$!

    # Run Amass (passive mode)
    echo "🔁 Running amass..."
    amass enum -passive -norecursive -d "$domain" > "$OUTPUT_DIR/amass.txt" 2>>error.log &
    PID5=$!

    # Run WaybackMachine query
    echo "🔁 Querying WaybackMachine..."
    curl -sk "http://web.archive.org/cdx/search/cdx?url=*.$domain&output=txt&fl=original&collapse=urlkey&page=" \
         | awk -F/ '{gsub(/:.*/, "", $3); print $3}' | sort -u > "$OUTPUT_DIR/WaybackMachine.txt" 2>>error.log &
    PID6=$!

    # Run crt.sh query
    echo "🔁 Querying crt.sh..."
    curl -sk "https://crt.sh/?q=%.$domain&output=json" \
         | tr ',' '\n' | awk -F'"' '/name_value/ {gsub(/\*\./, "", $4); gsub(/\\n/,"\n",$4); print $4}' \
         > "$OUTPUT_DIR/crt.txt" 2>>error.log &
    PID7=$!

    # Run jldc query
    echo "🔁 Querying jldc..."
    curl -s "https://jldc.me/anubis/subdomains/$domain" \
         | grep -Po "((http|https):\/\/)?(([\w.-]*)\.([\w]*)\.([A-z]))\w+" \
         | sort -u > "$OUTPUT_DIR/jldc.txt" 2>>error.log &
    PID8=$!

    # Run findomain
    echo "🔁 Running findomain..."
    findomain -t "$domain" --unique-output "$OUTPUT_DIR/findomain.txt" 2>>error.log &
    PID9=$!

    # Run urlscan.io query
    echo "🔁 Querying urlscan.io..."
    curl -s "https://urlscan.io/api/v1/search/?q=domain:$domain&size=10000" \
         | jq -r '.results[]?.page?.domain' \
         | grep -E "^[a-zA-Z0-9.-]+\.$domain$" | sort -u > "$OUTPUT_DIR/urlscan.txt" 2>>error.log &
    PID10=$!

    # Run rapiddns query
    echo "🔁 Querying rapiddns..."
    curl -s "https://rapiddns.io/subdomain/$domain?full=1#result" \
         | grep "<td><a" | cut -d '"' -f 2 | grep http | cut -d '/' -f3 \
         | sed 's/#results//g' | sort -u > "$OUTPUT_DIR/rapiddns.txt" 2>>error.log &
    PID11=$!

    # Run github-subdomains
    echo "🔁 Running github-subdomains..."
    github-subdomains -d "$domain" -t config.txt -o "$OUTPUT_DIR/github-subdomains.txt" 2>>error.log &
    PID12=$!

    # Run gau for URL scan
    echo "🔁 Running gau..."
    gau --threads 10 --subs "$domain" | unfurl -u domains > "$OUTPUT_DIR/gau.txt" 2>>error.log &
    PID13=$!

    # Run haktrails
    echo "🔁 Running haktrails..."
    echo "$domain" | haktrails subdomains > "$OUTPUT_DIR/haktrails.txt" 2>>error.log &
    PID14=$!

    # Run gitlab-subdomains
    echo "🔁 Running gitlab-subdomains..."
    gitlab-subdomains -d "$domain" -t config.txt > "$OUTPUT_DIR/gitlab-subdomains.txt" 2>>error.log &
    PID15=$!

    # Run cero
    echo "🔁 Running cero..."
    cero "$domain" > "$OUTPUT_DIR/cero.txt" 2>>error.log &
    PID16=$!

    # Run alienvault query
    echo "🔁 Querying alienvault..."
    curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$domain/url_list?limit=1000&page=100" \
         | grep -o '"hostname": *"[^"]*' | sed 's/"hostname": "//' | sort -u > "$OUTPUT_DIR/alienvault.txt" 2>>error.log &
    PID17=$!

    # Run subdomaincenter query
    echo "🔁 Querying subdomaincenter..."
    curl -s "https://api.subdomain.center/?domain=$domain" \
         | jq -r '.[]' | sort -u > "$OUTPUT_DIR/subdomaincenter.txt" 2>>error.log &
    PID18=$!

    # Run certspotter query
    echo "🔁 Querying certspotter..."
    curl -sk "https://api.certspotter.com/v1/issuances?domain=$domain&include_subdomains=true&expand=dns_names" \
         | jq -r '.[].dns_names[]' | sort -u > "$OUTPUT_DIR/certspotter.txt" 2>>error.log &
    PID19=$!

    # Wait for all background tasks to complete
    wait $PID1 $PID2 $PID3 $PID4 $PID5 $PID6 $PID7 $PID8 $PID9 $PID10 $PID11 $PID12 $PID13 $PID14 $PID15 $PID16 $PID17 $PID18 $PID19

    echo "🔁 Aggregating results..."

    # Aggregate and sort results from all tools
    sort -u "$OUTPUT_DIR"/*.txt > "$OUTPUT_DIR/uniq-subd.txt"
    
    # Check for live domains with httpx
    if [ -s "$OUTPUT_DIR/uniq-subd.txt" ]; then
        cat "$OUTPUT_DIR/uniq-subd.txt" | httpx-toolkit -threads 50 -o "$OUTPUT_DIR/live.txt" 2>>error.log
    fi

    # Print a summary
    echo "========================================"
    echo "Summary for $domain:"
    for file in subfinder subdominator assetfinder riddler amass WaybackMachine crt jldc findomain urlscan rapiddns github-subdomains gau haktrails gitlab-subdomains cero alienvault subdomaincenter certspotter; do
        count=$( [ -f "$OUTPUT_DIR/${file}.txt" ] && wc -l < "$OUTPUT_DIR/${file}.txt" || echo "0" )
        printf "Total %s: %s\n" "$file" "$count"
    done
    total_all=$(cat "$OUTPUT_DIR"/*.txt 2>/dev/null | wc -l)
    total_uniq=$(wc -l < "$OUTPUT_DIR/uniq-subd.txt")
    live_count=$( [ -f "$OUTPUT_DIR/live.txt" ] && wc -l < "$OUTPUT_DIR/live.txt" || echo "0" )
    echo "Total all subdomains: $total_all"
    echo "Total unique subdomains: $total_uniq"
    echo "Total live subdomains: $live_count"
    echo "========================================"
}

# Main execution based on provided options
if [[ -n "$DOMAIN" ]]; then
    # Single domain mode
    subdomain "$DOMAIN"
else
    # List mode: read each domain from the file and scan
    while IFS= read -r domain || [ -n "$domain" ]; do
        # Skip empty lines or lines starting with #
        if [[ -z "$domain" || "$domain" =~ ^# ]]; then
            continue
        fi
        subdomain "$domain"
    done < "${LIST_FILE:-list.txt}"
fi
