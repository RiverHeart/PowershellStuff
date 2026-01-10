While nice in theory, do remember that Powershell classes are awful to test/use within modules. Consider when state tracking is required and only as a last resort.

**Remember:**
* Once a module gets loaded it stays loaded, requiring a session restart when making updates.
* Keeping files separate means Powershell/PSScriptAnalyzer can't find custom types defined in other files so they will whine at you.
* Various limitations, such as not supporting private variables or events or calculated properties, at least not without some hacking.
* Can't import class from module without `using module $ModuleName`
