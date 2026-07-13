Describe 'Resolve-WPFDependencyProperty' -Tag 'Resolve-WPFDependencyProperty' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should resolve short owner names to the WPF type when names collide' {
        InModuleScope WPF {
            $result = Resolve-WPFDependencyProperty -Property 'Rectangle.Stroke' -TargetType ([System.Windows.Controls.Button])

            $result | Should -Not -Be $null
            $result.PropertyName | Should -Be -ExpectedValue 'Stroke'
            $result.IsOwnerQualified | Should -Be -ExpectedValue $true
            $result.IsAttached | Should -Be -ExpectedValue $true
            $result.OwnerType.FullName | Should -Be -ExpectedValue 'System.Windows.Shapes.Rectangle'
            $result.DependencyProperty.OwnerType.FullName | Should -Be -ExpectedValue 'System.Windows.Shapes.Shape'
            $result.PropertyType.FullName | Should -Be -ExpectedValue 'System.Windows.Media.Brush'
        }
    }

    It 'Should resolve fully-qualified owner names' {
        InModuleScope WPF {
            $result = Resolve-WPFDependencyProperty -Property 'System.Windows.Shapes.Rectangle.Stroke' -TargetType ([System.Windows.Controls.Button])

            $result | Should -Not -Be $null
            $result.PropertyName | Should -Be -ExpectedValue 'Stroke'
            $result.IsOwnerQualified | Should -Be -ExpectedValue $true
            $result.OwnerType.FullName | Should -Be -ExpectedValue 'System.Windows.Shapes.Rectangle'
            $result.DependencyProperty.OwnerType.FullName | Should -Be -ExpectedValue 'System.Windows.Shapes.Shape'
        }
    }

    It 'Should return null for unknown owner-qualified properties' {
        InModuleScope WPF {
            $result = Resolve-WPFDependencyProperty -Property 'NotAType.NotAProperty' -TargetType ([System.Windows.Controls.Button])

            $result | Should -Be $null
        }
    }

    It 'Should resolve unqualified properties against the target type' {
        InModuleScope WPF {
            $result = Resolve-WPFDependencyProperty -Property 'Opacity' -TargetType ([System.Windows.Controls.Button])

            $result | Should -Not -Be $null
            $result.PropertyName | Should -Be -ExpectedValue 'Opacity'
            $result.IsOwnerQualified | Should -Be -ExpectedValue $false
            $result.IsAttached | Should -Be -ExpectedValue $false
            $result.OwnerType.FullName | Should -Be -ExpectedValue 'System.Windows.Controls.Button'
            $result.DependencyProperty.OwnerType.FullName | Should -Be -ExpectedValue 'System.Windows.UIElement'
            $result.PropertyType.FullName | Should -Be -ExpectedValue 'System.Double'
        }
    }
}
