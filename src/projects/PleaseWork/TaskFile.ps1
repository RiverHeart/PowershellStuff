$foo = 'foo'

$env:PLEASE_DEFAULT_TASK = 'lint'

<#
.DESCRIPTION
    Foobar
#>
start: build {
    param(
        [Parameter(Mandatory)]
        [string] $foo
    )
    Write-Output "Starting application: $foo"
}


lint: {
    Write-Output 'Executing lint'
}

test: lint {
    Write-Output 'Executing test'
}

build: test {
    Write-Output 'Executing build'
}

foo: {
    Write-Output $foo
}
