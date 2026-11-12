using module AstEditor

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Nitpick plain-data context' {
    It 'copies every supported scalar without changing its type or value' {
        InModuleScope Nitpick {
            $Values = @(
                '', 'text', $true, $false,
                [sbyte]::MinValue, [byte]::MaxValue, [int16]::MinValue, [uint16]::MaxValue,
                [int32]::MinValue, [uint32]::MaxValue, [int64]::MinValue, [uint64]::MaxValue,
                [single] 1.23456789, [double] 1.2345678901234567, [decimal]::MaxValue,
                [version] '5.1', [version] '7.4.1.2'
            )
            foreach ($Value in $Values) {
                $Copy = Copy-NitpickContextValue -Value $Value
                $Copy.GetType() | Should -Be $Value.GetType()
                $Copy | Should -BeExactly $Value
            }
            $Copy = Copy-NitpickContextValue -Value $null
            $Copy | Should -BeNullOrEmpty
        }
    }

    It 'preserves empty, singleton, nested, typed arrays and null elements' {
        InModuleScope Nitpick {
            $Value = @($null, @(), @(,$null), @(,@(1, 2)), [int[]] @(3, 4))
            $Copy = Copy-NitpickContextValue -Value $Value
            $Copy.GetType() | Should -Be ([object[]])
            $Copy.Count | Should -Be 5
            $Copy[0] | Should -BeNullOrEmpty
            $Copy[1].GetType() | Should -Be ([object[]])
            $Copy[1].Count | Should -Be 0
            $Copy[2].Count | Should -Be 1
            $Copy[2][0] | Should -BeNullOrEmpty
            $Copy[3].Count | Should -Be 1
            $Copy[3][0] | Should -Be @(1, 2)
            $Copy[4].GetType() | Should -Be ([object[]])
            $Copy[4] | Should -Be @(3, 4)
        }
    }

    It 'copies repeated references independently and normalizes dictionary keys' {
        InModuleScope Nitpick {
            $Shared = [ordered]@{ Value = @(1) }
            $Copy = Copy-NitpickContextValue -Value @{ Left = $Shared; Right = $Shared }
            $Copy.Left | Should -BeOfType ([hashtable])
            $Copy.left.value[0] = 2
            $Copy.Right.Value[0] | Should -Be 1
            $Shared.Value[0] | Should -Be 1
            [object]::ReferenceEquals($Copy.Left, $Copy.Right) | Should -BeFalse
        }
    }

    It 'rejects dictionary and array cycles with a key/index path' {
        InModuleScope Nitpick {
            $Dictionary = @{}
            $Dictionary.Self = $Dictionary
            { Copy-NitpickContextValue -Value $Dictionary } |
                Should -Throw '*Context.Self*' -ErrorId 'NitpickInvalidContext*'
            $Array = [object[]]::new(1)
            $Array[0] = $Array
            { Copy-NitpickContextValue -Value @{ Nested = $Array } } |
                Should -Throw '*Context.Nested`[0`]*' -ErrorId 'NitpickInvalidContext*'
        }
    }

    It 'rejects non-string and case-duplicate dictionary keys' {
        InModuleScope Nitpick {
            { Copy-NitpickContextValue -Value @{ 1 = 'value' } } |
                Should -Throw -ErrorId 'NitpickInvalidContext*'
            $Dictionary = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
            $Dictionary.Add('Name', 1)
            $Dictionary.Add('name', 2)
            { Copy-NitpickContextValue -Value $Dictionary } |
                Should -Throw -ErrorId 'NitpickInvalidContext*'
        }
    }

    It 'rejects unsupported values explicitly with their paths' {
        InModuleScope Nitpick {
            foreach ($Value in @(
                    [pscustomobject]@{ Value = 1 }, { 'code' }, {}.Ast,
                    (Get-Module Nitpick), [datetime]::Now, [char] 'a',
                    [System.Collections.ArrayList]::new(), [int[,]]::new(1, 1)
                )) {
                { Copy-NitpickContextValue -Value @{ Extra = $Value } } |
                    Should -Throw '*Context.Extra*' -ErrorId 'NitpickInvalidContext*'
            }
        }
    }

    It 'does not copy ETS additions or shadowed dictionary members' {
        InModuleScope Nitpick {
            $Dictionary = @{ Count = 'entry'; Nested = @{ Value = 1 } }
            Add-Member -InputObject $Dictionary -NotePropertyName Count -NotePropertyValue 999 -Force
            Add-Member -InputObject $Dictionary -NotePropertyName Keys -NotePropertyValue @('spoof') -Force
            Add-Member -InputObject $Dictionary -NotePropertyName Extra -NotePropertyValue 'ETS'
            Add-Member -InputObject $Dictionary -MemberType ScriptMethod -Name GetType -Value { [string] } -Force
            $Copy = Copy-NitpickContextValue -Value $Dictionary
            $Copy['Count'] | Should -BeExactly 'entry'
            $Copy.psbase.Count | Should -Be 2
            $Copy.psobject.Properties['Extra'] | Should -BeNullOrEmpty
            $Copy.Nested.Value | Should -Be 1
        }
    }

    It 'ignores ETS array shape shadowing and preserves non-zero lower bounds' {
        InModuleScope Nitpick {
            $Value = [array]::CreateInstance([object], [int[]] @(2), [int[]] @(3))
            $Value.SetValue('first', 3)
            $Value.SetValue($null, 4)
            Add-Member -InputObject $Value -NotePropertyName Length -NotePropertyValue 999 -Force
            Add-Member -InputObject $Value -NotePropertyName Rank -NotePropertyValue 2 -Force
            $Copy = Copy-NitpickContextValue -Value $Value
            $Copy.GetType() | Should -Be ([object[]])
            $Copy.Length | Should -Be 2
            $Copy[0] | Should -BeExactly 'first'
            $Copy[1] | Should -BeNullOrEmpty
        }
    }

    It 'materializes clean scalar instances without attached ETS members' {
        InModuleScope Nitpick {
            # WARNING: ETS members attach to the boxed instance. A literal $true is PowerShell's shared
            # boxed singleton, so decorating it would change every later $true in the process.
            foreach ($Value in @('scalar', [version] '5.1', [int] 12345, [double] 1.23, [bool]::Parse('True'))) {
                $Wrapped = [psobject]::AsPSObject($Value)
                Add-Member -InputObject $Wrapped -NotePropertyName Extra -NotePropertyValue 'ETS'
                Add-Member -InputObject $Wrapped -MemberType ScriptMethod -Name GetType -Value { [datetime] } -Force
                Add-Member -InputObject $Wrapped -MemberType ScriptMethod -Name ToString -Value { 'shadow' } -Force
                $Copy = Copy-NitpickContextValue -Value $Wrapped
                $Copy | Should -Be $Value
                $Copy.psobject.Properties['Extra'] | Should -BeNullOrEmpty
            }
        }
    }

    It 'constructs fragment defaults without mutating caller data' {
        InModuleScope Nitpick {
            $Context = @{ Extra = @{ Values = @(1) } }
            $Copy = New-NitpickInvocationContext -Target {}.Ast -Context $Context
            $Copy.Caller | Should -BeExactly 'Nitpick'
            $Copy.RuleBehavior.SearchNestedScriptBlocks | Should -BeTrue
            $Copy.RuleBehavior.OutputType | Should -BeExactly 'NitpickFinding'
            $Copy.Policy.Count | Should -Be 0
            $Copy.TargetKind | Should -BeExactly 'Fragment'
            $Copy.ContainsKey('TargetPath') | Should -BeTrue
            $Copy.TargetPath | Should -BeNullOrEmpty
            $Copy.AnalysisHost.PowerShellVersion | Should -Be ([version] $PSVersionTable.PSVersion.ToString())
            $Copy.Extra.Values[0] = 2
            $Context.Extra.Values[0] | Should -Be 1
            $Context.Count | Should -Be 1
        }
    }

    It 'preserves explicit legacy values and partial RuleBehavior' {
        InModuleScope Nitpick {
            $Copy = New-NitpickInvocationContext -Target {}.Ast -Context @{
                Caller = $null
                File = 'legacy'
                RuleBehavior = @{ OutputType = 'DiagnosticRecord' }
            }
            $Copy.Caller | Should -BeNullOrEmpty
            $Copy.File | Should -BeExactly 'legacy'
            $Copy.RuleBehavior.Count | Should -Be 1
            $Copy.RuleBehavior.OutputType | Should -BeExactly 'DiagnosticRecord'
        }
    }

    It 'distinguishes a file document from AST provenance and in-memory documents' {
        InModuleScope Nitpick {
            $Path = Join-Path $TestDrive 'source.ps1'
            Set-Content -LiteralPath $Path -Value '# text'
            $Document = New-AstDocument -Path $Path
            $Copy = New-NitpickInvocationContext -Target $Document
            $Copy.TargetKind | Should -BeExactly 'File'
            $Copy.TargetPath | Should -BeExactly $Document.Path
            foreach ($Target in @($Document.Ast, (New-AstDocument -InputObject $Document.Ast))) {
                $Fragment = New-NitpickInvocationContext -Target $Target
                $Fragment.TargetKind | Should -BeExactly 'Fragment'
                $Fragment.TargetPath | Should -BeNullOrEmpty
                $Fragment.File | Should -BeExactly $Document.Path
            }
            $Again = New-NitpickInvocationContext -Target $Document -Context $Copy
            $Again.TargetPath | Should -BeExactly $Document.Path
        }
    }

    It 'uses the shared release catalog for direct policy strings and versions' {
        InModuleScope Nitpick {
            foreach ($Release in @('5.1', '6.0', '6.1', '6.2', '7.0', '7.1', '7.2', '7.3', '7.4', '7.5', '7.6')) {
                foreach ($Minimum in @($Release, [version] $Release)) {
                    $InputContext = @{ Policy = @{ Compatibility = @{ PowerShell = @{ MinimumVersion = $Minimum } } } }
                    $Copy = New-NitpickInvocationContext -Target {}.Ast -Context $InputContext
                    $Copy.Policy.Compatibility.PowerShell.MinimumVersion | Should -Be ([version] $Release)
                }
            }
        }
    }

    It 'rejects invalid reserved-key shapes and identity or host spoofing' {
        InModuleScope Nitpick {
            foreach ($Context in @(
                    'not a dictionary',
                    @{ Policy = $null },
                    @{ Policy = @{ Typo = @{} } },
                    @{ Policy = @{ Keys = @() } },
                    @{ Policy = @{ Compatibility = @{ PowerShell = @{ MinimumVersion = [version] '7.4.0' } } } },
                    @{ Policy = @{ Compatibility = @{ PowerShell = @{ MinimumVersion = '99.0' } } } },
                    @{ TargetKind = 'File' },
                    @{ TargetKind = $null },
                    @{ TargetPath = 'C:\spoof.ps1' },
                    @{ TargetPath = @() },
                    @{ AnalysisHost = $null },
                    @{ AnalysisHost = @{} },
                    @{ AnalysisHost = @{ PowerShellVersion = [version] '99.0' } },
                    @{ AnalysisHost = @{ PowerShellVersion = [version] $PSVersionTable.PSVersion; Count = 1 } },
                    @{ AnalysisHost = @{ PowerShellVersion = $PSVersionTable.PSVersion.ToString() } }
                )) {
                { New-NitpickInvocationContext -Target {}.Ast -Context $Context } |
                    Should -Throw -ErrorId 'NitpickInvalidContext*'
            }
        }
    }
}
