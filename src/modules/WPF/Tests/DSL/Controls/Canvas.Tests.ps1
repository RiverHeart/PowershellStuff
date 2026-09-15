Describe 'Canvas' -Tag 'Canvas' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -Canvas "Board_$Id" {
                Label "Child_$Id" {}
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should auto-attach child controls to the Canvas' {
        $Id = [guid]::NewGuid().ToString('N')
        $WindowName = "Window_$Id"
        $ChildName = "Piece_$Id"

        $null = Window $WindowName {
            Canvas "Board_$Id" {
                Label $ChildName {}
            }
        }

        $Child = Reference $ChildName
        $Child.Parent | Should -BeOfType [System.Windows.Controls.Canvas]
    }
}
