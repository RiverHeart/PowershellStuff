<#
.SYNOPSIS
    Updates a WPF object depending on the values returned
    with its' scriptblock.

.DESCRIPTION
    Updates a WPF object depending on the values returned
    with its' scriptblock.

    Intended to reduce code duplication for common operations
    like modifying object properties and adding handlers.

    Can return each result for further processing by the calling
    function.

.NOTES
    This function is only intended to be called by controls.
#>
function Update-WPFObject {
    [CmdletBinding(DefaultParameterSetName='ByScriptBlock')]
    [OutputType([void], [object[]])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=0)]
        [Parameter(Mandatory,ParameterSetName='ByChildObject',Position=0)]
        [object] $InputObject,

        [Parameter(Mandatory,ParameterSetName='ByScriptBlock',Position=1)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory,ParameterSetName='ByChildObject',Position=1)]
        [object[]] $ChildObjects,

        # Allow caller to get results for custom updates
        # without having to rerun the scriptblock
        [switch] $PassThru
    )

    $thisName = if ($InputObject.Name) { $InputObject.Name } else { '__Nameless__' }
    $thisType = $InputObject.GetType().Name
    $PSVars = New-WPFVariableList -InputObject $InputObject
    $strictUnexpectedChild = Test-WPFStrictUnexpectedChildMode

    Write-Debug "Updating WPF object '$thisName' ($thisType)"

    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
            if ($InputObject -is [System.Windows.FrameworkElementFactory]) {
                $factoryDslCommands = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($dslCommandName in @('Setter')) {
                    $null = $factoryDslCommands.Add($dslCommandName)
                }

                $factoryType = $InputObject.Type

                $isFactoryDependencyProperty = {
                    param(
                        [Parameter(Mandatory)]
                        [string] $PropertyName
                    )

                    $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($PropertyName, $factoryType, $factoryType)
                    return ($null -ne $descriptor)
                }

                $implicitSetterCommandMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                $commandAsts = $ScriptBlock.Ast.FindAll({
                        param($Ast)
                        $Ast -is [System.Management.Automation.Language.CommandAst]
                    }, $true)

                foreach ($commandAst in $commandAsts) {
                    $commandName = $commandAst.GetCommandName()
                    if ([string]::IsNullOrWhiteSpace($commandName)) {
                        continue
                    }

                    $isExplicitProperty = $commandName.EndsWith(':')
                    $propertyName = if ($isExplicitProperty) {
                        $commandName.Substring(0, $commandName.Length - 1)
                    } else {
                        $commandName
                    }

                    if ([string]::IsNullOrWhiteSpace($propertyName)) {
                        continue
                    }

                    $treatAsImplicitSetter = $false

                    if ($isExplicitProperty) {
                        $treatAsImplicitSetter = $true
                    } elseif ($factoryDslCommands.Contains($propertyName)) {
                        # Reserved DSL keywords remain explicit unless caller
                        # requests property mode using a trailing ':'.
                        $treatAsImplicitSetter = $false
                    } elseif (& $isFactoryDependencyProperty -PropertyName $propertyName) {
                        # Prefer dependency properties over commands to reduce collisions.
                        $treatAsImplicitSetter = $true
                    } elseif ($null -ne (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
                        $treatAsImplicitSetter = $false
                    } else {
                        $treatAsImplicitSetter = $true
                    }

                    if ($treatAsImplicitSetter -and -not $implicitSetterCommandMap.ContainsKey($commandName)) {
                        $implicitSetterCommandMap[$commandName] = $propertyName
                    }
                }

                $implicitSetterFunctions = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($factoryCommandName in $implicitSetterCommandMap.Keys) {
                    $propertyName = $implicitSetterCommandMap[$factoryCommandName]
                    $functionBody = [scriptblock]::Create(@"
param(
    [Parameter(Mandatory, Position = 0)]
    [AllowNull()]
    [object]`$Value,

    [Parameter()]
    [switch]`$Resource,

    [Parameter()]
    [string]`$Target,

    [Parameter()]
    [ValidateSet('Chrome')]
    [string]`$Scope,

    [Parameter(ValueFromRemainingArguments = `$true)]
    [object[]]`$Remaining
)

if (`$null -ne `$Remaining -and `$Remaining.Count -gt 0) {
    throw "Factory shorthand for property '$propertyName' received unsupported trailing arguments: `$(`$Remaining -join ', ')"
}

`$setterArgs = @{
    Property = '$propertyName'
    Value = `$Value
}

if (`$PSBoundParameters.ContainsKey('Resource')) {
    `$setterArgs['Resource'] = `$Resource
}

if (`$PSBoundParameters.ContainsKey('Target')) {
    `$setterArgs['Target'] = `$Target
}

if (`$PSBoundParameters.ContainsKey('Scope')) {
    `$setterArgs['Scope'] = `$Scope
}

Setter @setterArgs
"@)
                    $implicitSetterFunctions[$factoryCommandName] = $functionBody
                }

                $ChildObjects = $ScriptBlock.InvokeWithContext($implicitSetterFunctions, $PSVars, @())
            } else {
                $ChildObjects = $ScriptBlock.InvokeWithContext($null, $PSVars)
            }
        }

        foreach ($Child in $ChildObjects) {
            if ($null -eq $Child) {
                continue
            }

            # SetBinding() returns BindingExpression objects; these are side-effect
            # results, not visual children, and should not be auto-attached.
            if ($Child -is [System.Windows.Data.BindingExpressionBase]) {
                Write-Debug "Ignoring binding result output '$($Child.GetType().Name)'"
                continue
            }

            $ChildName = if ($Child.Name) { $Child.Name } else { '__Nameless__' }
            $ChildType = $Child.GetType().Name

            # Returning objects early so I don't need to worry about breaking out
            # of a nested if statement later. Calling `continue` is much simpler.
            if ($PassThru) {
                Write-Output $Child
            }

            # Command
            if (Test-WPFType $Child 'Command') {
                Write-Debug "Adding Command to object '$thisName' ($thisType)"
                Set-WPFObjectSpec -InputObject $InputObject -Name 'Command' -Value $Child | Out-Null
            }
            # Control
            elseif (Test-WPFType $Child @('Control', 'GridDefinition', 'DataGridColumn')) {
                # NOTE: Most controls are auto-attaching to their parents during
                # creation so their parent is available to their children before
                # recursing through their scriptblock but for objects being created
                # on the fly or re-parented I think it still makes sense to use Update-WPFObject.

                Add-WPFObject $InputObject $Child
            }
            # Shape
            elseif (Test-WPFType $Child 'Shape') {
                # My thinking here is that while a user can assign a Path to a button's content
                # property other objects are probably assigned differently so it's just be easier
                # to add them based on the object type so you don't need to remember.
                if ($InputObject -is [System.Windows.Controls.Button]) {
                    $InputObject.Content = $Child
                } elseif ($InputObject -is [System.Windows.Controls.Border]) {
                    $InputObject.Child = $Child
                }
            }
            else {
                $message = "Cannot add '$ChildName' ($ChildType) to '$thisName' ($thisType)"
                if ($strictUnexpectedChild) {
                    throw $message
                }

                # Maybe instead of erroring we just pass unhandled items further up the chain?
                Write-Warning $message
            }
        }

        Update-WPFObjectSpec -InputObject $InputObject

        Write-Debug "Finished updating '$thisName' ($thisType)"
    } catch {
        if ($strictUnexpectedChild) {
            throw
        }

        # Get base exception and surface here?
        Write-Error "Failed to update '$thisName' ($thisType) with error: $_"
        return
    }
}

