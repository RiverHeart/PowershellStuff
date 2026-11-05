BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
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
            -Corrections $Correction `
            -OutputAs NitpickFinding

        $Finding.GetType().Name | Should -Be 'NitpickFinding'
        $Finding.RuleId | Should -Be 'Example/Test-Rule'
        $Finding.Severity | Should -Be 'Warning'
        $Finding.Corrections.Count | Should -Be 1
        $Finding.Corrections[0] | Should -Be $Correction
    }

    It 'converts a finding to a ScriptAnalyzer DiagnosticRecord' {
        $Finding = New-NitpickFinding `
            -RuleId 'Example/Test-Rule' `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction `
            -OutputAs DiagnosticRecord

        $Finding.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
        $Finding.Message | Should -Be 'A problem was found.'
        $Finding.RuleName | Should -Be 'Test-Rule'
        $Finding.Severity.ToString() | Should -Be 'Information'
        $Finding.RuleSuppressionID | Should -Be 'Test-Rule'
        $Finding.SuggestedCorrections.Count | Should -Be 1
    }

    It 'defaults to a native finding even when ScriptAnalyzer is loaded' {
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

    It 'converts explicit identity to local diagnostic compatibility fields using <OutputAs>' -ForEach @(
        @{ OutputAs = 'NitpickFinding' }
        @{ OutputAs = 'DiagnosticRecord' }
    ) {
        $Finding = New-NitpickFinding -RuleId 'Example/TestRule' `
            -Message 'A problem was found.' -ViolationExtent $Extent -Severity Warning `
            -ScriptPath '<ScriptBlock>' -Explanation 'Test explanation.' `
            -Corrections $Correction -OutputAs $OutputAs
        $Diagnostic = if ($OutputAs -eq 'NitpickFinding') { $Finding.ToDiagnosticRecord() } else { $Finding }

        $Diagnostic.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
        $Diagnostic.RuleName | Should -BeExactly 'TestRule'
        $Diagnostic.RuleSuppressionID | Should -BeExactly 'TestRule'
        $Diagnostic.SuggestedCorrections | Should -HaveCount 1
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

    It 'omits multi-edit corrections while preserving single-edit suggestions' -ForEach @(
        @{ OutputAs = 'NitpickFinding' }
        @{ OutputAs = 'DiagnosticRecord' }
    ) {
        $MultiEditCorrection = New-NitpickCorrection `
            -TextEdit @(
                New-AstTextEdit -Extent $Extent `
                    -ReplacementText '$First' -Reason 'Coordinated fix.'
                New-AstTextEdit -Extent $Extent `
                    -ReplacementText '$Second' -Reason 'Coordinated fix.'
            ) `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Coordinated fix.'
        $Finding = New-NitpickFinding `
            -RuleId 'Example/Test-Rule' `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Information `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections (@($Correction) + $MultiEditCorrection) `
            -OutputAs $OutputAs

        $Diagnostic = if ($OutputAs -eq 'NitpickFinding') {
            $Finding.Corrections | Should -HaveCount 2
            $Finding.ToDiagnosticRecord()
        } else {
            $Finding
        }

        $Diagnostic.SuggestedCorrections | Should -HaveCount 1
        $Diagnostic.SuggestedCorrections[0].Text | Should -BeExactly '$Replacement'
    }

    It 'derives diagnostic identity from the current qualified ID' {
        $Finding = New-NitpickFinding `
            -RuleId 'Example/Test-Rule' `
            -Message 'A problem was found.' `
            -ViolationExtent $Extent `
            -Severity Warning `
            -ScriptPath '<ScriptBlock>' `
            -Explanation 'Test explanation.' `
            -Corrections $Correction `
            -OutputAs NitpickFinding
        $Finding.RuleId = 'NewOwner/RenamedRule'

        $DiagnosticRecord = $Finding.ToDiagnosticRecord()

        $DiagnosticRecord.RuleName | Should -BeExactly RenamedRule
        $DiagnosticRecord.RuleSuppressionID | Should -BeExactly RenamedRule
        $DiagnosticRecord.SuggestedCorrections.Count | Should -Be 1
    }

    It 'rejects invalid identity assigned before diagnostic conversion' {
        $Finding = New-NitpickFinding -RuleId 'Example/TestRule' -Message 'Test' `
            -ViolationExtent $Extent -Severity Warning -ScriptPath '<ScriptBlock>' -Explanation 'Test'
        $Finding.RuleId = 'Unqualified'
        { $Finding.ToDiagnosticRecord() } | Should -Throw '*Namespace/Name*'
    }

    It 'normalizes native and external identity consistently in performance parity keys' {
        $Finding = New-NitpickFinding -RuleId 'Nitpick/TestRule' -Message 'Test' `
            -ViolationExtent $Extent -Severity Warning -ScriptPath '<ScriptBlock>' -Explanation 'Test'
        $ScriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $PSScriptRoot '..\..\..\Scripts\Measure-LinterPerformance.ps1'),
            [ref] $null, [ref] $null
        )
        $KeyFunction = $ScriptAst.Find({
            param ($Node)
            $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $Node.Name -eq 'Get-FindingKey'
        }, $false).Body.GetScriptBlock()

        $NativeKey = & $KeyFunction -Finding $Finding
        $ExternalKey = & $KeyFunction -Finding $Finding.ToDiagnosticRecord()

        $NativeKey | Should -BeExactly $ExternalKey
        $NativeKey | Should -Match '\|Nitpick/TestRule\|'
    }
}
