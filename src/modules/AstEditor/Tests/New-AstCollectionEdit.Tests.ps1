using namespace System.Management.Automation.Language

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../AstEditor.psd1" -Force

Describe 'New-AstCollectionEdit' {
    BeforeDiscovery {
        $Cases = @(
            @{
                Position = 'first'
                Source = '[Parameter(Mandatory=$false,Position=0)]'
                Expected = '[Parameter(Position=0)]'
            }
            @{
                Position = 'middle'
                Source = "[Parameter(Position=0,Mandatory=`$false,HelpMessage='Name')]"
                Expected = "[Parameter(Position=0,HelpMessage='Name')]"
            }
            @{
                Position = 'last'
                Source = '[Parameter(Position=0,Mandatory=$false)]'
                Expected = '[Parameter(Position=0)]'
            }
            @{
                Position = 'only'
                Source = '[Parameter(Mandatory=$false)]'
                Expected = '[Parameter()]'
            }
            @{
                Position = 'multiline with trivia'
                Source = "[Parameter(Position=0,`n    Mandatory=`$false,`n    HelpMessage='Name')]"
                Expected = "[Parameter(Position=0,`n    `n    HelpMessage='Name')]"
            }
            @{
                Position = 'with a comma inside a comment'
                Source = '[Parameter(Mandatory=$false <# keep, this #>, Position=0)]'
                Expected = '[Parameter( <# keep, this #> Position=0)]'
            }
        )
    }

    It 'creates a removal edit for the <Position> element' -ForEach $Cases {
        $DocumentSource = "param($Source [string] `$Name)"
        $ExpectedDocument = "param($Expected [string] `$Name)"
        $Document = New-AstDocument -InputObject $DocumentSource
        $Attribute = $Document.Ast.Find({
            param ($Node)

            $Node -is [AttributeAst]
        }, $false)
        $Argument = $Attribute.NamedArguments | Where-Object ArgumentName -eq 'Mandatory'

        $Edit = New-AstCollectionEdit `
            -Remove $Argument `
            -From $Attribute.NamedArguments `
            -Within $Attribute

        $Actual = $DocumentSource.Remove(
            $Edit.StartOffset,
            $Edit.EndOffset - $Edit.StartOffset
        ).Insert($Edit.StartOffset, $Edit.ReplacementText)

        $Edit.PSTypeNames | Should -Contain 'AstEditor.CollectionEdit'
        $Edit.ExpectedText | Should -Be $DocumentSource.Substring(
            $Edit.StartOffset,
            $Edit.EndOffset - $Edit.StartOffset
        )
        $Actual | Should -Be $ExpectedDocument
    }

    It 'uses absolute source coordinates when the collection is nested' {
        $Source = 'function Test-Thing { param([Parameter(Position=0,Mandatory=$false)] $Name) }'
        $Document = New-AstDocument -InputObject $Source
        $Attribute = $Document.Ast.Find({
            param ($Node)

            $Node -is [AttributeAst]
        }, $true)
        $Argument = $Attribute.NamedArguments | Where-Object ArgumentName -eq 'Mandatory'

        $Edit = New-AstCollectionEdit -Remove $Argument -From $Attribute.NamedArguments -Within $Attribute

        $Edit.StartOffset | Should -BeGreaterThan $Attribute.Extent.StartOffset
        $Edit.ExpectedText | Should -Be ',Mandatory=$false'
    }
}
