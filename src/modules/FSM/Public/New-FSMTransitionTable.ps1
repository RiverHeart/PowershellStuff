function New-FSMTransitionTable {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [Array[]] $Transitions
    )

    begin {
        $TransitionTable = @{}
        $ErrorsFound = $False
    }

    process {
        foreach($Transition in $Transitions) {
            if ($Transition.Count -lt 3 -or $Transition.Count -gt 3) {
                Write-Error "Transitions can only contain 3 elements."
                $ErrorsFound = $true
                return
            }
            $Key = [System.Tuple]::Create($Transition[0], $Transition[1])
            $TransitionTable.Add($Key, $Transition[2])
        }
    }

    end {
        if ($ErrorsFound) {
            return @{}
        }
        return $TransitionTable
    }
}
