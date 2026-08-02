Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

Describe 'PleaseWork module exports' {
    It 'exports the runner and its aliases from the module' {
        $Commands = Get-Command Invoke-PleaseWork, pw, please

        $Commands.Name | Should -Be @('Invoke-PleaseWork', 'pw', 'please')
        $Commands.ModuleName | Should -Be @('PleaseWork', 'PleaseWork', 'PleaseWork')
    }

    It 'does not export implementation helpers' {
        Get-Command Get-TaskFileDeclaration -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
        Get-Command Invoke-PleaseWorkTask -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}

