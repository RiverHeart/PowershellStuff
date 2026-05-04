Describe 'React' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should pass the source value to converter param blocks' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                React Content "$windowName.Tag.IsReady" -Converter {
                    param($SourceValue)

                    if ($SourceValue) { 'Ready' } else { 'Not Ready' }
                }
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Content | Should -Be -ExpectedValue 'Not Ready'

        $window.Tag.IsReady = $true
        $label.Content | Should -Be -ExpectedValue 'Ready'
    }

    It 'Should pass the source value as $_ for converter scriptblocks' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsReady = $false
            }

            Label $labelName {
                React Content "$windowName.Tag.IsReady" -Converter {
                    if ($_) { 'Ready' } else { 'Not Ready' }
                }
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Content | Should -Be -ExpectedValue 'Not Ready'

        $window.Tag.IsReady = $true
        $label.Content | Should -Be -ExpectedValue 'Ready'
    }

    It 'Should apply -Invert and visibility conversion for bool sources' {
        $id = [guid]::NewGuid().ToString('N')
        $windowName = "Window_$id"
        $labelName = "Label_$id"

        $null = Window $windowName {
            $this.Tag = New-WPFObservableState @{
                IsFullScreen = $false
            }

            Label $labelName {
                React Visibility "$windowName.Tag.IsFullScreen" -Invert
            }
        }

        $window = Reference $windowName
        $label = Reference $labelName

        $label.Visibility | Should -Be -ExpectedValue ([System.Windows.Visibility]::Visible)

        $window.Tag.IsFullScreen = $true
        $label.Visibility | Should -Be -ExpectedValue ([System.Windows.Visibility]::Collapsed)
    }
}
