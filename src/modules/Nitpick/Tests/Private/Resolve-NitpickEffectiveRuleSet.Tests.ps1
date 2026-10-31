BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickEffectiveRuleSet' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'returns only the built-in package by default' {
        $Rules = InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet }

        @($Rules | Where-Object Namespace -ne Nitpick) | Should -HaveCount 0
        $Rules.Id | Should -Contain 'Nitpick/UseIsNotOperator'
    }

    It 'merges discovered and registered rules by Id' {
        Register-Nitpick -Name AvoidFoo -Source Personal -Callable { param ($ScriptBlockAst) }

        $Rules = InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet }

        $Rules.Id | Should -Contain 'Local/AvoidFoo'
        $Rules.Id | Should -Contain 'Nitpick/UseIsNotOperator'
    }

    It 'prefers registered metadata for a same-Id, same-callable discovered candidate' {
        $Registered = Register-Nitpick -Namespace Nitpick -Name UseIsNotOperator -Source Personal `
            -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick) -Category Quality -PassThru

        $Rules = InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet }

        $Rule = $Rules | Where-Object Id -eq 'Nitpick/UseIsNotOperator'
        [object]::ReferenceEquals($Rule, $Registered) | Should -BeTrue
        $Rule.Category | Should -Be Quality
    }

    It 'throws before returning when a same-Id candidate has a different callable' {
        Register-Nitpick -Namespace Nitpick -Name UseIsNotOperator -Source Personal `
            -Callable { param ($ScriptBlockAst) }

        { InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet } } | Should -Throw '*Nitpick/UseIsNotOperator*'
    }

    It 'throws a guidance error for an unmatched literal IncludeRule selector' {
        {
            InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet -IncludeRule 'Nitpick/MissingRule' }
        } | Should -Throw '*No Nitpick rules match the IncludeRule selector(s): Nitpick/MissingRule*'
    }

    It 'allows an unmatched wildcard IncludeRule selector when other rules remain' {
        $Rules = InModuleScope Nitpick {
            Resolve-NitpickEffectiveRuleSet -IncludeRule 'Nitpick/UseIsNotOperator', 'Nitpick/Missing*'
        }

        $Rules.Id | Should -Be 'Nitpick/UseIsNotOperator'
    }

    It 'keeps only EditorEnabled rules when EditorMode is specified' {
        Register-Nitpick -Name EditorRule -Source Tests -EditorEnabled $true `
            -Callable { param ($ScriptBlockAst) }
        Register-Nitpick -Name NonEditorRule -Source Tests -EditorEnabled $false `
            -Callable { param ($ScriptBlockAst) }

        $Rules = InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet -EditorMode }

        $Rules.Id | Should -Contain 'Local/EditorRule'
        $Rules.Id | Should -Not -Contain 'Local/NonEditorRule'
    }

    It 'throws when excluding every known rule leaves nothing eligible' {
        {
            InModuleScope Nitpick { Resolve-NitpickEffectiveRuleSet -ExcludeRule 'Nitpick/*' }
        } | Should -Throw '*No eligible Nitpick rules remain*'
    }
}
