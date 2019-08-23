<#
.SYNOPSIS

Profile bootstrapper & redirector

.DESCRIPTION

profile.ps1 is intended to be copied to each machine a user utilizes into the
location identified by $profile.CurrentUserAllHosts.  This script will grab the
most-recent version of itself from the user's OneDrive, as well as source the
OneDrive-hosted version of their profile script so that the user receives a
consistent experience on all of their machines.

#>

Set-StrictMode -Version latest

# Create the profile directory if it does not already exist
if(-not (Test-Path (Split-Path $profile.CurrentUserAllHosts)))
{
    New-Item -ItemType Directory -Path (Split-Path $profile.CurrentUserAllHosts)
}

# Copy this script from OneDrive to the local profile directory - serves as a
# bootstrapper and also self-updater
if(-not (Test-Path $profile.CurrentUserAllHosts))
{
    Copy-Item -Path "${env:OneDrive}\scripts\powershell\profile\bootstrap.ps1" -Destination $profile.CurrentUserAllHosts
}
else
{
    # See if the version of this script on OneDrive is different, if it is, update the script and the re-execute
    if((Get-FileHash -Algorithm SHA256 -Path $profile.CurrentUserAllHosts).Hash -ne (Get-FileHash -Algorithm SHA256 -Path "${env:OneDrive}\scripts\powershell\profile\bootstrap.ps1").Hash)
    {
        Copy-Item -Path "${env:OneDrive}\scripts\powershell\profile\bootstrap.ps1" -Destination $profile.CurrentUserAllHosts
        & $profile.CurrentUserAllHosts
        # The execution above will pick up where this one leaves off.  We can exit now.
        return
    }
}

# Source the "CurrentUserAllHosts" script from OneDrive
if(Test-Path "${env:OneDrive}\scripts\powershell\profile\$(Split-Path -Leaf $profile.CurrentUserAllHosts)")
{
    . "${env:OneDrive}\scripts\powershell\profile\$(Split-Path -Leaf $profile.CurrentUserAllHosts)"
}

# Source the "CurrentUserCurrentHost" script from OneDrive
if(Test-Path "${env:OneDrive}\scripts\powershell\profile\$(Split-Path -Leaf $profile.CurrentUserCurrentHost)")
{
    . "${env:OneDrive}\scripts\powershell\profile\$(Split-Path -Leaf $profile.CurrentUserCurrentHost)"
}
