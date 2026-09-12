Describe 'Get-WpfDesignerEditorKind' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should classify strings as Text' {
        Get-WpfDesignerEditorKind -PropertyType ([string]) | Should -Be -ExpectedValue 'Text'
    }

    It 'Should classify booleans as Bool' {
        Get-WpfDesignerEditorKind -PropertyType ([bool]) | Should -Be -ExpectedValue 'Bool'
    }

    It 'Should classify enums as Enum' {
        Get-WpfDesignerEditorKind -PropertyType ([System.Windows.HorizontalAlignment]) | Should -Be -ExpectedValue 'Enum'
    }

    It 'Should classify <_> as Number' -ForEach @(
        [byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64], [single], [double], [decimal]
    ) {
        Get-WpfDesignerEditorKind -PropertyType $_ | Should -Be -ExpectedValue 'Number'
    }

    It 'Should return $null for an unrecognized type' {
        Get-WpfDesignerEditorKind -PropertyType ([System.Windows.Media.Brush]) | Should -Be -ExpectedValue $null
    }
}
