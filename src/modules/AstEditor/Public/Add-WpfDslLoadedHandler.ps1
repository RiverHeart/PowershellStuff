<#
.SYNOPSIS
    Inserts a missing When 'Loaded' handler into a WPF DSL Window block.

.DESCRIPTION
    A focused AST-driven transform for the WPF DSL. The function locates
    the first Window command with a scriptblock argument, checks whether that block
    already includes a When 'Loaded' command, then applies the configured existing-handler
    policy: skip, insert a sibling handler after the existing node, or append to the
    existing handler body. If no Loaded handler exists, a new one is inserted in the
    Window block. By default, identical handler bodies are treated as already present
    and are not reinserted or re-appended.
    No source text is written directly; callers can validate and save through the
    overlay pipeline.

.EXAMPLE
    $doc = New-AstDocument -Path '.\ImageViewer.DSL.ps1'
    $changed = Add-WpfDslLoadedHandler -Document $doc
    if ($changed) {
        Save-AstDocument -Document $doc -OutPath '.\ImageViewer.DSL.mutated.ps1'
    }

    Adds a Loaded handler only when it does not already exist, then saves the result.

.EXAMPLE
    Add-WpfDslLoadedHandler -Document $doc -HandlerBody "Write-Verbose 'Window loaded'" -OnExistingHandler InsertAfterExisting

    Inserts a second Loaded handler directly beneath the existing Loaded handler.

.EXAMPLE
    Add-WpfDslLoadedHandler -Document $doc -HandlerBody "Write-Verbose 'Window loaded'" -OnExistingHandler AppendToExistingBody

    Appends new statements inside the existing Loaded handler block.
#>
function Add-WpfDslLoadedHandler {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-AstDocumentInstance -InputObject $_ })]
        [object] $Document,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $HandlerBody = "Write-Verbose 'Loaded handler inserted by AST overlay prototype.'",

        [Parameter()]
        [ValidateSet('Skip', 'InsertAfterExisting', 'AppendToExistingBody')]
        [string] $OnExistingHandler = 'Skip',

        [switch] $AllowDuplicateHandlerBody,

        [switch] $Force
    )

    $Plan = New-WpfDslLoadedHandlerRewritePlan -Document $Document -HandlerBody $HandlerBody -OnExistingHandler $OnExistingHandler -AllowDuplicateHandlerBody:$AllowDuplicateHandlerBody -Force:$Force
    if ($Plan.Action -eq 'None') {
        return $false
    }

    return Invoke-WpfDslLoadedHandlerRewritePlan -Document $Document -Plan $Plan
}
