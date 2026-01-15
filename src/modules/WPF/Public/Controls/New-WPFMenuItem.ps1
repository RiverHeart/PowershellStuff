<#
.SYNOPSIS
    Creates a WPF MenuItem object.

.DESCRIPTION
    Creates a WPF MenuItem object.

    Supports nested scriptblocks as is standard but also
    a shorthand syntax where the name of each MenuItem is
    separated by a forward slash.

    MenuItem 'NameOne/NameTwo/NameThree' {...}

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.menuitem
#>
function New-WPFMenuItem {
    [Alias('MenuItem')]
    [OutputType([System.Windows.Controls.MenuItem])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        # For strings like '_File/_Exit', split on the first occurence of '/'
        # RemainingNames will be used to create nested MenuItems
        $FirstName, $RemainingNames = $Name.Split('/', 2)

        # Support an alternative, in my opinion more intuitive,
        # accessor syntax: (F)ile
        $FirstName = $FirstName.Replace('(', '_').Replace(')', '')

        # Check if object already exists, if not, create one
        $WPFObject = Get-WPFRegisteredObject $FirstName -ErrorAction Ignore
        if (-not $WPFObject) {
            $WPFObject = [System.Windows.Controls.MenuItem] @{
                Name = $FirstName
                Header = $FirstName
            }
            Register-WPFObject $FirstName $WPFObject
        }

        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$FirstName' (MenuItem) with error: $_"
    }

    # Recurse until we exhaust all names and get the resulsting child items
    # If we're processing RemainingNames, assume that the scriptblock was passed
    # to the deepest MenuItem
    if ($RemainingNames) {
        $ChildObjects = New-WPFMenuItem -Name $RemainingNames -ScriptBlock $ScriptBlock
        Update-WPFObject $WPFObject $ChildObjects
    }
    # Or else see if we got a script block. The last MenuItem should always have one.
    elseif ($ScriptBlock) {
        Update-WPFObject $WPFObject $ScriptBlock
    }
    # Since Scriptblock is mandatory this scenario should never happen.
    else {
        Write-Error "Something unexpected occurred constructing '$FirstName' ($MenuItem)"
    }

    return $WPFObject
}
