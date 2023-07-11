<#PSScriptInfo 
.VERSION 3.0
.GUID f5187e3f-ed0a-4ce1-b438-d8f421619ca3 
.ORIGINAL AUTHOR Jan Van Meirvenne 
.MODIFIED BY Sooraj Rajagopalan, Paul Huijbregts & Pieter Wigleven, Sean McLaren, Imad Balute
.COPYRIGHT 
.TAGS Azure Intune Bitlocker  
.LICENSEURI  
.PROJECTURI  
.ICONURI  
.EXTERNALMODULEDEPENDENCIES  
.REQUIREDSCRIPTS  
.EXTERNALSCRIPTDEPENDENCIES  
.RELEASENOTES  
#>

<# 
 
.DESCRIPTION 
 Check whether BitLocker is Enabled, if not Enable Bitlocker on AAD Joined devices and store recovery info in AAD. 
 Store key in temp folder, just in case we need to use another task to copy it to OD4B

#> 
[cmdletbinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OSDrive = $env:SystemDrive
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try
    {
        # Transcript for logging/troubleshooting
        $stampDate = Get-Date
        $bitlockerTempDir = "C:\_showmewindows\manage\bitlocker"
        $transcriptName = $bitlockerTempDir + "\EnableBitlocker_" + $stampDate.ToFileTimeUtc() + ".txt"
        Start-Transcript -Path $transcriptName -NoClobber

        # Running as SYSTEM BitLocker may not implicitly load and running as SYSTEM the env variable is likely not set, so explicitly load it
	    Import-Module -Name C:\Windows\SysWOW64\WindowsPowerShell\v1.0\Modules\BitLocker -Verbose

            # --------------------------------------------------------------------------
            #  Let's dump the starting point
            # --------------------------------------------------------------------------
            Write-Host "--------------------------------------------------------------------------------------"
            Write-Host " STARTING POINT:  Get-BitLockerVolume " + $OSDrive
            Write-Host "--------------------------------------------------------------------------------------"
            $bdeStartingStatus = Get-BitLockerVolume $OSDrive 


        #  Evaluate the Volume Status to see what we need to do...
        $bdeProtect = Get-BitLockerVolume $OSDrive | select -Property VolumeStatus
            # Account for an uncrypted drive 
            if ($bdeProtect.VolumeStatus -eq "FullyDecrypted" -or $bdeProtect.KeyProtector.Count -lt 1) 
	        {
                Write-Host "--------------------------------------------------------------------------------------"
                Write-Host " Enabling BitLocker due to FullyDecrypted status or KeyProtector count less than 1"
                Write-Host "--------------------------------------------------------------------------------------"
                # Enable Bitlocker using TPM
                Enable-BitLocker -MountPoint $OSDrive  -TpmProtector -SkipHardwareTest -UsedSpaceOnly -ErrorAction Continue
                Enable-BitLocker -MountPoint $OSDrive  -RecoveryPasswordProtector -SkipHardwareTest
	        }  
            elseif ($bdeProtect.VolumeStatus -eq "FullyEncrypted" -or $bdeProtect.VolumeStatus -eq "UsedSpaceOnly") 
            {
                # $bdeProtect.ProtectionStatus -eq "Off" - This catches the Wait State
                if ($bdeProtect.KeyProtector.Count -lt 2)
                {
                    Write-Host "--------------------------------------------------------------------------------------"
                    Write-Host " Volume Status is encrypted, but BitLocker only has one key protector (TPM)"
                    Write-Host "  Adding a RecoveryPasswordProtector"
                    Write-Host "--------------------------------------------------------------------------------------"
                    manage-bde -on $OSDrive -UsedSpaceOnly -rp
                }
                else
                {
                    Write-Host "--------------------------------------------------------------------------------------"
                    Write-Host " BitLocker is in Wait State - running manage-bde -on -UsedSpaceOnly"
                    Write-Host "--------------------------------------------------------------------------------------"
                    manage-bde -on $OSDrive -UsedSpaceOnly
                }
            }    

            #Writing recovery key to temp directory, another user-mode task will move this to OneDrive for Business (if configured)
            Write-Host "--------------------------------------------------------------------------------------"
            Write-Host " Writing key protector to temp file so we can move it to OneDrive for Business"
            Write-Host "--------------------------------------------------------------------------------------"
            New-Item -ItemType Directory -Force -Path "$OSDrive\temp" | out-null
			(Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector   | Out-File "$OSDrive\temp\$($env:computername)_BitlockerRecoveryPassword.txt"
				
            #Check if we can use BackupToAAD-BitLockerKeyProtector commandlet
			$cmdName = "BackupToAAD-BitLockerKeyProtector"
            if (Get-Command $cmdName -ErrorAction SilentlyContinue)
			{
                Write-Host "--------------------------------------------------------------------------------------"
                Write-Host " Saving Key to AAD using BackupToAAD-BitLockerKeyProtector commandlet"
                Write-Host "--------------------------------------------------------------------------------------"
				#BackupToAAD-BitLockerKeyProtector commandlet exists
                $BLV = Get-BitLockerVolume -MountPoint $OSDrive | select *
				BackupToAAD-BitLockerKeyProtector -MountPoint $OSDrive -KeyProtectorId $BLV.KeyProtector[1].KeyProtectorId
            }
			else
            { 
		  		# BackupToAAD-BitLockerKeyProtector commandlet not available, using other mechanisme  
				# Get the AAD Machine Certificate
				$cert = dir Cert:\LocalMachine\My\ | where { $_.Issuer -match "CN=MS-Organization-Access" }

				# Obtain the AAD Device ID from the certificate
				$id = $cert.Subject.Replace("CN=","")

				# Get the tenant name from the registry
				$tenant = (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo\$($id)).UserEmail.Split('@')[1]

				# Generate the body to send to AAD containing the recovery information
                Write-Host "--------------------------------------------------------------------------------------"
                Write-Host " COMMAND BackupToAAD-BitLockerKeyProtector failed!"
                Write-Host " Saving key protector to AAD for self-service recovery by manually posting it to:"
                Write-Host "                     https://enterpriseregistration.windows.net/manage/$tenant/device/$($id)?api-version=1.0"
                Write-Host "--------------------------------------------------------------------------------------"
				    # Get the BitLocker key information from WMI
					(Get-BitLockerVolume -MountPoint $OSDrive).KeyProtector|?{$_.KeyProtectorType -eq 'RecoveryPassword'} | %{
					$key = $_
					write-verbose "kid : $($key.KeyProtectorId) key: $($key.RecoveryPassword)"
					$body = "{""key"":""$($key.RecoveryPassword)"",""kid"":""$($key.KeyProtectorId.replace('{','').Replace('}',''))"",""vol"":""OSV""}"
				
				    # Create the URL to post the data to based on the tenant and device information
					$url = "https://enterpriseregistration.windows.net/manage/$tenant/device/$($id)?api-version=1.0"
				
				    # Post the data to the URL and sign it with the AAD Machine Certificate
					$req = Invoke-WebRequest -Uri $url -Body $body -UseBasicParsing -Method Post -UseDefaultCredentials -Certificate $cert
					$req.RawContent
                    Write-Host "--------------------------------------------------------------------------------------"
                    Write-Host " -- Key save web request sent to AAD - Self-Service Recovery should work"
                    Write-Host "--------------------------------------------------------------------------------------"
                    }
			}


        #In case we had to encrypt, turn it on for any enabled volume
        Get-BitLockerVolume | Resume-BitLocker

        # --------------------------------------------------------------------------
        #  Finish - Let's dump the ending point
        # --------------------------------------------------------------------------
        Write-Host "--------------------------------------------------------------------------------------"
        Write-Host " ENDING POINT:  Get-BitLockerVolume $OSDrive"
        Write-Host "--------------------------------------------------------------------------------------"
        $bdeProtect = Get-BitLockerVolume $OSDrive 

        #>
    } 
catch 
    { 
        write-error "Error while setting up AAD Bitlocker, make sure that you are AAD joined and are running the cmdlet as an admin: $_" 
    }
