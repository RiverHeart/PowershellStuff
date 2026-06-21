Describe 'Link' -Tag 'Link' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
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

    It 'Should map boolean state values using typed boolean map keys' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link Content -ToState IsReady -Map @{
                    $true  = 'Ready'
                    $false = 'Not Ready'
                }
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Content | Should -Be 'Not Ready'

        $window.Tag.IsReady = $true
        $label.Content | Should -Be 'Ready'
    }

    It 'Should map boolean state values using True/False string map keys' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link Content -ToState IsReady -Map @{
                    True  = 'Ready'
                    False = 'Not Ready'
                }
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Content | Should -Be 'Not Ready'

        $window.Tag.IsReady = $true
        $label.Content | Should -Be 'Ready'
    }

    It 'Should map state values to prebuilt WPF objects' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $activeContent = [System.Windows.Controls.TextBlock]::new()
        $activeContent.Text = 'Ready'

        $inactiveContent = [System.Windows.Controls.TextBlock]::new()
        $inactiveContent.Text = 'Not Ready'

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link Content -ToState IsReady -Map @{
                    $true  = $activeContent
                    $false = $inactiveContent
                }
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        [object]::ReferenceEquals($label.Content, $inactiveContent) | Should -Be $true

        $window.Tag.IsReady = $true
        [object]::ReferenceEquals($label.Content, $activeContent) | Should -Be $true
    }

    It 'Should warn when -Map contains scriptblock values' {
        Mock Write-Warning {} -ModuleName WPF

        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link Content -ToState IsReady -Map @{
                    $true  = { 'Ready' }
                    $false = 'Not Ready'
                }
            }
        }

        Should -Invoke Write-Warning -ModuleName WPF -Times 1 -Exactly
    }

    It 'Should use -Default when map key is missing' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                Mode = 'Unknown'
            }

            Label $labelName {
                Link Content -ToState Mode -Map @{
                    Ready = 'Ready'
                    Busy  = 'Busy'
                } -Default 'Fallback'
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Content | Should -Be 'Fallback'
    }

    It 'Should throw when -StrictMap is set and map key is missing' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        {
            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    Mode = 'Unknown'
                }

                Label $labelName {
                    Link Content -ToState Mode -Map @{
                        Ready = 'Ready'
                    } -StrictMap
                }
            } -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject combining -Map with -Converter in state mode' {
        {
            $null = Link Content -ToState IsReady -Map @{ $true = 'Ready' } -Converter { 'x' } -InputObject ([System.Windows.Controls.Label]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject -Default without -Map in state mode' {
        {
            $null = Link Content -ToState IsReady -Default 'Fallback' -InputObject ([System.Windows.Controls.Label]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject combining -Default with -StrictMap in state mode' {
        {
            $null = Link Content -ToState IsReady -Map @{ $true = 'Ready' } -Default 'Fallback' -StrictMap -InputObject ([System.Windows.Controls.Label]::new()) -ErrorAction Stop
        } | Should -Throw
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
