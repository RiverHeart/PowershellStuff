BeforeAll {
    Import-Module "$PSScriptRoot\..\..\AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-PowerShellData' {
    It 'converts nested literal data from a string' {
        $Result = ConvertFrom-PowerShellData -String @'
@{
    Key = 'Value'
    Numbers = @(1, 2)
    Nested = @{ Enabled = $true; Empty = $null }
}
'@

        $Result.GetType() | Should -Be ([hashtable])
        $Result.Key | Should -Be 'Value'
        $Result.Numbers | Should -Be @(1, 2)
        $Result.Nested.Enabled | Should -BeTrue
        $Result.Nested.Empty | Should -BeNullOrEmpty
    }

    It 'accepts pipeline strings independently' {
        $Results = @(
            "@{ Number = 1 }"
            "@{ Number = 2 }"
        ) | ConvertFrom-PowerShellData

        $Results | Should -HaveCount 2
        $Results[0].Number | Should -Be 1
        $Results[1].Number | Should -Be 2
    }

    It 'reports syntax errors with a stable ErrorId' {
        {
            ConvertFrom-PowerShellData -String '@{ Key =' -ErrorAction Stop
        } | Should -Throw -ErrorId 'AstEditorPowerShellDataInvalidSyntax*'
    }

    It 'reports input without a hashtable with a stable ErrorId' {
        {
            ConvertFrom-PowerShellData -String "'not a hashtable'" -ErrorAction Stop
        } | Should -Throw -ErrorId 'AstEditorPowerShellDataNoHashtable*'
    }

    It 'emits one error with a stable ErrorId and the original exception for a dynamic expression' {
        $Records = @(
            ConvertFrom-PowerShellData -String '@{ Value = (Get-Date) }' `
                -ErrorAction Continue 2>&1
        )

        $Records | Should -HaveCount 1
        $Records[0] | Should -BeOfType ([System.Management.Automation.ErrorRecord])
        $Records[0].FullyQualifiedErrorId |
            Should -Match '^AstEditorPowerShellDataEvaluationFailed,'
        $Records[0].Exception | Should -BeOfType ([InvalidOperationException])
        $Records[0].CategoryInfo.Category.ToString() | Should -Be 'InvalidData'
    }

    It 'honors ErrorAction Stop for a dynamic expression' {
        {
            ConvertFrom-PowerShellData -String '@{ Value = (Get-Date) }' -ErrorAction Stop
        } | Should -Throw -ErrorId 'AstEditorPowerShellDataEvaluationFailed*'
    }

    It 'does not carry a failed evaluation into subsequent pipeline inputs' {
        $Records = @(
            @(
                '@{ Value = (Get-Date) }'
                '@{ Number = 2 }'
                '@{ Number ='
                '@{ Number = 3 }'
            ) | ConvertFrom-PowerShellData -ErrorAction Continue 2>&1
        )

        $Records | Should -HaveCount 4
        $Records[0].FullyQualifiedErrorId |
            Should -Match '^AstEditorPowerShellDataEvaluationFailed,'
        $Records[1].Number | Should -Be 2
        $Records[2].FullyQualifiedErrorId |
            Should -Match '^AstEditorPowerShellDataInvalidSyntax,'
        $Records[3].Number | Should -Be 3
    }

    It 'handles SkipLimitCheck according to the host edition' {
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            {
                ConvertFrom-PowerShellData -String '@{}' -SkipLimitCheck -ErrorAction Stop
            } | Should -Throw -ErrorId 'AstEditorPowerShellDataSkipLimitCheckNotSupported*'
        } else {
            $Text = '@{' + ((1..501 | ForEach-Object { "Key$_ = $_" }) -join ';') + '}'
            {
                ConvertFrom-PowerShellData -String $Text -ErrorAction Stop
            } | Should -Throw -ErrorId 'AstEditorPowerShellDataEvaluationFailed*'

            $Result = ConvertFrom-PowerShellData -String $Text -SkipLimitCheck -ErrorAction Stop
            $Result.GetType() | Should -Be ([hashtable])
            $Result.Count | Should -Be 501
        }
    }
}
