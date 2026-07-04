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

    It 'Should fail when used outside LinearGradientBrush context' {
        {
            GradientStop 'Yellow' 0.25 -ErrorAction Stop
        } | Should -Throw
    }
}
