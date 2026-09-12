Describe 'CanvasPosition' -Tag 'CanvasPosition' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should set Canvas.Left and Canvas.Top on explicit input object' {
        $Item = New-Object -TypeName System.Windows.Controls.Label

        CanvasPosition -Left 10 -Top 20 -InputObject $Item

        [System.Windows.Controls.Canvas]::GetLeft($Item) | Should -Be 10
        [System.Windows.Controls.Canvas]::GetTop($Item) | Should -Be 20
    }

    It 'Should only set the properties that were supplied' {
        $Item = New-Object -TypeName System.Windows.Controls.Label
        [System.Windows.Controls.Canvas]::SetLeft($Item, 5)

        CanvasPosition -Top 15 -InputObject $Item

        [System.Windows.Controls.Canvas]::GetLeft($Item) | Should -Be 5
        [System.Windows.Controls.Canvas]::GetTop($Item) | Should -Be 15
    }

    It 'Should set Right, Bottom, and ZIndex' {
        $Item = New-Object -TypeName System.Windows.Controls.Label

        CanvasPosition -Right 3 -Bottom 4 -ZIndex 2 -InputObject $Item

        [System.Windows.Controls.Canvas]::GetRight($Item) | Should -Be 3
        [System.Windows.Controls.Canvas]::GetBottom($Item) | Should -Be 4
        [System.Windows.Controls.Panel]::GetZIndex($Item) | Should -Be 2
    }

    It 'Should set Canvas.Left using current DSL context object' {
        $Id = [guid]::NewGuid().ToString('N')
        $WindowName = "Window_$Id"
        $ItemName = "Piece_$Id"

        $null = Window $WindowName {
            Canvas "Board_$Id" {
                Label $ItemName {
                    CanvasPosition -Left 25 -Top 30
                }
            }
        }

        $Item = Reference $ItemName
        [System.Windows.Controls.Canvas]::GetLeft($Item) | Should -Be 25
        [System.Windows.Controls.Canvas]::GetTop($Item) | Should -Be 30
    }

    It 'Should skip block when invoked with negative prefix' {
        $Item = New-Object -TypeName System.Windows.Controls.Label
        [System.Windows.Controls.Canvas]::SetLeft($Item, 1)

        {
            -CanvasPosition -Left 99 -InputObject $Item
        }.Invoke()

        [System.Windows.Controls.Canvas]::GetLeft($Item) | Should -Be 1
    }

    It 'Should error when both Left and Right are supplied' {
        $Item = New-Object -TypeName System.Windows.Controls.Label

        { CanvasPosition -Left 10 -Right 20 -InputObject $Item -ErrorAction Stop } |
            Should -Throw '*Specify either -Left or -Right, not both*'
    }

    It 'Should error when both Top and Bottom are supplied' {
        $Item = New-Object -TypeName System.Windows.Controls.Label

        { CanvasPosition -Top 10 -Bottom 20 -InputObject $Item -ErrorAction Stop } |
            Should -Throw '*Specify either -Top or -Bottom, not both*'
    }
}
