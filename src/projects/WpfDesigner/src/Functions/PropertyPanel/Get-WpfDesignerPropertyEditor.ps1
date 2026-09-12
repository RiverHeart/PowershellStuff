using namespace System.Windows.Controls

<#
.SYNOPSIS
    Builds a Label + input control pair for one property panel row.

.DESCRIPTION
    Given a descriptor from Get-WpfDesignerPropertyDescriptor, constructs the
    matching editor control for its EditorKind and two-way binds it to the
    property on Target. Controls are constructed directly via .NET rather
    than the DSL keyword functions, since this runs outside a declarative DSL
    tree and not every control type has a DSL keyword (CheckBox) or supports
    auto-attach suppression (TextBox).

    DataContext is set on each input control directly, before BindProperty
    runs, rather than left to inherit once the row is attached to the panel:
    a Binding created against a still-null (or not-yet-set) DataContext on an
    unparented element stays Unattached even after DataContext is assigned
    later - it only activates reliably when the element is already part of a
    live visual tree, which these rows aren't yet at construction time.
#>
function Get-WpfDesignerPropertyEditor {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Descriptor,

        [Parameter(Mandatory)]
        [object] $Target
    )

    $Label = [System.Windows.Controls.TextBlock]::new()
    $Label.Text = $Descriptor.Name
    $Label.Margin = 0, 0, 0, 2

    $Input = switch ($Descriptor.EditorKind) {
        'Text' {
            $TextBox = [System.Windows.Controls.TextBox]::new()
            $TextBox.DataContext = $Target
            BindProperty -InputObject $TextBox Text $Descriptor.Name -TwoWay
            Add-WpfDesignerEnterCommit -InputObject $TextBox
            $TextBox
        }
        'Number' {
            $TextBox = [System.Windows.Controls.TextBox]::new()
            $TextBox.DataContext = $Target
            if ($Descriptor.PropertyType -eq [double]) {
                $ConvertNumber = {
                    param($Value)

                    if ([double]::IsPositiveInfinity($Value)) { return 'None' }
                    return $Value
                }
                $ConvertNumberBack = {
                    param($Value)

                    if ($Value -is [string] -and $Value.Trim() -ieq 'None') {
                        return [double]::PositiveInfinity
                    }
                    return $Value
                }
                $ConfigureBinding = {
                    $this.Converter = New-WPFValueConverter $ConvertNumber $ConvertNumberBack
                }.GetNewClosure()

                BindProperty -InputObject $TextBox Text $Descriptor.Name -TwoWay -ScriptBlock $ConfigureBinding
            } else {
                BindProperty -InputObject $TextBox Text $Descriptor.Name -TwoWay
            }
            Add-WpfDesignerEnterCommit -InputObject $TextBox
            $TextBox
        }
        'Bool' {
            $CheckBox = [System.Windows.Controls.CheckBox]::new()
            $CheckBox.Content = $Descriptor.Name
            $CheckBox.DataContext = $Target
            BindProperty -InputObject $CheckBox IsChecked $Descriptor.Name -TwoWay
            $CheckBox
        }
        'Enum' {
            $ComboBox = [System.Windows.Controls.ComboBox]::new()
            $ComboBox.DataContext = $Target
            $ComboBox.ItemsSource = [System.Enum]::GetValues($Descriptor.PropertyType)
            BindProperty -InputObject $ComboBox SelectedItem $Descriptor.Name -TwoWay
            $ComboBox
        }
        default {
            throw "Get-WpfDesignerPropertyEditor: Unrecognized EditorKind '$($Descriptor.EditorKind)'."
        }
    }
    $Input.Margin = 0, 0, 0, 8
    $Elements = if ($Descriptor.EditorKind -eq 'Bool') {
        @($Input)
    } else {
        @($Label, $Input)
    }

    [pscustomobject] @{
        Label    = $Label
        Input    = $Input
        Elements = $Elements
    }
}

