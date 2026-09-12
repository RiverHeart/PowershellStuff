Describe 'WpfDesigner scaffold' -Tag 'WpfDesigner' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../modules/WPF/WPF.psd1" -Force
    }

    It 'Should launch and auto-close without error' {
        $ScriptPath = "$PSScriptRoot/../app.ps1"

        $Output = & pwsh -NoProfile -NonInteractive -Command {
            param($Path)
            $env:WPF_AUTO_CLOSE_SECONDS = 0
            & $Path
        } -args $ScriptPath 2>&1

        $LASTEXITCODE | Should -Be -ExpectedValue 0 -Because ($Output | Out-String)
    }
}
