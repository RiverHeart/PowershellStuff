# Stolen from https://github.com/CommunityToolkit/dotnet/blob/main/src/CommunityToolkit.Mvvm/Input/RelayCommand.cs

Add-Type -TypeDefinition @"
#nullable enable
using System;
using System.Runtime.CompilerServices;
using System.Windows.Input;

public class RelayCommand : ICommand
{
    private readonly Action execute;
    private readonly Func<bool>? canExecute;

    public event EventHandler? CanExecuteChanged;

    public RelayCommand(Action execute)
    {
        ArgumentNullException.ThrowIfNull(execute);
        this.execute = execute;
    }

    public RelayCommand(
        Action execute,
        Func<bool> canExecute
    )
    {
        ArgumentNullException.ThrowIfNull(execute);
        ArgumentNullException.ThrowIfNull(canExecute);
        this.execute = execute;
        this.canExecute = canExecute;
    }

    public void NotifyCanExecuteChanged()
    {
        CanExecuteChanged?.Invoke(this, EventArgs.Empty);
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public bool CanExecute(object? parameter) {
        return this.canExecute?.Invoke() != false;
    }

    public void Execute(object? parameter) {
        this.execute();
    }
}
"@
