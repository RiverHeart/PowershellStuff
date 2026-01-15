<#
.SYNOPSIS
    Creates a WPF Menu object.

.NOTES
    I would like to find a way to support this simplified syntax
    which omits the DockPanel and uses path separators to reduce the
    nesting. This assumes that the scriptblock for a menuitem is always
    going to be a scriptblock for Execute or an OnClick handler.
    Unfortunately there doesn't seem to be a great way of supporting
    Target/CanExecute with this...

    MenuBar 'Menu' {
        $self.Height = 25

        MenuItem '_File/_Open' {
            Command
        }
        MenuItem '_File/_Exit' {
            Write-Host "Barfu"
        }

        MenuItem '_Help/_Abount' {
            Write-Host "Zanzibar"
        }
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.menu
#>
function New-WPFMenu {
    [Alias('Menu')]
    [OutputType([System.Windows.Controls.Menu])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.Menu] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Menu) with error: $_"
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Update-WPFObject $WPFObject $ScriptBlock
    return $WPFObject
}
