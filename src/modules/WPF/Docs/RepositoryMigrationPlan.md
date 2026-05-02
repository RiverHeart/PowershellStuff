# WPF Repository Migration Plan

This document describes a low-friction path for splitting the WPF module into its own repository while preserving WPF-only history.

## Recommendation

Use `git subtree split` from the current repository.

Why this approach:

- It is built into Git, so it is usually less annoying on Windows than `git filter-repo`.
- It preserves the history for `src/modules/WPF` without dragging along unrelated module history.
- The extracted branch already treats `src/modules/WPF` as the repository root, so files do not need a second rename pass after extraction.

## Preconditions

- Confirm WPF is self-contained under `src/modules/WPF`.
- Decide the name and remote URL of the new repository.
- Decide whether repo-root files such as `LICENSE`, `.gitignore`, and `PSScriptAnalyzerSettings.psd1` should be copied into the new repository after the split.

## Migration Sequence

Run these commands from the current repository root.

### 1. Create an extracted branch

```powershell
git subtree split --prefix=src/modules/WPF -b wpf-split
```

This creates a branch named `wpf-split` whose root tree is the current contents of `src/modules/WPF`.

Examples:

- `src/modules/WPF/README.md` becomes `README.md`
- `src/modules/WPF/WPF.psm1` becomes `WPF.psm1`
- `src/modules/WPF/Docs/` stays `Docs/`

### 2. Inspect the extracted branch in a separate worktree

```powershell
git worktree add ..\WPF-Repo wpf-split
```

This gives you a separate checkout without disturbing the current repository.

In the new worktree, verify:

- The module imports without relying on files outside the new repo root.
- Relative paths in docs, examples, and tests still make sense.
- Any repo-level settings you care about are present or intentionally omitted.

### 3. Add missing repo-root files in the extracted worktree

Likely candidates:

- `LICENSE`
- `.gitignore`
- `PSScriptAnalyzerSettings.psd1`
- GitHub workflow files, if you want CI from day one

Do this as ordinary commits inside the extracted worktree. Keep it small and intentional.

### 4. Create the new repository remote

Create an empty repository on GitHub, then add it as a remote from the extracted worktree.

```powershell
git remote add origin <new-repo-url>
```

### 5. Push the extracted history

```powershell
git push -u origin wpf-split:main
```

If you rename the local branch first, push that branch instead.

### 6. Add traceability notes in both repositories

In the new repository:

- Add a short note explaining that it was extracted from the original monorepo.

In the current repository:

- Add a short note in the WPF area pointing to the new repository.
- Treat the in-repo copy as archived or remove it entirely once the split is complete.

## Minimal Validation Checklist

Before publishing, verify these in the extracted worktree:

- `README.md` reads correctly from the repo root.
- `Docs/` links resolve without the old `src/modules/WPF` prefix.
- `Examples/` still work with the new root layout.
- Tests and helper scripts do not assume the old monorepo path.
- Module manifest paths are still correct.

## Suggested Follow-Up Cleanup

- Convert markdown backlog candidates into GitHub issues.
- Add issue templates only if you expect outside contributors soon.
- Keep `MaintainerNotes.md` for durable implementation context.
- Keep the development log light and avoid using it as a permanent backlog.

## Alternative: Fresh Repo With Archive Link

If preserving history starts to feel heavier than the value it provides, the fallback is simple:

- Create a fresh repository from the current WPF contents.
- Link back to this repository as the incubation archive.
- Accept that commit-level archaeology will live in the old repo only.

That is acceptable for a personal project, but if the module is approaching public reuse, preserving WPF-only history is the better default.
