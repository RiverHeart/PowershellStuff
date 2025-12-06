<#
.SYNOPSIS
    Converts a timespan or time unit into a human readable string

.EXAMPLE
    Convert timespan into human readable string, with lower bound
    in seconds and with a formatted message where {0} represents
    the timespan.

    New-TimeSpan -Days 30 -Hours 30 -Minutes 16 -Seconds 15 |
        Format-TimeAsHumanString -Message "Completed in {0}" -LowerBound Seconds

    > Completed in 31 Days, 6 Hours, 16 Minutes, 15 Seconds

.EXAMPLE
    Measure command timespan and get output.

    Measure-Command { Start-Sleep -Seconds 80 } |
        Format-TimeAsHumanString -UpperBound Hours -LowerBound Seconds

    > 0 Hours, 1 Minutes, 20 Seconds

.EXAMPLE
    Use minimal flag to remove zero valued units from output.

    New-TimeSpan -Days 2 -Hours 0 -Minutes 16 -Seconds 0 |
        Format-TimeAsHumanString -Message "Completed in {0}" -MinimalOutput

    > Completed in 2 Days, 16 Minutes

.EXAMPLE
    Convert milliseconds output from Invoke-Sqlcmd to human readable string.

    Invoke-Sqlcmd `
        -ConnectionString $ConnectionString `
        -Query "WAITFOR DELAY '00:00:10'" `
        -StatisticsVariable sqlstats
    Format-TimeAsHumanString `
        -Duration $SqlStats.ExecutionTime `
        -Unit Milliseconds `
        -Message "Completed in {0}" `
        -MinimalOutput

    > Completed in 10 Seconds, 692 Milliseconds
#>
function Format-TimeAsHumanString {
    [CmdletBinding(DefaultParameterSetName='Timespan')]
    param(
        [Parameter(Mandatory,ParameterSetName='Timespan',ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [TimeSpan] $TimeSpan,

        [Parameter(Mandatory,ParameterSetName='TimeUnit',ValueFromPipeline)]
        [ValidateNotNull()]
        [int64] $Duration,

        [Parameter(Mandatory,ParameterSetName='TimeUnit')]
        [ValidateSet('Days', 'Hours', 'Minutes', 'Seconds', 'Milliseconds')]
        [string] $Unit,

        [Parameter(HelpMessage="Message to format with date string using {0} as placeholder")]
        [ValidateNotNullOrEmpty()]
        [string] $Message,

        [Parameter(HelpMessage="Anything greater than this unit will be ignored. WARNING: this time is not added to other units")]
        [ValidateSet('Days', 'Hours', 'Minutes', 'Seconds', 'Milliseconds')]
        [string] $UpperBound = 'Days',

        [Parameter(HelpMessage="Anything lower than this unit will be ignored. WARNING: this time is not added to other units")]
        [ValidateSet('Days', 'Hours', 'Minutes', 'Seconds', 'Milliseconds')]
        [string] $LowerBound = 'Milliseconds',

        [Parameter(HelpMessage="Ignore time units that are 0")]
        [switch] $MinimalOutput
    )

    process {
        enum TimeUnit {
            Milliseconds = 0
            Seconds = 1
            Minutes = 2
            Hours = 3
            Days = 4
        }

        if ([TimeUnit] $LowerBound -gt $UpperBound) {
            throw "LowerBound cannot be greater than UpperBound"
        }

        # Convert time unit to timespan object
        if ($PSCmdlet.ParameterSetName -eq 'TimeUnit') {
            $TimeSpan = switch ($Unit) {
                'MILLISECONDS' { [TimeSpan]::FromMilliseconds($Duration) }
                'SECONDS' { [TimeSpan]::FromSeconds($Duration) }
                'MINUTES' { [TimeSpan]::FromMinutes($Duration) }
                'HOURS' { [TimeSpan]::FromHours($Duration) }
                'DAYS' { [TimeSpan]::FromDays($Duration) }
                default { throw "Unsupported time unit '$Unit'" }
            }
        }

        $Builder = [System.Text.StringBuilder]::new()
        $Types = [System.Enum]::GetNames([TimeUnit]) | ForEach-Object { [TimeUnit] $_ } | Sort-Object -Descending
        foreach ($Type in $Types) {
            $ViolatesUpperBound = $UpperBound -and [TimeUnit] $Type -gt $UpperBound
            $ViolatesLowerBound = $LowerBound -and [TimeUnit] $Type -lt $LowerBound
            if ($ViolatesUpperBound -or $ViolatesLowerBound) {
                continue  # Skipping
            }

            $Value = $Timespan."$Type"

            if ($MinimalOutput -and $Value -le 0) {
                continue  # Skipping
            }

            $Comma = if ($Builder.Length -gt 0) { ', ' } else { '' }
            $Builder.Append("${Comma}${Value} ${Type}") | Out-Null
        }

        if ($Message) {
            $Message -f $Builder.ToString()
        } else {
            $Builder.ToString()
        }
    }
}
