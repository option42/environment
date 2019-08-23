#
# profile.ps1 - Intended to serve as $profile.CurrentUserAllHosts
#
#

<#

.SYNOPSIS

Just a convenience to more readily indicate if we are a script or an interactive session

.EXAMPLE

PS > Test-PSInteractive
True

#>
function Test-PSInteractive
{
    return (-not [bool]([Environment]::GetCommandLineArgs() -like '-noni*'))
}

<#

.SYNOPSIS

Just a convenience to more readily indicate if we are in the ISE or not

.EXAMPLE

PS > Test-IsHostISE
False

#>
function Test-IsHostISE
{
    if ($host.name -eq 'Windows PowerShell ISE Host')
    {
        return $true
    }
    else
    {
        return $true
    }
}

<#

.SYNOPSIS

Just a convenience to more readily indicate if we are in a console or not

.EXAMPLE

PS > Test-IsHostConsole
False

#>
function Test-IsHostConsole
{
    if($host.name -eq 'ConsoleHost')
    {
        return $true
    }
    else
    {
        return $true
    }
}

<#

.SYNOPSIS

Get an alias suggestion from the full text of the last command. Intended to
be added to your prompt function to help learn aliases for commands.

Inverse of Get-AliasExpansion

.EXAMPLE

PS > Get-AliasSuggestion Remove-ItemProperty
Suggestion: An alias for Remove-ItemProperty is rp

#>
function Get-AliasSuggestion
{
    param(
        ## The full text of the last command
        $LastCommand
    )

    $helpMatches = @()

    ## Find all of the commands in their last input
    $tokens = [Management.Automation.PSParser]::Tokenize(
        $lastCommand, [ref] $null)
    $commands = $tokens | Where-Object { $_.Type -eq "Command" }

    ## Go through each command
    foreach($command in $commands)
    {
        ## Get the alias suggestions
        foreach($alias in (Get-Alias -Definition $command.Content -ErrorAction SilentlyContinue))
        {
            $helpMatches += "Suggestion: An alias for " +
                "$($alias.Definition) is $($alias.Name)"
        }
    }

    $helpMatches
}

<#

.SYNOPSIS

Get an alias expansion from the full text of the last command. Intended to
be added to your prompt function to help learn commands for aliases.

Inverse of Get-AliasSuggestion

.EXAMPLE

PS > Get-AliasExpansion rp
Suggestion: An expansion for rp is Remove-ItemProperty

#>
function Get-AliasExpansion
{
    param(
        ## The full text of the last command
        $LastCommand
    )

    $helpMatches = @()

    ## Find all of the commands in their last input
    $tokens = [Management.Automation.PSParser]::Tokenize(
        $lastCommand, [ref] $null)
    $commands = $tokens | Where-Object { $_.Type -eq "Command" }

    ## Go through each command
    foreach($command in $commands)
    {
        ## Get the alias suggestions
        foreach($alias in (Get-Alias -Name $command.Content -ErrorAction SilentlyContinue))
        {
            $helpMatches += "Suggestion: An expansion for " +
                "$($alias.Name) is $($alias.Definition)"
        }
    }

    $helpMatches
}

<#

.SYNOPSIS

Runs the provided script block under an elevated instance of PowerShell as
through it were a member of a regular pipeline.

.EXAMPLE

PS > Get-Process | Invoke-ElevatedCommand {
    $input | Where-Object { $_.Handles -gt 500 } } | Sort Handles

