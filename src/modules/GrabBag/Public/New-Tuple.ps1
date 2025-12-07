<#
.SYNOPSIS
    Helper function to create tuples since Powershell lacks a nice syntax.

.EXAMPLE
    Basic usage

    $Foo = tuple 1, 2, 3
    $Foo.Items
    $One, $Two, $Three = $Foo.Items

.EXAMPLE
    Pipeline usage

    $Foo = (1, 2, 3) | tuple
    $Foo.Items
    $One, $Two, $Three = $Foo.Items
#>
function New-Tuple {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification='Does not alter system state.')]
    [Alias('tuple')]
    [Alias('~')]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [Object[]] $InputObject
    )

    begin {
        $Accumulator = [System.Collections.Generic.List[Object]]::new()
    }

    process {
        if ($MyInvocation.ExpectingInput) {
            $Accumulator.Add($InputObject)
        } else {
            $Accumulator = $InputObject
        }
    }

    end {
        $Tuple = [System.Tuple]::Create.Invoke($Accumulator)
        $Items = { $this.psobject.properties | Where-Object { $_.Name -match 'Item\d+' } | Select-Object -ExpandProperty Value }

        # Used to provide destructuring assignment since Powershell doesn't support
        # the necessary extension methods available in C#. Also, `Deconstruct()` isn't
        # supported in PSv5 anyway.
        Update-TypeData `
            -TypeName $Tuple.GetType().FullName `
            -MemberName 'Items' `
            -MemberType ScriptProperty `
            -Value $Items `
            -Force

        return $Tuple
    }
}