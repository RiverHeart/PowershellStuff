Describe 'Auto-Attach vs Event Handler $this' -Tag 'AutoAttachContext' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Does not auto-attach a control created from a scope with an ambient event-handler $this' {
        InModuleScope WPF {
            # Simulates PowerShell's automatic $this-to-sender binding for WPF
            # event handler delegates: $this ends up set in scope, but
            # WPFAutoAttachContext does not, because only $this is a name
            # PowerShell auto-populates for event handler scriptblocks.
            $Sender = [System.Windows.Controls.Button]::new()
            $this = $Sender

            $NewLabel = Label 'FromHandler' {}

            $NewLabel | Should -Not -Be $null
            $NewLabel.Parent | Should -Be $null
            $Sender.Content | Should -BeNullOrEmpty
        }
    }

    It 'Still auto-attaches declaratively when WPFAutoAttachContext is supplied' {
        InModuleScope WPF {
            $Parent = [System.Windows.Controls.StackPanel]::new()
            $PSVars = New-WPFVariableList -InputObject $Parent

            $Result = {
                Label 'Declarative' {}
            }.InvokeWithContext($null, $PSVars)

            @($Result).Count | Should -Be 0
            $Parent.Children | Should -HaveCount 1
            $Parent.Children[0].Name | Should -Be 'Declarative'
        }
    }
}
