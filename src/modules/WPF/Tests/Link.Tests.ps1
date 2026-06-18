Describe 'Link' -Tag 'Link' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should export Link' {
        $command = Get-Command -Name Link -Module WPF -ErrorAction Stop
        $command | Should -Not -Be $null
    }

    It 'Should delegate state mode to Bind with -ToState' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link Content -ToState IsReady -Converter {
                    if ($_) { 'Ready' } else { 'Not Ready' }
                }
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Content | Should -Be 'Not Ready'

        $window.Tag.IsReady = $true
        $label.Content | Should -Be 'Ready'
    }

    It 'Should delegate property mode to BindProperty with -Property' {
        $textBlock = [System.Windows.Controls.TextBlock]::new()
        $source = [pscustomobject]@{
            Value = 42
        }

        Link Text -Property Value -Source $source -InputObject $textBlock

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($textBlock, [System.Windows.Controls.TextBlock]::TextProperty)
        $binding | Should -Not -Be $null
        $binding.Path.Path | Should -Be 'Value'
        $binding.Source | Should -Be $source
    }

    It 'Should accept -Path as an alias for source property' {
        $textBlock = [System.Windows.Controls.TextBlock]::new()
        $source = [pscustomobject]@{
            Value = 7
        }

        Link Text -Path Value -Source $source -InputObject $textBlock

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($textBlock, [System.Windows.Controls.TextBlock]::TextProperty)
        $binding | Should -Not -Be $null
        $binding.Path.Path | Should -Be 'Value'
        $binding.Source | Should -Be $source
    }

    It 'Should return a Binding object in -AsBinding mode' {
        $binding = Link -AsBinding -Property IsEnabled -Self

        $binding | Should -Not -Be $null
        $binding | Should -BeOfType ([System.Windows.Data.Binding])
        $binding.Path.Path | Should -Be 'IsEnabled'
        $binding.RelativeSource.Mode | Should -Be ([System.Windows.Data.RelativeSourceMode]::Self)
    }
}
