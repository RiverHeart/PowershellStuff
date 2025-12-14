$ErrorActionPreference = 'Stop'

# MARK: SYS PRIORITY
enum EventPriority {
    LOW
    MEDIUM
    HIGH
    CRITICAL
}


# MARK: SYS EVENT
class SystemEvent {

    [guid] $Id = [guid]::NewGuid()
    [object] $Source
    [object] $Context
    [hashtable] $EventData
    [object] $Status
    [int] $Priority = [EventPriority]::LOW
    [object] $Topic
    [object] $Subscription

    SystemEvent(
        [object] $Topic,
        [object] $Subscription,
        [hashtable] $Data,
        [object] $Source
    ) {
        $this.Source = $Source
        $this.Topic = $Topic
        $this.Subscription = $Subscription
        $this.EventData = $Data
    }
}


# MARK: EVENT BUS
class EventBus: System.IDisposable {
    [guid] $Id = [guid]::NewGuid()
    [string] $Name

    # Two level hashtable hierachy of topics
    # and subscriptions below those.
    [hashtable] $Topics = @{}
    [EventPriority] $Priority = [EventPriority]::LOW
    $EventQueue = [System.Collections.Generic.Queue[SystemEvent]]::new()

    EventBus(
        [string] $Name,
        [EventPriority] $Priority
    ) {
        $this.Name = $Name
        $this.Priority = $Priority
    }

    Dispose() {
        $this.EventQueue.Dipose()
    }

    [string] ToString() {
        return "$($this.Name) ($($this.Id))"
    }

    # STATIC PROPS/METHODS
    #=======================

    # Contains all EventBuses
    static [hashtable] $Pool = @{}

    static [void] AddTopic(
        [EventBus[]] $EventBus,
        $Topic
    ) {
        foreach($Bus in $EventBus) {
            if ($Bus.Topics.ContainsKey($Topic)) {
                Write-Verbose "Topic '$Topic' already exists on bus '$Bus'"
            } else {
                Write-Verbose "Adding topic '$Topic' to bus '$Bus'"
                $Bus.Topics.Add($Topic, @{})
            }
        }
    }

    static [void] RemoveTopic(
        [EventBus[]] $EventBus,
        $Topic
    ) {
        foreach ($Bus in $EventBus) {
            if ($Bus.Topics.ContainsKey($Topic)) {
                Write-Verbose "Removing topic '$Topic' from bus '$Bus'"
                $Bus.Topics.Remove($Topic)
            } else {
                Write-Verbose "Topic '$Topic' already removed from bus '$Bus'"
            }
        }
    }

    static [void] AddSubscription(
        [EventBus[]] $EventBus,
        $Topic,
        $Subscription,
        [scriptblock] $Handler
    ) {
        foreach($Bus in $EventBus) {
            [EventBus]::AddTopic($Bus, $Topic)

            if ($Bus.Topics[$Topic].ContainsKey($Subscription)) {
                Write-Verbose "Subscription '$Topic/$Subscription' already exists on event bus '$Bus'"
            } else {
                Write-Verbose "Adding subscription '$Topic/$Subscription' to event bus '$Bus'"
                $Bus.Topics[$Topic].Add(
                    $Subscription,
                    [System.Collections.Generic.List[scriptblock]]::new()
                )

                $Bus.Topics[$Topic][$Subscription].Add($Handler)
            }
        }
    }

    static [void] RemoveSubscription(
        [EventBus[]] $EventBus,
        $Topic,
        $Subscription
    ) {
        foreach($Bus in $EventBus) {
            if ([EventBus]::HasTopic($Bus, $Topic)) {
                Write-Verbose "Removing Subscription '$Topic/$Subscription' from bus '$Bus'"
                $Bus.Topics[$Topic].Remove($Subscription)
            } else {
                Write-Verbose "Subscription '$Topic/$Subscription' already removed from bus '$Bus'"
            }
        }
    }

    static [bool] HasTopic(
        [EventBus] $EventBus,
        $Topic
    ) {
        if ($null -eq $Topic) {
            return $false
        }
        return $EventBus.Topics.ContainsKey($Topic)
    }

    static [bool] HasSubscription(
        [EventBus] $EventBus,
        $Topic,
        $Subscription
    ) {
        if ($null -eq $Topic -or
            $null -eq $EventBus.Topics.ContainsKey($Topic) -or
            $null -eq $Subscription
        ) {
            return $false
        }
        return $EventBus.Topics[$Topic].ContainsKey($Subscription)
    }

    # Create EventBus and add it to the pool
    static [EventBus] CreateBus(
        [string] $Name,
        [EventPriority] $Priority
    ) {
        $EventBus = [EventBus]::new($Name, $Priority)
        [EventBus]::AddBus($EventBus)
        return $EventBus
    }

    # Add EventBus to the pool.
    static [void] AddBus([EventBus[]] $EventBus) {
        foreach($Bus in $EventBus) {
            [EventBus]::Pool.Add($Bus.Id, $Bus)
        }
    }

    # Remove EventBus from the pool.
    static [void] RemoveBus([EventBus] $EventBus) {
        foreach($Bus in $EventBus) {
            [EventBus]::Pool.Remove($Bus.Id)
        }
    }

    static [EventBus[]] GetBusByTopic(
        $Topic
    ) {
        if ($null -eq $Topic) {
            return @()
        }

        return [EventBus]::Pool.Values | Where-Object { [EventBus]::HasTopic($_, $Topic) }
    }

