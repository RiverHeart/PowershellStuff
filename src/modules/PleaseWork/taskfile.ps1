build: {
    & "$(git rev-parse --show-toplevel)/tools/Build-PSResource.ps1" `
        -ProjectPath ./project.psd1 `
        -DestinationPath "$(git rev-parse --show-toplevel)/artifacts/packages"
}
