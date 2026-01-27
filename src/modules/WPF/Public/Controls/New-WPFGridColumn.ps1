
<#
.SYNOPSIS
    Creates a WPF ColumnDefinition object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.columndefinition
#>
function New-WPFGridColumn {
    [CmdletBinding(DefaultParameterSetName='Bare')]
    [Alias('Column', 'Cell', 'New-WPFColumnDefinition')]
    [OutputType([System.Windows.Controls.ColumnDefinition])]
    param(
        [object] $Init1,
        [object] $Init2,
        [object] $Init3,
        [switch] $NoAutoAttach
    )

    # Defaults
    $Name = '__NamelessColumn__'
    $Width = 'Auto'

    # I hate this but I refuse to compromise on the syntax and since
    # Powershell doesn't support a strictly typed parameter sets there's
    # no way to represent all 3 scenarios using ParameterSet due to implicit casting.
    if ($PSBoundParameters.Count -eq 3) {
        [ValidateNotNullOrEmpty()] [string] $Name = $Init1
        [ValidateNotNullOrEmpty()] [string] $Width = $Init2
        [scriptblock] $ScriptBlock = $Init3
    } elseif ($PSBoundParameters.Count -eq 2) {
        [ValidateNotNullOrEmpty()] [string] $NameOrWidth = $Init1
        [scriptblock] $ScriptBlock = $Init2

        $NumberOutvar = $null
        # Check if $Name is a valid GridLength
        if ($NameOrWidth -in @('*', 'Auto', 'Fit') -or
            $NameOrWidth -ilike 'Expand*' -or
            [int]::TryParse($NameOrWidth, [ref] $NumberOutvar)
        ) {
            $Width = $NameOrWidth
        }
        # $Name was not a valid GridLength
        else {
            $Name = $NameOrWidth
        }
    } elseif ($PSBoundParameters.Count -eq 1) {
        [scriptblock] $ScriptBlock = $Init1
    } else {
        throw "Bad"
    }

    # Support intuitive names
    if ($Width -ilike 'Expand*') {
        # Convert (Expand -> * && 'Expand*2' -> 2*)
        $Width = $Width -replace 'Expand[*]?(\d)?', '$1*'
    } elseif ($Width -eq 'Fit') {
        $Width = $Width -replace 'Fit', 'Auto'
    }

    $MemberDefinitions = @(
        # Actual `Parent` property would be the grid so compromising on the name.
        @{ MemberType = 'NoteProperty'; Name = 'GridParent'; Value = $null }
        @{ MemberType = 'NoteProperty'; Name = 'Children'; Value = [System.Collections.Generic.List[object]]::new() }
    )

    try {
        $WPFObject = [System.Windows.Controls.ColumnDefinition] @{
            Name = $Name
            Width = $Width
        }
        if ($Name -ne '__NamelessColumn__') {
            Register-WPFObject $Name $WPFObject
        }
        Add-WPFType $WPFObject 'GridDefinition'
        foreach($MemberDefinition in $MemberDefinitions) {
            $WPFObject | Add-Member @MemberDefinition
        }
    } catch {
        Write-Error "Failed to create (ColumnDefinition) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $ParentRow = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $ParentRow -and -not $WPFObject.ParentRow) {
        Write-Debug "Beginning auto-attach for $Name (ColumnDefinition)"
        Update-WPFObject $ParentRow $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (ColumnDefinition)"
    Update-WPFObject $WPFObject $ScriptBlock

    # Don't bother returning an object if we attached to the parent.
    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
