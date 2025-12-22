<#
.SYNOPSIS
    Memoizes a function and its' parameters for quick recall.

.EXAMPLE
    Basic usage

    function Get-Fibonacci {
        param([int] $n)
        if ($n -le 1) { return $n }
        # Simulate some delay for demonstration
        Start-Sleep -Milliseconds 100
        return (Get-Fibonacci ($n - 1)) + (Get-Fibonacci ($n - 2))
    }

    $ErrorActionPreference = 'Stop'
    $Script:MemoizationCache = @{}

    # Call memoized function
    $fib5 = Get-MemoizedResult `
        -Function { Get-Fibonacci $args[0] } `
        -Arguments @(5)
    $fib5_cached = Get-MemoizedResult `
        -Function { Get-Fibonacci $args[0] } `
        -Arguments @(5)  # This will be retrieved from cache

    Write-Host "Original: $fib5"
    Write-Host "Cached: $fib5_cached"
#>
function Get-MemoizedResult {
    param(
        [Parameter(Mandatory,HelpMessage='The function to memoize.')]
        [scriptblock] $Function,

        [Parameter(HelpMessage='The parameters to pass to the memoized function.')]
        [object[]] $Arguments  # Args passed to the original function
    )

    # Generate a unique key for the cache based on the function and its arguments
    $Key = "$($Function.ToString())" + ($Arguments | ConvertTo-Json -Compress)

    # Check if the result is already in the cache
    if ($script:MemoizationCache.ContainsKey($Key)) {
        Write-Verbose "Returning cached result for key: $Key"
        return $Script:MemoizationCache[$Key]
    }
    else {
        Write-Verbose "Calculating and caching result for key: $Key"
        # Execute original function with its arguments
        $Result = Invoke-Command `
            -Scriptblock $Function `
            -ArgumentList $Arguments

        $Script:MemoizationCache[$Key] = $Result
        return $Result
    }
}
