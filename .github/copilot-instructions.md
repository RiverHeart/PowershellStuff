# Overview

This repository contains a collection of PowerShell modules and scripts for various purposes, such as WPF UI development, file management, and more. Each module has its own set of instructions and coding style guidelines to ensure consistency and maintainability across the project.

# Repository Structure

- `src/modules/`: Contains the source code for all PowerShell modules, organized by functionality. Code here may or may not be production-ready, but should generally follow the coding style guidelines outlined in the instructions files.
- `src/modules/WPF/`: Contains the WPF DSL module for building Windows Presentation Foundation applications using PowerShell.
- `src/modules/GrabBag/`: Contains miscellaneous utility functions and scripts that don't fit into a specific category.
- `src/scripts/`: Contains standalone PowerShell scripts that can be executed directly.
- `src/projects/`: Contains project-specific code and resources. All code in this directory should be considered experimental and may not follow the same coding style guidelines as the modules.
- `PSScriptAnalyzerSettings.psd1`: Contains the configuration for PSScriptAnalyzer, which enforces the coding style guidelines across the project.

# Skills

- `.github/skills/test-runner`: A skill for discovering, listing, and running tests across the repository, including Pester suite discovery, tag discovery, and execution. Before any test execution, load this skill and follow its workflow, using `./.github/skills/test-runner/scripts/Invoke-Test.ps1` as the default test entrypoint.

# Test Execution Order

- Always run targeted tests first for files changed in the current task.
- If there are known failing tests from a previous run, re-run those failures first.
- Run the full suite only after targeted tests and previously failing tests pass.
- If full suite execution is required by mode instructions, keep that as the final validation step, not the first step.
