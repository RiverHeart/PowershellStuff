using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation.Language
using module AstEditor

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking project policy' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
    }

    It 'loads policy once and isolates it for each file target' {
        $Seen = [List[object]]::new()
        $Producer = {
            param([ScriptBlockAst] $ScriptBlockAst, [IDictionary] $Context)
            $Seen.Add([pscustomobject]@{
                Policy = $Context.Policy.Compatibility.PowerShell.MinimumVersion
                TargetKind = $Context.TargetKind
                TargetPath = $Context.TargetPath
            })
        }.GetNewClosure()
        $Applicability = {
            param([IDictionary] $Context)
            $Context.Policy.Compatibility.PowerShell.MinimumVersion -eq [version] '5.1'
        }
        Register-Nitpick `
            -Callable $Producer `
            -Name PolicyProbe `
            -Namespace Local `
            -Source Tests `
            -Applicability $Applicability

        $FirstPath = Join-Path $TestDrive 'first.ps1'
        $SecondPath = Join-Path $TestDrive 'second.ps1'
        [IO.File]::WriteAllText($FirstPath, '$Value = 1')
        [IO.File]::WriteAllText($SecondPath, '$Value = 2')
        $ConfigFile = Join-Path $TestDrive 'policy[local].psd1'
        Mock Read-NitpickConfiguration -ModuleName Nitpick {
            @{ Compatibility = @{ PowerShell = @{ MinimumVersion = [version] '5.1' } } }
        }

        $Results = @(
            @($FirstPath, $SecondPath) |
                Start-Nitpicking `
                    -ConfigFile $ConfigFile `
                    -IncludeRule Local/PolicyProbe `
                    -Output Object `
                    -ErrorAction Stop
        )

        Should -Invoke Read-NitpickConfiguration -ModuleName Nitpick -Times 1 -Exactly `
            -ParameterFilter { $LiteralPath -eq $ConfigFile }
        $Seen | Should -HaveCount 2
        foreach ($Entry in $Seen) {
            $Entry.Policy | Should -Be ([version] '5.1')
            $Entry.TargetKind | Should -BeExactly 'File'
        }
        $ExpectedPaths = @($FirstPath, $SecondPath) | Sort-Object
        $SeenPaths = @($Seen.TargetPath | Sort-Object)
        $SeenPaths | Should -Be $ExpectedPaths
        ($Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }).TargetCount |
            Should -Be 2
    }

    It 'treats missing policy as inapplicable without changing selected totals' {
        $State = @{ ProducerCalls = 0 }
        $Producer = {
            param([ScriptBlockAst] $ScriptBlockAst)
            $State.ProducerCalls++
        }.GetNewClosure()

        Register-Nitpick `
            -Callable $Producer `
            -Name PolicyProbe `
            -Namespace Local `
            -Source Tests `
            -Applicability {
                param([IDictionary] $Context)
                $Context.Policy.Count -gt 0
            }

        $Messages = @(
            Start-Nitpicking -Script '$Value = 1' -IncludeRule Local/PolicyProbe `
                -Output Object -Verbose 4>&1
        )

        $Summary = $Messages | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 0
        $State.ProducerCalls | Should -Be 0
        ($Messages -join "`n") | Should -Match "Rule 'Local/PolicyProbe' was inapplicable during original analysis"
    }

    It 'applies explicit policy to fragments without assigning file identity' {
        $Seen = [List[object]]::new()
        Register-Nitpick `
            -Callable ({
                param([ScriptBlockAst] $ScriptBlockAst, [IDictionary] $Context)
                $Seen.Add([pscustomobject]@{
                    Policy = $Context.Policy.Compatibility.PowerShell.MinimumVersion
                    TargetKind = $Context.TargetKind
                    TargetPath = $Context.TargetPath
                })
            }.GetNewClosure()) `
            -Name PolicyProbe `
            -Namespace Local `
            -Source Tests `
            -Applicability {
                param([IDictionary] $Context)
                $Context.Policy.Count -gt 0
            }

        Start-Nitpicking -Script '$Value = 1' `
            -ConfigData @{ Compatibility = @{ PowerShell = @{ MinimumVersion = '5.1' } } } `
            -IncludeRule Local/PolicyProbe `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop | Out-Null

        $Seen | Should -HaveCount 1
        $Seen[0].Policy | Should -Be ([version] '5.1')
        $Seen[0].TargetKind | Should -BeExactly 'Fragment'
        $Seen[0].TargetPath | Should -BeNullOrEmpty
    }

    It 'does not leak a configured policy into a later invocation' {
        $State = @{ ProducerCalls = 0 }
        Register-Nitpick -Callable ({
            param([ScriptBlockAst] $ScriptBlockAst)
            $State.ProducerCalls++
        }.GetNewClosure()) -Name PolicyProbe -Namespace Local -Source Tests `
            -Applicability {
                param([IDictionary] $Context)
                $Context.Policy.Count -gt 0
            }

        $ConfigData = New-NitpickConfiguration -Compatibility @{ PowerShell = @{ MinimumVersion = '5.1' } }

        Start-Nitpicking `
            -Script '$First = 1' `
            -ConfigData $ConfigData `
            -IncludeRule Local/PolicyProbe `
            -Output Object `
            -NoSummary `
            -ErrorAction Stop | Out-Null

        $WithoutPolicy = @(
            Start-Nitpicking -Script '$Second = 2' -IncludeRule Local/PolicyProbe `
                -Output Object -Verbose 4>&1
        )

        $State.ProducerCalls | Should -Be 1
        ($WithoutPolicy -join "`n") |
            Should -Match "Rule 'Local/PolicyProbe' was inapplicable during original analysis"
    }

    It 'rejects ConfigFile and ConfigData together' {
        {
            Start-Nitpicking -Script '$Value = 1' -ConfigFile (Join-Path $TestDrive 'policy.psd1') `
                -ConfigData @{}
        } | Should -Throw -ErrorId 'NitpickConflictingConfiguration*'
    }

    It 'rejects invalid ConfigData without requiring ErrorAction Stop' {
        {
            Start-Nitpicking -Script '$Value = 1' -ConfigData @{ Typo = 1 }
        } | Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
    }

    It 'fails with a configuration error without requiring ErrorAction Stop' {
        {
            Start-Nitpicking -Script '$Value = 1' -ConfigFile (Join-Path $TestDrive 'missing.psd1') `
                -IncludeRule Nitpick/UseIsNotOperator
        } | Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
    }

    It 'validates configured rule settings before reading any target' {
        $ConfigData = @{
            Rules = @{
                'Nitpick/AvoidLongLines' = @{ MaximumLenght = 100 }
            }
        }
        $MissingTarget = Join-Path $TestDrive 'not-read.ps1'

        $ErrorRecord = {
            Start-Nitpicking `
                -Path $MissingTarget `
                -ConfigData $ConfigData `
                -IncludeRule Nitpick/AvoidLongLines
        } | Should -Throw -ErrorId 'NitpickInvalidRuleSettings*' -PassThru

        $ErrorRecord.Exception.Message | Should -BeExactly (
            "Invalid settings for Nitpick rule 'Nitpick/AvoidLongLines' in configuration data: " +
            "unknown setting 'MaximumLenght' (known settings: MaximumLength)."
        )
    }

    It 'names the configuration file in rule settings errors' {
        $ConfigFile = Join-Path $TestDrive 'invalid-rule-settings.psd1'
        Set-Content -LiteralPath $ConfigFile -Value "@{ Rules = @{ 'Nitpick/AvoidLongLines' = @{ MaximumLenght = 100 } } }"

        $ErrorRecord = {
            Start-Nitpicking -Script '$Value = 1' -ConfigFile $ConfigFile -IncludeRule Nitpick/AvoidLongLines
        } | Should -Throw -ErrorId 'NitpickInvalidRuleSettings*' -PassThru

        $ErrorRecord.Exception.Message |
            Should -BeLike "Invalid settings for Nitpick rule 'Nitpick/AvoidLongLines' in configuration '$ConfigFile':*"
    }

    It 'passes configured settings for non-applicable rules through fix mode' {
        $ConfigData = @{
            Rules = @{
                'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 }
            }
        }

        {
            Start-Nitpicking `
                -Script '$Value = 1' `
                -ConfigData $ConfigData `
                -ExcludeRule Nitpick/AvoidLongLines `
                -FixMode Preview `
                -Output Object `
                -NoSummary `
                -ErrorAction Stop
        } | Should -Not -Throw
    }

    It 'rejects settings for a rule unavailable to this invocation before reading targets' {
        $ConfigData = @{
            Rules = @{
                'MissingPackage/Rule' = @{ MaximumLength = 100 }
            }
        }
        $MissingTarget = Join-Path $TestDrive 'not-read.ps1'

        $ErrorRecord = {
            Start-Nitpicking `
                -Path $MissingTarget `
                -ConfigData $ConfigData `
                -IncludeRule Nitpick/AvoidLongLines
        } | Should -Throw "*unknown Nitpick rule ID 'MissingPackage/Rule'*" -PassThru

        $ErrorRecord.Exception.Message | Should -BeLike 'Invalid rule settings in configuration data:*'
    }

    It 'does not save when candidate reanalysis exposes an unsupported rule' {
        $Path = Join-Path $TestDrive 'suppression-removal.ps1'
        $Source = "# nitpick disable-target Local/HostRule`n`$Value = 1"
        [IO.File]::WriteAllText($Path, $Source)

        $HeaderRule = New-Nitpick -Name HeaderFix -Source Tests -Callable {
            param([AstDocument] $Document)
            $Comment = @($Document.Tokens | Where-Object Kind -eq Comment)[0]
            if (-not $Comment) { return }

            $Correction = New-NitpickCorrection `
                -ViolationExtent $Comment.Extent `
                -ReplacementText '# suppression removed' `
                -FilePathOrContext $Document.Path `
                -Description 'Remove the test suppression.'

            New-NitpickFinding `
                -RuleId 'Local/HeaderFix' `
                -Message 'Remove the test suppression.' `
                -ViolationExtent $Comment.Extent `
                -Severity Information `
                -ScriptPath $Document.Path `
                -Corrections $Correction `
                -Explanation 'Allows candidate analysis to reach the host prerequisite.'
        }
        $HostRule = New-Nitpick `
            -Name HostRule `
            -Source Tests `
            -MinimumAnalysisHostVersion ([version] '999.0') `
            -Applicability { $true } `
            -Callable {
                param([ScriptBlockAst] $ScriptBlockAst)
                throw 'The host prerequisite should prevent producer execution.'
            }

        Register-Nitpick -Callable $HeaderRule, $HostRule

        {
            Start-Nitpicking -Path $Path -IncludeRule Local/HeaderFix,Local/HostRule `
                -FixMode Apply -Output Object -Confirm:$false
        } | Should -Throw -ErrorId 'NitpickUnsupportedAnalysisHost*'

        [IO.File]::ReadAllText($Path) | Should -BeExactly $Source
    }
}
