Describe 'ProgressBar' -Tag 'ProgressBar' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -ProgressBar 'MyProgressBar' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create and configure a ProgressBar with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = ProgressBar "ProgressBar_$Id" {
            $this.Minimum = 10
            $this.Maximum = 200
            $this.Value = 75
            $this.Orientation = [System.Windows.Controls.Orientation]::Vertical
            $this.IsIndeterminate = $true
        }

        $Result | Should -BeOfType [System.Windows.Controls.ProgressBar]
        $Result.Name | Should -Be "ProgressBar_$Id"
        $Result.Minimum | Should -Be 10
        $Result.Maximum | Should -Be 200
        $Result.Value | Should -Be 75
        $Result.Orientation | Should -Be ([System.Windows.Controls.Orientation]::Vertical)
        $Result.IsIndeterminate | Should -BeTrue
    }

    It 'Should auto-attach to parent context and return no output' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.StackPanel]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            ProgressBar "ProgressBar_$Id" {}
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 0
        $Parent.Children | Should -HaveCount 1
        $Parent.Children[0] | Should -BeOfType [System.Windows.Controls.ProgressBar]
        $Parent.Children[0].Name | Should -Be "ProgressBar_$Id"
    }
}
