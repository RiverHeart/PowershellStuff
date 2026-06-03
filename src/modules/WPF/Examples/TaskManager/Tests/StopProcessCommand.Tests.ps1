# Tests for TaskManager StopProcess command state behavior

Describe 'TaskManager StopProcess command state behavior' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
        . "$PSScriptRoot/../functions/Invoke-TaskManagerRefreshStopProcessCommand.ps1"
    }

    It 'Should requery the StopProcess command when selection changes' {
        $refreshState = [pscustomobject] @{
            Count = 0
        }

        $command = [pscustomobject] @{
            PSTypeName = 'TaskManager.TestCommand'
        }
        $command | Add-Member -MemberType ScriptMethod -Name NotifyCanExecuteChanged -Value {
            $refreshState.Count++
        }

        $button = [pscustomobject] @{
            Command = $command
        }

        Mock -CommandName Reference -MockWith {
            param($Name)

            if ($Name -eq 'StopProcessButton') {
                return $button
            }

            return $null
        }

        Invoke-TaskManagerRefreshStopProcessCommand

        $refreshState.Count | Should -Be 1
    }

    It 'Should disable the StopProcess command until a process is selected' {
        $window = Window 'TestWindow' {
            State @{
                SelectedProcess = $null
            }

            Button 'StopProcessButton' {
                Command 'StopProcessCommand' {
                    Execute {
                        $null = $true
                    }

                    CanExecute {
                        [bool] (Reference 'Window').Tag.SelectedProcess
                    }
                }
            }
        }

        $command = (Reference 'StopProcessButton').Command
        $command.CanExecute($null) | Should -BeFalse

        $window.Tag.SelectedProcess = [pscustomobject] @{
            Id = 123
            Name = 'TestProcess'
        }

        $command.NotifyCanExecuteChanged()

        $command.CanExecute($null) | Should -BeTrue
    }
}