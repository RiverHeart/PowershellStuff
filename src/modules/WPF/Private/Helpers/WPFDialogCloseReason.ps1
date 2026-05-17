function Get-WPFDialogCloseReasonStore {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $Script:WPFDialogCloseReasonByContextId) {
        $Script:WPFDialogCloseReasonByContextId = @{}
    }

    return $Script:WPFDialogCloseReasonByContextId
}

function Set-WPFDialogCloseReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ContextId,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'AutoClose')]
        [string] $Reason
    )

    $Store = Get-WPFDialogCloseReasonStore
    $Store[$ContextId] = $Reason
}

function Get-WPFDialogCloseReason {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $Store = Get-WPFDialogCloseReasonStore
    if ($Store.ContainsKey($ContextId)) {
        return [string] $Store[$ContextId]
    }

    return 'User'
}

function Remove-WPFDialogCloseReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ContextId
    )

    $Store = Get-WPFDialogCloseReasonStore
    $null = $Store.Remove($ContextId)
}