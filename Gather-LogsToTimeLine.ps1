[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false)]
    [string]$output=".\Logs",
    [Parameter(Mandatory=$false)]
    $excludeEvtxFiles = (Get-EventLog -List).Log,
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

Get-WinEvent -ListLog * | where-object {$_.recordcount -gt 0} | where-object {$_.LogName -notin $excludeEvtxFiles} | 
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



