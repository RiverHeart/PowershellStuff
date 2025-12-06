<#
.SYNOPSIS
  Converts a PSObject to a hashtable by doing a deep clone
  and converting PSObjects to Hashtables on the fly.

.NOTES
  This function is based on `Get-DeepClone` by Kevin Marquette
  https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-#about-hashtable?view=powershell-7.3#deep-copies

.EXAMPLE
  $Settings = [PSObject] @{
    foo = "foo"
    one = @{ two = "three" }
    four = [PSObject] @{ five = "six" }
    seven = @( @("eight", "nine") )
  }

  $Clone = Convert-PSObjectToHashtable $Settings
#>
function Convert-PSObjectToHashtable {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [AllowNull()]
    [Object] $InputObject
  )

  process {
    $Clone = @{}

    if ($null -eq $InputObject) {
      return $null
    }

    if ($InputObject -is [PSCustomObject] ) {
        $CustomProperties = $InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }
        foreach ($Property in $CustomProperties) {
          # Handle empty arrays explicitly to avoid converting them to $null
          # Handle single-item arrays to ensure they remain arrays
          if ($Property.Value -is [array] -and $Property.Value.Count -in @(0, 1)) {
              $Clone[$Property.Name] = @(Convert-PSObjectToHashtable $Property.Value)
              continue
          }
          $Clone[$Property.Name] = Convert-PSObjectToHashtable $Property.Value
        }
        return $Clone
    }

    elseif ($InputObject -is [Hashtable] ) {
      foreach ($Key in $InputObject.Keys) {
        $Clone[$Key] = Convert-PSObjectToHashtable $InputObject[$Key]
      }
      return $Clone
    }

    elseif ($InputObject -is [array] ) {
      $Array = @()
      foreach ($Item in $InputObject) {
        $Array += Convert-PSObjectToHashtable $Item
      }
      return $Array
    }

    else {
      return $InputObject
    }
  }
}
