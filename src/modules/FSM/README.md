# FSM

## Overview

Experimental module for making Finite State Machines in Powershell.


## Example

```powershell
    $VerbosePreference = 'Continue'

    Import-Module FSM

    # Using a list of dictionaries, where each dictionary represents a transition rule.
    $TransitionsTable = New-FSMTransitionTable @(
        @('idle', 'start', 'running'),
        @('running', 'stop', 'idle'),
        @('running',  'pause', 'paused'),
        @('paused', 'resume', 'running'),
        @('paused', 'stop', 'idle')
    )

    $MobilityFSM = New-FSMStateMachine 'idle' $TransitionsTable
    $StanceFSM = New-FSMStateMachine 'standing'

    $MobilityFSM | Set-FSMState 'start'  # Output: Transitioned to state: running
    $MobilityFSM | Set-FSMState 'pause'  # Output: Transitioned to state: paused
    $MobilityFSM | Set-FSMState 'resume' # Output: Transitioned to state: running
    $MobilityFSM | Set-FSMState 'stop'   # Output: Transitioned to state: idle
    $MobilityFSM | Set-FSMState 'invalid'  # Output: Invalid transition from idle with event invalid

    $StanceFSM | Add-FSMTransition -From 'standing' -OnEvent 'crouch' -To 'crouching'
    $StanceFSM | Add-FSMTransition -From 'crouching' -OnEvent 'crouch' -To 'standing'
```
