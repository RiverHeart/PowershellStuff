Import-Module "$PSScriptRoot/../../modules/WPF/WPF.psd1" -Force

Start-WPFApplication `
    -ModulePath "$PSScriptRoot/WpfDesigner.psd1" `
    -Force
