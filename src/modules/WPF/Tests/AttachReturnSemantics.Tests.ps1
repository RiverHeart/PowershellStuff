Describe 'Attach Return Semantics' -Tag 'AttachReturnSemantics' {
    $Cases = @(
        @{ Keyword = 'Button';       NamePrefix = 'Button';       Type = [System.Windows.Controls.Button] }
        @{ Keyword = 'Label';        NamePrefix = 'Label';        Type = [System.Windows.Controls.Label] }
        @{ Keyword = 'TextBlock';    NamePrefix = 'TextBlock';    Type = [System.Windows.Controls.TextBlock] }
        @{ Keyword = 'Image';        NamePrefix = 'Image';        Type = [System.Windows.Controls.Image] }
        @{ Keyword = 'ScrollViewer'; NamePrefix = 'ScrollViewer'; Type = [System.Windows.Controls.ScrollViewer] }
        @{ Keyword = 'StackPanel';   NamePrefix = 'StackPanel';   Type = [System.Windows.Controls.StackPanel] }
        @{ Keyword = 'DockPanel';    NamePrefix = 'DockPanel';    Type = [System.Windows.Controls.DockPanel] }
        @{ Keyword = 'DatePicker';   NamePrefix = 'DatePicker';   Type = [System.Windows.Controls.DatePicker] }
        @{ Keyword = 'DataGrid';     NamePrefix = 'DataGrid';     Type = [System.Windows.Controls.DataGrid] }
    )

    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    foreach ($case in $Cases) {
        It "Returns created $($case.Keyword) when no parent context exists" {
            $id = [guid]::NewGuid().ToString('N')
            $name = "{0}_{1}" -f $case.NamePrefix, $id

            $psVars = New-WPFVariableList -AdditionalVariables @([psvariable]::new('this', $null))
            $control = {
                & $case.Keyword $name {}
            }.InvokeWithContext($null, $psVars)
            $control = @($control)[0]

            $control | Should -Not -BeNullOrEmpty
            $control | Should -BeOfType $case.Type
            $control.Name | Should -Be $name
        }
    }

    foreach ($case in $Cases) {
        It "Auto-attaches $($case.Keyword) and returns no output when parent context exists" {
            $parent = [System.Windows.Controls.StackPanel]::new()
            $psVars = New-WPFVariableList -InputObject $parent
            $id = [guid]::NewGuid().ToString('N')
            $name = "{0}_{1}" -f $case.NamePrefix, $id

            $result = {
                & $case.Keyword $name {}
            }.InvokeWithContext($null, $psVars)

            @($result).Count | Should -Be 0
            $parent.Children | Should -HaveCount 1
            $parent.Children[0] | Should -BeOfType $case.Type
            $parent.Children[0].Name | Should -Be $name
        }
    }
}
