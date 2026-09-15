Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'New-PleaseWorkTaskExecutor' {
        It 'creates one configured pipeline in a dedicated runspace' {
            $Executor = $null
            $Runspace = $null
            try {
                $Executor = New-PleaseWorkTaskExecutor `
                    -ScriptBlock {
                        param ($InputValue)

                        "$Marker|$InputValue|$($PWD.ProviderPath)"
                    } `
                    -Parameters @{ InputValue = 'parameter' } `
                    -Variables @{ Marker = 'variable' } `
                    -WorkingDirectory $TestDrive
                $Runspace = $Executor.Runspace

                $Executor | Should -BeOfType ([powershell])
                @($Executor.Invoke()) | Should -Be @(
                    "variable|parameter|$((Resolve-Path -LiteralPath $TestDrive).ProviderPath)"
                )
            } finally {
                if ($null -ne $Executor) { $Executor.Dispose() }
                if ($null -ne $Runspace) { $Runspace.Dispose() }
            }
        }
    }
}
