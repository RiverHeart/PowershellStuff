<#
.SYNOPSIS
    Defines a simplified chrome template for supported styled controls.

.DESCRIPTION
    Chrome is an opt-in style helper that generates a control template shell with
    a named Border part and a ContentPresenter. This hides common template
    boilerplate for controls where rounded chrome styling is frequently needed.

    Inside Chrome blocks, property command shorthand is supported and maps to
    Setter in the current chrome factory context.

    The module ships with a default adapter for Button styles. Additional
    control target types can be enabled via Register-WPFChromeAdapter.


.EXAMPLE
    Style 'PrimaryButton' Button {
        Background: '#0A84FF'
        Foreground: '#FFFFFF'
        Padding: '14,8,14,8'

        Chrome {
            CornerRadius: 6
            BorderBrush: '#086FD5'
            BorderThickness: 2
        }

        Trigger IsEnabled $false -Scope Chrome {
            BorderBrush: '#9FC5EF'
            Background: '#B6D7FF'
        }
    }
#>
function Chrome {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $ScriptBlock
    )

    function Set-ChromeFactoryProperty {
        param(
            [Parameter(Mandatory)]
            [System.Windows.FrameworkElementFactory] $Factory,

            [Parameter(Mandatory)]
            [System.Windows.DependencyProperty] $Property,

            [Parameter()]
            [object] $Value
        )

        if ($Value -is [System.Windows.DynamicResourceExtension]) {
            $Factory.SetResourceReference($Property, $Value.ResourceKey)
            return
        }

        $Factory.SetValue($Property, $Value)
    }

    $style = $PSCmdlet.GetVariableValue('this')
    if (-not ($style -is [System.Windows.Style])) {
        Write-Error 'Chrome: Must be used directly inside a Style block.'
        return
    }

    if (-not $style.TargetType) {
        Write-Error 'Chrome: Current Style has no TargetType.'
        return
    }

    $registeredAdapters = @(Get-WPFChromeAdapter)
    $adapter = @(Get-WPFChromeAdapter -TargetType $style.TargetType) | Select-Object -First 1

    if ($null -eq $adapter) {
        $registeredAdapterNames = ($registeredAdapters | ForEach-Object { $_.Name }) -join ', '
        Write-Error "Chrome: TargetType '$($style.TargetType.FullName)' is not supported. No Chrome adapter is registered for this type. Registered adapters: $registeredAdapterNames."
        return
    }

    if ($style.PSObject.Properties['_WPFHasChrome'].Value) {
        Write-Error 'Chrome: A style can only define one Chrome block.'
        return
    }

    $existingTemplateSetter = $style.Setters |
        Where-Object {
            $_ -is [System.Windows.Setter] -and
            $_.Property -eq [System.Windows.Controls.Control]::TemplateProperty
        } |
        Select-Object -First 1

    if ($null -ne $existingTemplateSetter) {
        Write-Error 'Chrome: Cannot be combined with Template in the same style. Choose one.'
        return
    }

    $template = [System.Windows.Controls.ControlTemplate]::new($style.TargetType)

    $chromeFactory = [System.Windows.FrameworkElementFactory]::new($adapter.ShellType)
    $chromeFactory.Name = $adapter.PartName

    $styleSetterTable = @{}
    $styleChain = [System.Collections.Generic.List[System.Windows.Style]]::new()
    $currentStyle = $style
    while ($null -ne $currentStyle) {
        $styleChain.Insert(0, $currentStyle)
        $currentStyle = $currentStyle.BasedOn
    }

    foreach ($styleInChain in $styleChain) {
        foreach ($candidateSetter in $styleInChain.Setters) {
            if ($candidateSetter -is [System.Windows.Setter] -and $null -ne $candidateSetter.Property) {
                if ($candidateSetter.Property -eq [System.Windows.Controls.Control]::TemplateProperty) {
                    continue
                }

                $styleSetterTable[$candidateSetter.Property.Name] = $candidateSetter.Value
            }
        }
    }

    foreach ($mappedProperty in $adapter.ShellPropertyMap.GetEnumerator()) {
        if ($styleSetterTable.ContainsKey($mappedProperty.Key)) {
            Set-ChromeFactoryProperty -Factory $chromeFactory -Property $mappedProperty.Value -Value $styleSetterTable[$mappedProperty.Key]
        }
    }

    $warnOnUnmapped = $false
    $warnRaw = [System.Environment]::GetEnvironmentVariable('WPF_CHROME_WARN_UNMAPPED_SETTERS')
    if (-not [string]::IsNullOrWhiteSpace($warnRaw)) {
        $normalizedWarnValue = $warnRaw.Trim().ToLowerInvariant()
        if ($normalizedWarnValue -in @('1', 'true', 'yes', 'on')) {
            $warnOnUnmapped = $true
        }
    }

    if ($warnOnUnmapped) {
        $mappedSourceProperties = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($sourceProperty in $adapter.ShellPropertyMap.Keys) {
            $mappedSourceProperties.Add([string] $sourceProperty) | Out-Null
        }

        foreach ($sourceProperty in $adapter.ContentPropertyMap.Keys) {
            $mappedSourceProperties.Add([string] $sourceProperty) | Out-Null
        }

        $unmappedProperties = @(
            $styleSetterTable.Keys |
                Where-Object { -not $mappedSourceProperties.Contains([string] $_) } |
                Sort-Object
        )

        if ($unmappedProperties.Count -gt 0) {
            $unmappedList = $unmappedProperties -join ', '
            Write-Warning "Chrome: The following style setters were not mapped into adapter '$($adapter.Name)' for target type '$($style.TargetType.FullName)': $unmappedList. Set these in Chrome { ... } if they belong to the generated part, or use Template for full template control."
        }
    }


    $chromeVars = New-WPFVariableList -InputObject $chromeFactory

    $chromeDslCommands = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($dslCommandName in @('Setter')) {
        $null = $chromeDslCommands.Add($dslCommandName)
    }

    $chromeFactoryType = $adapter.ShellType

    $isChromeDependencyProperty = {
        param(
            [Parameter(Mandatory)]
            [string] $PropertyName
        )

        $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($PropertyName, $chromeFactoryType, $chromeFactoryType)
        return ($null -ne $descriptor)
    }

    $implicitSetterCommandMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $commandAsts = $ScriptBlock.Ast.FindAll({
            param($Ast)
            $Ast -is [System.Management.Automation.Language.CommandAst]
        }, $true)

    foreach ($commandAst in $commandAsts) {
        $commandName = $commandAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            continue
        }

        $isExplicitProperty = $commandName.EndsWith(':')
        $propertyName = if ($isExplicitProperty) {
            $commandName.Substring(0, $commandName.Length - 1)
        } else {
            $commandName
        }

        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        $treatAsImplicitSetter = $false

        if ($isExplicitProperty) {
            $treatAsImplicitSetter = $true
        } elseif ($chromeDslCommands.Contains($propertyName)) {
            # Reserved DSL keywords remain explicit unless caller opts into
            # property mode with a trailing ':'.
            $treatAsImplicitSetter = $false
        } elseif (& $isChromeDependencyProperty -PropertyName $propertyName) {
            # Prefer dependency properties over command names to reduce collisions.
            $treatAsImplicitSetter = $true
        } elseif ($null -ne (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            $treatAsImplicitSetter = $false
        } else {
            $treatAsImplicitSetter = $true
        }

        if ($treatAsImplicitSetter -and -not $implicitSetterCommandMap.ContainsKey($commandName)) {
            $implicitSetterCommandMap[$commandName] = $propertyName
        }
    }

    $implicitSetterFunctions = [System.Collections.Generic.Dictionary[string, scriptblock]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($chromeCommandName in $implicitSetterCommandMap.Keys) {
        $propertyName = $implicitSetterCommandMap[$chromeCommandName]
        $functionBody = [scriptblock]::Create(@"
param(
    [Parameter(Mandatory, Position = 0)]
    [AllowNull()]
    [object]`$Value,

    [Parameter()]
    [switch]`$Resource,

    [Parameter()]
    [string]`$Target,

    [Parameter()]
    [ValidateSet('Chrome')]
    [string]`$Scope,

    [Parameter(ValueFromRemainingArguments = `$true)]
    [object[]]`$Remaining
)

if (`$null -ne `$Remaining -and `$Remaining.Count -gt 0) {
    throw "Chrome shorthand for property '$propertyName' received unsupported trailing arguments: `$(`$Remaining -join ', ')"
}

`$setterArgs = @{
    Property = '$propertyName'
    Value = `$Value
}

if (`$PSBoundParameters.ContainsKey('Resource')) {
    `$setterArgs['Resource'] = `$Resource
}

if (`$PSBoundParameters.ContainsKey('Target')) {
    `$setterArgs['Target'] = `$Target
}

if (`$PSBoundParameters.ContainsKey('Scope')) {
    `$setterArgs['Scope'] = `$Scope
}

Setter @setterArgs
"@)
        $implicitSetterFunctions[$chromeCommandName] = $functionBody
    }

    $ScriptBlock.InvokeWithContext($implicitSetterFunctions, $chromeVars, @()) | Out-Null

    $contentPresenterFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.ContentPresenter])

    foreach ($mappedProperty in $adapter.ContentPropertyMap.GetEnumerator()) {
        if ($styleSetterTable.ContainsKey($mappedProperty.Key)) {
            Set-ChromeFactoryProperty -Factory $contentPresenterFactory -Property $mappedProperty.Value -Value $styleSetterTable[$mappedProperty.Key]
        } elseif ($adapter.ContentDefaults.Contains($mappedProperty.Key)) {
            Set-ChromeFactoryProperty -Factory $contentPresenterFactory -Property $mappedProperty.Value -Value $adapter.ContentDefaults[$mappedProperty.Key]
        }
    }

    $contentPresenterFactory.SetValue([System.Windows.Controls.ContentPresenter]::RecognizesAccessKeyProperty, $true)

    $chromeFactory.AppendChild($contentPresenterFactory)
    $template.VisualTree = $chromeFactory

    $style.Setters.Add(
        [System.Windows.Setter]::new(
            [System.Windows.Controls.Control]::TemplateProperty,
            $template
        )
    ) | Out-Null

    $style | Add-Member -NotePropertyName '_WPFHasChrome' -NotePropertyValue $true -Force
    $style | Add-Member -NotePropertyName '_WPFChromeTemplate' -NotePropertyValue $template -Force
    $style | Add-Member -NotePropertyName '_WPFChromeTargetName' -NotePropertyValue $adapter.PartName -Force
    $style | Add-Member -NotePropertyName '_WPFChromeTargetType' -NotePropertyValue $adapter.ShellType -Force
}
