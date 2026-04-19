# Decision: psmux install placement and test group (Issue #139)

**Date:** 2025-07-17
**Author:** Goofy (Cross-Platform Developer)
**Issue:** #139

## Context

Adding psmux (tmux equivalent for Windows PowerShell) to the Windows setup script.

## Decisions

### 1. Function placement -- after Install-Vim, before Install-CopilotCli

Install-Psmux is a standalone terminal tool (like vim), so it belongs with other editor/terminal tools. Placed after vim and before Copilot CLI which is a developer service integration, not a terminal tool.

### 2. Main call order -- mirrors function placement

Install-Psmux is called between Install-Vim and Install-CopilotCli in Main, keeping the call order consistent with function definition order.

### 3. No PATH patching (unlike vim)

psmux does not need the manual PATH workaround that vim requires. winget handles PATH registration for psmux correctly. If this changes, a follow-up can add it.

### 4. Test group letter -- Group H (not E)

The task template suggested "Group E" but Groups A-G already exist in the test file. Used Group H to follow the sequential naming convention.

### 5. AST-based tests instead of string matching

Used `[System.Management.Automation.Language.Parser]::ParseFile()` for function existence checks rather than simple `Select-String` patterns. This is more robust (catches renamed/commented-out functions) and aligns with the CI PS 5.1 validation approach documented in decisions.md.
