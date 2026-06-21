Describe 'BindProperty' -Tag 'BindProperty' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should bind a TextBlock.Text property to a source binding' {
        $Grid = [System.Windows.Controls.DataGrid]::new()
        $Grid.Name = 'TestGrid'

        $TextBlock = [System.Windows.Controls.TextBlock]::new()
        $TextBlock.Name = 'TestText'

        # Add some items to the grid
        $Grid.ItemsSource = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
        $Grid.ItemsSource.Add(@{ Name = 'Process1'; Id = 1 })
        $Grid.ItemsSource.Add(@{ Name = 'Process2'; Id = 2 })

        # Bind TextBlock.Text to Grid.ItemsSource.Count
        BindProperty -InputObject $TextBlock -Property Text -Path ItemsSource.Count -Source $Grid

        # TextBlock should have a binding set
        $binding = [System.Windows.Data.BindingOperations]::GetBinding($TextBlock, [System.Windows.Controls.TextBlock]::TextProperty)
        $binding | Should -Not -BeNullOrEmpty
        $binding.Path.Path | Should -Be 'ItemsSource.Count'
        $binding.Source | Should -Be $Grid
    }

    It 'Should bind with -Self relative source' {
        $Button = [System.Windows.Controls.Button]::new()
        $Button.IsEnabled = $true

        # Bind Button.IsEnabled to itself (just as a test)
        BindProperty -InputObject $Button -Property IsEnabled -Path IsEnabled -Self

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($Button, [System.Windows.Controls.Button]::IsEnabledProperty)
        $binding | Should -Not -BeNullOrEmpty
        $binding.RelativeSource.Mode | Should -Be ([System.Windows.Data.RelativeSourceMode]::Self)
    }

    It 'Should reject multiple source selectors' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        {
            BindProperty -InputObject $TextBlock -Property Text -Path 'SomePath' -Self -TemplatedParent -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should bind using inherited DataContext when no source selector is provided' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()
        $State = New-WPFObservableState @{
            Count = 1
        }

        $TextBlock.DataContext = $State

        BindProperty -InputObject $TextBlock -Property Text -Path Count

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($TextBlock, [System.Windows.Controls.TextBlock]::TextProperty)
        $binding | Should -Not -BeNullOrEmpty
        $binding.Path.Path | Should -Be 'Count'
        $binding.Source | Should -Be $null
        $binding.RelativeSource | Should -Be $null
        $binding.ElementName | Should -BeNullOrEmpty

        $TextBlock.Text | Should -Be '1'

        $State.Count = 2
        $TextBlock.Text | Should -Be '2'
    }

    It 'Should warn when no source selector is provided and DataContext is null' {
        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/../../../../GrabBag/Public/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $TextBlock = [System.Windows.Controls.TextBlock]::new()
        $Warnings = @()

        BindProperty -InputObject $TextBlock -Property Text -Path Count -WarningVariable Warnings

        $Warnings.Count | Should -Be 1
        $Warnings[0].ToString() | Should -Match 'DataContext is null'
    }

    It 'Should allow configuring the binding via ScriptBlock' {
        $Grid = [System.Windows.Controls.DataGrid]::new()
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        # Bind with a converter
        BindProperty -InputObject $TextBlock -Property Text -Path ItemsSource.Count -Source $Grid -ScriptBlock {
            $this.Converter = New-WPFValueConverter {
                param($Value)
                if ($null -eq $Value) { return '0' }
                return $Value.ToString()
            }
        }

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($TextBlock, [System.Windows.Controls.TextBlock]::TextProperty)
        $binding.Converter | Should -Not -BeNullOrEmpty
    }

    It 'Should work inside a DSL control body with $this' {
        $DummySource = [pscustomobject]@{ Value = 42 }

        $TextBlockInstance = TextBlock 'TestText' {
            BindProperty Text Value -Source $DummySource
        }

        $BindingApplied = [System.Windows.Data.BindingOperations]::GetBinding(
            $TextBlockInstance,
            [System.Windows.Controls.TextBlock]::TextProperty
        )

        $BindingApplied | Should -Not -BeNullOrEmpty
        $BindingApplied.Path.Path | Should -Be 'Value'
    }

    It 'Should reject invalid property names' {
        $TextBlock = [System.Windows.Controls.TextBlock]::new()

        {
            BindProperty -InputObject $TextBlock -Property 'NonExistentProperty' -Path 'SomePath' -Self -ErrorAction Stop
        } | Should -Throw
    }
}
