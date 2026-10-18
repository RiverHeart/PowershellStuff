BeforeAll {
    Add-Type -Path (Join-Path $PSScriptRoot '..\StableList.cs') -ErrorAction Stop
}

Describe 'Generic StableList sequence null handling' {
    It 'retains null elements by default' {
        $values = [StableList[object]]::new([object[]] @('first', $null, 'last'))

        $values.FilterNulls | Should -BeFalse
        $values.Count | Should -Be 3
        $values[0] | Should -Be 'first'
        $values[1] | Should -BeNullOrEmpty
        $values[2] | Should -Be 'last'
    }

    It 'filters sequence nulls and subsequent additions when requested' {
        $source = [System.Collections.Generic.List[object]]::new()
        $source.Add($null)
        $source.Add('first')
        $source.Add($null)
        $source.Add('last')
        $source.Add($null)
        $values = [StableList[object]]::new($source, $true)
        $values.Add($null)
        $values.Add('added')

        $values.FilterNulls | Should -BeTrue
        $values.Count | Should -Be 3
        $values[0] | Should -Be 'first'
        $values[1] | Should -Be 'last'
        $values[2] | Should -Be 'added'
    }

    It 'creates an empty list from a null sequence while retaining the option' {
        $values = [StableList[object]]::new($null, $true)
        $values.Add($null)

        $values.FilterNulls | Should -BeTrue
        $values.Count | Should -Be 0
    }

    It 'creates an empty list from an all-null sequence when filtering' {
        $values = [StableList[object]]::new([object[]] @($null, $null), $true)

        $values.Count | Should -Be 0
    }

    It 'retains zero and other non-nullable value types when filtering' {
        $values = [StableList[int]]::new([int[]] @(0, 1), $true)

        $values.Count | Should -Be 2
        $values[0] | Should -Be 0
        $values[1] | Should -Be 1
    }

    It 'filters nullable value types without removing zero' {
        $values = [StableList[System.Nullable[int]]]::new(
            [System.Nullable[int][]] @($null, 0, 1), $true
        )

        $values.Count | Should -Be 2
        $values[0] | Should -Be 0
        $values[1] | Should -Be 1
    }

    It 'allows the option to change without filtering index replacement' {
        $values = [StableList[object]]::new([object[]] @('first'), $true)
        $values[0] = $null
        $values.FilterNulls = $false
        $values.Add($null)

        $values.Count | Should -Be 2
        $values[0] | Should -BeNullOrEmpty
        $values[1] | Should -BeNullOrEmpty
    }

    It 'preserves parameterless construction and non-enumerating behavior' {
        $values = [StableList[object]]::new()
        $values.Add($null)

        $values.FilterNulls | Should -BeFalse
        $values.Count | Should -Be 1
        ($values -is [System.Collections.IEnumerable]) | Should -BeFalse
        @($values | ForEach-Object { $_ }).Count | Should -Be 1
        $values.ToArray().GetType() | Should -Be ([object[]])
    }

    Describe 'Non-generic StableList null filtering' {
        It 'retains nulls by default and filters subsequent additions when enabled' {
            $values = [StableList]::new()
            $values.FilterNulls | Should -BeFalse
            $values.Add($null)
            $values.FilterNulls = $true
            $values.Add($null)
            $values.Add('kept')

            $values.Count | Should -Be 2
            $values[0] | Should -BeNullOrEmpty
            $values[1] | Should -Be 'kept'
        }

        It 'does not filter constructor contents or index replacement' {
            $values = [StableList]::new([object[]] @($null, 'first'))
            $values.FilterNulls = $true
            $values[1] = $null

            $values.Count | Should -Be 2
            $values[0] | Should -BeNullOrEmpty
            $values[1] | Should -BeNullOrEmpty
        }
    }
}
