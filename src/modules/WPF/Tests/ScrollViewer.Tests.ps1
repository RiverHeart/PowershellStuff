Describe 'ScrollViewer' -Tag 'ScrollViewer' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -ScrollViewer "Viewer_$Id" {
                Label "Child_$Id" {}
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should support factory mode inside a template with PART_ContentHost' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "TextBoxTemplate_$Id"
        $TextBox = [System.Windows.Controls.TextBox]::new()

        Style $StyleName TextBox {
            Template {
                Border 'InputChrome' {
                    ScrollViewer 'PART_ContentHost' {
                        Setter Margin '2,2,2,2'
                    }
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $TextBox
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $TextBox.ApplyTemplate() | Out-Null
        $ContentHost = $TextBox.Template.FindName('PART_ContentHost', $TextBox)

        $ContentHost | Should -Not -BeNullOrEmpty
        $ContentHost.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Controls.ScrollViewer'
    }
}
