#Set variables as input for the script
$KeyPath = "HKLM:\SOFTWARE\Palo Alto Networks\GlobalProtect\PanSetup"
$KeyName = "Portal"
$KeyValue = "fqdn.portal.com"

#Verify if the registry path already exists
if(!(Test-Path $KeyPath)) {
    try {
        #Create registry path
        New-Item -Path $KeyPath -ItemType RegistryKey -Force -ErrorAction Stop
    }
    catch {
        Write-Output "FAILED to create the registry path"
    }
}

#Verify if the registry key already exists
if(!((Get-ItemProperty $KeyPath).$KeyName)) {
    try {
        #Create registry key 
        New-ItemProperty -Path $KeyPath -Name $KeyName -Value $KeyValue
    }
    catch {
        Write-Output "FAILED to create the registry key"
    }
} 
