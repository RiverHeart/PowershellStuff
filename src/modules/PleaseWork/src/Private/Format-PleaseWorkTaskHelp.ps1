<#
.SYNOPSIS
    Formats task names and descriptions for native help output.
#>
function Format-PleaseWorkTaskHelp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [psobject[]] $TaskInfo
    )

    begin {
        $Tasks = [System.Collections.Generic.List[psobject]]::new()
    }

    process {
        foreach ($Task in $TaskInfo) {
            $Tasks.Add($Task)
        }
    }

    end {
        $NameWidth = ($Tasks.Name | Measure-Object -Property Length -Maximum).Maximum
        'Available tasks:'
        foreach ($Task in $Tasks) {
            $HelpLine = '  {0}' -f $Task.Name.PadRight($NameWidth)
            if (-not [string]::IsNullOrWhiteSpace($Task.Description)) {
                $HelpLine += '  {0}' -f ($Task.Description -replace '\s+', ' ')
            }
            $HelpLine.TrimEnd()
        }
    }
}
