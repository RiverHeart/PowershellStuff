Describe 'Key' -Tag 'Key' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should invoke action when key and modifiers match for deferred event execution' {
        $WasExecuted = InModuleScope WPF {
            $script:CapturedHandler = $null
            $script:ActionExecuted = $false

            Mock -CommandName New-WPFVariableList -MockWith {
                [System.Collections.Generic.List[psvariable]]::new()
            }

            Mock -CommandName When -MockWith {
                param($Event, $ScriptBlock, $InputObject)
                $script:CapturedHandler = $ScriptBlock
            }

            Key 'Escape' {
                $script:ActionExecuted = $true
            }

            $event = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::Escape
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::None
                }
            }

            & $script:CapturedHandler $null $event
            return $script:ActionExecuted
        }

        $WasExecuted | Should -BeTrue
    }

    It 'Should not invoke action when key does not match' {
        $WasExecuted = InModuleScope WPF {
            $script:CapturedHandler = $null
            $script:ActionExecuted = $false

            Mock -CommandName New-WPFVariableList -MockWith {
                [System.Collections.Generic.List[psvariable]]::new()
            }

            Mock -CommandName When -MockWith {
                param($Event, $ScriptBlock, $InputObject)
                $script:CapturedHandler = $ScriptBlock
            }

            Key 'Escape' {
                $script:ActionExecuted = $true
            }

            $event = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::F11
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::None
                }
            }

            & $script:CapturedHandler $null $event
            return $script:ActionExecuted
        }

        $WasExecuted | Should -BeFalse
    }

    It 'Should allow action to set event handled without explicit param block' {
        $WasHandled = InModuleScope WPF {
            $script:CapturedHandler = $null

            Mock -CommandName New-WPFVariableList -MockWith {
                [System.Collections.Generic.List[psvariable]]::new()
            }

            Mock -CommandName When -MockWith {
                param($Event, $ScriptBlock, $InputObject)
                $script:CapturedHandler = $ScriptBlock
            }

            Key 'Escape' {
                $event.Handled = $true
            }

            $event = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::Escape
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::None
                }
                Handled = $false
            }

            & $script:CapturedHandler $null $event
            return $event.Handled
        }

        $WasHandled | Should -BeTrue
    }

    It 'Should accept variable arrays returned from New-WPFVariableList' {
        $WasExecuted = InModuleScope WPF {
            $script:CapturedHandler = $null
            $script:ActionExecuted = $false

            Mock -CommandName New-WPFVariableList -MockWith {
                @([psvariable]::new('this', [pscustomobject]@{ Name = 'Window' }))
            }

            Mock -CommandName When -MockWith {
                param($Event, $ScriptBlock, $InputObject)
                $script:CapturedHandler = $ScriptBlock
            }

            Key 'Escape' {
                $script:ActionExecuted = $true
            }

            $event = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::Escape
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::None
                }
            }

            & $script:CapturedHandler $null $event
            return $script:ActionExecuted
        }

        $WasExecuted | Should -BeTrue
    }

    It 'Should require exact modifier matches for modified gestures' {
        $ExecutionCount = InModuleScope WPF {
            $script:CapturedHandler = $null
            $script:ExecutionCount = 0

            Mock -CommandName New-WPFVariableList -MockWith {
                [System.Collections.Generic.List[psvariable]]::new()
            }

            Mock -CommandName When -MockWith {
                param($Event, $ScriptBlock, $InputObject)
                $script:CapturedHandler = $ScriptBlock
            }

            Key 'Ctrl+Shift+S' {
                $script:ExecutionCount++
            }

            $NoneModifiers = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::S
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::None
                }
            }

            $PartialModifiers = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::S
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::Control
                }
            }

            $ExactModifiers = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::S
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::Control -bor [System.Windows.Input.ModifierKeys]::Shift
                }
            }

            $ExtraModifiers = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::S
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::Control -bor [System.Windows.Input.ModifierKeys]::Shift -bor [System.Windows.Input.ModifierKeys]::Alt
                }
            }

            & $script:CapturedHandler $null $NoneModifiers
            & $script:CapturedHandler $null $PartialModifiers
            & $script:CapturedHandler $null $ExactModifiers
            & $script:CapturedHandler $null $ExtraModifiers

            return $script:ExecutionCount
        }

        $ExecutionCount | Should -Be 1
    }

    It 'Should invoke action when any configured gesture matches' {
        $ExecutionCount = InModuleScope WPF {
            $script:CapturedHandler = $null
            $script:ExecutionCount = 0

            Mock -CommandName New-WPFVariableList -MockWith {
                [System.Collections.Generic.List[psvariable]]::new()
            }

            Mock -CommandName When -MockWith {
                param($Event, $ScriptBlock, $InputObject)
                $script:CapturedHandler = $ScriptBlock
            }

            Key @('Ctrl+S', 'F11') {
                $script:ExecutionCount++
            }

            $CtrlS = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::S
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::Control
                }
            }

            $F11 = [pscustomobject]@{
                Key = [System.Windows.Input.Key]::F11
                KeyboardDevice = [pscustomobject]@{
                    Modifiers = [System.Windows.Input.ModifierKeys]::None
                }
            }

            & $script:CapturedHandler $null $CtrlS
            & $script:CapturedHandler $null $F11

            return $script:ExecutionCount
        }

        $ExecutionCount | Should -Be 2
    }
}
