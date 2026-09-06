Describe 'Add-WpfDesignerOverlayMarker' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerOverlayMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerOverlay.ps1"
    }

    It 'Should mark an element as overlay chrome' {
        $Target = [System.Windows.Controls.Border]::new()

        Add-WpfDesignerOverlayMarker -InputObject $Target

        Test-WpfDesignerOverlay -InputObject $Target | Should -Be -ExpectedValue $true
    }

    It 'Should be idempotent when called twice' {
        $Target = [System.Windows.Controls.Border]::new()

        Add-WpfDesignerOverlayMarker -InputObject $Target
        Add-WpfDesignerOverlayMarker -InputObject $Target

        ($Target.PSObject.TypeNames | Where-Object { $_ -eq 'Custom.WpfDesigner.Overlay' }).Count | Should -Be -ExpectedValue 1
    }
}

Describe 'Test-WpfDesignerOverlay' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerOverlayMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerOverlay.ps1"
    }

    It 'Should return false for an unmarked element' {
        $Target = [System.Windows.Controls.Label]::new()

        Test-WpfDesignerOverlay -InputObject $Target | Should -Be -ExpectedValue $false
    }
}
