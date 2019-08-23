#!/bin/bash
#
# installProfile.ps1: A BASH/Powershell Polyglot to install workstation customizations
#
# Run this script from either Windows or Linux to download and install customizations.
#

# BASH script starts here
#BASH REPOSITORY=$(mktemp -d)
#BASH git clone -b master --depth=1 https://github.com/option42/environment.git $REPOSITORY >/dev/null 2>&1
#BASH if [ $? -ne 0 ]; then
#BASH   echo "Git clone of https://github.com/option42/environment.git failed.  Aborting." > 2
#BASH   exit 1
#BASH fi
#BASH if [ -f ~/.bash_profile ] || [ -f ~/.bash_login ]; then
#BASH   PROFILE=~/.bash_profile
#BASH else
#BASH   PROFILEFILE=~/.profile
#BASH fi
#BASH if ! grep -q '# Add Option42 Profile' $PROFILEFILE; then
#BASH   echo "# Add Option42 Profile" >> $PROFILEFILE
#BASH   echo 'if [ -f "$HOME/.option42_profile" ]; then' >> $PROFILEFILE
#BASH   echo '    . "$HOME/.option42_profile"' >> $PROFILEFILE
#BASH   echo 'fi' >> $PROFILEFILE
#BASH fi
#BASH if [ -f $REPOSITORY/linux/profile ]; then
#BASH     cp $REPOSITORY/linux/profile ~/.option42_profile
#BASH fi

# PowerShell script starts here
#POSH if(-not [bool](Get-Command git -Type Application -ErrorAction SilentlyContinue)) {
#POSH   Write-Error "git is not installed: unable to retrieve repository"
#POSH }
#POSH 
#POSH if(-not [bool](Get-Command 'New-TemporaryFile' -Type Function -ErrorAction SilentlyContinue)) {
#POSH   Set-Item function:New-TemporaryFile -Value {
#POSH         <#
#POSH         .SYNOPSIS
#POSH         New-TemporaryFile completes the same task as the PowerShell v5.0+ cmdlet of the same name
#POSH         #>
#POSH         $tempFile = New-Item -ItemType File -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName()))
#POSH         return $tempFile
#POSH   }
#POSH }
#POSH 
#POSH if(-not [bool](Get-Command 'New-TemporaryDirectory' -Type Function -ErrorAction SilentlyContinue)) {
#POSH   Set-Item function:New-TemporaryDirectory -Value {
#POSH         <#
#POSH         .SYNOPSIS
#POSH         New-TemporaryDirectory completes the same task as New-TemporaryFile, but makes a directory instead 
#POSH         #>
#POSH         $tempFile = New-TemporaryFile
#POSH         $tempDirectory = New-Item -ItemType Directory -Path "$($tempFile.DirectoryName)\$($tempfile.BaseName)" 
#POSH         Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
#POSH         return $tempDirectory
#POSH   }
#POSH }
#POSH 
#POSH $REPOSITORY = New-TemporaryDirectory
#POSH git clone -b master --depth=1 https://github.com/option42/environment.git $REPOSITORY.FullName | Out-Null
#POSH if ([bool](Test-Path "$($REPOSITORY.FullName)\windows\powershell_profile" -ErrorAction SilentlyContinue)) {
#POSH   $profilePath = ([System.IO.DirectoryInfo]$profile).Parent.FullName
#POSH   if( -not [bool](Test-Path $profilePath -ErrorAction SilentlyContinue)) {
#POSH     New-Item -Type Directory -Path $profilePath
#POSH   }
#POSH   Copy-Item -Path "$($REPOSITORY.FullName)\windows\powershell_profile\*.ps1" -Destination $profilePath
#POSH }
#POSH Remove-Item -Path $REPOSITORY -Force -Recurse -ErrorAction SilentlyContinue

function executeInstallationBash {
  MYTEMPFILE=$(mktemp)
  echo "#!/bin/bash" > $MYTEMPFILE
  sed -e '/^#BASH/!d' -e 's/^#BASH //g' $0 >> $MYTEMPFILE
  chmod +x $MYTEMPFILE
  $MYTEMPFILE
  rm $MYTEMPFILE
  exit
}

"executeInstallationBash"

# PowerShell Here
if(-not [bool](Get-Command 'New-TemporaryFile' -Type Function -ErrorAction SilentlyContinue)) {
  Set-Item function:New-TemporaryFile -Value {
        <#
        .SYNOPSIS
        New-TemporaryFile completes the same task as the PowerShell v5.0+ cmdlet of the same name
        #>
        $tempFile = New-Item -ItemType File -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName()))
        return $tempFile
  }
}

$MYTEMPFILE=(New-TemporaryFile)
Rename-Item -Path $MYTEMPFILE.FullName -NewName "$($MYTEMPFILE.BaseName).ps1"
$MYTEMPSCRIPT = Get-ChildItem -Path "$($MYTEMPFILE.Directory.FullName)\$($MYTEMPFILE.BaseName).ps1"
((Get-Content $MyInvocation.MyCommand.Source) -match '^#POSH' -replace '^#POSH ') -join "`n" | Set-Content -Path $MYTEMPSCRIPT.FullName
& "$($MYTEMPSCRIPT.FullName)"

Remove-Item -Path $MYTEMPSCRIPT.FullName
