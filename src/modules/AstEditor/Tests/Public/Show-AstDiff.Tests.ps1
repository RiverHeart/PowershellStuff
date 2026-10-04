using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Show-AstDiff' {
    It 'shows all queued edits in sorted order' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "appended"', 'Insert additional greeting after Write-Host')

        $Diff = Show-AstDiff -Document $Overlay

        $Diff | Should -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Match '\[1\] Replace Write-Host with Write-Output'
        $Diff | Should -Match '\[2\] Insert additional greeting after Write-Host'
        $Diff | Should -Match 'prepended'
        $Diff | Should -Match 'appended'
    }

    It 'shows only selected edit indexes' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "appended"', 'Insert additional greeting after Write-Host')

        $Diff = Show-AstDiff -Document $Overlay -EditIndex 1

        $Diff | Should -Match '\[1\] Replace Write-Host with Write-Output'
        $Diff | Should -Not -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Not -Match '\[2\] Insert additional greeting after Write-Host'
    }

    It 'allows selecting the first edit index' {
        $Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

        $Overlay = New-AstDocument -InputObject $Source
        $WriteHostCall = $Overlay.Ast.Find({
                param($Node)
                $Node -is [System.Management.Automation.Language.CommandAst] -and
                $Node.GetCommandName() -eq 'Write-Host'
            }, $true)

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "prepended"', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')

        $Diff = Show-AstDiff -Document $Overlay -EditIndex 0

        $Diff | Should -Match '\[0\] Insert greeting before Write-Host'
        $Diff | Should -Not -Match '\[1\] Replace Write-Host with Write-Output'
    }
}
