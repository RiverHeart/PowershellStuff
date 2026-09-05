using namespace System.Windows.Controls

<#
.SYNOPSIS
    Converts the design surface's placed Labels into runnable WPF DSL script text.

.DESCRIPTION
    Walks the Canvas's children, skipping anything that isn't a placed Label
    (for example, the resize handle Thumb), and emits a Window/Canvas/Label
    DSL block that reconstructs the current design when run.
#>
function ConvertTo-WpfDesignerScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas] $Canvas
    )

    $Lines = [System.Collections.Generic.List[string]]::new()
    $Lines.Add("Window 'Window' {")
    $Lines.Add("    Canvas 'Canvas' {")

    foreach ($Child in $Canvas.Children) {
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
