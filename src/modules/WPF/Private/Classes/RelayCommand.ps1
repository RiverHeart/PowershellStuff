<#
.SYNOPSIS
    A simple implementation of the ICommand interface for use in WPF applications.

.DESCRIPTION
    The RelayCommand class is a simple implementation of the ICommand interface that
    allows you to pass delegates for the Execute and CanExecute methods. It is commonly
    used in MVVM applications to bind commands to UI elements.

.NOTES
    This implementation is based on the RelayCommand class from the CommunityToolkit.Mvvm library.

    For the original implementation, see: https://github.com/CommunityToolkit/dotnet/blob/main/src/CommunityToolkit.Mvvm/Input/RelayCommand.cs
#>

# WARNING!
# This code MUST be compatible with Windows PowerShell 5.1.
# Do not use any syntax or APIs that are not supported in that version of PowerShell.
if (-not ('RelayCommand' -as [type])) {
    Add-Type -ErrorAction Stop -TypeDefinition @"
using System;
using System.Windows.Input;

public class RelayCommand : ICommand
{
    private readonly Action execute;
    private readonly Func<bool> canExecute;

    public event EventHandler CanExecuteChanged;

    public RelayCommand(Action execute)
    {
        if (execute == null)
        {
            throw new ArgumentNullException("execute");
        }

        this.execute = execute;
    }

    public RelayCommand(
        Action execute,
        Func<bool> canExecute
    )
    {
        if (execute == null)
        {
            throw new ArgumentNullException("execute");
        }

        if (canExecute == null)
        {
            throw new ArgumentNullException("canExecute");
        }

        this.execute = execute;
        this.canExecute = canExecute;
    }

    public void NotifyCanExecuteChanged()
    {
        EventHandler handler = this.CanExecuteChanged;
        if (handler != null)
        {
            handler(this, EventArgs.Empty);
        }
    }

    public bool CanExecute(object parameter) {
        return this.canExecute == null || this.canExecute();
    }

    public void Execute(object parameter) {
        this.execute();
    }
}
"@
}
