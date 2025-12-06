<#
.SYNOPSIS
    Flattens an object with nested properties into one or more
    hashtables.

.EXAMPLE
    Pipe object with nested properties to Format-Flat to flatten
    those properties into a single colon delimited string to
    use as the key and return a single hashtable instead of
    multiple ones.

    $Object = @{
        Name = "Example"
        Details = @{
            Age = 30
            Address = @{
            Street = "123 Main St"
            City = "Anytown"
            }
            Hobbies = @("Reading", "Hiking")
        }
        Scores = @(
            @{ Subject = "Math"; Score = 95 }
            @{ Subject = "Science"; Score = 88 }
        )
    }

    $Flattened = $Object | Format-Flat -Delimiter ':' -SingleObject
    $Flattened
#>
function Format-Flat {
  [CmdletBinding()]
  [Alias('fflat', 'Flatten-Object')]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [AllowNull()]
    [Object] $InputObject,

    [string] $Delimiter = '.',

    [switch] $SingleObject,

    [UInt32] $Depth = 100,

    [System.Collections.Generic.LinkedList[string]] $KeyStack
  )

  begin {
    if (-not $KeyStack) {
      $KeyStack = [System.Collections.Generic.LinkedList[string]]::new()
    }
    Write-Debug "KeyStack: $KeyStack"

    $SharedParams = @{
      Delimiter   = $Delimiter
      Depth       = $Depth
      KeyStack    = $KeyStack
    }
  }

  process {
    if ($null -eq $InputObject) {
      return $null
    }

    if ($Depth -le 0) {
      throw "Maximum depth reached. Possible circular reference in object."
    }

    $Depth--

    # Return single object by forwarding parameters, omitting SingleObject
    # then assign all the resulting key-value pairs to a single hashtable
    if ($SingleObject) {
        $Result = @{}
        Format-Flat -InputObject $InputObject @SharedParams |
            ForEach-Object {
                foreach ($Key in $_.Keys) {
                    $Result[$Key] = $_[$Key]
                }
            }
        return $Result
    }

    # Powershell type system gets a little screwy here. The [object] cast
    # causes `$Hashtable -is [PSCustomObject]` to return $true. So check
    # if it's a hashtable first.
    if ($InputObject -is [Hashtable] ) {
      foreach ($Key in $InputObject.Keys) {
        $KeyStack.AddLast($Key) | Out-Null
        Write-Output (Format-Flat $InputObject[$Key] @SharedParams)
        $KeyStack.RemoveLast() | Out-Null
      }
    }
    elseif ($InputObject -is [PSCustomObject] ) {
        $CustomProperties = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
        foreach ($Property in $CustomProperties) {
          # Handle empty arrays explicitly to avoid converting them to $null
          # Handle single-item arrays to ensure they remain arrays
          if ($Property.Value -is [array] -and $Property.Value.Count -in @(0, 1)) {
              $KeyStack.AddLast($Property.Name) | Out-Null
              Write-Output (Format-Flat $Property.Value @SharedParams)
              $KeyStack.RemoveLast() | Out-Null
              continue
          }
          $KeyStack.AddLast($Property.Name) | Out-Null
          Write-Output (Format-Flat $Property.Value @SharedParams)
          $KeyStack.RemoveLast() | Out-Null
        }
    }
    elseif ($InputObject -is [array] ) {
      $Array = @()
      for ($i=0; $i -lt $InputObject.Count; $i++) {
        $KeyStack.AddLast($i) | Out-Null
        $Array += Format-Flat $InputObject[$i] @SharedParams
        $KeyStack.RemoveLast() | Out-Null
      }
      Write-Output $Array
    }

    else {
      # If there's nothing left to flatten, construct the flattened key
      $FlatKey = $KeyStack -join $Delimiter
      Write-Debug "FlatKey: $FlatKey"
      $KeyValPair = @{ $FlatKey = $InputObject }
      Write-Output $KeyValPair
    }
  }
}