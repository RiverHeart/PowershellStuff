<#
.SYNOPSIS
    Copies one supported value for use in a Task Snapshot.

.DESCRIPTION
    Recursively reconstructs PowerShell data values so separate task runspaces
    do not share mutable object references. Live object references are rejected.

.PARAMETER InputObject
    The value to copy.

.PARAMETER Name
    The TaskFile-visible name used when reporting unsupported values.

.EXAMPLE
    Copy-PleaseWorkSnapshotValue -InputObject @{ Name = 'build' } -Name Settings

    Returns a new hashtable containing a separate copy of each value.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function Copy-PleaseWorkSnapshotValue {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or
        $InputObject -is [char] -or
        $InputObject -is [bool] -or
        $InputObject -is [datetime] -or
        $InputObject -is [datetimeoffset] -or
        $InputObject -is [guid] -or
        $InputObject -is [timespan] -or
        $InputObject -is [uri] -or
        $InputObject -is [enum] -or
        $InputObject.GetType().IsValueType
    ) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $Copy = if (
            $InputObject -is [System.Collections.Specialized.OrderedDictionary]
        ) {
            [System.Collections.Specialized.OrderedDictionary]::new()
        } elseif ($InputObject -is [System.Collections.Hashtable]) {
            $InputObject.Clone()
        } else {
            throw (
                "Task Snapshot value '$Name' has unsupported dictionary type " +
                "'$($InputObject.GetType().FullName)'."
            )
        }
        foreach ($Entry in $InputObject.GetEnumerator()) {
            $CopiedKey = Copy-PleaseWorkSnapshotValue `
                -InputObject $Entry.Key `
                -Name ('{0} key' -f $Name)
            $EntryName = '{0}[{1}]' -f $Name, $Entry.Key
            $CopiedValue = Copy-PleaseWorkSnapshotValue `
                -InputObject $Entry.Value `
                -Name $EntryName
            $Copy[[object] $CopiedKey] = $CopiedValue
        }
        return ,$Copy
    }

    if ($InputObject -is [System.Array]) {
        $Copy = [System.Array]::CreateInstance(
            $InputObject.GetType().GetElementType(),
            $InputObject.Count
        )
        for ($Index = 0; $Index -lt $InputObject.Count; $Index++) {
            $CopiedValue = Copy-PleaseWorkSnapshotValue `
                -InputObject $InputObject[$Index] `
                -Name ('{0}[{1}]' -f $Name, $Index)
            $Copy.SetValue($CopiedValue, $Index)
        }
        return ,$Copy
    }

    if ($InputObject -is [System.Collections.IList]) {
        try {
            $Copy = [System.Activator]::CreateInstance($InputObject.GetType())
        } catch {
            throw (
                "Task Snapshot value '$Name' has unsupported list type " +
                "'$($InputObject.GetType().FullName)'."
            )
        }
        for ($Index = 0; $Index -lt $InputObject.Count; $Index++) {
            $CopiedValue = Copy-PleaseWorkSnapshotValue `
                -InputObject $InputObject[$Index] `
                -Name ('{0}[{1}]' -f $Name, $Index)
            $null = $Copy.Add($CopiedValue)
        }
        return ,$Copy
    }

    $Properties = @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.MemberType -eq 'Property' -or $_.MemberType -eq 'NoteProperty' }
    )
    if ($InputObject -is [pscustomobject] -and $Properties.Count -gt 0) {
        $Copy = [ordered] @{}
        foreach ($Property in $Properties) {
            $PropertyName = '{0}.{1}' -f $Name, $Property.Name
            $Copy[$Property.Name] = Copy-PleaseWorkSnapshotValue `
                -InputObject $Property.Value `
                -Name $PropertyName
        }
        return ,([pscustomobject] $Copy)
    }

    throw "Task Snapshot value '$Name' has unsupported type '$($InputObject.GetType().FullName)'."
}
