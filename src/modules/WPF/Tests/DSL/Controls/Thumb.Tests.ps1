Describe 'Thumb' -Tag 'Thumb' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -Thumb 'MyThumb' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create and configure a Thumb with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = Thumb "Thumb_$Id" {
            $this.Width = 12
            $this.Height = 12
        }

        $Result | Should -BeOfType [System.Windows.Controls.Primitives.Thumb]
        $Result.Name | Should -Be "Thumb_$Id"
        $Result.Width | Should -Be 12
        $Result.Height | Should -Be 12
    }

    It 'Should auto-attach to parent context and return no output' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.StackPanel]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Thumb "Thumb_$Id" {}
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be 0
        $Parent.Children | Should -HaveCount 1
        $Parent.Children[0] | Should -BeOfType [System.Windows.Controls.Primitives.Thumb]
        $Parent.Children[0].Name | Should -Be "Thumb_$Id"
    }
}
