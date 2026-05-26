<#
.SYNOPSIS
   Version of the UriBuilder class with improved support for Query Params.

.DESCRIPTION
   Version of the UriBuilder class with improved support for Query Params.

   Provides the following benefits over the base class:
       * Automatically escapes query parameters.
       * Implicitly converts array values into multiple key=value pairs when adding
         multiple parameters (`AddParameters`), or into a CSV string when adding
         a single parameter (`AddParameter`).
       * Enables addition of paths/parameters only when a given predicate evaluates to true.

.NOTES
   Like the base class, removing the port from ToString() output requires setting the
   port to -1. I don't care for the default behaviour but we'll stick with it for compatibility.

.EXAMPLE
   A simple key/value pair.

   $Builder = [UriBuilderPro]::new('https://localhost')
   $Builder.AddParameter('one', 'two')
   $Builder.Parameters  # Display Parameters
   $Builder.Query       # Display Query

.EXAMPLE
   Append path segments with optional predicate logic.

   $Builder = [UriBuilderPro]::new('https://localhost')
   $Builder.AppendPath('base')
   $Builder.AppendPathIf($false, 'optional')  # Ignored
   $Builder.AppendPathIf({ 1 -eq 1 }, 'conditional')  # Appended
   $Builder.Path  # Display Path

.EXAMPLE
   Add parameters with optional predicate logic.

   $Builder = [UriBuilderPro]::new('https://localhost')
   $exists = 'exists'
   $Builder.AddParameter($exists, 'exists')  # Adds parameter
   $Builder.AddParameterIf($exists, 'exists', $exists)  # Evals true and passes
   $Builder.AddParameterIf($notexists, 'notExists', $notexists)  # Evals false and ignored
   $Builder.AddParameterIf({ $exists -eq 'notexists' }, 'mayExist', $notexists)  # Evals false and ignored
   $Builder.Parameters  # Display Parameters
   $Builder.Query       # Display Query

.EXAMPLE
   Add parameters using array values.

   $Builder = [UriBuilderPro]::new('https://localhost')
   $Builder.AddParameter('bar', @('bar', 'barfu'))  # Implicit conversion of array to CSV when adding single parameter.
   $Builder.AddParameters('foo', @('foo', 'fubar'))  # Implicit conversion of array into multiple key=value pairs when adding multiple parameters.
   $Builder.Parameters  # Display Parameters
   $Builder.Query       # Display Query

.EXAMPLE
   Lazily evaluate parameter value using scriptblock after predicate passes.

   $Builder = [UriBuilderPro]::new('https://localhost')
   $Builder.AddParameterIf($date, 'date', { $date.ToUniversalTime().ToString('o') })
#>
class UriBuilderPro : System.UriBuilder {
    $Parameters = [System.Collections.ArrayList]::new()

    UriBuilderPro() : base() { $this.Init() }

    UriBuilderPro([string] $Uri) : base([string] $Uri) { $this.Init() }

    UriBuilderPro([uri] $uri) : base([uri] $uri) { $this.Init() }

    UriBuilderPro([string] $schemeName, [string] $hostName) :
        base([string] $schemeName, [string] $hostName) {
            $this.Init()
        }

    UriBuilderPro([string] $scheme, [string] $hostname, [int] $portNumber) :
        base([string] $scheme, [string] $hostname, [int] $portNumber) {
            $this.Init()
        }

    UriBuilderPro([string] $scheme, [string] $hostname, [int] $port, [string] $pathValue) :
        base([string] $scheme, [string] $hostname, [int] $port, [string] $pathValue) {
            $this.Init()
        }

    UriBuilderPro([string] $scheme, [string] $hostname, [int] $port, [string] $path, [string] $extraValue) :
        base([string] $scheme, [string] $hostname, [int] $port, [string] $path, [string] $extraValue) {
            $this.Init()
        }

    # MARK: PRIVATE METHODS
    #=======================

    hidden [void] Init() {
        $this | Add-Member -MemberType ScriptProperty -Name PathAndQuery -Value {
            if ($this.Query) {
                return ("{0}?{1}" -f $this.Path, $this.Query.TrimStart('?'))
            } else {
                return $this.Path
            }
        }
    }

    hidden [bool] EvalPredicate([object] $Predicate) {
        if ($null -ne $Predicate -and $Predicate -is [scriptblock]) {
            return $Predicate.InvokeReturnAsIs()
        }
        return [bool] $Predicate
    }

    hidden [object] ResolveParameterValue([object] $Value) {
        if ($Value -is [scriptblock]) {
            return $Value.InvokeReturnAsIs()
        }

        return $Value
    }

    # MARK: PUBLIC METHODS
    #=======================

    [void] AddParameter([string] $Key, [object] $Value) {
        $Value = $this.ResolveParameterValue($Value)

        # Convert arrays to CSV strings when adding a single parameter.
        if ($Value -is [array]) {
            $Value = $Value -join ','
        }

        [void] $this.Parameters.Add([pscustomobject]@{
            Key = $Key
            Value = $Value
        })
        $this.UpdateQuery()
    }

    [void] AddParameterIf([object] $Predicate, [string] $Key, [object] $Value) {
        if ($this.EvalPredicate($Predicate)) {
             $this.AddParameter($Key, $Value)
        }
    }

    [void] AddParameters([string] $Key, [object[]] $Values) {
        $AddEntries = $null
        $AddEntries = {
            param([object] $EntryValue)

            $ResolvedValue = $this.ResolveParameterValue($EntryValue)

            if ($null -ne $ResolvedValue -and $ResolvedValue -is [System.Collections.IEnumerable] -and $ResolvedValue -isnot [string]) {
                foreach ($NestedValue in $ResolvedValue) {
                    & $AddEntries $NestedValue
                }
                return
            }

            [void] $this.Parameters.Add([pscustomobject]@{
                Key = $Key
                Value = $ResolvedValue
            })
        }

        foreach ($Value in $Values) {
            & $AddEntries $Value
        }

        $this.UpdateQuery()
    }

    [void] AddParametersIf([object] $Predicate, [string] $Key, [object[]] $Values) {
        if ($this.EvalPredicate($Predicate)) {
            $this.AddParameters($Key, $Values)
        }
    }

    [void] AppendPath([string] $Path) {
        if ($this.Path.EndsWith('/')) {
            $this.Path += $Path.TrimStart('/')
        } else {
            $this.Path += '/' + $Path.TrimStart('/')
        }
    }

    [void] AppendPathIf([object] $Predicate, [string] $Path) {
        if ($this.EvalPredicate($Predicate)) {
            $this.AppendPath($Path)
        }
    }

    [void] UpdateQuery() {
        $TempQuery = ''
        foreach($Param in $this.Parameters) {
            # Regarding encoding of the parens, some markdown
            # parsers stop evaluating url syntax (ie [text](link) )
            # on the first occurence of a closing parens.
            # We don't want that so just encode them for safety.
            $TempQuery += "{0}={1}&" -f $Param.Key, [uri]::EscapeDataString([string] $Param.Value).Replace('(', '%28').Replace(')', '%29')
        }
        # UriBuilder implicitly adds a leading ? mark when setting Query
        $this.Query = $TempQuery.TrimEnd('&')
    }
}
