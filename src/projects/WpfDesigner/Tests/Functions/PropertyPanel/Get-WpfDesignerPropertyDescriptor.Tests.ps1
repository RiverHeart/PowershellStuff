Describe 'Get-WpfDesignerPropertyDescriptor' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should include a writable string property as Text' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        ($Descriptors | Where-Object Name -eq 'Text').EditorKind | Should -Be -ExpectedValue 'Text'
    }

    It 'Should include textual ContentControl content as Text' {
        $Label = [System.Windows.Controls.Label]::new()
        $Label.Content = 'Label text'

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $Label
        $ContentDescriptor = $Descriptors | Where-Object Name -eq 'Content'

        $ContentDescriptor.PropertyType | Should -Be ([object])
        $ContentDescriptor.EditorKind | Should -Be -ExpectedValue 'Text'
        $ContentDescriptor.IsReadOnly | Should -BeFalse
    }

    It 'Should include rich ContentControl content as read-only Text' {
        $Label = [System.Windows.Controls.Label]::new()
        $Label.Content = [System.Windows.Controls.StackPanel]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $Label
        $ContentDescriptor = $Descriptors | Where-Object Name -eq 'Content'

        $ContentDescriptor.EditorKind | Should -Be -ExpectedValue 'Text'
        $ContentDescriptor.IsReadOnly | Should -BeTrue
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

    It 'Should exclude attached properties that require parent-aware editing' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        @($Descriptors | Where-Object Name -eq 'Typography.Fraction') | Should -HaveCount 0
    }

    It 'Should exclude a property with an unrecognized type' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        $Descriptors = Get-WpfDesignerPropertyDescriptor -InputObject $TextBlock

        @($Descriptors | Where-Object Name -eq 'Foreground') | Should -HaveCount 0
    }
}
