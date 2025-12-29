<#
.SYNOPSIS
    Emulates the brace expansion for strings found in Bash.

.DESCRIPTION
    Emulates the brace expansion for strings found in Bash.

    There is no limit to the number of braces that can be expanded
    within a string. Two expansion types are supported.

    # String Expansion

    String expansion takes a string such as "example/{foo,bar,baz}"
    and creates a string for each item found within the braces and
    outputs:
      * example/foo
      * example/bar
      * example/baz

    # Numeric Range Expansion

    Numeric range expansion takes a string such as "example/{1..3}"
    and creates a string for each number between and including the
    start and end values, outputting:
      * example/1
      * example/2
      * example/3

.EXAMPLE
    Expands a string into @(test_1.txt, test_2.txt, test_1.log, test_2.log)
    and pass to New-Item.

    Register-StringBraceExpansion
    New-Item "test_{1..2}{.txt,.log}".expand() -WhatIf

.EXAMPLE
    Expands a string into @(test_1.txt, test_2.txt, test_1.log, test_2.log)
    and pass to New-Item using pipeline.

    Register-StringBraceExpansion
    "test_{1..2}{.txt,.log}".expand() | New-Item -Path { $_ } -WhatIf

.LINK
    https://stackoverflow.com/a/77233613/5339918
#>

function Register-StringBraceExpansion {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if ($null -ne "".Expand) {
        Write-Verbose "StringExpansion already registered with String type."
        return
    }

    $ExpandMethod = [scriptblock] {

        $Expandables = [Regex]::Matches($this, "{([^}]+)}")  # Match everything between curlies that isn't a right curly
        $Strings = @($this)  # Seed initial value for foreach loop

        foreach ($Expandable in $Expandables) {

            # Return array based on whether we're working with strings
            # or numbers.
            $Transforms = switch ($Expandable.Groups[1].Value) {
                { $_.Contains(',')  } { $_.Split(',') }
                { $_.Contains('..') } { [int]$Start, [int]$End = $_ -split '\.\.'; $Start..$End }
                default { throw [System.InvalidOperationException] "Could not determine how to expand string." }
            }

            $TempStrings = @()
            foreach ($Transform in $Transforms) {
                foreach ($String in $Strings) {
                    $TempStrings += $String -Replace $Expandable.Value, $Transform
                }
            }

            # Overwrite to ensure that expandables in the next run only used
            # transformed strings.
            $Strings = $TempStrings
        }

        return $Strings
    }

    Update-TypeData -TypeName 'System.String' `
        -MemberType 'ScriptMethod' `
        -MemberName 'Expand' `
        -Value $ExpandMethod `
        -Force
}
