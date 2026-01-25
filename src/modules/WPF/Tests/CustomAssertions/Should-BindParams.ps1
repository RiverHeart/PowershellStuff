<#
.SYNOPSIS
    Custom Pester assertion that uses static analysis to check if parameters are bound properly.

.LINK
    Class | https://github.com/PowerShell/PowerShell/blob/master/src/System.Management.Automation/engine/CommandCompletion/PseudoParameterBinder.cs
    Usage | https://github.com/PowerShell/PowerShell/blob/master/test/powershell/engine/ParameterBinding/StaticParameterBinder.Tests.ps1

.EXAMPLE
    Register custom assertion and use in test.

    $IsRegistered = Get-ShouldOperator | Where-Object { $_.Name -eq 'BindParams' }
    if (-not $IsRegistered) {
        $ShouldOpParams = @{
            Name = 'BindParams'
            InternalName = 'Should-BindParams'
            Test = ${function:Should-BindParams}
            Alias = 'Bind'
        }

        Add-ShouldOperator @ShouldOpParams
    }

    Describe 'Example' {
        It 'Should bind Foobar to object param' {
            { Write-Host 'Foobar' } | Should -BindParams @{ Object = 'Foobar' }
        }
    }
#>
function Should-BindParams {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', Scope='Function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', Scope='Function')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ActualValue,

        [Parameter(Mandatory)]
        [hashtable] $ExpectedBindings,

        [switch] $Negate,
        [System.Management.Automation.SessionState] $CallerSessionState
    )

    process {
        $FailureMessage = @()
        $CommandAst = $ActualValue.Ast.Find({
            param($AstNode) $AstNode -is [System.Management.Automation.Language.CommandAst]}, $false)
        $ParamBindResult = [System.Management.Automation.Language.StaticParameterBinder]::BindCommand($CommandAst, $false)

        if ($ParamBindResult.BindingExceptions) {
            $FailureMessage += $ParamBindResult.BindingExceptions.values.bindingexception.message -join "`n"
        } else {
            foreach($BoundParam in $ParamBindResult.BoundParameters.GetEnumerator()) {
                $BPName, $BPValue = $BoundParam.Key, $BoundParam.Value.SafeGetValue()

                if ($ExpectedBindings.ContainsKey($BPName) -and
                    $Null -ne $ExpectedBindings[$BPName] -and
                    $BPValue -ne $ExpectedBindings[$BPName]
                ) {
                    $FailureMessage += "Expected value '$($ExpectedBindings[$BPName])' for '$BPName' but got '$BPValue' instead."
                } else {
                    $FailureMessage += "Found unexpected bound param '$BPName'"
                    continue
                }
            }
        }

        return [pscustomobject] @{
            Succeeded = 'Bindings matched expected values!'
            FailureMessage = $FailureMessage -join "`n"
        }
    }
}

$IsRegistered = Get-ShouldOperator | Where-Object { $_.Name -eq 'BindParams' }
if (-not $IsRegistered) {
    $ShouldOpParams = @{
        Name = 'BindParams'
        InternalName = 'Should-BindParams'
        Test = ${function:Should-BindParams}
        Alias = 'Bind'
    }

    Add-ShouldOperator @ShouldOpParams
}
