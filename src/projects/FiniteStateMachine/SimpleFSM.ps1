$ErrorActionPreference = 'Stop'

# MARK: SIMPLE FSM
class SimpleFSM {
    [string] $CurrentState
    [hashtable] $TransitionTable

    SimpleFSM(
        [string] $InitialState,
        [hashtable] $TransitionTable
    ) {
        $this.CurrentState = $InitialState
        $this.TransitionTable = $TransitionTable.Clone()
    }

    [void] ProcessEvent([string] $EventType) {
        $Key = [System.Tuple]::Create($this.CurrentState, $EventType)
        if ($this.TransitionTable.ContainsKey($Key)) {
            $this.CurrentState = $this.TransitionTable[$Key]
            Write-Host "Transitioned to state: $($this.CurrentState)"
        } else {
            Write-Host "Invalid transition from '$($this.CurrentState)' with event $EventType'"
        }
    }
}


# MARK: NEW TUPLE
function New-Tuple {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification='Does not alter system state.')]
    [Alias('tuple')]
    [Alias('~')]
    param()

    $Tuple = [System.Tuple]::Create.Invoke($args)

    return $Tuple
}

# MARK: SCRATCHPAD
function Scratchpad {
    # Using a dictionary where keys are (current_state, input_event) tuples
    # and values are the next_state.
    $TransitionTableDict = @{
        (tuple 'idle' 'start') = 'running'
        (tuple 'running' 'stop') = 'idle'
        (tuple 'running' 'pause') = 'paused'
        (tuple 'paused' 'resume') = 'running'
        (tuple 'paused' 'stop') = 'idle'
    }

    # Using a list of dictionaries, where each dictionary represents a transition rule.
    $TransitionTableList = @(
        @{ CurrentState = 'idle';  InputEvent =  'start'; NextState = 'running'},
        @{ CurrentState = 'running';  InputEvent =  'stop'; NextState = 'idle'},
        @{ CurrentState = 'running';  InputEvent =  'pause'; NextState = 'paused'},
        @{ CurrentState = 'paused';  InputEvent =  'resume'; NextState = 'running'},
        @{ CurrentState = 'paused';  InputEvent =  'stop'; NextState = 'idle'}
    )

    # Example usage
    $FSM = [SimpleFSM]::new('idle', $TransitionTableDict)
    $FSM.ProcessEvent('start')  # Output: Transitioned to state: running
    $FSM.ProcessEvent('pause')  # Output: Transitioned to state: paused
    $FSM.ProcessEvent('resume') # Output: Transitioned to state: running
    $FSM.ProcessEvent('stop')   # Output: Transitioned to state: idle
    $FSM.ProcessEvent('invalid') # Output: Invalid transition from idle with event 'invalid'
}

# Ignore scratchpad if sourcing
if ($MyInvocation.InvocationName -ne '.') {
    Scratchpad
}
