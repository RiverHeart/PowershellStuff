<#
.SYNOPSIS
    Converts text into values that can be rendered as a barcode
    when used with a barcode font such as Libre Barcode 128.

.EXAMPLE
    Get type A barcode. Based on wikipedia's example.

    Get-BcBarcode128 "PJJ123C" -Type 'A' -Debug

    > ËPJJ123CVÎ

.EXAMPLE
    Pipeline usage plus debug

    PJJ123C" | Get-BcBarcode128 -Type 'A'
#>
function Get-BcBarcode128 {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        # Code Type. Not a char because hash lookup below will not work.
        [Parameter(Mandatory,Position=1)]
        [ValidateSet("A", "B", "C")]
        [string] $Type
    )

    begin {
        # Codes represent values used to calculate checksum.
        $Codes = 32..126 + 195..206
        switch ($Type) {
            'A' { $Output = [char][byte]203; $ProductSum = 103; break }
            'B' { $Output = [char][byte]204; $ProductSum = 104; break }
            'C' { $Output = [char][byte]205; $ProductSum = 105; break }
        }
        Write-Debug "Test $Output"
    }

    process {
        for ($i = 0; $i -lt $($Text.Length); $i++)
        {
            $Output += $Char = $Text[$i]

            # Ensure our input is allowed in this codeset.
            if (-not (Test-BcBarcode128Value $Char -Type $Type)) {
                throw "Value `"$Char`" not allowed in Codeset $Type"
            }

            $UnicodeValue = [byte][char]$Char - 32
            $ProductSum += $UnicodeValue * ($i + 1)
            Write-Debug "Unicode value for $Char is $UnicodeValue"
        }
    }

    end {
        $Checksum = $ProductSum % 103
        Write-Debug "ProductSum: $ProductSum"
        Write-Debug "Checksum: $Checksum"

        $Output += [char][byte] $Codes[$Checksum]
        $Output += [char][byte] 206  # Stop code

        return $Output
    }
}
