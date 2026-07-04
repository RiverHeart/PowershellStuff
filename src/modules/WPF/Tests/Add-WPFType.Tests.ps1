Describe 'Add-WPFType' -Tag 'Add-WPFType' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should be exported from the module' {
        Get-Command Add-WPFType -Module WPF | Should -Not -BeNullOrEmpty
    }

    It 'Should add the requested custom WPF type name' {
        $Border = [System.Windows.Controls.Border]::new()

        Add-WPFType -InputObject $Border -Type Control

        $Border.PSTypeNames | Should -Contain 'Custom.WPF.Control'
    }
}
