/// <summary>
/// A PowerShell host UI that suppresses output such as Write-Host, Write-Error,
/// and other streams, while still allowing user interaction through prompts.
///
/// <para><c>[Console]::WriteLine()</c> calls are not suppressed and will still output to the console.</para>
/// </summary>
using System;
using System.Collections;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;
using Foo;

namespace Foo
{
    public class SilentPSHostUI : PSHostUserInterface
    {
        private readonly PSHostUserInterface _baseUI;

        // Pass the original PSHostUserInterface to forward interactive prompts
        public SilentPSHostUI(PSHostUserInterface baseUI)
        {
            if (baseUI == null)
            {
                throw new ArgumentNullException(nameof(baseUI));
            }
            this._baseUI = baseUI;
        }


        // Suppress all output methods
        public override void Write(string value) { }
        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) { }
        public override void WriteLine() { }
        public override void WriteLine(string value) { }
        public override void WriteLine(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value) { }


        // Suppress secondary streams
        public override void WriteDebugLine(string message) { }
        public override void WriteErrorLine(string value) { }
        public override void WriteInformation(InformationRecord record) { }
        public override void WriteProgress(long sourceId, ProgressRecord progressRecord) { }
        public override void WriteVerboseLine(string value) { }
        public override void WriteWarningLine(string value) { }


        // Forward interactive prompts to the base UI
        public override Dictionary<string, PSObject> Prompt(
            string caption,
            string message,
            Collection<FieldDescription> descriptions
        ) {
            return _baseUI.Prompt(caption, message, descriptions);
        }

        public override PSCredential PromptForCredential(
            string caption,
            string message,
            string userName,
            string targetName
        ) {
            return _baseUI.PromptForCredential(caption, message, userName, targetName);
        }

        public override PSCredential PromptForCredential(
            string caption,
            string message,
            string userName,
            string targetName,
            PSCredentialTypes allowedCredentialTypes,
            PSCredentialUIOptions options
        ) {
            return _baseUI.PromptForCredential(caption, message, userName, targetName, allowedCredentialTypes, options);
        }

        public override int PromptForChoice(
            string caption,
            string message,
            Collection<ChoiceDescription> choices,
            int defaultChoice
        ) {
            return _baseUI.PromptForChoice(caption, message, choices, defaultChoice);
        }

        public override string ReadLine()
        {
            return _baseUI.ReadLine();
        }

        public override SecureString ReadLineAsSecureString()
        {
            return _baseUI.ReadLineAsSecureString();
        }

        // Forward raw ui access
        public override PSHostRawUserInterface RawUI
        {
            get { return _baseUI.RawUI; }
        }
    }
}

public class SilentPSHost : PSHost
{
    private readonly Guid _id = Guid.NewGuid();
    private readonly SilentPSHostUI _ui;

    public SilentPSHost(PSHost host)
    {
        if (host == null) throw new ArgumentNullException(nameof(host));
        _ui = new SilentPSHostUI(host.UI);
    }

    public override string Name => "SilentPSHost";
    public override Version Version => new Version(1, 0);

    public override Guid InstanceId => _id;

    public override PSHostUserInterface UI => _ui;


    // The following methods are required overrides for PSHost but are
    // intentionally left empty to suppress output.
    public override CultureInfo CurrentCulture {
        get { return CultureInfo.CurrentCulture; }
    }

    public override CultureInfo CurrentUICulture {
        get { return CultureInfo.CurrentUICulture; }
    }

    public override void SetShouldExit(int exitCode) { }

    public override void EnterNestedPrompt() { throw new NotImplementedException(); }

    public override void ExitNestedPrompt() { throw new NotImplementedException(); }

    public override void NotifyBeginApplication() { }

    public override void NotifyEndApplication() { }
}
