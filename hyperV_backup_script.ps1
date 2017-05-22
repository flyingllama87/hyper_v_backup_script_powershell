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
# - Adjust script settings below
# - Script provided as-is

### SCRIPT SETTINGS

$bTestRun =                     $False # Enable if you want the script to run & evaluate conditions but not actually write or delete any data.
$bBackupToExternal =            $True  # Choose whether backups are copied to external drive if there is enough disk space.
$bPurgeBackups =                $True  # Choose whether you want Backups older than the retention period specified above removed from the main drive
$bPurgeBackupsExternal =        $True  # Choose whether you want Backups older than the retention period specified above removed from the external drive.
$OutdatedBackupDay =            -10    # Backups older than 10 days on Main backup drive are removed.
$OutdatedBackupDayExternal =    -20    # Backups older than 20 days on external drive are removed.

[String]$BackupPathExternal =   "B:\Backups\"
[String]$BackupPath = 			"D:\Backups\"
[String]$LogFilePath = 		    "D:\Backups\"
[String[]]$EmailRecipients = 	@("address1@company.com", "address2@company.com")
[String]$SMTPServer  = 			"relay.company.com"
[String]$EmailFromAddress = 	"backups@company.com"
[String]$EmailSubject =         "$env:computername Hyper-V Backup"

### FUNCTION DEFINITIONS

# Init Script - Acquire current date, update e-mail subject & set log file

$StartDate = Get-Date -format yyyy-MM-dd
$EmailSubject = $EmailSubject + " - $StartDate"
$LogFilePath = "$LogFilePath" + "Hyper-V-" + "$StartDate" + ".log"

# Log information to log file & also output to console

Function LogAndPrint
{
    # [CmdletBinding()]
    Param([Parameter(ValueFromPipeline)]$StringToLogAndPrint)

    Process
    {
        "$(Get-Date) - $StringToLogAndPrint" | Out-File $LogFilePath -Append
        Write-Host "$(Get-Date) - $StringToLogAndPrint"
    }
}

### PREBACKUP ACTIONS

Try
{
    LogAndPrint "No pre-backup actions to perform"
    LogAndPrint " " #Blank link for cleanliness
}
Catch
{
    LogAndPrint "Pre-Backup actions failed:  $($_.Exception.Message)"
}


### SCRIPT LOGIC

LogAndPrint "*** HYPER-V BACKUPS STARTING ***"
LogAndPrint " " #Blank link for cleanliness

## PURGE OLD BACKUPS

LogAndPrint "*** PURGING OLD BACKUPS FROM DESTINATION MEDIA ***"
LogAndPrint " " #Blank link for cleanliness

# Purge old backups from primary backup location

If ($bPurgeBackups)
{
    LogAndPrint "Purging old backups from primary destination $BackupPath is Enabled. Looking for backups older than $OutdatedBackupDay days:"

    $OutdatedBackupDate = (Get-Date).AddDays($OutdatedBackupDay).ToString('yyyy-MM-dd')
    $HyperVBackupSets = Get-ChildItem -dir $BackupPath | Where-Object {$_.Name -match "Hyper-V-\d\d\d\d-\d\d-\d\d"}

    Foreach ($BackupSet in $HyperVBackupSets)
    {
	    $BackupSetDate = $BackupSet | Select -Expand Name
	    $BackupSetDate = $BackupSetDate.Substring(8,10)

	    If ((Get-Date $BackupSetDate) -lt (Get-Date $OutdatedBackupDate))
	    {
		     LogAndPrint "Old backup found! It was made $BackupSetDate"

		    # If there is more than one backup folders created in the last week
		    If (@(Get-ChildItem -Path $BackupPath -dir | Where-Object {$_.Name -match "Hyper-V-\d\d\d\d-\d\d-\d\d"} | ? { $_.LastWriteTime -gt (Get-Date).AddDays($OutdatedBackupDay) } | Select -Expand Name).length -gt 0) 
		    {
		       LogAndPrint "Removing $BackupPath$BackupSet Backup as it's past the retention period and a newer one exists"
		       Remove-Item "$BackupPath$BackupSet" -recurse | LogAndPrint
		    }
		    Else
		    {
		       LogAndPrint "Backup past retention period found but not removing as no newer backup exists"
		    }
		
	    }
	    Else
	    {
		    LogAndPrint "Backup $BackupSetDate not a candidate for removal"
	    }
    }
}

# Purge Backups from External drive

