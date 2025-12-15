<#
.SYNOPSIS
    Checks whether a given value is valid for a given code set.

.EXAMPLE
    Test-BcBarcode128Value 'P' -Type 'A'  # returns $True
    Test-BcBarcode128Value 'p' -Type 'A'  # returns $False
#>
function Test-BcBarcode128Value {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Value,

        # Code Type. Not a char because hash lookup below will not work.
        [Parameter(Mandatory,Position=1)]
        [ValidateSet("A", "B", "C")]
        [string] $Type
    )

    begin {
        # Covers 0-9, A-Z, control codes, special characters, and FNC 1-4
        [byte[]] $CodeSetA = 0..95 + @(202, 197, 196, 201)

        # Covers 0-9, A-Z, a-z, special characters, and FNC 1-4
        [byte[]] $CodeSetB = 32..127 + @(207, 202, 201, 205)
    }

    process {
        $IsValid = $True
        switch($Type) {
            'A' { if (-not $CodeSetA.Contains([byte][char]$Value)) { $IsValid = $False }; break}
            'B' { if (-not $CodeSetB.Contains([byte][char]$Value)) { $IsValid = $False }; break}
            'C' { if (-not [char]::IsDigit($Value)) { $IsValid = $False }; break}
        }

        Write-Output $IsValid
    }
}
