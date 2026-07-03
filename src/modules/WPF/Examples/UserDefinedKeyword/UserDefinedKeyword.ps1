using namespace System.Windows
using namespace System.Windows.Controls

# Change to the script directory if we're not in it.
if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

# Register completion so $this inside Badge resolves like a Border.
Register-WPFCompletionType -Name Badge -Type ([System.Windows.Controls.Border])

function Badge {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [OutputType([void], [System.Windows.Controls.Border])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $Badge = [System.Windows.Controls.Border]::new()
    $Badge.Padding = '10,4,10,4'
    $Badge.Margin = '0,0,0,8'
    $Badge.CornerRadius = '12'
    $Badge.Background = 'LightSteelBlue'
    $Badge.HorizontalAlignment = 'Left'
    $Badge.VerticalAlignment = 'Top'

    if ($Name -ne '__Nameless__') {
        $Badge.Name = $Name
        Register-WPFObject $Name $Badge
    }

    Add-WPFType -InputObject $Badge -Type Control

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Add-WPFObject -InputObject $Parent -ChildObjects $Badge
    }

    $PSVars = New-WPFVariableList -InputObject $Badge
    $ChildObjects = @($ScriptBlock.InvokeWithContext($null, $PSVars))
    foreach ($Child in $ChildObjects) {
        if ($null -eq $Child) {
            continue
        }

        if ($Child -is [System.Windows.Data.BindingExpressionBase]) {
            continue
        }

        Add-WPFObject -InputObject $Badge -ChildObjects $Child
    }

    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $Parent) {
        return $Badge
    }
}

Window 'Window' {
    $this.Title = 'Custom Keyword Example'
    $this.Width = 360
    $this.Height = 220
    $this.WindowStartupLocation = 'CenterScreen'

    StackPanel 'Root' {
        $this.Margin = '16'

        TextBlock 'TitleText' {
            $this.Text = 'Badge keyword built from Border'
            $this.Margin = '0,0,0,12'
            $this.FontSize = 18
            $this.FontWeight = 'SemiBold'
        }

        Badge 'ReadyBadge' {
            $this.Child = [System.Windows.Controls.TextBlock]::new()
            $this.Child.Text = 'Ready'
            $this.Background = 'PaleGreen'
        }

        Badge 'BusyBadge' {
            $this.Child = [System.Windows.Controls.TextBlock]::new()
            $this.Child.Text = 'Busy'
            $this.Background = 'Moccasin'
        }

        Button 'InspectButton' {
            $this.Content = 'Inspect Ready Badge'
            On 'Click' {
                $ReadyBadge = Reference ReadyBadge
                [System.Windows.MessageBox]::Show(
                    "ReadyBadge type names:`n$($ReadyBadge.PSTypeNames -join [Environment]::NewLine)",
                    'Badge Metadata'
                ) | Out-Null
            }
        }
    }
} | Show-WPFWindow
