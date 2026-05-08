function Get-WPFObjectSpec {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [switch] $Ensure
    )

    $SpecProperty = $InputObject.PSObject.Properties['WPFSpec']
    if ($SpecProperty) {
        return $SpecProperty.Value
    }

    if ($Ensure) {
        $Spec = [ordered] @{}
        $InputObject | Add-Member -NotePropertyName 'WPFSpec' -NotePropertyValue $Spec
        return $Spec
    }

    return $null
}

function Set-WPFObjectSpec {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Value
    )

    $Spec = Get-WPFObjectSpec -InputObject $InputObject -Ensure
    $Spec[$Name] = $Value
    return $Spec
}

function Update-WPFObjectSpec {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    $Spec = Get-WPFObjectSpec -InputObject $InputObject
    if (-not $Spec) {
        return
    }

    if ($Spec.Contains('Command') -and $InputObject.PSObject.Properties['Command']) {
        $InputObject.Command = $Spec['Command']
    }
}