    static [EventBus[]] GetBusBySubscription(
        $Topic,
        $Subscription
    ) {
        return [EventBus]::Pool.Values | Where-Object { [EventBus]::HasSubscription($_, $Topic, $Subscription) }
    }

    # For complex events that have extra data
    static [void] EmitEvent(
        [SystemEvent] $SystemEvent
    ) {
        # Queue event for appropriate subscribers
        foreach ($EventBus in [EventBus]::GetBusBySubscription($SystemEvent.Topic, $SystemEvent.Subscription)) {
            Write-Debug "Queuing event for '$($SystemEvent.Topic)/$($SystemEvent.Subscription)'"
            $EventBus.EventQueue.Enqueue($SystemEvent)
        }
    }

    # For simple events that need no extra data
    static [void] EmitEvent(
        [object] $Topic,
        [string] $Subscription,
        [hashtable] $EventData,
        [object] $Source
    ) {
        [EventBus]::EmitEvent(
            [SystemEvent]::new($Topic, $Subscription, $EventData, $Source)
        )
    }

    static [EventBus[]] GetBus() {
        return [EventBus]::Pool.Values
    }

    static [void] ClearPool() {
        [EventBus]::Pool.Clear()
    }

    # Process all events for all buses in pool
    static [void] ProcessEvent() {
        [EventBus]::ProcessEvent([EventBus]::GetBus())
    }

    # Process all queued events for each given bus
    # static [void] ProcessNextEvent([EventBus[]] $EventBus) {
    #     [EventBus]::ProcessEvent(
    #         ($EventBus | Where-Object { $_.EventQueue.Count -gt 0}),
    #         $EventBus.EventQueue.Dequeue()
    #     )
    # }

    # This returns [void] but maybe it should return $false.
    # It would make sense for there to be a ProcessEvent() that just
    # dequeues events from the bus itself and returns a bool if the
    # there are more to process
    static [void] ProcessEvent(
        [EventBus[]] $EventBus
    ) {
        foreach($Bus in $EventBus | Sort-Object -Property Priority -Descending) {
            if ($Bus.EventQueue.Count -le 0) {
                Write-Host "No events to process."
                return
            }

            Write-Host "Processing events"
            while ($Bus.EventQueue.Count -gt 0) {
                $SystemEvent = $Bus.EventQueue.Dequeue()

                # Validate that the topic and/or subscription have no been unsubscribed since
                # this event was posted.
                if (-not [EventBus]::HasSubscription($Bus, $SystemEvent.Topic, $SystemEvent.Subscription)) {
                    Write-Verbose "Bus '$Bus' no longer subcribed to '$($SystemEvent.Topic)/$($SystemEvent.Subscription). Discarding event..."
                    continue
                }

                # Call each handler for topic/subscription
                foreach($Handler in $Bus.Topics[$SystemEvent.Topic][$SystemEvent.Subscription]) {
                    try {
                        $Handler.Invoke(
                            $SystemEvent.Source,
                            $SystemEvent.EventData,
                            $SystemEvent.Context
                        )
                    } catch {
                        Write-Host "Handler failed with error: $_"
                    }
                }
            }
        }
    }

    # Returns a specific topic
    static [hashtable] GetTopic(
        $EventBus,
        $Topic
    ) {
        return $EventBus.Topics[$Topic]
    }

    # Returns all topics
    static [hashtable] GetTopic(
        $EventBus
    ) {
        return $EventBus.Topics
    }

    # Returns a specific subscription
    static [array] GetSubscription(
        $EventBus,
        $Topic,
        $Subscription
    ) {
        return $EventBus.Topics[$Topic][$Subscription]
    }

    # Return all subscriptions
    static [hashtable] GetSubscription(
        $EventBus,
        $Topic
    ) {
        return $EventBus.Topics[$Topic]
    }
}


# MARK: SCRATCHPAD
function Scratchpad {

    $VerbosePreference = 'Continue'

    # Create object whose methods emit events
    # of different priorities when called.
    class Test {
        [void] DoFoo() {
            [EventBus]::EmitEvent('category', 'foo', @{}, $this)
        }

        [void] Important() {
            $SysEvent = [SystemEvent]::new('category', 'bar', @{}, $this)
            $SysEvent.Priority = [EventPriority]::HIGH
            [EventBus]::EmitEvent($SysEvent)
        }
    }

    [EventBus]::ClearPool()
    $EventBusOne = [EventBus]::CreateBus('test_bus1', [EventPriority]::HIGH)
    $EventBusTwo = [EventBus]::CreateBus('test_bus2', [EventPriority]::LOW)

    [EventBus]::AddSubscription(
        $EventBusOne,
        'category',
        'foo',
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

    [EventBus]::AddSubscription(
        $EventBusTwo,
        'category',
        'bar',
        {
            Write-Host "Barfu"
        }
    )

    $Test = [Test]::new()
    $Test.DoFoo()
    $Test.Important()
    [EventBus]::ProcessEvent()

    [EventBus]::RemoveSubscription(
        $EventBusOne,
        'category',
        'foo'
    )
}


# Boilerplate to detect if this script is being
# sourced or run.
$TopLevelScript = Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1
$IsTopLevelScript = $TopLevelScript.Command -eq $MyInvocation.MyCommand.Name
$IsMain = $IsTopLevelScript -and $MyInvocation.InvocationName -ne '.'
$IsMainInVSCode = (
    $IsTopLevelScript -and
    $Host.Name -eq 'Visual Studio Code Host' -and
    $MyInvocation.CommandOrigin -eq 'Internal'
)
if ($IsMain -or $IsMainInVSCode) {
    Scratchpad
}