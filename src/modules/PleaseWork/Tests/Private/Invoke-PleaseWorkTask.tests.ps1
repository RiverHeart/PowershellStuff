Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'Invoke-PleaseWorkTask' {
        It 'injects task context and records a successful result without mixing it into output' {
            $Context = @{
                TaskFilePath = 'C:\project\TaskFile.ps1'
                TaskFileRoot = 'C:\project'
            }
            $Result = $null

            $Output = @(Invoke-PleaseWorkTask `
                -Name inspect `
                -ScriptBlock { "$TaskFilePath|$TaskFileRoot"; 'task output' } `
                -Context $Context `
                -Result ([ref] $Result))

            $Output | Should -Be @(
                'C:\project\TaskFile.ps1|C:\project'
                'task output'
            )
            $Result.TaskName | Should -Be 'inspect'
            $Result.Succeeded | Should -BeTrue
            $Result.ExitCode | Should -Be 0
            $Result.Error | Should -BeNullOrEmpty
            $Result.StartedAt | Should -BeOfType ([datetime])
            $Result.FinishedAt | Should -BeOfType ([datetime])
            $Result.Duration | Should -BeOfType ([timespan])
        }

        It 'resets stale native status before invoking a task with no native commands' {
            $global:LASTEXITCODE = 23
            $Result = $null

            Invoke-PleaseWorkTask `
                -Name powershellOnly `
                -ScriptBlock { Write-Output 'done' } `
                -Context @{} `
                -Result ([ref] $Result)

            $Result.Succeeded | Should -BeTrue
            $Result.ExitCode | Should -Be 0
            $LASTEXITCODE | Should -Be 0
        }

        It 'records a terminating error before rethrowing it' {
            $Result = $null

            { Invoke-PleaseWorkTask `
                -Name broken `
                -ScriptBlock { throw 'broken task' } `
                -Context @{} `
                -Result ([ref] $Result) } | Should -Throw 'broken task'

            $Result.TaskName | Should -Be 'broken'
            $Result.Succeeded | Should -BeFalse
            $Result.ExitCode | Should -Be 0
            $Result.Error.Exception.Message | Should -Match 'broken task'
        }
    }
}

