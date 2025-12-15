class StateTransitionEvent {
    [string] $EventType
    [StateMachine] $StateMachine
    [StateTransitionWindow] $StateTransitionWindow = [StateTransitionWindow]::ON_TRANSITION

    StateTransitionEvent(
        [StateMachine] $StateMachine,
        [string] $EventType
    ) {
        $this.EventType = $EventType
        $this.StateMachine = $StateMachine
    }

    StateTransitionEvent(
        [StateMachine] $StateMachine,
        [string] $EventType,
        [StateTransitionWindow] $StateTransitionWindow
    ) {
        $this.EventType = $EventType
        $this.StateMachine = $StateMachine
        $this.StateTransitionWindow = $StateTransitionWindow
    }
}
