<#
.SYNOPSIS
    Updated version of the System.UriBuilder class with improved support for query params.

.DESCRIPTION
    Version of the UriBuilder class with improved support for Query Params.

    Provides the following benefits over the base class:
      * Automatically escapes the value part of the key/value pair.

      * Enables the addition of multiple parameters with the same key.
        Consider that other, pure hashtable solutions, may not account
        for this use case and that hashtables do not allow duplicate keys.

      * Enables conversion of an array of values into a string, joined
        by choice of char/string, for value part of the key/value pair.

      * Enables addition of parameters only when a given constant/scriptblock evaluates to true.

.NOTES
    Like the base class, removing the port from ToString() output requires setting the
    port to -1. I don't care for the default behaviour but we'll stick with it for compatibility.

.EXAMPLE
    Add simple key/value pair.

    $Builder = [UriBuilderPro]::new('https://this.example.com')
    $Builder.AddParameter('one', 'two')
    $Builder.Parameters  # Display Parameters
    $Builder.Query       # Display Query

.EXAMPLE
    Add parameters based on predicate logic, either a constant
    or scriptblock that resolves to True/False.

    $Builder = [UriBuilderPro]::new('https://this.example.com')
    $exists = 'exists'
    $Builder.AddParameter('exists', $exists, $exists)  # Evals true and added
    $Builder.AddParameter('notExists', $notexists, $notexists)  # Evals false and not added
    $Builder.AddParameter('mayExist', $notexists, { $exists -eq 'notexists' })  # Evals false and not added
    $Builder.Parameters  # Display Parameters
    $Builder.Query       # Display Query

.EXAMPLE
    Add parameter with array values

    $Builder = [UriBuilderPro]::new('https://this.example.com')
    $Builder.AddParameter('foo', @('foo', 'fubar'))  # Implicit conversion of array value into multiple key=value pairs.
    $Builder.AddParameter('bar', @('bar', 'barfu'), $True, ',')  # Join array on string value. Pass $True just to satisfy overload.
    $Builder.Parameters  # Display Parameters
    $Builder.Query       # Display Query
#>
class UriBuilderPro : System.UriBuilder {
    [hashtable] $Parameters = @{}

    UriBuilderPro() : base() { }

    UriBuilderPro([string] $Uri) : base([string] $Uri) {}

    UriBuilderPro([uri] $uri) : base($args) {}

    UriBuilderPro([string] $schemeName, [string] $hostName) :
        base([string] $schemeName, [string] $hostName) {}

    UriBuilderPro([string] $scheme, [string] $hostname, [int] $portNumber) :
        base([string] $scheme, [string] $hostname, [int] $portNumber) {}

    UriBuilderPro([string] $scheme, [string] $hostname, [int] $port, [string] $pathValue) :
        base($args) {
            [string] $scheme, [string] $hostname, [int] $port, [string] $pathValue
        }

    UriBuilderPro([string] $scheme, [string] $hostname, [int] $port, [string] $path, [string] $extraValue) :
        base([string] $scheme, [string] $hostname, [int] $port, [string] $path, [string] $extraValue) {}

    AddParameter([string] $Key, [object] $Value) {
        if ($this.Parameters.ContainsKey($Key)) {
            throw [System.IO.InvalidDataException] "Cannot add duplicate key '$Key'"
        }
        $this.Parameters[$Key] = $Value
        $this.UpdateQuery()
    }

    AddParameter([string] $Key, [object] $Value, [string] $Join) {
        $this.AddParameter($Key, ($Value -join $Join))
    }

    AddParameter([string] $Key, [object] $Value, [object] $Predicate) {
        if ($null -ne $Predicate -and
            $Predicate.GetType().Name -eq "Scriptblock" -and
            $Predicate.InvokeReturnAsIs()
        ) {
            $this.AddParameter($Key, $Value)
        }
    }

    AddParameter([string] $Key, [object] $Value, [object] $Predicate, [string] $Join) {
        if ($null -ne $Predicate -and
            $Predicate.GetType().Name -eq "Scriptblock" -and
            $Predicate.InvokeReturnAsIs()
        ) {
            $this.AddParameter($Key, $Value, $Join)
        } elseif ($Predicate) {
            $this.AddParameter($Key, $Value, $Join)
        }
    }

    UpdateQuery() {
        $TempQuery = ''
        foreach($Param in $this.Parameters.GetEnumerator()) {
            # Regarding encoding of the parens, some markdown
            # parsers stop evaluating url syntax (ie [text](link) )
            # on the first occurence of a closing parens.
            # We don't want that so just encode them for safety.
            foreach ($Value in $Param.Value) {
                $TempQuery += "{0}={1}&" -f $Param.Key, [uri]::EscapeDataString($Value).Replace('(', '%28').Replace(')', '%29')
            }
        }
        # UriBuilder implicitly adds a leading ? mark when setting Query
        $this.Query = $TempQuery.TrimEnd('&')
    }
}
