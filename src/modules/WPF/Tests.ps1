if ($PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

# Look into https://github.com/PowerShell/PowerShell/blob/master/test/powershell/engine/ParameterBinding/StaticParameterBinder.Tests.ps1
function Should-BindParams {
    [CmdletBinding()]
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

#Invoke-Pester -Path "$PSScriptRoot/Tests"
Invoke-Pester -Path "$PSScriptRoot/Tests/New-WPFGridColumn.Tests.ps1"
