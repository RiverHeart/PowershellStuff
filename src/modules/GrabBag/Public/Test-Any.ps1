<#
.SYNOPSIS
    Returns true if any element evaluates to true

.EXAMPLE
    $Number = 10
    $FoundNumber = 1..10 | Test-Any { $_ -eq $Number }
    if ($FoundNumber) {
        Write-Host "Found number '$Number'"
    }
#>
function Test-Any {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $Scriptblock,

        [Parameter(Mandatory,ValueFromPipeline)]
        [Object[]] $InputObject
    )

    begin {
        $Pipe = { ForEach-Object $Scriptblock }.GetSteppablePipeline()
        $Pipe.Begin($True)
        $HadSuccess = $false
    }

    process {
        foreach($Item in $InputObject) {
            $Result = $Pipe.Process($Item)
            if ($Result) {
                $HadSuccess = $true
                $Pipe.End()
                return  # Stop processing, move to end
            }
        }
    }

    end {
        return $HadSuccess
    }
}