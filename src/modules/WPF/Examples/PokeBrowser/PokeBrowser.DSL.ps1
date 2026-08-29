using module ./PokeBrowser.Models.psm1

using namespace System.Collections.ObjectModel
using namespace System.Windows
using namespace System.Windows.Controls

$DebugPreference = 'Continue'

<#
.SYNOPSIS
    Displays Pokemon retrieved from PokeAPI.

.NOTES
    Adapted from Jakub Jareš' PokeBrowser.
    See THIRD-PARTY-NOTICES.txt for attribution and license terms.
#>

Set-Location $PSScriptRoot

Import-Module WPF -ErrorAction Stop -Force

Import "$PSScriptRoot/PokeBrowser.Styles.ps1"
Import "$PSScriptRoot/functions"

$PokemonList = [ObservableCollection[PokemonSummary]]::new()
$PlaceholderImage = [System.Windows.Media.Imaging.BitmapImage]::new(
    [uri] (Join-Path $PSScriptRoot 'images/0.png')
)

$RefreshCatalogCommand = Command 'RefreshCatalogCommand' {
    Execute {
        $State = (Get-WPFWindow).DataContext
        $State.IsLoading = $true

        $WindowContext = Get-WPFContextId
        Update-PokeBrowserCatalog -ContextId $WindowContext -Refresh
    }

    CanExecute {
        -not (Get-WPFWindow).DataContext.IsLoading
    }
}

App 'Window' {
    UseStyle 'PokeBrowser.Window'

    $this.Title = 'PokeBrowser'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.WindowState = [WindowState]::Maximized
    $this.ResizeMode = [ResizeMode]::CanResize

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
        $WindowContext = Get-WPFContextId -InputObject $this
        Update-PokeBrowserCatalog -ContextId $WindowContext
    }

    MenuItem '(F)ile/(E)xit' {
        Command 'CloseCommand' 'Ctrl+q' {
            Write-Debug 'Close command triggered. Closing window.'
            (Get-WPFWindow).Close()
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
                            Link StatusText -To Text
                        }
                    }
                }
            }

            Row 'Expand' {
                Column {
                    Border 'CatalogPanel' {
                        UseStyle 'PokeBrowser.CatalogPanel'

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
                                BindProperty FontSize ActualHeight -Self -Converter {
                                    param($Height); [Math]::Max(12, [double] $Height * 0.4)
                                }
                                Link PokemonList -To ItemsSource
                                Link SelectedItem -To SelectedPokemon -Sync

                                On SelectionChanged {
                                    $SelectedPokemon = $this.SelectedItem
                                    if ($null -ne $SelectedPokemon) {
                                        $State = (Get-WPFWindow).DataContext
                                        $State.Detail = Get-PokeBrowserCachedDetail -Storage $State.Storage -Pokemon $SelectedPokemon
                                    }
                                }
                            }

                            Button 'RefreshCatalogButton' {
                                UseStyle 'PrimaryButton'
                                $this.Content = 'Refresh catalog'

                                Command $RefreshCatalogCommand
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
                        Link Detail -To DataContext

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
