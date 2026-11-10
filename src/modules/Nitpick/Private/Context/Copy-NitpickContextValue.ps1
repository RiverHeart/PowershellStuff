using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.Management.Automation

<#
.SYNOPSIS
    Copies plain context data without retaining mutable references or ETS members.
.DESCRIPTION
    Accepts string-keyed dictionaries, one-dimensional arrays, null, strings,
    Booleans, CLR numeric values, and System.Version. Repeated references are
    copied independently; cycles and unsupported values terminate with
    NitpickInvalidContext and the offending key/index path.

.EXAMPLE
    $Original = @{ Extra = @{ Values = @(1, 2) } }
    $Copy = Copy-NitpickContextValue -Value $Original
    $Copy.Extra.Values[0] = 9
    $Original.Extra.Values[0]

    Returns 1: changing a nested array in the copy leaves the original unchanged.

.EXAMPLE
    $Shared = @{ Enabled = $true }
    $Copy = Copy-NitpickContextValue -Value @{ Left = $Shared; Right = $Shared }
    $Copy.Left.Enabled = $false
    $Copy.Right.Enabled

    Returns True: repeated references produce independent copies, not a shared
    mutable subgraph. A reference back to an active ancestor would instead error.

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function Copy-NitpickContextValue {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowNull()]
        [object] $Value,

        [string] $Path = 'Context'
    )

    $Active = [List[object]]::new()
    $GetRuntimeType = [object].GetMethod('GetType')

    <#
    .SYNOPSIS
        Copies one value while retaining the active ancestor path for cycle checks.
    #>
    function Copy-Value {
        param(
            [AllowNull()]
            [object] $Item,

            [string] $ItemPath
        )

        if ($null -eq $Item) { return $null }

        $Base = $Item.psobject.BaseObject
        $Type = $GetRuntimeType.Invoke($Base, $null)

        if ($Base -is [IDictionary] -or $Base -is [array]) {
            foreach ($Ancestor in $Active) {
                if ([object]::ReferenceEquals($Base, $Ancestor)) {
                    throw [ArgumentException]::new("Cyclic context value at '$ItemPath'.")
                }
            }

            $Active.Add($Base)

            try {
                if ($Base -is [IDictionary]) {
                    $Copy = @{}

                    foreach ($Key in $Base.psbase.Keys) {
                        if ($Key -isnot [string]) {
                            throw [ArgumentException]::new(
                                "Non-string dictionary key at '$ItemPath'."
                            )
                        }

                        if ($Copy.ContainsKey($Key)) {
                            throw [ArgumentException]::new(
                                "Case-duplicate dictionary key at '$ItemPath.$Key'."
                            )
                        }

                        $CleanKey = [string]::new($Key.psbase.ToCharArray())
                        $Copy[$CleanKey] = Copy-Value `
                            -Item $Base[$Key] `
                            -ItemPath "$ItemPath.$CleanKey"
                    }

                    return ,$Copy
                }
                if ($Base.psbase.Rank -ne 1) {
                    throw [ArgumentException]::new("Multidimensional array at '$ItemPath'.")
                }

                $Copy = [object[]]::new($Base.psbase.Length)

                for ($Index = 0; $Index -lt $Base.psbase.Length; $Index++) {
                    $Copy[$Index] = Copy-Value `
                        -Item $Base.psbase.GetValue($Index + $Base.psbase.GetLowerBound(0)) `
                        -ItemPath "$ItemPath[$Index]"
                }

                return ,$Copy
            } finally {
                $Active.RemoveAt($Active.Count - 1)
            }
        }

        if ($Type -eq [string]) { return [string]::new($Base.psbase.ToCharArray()) }

        if ($Type -eq [version]) {
            return [version]::new($Base.psbase.ToString())
        }

        if ($Type -eq [bool]) { return [bool]::Parse($Base.psbase.ToString()) }

        if ($Type -in @(
            [sbyte], [byte], [int16], [uint16], [int32], [uint32],
            [int64], [uint64], [single], [double], [decimal]
        )) {
            $Text = if ($Type -eq [single] -or $Type -eq [double]) {
                $Base.psbase.ToString('R', [CultureInfo]::InvariantCulture)
            } else {
                $Base.psbase.ToString([CultureInfo]::InvariantCulture)
            }

            return $Type::Parse($Text, [CultureInfo]::InvariantCulture)
        }

        throw [ArgumentException]::new(
            "Unsupported context type '$($Type.FullName)' at '$ItemPath'."
        )
    }

    try {
        $Copy = Copy-Value -Item $Value -ItemPath $Path
        return ,$Copy
    } catch {
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $_.Exception,
            'NitpickInvalidContext',
            [ErrorCategory]::InvalidData,
            $Path
        ))
    }
}
