<#
.SYNOPSIS
    Scaffolds a new Pester test file.

.EXAMPLE
    Create a new Pester test file.

    New-Test

.EXAMPLE
    Create a new Pester test file with a specific name.

    New-Test -Name 'MyTest'

.EXAMPLE
    Create Pester tests from existing files, ignoring those that already exist.

    Get-ChildItem 'Public' | New-Test -OutDirectory 'Tests' -SkipExisting
#>
function New-Test {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory,ParameterSetName = 'ByName',Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName = 'ByFile',ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $InFile,

        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo] $OutDirectory,

        [Parameter(ParameterSetName = 'ByName')]
        [switch] $Empty,

        [switch] $Force,
        [switch] $SkipExisting
    )

    begin {
        $Builder = [System.Text.StringBuilder]::new()

        if (-not $OutDirectory) { $OutDirectory = (Get-Location).ToString() }
        if (-not $OutDirectory.Exists) { $OutDirectory.Create() | Out-Null }
    }

    process {
        $OutName = if ($Name) { $Name } else { $InFile.Name }
        if ($OutName -notlike "*.Tests.ps1") { $OutName = "$OutName.Tests.ps1" }
        $OutPath = Join-Path -Path $OutDirectory -ChildPath $OutName

        $TestExists = Test-Path -Path $OutPath -PathType Leaf
        if ($TestExists -and $SkipExisting) {
            Write-Verbose "File '$OutPath' already exists. Skipping due to -SkipExisting."
            return
        } elseif ($TestExists -and -not $Force) {
            Write-Warning "File '$OutPath' already exists. Use -Force to overwrite."
            return
        }

        if ($InFile) {
            $Builder.AppendLine('BeforeAll {') | Out-Null
            $Builder.AppendLine("    # Add your setup code here") | Out-Null
            $Builder.AppendLine("}`n") | Out-Null
            $Functions = Find-AstNode -FilePath $InFile -Type FunctionDefinitionAst
            foreach ($Function in $Functions) {
                $Builder.AppendLine("Describe '$($Function.Name)' {") | Out-Null
                $Builder.AppendLine("    It 'Should have tests' {") | Out-Null
                $Builder.AppendLine("        # Add your tests here") | Out-Null
                $Builder.AppendLine("    }") | Out-Null
                $Builder.AppendLine("}") | Out-Null
            }
        } elseif ($Empty) {
            $Builder.Append(@"
BeforeAll {
    # Add your setup code here
}

Describe '$Name' {
    It 'Should have tests' {
        # Add your tests here
    }
}
"@) | Out-Null
        } else {
            $Builder.Append(@'
BeforeAll {
    function Get-Planet ([string]$Name = '*') {
        $planets = @(
            @{ Name = 'Mercury' }
            @{ Name = 'Venus'   }
            @{ Name = 'Earth'   }
            @{ Name = 'Mars'    }
            @{ Name = 'Jupiter' }
            @{ Name = 'Saturn'  }
            @{ Name = 'Uranus'  }
            @{ Name = 'Neptune' }
        ) | ForEach-Object { [PSCustomObject] $_ }

        $planets | Where-Object { $_.Name -like $Name }
    }
}

Describe 'Get-Planet' {
    It 'Given no parameters, it lists all 8 planets' {
        $allPlanets = Get-Planet
        $allPlanets.Count | Should-Be 8
    }
}
'@) | Out-Null
        }

        $Builder.ToString() | Out-File -FilePath $OutPath -Force
    }
}