#>
function Invoke-ElevatedCommand
{
    param(
        ## The script block to invoke elevated
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $Scriptblock,

        ## Any input to give the elevated process
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        ## Switch to enable the user profile
        [switch] $EnableProfile
    )

    begin
    {
        Set-StrictMode -Version 3
        $inputItems = New-Object System.Collections.ArrayList
    }

    process
    {
        $null = $inputItems.Add($inputObject)
    }

    end
    {
        ## Create some temporary files for streaming input and output
        $outputFile = [IO.Path]::GetTempFileName()
        $inputFile = [IO.Path]::GetTempFileName()

        ## Stream the input into the input file
        $inputItems.ToArray() | Export-CliXml -Depth 1 $inputFile

        ## Start creating the command line for the elevated PowerShell session
        $commandLine = ""
        if(-not $EnableProfile) { $commandLine += "-NoProfile " }

        ## Convert the command into an encoded command for PowerShell
        $commandString = "Set-Location '$($pwd.Path)'; " +
            "`$output = Import-CliXml '$inputFile' | " +
            "& {" + $scriptblock.ToString() + "} 2>&1; " +
            "`$output | Export-CliXml -Depth 1 '$outputFile'"

        $commandBytes = [System.Text.Encoding]::Unicode.GetBytes($commandString)
        $encodedCommand = [Convert]::ToBase64String($commandBytes)
        $commandLine += "-EncodedCommand $encodedCommand"

        ## Start the new PowerShell process
        $process = Start-Process -FilePath (Get-Command powershell).Definition `
            -ArgumentList $commandLine -Verb RunAs `
            -WindowStyle Hidden `
            -Passthru
        $process.WaitForExit()

        ## Return the output to the user
        if((Get-Item $outputFile).Length -gt 0)
        {
            Import-CliXml $outputFile
        }

        ## Clean up
        Remove-Item $outputFile
        Remove-Item $inputFile
    }
}

<#

.SYNOPSIS

Part of the slow POSIX-ification of my PowerShell profile.

.EXAMPLE

PS > which which
which: PowerShell Function

PS > which gci
gci: Alias for Get-ChildItem

PS > which ssh
C:\WINDOWS\System32\OpenSSH\ssh.exe

#>
function which
{
    param(
        ## The command or program to be resolved
        [Parameter(Mandatory = $true,
        ValueFromPipeline = $true)]
        $name
    )
    try
    {
        if($command = Get-Command $name -ErrorAction SilentlyContinue)
        {
            switch($command.CommandType)
            {
                "Alias"
                {
                    "${name}: Alias for "+$command.Definition
                }
                "Application"
                {
                    $command.Path
                }
                "Cmdlet"
                {
                    "${name}: PowerShell Cmdlet"
                }
                "Function"
                {
                    "${name}: PowerShell Function"
                }
                default
                {
                    $command | Select-Object -ExpandProperty Definition
                }
            }
        }
    }
    catch
    {
        Write-Host ""
    }
}

<#

.SYNOPSIS

Make every ssh connection a tmuxified-connection (if possible)

.EXAMPLE

PS > ssh <hostspec> [session]

#>
function sshAliasFunction
{
    $sshCommand = Get-Command -Type Application -Name ssh -ErrorAction SilentlyContinue
    if($sshCommand -eq $null)
    {
        throw "Cannot find ssh application"
    }
    if($args[0] -eq $null)
    {
        throw "You must specify a host to connect to"
    }
    $session = "main"
    if($args.length -gt 1)
    {
        $session = $args[1]
    }
    if(Test-IsHostConsole)
    {
        & $sshCommand.Path $args[0] -t "(which tmux >/dev/null 2>&1 && (tmux has-session -t ${session} 2>/dev/null && tmux attach -t ${session}) || tmux new -s ${session}) || /bin/bash || /bin/sh"
    }
    else
    {
        Start-Process -FilePath $sshCommand.Path -ArgumentList "$($args[0]) -t `"(which tmux >/dev/null 2>&1 && (tmux has-session -t ${session} 2>/dev/null && tmux attach -t ${session}) || tmux new -s ${session}) || /bin/bash || /bin/sh`""
    }
}
Set-Alias -Name ssh -Value sshAliasFunction

###############################################################################
###############################################################################
###############################################################################
# Customize the prompt, only if we are interactive
if (Test-PSInteractive)
{
    # Not really that nice, but I don't want to evaluate the (Get-Host).Name on every command execution.
    # We will check it once, and set the prompt function appropriately
    if((Get-Host).Name -eq "Windows PowerShell ISE Host")
    {
        function global:prompt
        {
            ## Get the last item from the history
            $historyItem = Get-History -Count 1
            ## If there were any history items
            if($historyItem)
            {
                $next = (($historyItem).Id) + 1
                ## Get the training suggestion for that item
                $suggestions = @(Get-AliasExpansion $historyItem.CommandLine)
                ## If there were any suggestions
                if($suggestions)
                {
                    ## For each suggestion, write it to the screen
                    foreach($aliasSuggestion in $suggestions)
                    {
                        Write-Host "$aliasSuggestion"
                    }
                    Write-Host ""
                }
            }
            else
            {
                $next = 1;
            }
            $pwdLeaf = Split-Path(Get-Location) -Leaf
            "PS ${pwdLeaf} [${next}]> "
        }
    }
    else
    {
        function global:prompt
        {
            ## Get the last item from the history
            $historyItem = Get-History -Count 1
            ## If there were any history items
            if($historyItem)
            {
                $next = (($historyItem).Id) + 1
                ## Get the training suggestion for that item
                $suggestions = @(Get-AliasSuggestion $historyItem.CommandLine)
                ## If there were any suggestions
                if($suggestions)
                {
                    ## For each suggestion, write it to the screen
                    foreach($aliasSuggestion in $suggestions)
                    {
                        Write-Host "$aliasSuggestion"
                    }
                    Write-Host ""
                }
                $durationString="d:$(($historyItem.EndExecutionTime - $historyItem.StartExecutionTime).minutes) "
            }
            else
            {
                $next = 1;
                $durationString=""
            }
            $pwdLeaf = Split-Path(Get-Location) -Leaf
            $host.UI.RawUI.WindowTitle = Get-Location
            "PS ${durationString}${pwdLeaf} [${next}]> "
        }
    }
}