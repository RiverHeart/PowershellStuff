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

    $SelfName = if ($InputObject.Name) { $InputObject.Name } else { '<Nameless>' }
    $SelfType = $InputObject.GetType().Name

    # Set `$self` as reference to the current object.
    # `$this` would be more idiomatic but this avoids
    # potential issues arising from modifying automatic variables.
    $PSVars = @(
        [psvariable]::new('self', $InputObject)
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByScriptBlock') {
            $ChildObjects = $ScriptBlock.InvokeWithContext($null, $PSVars)
        }

        foreach ($Child in $ChildObjects) {
            $ChildName = if ($Child.Name) { $Child.Name } else { '<Nameless>' }
            $ChildType = $Child.GetType().Name

            # Returning objects early so I don't need to worry about breaking out
            # of a nested if statement later. Calling `continue` is much simpler.
            if ($PassThru) {
                Write-Output $Child
            }
            # Command
            elseif (Test-WPFType $Child 'Command') {
                Write-Debug "Adding Command to object '$SelfName' ($SelfType)"
                $InputObject.Command = $Child
            }
            # Control
            elseif (Test-WPFType $Child @('Control', 'GridDefinition')) {
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
                }
            }
            else {
                # Maybe instead of erroring we just pass unhandled items further up the chain?
                Write-Warning "Cannot add '$ChildName' ($ChildType) to '$SelfName' ($SelfType)"
            }
        }
    } catch {
        # Get base exception and surface here?
        Write-Error "Failed to update '$SelfName' ($SelfType) with error: $_"
        return
    }
}
