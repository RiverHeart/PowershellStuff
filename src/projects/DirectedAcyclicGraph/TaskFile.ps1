$foo = 'foo'


start: build {
    Write-Output 'Starting application'
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
