# WPF DSL Grammar Injection (Local)

This extension contributes a TextMate injection grammar that scopes WPF DSL style property keys like:

```powershell
CornerRadius: 8
Padding: 4
BorderThickness: 1
```

Only the `PropertyName` token before `:` is scoped as `entity.other.attribute-name.wpf-dsl`.

## Load Locally (No Node Required)

1. Open the Command Palette in VS Code.
2. Run **Developer: Install Extension from Location...**.
3. Select this folder:
   - `.vscode/wpf-dsl-grammar-extension`
4. Reload VS Code when prompted.

## Notes

- No npm, Node.js, or build step is required for local install.
- Node tooling is only needed if you want to package/publish the extension.
- This is a Work-In-Progress. I'm not sure what the true coloring should be. The light blue given to variables is what is used for json/css keys but when used together clashes hard. Recoloring variables to a distinct color helps but breaks a default people would be used to.
