using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Creates a present value calculator.

.DESCRIPTION
    Creates a present value calculator.

    Reimplementation of the Microsoft example.

.LINK
    https://learn.microsoft.com/en-us/archive/msdn-magazine/2011/july/msdn-magazine-windows-powershell-with-wpf-secrets-to-building-a-wpf-application-in-windows-powershell
#>


# Change to the script directory if we're not in it.
if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$ErrorActionPreference = 'Stop'
$DebugPreference = 'Continue'

Import-Module ../.. -Force

Import "$PSScriptRoot/PresentValueCalculator.Styles.ps1"

$Amount = 1000
$Interest = 0.46
$NumberOfYears = 2

<#
.SYNOPSIS
    Calculates the present value of an amount given an interest rate and number of years.

.EXAMPLE
    Get-PresentValue -Amount 1000 -Interest 0.46 -NumberOfYears 2

.EXAMPLE
    1000..1010 | Get-PresentValue -Interest 0.46 -NumberOfYears 2
#>
function Get-PresentValue {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotnullOrEmpty()]
        [double] $Amount,

        [Parameter(Mandatory)]
        [ValidateNotnullOrEmpty()]
        [double] $Interest,

        [int] $NumberOfYears
    )

    process {
        $Result =[PSCustomObject] @{
            Amount = $Amount
            Interest = $Interest
            NumberOfYears = $NumberOfYears
            PresentValue = [Math]::Round($Amount / [Math]::Pow((1 + $Interest), $NumberOfYears), 2)
        }

        Write-Output $Result
    }
}

function Get-Range {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateNotnullOrEmpty()]
        [double] $Start,

        [Parameter(Mandatory)]
        [ValidateNotnullOrEmpty()]
        [double] $End,

        [int] $Step = 1
    )

    process {
        for ($i = $Start; $i -le $End; $i += $Step) {
            Write-Output $i
        }
    }
}


App 'PresentValueCalculator' {
    $this.Title = 'Present Value Calculator'
    $this.SizeToContent = 'WidthAndHeight'
    $this.ResizeMode = 'NoResize'
    $this.WindowStartupLocation = 'CenterScreen'

    State @{
        Amounts = 1000..1010
        Results = @()
    }

    Content {
        HStackPanel {
            $this.Margin = '10'

            VStackPanel {
                Label { $this.Content = 'Amount:' }
                TextBox 'AmountTextBox' {
                    $this.Text = $Amount
                }

                Label { $this.Content = 'Interest:' }
                TextBox 'InterestTextBox' {
                    $this.Text = $Interest
                }

                Label { $this.Content = 'Number of Years:' }
                TextBox 'NumberOfYearsTextBox' {
                    $this.Text = $NumberOfYears
                }

                Label { $this.Content = 'Max' }
                TextBox 'MaxTextBox' {
                    # Keep defaults in ascending order so Calculate produces visible rows.
                    $this.Text = 2000
                }

                Label { $this.Content = 'Step' }
                TextBox 'StepTextBox' {
                    $this.Text = 100
                }

                Button 'CalculateButton' {
                    $this.Content = 'Calculate'
                    $this.Margin = '0,10,0,0'
                    $this.Add_Click({
                        Write-Debug "Calculating present value for Amount=$Amount, Interest=$Interest, NumberOfYears=$NumberOfYears"
                        $Amount = [double] (Reference AmountTextBox -Property 'Text')
                        $Interest = [double] (Reference InterestTextBox -Property 'Text')
                        $NumberOfYears = [int] (Reference NumberOfYearsTextBox -Property 'Text')
                        $Max = [double] (Reference MaxTextBox -Property 'Text')
                        $Step = [Math]::Abs([int] (Reference StepTextBox -Property 'Text'))

                        if ($Step -lt 1) {
                            $Step = 1
                        }

                        if ($Max -lt $Amount) {
                            Write-Debug "Max was less than Amount; clamping Max to Amount so at least one row is produced."
                            $Max = $Amount
                        }

                        $AppState = Reference PresentValueCalculator -Property 'Tag'
                        $AppState.Results = @(
                            Get-Range -Start $Amount -End $Max -Step $Step |
                            Get-PresentValue -Interest $Interest -NumberOfYears $NumberOfYears
                        )
                    })
                }
            }

            Grid {
                $this.Margin = '20,0,0,0'
                $this.HorizontalAlignment = 'Left'

                Row Fit {
                    Column {
                        Label { $this.Content = 'Results:' }
                    }
                }

                Row Expand {
                    Column {
                        ListView 'ResultsListView' {
                            $this.Margin = '0,10,0,0'
                            $this.Width = 300
                            $this.VerticalAlignment = 'Stretch'

                            Link Results -To ItemsSource

                            GridView {
                                GridViewColumn {
                                    $this.Header = 'Amount'
                                    $this.DisplayMemberBinding = Binding 'Amount'
                                }
                                GridViewColumn {
                                    $this.Header = 'Present Value'
                                    $this.DisplayMemberBinding = Binding 'PresentValue'
                                }
                                GridViewColumn {
                                    $this.Header = 'Interest'
                                    $this.DisplayMemberBinding = Binding 'Interest'
                                }
                                GridViewColumn {
                                    $this.Header = 'Number of Years'
                                    $this.DisplayMemberBinding = Binding 'NumberOfYears'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
