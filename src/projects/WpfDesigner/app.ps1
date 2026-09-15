Import-Module "$PSScriptRoot/../../modules/WPF/WPF.psd1" -Force

Start-WPFApplication `
    -ModulePath "$PSScriptRoot/WpfDesigner.psd1" `
    -EntryPoint 'src/Views/main.view.ps1' `
    -Force
