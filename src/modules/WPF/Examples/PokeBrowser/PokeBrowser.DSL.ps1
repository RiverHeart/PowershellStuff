using module ./PokeBrowser.Models.psm1

using namespace System.Collections.ObjectModel
using namespace System.Windows
using namespace System.Windows.Controls

<#
.SYNOPSIS
    Displays Pokemon retrieved from PokeAPI.

.NOTES
    MIT License

    Copyright (c) 2019 Jakub Jareš

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>

Set-Location $PSScriptRoot

if (-not (Get-Module -Name WPF) -and
    (Get-Module -ListAvailable -Name WPF)
) {
    Import-Module WPF -ErrorAction Stop -Force
}

Import "$PSScriptRoot/PokeBrowser.Styles.ps1"
Import "$PSScriptRoot/functions"

$PokemonList = [ObservableCollection[PokemonSummary]]::new()
$PlaceholderImage = [System.Windows.Media.Imaging.BitmapImage]::new(
    [uri] (Join-Path $PSScriptRoot 'images/0.png')
)

App 'Window' {
    $this.Title = 'PokeBrowser'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.WindowState = [WindowState]::Maximized
    $this.ResizeMode = [ResizeMode]::CanResize
    $this.Width = 960
    $this.Height = 640
    $this.MinWidth = 760
    $this.MinHeight = 520
    $this.Background = '#F3F4F6'

    State @{
        PokemonList = $PokemonList
        SelectedPokemon = $null
        Detail = [PokemonDetail]::new()
        IsLoading = $false
        StatusText = 'Loading Pokemon catalog...'
        Storage = New-WPFAppStorage -Application 'PokeBrowser' -ErrorAction Stop
    }

    On Loaded {
        Write-Debug 'PokeBrowser loaded.'
        $WindowContext = Get-WPFContextId -InputObject (Reference 'Window')
        Update-PokeBrowserCatalog -ContextId $WindowContext
    }

    MenuItem '(F)ile/(E)xit' {
        Command 'CloseCommand' 'Ctrl+q' {
            Write-Debug 'Close command triggered. Closing window.'
            (Reference 'Window').Close()
        }
    }

    Content {
        Grid 'Workspace' {
            $this.Margin = 24

            Row {
                Column {
                    StackPanel 'Header' {
                        $this.Margin = 0, 0, 0, 20

                        TextBlock 'AppTitle' {
                            UseStyle 'PokeBrowser.Title'
                            $this.Text = 'PokeBrowser'
                        }

                        TextBlock 'StatusText' {
                            UseStyle 'PokeBrowser.Status'
                            BindProperty Text StatusText
                        }
                    }
                }
            }

            Row 'Expand' {
                Column {
                    Border 'CatalogPanel' {
                        UseStyle 'PokeBrowser.Panel'
                        $this.Width = 300
                        $this.Margin = 0, 0, 20, 0

                        StackPanel 'CatalogContent' {
                            TextBlock 'CatalogHeading' {
                                UseStyle 'PokeBrowser.SectionHeading'
                                $this.Text = 'Pokemon catalog'
                            }

                            ComboBox 'PokemonPicker' {
                                UseStyle 'PokeBrowser.PokemonPicker'

                                $this.DisplayMemberPath = 'Name'

                                # Compute FontSize as 40% of the rendered height with a 12-point floor.
                                # A 40 pixel minimum height yields a 16-point font size, which is a reasonable minimum for legibility.
                                #
                                # TODO: That said, it would be nice to find a nicer abstraction for this, e.g. a "ScaleFontSize"
                                # binding converter that could be reused in other scenarios.
                                BindProperty FontSize ActualHeight -Self -ScriptBlock {
                                    $this.Converter = New-WPFValueConverter {
                                        param($Height)
                                        [Math]::Max(12, [double] $Height * 0.4)
                                    }
                                }
                                BindProperty ItemsSource PokemonList
                                BindProperty SelectedItem SelectedPokemon -ScriptBlock {
                                    $this.Mode = [System.Windows.Data.BindingMode]::TwoWay
                                }

                                On SelectionChanged {
                                    $State = (Reference 'Window').DataContext
                                    $State.SelectedPokemon = $this.SelectedItem
                                    (Reference 'ShowPokemonButton').Command.NotifyCanExecuteChanged()
                                }
                            }

                            Button 'ShowPokemonButton' {
                                UseStyle 'PrimaryButton'
                                $this.Content = 'Show details'

                                Command 'ShowPokemonCommand' {
                                    Execute {
                                        $State = (Reference 'Window').DataContext
                                        $State.IsLoading = $true

                                        try {
                                            $State.Detail = Get-PokeBrowserDetail -Pokemon $State.SelectedPokemon
                                            $State.StatusText = "Showing $($State.Detail.Name) from PokeAPI"
                                        } catch {
                                            $State.StatusText = "Unable to load Pokemon details: $($_.Exception.Message)"
                                        } finally {
                                            $State.IsLoading = $false
                                            (Reference 'ShowPokemonButton').Command.NotifyCanExecuteChanged()
                                            (Reference 'RefreshCatalogButton').Command.NotifyCanExecuteChanged()
                                        }
                                    }

                                    CanExecute {
                                        $State = (Reference 'Window').DataContext
                                        $null -ne $State.SelectedPokemon -and -not $State.IsLoading
                                    }
                                }
                            }

                            Button 'RefreshCatalogButton' {
                                UseStyle 'GhostButton'
                                $this.Content = 'Refresh catalog'

                                Command 'RefreshCatalogCommand' {
                                    Execute {
                                        $State = (Reference 'Window').DataContext
                                        $State.IsLoading = $true

                                        $WindowContext = Get-WPFContextId -InputObject (Reference 'Window')
                                        Update-PokeBrowserCatalog -ContextId $WindowContext -Refresh
                                    }

                                    CanExecute {
                                        -not (Reference 'Window').DataContext.IsLoading
                                    }
                                }
                            }

                            ProgressBar 'LoadingIndicator' {
                                $this.Height = 4
                                $this.Margin = 0, 16, 0, 0
                                $this.IsIndeterminate = $true
                                Link IsLoading -To Visibility
                            }
                        }
                    }
                }

                Column {
                    Border 'DetailPanel' {
                        UseStyle 'PokeBrowser.Panel'
                        BindProperty DataContext Detail

                        Grid 'DetailContent' {
                            Row {
                                Column 'Expand' {
                                    TextBlock 'PokemonName' {
                                        UseStyle 'PokeBrowser.PokemonName'
                                        BindProperty Text Name
                                    }
                                }
                            }

                            Row 'Expand' {
                                Column {
                                    VStackPanel 'ImageContainer' {
                                        Border 'ImageFrame' {
                                            UseStyle 'PokeBrowser.ImageFrame'
                                            $this.Width = 240
                                            $this.Height = 240
                                            $this.Margin = 0, 20, 28, 0

                                            Image 'PokemonImage' {
                                                $this.Stretch = [System.Windows.Media.Stretch]::Uniform
                                                BindProperty Source ImageUri -ScriptBlock {
                                                    $this.FallbackValue = $PlaceholderImage
                                                    $this.TargetNullValue = $PlaceholderImage
                                                }
                                            }
                                        }
                                    }
                                }

                                Column 'Expand' {
                                    StackPanel 'PokemonFacts' {
                                        $this.Margin = 0, 28, 0, 0

                                        TextBlock 'TypeLabel' {
                                            UseStyle 'PokeBrowser.FactLabel'
                                            $this.Text = 'TYPE'
                                        }

                                        TextBlock 'PokemonType' {
                                            UseStyle 'PokeBrowser.FactValue'
                                            BindProperty Text Type
                                        }

                                        TextBlock 'HeightLabel' {
                                            UseStyle 'PokeBrowser.FactLabel'
                                            $this.Text = 'HEIGHT'
                                        }

                                        TextBlock 'PokemonHeight' {
                                            UseStyle 'PokeBrowser.FactValue'
                                            BindProperty Text Height
                                        }

                                        TextBlock 'WeightLabel' {
                                            UseStyle 'PokeBrowser.FactLabel'
                                            $this.Text = 'WEIGHT'
                                        }

                                        TextBlock 'PokemonWeight' {
                                            UseStyle 'PokeBrowser.FactValue'
                                            BindProperty Text Weight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
