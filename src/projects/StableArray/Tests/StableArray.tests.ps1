BeforeAll {
    . (Join-Path $PSScriptRoot '..\StableArray.ps1') | Out-Null
}

Describe 'New-StableArray input collection' {
    It 'returns one empty wrapper when no input is supplied' {
        $output = @(New-StableArray)

        $output.Count | Should -Be 1
        $output[0].GetType() | Should -Be ([StableArray])
        $output[0].Count | Should -Be 0
    }

    It 'returns one empty wrapper for an empty pipeline' {
        $output = @(@() | New-StableArray)

        $output.Count | Should -Be 1
        $output[0].GetType() | Should -Be ([StableArray])
        $output[0].Count | Should -Be 0
    }

    It 'adds a directly supplied scalar exactly once' {
        $values = New-StableArray -InputObject 'first'

        $values.Count | Should -Be 1
        $values.Item(0) | Should -Be 'first'
    }

    It 'preserves a directly supplied array as one item' {
        $source = [object[]] @(1, 2)
        $values = New-StableArray -InputObject $source

        $values.Count | Should -Be 1
        [object]::ReferenceEquals($values.Item(0), $source) | Should -BeTrue
    }

    It 'preserves a directly supplied empty array as one item' {
        $source = [object[]] @()
        $values = New-StableArray -InputObject $source

        $values.Count | Should -Be 1
        [object]::ReferenceEquals($values.Item(0), $source) | Should -BeTrue
    }

    It 'retains an explicitly supplied null' {
        $values = New-StableArray -InputObject $null

        $values.Count | Should -Be 1
        $values.Item(0) | Should -BeNullOrEmpty
    }

    It 'ignores an explicitly supplied null when requested' {
        $values = New-StableArray -InputObject $null -IgnoreNulls $true

        $values.Count | Should -Be 0
        $values.IgnoreNulls | Should -BeTrue
    }

    It 'collects pipeline items in order and retains nulls by default' {
        $output = @(1, $null, 2 | New-StableArray)

        $output.Count | Should -Be 1
        $values = $output[0]
        $values.Count | Should -Be 3
        $values.Item(0) | Should -Be 1
        $values.Item(1) | Should -BeNullOrEmpty
        $values.Item(2) | Should -Be 2
    }

    It 'filters pipeline nulls when requested' {
        $values = 1, $null, 2 | New-StableArray -IgnoreNulls $true

        $values.Count | Should -Be 2
        $values.Item(0) | Should -Be 1
        $values.Item(1) | Should -Be 2
    }

    It 'does not flatten an array received as a single pipeline object' {
        $source = [object[]] @(1, 2)
        $values = ,$source | New-StableArray

        $values.Count | Should -Be 1
        [object]::ReferenceEquals($values.Item(0), $source) | Should -BeTrue
    }
}

Describe 'StableArray list-backed storage' {
    It 'starts empty with list-backed storage' {
        $values = [StableArray]::new()

        $values.Items.GetType() | Should -Be ([System.Collections.Generic.List[object]])
        $values.Count | Should -Be 0
        $values.ToArray().GetType() | Should -Be ([object[]])
    }

    It 'normalizes a null constructor argument to an empty list' {
        $values = [StableArray]::new($null)

        $values.Count | Should -Be 0
    }

    It 'preserves scalar conversion through the constructor' {
        [StableArray] $values = 'first'
        $values = 'second'

        $values.Count | Should -Be 1
        $values.Item(0) | Should -Be 'second'
    }

    It 'copies array elements in order, including nulls and nested arrays' {
        $source = [object[]] @('first', $null, @(2, 3))
        $values = [StableArray]::new($source)
        $source[0] = 'changed'

        $values.Count | Should -Be 3
        $values.Item(0) | Should -Be 'first'
        $values.Item(1) | Should -BeNullOrEmpty
        $values.Item(2).GetType() | Should -Be ([object[]])
        $values.Item(2).Count | Should -Be 2
    }

    It 'keeps a non-array collection as a single constructor item' {
        $source = [System.Collections.Generic.List[object]]::new()
        $source.Add('first')
        $source.Add('second')
        $values = [StableArray]::new($source)

        $values.Count | Should -Be 1
        [object]::ReferenceEquals($values.Item(0), $source) | Should -BeTrue
    }

    It 'adds items without replacing the backing list or emitting output' {
        $values = [StableArray]::new()
        $storage = $values.Items

        @($values.Add('first')).Count | Should -Be 0
        $values.Add(@(2, 3))

        [object]::ReferenceEquals($values.Items, $storage) | Should -BeTrue
        $values.Count | Should -Be 2
        $values.Item(1).Count | Should -Be 2
    }

    It 'only ignores added nulls when requested' {
        $values = [StableArray]::new()
        $values.Add($null)
        $values.IgnoreNulls = $true
        $values.Add($null)
        $values.Add('kept')

        $values.Count | Should -Be 2
        $values.Item(0) | Should -BeNullOrEmpty
        $values.Item(1) | Should -Be 'kept'
    }

    It 'clears and reuses the existing list' {
        $values = [StableArray]::new(@(1, 2))
        $storage = $values.Items
        $values.Clear()

        $values.Count | Should -Be 0
        [object]::ReferenceEquals($values.Items, $storage) | Should -BeTrue
        $values.Add(3)
        $values.Item(0) | Should -Be 3
    }

    It 'returns an independent array snapshot' {
        $values = [StableArray]::new(@('first', 'second'))
        $snapshot = $values.ToArray()
        $snapshot[0] = 'changed'
        $values.Add('third')

        $snapshot.GetType() | Should -Be ([object[]])
        $snapshot.Count | Should -Be 2
        $values.Item(0) | Should -Be 'first'
        $values.Count | Should -Be 3
    }

    It 'iterates the backing list without enumerating the wrapper' {
        $values = [StableArray]::new(@('first', 'second'))

        ($values -is [System.Collections.IEnumerable]) | Should -BeFalse
        @($values | ForEach-Object { $_ }).Count | Should -Be 1
        $enumerator = $values.GetEnumerator()
        $enumerator.MoveNext() | Should -BeTrue
        $enumerator.Current | Should -Be 'first'
        $enumerator.MoveNext() | Should -BeTrue
        $enumerator.Current | Should -Be 'second'
        $enumerator.MoveNext() | Should -BeFalse
    }
}
