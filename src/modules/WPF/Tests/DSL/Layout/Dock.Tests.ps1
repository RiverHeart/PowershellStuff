Describe 'Dock' -Tag 'Dock' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should set DockPanel.Dock on explicit input object' {
        $Item = New-Object -TypeName System.Windows.Controls.Primitives.StatusBarItem

        Dock Right -InputObject $Item

        [System.Windows.Controls.DockPanel]::GetDock($Item) | Should -Be ([System.Windows.Controls.Dock]::Right)
    }

    It 'Should set DockPanel.Dock using current DSL context object' {
        $Id = [guid]::NewGuid().ToString('N')
        $WindowName = "Window_$Id"
        $ItemName = "StatusItem_$Id"

        $null = Window $WindowName {
            StatusBar {
                StatusBarItem $ItemName {
                    Dock Right
                    Label "StatusLabel_$Id" {
                        $this.Content = 'Ready'
                    }
                }
            }
        }

        $Item = Reference $ItemName
        [System.Windows.Controls.DockPanel]::GetDock($Item) | Should -Be ([System.Windows.Controls.Dock]::Right)
    }

    It 'Should support Top and Bottom values' {
        $Item = New-Object -TypeName System.Windows.Controls.Primitives.StatusBarItem

        Dock Top -InputObject $Item
        [System.Windows.Controls.DockPanel]::GetDock($Item) | Should -Be ([System.Windows.Controls.Dock]::Top)

        Dock Bottom -InputObject $Item
        [System.Windows.Controls.DockPanel]::GetDock($Item) | Should -Be ([System.Windows.Controls.Dock]::Bottom)
    }

    It 'Should skip block when invoked with negative prefix' {
        $Item = New-Object -TypeName System.Windows.Controls.Primitives.StatusBarItem
        [System.Windows.Controls.DockPanel]::SetDock($Item, [System.Windows.Controls.Dock]::Top)

        {
            -Dock Right -InputObject $Item
        }.Invoke()

        [System.Windows.Controls.DockPanel]::GetDock($Item) | Should -Be ([System.Windows.Controls.Dock]::Top)
    }
}
