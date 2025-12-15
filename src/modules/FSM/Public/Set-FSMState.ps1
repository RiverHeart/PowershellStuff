function Set-FSMState {
    [CmdletBinding(DefaultParameterSetName='ByStateMachine')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByStateMachine',ValueFromPipeline)]
        [StateMachine[]] $StateMachine,

        [Parameter(Mandatory,ParameterSetName='ByStateMachine',Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $OnEvent,

        [Parameter(Mandatory,ParameterSetName='ByTransitionEvent')]
        [StateTransitionEvent[]] $TransitionEvent
    )

    process {
        if ($PScmdlet.ParameterSetName -eq 'ByTransitionEvent') {
            [StateManagement]::Transition($TransitionEvent.StateMachine, $TransitionEvent.EventType)
        } else {
            [StateManagement]::Transition($StateMachine, $OnEvent)
        }
    }
}
