Describe 'When' -Tag 'When', 'Category:Events' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    BeforeAll {
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should inject this as the current object when event fires' {
        $global:OnThisName = $null

        $Name = "OnButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            On Click {
                $global:OnThisName = $this.Name
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $global:OnThisName | Should -Be -ExpectedValue $Name

        Remove-Variable -Name OnThisName -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should run -State handler when value becomes target value' {
        $global:WhenStateCount = 0

        $Name = "WhenStateButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            State @{
                IsReady = $false
            }

            When -State IsReady -Becomes $true {
                $global:WhenStateCount++
            }
        }

        $Button.Tag.IsReady = $true
        $Button.Tag.IsReady = $true
        $Button.Tag.IsReady = $false
        $Button.Tag.IsReady = $true

        $global:WhenStateCount | Should -Be -ExpectedValue 2

        Remove-Variable -Name WhenStateCount -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should bind `$this to parent control in -State handler' {
        $global:WhenStateThisName = $null

        $Name = "WhenStateThisButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            State @{
                IsReady = $false
            }

            When -State IsReady -Becomes $true {
                $global:WhenStateThisName = $this.Name
            }
        }

        $Button.Tag.IsReady = $true

        $global:WhenStateThisName | Should -Be -ExpectedValue $Name

        Remove-Variable -Name WhenStateThisName -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should run -Changes handler when state value changes' {
        $global:WhenChangesCount = 0

        $Name = "WhenChangesButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            State @{
                RotationAngle = 0
            }

            When -State RotationAngle -Changes {
                $global:WhenChangesCount++
            }
        }

        $Button.Tag.RotationAngle = 90
        $Button.Tag.RotationAngle = 180

        $global:WhenChangesCount | Should -Be -ExpectedValue 2

        Remove-Variable -Name WhenChangesCount -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should respect -To filter with -Changes' {
        $global:WhenChangesToCount = 0

        $Name = "WhenChangesToButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            State @{
                IsReady = $false
            }

            When -State IsReady -Changes -To $true {
                $global:WhenChangesToCount++
            }
        }

        $Button.Tag.IsReady = $true
        $Button.Tag.IsReady = $false
        $Button.Tag.IsReady = $true

        $global:WhenChangesToCount | Should -Be -ExpectedValue 2

        Remove-Variable -Name WhenChangesToCount -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should respect -From and -To filters with -Changes' {
        $global:WhenChangesFromToCount = 0

        $Name = "WhenChangesFromToButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            State @{
                IsReady = $false
            }

            When -State IsReady -Changes -From $false -To $true {
                $global:WhenChangesFromToCount++
            }
        }

        $Button.Tag.IsReady = $true
        $Button.Tag.IsReady = $false
        $Button.Tag.IsReady = $true

        $global:WhenChangesFromToCount | Should -Be -ExpectedValue 2

        Remove-Variable -Name WhenChangesFromToCount -Scope Global -ErrorAction SilentlyContinue
    }
}
