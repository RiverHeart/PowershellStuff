<#
.SYNOPSIS
    Defines a function to create constant variables in the caller's scope.

.DESCRIPTION
    The 'Const' function allows you to create constant variables using a DSL-like syntax.
    It takes a variable name, an operator (which must be '='), and a value. The variable
    is created with the 'Constant' option, meaning its value cannot be changed after assignment.

.NOTES
    WARNING!

    Wildly experimental. Powershell maintainers would probably hate to see this.

    Note to myself. While creating the syntax `const ButtonWidth = 56` worked but
    failed when the right hand side was an expression like `const ButtonWidth = 16 * 4`.
    Unless I can figure out how to get the expression to evaluate in the context of the caller
    and apply PSConverters (Margin/CornerRadius), this is probably not viable.

.EXAMPLE
    Create a constant variable using DSL syntax:

    Const Pi = 3.14

.EXAMPLE
    Create a constant variable named 'Pi' with the value 3.14 and demonstrate
    that it cannot be changed:

    # Calling inside a script block so the const variable is ephemeral.
    {
        Const Pi = 3.14
        try {
            $Pi = 'fail' # This should throw an error because Pi is a constant.
        } catch [System.Management.Automation.SessionStateException] {
            Write-Host "Error: $_"
        }
        Write-Host "The value of Pi is $Pi."
    }.Invoke()
#>
function Const {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [char] $Operator,

        [Parameter(Mandatory,ValueFromRemainingArguments)]
        [object] $Value
    )

    $PSVariables = $PSCmdlet.SessionState.PSVariable

    if ($Operator -ne '=') {
        throw [System.Data.InvalidExpressionException]::new(
            "The operator must be '='.")
    }

    $Name = $Name.Trim()

    if ($PSVariables.Get($Name)) {
        throw "A variable named '$Name' already exists."
    }

    # ValueFromRemainingArguments may surface as a list/array.
    # Unwrap single-value assignments for expected scalar semantics.
    if ($Value -is [System.Collections.IList]) {
        if ($Value.Count -eq 1) {
            $Value = $Value[0]
        } elseif ($Value -isnot [object[]]) {
            $Value = @($Value)
        }
    }

    # Ensure that PSConverters are applied to the value as they would be in
    # a normal variable assignment.
    New-Variable -Name $Name -Value $Value -Option Constant -Force | Out-Null
    $PSVar = Get-Variable -Name $Name

    # Create a constant variable in the caller's scope.
    # Set WhatIf to $false to ensure the variable is always assigned
    # since that's how normal variable assignment works.
    $PSVariables.Set($PSVar)
}


