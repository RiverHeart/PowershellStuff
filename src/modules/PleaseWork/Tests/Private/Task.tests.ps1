Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'Task' {
        It 'registers a task without writing to the output pipeline' {
            $Registry = [System.Collections.Generic.List[hashtable]]::new()
            $Body = { 'build' }
            $Help = Get-TaskHelp -Comments @(
                '<# .DESCRIPTION Builds the project. #>'
            )

            $Output = @(Task `
                -Name build `
                -Help $Help `
                -Registry $Registry `
                -Dependencies test, lint `
                -PathSpecs ./Public, ./Private `
                -ScriptBlock $Body)

            $Output | Should -BeNullOrEmpty
            $Registry.Count | Should -Be 1
            $Registry[0].Name | Should -Be 'build'
            $Registry[0].Help | Should -Be $Help
            $Registry[0].Dependencies | Should -Be @('test', 'lint')
            $Registry[0].PathSpecs | Should -Be @('./Public', './Private')
            $Registry[0].ScriptBlock | Should -Be $Body
        }

        It 'requires a scriptblock' {
            $Registry = [System.Collections.Generic.List[hashtable]]::new()

            { Task -Name build -Registry $Registry -ScriptBlock $null } | Should -Throw
            $Registry | Should -BeNullOrEmpty
        }
    }
}

