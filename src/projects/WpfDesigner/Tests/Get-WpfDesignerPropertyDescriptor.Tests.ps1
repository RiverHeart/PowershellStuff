Describe 'Get-WpfDesignerPropertyDescriptor' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Get-WpfDesignerEditorKind.ps1"
        . "$PSScriptRoot/../functions/Get-WpfDesignerPropertyDescriptor.ps1"
    }

    It 'Should include a writable string property as Text' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        ($Descriptors | Where-Object Name -eq 'Text').EditorKind | Should -Be -ExpectedValue 'Text'
    }

    It 'Should include a writable numeric property as Number' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        ($Descriptors | Where-Object Name -eq 'Width').EditorKind | Should -Be -ExpectedValue 'Number'
    }

    It 'Should include a writable enum property as Enum' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        ($Descriptors | Where-Object Name -eq 'HorizontalAlignment').EditorKind | Should -Be -ExpectedValue 'Enum'
    }

    It 'Should exclude a read-only property' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        @($Descriptors | Where-Object Name -eq 'ActualWidth') | Should -HaveCount 0
    }

    It 'Should exclude a property with an unrecognized type' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        @($Descriptors | Where-Object Name -eq 'Foreground') | Should -HaveCount 0
    }
}
