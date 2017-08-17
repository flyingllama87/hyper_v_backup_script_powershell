# hyper_v_backup_script_powershell
Script to backup HyperV VMs written in powershell.  Complete with e-mail notifications, error checking and purging old backups etc.


### DESCRIPTION
#
# Scripts has 4 functions:
#
# 1) Remove old backups past retention from specified location.
# 2) Backup Hyper-V VMs one at a time by suspending VM, exporting it to specified location and resuming VMs.
# 3) Copy backup to USB drive (or other specified location)
# 4) Log all the actions and send an e-mail
#
# Author: Morgan Robertson / morganrobertson.net
# Date: 06/11/2015 | Updated: 15/04/2017
# 
# - You're still better off paying for a commercial solution for business critical stuff.
# - Happy to hear any constructive criticism towards this script.
# - Run as Administrator
# - Adjust script settings at top of script
# - Script provided as-is
# - Script is designed to handle errors and be robust (e.g. not just exit if a trivial error is encountered
