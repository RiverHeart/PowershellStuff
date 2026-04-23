function Get-WPFDarkModePreference {
    try {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        $value = Get-ItemPropertyValue -Path $key -Name 'AppsUseLightTheme' -ErrorAction Stop
        return -not [bool]$value
    } catch {
        Write-Warning "Failed to get dark mode preference, defaulting to light mode."
        return $false
    }
}
