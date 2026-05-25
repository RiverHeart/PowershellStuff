Describe 'Update-WPFObject strict unexpected child mode' -Tag 'Update-WPFObject' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force -ErrorAction Stop
        $script:OriginalStrictValue = [Environment]::GetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD')
    }

    AfterAll {
        [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', $script:OriginalStrictValue)
    }

    It 'Should warn and continue by default for unexpected child objects' {
        InModuleScope WPF {
            [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', $null)
            Mock Write-Warning {}

            {
                Update-WPFObject -InputObject ([System.Windows.Controls.Grid]::new()) -ChildObjects @([pscustomobject]@{ Foo = 1 })
            } | Should -Not -Throw

            Should -Invoke Write-Warning -Times 1 -Exactly
        }
    }

    It 'Should throw when strict unexpected child mode is enabled' {
        InModuleScope WPF {
            [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', '1')

            {
                Update-WPFObject -InputObject ([System.Windows.Controls.Grid]::new()) -ChildObjects @([pscustomobject]@{ Foo = 1 })
            } | Should -Throw -ExpectedMessage "Cannot add '__Nameless__' (PSCustomObject)*"
        }
    }
}