If ($bPurgeBackupsExternal)
{
    LogAndPrint " " #Blank link for cleanliness
    LogAndPrint "Purging old backups from USB/external destination $BackupPathExternal is enabled. Looking for backups older than $OutdatedBackupDayExternal days:"

    $OutdatedBackupDateExternal = (Get-Date).AddDays($OutdatedBackupDayExternal).ToString('yyyy-MM-dd')
    $HyperVBackupSets = Get-ChildItem -dir $BackupPathExternal | Where-Object {$_.Name -match "Hyper-V-\d\d\d\d-\d\d-\d\d"}

    Foreach ($BackupSet in $HyperVBackupSets)
    {
	    # Get date of existing backup set
        $BackupSetDate = $BackupSet | Select -Expand Name
	    $BackupSetDate = $BackupSetDate.Substring(8,10)
        
        # Backup if old backup is found
	    If ((Get-Date $BackupSetDate) -lt (Get-Date $OutdatedBackupDateExternal))
	    {
		    LogAndPrint "Old backup found! It was made $BackupSetDate"

		    # If there is more than one backup folders created in the last $OutdatedBackupDayExternal days
		    If (@(Get-ChildItem -Path $BackupPathExternal -dir | Where-Object {$_.Name -match "Hyper-V-\d\d\d\d-\d\d-\d\d"} | ? { $_.LastWriteTime -gt (Get-Date).AddDays($OutdatedBackupDayExternal) } | Select -Expand Name).length -gt 0) 
		    {
		       LogAndPrint "Removing $BackupSet Backup as it's past the retention period and a newer one exists" 
		       Remove-Item "$BackupPathExternal$BackupSet" -recurse | LogAndPrint
		    }
		    Else
		    {
		       LogAndPrint "Backup past retention period found but not removing as no newer backup exists"
		    }
		
	    }
	    Else
	    {
		    LogAndPrint "Backup $BackupSetDate not a candidate for removal from external drive"
	    }
    }
}

# Generate Backup Path for today's backup and create folder

$BackupPath = $BackupPath + "Hyper-V-" + $StartDate + "\"

LogAndPrint " " #Blank link for cleanliness
LogAndPrint "*** STARTING VM OPTIMISATION AND EXPORT ***" 
LogAndPrint " " #Blank link for cleanliness
LogAndPrint "Backup location is $BackupPath" 
LogAndPrint " " #Blank link for cleanliness

Try
{
   New-Item $BackupPath -type directory -ErrorAction Stop | Out-Null
}
Catch
{
    LogAndPrint "Error creating backup Path: $($_.Exception.Message)"
    $EmailSubject = $EmailSubject + " - ERROR"
}

### START MAIN BACKUP LOGIC

# Get Free Space on Backup disk
$BackupDriveLetter = $BackupPath.Substring(0,1)
$FreeBackupDiskSpace = Get-PSDrive $BackupDriveLetter | Select -ExpandProperty "Free"

# Get list of all running VMs and store into an array:

Try
{
    $List_of_VMs = Get-VM | Where { $_.State –eq ‘Running’ } | select -expand Name
}
Catch
{
    LogAndPrint "Error during Get-VM to acquire list of VM names: $($_.Exception.Message)"
}

## Loop through each VM, save, export and resume VM one at a time

