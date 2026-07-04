Describe 'GridViewColumnHeader' -Tag 'GridViewColumnHeader' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -GridViewColumnHeader 'MyGridViewColumnHeader' {}
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should create a GridViewColumnHeader with the given name' {
        $Id = [guid]::NewGuid().ToString('N')

        $Result = GridViewColumnHeader "Header_$Id" {
            $this.Content = 'Name'
        }

        $Result | Should -BeOfType [System.Windows.Controls.GridViewColumnHeader]
        $Result.Name | Should -Be "Header_$Id"
        $Result.Content | Should -Be 'Name'
    }

    It 'Should attach GridViewColumnHeader when declared inside GridViewColumn' {
        $Result = GridViewColumn {
            GridViewColumnHeader {
                $this.Content = 'CPU'
            }
        }

        $Result.Header | Should -BeOfType [System.Windows.Controls.GridViewColumnHeader]
        $Result.Header.Content | Should -Be 'CPU'
    }
}
