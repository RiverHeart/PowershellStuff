Describe 'NotifyCanExecuteChanged' -Tag 'Command' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should notify a command resolved through a registered control name' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Command = [RelayCommand]::new([Action] { })
        $Notifications = [System.Collections.Generic.List[object]]::new()
        $Command.add_CanExecuteChanged({
            param($Sender, $EventArgs)
            $Notifications.Add($EventArgs)
        })

        $Button = [System.Windows.Controls.Button]::new()
        $Button.Command = $Command
        Register-WPFObject -Name 'SaveButton' -InputObject $Button

        NotifyCanExecuteChanged 'SaveButton'

        $Notifications.Count | Should -Be 1
    }

    It 'Should notify a shared command only once per invocation' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Command = [RelayCommand]::new([Action] { })
        $Notifications = [System.Collections.Generic.List[object]]::new()
        $Command.add_CanExecuteChanged({
            param($Sender, $EventArgs)
            $Notifications.Add($EventArgs)
        })

        $FirstButton = [System.Windows.Controls.Button]::new()
        $FirstButton.Command = $Command
        Register-WPFObject -Name 'FirstButton' -InputObject $FirstButton

        $SecondButton = [System.Windows.Controls.Button]::new()
        $SecondButton.Command = $Command
        Register-WPFObject -Name 'SecondButton' -InputObject $SecondButton

        NotifyCanExecuteChanged 'FirstButton', 'SecondButton'

        $Notifications.Count | Should -Be 1
    }

    It 'Should accept commands and command-bearing objects from the pipeline' {
        $Command = [RelayCommand]::new([Action] { })
        $Notifications = [System.Collections.Generic.List[object]]::new()
        $Command.add_CanExecuteChanged({
            param($Sender, $EventArgs)
            $Notifications.Add($EventArgs)
        })

        $Definition = [pscustomobject] @{
            Command = $Command
        }

        $Command, $Definition | NotifyCanExecuteChanged

        $Notifications.Count | Should -Be 1
    }

    It 'Should reject targets without a notifiable command' {
        $Target = [pscustomobject] @{
            Command = $null
        }

        { $Target | NotifyCanExecuteChanged -ErrorAction Stop } |
            Should -Throw -ExpectedMessage '*does not expose a command with NotifyCanExecuteChanged()*'
    }
}
