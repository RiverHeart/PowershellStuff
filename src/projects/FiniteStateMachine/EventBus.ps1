$ErrorActionPreference = 'Stop'

# MARK: SYS PRIORITY
enum SystemPriority {
    LOW
    MEDIUM
    HIGH
    CRITICAL
}


# MARK: SYS EVENT
class SystemEvent {
    [object] $Source
    [object] $Context
    [hashtable] $EventData
    [object] $Status
    [int] $Id
    [int] $Priority = [SystemPriority]::LOW

    SystemEvent(
        [object] $EventGroup,
        [object] $EventType,
        [hashtable] $EventData,
        [object] $Source
    ) {
        $this.Source = $Source
        $this.EventData = @{
            Group = $EventGroup
            Type = $EventType
            Args = $EventData
        }
        $this.Id = [System.Tuple]::Create($EventGroup, $EventType).GetHashCode()
    }
}


# MARK: EVENT BUS
class EventBus: System.IDisposable {
    [int] $Id
    [string] $Name
    [hashtable] $Listeners = @{}
    [hashtable] $Subscriptions = @{
        Groups = @()
        Events = @()
    }
    [SystemPriority] $Priority = [SystemPriority]::LOW
    $EventQueue = [System.Collections.Generic.Queue[SystemEvent]]::new()

    EventBus(
        [string] $Name,
        [SystemPriority] $Priority
    ) {
        $this.Name = $Name
        $this.Priority = $Priority
        $this.Id = [System.Tuple]::Create($Name, $Priority).GetHashCode()
    }

    Dispose() {
        $this.EventQueue.Dipose()
    }

    # STATIC PROPS/METHODS
    #=======================

    static [hashtable] $EventBuses = @{}

    # Create and add EventBus
    static [EventBus] CreateBus(
        [string] $Name,
        [SystemPriority] $Priority
    ) {
        $EventBus = [EventBus]::new($Name, $Priority)
        [EventBus]::AddBus($EventBus)
        return $EventBus
    }

    # Create and add EventBus with listeners
    static [EventBus] CreateBus(
        [string] $Name,
        [SystemPriority] $Priority,
        [hashtable] $Listeners
    ) {
        $EventBus = [EventBus]::new($Name, $Priority)
        $EventBus.Listeners = $Listeners
        [EventBus]::AddBus($EventBus)
        return $EventBus
    }

    # Add existing EventBus
    static [void] AddBus([EventBus] $EventBus) {
        [EventBus]::EventBuses.Add($EventBus.Id, $EventBus)
    }

    static [void] RemoveBus([EventBus] $EventBus) {
        [EventBus]::EventBuses.Remove($EventBus.Id)
    }

    static [EventBus[]] GetBusBySubscription(
        [string] $EventGroup,
        [string] $EventType
    ) {
        $GroupIsNull = [string]::IsNullOrEmpty($EventGroup)
        $TypeIsNull = [string]::IsNullOrEmpty($EventType)
        if ($GroupIsNull -and $TypeIsNull) {
            return [EventBus[]]::Empty()
        }

        $UsePartialMatch = $GroupIsNull -or $TypeIsNull

        return [EventBus]::EventBuses.Values | Where-Object {
            $ContainsGroup = $_.Subscriptions.Groups -contains $EventGroup
            $ContainsEvent = $_.Subscriptions.Events -contains $EventType
            if ($UsePartialMatch) {
                $ContainsGroup -or $ContainsEvent
            } else {
                $ContainsGroup -and $ContainsEvent
            }
        }
    }

    # For complex events that have extra data
    static [void] EmitEvent(
        [SystemEvent] $SystemEvent
    ) {
        # Queue event for appropriate subscribers
        foreach ($EventBus in [EventBus]::GetBusBySubscription($SystemEvent.EventData.Group, $SystemEvent.EventData.Type)) {
            $EventBus.EventQueue.Enqueue($SystemEvent)
        }
    }

    # For simple events that need no extra data
    static [void] EmitEvent(
        [object] $EventGroup,
        [string] $EventType,
        [hashtable] $EventData,
        [object] $Source
    ) {
        [EventBus]::EmitEvent(
            [SystemEvent]::new($EventGroup, $EventType, $EventData, $Source)
        )
    }

    static [EventBus[]] GetBus() {
        return [EventBus]::EventBuses.Values
    }

    static [void] ClearBus() {
        [EventBus]::EventBuses.Clear()
    }

