using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'AstDocument line helpers' {
    It 'rejects non-AstDocument arguments at runtime' {
        { Resolve-AstDocument -Document ([pscustomobject] @{}) } |
            Should -Throw
    }

    It 'renders prepend, replace, and append edits in the expected order and indentation' {
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

        $Overlay.PrependLine($WriteHostCall, 'Write-Output "....testing, mic check..."', 'Insert greeting before Write-Host')
        $Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
        $Overlay.AppendLine($WriteHostCall, 'Write-Output "Welcome to the AstOverlayLab!"', 'Insert additional greeting after Write-Host')

        $Validation = Resolve-AstDocument -Document $Overlay -PassThruText
        $Validation.ParseErrorCount | Should -Be 0
        $Validation.EditCount | Should -Be 3
        $Validation.RenderedText | Should -Be @'
function Greet {
    param([string] $Name)
    Write-Output "....testing, mic check..."
    Write-Output "Hello, $Name!"
    Write-Output "Welcome to the AstOverlayLab!"
}
'@
    }
}
