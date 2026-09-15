Describe 'TextBlock' -Tag 'TextBlock' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $Result = {
            -TextBlock "TextBlock_$Id" {
                $this.Text = "Hello"
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }

    It 'Should support factory mode inside a template' {
        $Id = [guid]::NewGuid().ToString('N')
        $StyleName = "ButtonTextTemplate_$Id"
        $Button = [System.Windows.Controls.Button]::new()

        Style $StyleName Button {
            Template {
                Border 'TemplateBorder' {
                    TextBlock 'TemplateText' {
                        Text: 'Hello'
                    }
                }
            }
        }

        $Vars = New-WPFVariableList -InputObject $Button
        { UseStyle $StyleName }.InvokeWithContext($null, $Vars) | Out-Null

        $Button.ApplyTemplate() | Out-Null
        $TemplateText = $Button.Template.FindName('TemplateText', $Button)

        $TemplateText | Should -Not -BeNullOrEmpty
        $TemplateText.GetType().FullName | Should -Be -ExpectedValue 'System.Windows.Controls.TextBlock'
        $TemplateText.Text | Should -Be -ExpectedValue 'Hello'
    }
}
