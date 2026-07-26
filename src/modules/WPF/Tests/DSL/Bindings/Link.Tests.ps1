Describe 'Link' -Tag 'Link' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../WPF.psd1" -Force
    }

    It 'Should export Link' {
        $command = Get-Command -Name Link -Module WPF -ErrorAction Stop
        $command | Should -Not -Be $null
    }

    It 'Should support directional syntax for state to property binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link IsReady -To Content -Transform {
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

    It 'Should throw when directional source endpoint is ambiguous without explicit kind' {
        $errors = & {
            $id = [guid]::NewGuid().ToString('N')
            $windowName = "Window_$id"
            $labelName = "Label_$id"

            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    IsEnabled = $true
                }

                Label $labelName {
                    Link IsEnabled -To Content
                }
            } -ErrorAction Stop
        } 2>&1

        ($errors | Out-String) | Should -Match 'ambiguous'
    }

    It 'Should throw when directional target endpoint is ambiguous without explicit kind' {
        $errors = & {
            $id = [guid]::NewGuid().ToString('N')
            $windowName = "Window_$id"
            $labelName = "Label_$id"

            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    IsReady   = $true
                    IsEnabled = $false
                }

                Label $labelName {
                    Link IsReady -To IsEnabled
                }
            } -ErrorAction Stop
        } 2>&1

        ($errors | Out-String) | Should -Match 'ambiguous'
    }

    It 'Should allow directional disambiguation via -FromKind and -ToKind' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsEnabled = $false
            }

            Label $labelName {
                Link IsEnabled -To IsEnabled -FromKind State -ToKind Property
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.IsEnabled | Should -BeFalse

        $window.Tag.IsEnabled = $true
        $label.IsEnabled | Should -BeTrue
    }

    It 'Should support directional property to property binding with explicit kinds' {
        $label = [System.Windows.Controls.Label]::new()
        $label.IsEnabled = $false

        Link IsEnabled -To IsHitTestVisible -FromKind Property -ToKind Property -InputObject $label

        $binding = [System.Windows.Data.BindingOperations]::GetBinding($label, [System.Windows.UIElement]::IsHitTestVisibleProperty)
        $binding | Should -Not -Be $null
        $binding.Path.Path | Should -Be 'IsEnabled'
        $binding.RelativeSource.Mode | Should -Be ([System.Windows.Data.RelativeSourceMode]::Self)

        $label.IsEnabled = $true
        $label.IsHitTestVisible | Should -BeTrue
    }

    It 'Should support directional property to state binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $textBoxName = "TextBox_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                SearchQuery = ''
            }

            TextBox $textBoxName {
                Link Text -To SearchQuery
            }
        }

        $window = Reference $windowName
        $textBox = Reference $textBoxName

        $window.Tag.SearchQuery | Should -Be ''

        $textBox.Text = 'cats'
        $window.Tag.SearchQuery | Should -Be 'cats'
    }

    It 'Should support -Transform for directional property to state binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $textBoxName = "TextBox_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                SearchQuery = ''
            }

            TextBox $textBoxName {
                Link Text -To SearchQuery -Transform {
                    param($Value)
                    $Value.Trim().ToUpperInvariant()
                }
            }
        }

        $window = Reference $windowName
        $textBox = Reference $textBoxName

        $textBox.Text = '  cats  '
        $window.Tag.SearchQuery | Should -Be 'CATS'
    }

    It 'Should support -Map for directional property to state binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $textBoxName = "TextBox_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                SearchQuery = ''
            }

            TextBox $textBoxName {
                Link Text -To SearchQuery -Map @{
                    cat = 'feline'
                }
            }
        }

        $window = Reference $windowName
        $textBox = Reference $textBoxName

        $textBox.Text = 'cat'
        $window.Tag.SearchQuery | Should -Be 'feline'
    }

    It 'Should support -Default with -Map for directional property to state binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $textBoxName = "TextBox_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                SearchQuery = ''
            }

            TextBox $textBoxName {
                Link Text -To SearchQuery -Map @{
                    cat = 'feline'
                } -Default 'unknown'
            }
        }

        $window = Reference $windowName
        $textBox = Reference $textBoxName

        $textBox.Text = 'dog'
        $window.Tag.SearchQuery | Should -Be 'unknown'
    }

    It 'Should support -Invert for directional property to state binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $textBoxName = "TextBox_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                Inverted = $false
            }

            TextBox $textBoxName {
                Link Text -To Inverted -Invert
            }
        }

        $window = Reference $windowName
        $textBox = Reference $textBoxName

        $textBox.Text = 'hello'
        $window.Tag.Inverted | Should -BeFalse

        $textBox.Text = ''
        $window.Tag.Inverted | Should -BeTrue
    }

    It 'Should apply -Invert before -Map for directional property to state binding' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $textBoxName = "TextBox_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                DisplayState = ''
            }

            TextBox $textBoxName {
                Link Text -To DisplayState -Invert -Map @{
                    $true  = 'ON'
                    $false = 'OFF'
                }
            }
        }

        $window = Reference $windowName
        $textBox = Reference $textBoxName

        $textBox.Text = 'hello'
        $window.Tag.DisplayState | Should -Be 'OFF'

        $textBox.Text = ''
        $window.Tag.DisplayState | Should -Be 'ON'
    }

    It 'Should reject combining -Map with -Transform for directional property to state binding' {
        {
            $id = [guid]::NewGuid().ToString('N')
            $windowName = "Window_$id"
            $textBoxName = "TextBox_$id"

            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    SearchQuery = ''
                }

                TextBox $textBoxName {
                    Link Text -To SearchQuery -Map @{ cat = 'feline' } -Transform { $_ }
                }
            } -ErrorAction Stop
        } | Should -Throw '*either -Map or -Transform*'
    }

    It 'Should reject -Default without -Map for directional property to state binding' {
        {
            $id = [guid]::NewGuid().ToString('N')
            $windowName = "Window_$id"
            $textBoxName = "TextBox_$id"

            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    SearchQuery = ''
                }

                TextBox $textBoxName {
                    Link Text -To SearchQuery -Default 'unknown'
                }
            } -ErrorAction Stop
        } | Should -Throw '*-Default and -StrictMap require -Map*'
    }

    It 'Should reject combining -Default with -StrictMap for directional property to state binding' {
        {
            $id = [guid]::NewGuid().ToString('N')
            $windowName = "Window_$id"
            $textBoxName = "TextBox_$id"

            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    SearchQuery = ''
                }

                TextBox $textBoxName {
                    Link Text -To SearchQuery -Map @{ cat = 'feline' } -Default 'unknown' -StrictMap
                }
            } -ErrorAction Stop
        } | Should -Throw '*cannot be combined*'
    }

    It 'Should support directional state to state one-way propagation' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                SourceValue = 5
                MirrorValue = 0
            }

            Link SourceValue -To MirrorValue
        }

        $window = Reference $windowName
        $window.Tag.MirrorValue | Should -Be 5

        $window.Tag.SourceValue = 42
        $window.Tag.MirrorValue | Should -Be 42
    }

    It 'Should reject directional state to state self-links' {
        $errors = & {
            $id = [guid]::NewGuid().ToString('N')
            $windowName = "Window_$id"

            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    Value = 1
                }

                Link Value -To Value -FromKind State -ToKind State
            } -ErrorAction Stop
        } 2>&1

        ($errors | Out-String) | Should -Match 'distinct endpoints'
    }

    It 'Should delegate state mode to Bind with -FromState' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                Link Content -FromState IsReady -Transform {
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
                Link Content -FromState IsReady -Map @{
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
                Link Content -FromState IsReady -Map @{
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
                Link Content -FromState IsReady -Map @{
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
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $warnings = & {
            $null = Window $windowName {
                $this.Tag = New-WPFObservableState @{
                    IsReady = $false
                }

                Label $labelName {
                    Link Content -FromState IsReady -Map @{
                        $true  = { 'Ready' }
                        $false = 'Not Ready'
                    }
                }
            }
        } 3>&1

        ($warnings | Out-String) | Should -Match '-Map contains scriptblock value\(s\)'

        $window = Reference $windowName
        $label = Reference $labelName
        $window | Should -Not -Be $null
        $label | Should -Not -Be $null
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
                Link Content -FromState Mode -Map @{
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
                    Link Content -FromState Mode -Map @{
                        Ready = 'Ready'
                    } -StrictMap
                }
            } -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject combining -Map with -Transform in state mode' {
        {
            $null = Link Content -FromState IsReady -Map @{ $true = 'Ready' } -Transform { 'x' } -InputObject ([System.Windows.Controls.Label]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject -Default without -Map in state mode' {
        {
            $null = Link Content -FromState IsReady -Default 'Fallback' -InputObject ([System.Windows.Controls.Label]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject combining -Default with -StrictMap in state mode' {
        {
            $null = Link Content -FromState IsReady -Map @{ $true = 'Ready' } -Default 'Fallback' -StrictMap -InputObject ([System.Windows.Controls.Label]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject legacy property mode syntax with -Property' {
        {
            Link Text -Property Value -Source ([pscustomobject]@{ Value = 42 }) -InputObject ([System.Windows.Controls.TextBlock]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should reject legacy property mode syntax with -Path' {
        {
            Link Text -Path Value -Source ([pscustomobject]@{ Value = 7 }) -InputObject ([System.Windows.Controls.TextBlock]::new()) -ErrorAction Stop
        } | Should -Throw
    }

    It 'Should return a Binding object in -AsBinding mode' {
        $binding = Link -AsBinding -Property IsEnabled -Self

        $binding | Should -Not -Be $null
        $binding | Should -BeOfType ([System.Windows.Data.Binding])
        $binding.Path.Path | Should -Be 'IsEnabled'
        $binding.RelativeSource.Mode | Should -Be ([System.Windows.Data.RelativeSourceMode]::Self)
    }
}
