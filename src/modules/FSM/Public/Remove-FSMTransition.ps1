function Remove-FSMTransition {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='ByProperty')]
    param(
        [Parameter(Mandatory,ParameterSetName='ByProperty',ValueFromPipeline)]
        [Parameter(Mandatory,ParameterSetName='ByHashtable',ValueFromPipeline)]
        [StateMachine] $StateMachine,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [string] $From,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [string] $EventType,

        [Parameter(Mandatory,ParameterSetName='ByHashtable')]
        [hashtable] $Transitions
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByHashtable') {
            # Parameter validation attributes are still in effect
            $From = $Transitions.From
            $EventType = $Transitions.EventType
        }

        if ($PSCmdlet.ShouldProcess($StateMachine, "Removing transition '$From' for event '$EventType'")) {
            [StateManagement]::RemoveTransition($StateMachine, $From, $EventType)
        }
    }
}
