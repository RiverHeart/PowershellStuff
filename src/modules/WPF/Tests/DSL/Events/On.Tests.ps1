Describe 'On' -Tag 'On', 'Category:Events' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    BeforeAll {
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should inject this as the current object when event fires' {
        $global:OnThisName = $null

        $Name = "OnButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            On Click {
                $global:OnThisName = $this.Name
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $global:OnThisName | Should -Be -ExpectedValue $Name

        Remove-Variable -Name OnThisName -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Attaches to the WPFAutoAttachContext object, not an ambient event-handler $this' {
        InModuleScope WPF {
            # Regression: On previously accepted its InputObject via ambient
            # $this instead of the WPFAutoAttachContext/pipeline value, so a
            # stale $this from an enclosing real event handler would win.
            $DecoySender = [pscustomobject]@{ Name = 'DecoySender' }
            Add-Member -InputObject $DecoySender -MemberType ScriptMethod -Name Add_Click -Value {
                throw 'On should not attach to the ambient $this sender'
            }

            $RealParent = [pscustomobject]@{ Name = 'RealParent'; AttachedHandler = $null }
            Add-Member -InputObject $RealParent -MemberType ScriptMethod -Name Add_Click -Value {
                param($Handler)
                $this.AttachedHandler = $Handler
            }

            $this = $DecoySender
            $PSVars = [System.Collections.Generic.List[psvariable]]::new()
            $PSVars.Add([psvariable]::new('WPFAutoAttachContext', $RealParent))

            { On Click {} }.InvokeWithContext($null, $PSVars)

            # An empty scriptblock stringifies to '', so -BeNullOrEmpty would false-positive here.
            $RealParent.AttachedHandler | Should -Not -Be $null
            $RealParent.AttachedHandler | Should -BeOfType ([scriptblock])
        }
    }
}
