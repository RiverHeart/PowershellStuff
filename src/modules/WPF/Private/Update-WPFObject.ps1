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
    [CmdletBinding()]
    [OutputType([void], [object[]])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        # Allow caller to get results for custom updates
        # without having to rerun the scriptblock
        [switch] $PassThru
    )

    $Name = $InputObject.Name

    try {
        foreach ($Result in $ScriptBlock.Invoke()) {
            $ChildName = if ($Result.Name) { $Result.Name } else { 'Unknown' }

            switch ($Result.WPF_TYPE) {
                'Properties' {
                    foreach($KVP in $Result.GetEnumerator()) {
                        Write-Debug "Updating property $($KVP.Name) with $($KVP.Value)"
                        $InputObject.($KVP.Name) = $KVP.Value
                    }
                    break
                }
                'Handler' {
                    # TODO: Wrap the scriptblock to catch errors and report them properly.
                    Write-Debug "Adding handler for event '$($Result.event)' to object '$($InputObject.Name)'"
                    $InputObject."Add_$($Result.Event)"($Result.ScriptBlock)
                    break
                }
                'Control' {
                    Write-Debug "Adding child object '$($Result.Name)' to '$($InputObject.Name)'"
                    $InputObject.AddChild($Result)

                    # Hacky but what's a guy to do?
                    $IsMenuBar =
                        $InputObject -is [System.Windows.Controls.DockPanel] -and
                        $Result -is [System.Windows.Controls.Menu]

                    if ($IsMenuBar) {
                        [System.Windows.Controls.DockPanel]::SetDock($Result, [System.Windows.Controls.Dock]::Top)
                    }

                    break
                }
                # My thinking here is that while a user can assign a Path to a button's content
                # property other objects are probably assigned differently so it's just be easier
                # to add them based on the object type so you don't need to remember.
                'Shape' {
                    if ($InputObject -is [System.Windows.Controls.Button]) {
                        $InputObject.Content = $Result
                    }
                }
                default {
                    Write-Error "Unsupported object '$ChildName' of type '$($Result.GetType().Name)' returned for '$Name'"
                }
            }

            if ($PassThru) {
                Write-Output $Result
            }
        }
    } catch {
        Write-Error "Failed to update '$Name' with error: $_"
        return
    }
}
