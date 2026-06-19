Describe 'Import' -Tag 'Import' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeAll {
        $script:ImportedWhenHelperName = 'Invoke-ImportedWhenBeforeAllHelper'
        $script:ImportedWhenHelperPath = Join-Path $TestDrive "$($script:ImportedWhenHelperName).ps1"

        @"
function $($script:ImportedWhenHelperName) {
    'ok'
}
"@ | Set-Content -Path $script:ImportedWhenHelperPath -Encoding UTF8

        # Import in BeforeAll to model script-lifecycle usage (like ImageViewer).
        Import $script:ImportedWhenHelperPath
    }

    It 'Should import a function into caller scope' {
        $FunctionName = 'Invoke-ImportedScopeTestHelper'
        $ScriptPath = Join-Path $TestDrive "$FunctionName.ps1"

        @"
function $FunctionName {
    'ok'
}
"@ | Set-Content -Path $ScriptPath -Encoding UTF8

        Import $ScriptPath

        (& $FunctionName) | Should -Be -ExpectedValue 'ok'
    }

    It 'Should show imported helper is visible inside When handler scope' {
        $global:ImportedWhenVisibility = $null

        $Button = Button "ImportWhenButton_$([guid]::NewGuid().ToString('N'))" {
            On Click {
                $global:ImportedWhenVisibility = [ordered] @{}

                try {
                    $global:ImportedWhenVisibility.InsideHasGetCommand = [bool] (Get-Command -Name 'Get-Command' -ErrorAction Stop)
                }
                catch {
                    $global:ImportedWhenVisibility.InsideHasGetCommand = $false
                }

                try {
                    $global:ImportedWhenVisibility.InsideHasImported = [bool] (Get-Command -Name 'Invoke-ImportedWhenBeforeAllHelper' -ErrorAction Stop)
                }
                catch {
                    $global:ImportedWhenVisibility.InsideHasImported = $false
                }
            }
        }

        $OutsideHasImported = [bool] (Get-Command -Name 'Invoke-ImportedWhenBeforeAllHelper' -ErrorAction SilentlyContinue)
        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $OutsideHasImported | Should -BeTrue
        $global:ImportedWhenVisibility | Should -Not -BeNullOrEmpty
        $global:ImportedWhenVisibility.InsideHasGetCommand | Should -BeTrue
        $global:ImportedWhenVisibility.InsideHasImported | Should -BeTrue

        Remove-Variable -Name ImportedWhenVisibility -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should show global helper is visible inside current When closure scope' {
        function global:Invoke-ImportedWhenGlobalHelper {
            'ok-global'
        }

        $global:ImportedWhenGlobalVisibility = $null

        $Button = Button "ImportGlobalWhenButton_$([guid]::NewGuid().ToString('N'))" {
            On Click {
                $global:ImportedWhenGlobalVisibility = [ordered] @{
                    InsideHasGlobal = [bool] (Get-Command -Name 'Invoke-ImportedWhenGlobalHelper' -ErrorAction SilentlyContinue)
                }
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $OutsideHasGlobal = [bool] (Get-Command -Name 'Invoke-ImportedWhenGlobalHelper' -ErrorAction SilentlyContinue)
        $OutsideHasGlobal | Should -BeTrue
        $global:ImportedWhenGlobalVisibility | Should -Not -BeNullOrEmpty
        $global:ImportedWhenGlobalVisibility.InsideHasGlobal | Should -BeTrue

        Remove-Item -Path Function:\Invoke-ImportedWhenGlobalHelper -ErrorAction SilentlyContinue
        Remove-Variable -Name ImportedWhenGlobalVisibility -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Sanity check: dot-sourced helper resolves inside When handler scope' {
        $FunctionName = 'Invoke-DotSourcedWhenHelper'
        $ScriptPath = Join-Path $TestDrive "$FunctionName.ps1"

        @"
function $FunctionName {
    'ok-dot'
}
"@ | Set-Content -Path $ScriptPath -Encoding UTF8

        . $ScriptPath

        $global:DotSourcedWhenResult = $null

        $Button = Button "DotSourceWhenButton_$([guid]::NewGuid().ToString('N'))" {
            On Click {
                if (Get-Command -Name 'Invoke-DotSourcedWhenHelper' -ErrorAction SilentlyContinue) {
                    $global:DotSourcedWhenResult = Invoke-DotSourcedWhenHelper
                }
                else {
                    $global:DotSourcedWhenResult = 'missing-dot'
                }
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $global:DotSourcedWhenResult | Should -Be -ExpectedValue 'ok-dot'

        Remove-Item -Path Function:\Invoke-DotSourcedWhenHelper -ErrorAction SilentlyContinue
        Remove-Variable -Name DotSourcedWhenResult -Scope Global -ErrorAction SilentlyContinue
    }
}
