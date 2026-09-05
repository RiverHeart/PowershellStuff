Describe 'Add-WpfDesignerPropertyMinimum' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerPropertyMinimum.ps1"
    }

    It 'Should clamp a below-minimum committed value on LostFocus' {
        $TextBox = [System.Windows.Controls.TextBox]::new()
        $TextBox.Text = '5'
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $State = @{ SelectedElement = $Target }

        Add-WpfDesignerPropertyMinimum -InputObject $TextBox -PropertyName Width -Minimum 20 -State $State

        $LostFocusArgs = [System.Windows.RoutedEventArgs]::new([System.Windows.UIElement]::LostFocusEvent)
        $TextBox.RaiseEvent($LostFocusArgs)

        $Target.Width | Should -Be -ExpectedValue 20
    }

    It 'Should leave an above-minimum committed value untouched' {
        $TextBox = [System.Windows.Controls.TextBox]::new()
        $TextBox.Text = '150'
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Height = 26
        $State = @{ SelectedElement = $Target }

        Add-WpfDesignerPropertyMinimum -InputObject $TextBox -PropertyName Height -Minimum 20 -State $State

        $LostFocusArgs = [System.Windows.RoutedEventArgs]::new([System.Windows.UIElement]::LostFocusEvent)
        $TextBox.RaiseEvent($LostFocusArgs)

        $Target.Height | Should -Be -ExpectedValue 150
    }

    It 'Should ignore non-numeric text' {
        $TextBox = [System.Windows.Controls.TextBox]::new()
        $TextBox.Text = 'not-a-number'
        $Target = [System.Windows.Controls.Label]::new()
        $Target.Width = 100
        $State = @{ SelectedElement = $Target }

        Add-WpfDesignerPropertyMinimum -InputObject $TextBox -PropertyName Width -Minimum 20 -State $State

        $LostFocusArgs = [System.Windows.RoutedEventArgs]::new([System.Windows.UIElement]::LostFocusEvent)
        { $TextBox.RaiseEvent($LostFocusArgs) } | Should -Not -Throw
        $Target.Width | Should -Be -ExpectedValue 100
    }

    It 'Should be a no-op when nothing is selected' {
        $TextBox = [System.Windows.Controls.TextBox]::new()
        $TextBox.Text = '5'
        $State = @{ SelectedElement = $null }

        Add-WpfDesignerPropertyMinimum -InputObject $TextBox -PropertyName Width -Minimum 20 -State $State

        $LostFocusArgs = [System.Windows.RoutedEventArgs]::new([System.Windows.UIElement]::LostFocusEvent)
        { $TextBox.RaiseEvent($LostFocusArgs) } | Should -Not -Throw
    }
}

Describe 'Add-WpfDesignerEnterCommit' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        . "$PSScriptRoot/../functions/Add-WpfDesignerEnterCommit.ps1"
    }

    It 'Should not throw when Enter is pressed' {
        $TextBox = [System.Windows.Controls.TextBox]::new()
        Add-WpfDesignerEnterCommit -InputObject $TextBox

        # KeyEventArgs requires a real PresentationSource, so host the TextBox
        # in an invisible native window instead of a full app Window/Show().
        $HwndSourceParams = [System.Windows.Interop.HwndSourceParameters]::new('WpfDesignerTest')
        $HwndSourceParams.Width = 100
        $HwndSourceParams.Height = 100
        $HwndSource = [System.Windows.Interop.HwndSource]::new($HwndSourceParams)
        try {
            $HwndSource.RootVisual = $TextBox

            $KeyArgs = [System.Windows.Input.KeyEventArgs]::new(
                [System.Windows.Input.Keyboard]::PrimaryDevice,
                $HwndSource,
                0,
                [System.Windows.Input.Key]::Enter
            )
            $KeyArgs.RoutedEvent = [System.Windows.UIElement]::KeyDownEvent

            { $TextBox.RaiseEvent($KeyArgs) } | Should -Not -Throw
        } finally {
            $HwndSource.Dispose()
        }
    }
}
