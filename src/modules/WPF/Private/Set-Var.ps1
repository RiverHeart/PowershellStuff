<#
.SYNOPSIS
    Defines a function to create constant variables in the caller's scope.

.DESCRIPTION
    The 'Const' function allows you to create constant variables using Powershell syntax.
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
    Create constant from scalar value.

    Const Pi = 3.14

.EXAMPLE
    Create constant from a more complex expression by wrapping it in parentheses
    so the expression is evaluated in the caller's context and the resulting
    value is assigned to the constant.

    Const ButtonWidth = (16 * 4)

.EXAMPLE
    Create a constant array.

    Const PrimaryColors = @('Red', 'Green', 'Blue')

.EXAMPLE
    Create a constant with a value that requires type conversion,
    demonstrating that PSConverters are applied.

    # This should be converted to a Thickness object with Left=4, Top=3, Right=4, Bottom=3.
    Const [Thickness] ButtonMargin2 = 4, 3, 4, 3

.EXAMPLE
    Create a constant variable named 'Pi' with the value 3.14 and demonstrate
    that it cannot be changed.

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
function Set-Var {
    [CmdletBinding()]
    [Alias('const', 'readonly', 'global', 'local')]
    param (
        [Parameter(Mandatory,ValueFromRemainingArguments)]
        [ValidateNotNullOrEmpty()]
        [object[]] $ArgumentList
    )

    $EqualsIndex = $ArgumentList.IndexOf('=')

    if ($EqualsIndex -lt 1) {
        throw [System.Data.InvalidExpressionException]::new(
            "Expected assignment syntax: Const Name = Value or Const [Type] Name = Value.")
    }

    $Type = $null
    $Name = $null
    # Expected structure: const Name = Value
    if ($EqualsIndex -eq 1) {
        $Name = [string] $ArgumentList[0]
    }
    # Expected structure: const [Type] Name = Value
    elseif ($EqualsIndex -eq 2) {
        $Type = $ArgumentList[0]
        $Name = [string] $ArgumentList[1]
    } else {
        throw [System.Data.InvalidExpressionException]::new(
            "Expected exactly one token (name) or two tokens (type and name) before '='.")
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw [System.ArgumentException]::new("The variable name cannot be null or empty.")
    }

    if ($EqualsIndex -ge ($ArgumentList.Count - 1)) {
        throw [System.ArgumentException]::new("A value is required to the right of '='.")
    }

    $ValueTokens = $ArgumentList[($EqualsIndex + 1)..($ArgumentList.Count - 1)]
    if ($ValueTokens.Count -eq 1) {
        $Value = $ValueTokens[0]
    } else {
        $Value = $ValueTokens
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

    $InvocationName = $MyInvocation.InvocationName.ToLowerInvariant()
    $VarParams = @{
        Name  = $Name.Trim()
        Force = $true
    }

    switch ($InvocationName) {
        'const' {
            $VarParams.Option = 'Constant'
            $VarParams.Scope = 1
        }
        'readonly' {
            $VarParams.Option = 'ReadOnly'
            $VarParams.Scope = 1
        }
        'global' {
            $VarParams.Scope = 'Global'
        }
        'local' {
            $VarParams.Scope = 1
        }
        default {
            $VarParams.Scope = 1
        }
    }

    $existingVariable = Get-Variable -Name $VarParams.Name -Scope $VarParams.Scope -ErrorAction SilentlyContinue
    if ($null -ne $existingVariable) {
        throw [System.Management.Automation.SessionStateException]::new(
            "Cannot define constant '$($VarParams.Name)' because a variable with that name already exists in caller scope.")
    }

    $ResolvedType = $null
    if ($Type) {
        if ($Type -is [Type]) {
            $ResolvedType = $Type
        } elseif ($Type -is [string]) {
            $TypeName = $Type.Trim(' []')
            $ResolvedType = [System.Management.Automation.PSTypeName]::new($TypeName).Type
        }

        if (-not $ResolvedType) {
            throw [System.ArgumentException]::new("Could not resolve type '$Type'.")
        }

        $VarParams.Value = [System.Management.Automation.LanguagePrimitives]::ConvertTo($Value, $ResolvedType)
    } else {
        $VarParams.Value = $Value
    }

    # Ensure that PSConverters are applied to the value as they would be in
    # a normal variable assignment.
    New-Variable @VarParams | Out-Null
}
