BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'TabExpansion2 custom behavior' {
    BeforeEach {
        Reset-TabExpansion2
        Disable-TabCentral | Out-Null
    }

    It 'returns CommandCompletion when TabCentral is disabled' {
        $Result = TabExpansion2 -inputScript 'Write-Hos' -cursorColumn 9

        $Result | Should -BeOfType ([System.Management.Automation.CommandCompletion])
        @($Result.CompletionMatches).Count | Should -BeGreaterThan 0
    }

    It 'returns CommandCompletion when TabCentral is enabled and no hooks are registered' {
        Enable-TabCentral | Out-Null

        $Result = TabExpansion2 -inputScript 'Write-Hos' -cursorColumn 9

        $Result | Should -BeOfType ([System.Management.Automation.CommandCompletion])
        @($Result.CompletionMatches).Count | Should -BeGreaterThan 0
    }

    It 'uses the first custom completer CommandCompletion result when enabled' {
        Enable-TabCentral | Out-Null

        Register-TabCentralHook -Type Completer -Name CustomCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )

            [System.Management.Automation.CommandCompletion]::CompleteInput('Get-Chi', 7, $null)
        }

        $Result = TabExpansion2 -inputScript 'Write-Hos' -cursorColumn 9
        $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

        $Texts | Should -Contain 'Get-ChildItem'
        $Texts | Should -Not -Contain 'Write-Host'
    }

    It 'falls back to default completion when a completer throws' {
        Enable-TabCentral | Out-Null

        Register-TabCentralHook -Type Completer -Name ThrowingCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )

            throw 'Completer failure'
        }

        $Result = TabExpansion2 -inputScript 'Write-Hos' -cursorColumn 9
        $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

        $Texts | Should -Contain 'Write-Host'
    }

    It 'applies modifier hook output when it returns a CommandCompletion' {
        Enable-TabCentral | Out-Null

        Register-TabCentralHook -Type Completer -Name BaseCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )

            [System.Management.Automation.CommandCompletion]::CompleteInput('Get-Chi', 7, $null)
        }

        Register-TabCentralHook -Type Modifier -Name ReplaceModifier -Source Tests -Callable {
            param (
                [System.Management.Automation.CommandCompletion] $CommandCompletion
            )

            [System.Management.Automation.CommandCompletion]::CompleteInput('Write-Hos', 9, $null)
        }

        $Result = TabExpansion2 -inputScript 'Whatever' -cursorColumn 8
        $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

        $Texts | Should -Contain 'Write-Host'
        $Texts | Should -Not -Contain 'Get-ChildItem'
    }

    It 'ignores modifier output when it is not a CommandCompletion' {
        Enable-TabCentral | Out-Null

        Register-TabCentralHook -Type Completer -Name BaseCompleter -Source Tests -Callable {
            param (
                [string] $inputScript,
                [int] $cursorColumn,
                [System.Management.Automation.Language.Ast] $ast,
                [System.Management.Automation.Language.Token[]] $tokens,
                [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,
                [hashtable] $options
            )

            [System.Management.Automation.CommandCompletion]::CompleteInput('Get-Chi', 7, $null)
        }

        Register-TabCentralHook -Type Modifier -Name InvalidModifier -Source Tests -Callable {
            param (
                [System.Management.Automation.CommandCompletion] $CommandCompletion
            )

            'not-a-completion-object'
        }

        $Result = TabExpansion2 -inputScript 'Whatever' -cursorColumn 8
        $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

        $Texts | Should -Contain 'Get-ChildItem'
    }

    It 'auto-completes function names when enabled with no hooks' {
        Enable-TabCentral | Out-Null

        $Result = TabExpansion2 -inputScript 'Write-Hos' -cursorColumn 9
        $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

        $Texts | Should -Contain 'Write-Host'
    }

    It 'auto-completes variable names when enabled with no hooks' {
        Enable-TabCentral | Out-Null

        $Result = TabExpansion2 -inputScript '$PSVer' -cursorColumn 6
        $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

        $Texts | Should -Contain '$PSVersionTable'
    }

    It 'auto-completes file paths when enabled with no hooks' {
        Enable-TabCentral | Out-Null

        $FileName = 'tabcentral-completion-target.txt'
        $FilePath = Join-Path -Path $TestDrive -ChildPath $FileName
        Set-Content -Path $FilePath -Value 'ok' -Encoding UTF8

        Push-Location -Path $TestDrive
        try {
            $InputScript = '.\\tabcentral-completion-t'
            $Result = TabExpansion2 -inputScript $InputScript -cursorColumn $InputScript.Length
            $Texts = @($Result.CompletionMatches | ForEach-Object { $_.CompletionText })

            @($Texts | Where-Object { $_ -match 'tabcentral-completion-target\.txt' }).Count | Should -BeGreaterThan 0
        } finally {
            Pop-Location
        }
    }
}
