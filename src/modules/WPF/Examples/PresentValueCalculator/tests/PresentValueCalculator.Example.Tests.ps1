Describe 'PresentValueCalculator Example' -Tag 'PresentValueCalculator-Example' {
    It 'Should default Max input to a value greater than or equal to Amount' {
        $scriptPath = Join-Path $PSScriptRoot '../PresentValueCalculator.DSL.ps1'
        $content = Get-Content -Path $scriptPath -Raw

        $amountMatch = [regex]::Match($content, '(?m)^\$Amount\s*=\s*(?<Value>-?\d+(?:\.\d+)?)\s*$')
        $maxMatch = [regex]::Match($content, 'TextBox\s+''MaxTextBox''\s*\{[\s\S]*?\$this\.Text\s*=\s*(?<Value>-?\d+(?:\.\d+)?)', [System.Text.RegularExpressions.RegexOptions]::Singleline)

        $amountMatch.Success | Should -BeTrue
        $maxMatch.Success | Should -BeTrue

        $amount = [double] $amountMatch.Groups['Value'].Value
        $max = [double] $maxMatch.Groups['Value'].Value

        $max | Should -BeGreaterOrEqual $amount
    }

    It 'Should clamp Max to Amount when the entered Max is lower' {
        $scriptPath = Join-Path $PSScriptRoot '../PresentValueCalculator.DSL.ps1'
        $content = Get-Content -Path $scriptPath -Raw

        $content | Should -Match 'if\s*\(\$Max\s*-lt\s*\$Amount\)'
        $content | Should -Match '\$Max\s*=\s*\$Amount'
    }
}
