<#
.SYNOPSIS
    Creates a data template for a DataGrid column header with a total value and label.

.DESCRIPTION
    Builds a DataTemplate containing a StackPanel with two right-aligned TextBlocks:
    - A bold, larger total value bound to a source property
    - A gray, smaller label below it

    This is useful for displaying aggregate values (like total CPU usage) in column headers.

.PARAMETER TotalPropertyPath
    The binding path to the total value property (e.g., 'TotalCpuPercent')

.PARAMETER Label
    The label text to display below the total

.PARAMETER ValueConverter
    Optional scriptblock to convert the total value for display. Receives $Value as parameter.

.EXAMPLE
    $template = New-ColumnHeaderTemplate -TotalPropertyPath 'TotalCpuPercent' -Label 'CPU' -ValueConverter {
        param($Value)
        if ($null -eq $Value) { '0.0%' } else { '{0:N1}%' -f [double]$Value }
    }
#>
function New-ColumnHeaderTemplate {
    [CmdletBinding()]
    [OutputType([System.Windows.DataTemplate])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $TotalPropertyPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Label,

        [Parameter()]
        [scriptblock] $ValueConverter
    )

    # Build the entire tree using FrameworkElementFactory
    # Create the StackPanel factory
    $panelFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.StackPanel])
    $panelFactory.SetValue([System.Windows.Controls.StackPanel]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Right)

    # Create the total value TextBlock factory
    $totalBlockFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.TextBlock])
    $totalBlockFactory.SetValue([System.Windows.Controls.TextBlock]::FontWeightProperty, [System.Windows.FontWeights]::Bold)
    $totalBlockFactory.SetValue([System.Windows.Controls.TextBlock]::FontSizeProperty, [double]14)
    $totalBlockFactory.SetValue([System.Windows.Controls.TextBlock]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Right)
    $totalBlockFactory.SetValue([System.Windows.Controls.TextBlock]::TextAlignmentProperty, [System.Windows.TextAlignment]::Right)

    # Create and set the binding on the factory
    # Bind to Window.DataContext.<PropertyPath> so totals track State through standard WPF context.
    $bindingPath = "DataContext.$TotalPropertyPath"
    $binding = [System.Windows.Data.Binding]::new($bindingPath)
    $binding.RelativeSource = [System.Windows.Data.RelativeSource]::new([System.Windows.Data.RelativeSourceMode]::FindAncestor, [System.Windows.Window], 1)

    Write-Debug ("TaskManager header template binding configured: Path='{0}', Label='{1}'" -f $bindingPath, $Label)

    if ($ValueConverter) {
        $binding.Converter = New-WPFValueConverter $ValueConverter
    }

    $totalBlockFactory.SetBinding([System.Windows.Controls.TextBlock]::TextProperty, $binding)
    $panelFactory.AppendChild($totalBlockFactory)

    # Create the label TextBlock factory
    $labelBlockFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.TextBlock])
    $labelBlockFactory.SetValue([System.Windows.Controls.TextBlock]::TextProperty, $Label)
    $labelBlockFactory.SetValue([System.Windows.Controls.TextBlock]::FontSizeProperty, [double]10)
    $labelBlockFactory.SetValue([System.Windows.Controls.TextBlock]::ForegroundProperty, [System.Windows.Media.Brushes]::Gray)
    $labelBlockFactory.SetValue([System.Windows.Controls.TextBlock]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Right)
    $labelBlockFactory.SetValue([System.Windows.Controls.TextBlock]::TextAlignmentProperty, [System.Windows.TextAlignment]::Right)
    $panelFactory.AppendChild($labelBlockFactory)

    # Create and return the DataTemplate
    $template = [System.Windows.DataTemplate]::new()
    $template.VisualTree = $panelFactory

    return $template
}

