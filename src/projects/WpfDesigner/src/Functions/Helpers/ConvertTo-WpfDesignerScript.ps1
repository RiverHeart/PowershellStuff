using namespace System.Windows.Controls

<#
.SYNOPSIS
    Converts the design surface's placed Labels into runnable WPF DSL script text.

.DESCRIPTION
    When the design surface contains a Window proxy, reads Window properties
    from its associated hidden Window and placed Labels from its default
    content Canvas. Otherwise retains the original flat-Canvas behavior.
#>
function ConvertTo-WpfDesignerScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas
    )

    $WindowModel = $null
    $ContentCanvas = $Canvas
    foreach ($Child in $Canvas.Children) {
        $PropertyTarget = $Child.PSObject.Properties['_WPFDesignerPropertyTarget']
        $ContentRoot = $Child.PSObject.Properties['_WPFDesignerContentRoot']
        if (
            $PropertyTarget -and $PropertyTarget.Value -is [System.Windows.Window] -and
            $ContentRoot -and $ContentRoot.Value -is [System.Windows.Controls.Canvas]
        ) {
            $WindowModel = $PropertyTarget.Value
            $ContentCanvas = $ContentRoot.Value
            break
        }
    }

    $WindowTitle = if ($WindowModel) { [string] $WindowModel.Title } else { 'Window' }
    $EscapedTitle = $WindowTitle -replace "'", "''"

    $Lines = [System.Collections.Generic.List[string]]::new()
    $Lines.Add("Window '$EscapedTitle' {")
    if ($WindowModel) {
        $Lines.Add("    `$this.Width = $($WindowModel.Width)")
        $Lines.Add("    `$this.Height = $($WindowModel.Height)")
    }
    $Lines.Add("    Canvas 'Canvas' {")

    foreach ($Child in $ContentCanvas.Children) {
        if ($Child -isnot [System.Windows.Controls.Label]) {
            continue
        }

        $Left = [System.Windows.Controls.Canvas]::GetLeft($Child)
        $Top = [System.Windows.Controls.Canvas]::GetTop($Child)
        if ([double]::IsNaN($Left)) { $Left = 0 }
        if ([double]::IsNaN($Top)) { $Top = 0 }

        # Single-quoted DSL string, so escape embedded quotes by doubling them.
        $EscapedContent = [string] $Child.Content -replace "'", "''"

        $Lines.Add('        Label {')
        $Lines.Add("            `$this.Content = '$EscapedContent'")
        $Lines.Add("            `$this.Width = $($Child.Width)")
        $Lines.Add("            `$this.Height = $($Child.Height)")
        $Lines.Add("            CanvasPosition -Left $Left -Top $Top")
        $Lines.Add('        }')
    }

    $Lines.Add('    }')
    $Lines.Add('}')

    return ($Lines -join [System.Environment]::NewLine)
}
