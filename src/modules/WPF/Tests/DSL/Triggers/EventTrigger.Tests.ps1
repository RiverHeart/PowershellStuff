Describe 'EventTrigger' -Tag 'EventTrigger' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should add an EventTrigger with a BeginStoryboard and DoubleAnimation children' {
        $template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])
        $psVars = New-WPFVariableList -InputObject $template

        {
            EventTrigger 'Mouse.MouseEnter' {
                BeginStoryboard 'mouseEnterBeginStoryboard' {
                    Storyboard {
                        DoubleAnimation -Target 'GlassCube' -Property '(Rectangle.RenderTransform).(TransformGroup.Children)[0].(ScaleTransform.ScaleX)' -By -0.1 -Duration '0:0:0.5'
                        DoubleAnimation -Target 'GlassCube' -Property '(Rectangle.RenderTransform).(TransformGroup.Children)[0].(ScaleTransform.ScaleY)' -By -0.1 -Duration '0:0:0.5'
                    }
                }
            }
        }.InvokeWithContext($null, $psVars) | Out-Null

        $template.Triggers.Count | Should -Be -ExpectedValue 1
        $trigger = $template.Triggers[0]

        $trigger | Should -BeOfType ([System.Windows.EventTrigger])
        $trigger.RoutedEvent.Name | Should -Be -ExpectedValue 'MouseEnter'
        $trigger.Actions.Count | Should -Be -ExpectedValue 1

        $beginStoryboard = $trigger.Actions[0]
        $beginStoryboard | Should -BeOfType ([System.Windows.Media.Animation.BeginStoryboard])
        $beginStoryboard.Name | Should -Be -ExpectedValue 'mouseEnterBeginStoryboard'
        $beginStoryboard.Storyboard | Should -Not -Be $null
        $beginStoryboard.Storyboard.Children.Count | Should -Be -ExpectedValue 2

        $firstAnimation = $beginStoryboard.Storyboard.Children[0]
        $firstAnimation | Should -BeOfType ([System.Windows.Media.Animation.DoubleAnimation])
        ([System.Windows.Media.Animation.Storyboard]::GetTargetName($firstAnimation)) | Should -Be -ExpectedValue 'GlassCube'
        ([System.Windows.Media.Animation.Storyboard]::GetTargetProperty($firstAnimation).Path) | Should -Be -ExpectedValue '(Rectangle.RenderTransform).(TransformGroup.Children)[0].(ScaleTransform.ScaleX)'
        $firstAnimation.By | Should -Be -ExpectedValue -0.1
        $firstAnimation.Duration.TimeSpan | Should -Be -ExpectedValue ([TimeSpan]::FromSeconds(0.5))

        $nameScope = [System.Windows.Markup.INameScope] $template
        $findNameMethod = [System.Windows.Markup.INameScope].GetMethod('FindName')
        $registeredAction = $findNameMethod.Invoke($nameScope, @('mouseEnterBeginStoryboard'))
        $registeredAction | Should -Not -Be $null
        $registeredAction | Should -BeOfType ([System.Windows.Media.Animation.BeginStoryboard])
    }

    It 'Should add a StopStoryboard action for a named BeginStoryboard' {
        $template = [System.Windows.Controls.ControlTemplate]::new([System.Windows.Controls.Button])
        $psVars = New-WPFVariableList -InputObject $template

        {
            EventTrigger 'Mouse.MouseLeave' {
                StopStoryboard 'mouseEnterBeginStoryboard'
            }
        }.InvokeWithContext($null, $psVars) | Out-Null

        $template.Triggers.Count | Should -Be -ExpectedValue 1

        $trigger = $template.Triggers[0]
        $trigger | Should -BeOfType ([System.Windows.EventTrigger])
        $trigger.RoutedEvent.Name | Should -Be -ExpectedValue 'MouseLeave'
        $trigger.Actions.Count | Should -Be -ExpectedValue 1

        $stopStoryboard = $trigger.Actions[0]
        $stopStoryboard | Should -BeOfType ([System.Windows.Media.Animation.StopStoryboard])
        $stopStoryboard.BeginStoryboardName | Should -Be -ExpectedValue 'mouseEnterBeginStoryboard'

    }

    It 'Should reject EventTrigger usage outside style or template contexts' {
        $button = [System.Windows.Controls.Button]::new()
        $psVars = New-WPFVariableList -InputObject $button

        {
            { EventTrigger 'Mouse.MouseEnter' { BeginStoryboard { Storyboard {} } } -ErrorAction Stop }.InvokeWithContext($null, $psVars) | Out-Null
        } | Should -Throw
    }
}
