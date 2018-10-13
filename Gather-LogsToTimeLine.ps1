<#
    .SYNOPSIS 
        Gather Event Logs from the current Windows system and place them in to a folder of your choosing.
    .DESCRIPTION 
        Gathers All Event Logs from Windows 7/2008R2 and newer operating systems.
		
		Requires Powershell Version 2+ and an ExecutionPolicy of 'unrestricted'.
		
		By default, all logs that can be gathered with Get-EventLog will be parsed immediately as it is the fastest possible method.
		This behavior can be changed with the excludeEvtxFiles and IncludeAllEvtxFiles parameters.
		
		Output is sorted in a single folder. It can then be compressed and moved over to another system for parsing.
		
		This script does not delete or clear any event logs.
    .PARAMETER Output  
        The folder where all event logs will be saved. Absolute and relative paths are allowed
    .PARAMETER excludeEvtxFiles  
        A comma separated list of all logs this script should just parse now instead of gathering the .evtx file for parsing. Default is any log that can be gathered with Get-EventLog (This is the fastest mode possible)
    .PARAMETER IncludeAllEvtxFiles  
        Gathers evtx files for all logs excluded under the "excludeEvtxFiles" parameter. This doesn't slow down collection too much but allows you to use the evtx files in other tools.
	.PARAMETER LogTag  
        Prepends a string of your choosing to the all collected log files. Default is the local computer name.
    .EXAMPLE 
        .\Gather-LogsToTimeLine.ps1 -output "c:\Logs"
		Places all Event Logs into the folder "C:\Logs". The folder will be created if it does not already exist.
	.EXAMPLE 
        .\Gather-LogsToTimeLine.ps1 -output "c:\Logs" -excludeEvtxFiles Security,System
		Places all Event Logs into the folder "C:\Logs". The folder will be created if it does not already exist. Only the Security and System log will be parsed immediately. The rest will be exported as evtx files.
	.EXAMPLE 
        .\Gather-LogsToTimeLine.ps1 -output "c:\Logs" -excludeEvtxFiles Security,System -IncludeAllEvtxFiles
		Places all Event Logs into the folder "C:\Logs". The folder will be created if it does not already exist. Only the Security and System log will be parsed immediately. All Logs (Including Security and System) will be exported as evtx files.
		
    .NOTES 
        Author: @piesecurity - https://twitter.com/piesecurity - admin@pie-secure.org       
        LEGAL:
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
    
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.
        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <http://www.gnu.org/licenses/>.
    #>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string]$output=".\Logs",
    [Parameter(Mandatory=$false)]
    $excludeEvtxFiles = ((get-eventlog -list) | foreach-object{$_.log}),
    [Parameter(Mandatory=$false)]
    $logTag = $env:ComputerName,
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAllEvtxFiles
)


function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false) {
    Write-Error "Script Not Ran as Admin"
    exit
}

Write-Verbose "Checking For Output Directory"
if (!(test-path $output)) {
Write-Verbose "Creating Output Directory $output"
    mkdir $output | Out-Null
}

if ($excludeEvtxFiles) {
    $excludeEvtxFiles | ForEach-Object {
        $LogName = "$LogTag-" + $_
        Write-Verbose "Dumping $_ Event Log to CSV"
        Try {
            Get-EventLog $_ -ErrorAction Stop |
                select @{name="containerLog";expression={$LogName}},
                    @{name="id";expression={$_.EventID}},
                    @{name="levelDisplayName";expression={$_.EntryType}},
                    MachineName,
                    @{name="LogName";expression={$LogName}},
                    ProcessId,
                    @{name="UserId";expression={$_.UserName}},
                    @{name="ProviderName";expression={$_.source}},
                    @{Name="TimeCreated";expression={(($_.TimeGenerated).ToUniversalTime()).ToString('yyyy-MM-dd HH:mm:ssZ')}},
                    @{Name="Message";expression={$_.message -replace "\r\n"," | " -replace "\n", " | " -replace "The local computer may not have the necessary registry information or message DLL files to display the message, or you may not have permission to access them.",""}} | 
               Export-Csv -NoTypeInformation ($output + "\" + "$LogTag-" + $_ + ".csv")
        }
        Catch {
            Write-Verbose "Previous Log doesn't have any records. No output will be produced"
        }
        
    }
}
Write-Verbose "Dump All Operational Logs Event Log With Tag: $logtag Excluding: $excludeEvtxFiles"

Get-WinEvent -ListLog * | where-object {$_.recordcount -gt 0} | where-object {$excludeEvtxFiles -notcontains $_.LogName} |
ForEach-Object {
    wevtutil epl $_.LogName  ($output + "\" + "$LogTag-" + ($_.LogName -replace "/","%4") +".evtx")
}

Write-Verbose "Adding Event Context to exported evtx files"
Get-ChildItem $output\*.evtx | ForEach-Object {
    wevtutil archive-log $_ /l:en-us
}

if ($IncludeAllEvtxFiles) {
    Write-Verbose "Gathering Evtx Files for all previously excluded files"
    $excludeEvtxFiles | ForEach-Object {
        wevtutil epl $_ ($output + "\" + "$LogTag-" + ($_ -replace "/","%4") +".evtx")
    }
    Write-Verbose "Adding Event Context to previously excluded files"
    $excludeEvtxFiles | foreach-object {
        Get-ChildItem ($output +"\" + $LogTag + "-" + $_ + ".evtx") | ForEach-Object {
            wevtutil archive-log $_ /l:en-us
        }
    }
}



