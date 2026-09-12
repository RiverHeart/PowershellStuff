Describe 'Add-PSType' -Tag 'WpfDesigner' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../../../../modules/WPF/WPF.psd1" -Force
    }

    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../../../WpfDesigner.psm1" -Force
    }

    It 'Should tag an object with an arbitrary type name' {
        $Target = [System.Windows.Controls.StackPanel]::new()

        Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type'

        Test-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type' | Should -Be -ExpectedValue $true
    }

    It 'Should be idempotent when called twice' {
        $Target = [System.Windows.Controls.StackPanel]::new()

        Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type'
        Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type'

        ($Target.PSObject.TypeNames | Where-Object { $_ -eq 'Some.Arbitrary.Type' }).Count | Should -Be -ExpectedValue 1
    }

    It 'Should accept pipeline input' {
        $First = [System.Windows.Controls.Label]::new()
        $Second = [System.Windows.Controls.Label]::new()

        $First, $Second | Add-PSType -TypeName 'Some.Arbitrary.Type'

        Test-PSType -InputObject $First -TypeName 'Some.Arbitrary.Type' | Should -Be -ExpectedValue $true
        Test-PSType -InputObject $Second -TypeName 'Some.Arbitrary.Type' | Should -Be -ExpectedValue $true
    }

    It 'Should pass the object through when -PassThru is set' {
        $Target = [System.Windows.Controls.Label]::new()

        $Result = Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type' -PassThru

        $Result | Should -Be -ExpectedValue $Target
    }

    It 'Should not emit anything when -PassThru is not set' {
        $Target = [System.Windows.Controls.Label]::new()

        $Result = Add-PSType -InputObject $Target -TypeName 'Some.Arbitrary.Type'

        $Result | Should -Be -ExpectedValue $null
    }
}
