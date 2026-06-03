Describe 'Get-WPFKeyword' -Tag 'Get-WPFKeyword' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should match whole command names and ignore hyphenated variants' {
        $Result = InModuleScope WPF {
            Get-WPFKeyword -ScriptBlock {
                Execute { 'ok' }
                Execute-Now { 'not-a-match' }
                CanExecute { $true }
            } -Name 'Execute', 'CanExecute'
        }

        @($Result).Count | Should -Be 2
        @($Result.Name) | Should -Contain 'Execute'
        @($Result.Name) | Should -Contain 'CanExecute'
    }

    It 'Should mark contextual keywords as requiring context by default' {
        $Result = InModuleScope WPF {
            Get-WPFKeyword -ScriptBlock {
                Execute { 'ok' }
                CanExecute { $true }
            } -Name 'Execute', 'CanExecute'
        }

        foreach ($Item in @($Result)) {
            $Item.Kind | Should -Be 'Contextual'
            $Item.IsValidInContext | Should -BeNullOrEmpty
            $Item.ValidationState | Should -Be 'ContextRequired'
        }
    }

    It 'Should validate contextual keywords when parent context is provided' {
        $Result = InModuleScope WPF {
            Get-WPFKeyword -ScriptBlock {
                Execute { 'ok' }
                CanExecute { $true }
            } -Name 'Execute', 'CanExecute' -ParentContext 'Command' -Mode Strict
        }

        @($Result).Count | Should -Be 2
        foreach ($Item in @($Result)) {
            $Item.Kind | Should -Be 'Contextual'
            $Item.IsValidInContext | Should -BeTrue
            $Item.ValidationState | Should -Be 'Valid'
            $Item.ParentContextUsed | Should -Be 'Command'
        }
    }

    It 'Should reject invalid contextual keywords in strict mode when parent is provided' {
        $Outcome = InModuleScope WPF {
            $Errors = @()
            $Result = Get-WPFKeyword -ScriptBlock {
                Execute { 'ok' }
            } -Name 'Execute' -ParentContext 'Button' -Mode Strict -ErrorAction SilentlyContinue -ErrorVariable Errors

            [pscustomobject]@{
                Result = @($Result)
                Errors = @($Errors)
            }
        }

        @($Outcome.Result).Count | Should -Be 0
        @($Outcome.Errors).Count | Should -BeGreaterThan 0
        @($Outcome.Errors)[0].ToString() | Should -Match "Contextual keyword 'Execute' is not valid"
    }

    It 'Should validate TimedEvent contextual keywords with parent context' {
        $Result = InModuleScope WPF {
            Get-WPFKeyword -ScriptBlock {
                Work { 'payload' }
                OnComplete { param($result, $sender) $null = $result; $null = $sender }
            } -Name 'Work', 'OnComplete' -ParentContext 'TimedEvent' -Mode Strict
        }

        @($Result).Count | Should -Be 2
        foreach ($Item in @($Result)) {
            $Item.Kind | Should -Be 'Contextual'
            $Item.IsValidInContext | Should -BeTrue
            $Item.ValidationState | Should -Be 'Valid'
        }
    }
}
