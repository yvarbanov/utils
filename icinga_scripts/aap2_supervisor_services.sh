#!/bin/bash

: <<'DOC'
------------------------------------------------------------------------------
Script Name: aap2_supervisor_services.sh
Description : Checks if all Ansible Automation Platform 2 (AAP2) services managed by
              supervisorctl are running, designed for use as an Icinga2 plugin.

Author      : yvarbev@redhat.com
Date        : 2025-06-04
Version     : 1.0

------------------------------------------------------------------------------
Usage:
  aap2_supervisor_services.sh

Example Output:
  OK - All supervisor-managed AAP2 processes are running.
  CRITICAL - These supervisor processes are not running: tower-processes:awx-wsrelay

------------------------------------------------------------------------------
Icinga2 Integration:
1. Save to: plugins/aap2_supervisor_services.sh
2. Make executable:
   chmod +x plugins/aap2_supervisor_services.sh

3. Define the command (e.g., in /etc/icinga2/conf.d/commands.conf):
   object CheckCommand "aap2_supervisor_services" {
     command = [ "plugins/aap2_supervisor_services.sh" ]
   }

4. Use in a service check:
   apply Service "aap2-supervisor-services" {
     import "generic-service"
     check_command = "aap2_supervisor_services"
     assign where host.name == "<host_name>"
   }

------------------------------------------------------------------------------
Notes:
- Dynamically fetches and checks all services managed by supervisorctl.
- Requires supervisorctl to be installed and accessible in PATH.
- Compatible with Bash v4.0+.
- Does not exit on first failure; reports all non-running processes.
------------------------------------------------------------------------------
DOC

# Get the status of all supervisor-controlled processes
SUPERVISOR_STATUS=$(supervisorctl status)

# Extract all process names (everything before the first whitespace)
mapfile -t EXPECTED_PROCESSES < <(echo "$SUPERVISOR_STATUS" | awk '{print $1}')

EXIT_CODE=0
NOT_RUNNING=()

# Check each process status
for PROCESS in "${EXPECTED_PROCESSES[@]}"; do
  LINE=$(echo "$SUPERVISOR_STATUS" | grep "^$PROCESS")
  if echo "$LINE" | grep -q "RUNNING"; then
    continue
  else
    NOT_RUNNING+=("$PROCESS")
    EXIT_CODE=2
  fi
done

# Output based on check results
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "OK - All supervisor-managed AAP2 processes are running."
else
  echo "CRITICAL - These supervisor processes are not running: ${NOT_RUNNING[*]}"
fi

exit "$EXIT_CODE"
