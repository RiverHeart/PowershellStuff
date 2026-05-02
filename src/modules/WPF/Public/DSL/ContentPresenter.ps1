<#
.SYNOPSIS
    Creates a ContentPresenter, or a FrameworkElementFactory for one inside a Template.

.DESCRIPTION
    Inside a Template block, produces a FrameworkElementFactory typed to
    ContentPresenter and appends it to the enclosing factory parent.

    Outside a Template block, creates a live ContentPresenter instance.

.EXAMPLE
    Template {
        Border 'TemplateBorder' {
            ContentPresenter {
                Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
                Setter VerticalAlignment ([VerticalAlignment]::Stretch)
                Setter SnapsToDevicePixels $true
            }
        }
    }
#>
function ContentPresenter {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.ContentPresenter], [System.Windows.FrameworkElementFactory])]
    param(
        [Parameter(Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $InFactoryContext = $PSCmdlet.GetVariableValue('WPFFactoryContext') -eq $true

    if ($InFactoryContext) {
        $Factory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.ContentPresenter])

        $Parent = $PSCmdlet.GetVariableValue('this')
        if ($Parent) {
            Add-WPFObject $Parent $Factory
        }

        if ($ScriptBlock) {
            Update-WPFObject $Factory $ScriptBlock
        }

        if (-not $Parent) { return $Factory }
        return
    }

    $Presenter = [System.Windows.Controls.ContentPresenter]::new()

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Add-WPFObject $Parent $Presenter
    }

    if ($ScriptBlock) {
        Update-WPFObject $Presenter $ScriptBlock
    }

    if (-not $Parent) { return $Presenter }
}
