using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.Management.Automation

<#
.SYNOPSIS
    Copies plain data without retaining mutable references or ETS members.

.DESCRIPTION
    Accepts string-keyed dictionaries, one-dimensional arrays, null, strings,
    Booleans, CLR numeric values, and System.Version. Repeated references are
    copied independently; cycles and unsupported values terminate with
    NitpickInvalidPlainData and the offending key/index path.

    Nitpick passes context and rule settings to rule code that it does not own.
    Each predicate, producer, rule, and target receives its own copy, so one rule
    changing a value cannot affect another rule, a later target, candidate
    reanalysis, or the caller's original data.

    Values are rebuilt rather than cloned. A clone would keep members added with
    Add-Member, and those can leak across the whole process. For example, the
    boxed $true is shared process-wide, so a member attached to it would appear on
    every $true. Rebuilding strings, Booleans, and numbers drops those members.

    Only plain data is accepted, which keeps context serializable and prevents
    rules from receiving live objects such as script blocks or file handles.
    Copied dictionaries are case-insensitive hashtables, so rule IDs and setting
    names can be looked up without matching their casing.

.PARAMETER Value
    The value to copy.

.PARAMETER Path
    Names the root of Value in error messages; defaults to 'Value'. For example, 'Configuration'
    reports an invalid nested value as 'Configuration.Rules[0]'.

.EXAMPLE
    $Original = @{ Extra = @{ Values = @(1, 2) } }
    $Copy = Copy-NitpickPlainData -Value $Original
    $Copy.Extra.Values[0] = 9
    $Original.Extra.Values[0]

    Returns 1: changing a nested array in the copy leaves the original unchanged.

.EXAMPLE
    $Shared = @{ Enabled = $true }
    $Copy = Copy-NitpickPlainData -Value @{ Left = $Shared; Right = $Shared }
    $Copy.Left.Enabled = $false
    $Copy.Right.Enabled

    Returns True: repeated references produce independent copies, not a shared
    mutable subgraph. A reference back to an active ancestor would instead error.

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function Copy-NitpickPlainData {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowNull()]
        [object] $Value,

        [string] $Path = 'Value'
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
                    throw [ArgumentException]::new("Cyclic value at '$ItemPath'.")
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
            "Unsupported plain data type '$($Type.FullName)' at '$ItemPath'."
        )
    }

    try {
        $Copy = Copy-Value -Item $Value -ItemPath $Path
        return ,$Copy
    } catch {
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $_.Exception,
            'NitpickInvalidPlainData',
            [ErrorCategory]::InvalidData,
            $Path
        ))
    }
}
