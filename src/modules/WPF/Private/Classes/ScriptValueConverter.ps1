<#
.SYNOPSIS
    A simple IValueConverter implementation backed by PowerShell scriptblocks.

.DESCRIPTION
    ScriptValueConverter allows WPF bindings to use PowerShell scriptblocks for
    Convert and ConvertBack operations while still satisfying WPF's requirement
    for a real System.Windows.Data.IValueConverter instance.
#>

# WARNING!
# This code MUST be compatible with Windows PowerShell 5.1.
# Do not use any syntax or APIs that are not supported in that version of PowerShell.
if (-not ('ScriptValueConverter' -as [type])) {
    Add-Type -ErrorAction Stop -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Windows.Data;

public class ScriptValueConverter : IValueConverter
{
    private readonly ScriptBlock convert;
    private readonly ScriptBlock convertBack;

    public ScriptValueConverter(ScriptBlock convert)
    {
        if (convert == null)
        {
            throw new ArgumentNullException("convert");
        }

        this.convert = convert;
    }

    public ScriptValueConverter(
        ScriptBlock convert,
        ScriptBlock convertBack
    )
    {
        if (convert == null)
        {
            throw new ArgumentNullException("convert");
        }

        this.convert = convert;
        this.convertBack = convertBack;
    }

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return InvokeScriptBlock(this.convert, value);
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (this.convertBack == null)
        {
            return Binding.DoNothing;
        }

        return InvokeScriptBlock(this.convertBack, value);
    }

    private static object InvokeScriptBlock(ScriptBlock scriptBlock, object value)
    {
        ScriptBlockAst scriptBlockAst = scriptBlock.Ast as ScriptBlockAst;
        bool hasParameters = scriptBlockAst != null &&
            scriptBlockAst.ParamBlock != null &&
            scriptBlockAst.ParamBlock.Parameters != null &&
            scriptBlockAst.ParamBlock.Parameters.Count > 0;

        if (hasParameters)
        {
            return Unwrap(scriptBlock.InvokeReturnAsIs(value));
        }

        List<PSVariable> variables = new List<PSVariable>();
        variables.Add(new PSVariable("_", value));
        variables.Add(new PSVariable("PSItem", value));

        Collection<PSObject> results = scriptBlock.InvokeWithContext(null, variables, null, null);
        if (results != null && results.Count > 0)
        {
            return Unwrap(results[0]);
        }

        return value;
    }

    private static object Unwrap(object value)
    {
        PSObject psObject = value as PSObject;
        if (psObject != null)
        {
            return psObject.BaseObject;
        }

        return value;
    }
}
"@ -ReferencedAssemblies @(
        'System'
    'System.Collections'
        'System.Core'
        'System.Management.Automation'
    'System.ObjectModel'
        'PresentationFramework'
    )
}