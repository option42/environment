#
# Microsoft.PowerShell_profile.ps1 - Intended to serve as $profile.CurrentUserCurrentHost when not using the ISE
# Currently only starts a transcript.  Everything else is in the main profile script.
#

if(Test-PSInteractive)
{
    $year = Get-Date -Format yyyy
    $month = Get-Date -Format MM
    $day = Get-Date -Format dd
    $hour = Get-Date -Format HH
    $minute = Get-Date -Format mm
    # Make the log folder if it doesn't already exist
    if(-not (Test-Path -PathType Container -Path "${env:OneDrive}\!logs\${year}\${month}"))
    {
        New-Item -ItemType Directory -Path "${env:OneDrive}\!logs\${year}\${month}"
    }
    # Start the transcript - Append (in case we for some reason created multiple sessions in the same minute - if we did, it's our own fault)
    Start-Transcript "${env:OneDrive}\!logs\${year}\${month}\transcript-${year}${month}${day}-${hour}${minute}.log" -Append
}
