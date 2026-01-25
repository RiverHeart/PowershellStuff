
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
        [Parameter(ParameterSetName='SingleInit',Position=0)]
        [Parameter(ParameterSetName='DoubleInit',Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $NameOrWidth = '__Nameless__',

        [Parameter(ParameterSetName='DoubleInit',Position=1)]
        [ValidateNotNullOrEmpty()]
        [string] $Width = 'Auto',

        [Parameter(Mandatory,ParameterSetName='Bare',Position=0)]
        [Parameter(Mandatory,ParameterSetName='SingleInit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='DoubleInit',Position=2)]
        [ScriptBlock] $ScriptBlock
    )

    # NOTE:
    # This is super hacky but I really want the syntax to support setting width without name.
    # Because a string is castable to `GridLength`, powershell can't resolve the parameter set
    # since position=0 looks the same as `$Name` if user passes 'Auto' or '*'.
    # With this in mind, check if `$Name` is a valid `GridLength` value when `$Width` isn't
    # explicitly passed.
    $NumberOutvar = $null
    if ($NameOrWidth -and $Width) {
        # Clearly width is already provided
        $Name = $NameOrWidth
    }
    # Check if $Name is a valid GridLength
    elseif (
        $NameOrWidth -in @('*', 'Auto', 'Fit') -or
        $NameOrWidth -ilike 'Expand*' -or
        [int]::TryParse($NameOrWidth, [ref] $NumberOutvar)
    ) {
        $Width = $NameOrWidth
    }
    # $Name was not a valid GridLength
    else {
        $Name = $NameOrWidth
    }

    if ($Width -ilike 'Expand*') {
        $Width = $Width -replace 'Expand', '*'
    } elseif ($Width -eq 'Fit') {
        $Width = $Width -replace 'Fit', 'Auto'
    }

    $MemberDefinitions = @(
        @{ MemberType = 'NoteProperty'; Name = 'Children'; Value = [System.Collections.Generic.List[object]]::new() }
    )

    try {
        $WPFObject = [System.Windows.Controls.ColumnDefinition] @{
            Name = $Name
            Width = $Width
        }
        if ($Name -ne '__Nameless__') {
            $WPFObject.Name = $Name
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
    $Parent = $PSCmdlet.GetVariableValue('self')
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Update-WPFObject $Parent.Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    $WPFObject.Children = Update-WPFObject $WPFObject $ScriptBlock -PassThru

    # Don't bother returning an object if we attached to the parent.
    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
