Describe 'RelayCommand' -Tag 'RelayCommand' {
    It 'Should compile in Windows PowerShell 5.1' {
        $PowerShellExe = Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue
        $PowerShellExe | Should -Not -BeNullOrEmpty

        $RelayCommandPath = Join-Path $PSScriptRoot '../Private/Classes/RelayCommand.ps1'
        $EscapedRelayCommandPath = $RelayCommandPath -replace "'", "''"

        $Command = "`$ErrorActionPreference = 'Stop'; . '$EscapedRelayCommandPath'; [void][RelayCommand]"
        $Output = & $PowerShellExe.Path -NoProfile -NonInteractive -Command $Command 2>&1
        $ExitCode = $LASTEXITCODE

        $ExitCode | Should -Be 0 -Because ($Output | Out-String)
    }

    It 'Should be idempotent in Windows PowerShell 5.1' {
        $PowerShellExe = Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue
        $PowerShellExe | Should -Not -BeNullOrEmpty

        $RelayCommandPath = Join-Path $PSScriptRoot '../Private/Classes/RelayCommand.ps1'
        $EscapedRelayCommandPath = $RelayCommandPath -replace "'", "''"

        $Command = "`$ErrorActionPreference = 'Stop'; . '$EscapedRelayCommandPath'; . '$EscapedRelayCommandPath'; [void][RelayCommand]"
        $Output = & $PowerShellExe.Path -NoProfile -NonInteractive -Command $Command 2>&1
        $ExitCode = $LASTEXITCODE

        $ExitCode | Should -Be 0 -Because ($Output | Out-String)
    }
}
