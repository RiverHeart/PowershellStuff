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
                $factoryType = $InputObject.Type

                $implicitSetterFunctions = New-WPFStylePropertyHandler `
                    -ScriptBlock $ScriptBlock `
                    -ContextName 'Factory'

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

                $AppRootProperty = $InputObject.PSObject.Properties['_WPFAppRoot']
                $AppContentProperty = $InputObject.PSObject.Properties['_WPFAppContent']
                if ($InputObject -is [System.Windows.Window] -and $AppRootProperty -and $AppRootProperty.Value -and $AppContentProperty -and $AppContentProperty.Value) {

                    if ($Child -is [System.Windows.Controls.MenuItem]) {
                        $Menu = Get-WPFMenu -Window $InputObject
                        $AppRootProperty = $InputObject.PSObject.Properties['_WPFAppRoot']
                        if (-not $Menu -and $AppRootProperty.Value) {
                            $Menu = New-WPFMenu -Window $InputObject
                        }
                        if ($Menu) {
                            Add-WPFObject $Menu $Child
                        }
                    } elseif ($Child -is [System.Windows.Controls.Menu]) {
                        Add-WPFAppRootChild -Window $InputObject -Child $Child -Placement 'Menu'
                    } elseif ($Child -is [System.Windows.Controls.Primitives.StatusBar]) {
                        Add-WPFAppRootChild -Window $InputObject -Child $Child -Placement 'StatusBar'
                    } else {
                        Add-WPFAppRootChild -Window $InputObject -Child $Child -Placement 'Content'
                    }
                } else {
                    Add-WPFObject $InputObject $Child
                }
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

