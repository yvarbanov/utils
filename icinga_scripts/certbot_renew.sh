#!/bin/bash

: <<'DOC'
------------------------------------------------------------------------------
Script Name: certbot_renew.sh
Description : auto renew certificates with certbot

Author      : yvarbev@redhat.com
Version     : 1.0

------------------------------------------------------------------------------
Usage:
   ./certbot-renew-check.sh
   ./certbot-renew-check.sh --dry-run

Example Output:
  OK - All services are running.
  CRITICAL - Service XYZ is not running.

------------------------------------------------------------------------------
Notes:
- Compatible with Bash v4.0+
- Requires: certbot

------------------------------------------------------------------------------
DOC

# Config
THRESHOLD=9
LOGFILE="/var/log/certbot-renew-check.log"

# Optional: dry run mode
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "$(date): Running in DRY RUN mode" >> "$LOGFILE"
else
  echo "$(date): Running actual renewal check" >> "$LOGFILE"
fi

# Process certbot output
certbot certificates 2>/dev/null | awk -v threshold="$THRESHOLD" '
/Certificate Name:/ { cert_name=$3 }
/Expiry Date:/ {
    match($0, /\(VALID: ([0-9]+) days\)/, m)
    if (m[1] < threshold) {
        print cert_name
    }
}' | while read -r cert; do
    if $DRY_RUN; then
        echo "$(date): Would renew certificate: $cert" | tee -a "$LOGFILE"
        certbot renew --cert-name "$cert" --dry-run >> "$LOGFILE" 2>&1
    else
        echo "$(date): Renewing certificate: $cert" | tee -a "$LOGFILE"
        certbot renew --cert-name "$cert" >> "$LOGFILE" 2>&1
    fi
done
