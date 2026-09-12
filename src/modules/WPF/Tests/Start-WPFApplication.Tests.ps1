Describe 'Start-WPFApplication' -Tag 'Start-WPFApplication' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeAll {
        $script:ApplicationRoot = Join-Path $TestDrive 'TestApplication'
        $script:ViewRoot = Join-Path $script:ApplicationRoot 'src/Views'
        $script:ModulePath = Join-Path $script:ApplicationRoot 'TestApplication.psd1'
        $script:EntryPoint = 'src/Views/main.gui.ps1'

        $null = New-Item -Path $script:ViewRoot -ItemType Directory -Force

        @'
function Invoke-PrivateApplicationCommand {
    'private application command reached'
}

Export-ModuleMember -Function @()
'@ | Set-Content -Path (Join-Path $script:ApplicationRoot 'TestApplication.psm1') -Encoding UTF8

        New-ModuleManifest `
            -Path $script:ModulePath `
            -RootModule 'TestApplication.psm1' `
            -ModuleVersion '1.0.0' `
            -FunctionsToExport @()

        'Invoke-PrivateApplicationCommand' |
            Set-Content -Path (Join-Path $script:ApplicationRoot $script:EntryPoint) -Encoding UTF8
    }

    It 'Runs the entry point in application module scope' {
        $Result = Start-WPFApplication `
            -ModulePath $script:ModulePath `
            -EntryPoint $script:EntryPoint `
            -Force

        $Result | Should -Be 'private application command reached'
    }

    It 'Rejects an entry point outside the application module root' {
        $OutsideEntryPoint = Join-Path $TestDrive 'outside.ps1'
        "'outside'" | Set-Content -Path $OutsideEntryPoint -Encoding UTF8

        {
            Start-WPFApplication `
                -ModulePath $script:ModulePath `
                -EntryPoint '../outside.ps1' `
                -Force
        } | Should -Throw '*outside module root*'
    }

    It 'Reports a missing entry point' {
        {
            Start-WPFApplication `
                -ModulePath $script:ModulePath `
                -EntryPoint 'src/Views/missing.gui.ps1' `
                -Force
        } | Should -Throw '*was not found*'
    }
}
