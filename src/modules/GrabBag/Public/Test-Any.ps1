<#
.SYNOPSIS
    Returns true if any element evaluates to true

.NOTES
    Been a minute since I touched this and GetSteppablePipeline()
    isn't something I call often but it essentially acts as a wrapper
    for Foreach-Object so we can get the same behaviour without
    the boilerplate. Has the benefit that we can prematurely
    end the pipeline once our condition is fulfilled.

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
                $Pipe.End()  # Stop processing input
                return  # Leave process block, move to end
            }
        }
    }

    end {
        return $HadSuccess
    }
}