Foreach ($VM_name in $List_of_VMs)
{
   
   # Refresh free disk space
   $FreeBackupDiskSpace = Get-PSDrive $BackupDriveLetter | Select -ExpandProperty "Free"
   
   LogAndPrint "Processing VM: $VM_name"

   # Suspend VM

   Try
   {
      Stop-VM -Name $VM_name -ErrorAction Stop -Save
      # LogAndPrint "DEBUG: Stop-VM -Name $VM_name -ErrorAction Stop -Save"
      LogAndPrint "VM Suspended"
   }
   Catch
   {
      LogAndPrint "Error during VM Save: $($_.Exception.Message)"
      Continue
   }

   # Optimise VHD

   Try
   {
	   $VMHD = $VM_name | Get-VMHardDiskDrive | Select -ExpandProperty "Path"
       Optimize-VHD -Path "$VMHD" -ErrorAction Stop -Mode Full
       # LogAndPrint "DEBUG: $(Get-Date) - Optimize-VHD -Path `"$VMHD`" -ErrorAction Stop -Mode Full"
	   LogAndPrint "VHD optimised"
   }
   Catch
   {
      LogAndPrint "Error during Optimize-VHD: $($_.Exception.Message)"
   }
   
   ## Export VM if there's enough free disk space

   $SizeOfVirtualDisk = Get-Item -path $VMHD | Select -ExpandProperty Length
	
   If ($SizeOfVirtualDisk -lt $FreeBackupDiskSpace)
   {	
   	   LogAndPrint "Attempting backup.  File to backup is $(($SizeOfVirtualDisk)/1073741824) Gbytes and there is $(($FreeBackupDiskSpace)/1073741824) Gbytes free on $BackupDriveLetter Drive"
  
	   Try
	   {
		   Export-VM -Name $VM_name -ErrorAction Stop -Path $BackupPath
		   LogAndPrint "VM Exported"
	   }
	   Catch
	   {
          LogAndPrint "Error during Export-VM: $($_.Exception.Message)"
          $EmailSubject = $EmailSubject + " - ERROR"
	   }
	}
	Else
	{
        $EmailSubject = $EmailSubject + " - ERROR"
		LogAndPrint "Not enough free space to perform backup.  File to backup is $(($SizeOfVirtualDisk)/1073741824) Gbytes but only $(($FreeBackupDiskSpace)/1073741824) Gbytes free on $BackupDriveLetter Drive"
	}
	
   ## Resume VM

   Try
   {
      Start-VM -Name $VM_name -ErrorAction Stop
      LogAndPrint "VM Resumed"
   }
   Catch
   {
      LogAndPrint "Error during VM Resumation: $($_.Exception.Message)"
      $EmailSubject = $EmailSubject + " - ERROR"
      Continue
   }

   # Write blank line in log & terminal
   LogAndPrint " " 

} # End of main backup loop

LogAndPrint "*** FINISHED VM EXPORTS ***" 
LogAndPrint " " #Blank link for cleanliness

### COPY BACKUP TO EXTERNAL DISK


LogAndPrint "*** STARTING BACKUP TO EXTERNAL DRIVE ***" 
LogAndPrint " " #Blank link for cleanliness

# If backing up to external drive is on, check if the size of today's backup is big enough to fit, 
If ($bBackupToExternal)
{
	LogAndPrint "Backup to External drive is on.  External backup location is $BackupPathExternal"
    
    # Get Free Space on External Backup disk
	$BackupDriveLetter = $BackupPathExternal.Substring(0,1)
	$FreeBackupDiskSpace = Get-PSDrive $BackupDriveLetter | Select -ExpandProperty "Free"
	
    # Get size of today's backup
	$SizeOfTodaysBackup = Get-Item "$BackupPath" | Get-ChildItem -recurse | Measure-Object -Sum -Property Length | Select Sum | foreach {$_.Sum}

	If ($SizeOfTodaysBackup -lt $FreeBackupDiskSpace)
    {	
   	   LogAndPrint "Attempting copy of backup to external disk.  Backup is $(($SizeOfTodaysBackup)/1073741824) Gbytes and there is $(($FreeBackupDiskSpace)/1073741824) Gbytes free on $BackupDriveLetter Drive"
		   
	   Try
	   {
		   # Copy Backup
		   Copy-Item "$BackupPath" $BackupPathExternal -recurse -ErrorAction Stop
		   # LogAndPrint "DEBUG: Copy-Item $BackupPath $BackupPathExternal -recurse -ErrorAction Stop"
		   LogAndPrint "$BackupPath backup copied to $BackupPathExternal"
	   }
	   Catch
	   {
		  LogAndPrint "Error during Copy-Item: $($_.Exception.Message)"
	   }
	}
	Else
	{
		LogAndPrint "Not enough free space to perform copy to external disk.  The script may be set to automatically remove old backups past the set retention period of $OutdatedBackupDayExternal days.  Today's backup is $(($SizeOfTodaysBackup)/1073741824) Gbytes but only $(($FreeBackupDiskSpace)/1073741824) Gbytes free on $BackupDriveLetter Drive"
	}
}

### POSTBACKUP ACTIONS

LogAndPrint " " #Blank link for cleanliness

Try
{
    LogAndPrint "No Post Backup Actions to perform"
}
Catch
{
    LogAndPrint "Post Backup actions failed: $($_.Exception.Message)"
}

LogAndPrint " " #Blank link for cleanliness

# Write end timestamp to log
LogAndPrint "*** HYPER-V BACKUPS COMPLETED ***"

## Send E-mail with log attached

Try
{
   Send-MailMessage -To $EmailRecipients -Subject "$EmailSubject" -From $EmailFromAddress -SmtpServer $SMTPServer -Attachments $LogFilePath -Body "See attached file for today's Hyper V Backup log"
}
Catch
{
   LogAndPrint "Can't send e-mail message: $($_.Exception.Message)"
}
