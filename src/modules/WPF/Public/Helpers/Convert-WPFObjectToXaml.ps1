<#
.SYNOPSIS
    Converts a PS Object to a XAML string or Xml object.

.DESCRIPTION
    Converts a PS Object to a XAML string or Xml object.

.EXAMPLE
    Basic usage

    Window "Title" 640 480 {
        StackPanel "Buttons" {
            Button "TestButton" "Hello World"
            Button "TestButton2" "Konichiwa Sekai" {
                Properties {
                    Width = 100
                    Height = 30
                }
                Handler "Click" {
                    Write-Host "Foo"
                }
            }
        }
    } | Convert-WPFObjectToXaml
#>
function Convert-WPFObjectToXaml {
    [CmdletBinding()]
    [OutputType([string], [xml])]
    param(
        # NOTE: Not sure if there's a better object type to accept here.
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]] $InputObject,

        [ValidateSet('string', 'xml')]
        [string] $OutputAs = 'string'
    )

    process {
        foreach($Item in $InputObject) {
            if ($OutputAs -eq 'xml') {
                [xml] [System.Windows.Markup.XamlWriter]::Save($Item)
            } else {
                # TODO: Investigate XamlXmlWriter. See if pretty printing xml
                # is possible.
                [System.Windows.Markup.XamlWriter]::Save($Item)
            }
        }
    }
}
