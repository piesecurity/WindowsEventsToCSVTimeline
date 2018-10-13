# WindowsEventsToCSVTimeline

A couple of simple Powershell scripts to collect all Windows Event Logs from a host and parse them into one CSV Timeline.

## But Why This Script?
This script uses Windows Powershell to parse event logs following 5 goals.

1. **Be Quick** - We play to the strong suits of Get-WinEvent and Get-EventLog and use the quickest one in the right situations

2. **Avoid Missing Event Viewer Descriptors** - We collect metadata from Event Logs during collection. If your parsing box doesn't have all the same roles we avoid this dreaded error.

```
# Example of Missing Descriptors
The description for Event ID 100 from source XXXX cannot be found. Either the component that raises this event is not installed on your local computer or the installation is corrupted. You can install or repair the component on the local computer.
```

To accomplish goal #1, we only use the metadata when it is required.

3. **Conform the Timestamp and Convert Everything to UTC**

4. **Timeline Logs from Multiple Systems at Once**

5. **Be Multi-Threaded** - We use this great project to multi-thread our parsing and push Get-WinEvent (and your CPU) as fast as possible. https://github.com/RamblingCookieMonster/Invoke-Parallel

### System Requirements

**Gather-LogsToTimeLine.ps1** only supports PowerShell version 2.0 thru 5.1

*1.0 and 6.0+ (PSCore) are not supported*

**Parse-LogsToTimeLine.ps1** only support Powershell Versions 3.0+

*PowerShell v6 (PSCore) is supported on Windows Only*

### Getting Started

Collect All of the Logs!
```
.\Gather-LogsToTimeLine.ps1 -output "c:\Logs"

#Now copy your log files back to your analysis system
```

Parse All of the Logs!
```
.\Parse-LogsToTimeLine.ps1 -LogFolder "C:\Logs" -outputfile MyTimeline.csv
```

### Additional Options
```
Get-Help .\Gather-LogsToTimeLine.ps1 -Full
Get-Help .\Parse-LogsToTimeLine.ps1 -Full
```


