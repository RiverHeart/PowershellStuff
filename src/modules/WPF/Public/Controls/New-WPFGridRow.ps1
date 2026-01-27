
<#
.SYNOPSIS
    Creates a WPF RowDefinition object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.rowdefinition
#>
function New-WPFGridRow {
    [CmdletBinding(DefaultParameterSetName='Bare')]
    [Alias('Row', 'New-WPFRowDefinition')]
    [OutputType([System.Windows.Controls.RowDefinition])]
    param(
        [object] $Init1,
        [object] $Init2,
        [object] $Init3,
        [switch] $NoAutoAttach
    )

    # Defaults
    $Name = '__NamelessRow__'
    $Height = 'Auto'

    # I hate this but I refuse to compromise on the syntax and since
    # Powershell doesn't support a strictly typed parameter sets there's
    # no way to represent all 3 scenarios using ParameterSet due to implicit casting.
    if ($PSBoundParameters.Count -eq 3) {
        [ValidateNotNullOrEmpty()] [string] $Name = $Init1
        [ValidateNotNullOrEmpty()] [string] $Height = $Init2
        [scriptblock] $ScriptBlock = $Init3
    } elseif ($PSBoundParameters.Count -eq 2) {
        [ValidateNotNullOrEmpty()] [string] $NameOrHeight = $Init1
        [scriptblock] $ScriptBlock = $Init2

        $NumberOutvar = $null
        # Check if $Name is a valid GridLength
        if ($NameOrHeight -in @('*', 'Auto', 'Fit') -or
            $NameOrHeight -ilike 'Expand*' -or
            [int]::TryParse($NameOrHeight, [ref] $NumberOutvar)
        ) {
            $Height = $NameOrHeight
        }
        # $Name was not a valid GridLength
        else {
            $Name = $NameOrHeight
        }
    } elseif ($PSBoundParameters.Count -eq 1) {
        [scriptblock] $ScriptBlock = $Init1
    } else {
        throw "Bad"
    }

    # Support intuitive names
    if ($Height -ilike 'Expand*') {
        # Convert (Expand -> * && 'Expand*2' -> 2*)
        $Height = $Height -replace 'Expand[*]?(\d)?', '$1*'
    } elseif ($Height -eq 'Fit') {
        $Height = $Height -replace 'Fit', 'Auto'
    }

    $MemberDefinitions = @(
        @{ MemberType = 'NoteProperty'; Name = 'Children'; Value = [System.Collections.Generic.List[object]]::new() }
    )

    try {
        $WPFObject = [System.Windows.Controls.RowDefinition] @{
            Name = $Name
            Height = $Height
        }
        if ($Name -ne '__NamelessRow__') {
            Register-WPFObject $Name $WPFObject
        }
        Add-WPFType $WPFObject 'GridDefinition'
        foreach($MemberDefinition in $MemberDefinitions) {
            $WPFObject | Add-Member @MemberDefinition
        }
    } catch {
        Write-Error "Failed to create '(RowDefinition) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Write-Debug "Beginning auto-attach for $Name (RowDefinition)"
        Update-WPFObject $Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (RowDefinition)"
    Update-WPFObject $WPFObject $ScriptBlock

    # Don't bother returning an object if we attached to the parent.
    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
