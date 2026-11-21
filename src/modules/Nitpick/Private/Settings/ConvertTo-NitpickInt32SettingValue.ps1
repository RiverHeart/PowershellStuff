using namespace System

<#
.SYNOPSIS
    Converts one rule-settings value to Int32, rejecting loosely typed input.

.DESCRIPTION
    Accepts only integral CLR values (SByte through UInt64) that fit in Int32.
    Strings, Booleans, null, decimals, and floating-point values are rejected.

    PowerShell's ordinary [int] cast would turn '5', $true, and 2.6 into 5, 1,
    and 3. A mistyped settings file would then silently run with a surprising
    value, so settings use this stricter conversion instead.

.PARAMETER Value
    The value to convert.

.PARAMETER Name
    Describes the value in error messages, such as "setting 'MaximumLength'".

.EXAMPLE
    ConvertTo-NitpickInt32SettingValue -Value ([int16] 80) -Name "setting 'MaximumLength'"

    Returns 80 as an Int32. Any integral type within the Int32 range is accepted.

.EXAMPLE
    ConvertTo-NitpickInt32SettingValue -Value '80' -Name "setting 'MaximumLength'"

    Throws "setting 'MaximumLength' must be an integer in the Int32 range ...",
    because strings are not converted.

.NOTES
    Private helper; examples run within Nitpick's module scope. Messages omit the
    rule ID because the calling function adds it once when it reports the error.
#>
function ConvertTo-NitpickInt32SettingValue {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $IntegralTypes = @(
        [sbyte], [byte], [int16], [uint16], [int32], [uint32], [int64], [uint64]
    )

    if ($null -eq $Value -or $Value.GetType() -notin $IntegralTypes) {
        throw [ArgumentException]::new(
            "$Name must be an integer in the Int32 range; Boolean, null, string, " +
            'decimal, and floating-point values are not accepted.'
        )
    }

    $DecimalValue = [decimal] $Value
    if ($DecimalValue -lt [int]::MinValue -or $DecimalValue -gt [int]::MaxValue) {
        throw [ArgumentException]::new(
            "$Name must be between $([int]::MinValue) and $([int]::MaxValue); actual value is $Value."
        )
    }

    return [int] $DecimalValue
}
