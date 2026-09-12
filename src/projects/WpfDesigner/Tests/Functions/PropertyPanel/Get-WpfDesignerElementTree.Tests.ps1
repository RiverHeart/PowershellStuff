Describe 'Get-WpfDesignerElementTree' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should return an empty array for an empty canvas' {
        $Canvas = [System.Windows.Controls.Canvas]::new()

        @(Get-WpfDesignerElementTree -Element $Canvas).Count | Should -Be -ExpectedValue 0
    }

    It 'Should list loose elements as depth-0 root nodes' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $First = [System.Windows.Controls.Label]::new()
        $Second = [System.Windows.Controls.Label]::new()
        $Canvas.Children.Add($First) | Out-Null
        $Canvas.Children.Add($Second) | Out-Null

        $Tree = Get-WpfDesignerElementTree -Element $Canvas

        $Tree.Count | Should -Be -ExpectedValue 2
        $Tree[0].Element | Should -Be -ExpectedValue $First
        $Tree[0].Depth | Should -Be -ExpectedValue 0
        $Tree[1].Element | Should -Be -ExpectedValue $Second
    }

    It 'Should recurse into a StackPanel''s children at depth 1' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $StackPanel = [System.Windows.Controls.StackPanel]::new()
        $ChildLabel = [System.Windows.Controls.Label]::new()
        $StackPanel.Children.Add($ChildLabel) | Out-Null
        $Canvas.Children.Add($StackPanel) | Out-Null

        $Tree = Get-WpfDesignerElementTree -Element $Canvas

        $Tree.Count | Should -Be -ExpectedValue 2
        $Tree[0].Element | Should -Be -ExpectedValue $StackPanel
        $Tree[0].Depth | Should -Be -ExpectedValue 0
        $Tree[1].Element | Should -Be -ExpectedValue $ChildLabel
        $Tree[1].Depth | Should -Be -ExpectedValue 1
    }

    It 'Should recurse into a Border''s single Child (the Window frame shape)' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Frame = [System.Windows.Controls.Border]::new()
        $ChildLabel = [System.Windows.Controls.Label]::new()
        $Frame.Child = $ChildLabel
        $Canvas.Children.Add($Frame) | Out-Null

        $Tree = Get-WpfDesignerElementTree -Element $Canvas

        $Tree[0].Element | Should -Be -ExpectedValue $Frame
        $Tree[1].Element | Should -Be -ExpectedValue $ChildLabel
        $Tree[1].Depth | Should -Be -ExpectedValue 1
    }

    It 'Should skip overlay-marked elements (resize handle / selection outline)' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Real = [System.Windows.Controls.Label]::new()
        $Overlay = [System.Windows.Controls.Border]::new()
        Add-PSType -InputObject $Overlay -TypeName 'Custom.WpfDesigner.Overlay'
        $Canvas.Children.Add($Real) | Out-Null
        $Canvas.Children.Add($Overlay) | Out-Null

        $Tree = Get-WpfDesignerElementTree -Element $Canvas

        $Tree.Count | Should -Be -ExpectedValue 1
        $Tree[0].Element | Should -Be -ExpectedValue $Real
    }

    It 'Should nest depth across multiple levels' {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        $Outer = [System.Windows.Controls.StackPanel]::new()
        $Inner = [System.Windows.Controls.StackPanel]::new()
        $Leaf = [System.Windows.Controls.Label]::new()
        $Inner.Children.Add($Leaf) | Out-Null
        $Outer.Children.Add($Inner) | Out-Null
        $Canvas.Children.Add($Outer) | Out-Null

        $Tree = Get-WpfDesignerElementTree -Element $Canvas

        $Tree.Count | Should -Be -ExpectedValue 3
        $Tree[0].Depth | Should -Be -ExpectedValue 0
        $Tree[1].Depth | Should -Be -ExpectedValue 1
        $Tree[2].Depth | Should -Be -ExpectedValue 2
        $Tree[2].Element | Should -Be -ExpectedValue $Leaf
    }
}
