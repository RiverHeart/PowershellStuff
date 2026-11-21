BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\GrabBag.psd1') -Force -DisableNameChecking -ErrorAction Stop
}

Describe 'Add-ToCollection' {
    It 'keeps empty and singleton array shapes without emitting results' {
        $Items = @()
        $Output = @($null | Add-ToCollection -Collection ([ref] $Items))
        $Items.GetType() | Should -Be ([object[]])
        $Items.Count | Should -Be 0
        $Output | Should -HaveCount 0
        $Output = @(42 | Add-ToCollection -Collection ([ref] $Items))
        $Items.GetType() | Should -Be ([object[]])
        $Items.Count | Should -Be 1
        $Items[0] | Should -Be 42
        $Output | Should -HaveCount 0
    }

    It 'skips null items unless AllowNull is specified' {
        $Skipped = @()
        $Preserved = @()
        1, $null, 3 | Add-ToCollection -Collection ([ref] $Skipped)
        1, $null, 3 | Add-ToCollection -Collection ([ref] $Preserved) -AllowNull
        $Skipped | Should -Be @(1, 3)
        $Preserved.Count | Should -Be 3
        ($null -eq $Preserved[1]) | Should -BeTrue
    }

    It 'adds an explicitly supplied array as one nested item' {
        $Items = @()
        $Nested = @(1, $null, 3)
        Add-ToCollection -Collection ([ref] $Items) -InputObject $Nested
        $Items.Count | Should -Be 1
        [object]::ReferenceEquals($Items[0], $Nested) | Should -BeTrue
        $Items[0].Count | Should -Be 3
    }

    It 'preserves typed arrays and does not replace other references to the original' {
        $Items = [int[]] @(1)
        $Original = $Items
        Add-ToCollection -Collection ([ref] $Items) -InputObject 2
        $Items.GetType() | Should -Be ([int[]])
        $Items | Should -Be @(1, 2)
        $Original | Should -Be @(1)
        [object]::ReferenceEquals($Items, $Original) | Should -BeFalse
    }

    It 'rejects incompatible typed-array items without replacing the destination' {
        $Items = [int[]] @(1)
        $Original = $Items
        { Add-ToCollection -Collection ([ref] $Items) -InputObject '2' } | Should -Throw
        [object]::ReferenceEquals($Items, $Original) | Should -BeTrue
        $Items.Count | Should -Be 1
    }

    It 'retains earlier successful additions when a later item fails' {
        $Items = [int[]] @()
        $Failure = $null
        try {
            1, 'invalid', 3 | Add-ToCollection -Collection ([ref] $Items)
        } catch {
            $Failure = $_
        }
        $Failure | Should -Not -BeNullOrEmpty
        $Items | Should -Be @(1)
    }

    It 'mutates an ArrayList in place without leaking Add indices' {
        $Items = [System.Collections.ArrayList]::new()
        $Original = $Items
        $Output = @(1, $null, 3 | Add-ToCollection -Collection ([ref] $Items) -AllowNull)
        [object]::ReferenceEquals($Items, $Original) | Should -BeTrue
        $Items.Count | Should -Be 3
        ($null -eq $Items[1]) | Should -BeTrue
        $Output | Should -HaveCount 0
    }

    It 'mutates a generic list without changing its identity' {
        $Items = [System.Collections.Generic.List[object]]::new()
        $Original = $Items
        Add-ToCollection -Collection ([ref] $Items) -InputObject 42
        [object]::ReferenceEquals($Items, $Original) | Should -BeTrue
        $Items.Count | Should -Be 1
    }

    It 'rejects unsupported destinations even when the input is skipped null' {
        foreach ($Items in @('text', 42, [System.Collections.Queue]::new(), @{})) {
            { Add-ToCollection -Collection ([ref] $Items) -InputObject $null } |
                Should -Throw '*must reference an array*'
        }
        $Items = $null
        { Add-ToCollection -Collection ([ref] $Items) -InputObject $null } |
            Should -Throw '*must reference an array*'
    }

    It 'rejects read-only and non-array fixed-size lists' {
        $Items = [System.Collections.ArrayList]::ReadOnly([System.Collections.ArrayList]::new())
        { Add-ToCollection -Collection ([ref] $Items) -InputObject 42 } |
            Should -Throw '*read-only or fixed-size*'
        $Items = [System.Collections.ArrayList]::FixedSize([System.Collections.ArrayList]::new())
        $Original = $Items
        { Add-ToCollection -Collection ([ref] $Items) -InputObject 42 } |
            Should -Throw '*read-only or fixed-size*'
        [object]::ReferenceEquals($Items, $Original) | Should -BeTrue
    }

    It 'rejects multidimensional and non-zero-based arrays' {
        $Items = [array]::CreateInstance([object], 2, 2)
        { Add-ToCollection -Collection ([ref] $Items) -InputObject 42 } |
            Should -Throw '*zero-based, one-dimensional*'
        $Items = [array]::CreateInstance([object], [int[]] @(2), [int[]] @(1))
        { Add-ToCollection -Collection ([ref] $Items) -InputObject 42 } |
            Should -Throw '*zero-based, one-dimensional*'
    }
}
