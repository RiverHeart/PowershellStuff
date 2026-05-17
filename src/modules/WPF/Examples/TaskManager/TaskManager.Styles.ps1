<#
.SYNOPSIS
    Style declarations for the TaskManager project.

.DESCRIPTION
    Add theme, brush, and style definitions in this file as your project grows.
#>

# Right-aligned DataGrid header style for CPU/Memory columns
Style 'RightAlignedDataGridHeader' DataGridColumnHeader {
    Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
    Setter HorizontalContentAlignment ([HorizontalAlignment]::Right)
}

# Right-aligned DataGrid cell style for CPU/Memory columns
Style 'RightAlignedDataGridCell' TextBlock {
    Setter HorizontalAlignment ([HorizontalAlignment]::Right)
}

# DataGrid header and cell alignment styles
Style DataGridColumnHeader {
    Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
    Setter HorizontalContentAlignment ([HorizontalAlignment]::Right)
}

Style TextBlock {
    Setter HorizontalAlignment ([HorizontalAlignment]::Right)
}
