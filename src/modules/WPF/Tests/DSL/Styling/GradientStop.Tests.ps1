Describe 'GradientStop' -Tag 'GradientStop' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should add a gradient stop when used inside LinearGradientBrush context' {
        $brush = [System.Windows.Media.LinearGradientBrush]::new()
        $psVars = New-WPFVariableList -InputObject $brush

        { GradientStop 'Yellow' 0.25 }.InvokeWithContext($null, $psVars) | Out-Null

        $brush.GradientStops.Count | Should -Be 1
        $brush.GradientStops[0].Color.ToString() | Should -Be '#FFFFFF00'
        $brush.GradientStops[0].Offset | Should -Be 0.25
    }

    It 'Should add a gradient stop when used inside GradientStopCollection context' {
        $collection = [System.Windows.Media.GradientStopCollection]::new()
        $psVars = New-WPFVariableList -InputObject $collection

        {
            $null -eq $this
            GradientStop 'WhiteSmoke' 0.2 }.InvokeWithContext($null, $psVars) | Out-Null

        $collection.Count | Should -Be 1
        $collection[0].Color.ToString() | Should -Be '#FFF5F5F5'
        $collection[0].Offset | Should -Be 0.2
    }

    It 'Should fail when used outside LinearGradientBrush or GradientStopCollection context' {
        {
            GradientStop 'Yellow' 0.25 -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should accept unprefixed six-digit hex colors' {
        $brush = [System.Windows.Media.LinearGradientBrush]::new()
        $psVars = New-WPFVariableList -InputObject $brush

        { GradientStop 'FF00AA' 0.5 }.InvokeWithContext($null, $psVars) | Out-Null

        $brush.GradientStops.Count | Should -Be 1
        $brush.GradientStops[0].Color.ToString() | Should -Be '#FFFF00AA'
        $brush.GradientStops[0].Offset | Should -Be 0.5
    }

    It 'Should accept unprefixed three-digit hex colors' {
        $brush = [System.Windows.Media.LinearGradientBrush]::new()
        $psVars = New-WPFVariableList -InputObject $brush

        { GradientStop 'fff' 0.4 }.InvokeWithContext($null, $psVars) | Out-Null

        $brush.GradientStops.Count | Should -Be 1
        $brush.GradientStops[0].Color.ToString() | Should -Be '#FFFFFFFF'
        $brush.GradientStops[0].Offset | Should -Be 0.4
    }

    It 'Should accept hash-prefixed six-digit hex colors' {
        $brush = [System.Windows.Media.LinearGradientBrush]::new()
        $psVars = New-WPFVariableList -InputObject $brush

        { GradientStop '#ffffff' 0.6 }.InvokeWithContext($null, $psVars) | Out-Null

        $brush.GradientStops.Count | Should -Be 1
        $brush.GradientStops[0].Color.ToString() | Should -Be '#FFFFFFFF'
        $brush.GradientStops[0].Offset | Should -Be 0.6
    }

    It 'Should fail for invalid color tokens' {
        $brush = [System.Windows.Media.LinearGradientBrush]::new()
        $psVars = New-WPFVariableList -InputObject $brush

        {
            { GradientStop 'not-a-color' 0.5 -ErrorAction Stop }.InvokeWithContext($null, $psVars) | Out-Null
        } | Should -Throw
    }
}
