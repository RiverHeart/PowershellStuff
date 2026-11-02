BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name "$PSScriptRoot/../../../../AstEditor/AstEditor.psd1" -Force
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickCorrection' {
    BeforeAll {
        $Extent = { $Value }.Ast.EndBlock.Statements[0].Extent
    }

    It 'creates a Nitpick correction from an extent' {
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.'

        $Correction.GetType().Name | Should -Be 'NitpickCorrection'
        $Correction.TextEdit.GetType().Name | Should -Be 'AstTextEdit'
        $Correction.StartLineNumber | Should -Be $Extent.StartLineNumber
        $Correction.StartOffset | Should -Be $Extent.StartOffset
        $Correction.EndOffset | Should -Be $Extent.EndOffset
        $Correction.HasOffsets | Should -BeTrue
        $Correction.ExpectedText | Should -Be $Extent.Text
        $Correction.ReplacementText | Should -Be '$Replacement'
        $Correction.Description | Should -Be 'Replace the value.'
    }

    It 'creates a Nitpick correction from line and column positions' {
        $Correction = New-NitpickCorrection `
            -StartLineNumber 1 `
            -EndLineNumber 2 `
            -StartColumnNumber 3 `
            -EndColumnNumber 4 `
            -ReplacementText 'replacement' `
            -FilePathOrContext 'Test.ps1' `
            -Description 'Replace text.'

        $Correction.StartLineNumber | Should -Be 1
        $Correction.EndLineNumber | Should -Be 2
        $Correction.StartColumnNumber | Should -Be 3
        $Correction.EndColumnNumber | Should -Be 4
        $Correction.HasOffsets | Should -BeFalse
        $Correction.StartOffset | Should -Be -1
        $Correction.ExpectedText | Should -BeNullOrEmpty
    }

    It 'creates a correction from explicit offsets' {
        $Correction = New-NitpickCorrection `
            -StartLineNumber 1 `
            -EndLineNumber 1 `
            -StartColumnNumber 2 `
            -EndColumnNumber 4 `
            -StartOffset 1 `
            -EndOffset 3 `
            -ExpectedText 'bc' `
            -ReplacementText 'BC' `
            -FilePathOrContext 'Test.ps1' `
            -Description 'Replace text.' `
            -Applicability Review `
            -ChangeSetId 'changeset-1' `
            -RuleId 'Example/ExampleRule'

        $Correction.HasOffsets | Should -BeTrue
        $Correction.StartOffset | Should -Be 1
        $Correction.EndOffset | Should -Be 3
        $Correction.ExpectedText | Should -Be 'bc'
        $Correction.Applicability | Should -Be 'Review'
        $Correction.ChangeSetId | Should -Be 'changeset-1'
        $Correction.RuleId | Should -Be 'Example/ExampleRule'
    }

    It 'creates a correction from an AstEditor collection edit' {
        $Document = New-AstDocument `
            -InputObject 'param([Parameter(Position=0,Mandatory=$false)] [string] $Name)'
        $ParameterAttribute = $Document.Ast.Find({
            param ($Node)

            $Node -is [System.Management.Automation.Language.AttributeAst]
        }, $false)
        $Argument = $ParameterAttribute.NamedArguments | Where-Object ArgumentName -eq 'Mandatory'
        $TextEdit = New-AstCollectionEdit `
            -Remove $Argument `
            -From $ParameterAttribute.NamedArguments `
            -Within $ParameterAttribute

        $Correction = New-NitpickCorrection `
            -TextEdit $TextEdit `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Remove the argument.'

        $Correction.TextEdit | Should -Be $TextEdit
        $Correction.StartOffset | Should -Be $TextEdit.StartOffset
        $Correction.EndOffset | Should -Be $TextEdit.EndOffset
        $Correction.ExpectedText | Should -Be ',Mandatory=$false'
        $Correction.ReplacementText | Should -Be ''
    }

    It 'accepts explicit standalone identity with <Construction> construction' -ForEach @(
        @{ Construction = 'Extent' }
        @{ Construction = 'TextEdit' }
        @{ Construction = 'Offset' }
        @{ Construction = 'LineAndColumn' }
    ) {
        $Parameters = @{
            RuleId = 'Example/TestRule'; FilePathOrContext = '<ScriptBlock>'
            Description = 'Replace the value.'
        }
        switch ($Construction) {
            'Extent' {
                $Parameters.ViolationExtent = $Extent
                $Parameters.ReplacementText = '$Replacement'
            }
            'TextEdit' {
                $Parameters.TextEdit = New-AstTextEdit -Extent $Extent `
                    -ReplacementText '$Replacement' -Reason 'Replace the value.'
            }
            default {
                $Parameters.StartLineNumber = 1
                $Parameters.EndLineNumber = 1
                $Parameters.StartColumnNumber = 1
                $Parameters.EndColumnNumber = 7
                $Parameters.ReplacementText = '$Replacement'
                if ($Construction -eq 'Offset') {
                    $Parameters.StartOffset = 0
                    $Parameters.EndOffset = 6
                    $Parameters.ExpectedText = '$Value'
                }
            }
        }
        $Correction = New-NitpickCorrection @Parameters

        $Correction.RuleId | Should -BeExactly 'Example/TestRule'
        $Correction.ReplacementText | Should -BeExactly '$Replacement'
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
            New-NitpickCorrection -RuleId $RuleId -ViolationExtent $Extent `
                -ReplacementText '$Replacement' -FilePathOrContext '<ScriptBlock>' `
                -Description 'Invalid identity.'
        } | Should -Throw
    }

    It 'validates explicit identity in the correction hashtable constructor' {
        InModuleScope Nitpick {
            $Properties = @{
                RuleId = 'Example/TestRule'
                StartLineNumber = 1; EndLineNumber = 1
                StartColumnNumber = 1; EndColumnNumber = 2
                ReplacementText = 'x'; Description = 'Constructor identity.'
            }
            $Correction = [NitpickCorrection]::new($Properties)
            $Correction.RuleId | Should -BeExactly 'Example/TestRule'
            $Properties.RuleId = 'Unqualified'
            { [NitpickCorrection]::new($Properties) } | Should -Throw '*Namespace/Name*'
        }
    }

    It 'rejects unknown correction constructor keys' -ForEach @(
        @{ Key = 'RuleName' }
        @{ Key = 'NotARealKey' }
    ) {
        InModuleScope Nitpick -Parameters @{ Key = $Key } {
            param ($Key)
            $Properties = @{ RuleId = 'Example/TestRule' }
            $Properties[$Key] = 'Unknown'
            { [NitpickCorrection]::new($Properties) } |
                Should -Throw "*Unknown NitpickCorrection constructor key '$Key'*"
        }
    }

    It 'converts an explicitly attributed correction to a CorrectionExtent' {
        $Correction = New-NitpickCorrection -RuleId 'Example/TestRule' -ViolationExtent $Extent `
            -ReplacementText '$Replacement' -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.' -OutputAs CorrectionExtent

        $Correction.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent'
        $Correction.Text | Should -BeExactly '$Replacement'
    }

    It 'supports insertion and multiline offset ranges' {
        $Insertion = New-NitpickCorrection `
            -StartLineNumber 1 -EndLineNumber 1 `
            -StartColumnNumber 1 -EndColumnNumber 1 `
            -StartOffset 0 -EndOffset 0 `
            -ExpectedText '' -ReplacementText 'prefix' `
            -FilePathOrContext '<ScriptBlock>' -Description 'Insert a prefix.'
        $Multiline = New-NitpickCorrection `
            -StartLineNumber 1 -EndLineNumber 2 `
            -StartColumnNumber 1 -EndColumnNumber 2 `
            -StartOffset 0 -EndOffset 4 `
            -ExpectedText "a`r`nb" -ReplacementText 'c' `
            -FilePathOrContext '<ScriptBlock>' -Description 'Replace multiline text.'

        $Insertion.ExpectedText | Should -Be ''
        $Insertion.StartOffset | Should -Be $Insertion.EndOffset
        $Multiline.ExpectedText | Should -Be "a`r`nb"
    }

    It 'rejects invalid offset and coordinate ranges' {
        {
            New-NitpickCorrection `
                -StartLineNumber 1 -EndLineNumber 1 `
                -StartColumnNumber 4 -EndColumnNumber 2 `
                -StartOffset 3 -EndOffset 1 `
                -ExpectedText '' -ReplacementText 'x' `
                -FilePathOrContext '<ScriptBlock>' -Description 'Invalid range.'
        } | Should -Throw
    }

    It 'rejects expected text whose length does not match the offset range' {
        {
            New-NitpickCorrection `
                -StartLineNumber 1 -EndLineNumber 1 `
                -StartColumnNumber 1 -EndColumnNumber 3 `
                -StartOffset 0 -EndOffset 2 `
                -ExpectedText 'x' -ReplacementText 'X' `
                -FilePathOrContext '<ScriptBlock>' -Description 'Mismatched text.'
        } | Should -Throw '*ExpectedText length must match*'
    }

    It 'converts a correction to a ScriptAnalyzer CorrectionExtent' {
        $Correction = New-NitpickCorrection `
            -ViolationExtent $Extent `
            -ReplacementText '$Replacement' `
            -FilePathOrContext '<ScriptBlock>' `
            -Description 'Replace the value.' `
            -OutputAs CorrectionExtent

        $Correction.GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent'
        $Correction.Text | Should -Be '$Replacement'
        $Correction.Description | Should -Be 'Replace the value.'
    }
}
