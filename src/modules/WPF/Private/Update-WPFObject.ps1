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

    # NOTE: Should probably add Name to Window object so this isn't necessary. Besides,
    # title isn't a good fit here anyway.
    $Name = if ($InputObject.GetType().Name -eq 'Window') { $InputObject.Title } else { $InputObject.Name }

    try {
        foreach ($Result in $ScriptBlock.Invoke()) {
            switch ($Result.WPF_TYPE) {
                'Properties' {
                    foreach($KVP in $Result.GetEnumerator()) {
                        $InputObject.($KVP.Name) = $KVP.Value
                    }
                    break
                }
                'Handler' {
                    $InputObject."Add_$($Result.Event)"($Result.ScriptBlock)
                    break
                }
                'Control' {
                    $InputObject.AddChild($Result)
                    break
                }
                default {
                    Write-Error "Unsupported object returned for '$Name'"
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
