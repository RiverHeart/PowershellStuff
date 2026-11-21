BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../../AstEditor/AstEditor.psd1" -Force
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickFinding' {
    BeforeEach {
        $Extent = { $Value }.Ast.EndBlock.Statements[0].Extent
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.'
    }

    It 'creates a Nitpick finding from a scalar correction' {
        $Finding = New-NitpickFinding `
            -RuleId 'Example/Test-Rule' `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Warning `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction

        $Finding.GetType().Name | Should -Be 'NitpickFinding'
        $Finding.RuleId | Should -Be 'Example/Test-Rule'
        $Finding.Severity | Should -Be 'Warning'
        $Finding.Corrections.Count | Should -Be 1
        $Finding.Corrections[0] | Should -Be $Correction
    }

    It 'returns a native finding' {
        $Finding = New-NitpickFinding `
            -RuleId 'Example/Test-Rule' `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction

        $Finding.GetType().Name | Should -Be 'NitpickFinding'
    }

    It 'creates a qualified standalone finding without legacy identity fields' {
        $Finding = New-NitpickFinding -RuleId 'Example/TestRule' `
            -Message 'A problem was found.' -ViolationExtent $Extent -Severity Warning `
            -ScriptPath '<ScriptBlock>' -Explanation 'Test explanation.' -Corrections $Correction

        $Finding.RuleId | Should -BeExactly 'Example/TestRule'
        $Finding.PSObject.Properties.Name | Should -Not -Contain RuleName
        $Finding.PSObject.Properties.Name | Should -Not -Contain RuleSuppressionID
        $Finding.ToString() | Should -Match 'Warning Example/TestRule:'
        [object]::ReferenceEquals($Finding.Corrections[0], $Correction) | Should -BeTrue
        $Correction.RuleId | Should -BeNullOrEmpty
    }

    It 'rejects malformed standalone identity <RuleId>' -ForEach @(
        @{ RuleId = $null }
        @{ RuleId = '' }
        @{ RuleId = ' ' }
        @{ RuleId = 'TestRule' }
        @{ RuleId = '/TestRule' }
        @{ RuleId = 'Example/' }
        @{ RuleId = ' /TestRule' }
        @{ RuleId = 'Example/ ' }
        @{ RuleId = 'Example/Test/Rule' }
        @{ RuleId = 'Example\TestRule' }
        @{ RuleId = 'Example/*' }
        @{ RuleId = '*/TestRule' }
        @{ RuleId = 'Example/Test?' }
        @{ RuleId = 'Example/[Test]' }
    ) {
        {
            New-NitpickFinding -RuleId $RuleId -Message 'Invalid identity.' `
                -ViolationExtent $Extent -Severity Warning -ScriptPath '<ScriptBlock>' `
                -Explanation 'Invalid identity.'
        } | Should -Throw
    }

    It 'validates explicit identity in the finding hashtable constructor' {
        InModuleScope Nitpick -Parameters @{ Extent = $Extent } {
            param ($Extent)

            $Properties = @{
                RuleId = 'Example/TestRule'; ViolationExtent = $Extent
                Message = 'Constructor identity.'; Severity = 'Warning'
            }
            $Finding = [NitpickFinding]::new($Properties)
            $Finding.RuleId | Should -BeExactly 'Example/TestRule'
            $Properties.RuleId = 'Unqualified'
            { [NitpickFinding]::new($Properties) } | Should -Throw '*Namespace/Name*'
        }
    }

    It 'requires RuleId in the helper signature and constructor' {
        (Get-Command New-NitpickFinding).Parameters.RuleId.Attributes.Mandatory | Should -Contain $true
        InModuleScope Nitpick {
            { [NitpickFinding]::new(@{}) } | Should -Throw
        }
    }

    It 'rejects unknown finding constructor keys' -ForEach @(
        @{ Key = 'RuleName' }
        @{ Key = 'NotARealKey' }
    ) {
        InModuleScope Nitpick -Parameters @{ Key = $Key; Extent = $Extent } {
            param ($Key, $Extent)
            $Properties = @{
                RuleId = 'Example/TestRule'; ViolationExtent = $Extent
                Message = 'Unknown key.'; Severity = 'Warning'
            }
            $Properties[$Key] = 'Unknown'
            { [NitpickFinding]::new($Properties) } |
                Should -Throw "*Unknown NitpickFinding constructor key '$Key'*"
        }
    }

}
