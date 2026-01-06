# Argument Completers

## User Context

Argument completion always occurs in the user context so if we are accessing module scoped variables we need to use a public function to interact with it. Private functions cannot be used for argument completion.

## PSReviewUnusedParameter

PSScriptAnalyzer will bark at you about `PSReviewUnusedParameter` but including the code below to suppress it
somehow causes an error during runtime that is not indicated to the user whatsoever...

```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(<#Category#> 'PSReviewUnusedParameter', Scope='Function', Justification='My little remaining sanity')]
```

## WordToComplete

You may not think it but `"Foo".StartsWith("") returns $True`. A null value cast to a string becomes an empty string. With this in mind, always filter on `$WordToComplete` even when it's null.

## Disabling Autocomplete Fallback

If there is nothing to complete Powershell will fallback to it's default which is to autocomplete files. Return `$null` when there are no results to prevent that.
