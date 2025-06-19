#!/bin/bash

: <<'DOC'
------------------------------------------------------------------------------
Script Name: <SCRIPT_NAME>
Description : <SHORT_DESCRIPTION>

Author      : <YOUR_NAME>
Date        : <YYYY-MM-DD>
Version     : <VERSION>

------------------------------------------------------------------------------
Usage:
  <SCRIPT_NAME> [options]

Example Output:
  OK - All services are running.
  CRITICAL - Service XYZ is not running.

------------------------------------------------------------------------------
Icinga2 Integration:
1. Save to: /usr/lib64/nagios/plugins/<SCRIPT_NAME>
2. Make executable:
   chmod +x /usr/lib64/nagios/plugins/<SCRIPT_NAME>

3. Define the command (e.g., in /etc/icinga2/conf.d/commands.conf):
   object CheckCommand "<icinga_command_name>" {
     command = [ "/usr/lib64/nagios/plugins/<SCRIPT_NAME>" ]
   }

4. Use in a service check:
   apply Service "<service_name>" {
     import "generic-service"
     check_command = "<icinga_command_name>"
     assign where host.name == "<host_name>"
   }

------------------------------------------------------------------------------
Notes:
- <ANY_SPECIAL_NOTES_OR_REQUIREMENTS>
- Compatible with Bash v4.0+
- Requires: <dependencies like `jq`, etc.>

------------------------------------------------------------------------------
DOC