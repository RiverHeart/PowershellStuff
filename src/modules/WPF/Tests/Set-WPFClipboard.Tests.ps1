Describe 'Set-WPFClipboard' -Tag 'Set-WPFClipboard' {
    BeforeAll {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force

        $Script:ModulePath = Join-Path $PSScriptRoot '../WPF.psd1'
        $Script:PowerShellPath = (Get-Process -Id $PID).Path

        function Invoke-ClipboardScenario {
            param (
                [Parameter(Mandatory)]
                [ValidateSet('CopyImageControl', 'CopyBitmap', 'RejectNonBitmap')]
                [string] $Scenario
            )

            $scriptBlock = {
                param (
                    [Parameter(Mandatory)]
                    [ValidateSet('CopyImageControl', 'CopyBitmap', 'RejectNonBitmap')]
                    [string] $ScenarioName
                )

                [System.Windows.Clipboard]::Clear()

                switch ($ScenarioName) {
                    'CopyImageControl' {
                        $Bitmap = [System.Windows.Media.Imaging.WriteableBitmap]::new(
                            10, 10, 96, 96,
                            [System.Windows.Media.PixelFormats]::Bgr32,
                            $null
                        )
                        $Image = [System.Windows.Controls.Image]::new()
                        $Image.Source = $Bitmap

                        Set-WPFClipboard -InputObject $Image

                        [pscustomobject]@{
                            HasImage   = [System.Windows.Clipboard]::ContainsImage()
                            ErrorCount = 0
                        }
                    }
                    'CopyBitmap' {
                        $Bitmap = [System.Windows.Media.Imaging.WriteableBitmap]::new(
                            10, 10, 96, 96,
                            [System.Windows.Media.PixelFormats]::Bgr32,
                            $null
                        )

                        Set-WPFClipboard -InputObject $Bitmap

                        [pscustomobject]@{
                            HasImage   = [System.Windows.Clipboard]::ContainsImage()
                            ErrorCount = 0
                        }
                    }
                    'RejectNonBitmap' {
                        $Errors = @()

                        Set-WPFClipboard -InputObject 'not-an-image' -ErrorVariable +Errors -ErrorAction SilentlyContinue

                        [pscustomobject]@{
                            HasImage   = [System.Windows.Clipboard]::ContainsImage()
                            ErrorCount = @($Errors).Count
                        }
                    }
                }
            }

            if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
                return & $scriptBlock $Scenario
            }

            $escapedModulePath = $Script:ModulePath.Replace("'", "''")
            $command = @"
`$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module -Name '$escapedModulePath' -Force

`$ScenarioResult = & {
    param (
        [string] `$ScenarioName
    )

    [System.Windows.Clipboard]::Clear()

    switch (`$ScenarioName) {
        'CopyImageControl' {
            `$Bitmap = [System.Windows.Media.Imaging.WriteableBitmap]::new(
                10, 10, 96, 96,
                [System.Windows.Media.PixelFormats]::Bgr32,
                `$null
            )
            `$Image = [System.Windows.Controls.Image]::new()
            `$Image.Source = `$Bitmap

            Set-WPFClipboard -InputObject `$Image

            [pscustomobject]@{
                HasImage   = [System.Windows.Clipboard]::ContainsImage()
                ErrorCount = 0
            }
        }
        'CopyBitmap' {
            `$Bitmap = [System.Windows.Media.Imaging.WriteableBitmap]::new(
                10, 10, 96, 96,
                [System.Windows.Media.PixelFormats]::Bgr32,
                `$null
            )

            Set-WPFClipboard -InputObject `$Bitmap

            [pscustomobject]@{
                HasImage   = [System.Windows.Clipboard]::ContainsImage()
                ErrorCount = 0
            }
        }
        'RejectNonBitmap' {
            `$Errors = @()

            Set-WPFClipboard -InputObject 'not-an-image' -ErrorVariable +Errors -ErrorAction SilentlyContinue

            [pscustomobject]@{
                HasImage   = [System.Windows.Clipboard]::ContainsImage()
                ErrorCount = @(`$Errors).Count
            }
        }
    }
} -ScenarioName '$Scenario'

`$ScenarioResult | ConvertTo-Json -Compress
"@

            $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
            $output = & $Script:PowerShellPath -NoProfile -STA -EncodedCommand $encodedCommand

            if ($LASTEXITCODE -ne 0) {
                throw "STA subprocess failed for scenario '$Scenario': $output"
            }

            return $output | ConvertFrom-Json
        }
    }

    It 'Copies an Image control source to the clipboard' {
        $result = Invoke-ClipboardScenario -Scenario 'CopyImageControl'

        $result.HasImage | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Copies a BitmapSource directly to the clipboard' {
        $result = Invoke-ClipboardScenario -Scenario 'CopyBitmap'

        $result.HasImage | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }

    It 'Writes an error when the input is not clipboard-compatible' {
        $result = Invoke-ClipboardScenario -Scenario 'RejectNonBitmap'

        $result.ErrorCount | Should -Be 1
        $result.HasImage | Should -BeFalse
    }
}
