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
            PresentValue = $Amount / [Math]::Pow((1 + $Interest), $NumberOfYears)
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
        Grid 'PresentValueCalculatorGrid' {
            Row {
                Column {
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
                }
            }

            Row {
                Column {
                    Label { $this.Content = 'Max' }
                    TextBox 'MaxTextBox' {
                        $this.Text = 500
                    }

                    Label { $this.Content = 'Step' }
                    TextBox 'StepTextBox' {
                        $this.Text = 100
                    }
                }
            }

            Row {
                Column {
                    Button {
                        $this.Content = 'Calculate'
                        $this.Margin = '0,10,0,0'
                        $this.Add_Click({
                            $Amount = Reference AmountTextBox -Property 'Text'
                            $Interest = Reference InterestTextBox -Property 'Text'
                            $NumberOfYears = Reference NumberOfYearsTextBox -Property 'Text'
                            $Max = Reference MaxTextBox -Property 'Text'
                            $Step = Reference StepTextBox -Property 'Text'
                            $AppState = Reference PresentValueCalculator -Property 'Tag'
                            $AppState.Results = @(
                                Get-Range -Start $Amount -End $Max -Step $Step |
                                Get-PresentValue -Interest $Interest -NumberOfYears $NumberOfYears
                            )
                        })
                    }
                }
            }

            Row {
                Column {
                    ListView 'ResultsListView' {
                        $this.Margin = '0,10,0,0'
                        $this.Height = 200
                        $this.Width = 300
                        Link ItemsSource -Property Results

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
} | Show-WPFWindow
