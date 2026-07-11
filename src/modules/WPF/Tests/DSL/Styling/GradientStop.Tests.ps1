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
}