    static [void] ProcessEvents() {
        foreach($EventBus in [EventBus]::GetBus() | Sort-Object -Property Priority -Descending) {
            if ($EventBus.EventQueue.Count -le 0) {
                Write-Host "No events to process."
                return
            }

            Write-Host "Processing events"
            while ($EventBus.EventQueue.Count -gt 0) {
                [EventBus]::ProcessEvent($EventBus)
            }
        }
    }

    # Implicitly process the next event in the queue
    static [void] ProcessEvent([EventBus] $EventBus) {
        if ($EventBus.EventQueue.Count -le 0) {
            return
        }
        [EventBus]::ProcessEvent($EventBus, $EventBus.EventQueue.Dequeue())
    }

    # This returns [void] but maybe it should return $false.
    # It would make sense for there to be a ProcessEvent() that just
    # dequeues events from the bus itself and returns a bool if the
    # there are more to process
    static [void] ProcessEvent(
        [EventBus] $EventBus,
        [SystemEvent] $SystemEvent
    ) {
        foreach($Listener in $EventBus.Listeners[$SystemEvent.Id]) {
            try {
                $Listener.Invoke(
                    $SystemEvent.Source,
                    $SystemEvent.EventData,
                    $SystemEvent.Context
                )
            } catch {
                Write-Host "Handler failed with error: $_"
            }
        }
    }

    # Automatically resolve EventBus to add listener to
    static [void] AddListener(
        [object] $EventGroup,
        [string] $EventType,
        [object] $Source,
        [scriptblock] $Callback
    ) {
        [EventBus]::AddListener(
            [EventBus]::GetBusBySubscription($EventGroup, $EventType),
            $EventGroup,
            $EventType,
            $Source,
            $Callback
        )
    }

    static [void] AddListener(
        [EventBus[]] $EventBuses,
        [object] $EventGroup,
        [string] $EventType,
        [object] $Source,
        [scriptblock] $Callback
    ) {
        $Key = [System.Tuple]::Create($EventGroup, $EventType).GetHashCode()

        foreach($Bus in $EventBuses) {
            # Initialize handler group container
            if (-not $Bus.Listeners.ContainsKey($Key)) {
                $Bus.Listeners.Add(
                    $Key,
                    [System.Collections.Generic.List[scriptblock]]::new()
                )
            }

            $Bus.Listeners[$Key].Add($Callback)
        }
    }

    static [void] RemoveListener(
        [EventBus] $EventBus,
        [object] $EventGroup,
        [string] $EventType,
        [object] $Source
    ) {
        $Key = [System.Tuple]::Create($EventGroup, $EventType).GetHashCode()
        if (-not $EventBus.Listeners.ContainsKey($Key)) {
            Write-Host "Handler '$Key' not found."
            return
        }

        $ListenersToRemove = $EventBus.Listeners[$Key] |
            ForEach-Object {
                if ($_.Source -eq $Source) {
                    $_
                }
            }

        foreach($Listener in $ListenersToRemove) {
            Write-Host "Removing handler '$Key'."
            $EventBus.Listeners.Remove($Key)
        }
    }
}


# MARK: SCRATCHPAD
function Scratchpad {
    class Test {
        [void] DoFoo() {
            [EventBus]::EmitEvent('category', 'foo', @{}, $this)
        }

        [void] Important() {
            $SysEvent = [SystemEvent]::new('category', 'bar', @{}, $this)
            $SysEvent.Priority = [SystemPriority]::HIGH
            [EventBus]::EmitEvent($SysEvent)
        }
    }

    $Subscriptions = @{
        Groups = 'category'
        Events = @('foo', 'bar')
    }

    [EventBus]::ClearBus()
    $EventBusOne = [EventBus]::CreateBus('test_bus1', [SystemPriority]::HIGH)
    $EventBusTwo = [EventBus]::CreateBus('test_bus2', [SystemPriority]::LOW)
    $EventBusOne.Subscriptions = $Subscriptions
    $EventBusTwo.Subscriptions = $Subscriptions

    [EventBus]::AddListener(
        #$EventBusOne,
        'category',
        'foo',
        $this,
        {
            param(
                $Source,
                $EventData,
                $Context
            )

            Write-Host "Source: $Source"
            Write-Host "EventData: $EventData"
            Write-Host "Context: $Context"
        }
    )

    [EventBus]::AddListener(
        #$EventBusTwo,
        'category',
        'bar',
        $this,
        {
            Write-Host "Barfu"
        }
    )

    $Test = [Test]::new()
    $Test.DoFoo()
    $Test.Important()
    [EventBus]::ProcessEvents()
}

# Ignore scratchpad if sourcing
if ($MyInvocation.InvocationName -ne '.') {
    Scratchpad
}
