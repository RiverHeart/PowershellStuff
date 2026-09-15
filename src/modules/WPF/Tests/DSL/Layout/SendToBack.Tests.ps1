Describe 'SendToBack' -Tag 'SendToBack' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should set ZIndex below all siblings on explicit input object' {
        $Parent = [System.Windows.Controls.Canvas]::new()
        $A = New-Object -TypeName System.Windows.Controls.Label
        $B = New-Object -TypeName System.Windows.Controls.Label
        $Parent.Children.Add($A) | Out-Null
        $Parent.Children.Add($B) | Out-Null
        [System.Windows.Controls.Panel]::SetZIndex($A, 5)
        [System.Windows.Controls.Panel]::SetZIndex($B, 2)

        SendToBack -InputObject $A

        [System.Windows.Controls.Panel]::GetZIndex($A) | Should -Be 1
    }

    It 'Should default to ZIndex 0 when there are no siblings' {
        $Parent = [System.Windows.Controls.Canvas]::new()
        $Item = New-Object -TypeName System.Windows.Controls.Label
        $Parent.Children.Add($Item) | Out-Null

        SendToBack -InputObject $Item

        [System.Windows.Controls.Panel]::GetZIndex($Item) | Should -Be 0
    }

    It 'Should error when the object has no Panel parent' {
        $Item = New-Object -TypeName System.Windows.Controls.Label

        { SendToBack -InputObject $Item -ErrorAction Stop } |
            Should -Throw '*must be attached to a Panel*'
    }

    It 'Should set ZIndex using current DSL context object' {
        $Id = [guid]::NewGuid().ToString('N')
        $WindowName = "Window_$Id"
        $FrontName = "Front_$Id"
        $BackName = "Back_$Id"

        $null = Window $WindowName {
            Canvas "Board_$Id" {
                Label $FrontName {
                    CanvasPosition -Left 0 -Top 0 -ZIndex 5
                }
                Label $BackName {
                    CanvasPosition -Left 0 -Top 0
                    SendToBack
                }
            }
        }

        $Back = Reference $BackName
        [System.Windows.Controls.Panel]::GetZIndex($Back) | Should -Be 4
    }

    It 'Should skip block when invoked with negative prefix' {
        $Parent = [System.Windows.Controls.Canvas]::new()
        $Item = New-Object -TypeName System.Windows.Controls.Label
        $Parent.Children.Add($Item) | Out-Null
        [System.Windows.Controls.Panel]::SetZIndex($Item, 3)

        {
            -SendToBack -InputObject $Item
        }.Invoke()

        [System.Windows.Controls.Panel]::GetZIndex($Item) | Should -Be 3
    }
}
