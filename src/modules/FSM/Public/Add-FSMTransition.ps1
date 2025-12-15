function Add-FSMTransition {
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
        [string] $OnEvent,

        [Parameter(Mandatory,ParameterSetName='ByProperty')]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [string] $To,

        [Parameter(ParameterSetName='ByHashtable')]
        [hashtable] $Transitions
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByHashtable') {
            # Parameter validation attributes are still in effect
            $From = $Transition.From
            $OnEvent = $Transition.EventType
            $To = $Transitions.To
        }

        if ($PSCmdlet.ShouldProcess($StateMachine, "Adding transition '$From' -> '$To' on '$OnEvent'")) {
            [StateManagement]::AddTransition($StateMachine, $From, $OnEvent, $To)
        }
    }
}
