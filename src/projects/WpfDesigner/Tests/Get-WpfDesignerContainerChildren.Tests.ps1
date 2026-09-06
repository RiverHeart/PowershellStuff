Describe 'Get-WpfDesignerContainerChildren' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerOverlayMarker.ps1"
        . "$PSScriptRoot/../functions/Test-WpfDesignerOverlay.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerContainerChildren.ps1"
    }

    It 'Should return a Panel''s children in order' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $First = [System.Windows.Controls.Label]::new()
        $Second = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($First) | Out-Null
        $Canvas.Children.Add($Second) | Out-Null

        $Children = Get-WpfDesignerContainerChildren -Element $Canvas

        $Children | Should -Be -ExpectedValue @($First, $Second)
    }

    It 'Should filter out overlay-marked siblings' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Real = [System.Windows.Controls.Label]::new()
        $Overlay = [System.Windows.Controls.Border]::new()
        Add-WpfDesignerOverlayMarker -InputObject $Overlay
        $Canvas.Children.Add($Real) | Out-Null
        $Canvas.Children.Add($Overlay) | Out-Null

        $Children = Get-WpfDesignerContainerChildren -Element $Canvas

        $Children | Should -Be -ExpectedValue @($Real)
    }

    It 'Should return a Border''s single Child' {
        $Border = [System.Windows.Controls.Border]::new()
        $Child = [System.Windows.Controls.Label]::new()
        $Border.Child = $Child

        Get-WpfDesignerContainerChildren -Element $Border | Should -Be -ExpectedValue @($Child)
    }

    It 'Should return an empty array for an empty Border' {
        $Border = [System.Windows.Controls.Border]::new()

        @(Get-WpfDesignerContainerChildren -Element $Border).Count | Should -Be -ExpectedValue 0
    }

    It 'Should return an empty array for a leaf element' {
        $Label = [System.Windows.Controls.Label]::new()

        @(Get-WpfDesignerContainerChildren -Element $Label).Count | Should -Be -ExpectedValue 0
    }
}
