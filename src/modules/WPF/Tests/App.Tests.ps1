Describe 'App' -Tag 'App' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should return a window with an app root when no parent context exists' {
        $Id = [guid]::NewGuid().ToString('N')

        $App = App "App_$Id" {
            $this.Title = 'App Test'
        }

        $App | Should -BeOfType [System.Windows.Window]
        $App.Content | Should -BeOfType [System.Windows.Controls.DockPanel]
        $App.Title | Should -Be 'App Test'
        $ContentHost = @($App.Content.Children | Where-Object { $_ -is [System.Windows.Controls.StackPanel] })
        $ContentHost | Should -HaveCount 1
        $ContentHost[0].Margin.Left | Should -Be 16
        $ContentHost[0].Margin.Top | Should -Be 16
        $ContentHost[0].Margin.Right | Should -Be 16
        $ContentHost[0].Margin.Bottom | Should -Be 16
    }

    It 'Should route root-level controls into the content host, dock the menu, and dock the status bar' {
        $Id = [guid]::NewGuid().ToString('N')

        $App = App "App_$Id" {
            $this.Title = 'App Menu Test'

            MenuItem "File_$Id/Open_$Id" { }

            Button "Button_$Id" {
                $this.Content = 'Open'
            }

            StatusBar "StatusBar_$Id" {
                TextBlock "Ready_$Id" {
                    $this.Text = 'Ready'
                }
            }
        }

        $App.Content | Should -BeOfType [System.Windows.Controls.DockPanel]
        $App.Content.Children | Should -HaveCount 3

        $RootMenu = @($App.Content.Children | Where-Object { $_ -is [System.Windows.Controls.Menu] })
        $RootMenu | Should -HaveCount 1
        [System.Windows.Controls.DockPanel]::GetDock($RootMenu[0]) | Should -Be 'Top'

        $RootStatusBar = @($App.Content.Children | Where-Object { $_ -is [System.Windows.Controls.Primitives.StatusBar] })
        $RootStatusBar | Should -HaveCount 1
        [System.Windows.Controls.DockPanel]::GetDock($RootStatusBar[0]) | Should -Be 'Bottom'

        $ContentHost = @($App.Content.Children | Where-Object { $_ -is [System.Windows.Controls.StackPanel] })
        $ContentHost | Should -HaveCount 1
        $ContentHost[0].Children | Should -HaveCount 1
        $ContentHost[0].Children[0] | Should -BeOfType [System.Windows.Controls.Button]
        $ContentHost[0].Children[0].Name | Should -Be "Button_$Id"

        $RootMenu[0].Items | Should -HaveCount 1
        $RootMenu[0].Items[0] | Should -BeOfType [System.Windows.Controls.MenuItem]

        $RootStatusBar[0].Items | Should -HaveCount 1
        $RootStatusBar[0].Items[0] | Should -BeOfType [System.Windows.Controls.TextBlock]
    }

    It 'Should route Content blocks into the app content host' {
        $Id = [guid]::NewGuid().ToString('N')

        $App = App "App_$Id" {
            Content {
                Button "ContentButton_$Id" {
                    $this.Content = 'Inside content block'
                }
            }
        }

        $ContentHost = @($App.Content.Children | Where-Object { $_ -is [System.Windows.Controls.StackPanel] })
        $ContentHost | Should -HaveCount 1
        $ContentHost[0].Children | Should -HaveCount 1
        $ContentHost[0].Children[0] | Should -BeOfType [System.Windows.Controls.Button]
    }

    It 'Should support nameless StatusBar syntax' {
        $Id = [guid]::NewGuid().ToString('N')

        $App = App "App_$Id" {
            StatusBar {
                TextBlock "StatusText_$Id" {
                    $this.Text = 'Ready'
                }
            }
        }

        $RootStatusBar = @($App.Content.Children | Where-Object { $_ -is [System.Windows.Controls.Primitives.StatusBar] })
        $RootStatusBar | Should -HaveCount 1
        [string]::IsNullOrWhiteSpace($RootStatusBar[0].Name) | Should -BeTrue
        $RootStatusBar[0].Items | Should -HaveCount 1
        $RootStatusBar[0].Items[0] | Should -BeOfType [System.Windows.Controls.TextBlock]
    }
}
