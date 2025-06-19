#!/bin/bash

# Script Name: slack-notify.sh
# Author: yvarbev@redhat.com
# Description: Icinga Notification Script for Sending Host and Service Status to Slack
#              Sends formatted notifications to Slack based on Icinga host or service state.
#              The status values can be one of the following:
#                 UP/OK         = [Green]  Host/Service is in a healthy state.
#                 WARNING       = [Orange] Host/Service has warnings.
#                 DOWN/CRITICAL = [Red] Host/Service is in a critical state.
#                 UNKNOWN       = [Blue] Unknown or unrecognized state.
#
# Usage:
#   Run this script with the appropriate flags to provide Icinga host and service data.
#   Example:
#     ./slack-notify.sh --host.name "web01" --host.state "UP" --host.output "All services running fine" --user "admin"
#     --service.name "http" --service.state "WARNING" --service.output "Slow response time"
#
# Example Output:
#   *Service Monitoring on myhost* ⚠️
#   *Service*: _HTTP Check_ 
#   *State*: *warning!*
#   *Service*: http
#
# Exit Code: 0 (Success) or 2 (Failure)


# Function to check if a string is empty
is_empty() {
  [[ -z "${1// }" ]]
}

# Function to print an error message and exit
die() {
  echo "$1" >&2
  exit 2
}

# Escape JSON string safely
json_escape() {
  echo "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e ':a;N;$!ba;s/\n/\\n/g'
}

# Format text as Slack link or italic
format_text() {
  local text="$1"
  local url="$2"
  text="$(json_escape "$text")"
  url="$(json_escape "$url")"
  if is_empty "$url"; then
    echo "_${text}_"
  else
    echo "<${url}|${text}>"
  fi
}

# Parse args
dry_run=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --icinga.ts) icinga_timestamp="$2"; shift ;;
    --host.name) host_name="$2"; shift ;;
    --host.display_name) host_display_name="$2"; shift ;;
    --host.state) host_state="$2"; shift ;;
    --host.output) host_output="$2"; shift ;;
    --service.name) service_name="$2"; shift ;;
    --service.display_name) service_display_name="$2"; shift ;;
    --service.state) service_state="$2"; shift ;;
    --service.output) service_output="$2"; shift ;;
    --user) user="$2"; shift ;;
    --dry-run) dry_run=true ;;
    *) shift ;;
  esac
  shift
done

icinga_timestamp="${icinga_timestamp:-$(date +%s)}"
webhook_url="${WEBHOOK_URL}"
if is_empty "$webhook_url" && ! $dry_run; then
  die "env \$WEBHOOK_URL missing"
fi

is_service_report=false
current_state=""
current_output=""

if ! is_empty "$service_state"; then
  if is_empty "$host_name" || is_empty "$service_name"; then
    die "-service.* is given, missing some of: -host.name, -service.name, -service.state"
  fi
  is_service_report=true
  service_display_name="${service_display_name:-$service_name}"
  current_state="$service_state"
  current_output="$service_output"
elif ! is_empty "$host_state"; then
  if is_empty "$host_name"; then
    die "-host.* is given, missing -host.name or -host.state"
  fi
  current_state="$host_state"
  current_output="$host_output"
else
  die "Missing state info"
fi

host_display_name="${host_display_name:-$host_name}"

# Set icon and color
case "$current_state" in
  OK|UP) icon="✅"; color="#2eb886" ;;
  WARNING) icon="⚠️"; color="#f2c744" ;;
  CRITICAL|DOWN) icon="❌"; color="#d00000" ;;
  *) icon="❓"; color="#439fe0" ;;
esac

# Get the hostname of the current machine
# This is used to identify the source of the notification
current_hostname=$(hostname 2>/dev/null)
exit_status=0
if is_empty "$current_hostname"; then
  current_hostname="(unknown)"
  exit_status=2
fi

# Define the base URL and format the host URL
base_url="${BASE_URL}"
if is_empty "$base_url" && ! $dry_run; then
  die "env \$BASE_URL missing"
fi
host_url="${base_url}/host?name=${host_name}"
host_field=$(format_text "$host_display_name" "$host_url")

# Convert state to uppercase for display
state_upper=$(echo "$current_state" | tr '[:lower:]' '[:upper:]')

if $is_service_report; then
  title="$icon [$state_upper] $service_display_name"
  service_url="${BASE_URL}/service?name=${service_name}&host.name=${host_name}"
  service_field=$(format_text "$service_display_name" "$service_url")
  fields="{
    \"title\": \"Host\", \"value\": \"$(json_escape "$host_field")\", \"short\": true
  },
  {
    \"title\": \"Service\", \"value\": \"$(json_escape "$service_field")\", \"short\": true
  },
  {
    \"title\": \"Raw Name\", \"value\": \"$(json_escape "$service_name")\", \"short\": true
  },
  {
    \"title\": \"From\", \"value\": \"$(json_escape "$current_hostname")\", \"short\": true
  }"
else
  title="$icon [$state_upper] $host_display_name"
  fields="{
    \"title\": \"Host\", \"value\": \"$(json_escape "$host_field")\", \"short\": true
  },
  {
    \"title\": \"Raw Name\", \"value\": \"$(json_escape "$host_name")\", \"short\": true
  },
  {
    \"title\": \"From\", \"value\": \"$(json_escape "$current_hostname")\", \"short\": true
  }"
fi

user_line=""
if ! is_empty "$user"; then
  user_line="by $(json_escape "$user")"
fi

# Final JSON payload
json_payload=$(cat <<YV
{
  "attachments": [
    {
      "mrkdwn_in": ["text"],
      "color": "$color",
      "title": "$(json_escape "$title")",
      "text": "\`\`\`$current_output\`\`\`",
      "fields": [
        $fields
      ],
      "footer": "$user_line",
      "ts": $icinga_timestamp
    }
  ]
}
YV
)

# Dry-run or send
if $dry_run; then
  echo "$json_payload"
else
  response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-type: application/json" \
    --data "$json_payload" "$webhook_url")

  if [[ "$response" -gt 299 ]]; then
    echo "Error: Failed to send message to Slack (HTTP $response)" >&2
    exit 1
  fi
fi

exit $exit_status
