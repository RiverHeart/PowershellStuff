Describe 'Resolve-WPFFileDialogFilter' -Tag 'Resolve-WPFFileDialogFilter' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should place aggregate category filter first and All Files last' {
        InModuleScope WPF {
            Mock -CommandName Get-WPFFileInfo -MockWith {
                param (
                    [string[]] $Type,
                    [string[]] $Category
                )

                if ($Category -and -not $Type -and $Category.Count -eq 1 -and $Category[0] -eq 'Image') {
                    return @(
                        @{ Display = 'JPEG'; Extensions = @('jpeg', 'jpg'); Filter = 'JPEG (*.jpeg;*.jpg)|*.jpeg;*.jpg' },
                        @{ Display = 'PNG'; Extensions = 'png'; Filter = 'PNG (*.png)|*.png' }
                    )
                }

                return @(
                    @{ Display = 'JPEG'; Extensions = @('jpeg', 'jpg'); Filter = 'JPEG (*.jpeg;*.jpg)|*.jpeg;*.jpg' },
                    @{ Display = 'PNG'; Extensions = 'png'; Filter = 'PNG (*.png)|*.png' }
                )
            }

            $Filters = Resolve-WPFFileDialogFilter -Category Image

            $Filters[0] | Should -BeLike -ExpectedValue 'All Images (*.jpeg;*.jpg;*.png)|*.jpeg;*.jpg;*.png'
            $Filters[-1] | Should -Be -ExpectedValue 'All Files (*.*)|*.*'
        }
    }

    It 'Should keep only one All Files fallback entry' {
        InModuleScope WPF {
            Mock -CommandName Get-WPFFileInfo -MockWith {
                param (
                    [string[]] $Type,
                    [string[]] $Category
                )

                return @(
                    @{ Display = 'All Files'; Filter = 'All Files (*.*)|*.*'; Extensions = '*' },
                    @{ Display = 'PNG'; Extensions = 'png'; Filter = 'PNG (*.png)|*.png' }
                )
            }

            $Filters = Resolve-WPFFileDialogFilter -Category Image
            $AllCount = @($Filters | Where-Object { $_ -eq 'All Files (*.*)|*.*' }).Count

            $AllCount | Should -Be -ExpectedValue 1
            $Filters[-1] | Should -Be -ExpectedValue 'All Files (*.*)|*.*'
        }
    }
}
