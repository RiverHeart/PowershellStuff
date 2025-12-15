function New-FSMTransitionEvent {
    [CmdletBinding()]
    [OutputType([StateTransitionEvent])]
    param (
        [Parameter(Mandatory)]
        [StateMachine] $StateMachine,

        [Parameter(Mandatory)]
        [ValidateScript({ -not [String]::IsNullOrEmpty($_.Trim()) })]
        [string] $EventType
    )

    return [StateTransitionEvent]::new($StateMachine, $EventType)
}
