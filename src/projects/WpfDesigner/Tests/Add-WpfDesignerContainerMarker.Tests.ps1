Describe 'Add-WpfDesignerContainerMarker' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerContainerMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainer.ps1"
    }

    It 'Should mark an element as a valid container' {
        $Target = [System.Windows.Controls.StackPanel]::new()

        Add-WpfDesignerContainerMarker -InputObject $Target

        Test-WpfDesignerContainer -InputObject $Target | Should -Be -ExpectedValue $true
    }

    It 'Should be idempotent when called twice' {
        $Target = [System.Windows.Controls.StackPanel]::new()

        Add-WpfDesignerContainerMarker -InputObject $Target
        Add-WpfDesignerContainerMarker -InputObject $Target

        ($Target.PSObject.TypeNames | Where-Object { $_ -eq 'Custom.WpfDesigner.Container' }).Count | Should -Be -ExpectedValue 1
    }
}

Describe 'Test-WpfDesignerContainer' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerContainerMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainer.ps1"
    }

    It 'Should return false for an unmarked element' {
        $Target = [System.Windows.Controls.Label]::new()

        Test-WpfDesignerContainer -InputObject $Target | Should -Be -ExpectedValue $false
    }
}

Describe 'Test-WpfDesignerContainerCapacity' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Test-WpfDesignerContainerCapacity.ps1"
    }

    It 'Should always have capacity for a Panel-derived container' {
        $Target = [System.Windows.Controls.StackPanel]::new()

        Test-WpfDesignerContainerCapacity -Container $Target | Should -Be -ExpectedValue $true
    }

    It 'Should have capacity for an empty Border' {
        $Target = [System.Windows.Controls.Border]::new()

        Test-WpfDesignerContainerCapacity -Container $Target | Should -Be -ExpectedValue $true
    }

    It 'Should have no capacity for a Border that already has a Child' {
        $Target = [System.Windows.Controls.Border]::new()
        $Target.Child = [System.Windows.Controls.Label]::new()

        Test-WpfDesignerContainerCapacity -Container $Target | Should -Be -ExpectedValue $false
    }
}
