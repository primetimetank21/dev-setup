# scripts/windows/lib/tui.ps1 -- PS 5.1 ASCII menu and toolset resolution (#495 Slice 3)
#
# Dot-sourced by scripts/windows/setup.ps1.
# Exports: Resolve-FinalToolset, Resolve-ToolSelection, Show-ToolMenu
#
# PS 5.1 ASCII-only: no smart quotes, em-dashes, arrows, or non-ASCII characters.
# No Write-Host. Console output via [Console]::Write / [Console]::WriteLine only.

# ---------------------------------------------------------------------------
# Resolve-FinalToolset: canonical ordered tool resolver.
# Pure function -- no exit, no console output, no validation.
# Callers must validate tool names before calling (non-interactive path).
#
# Returns [string[]] in install order:
#   -Only path : DefaultTools order first, then opt-ins appended alphabetically.
#   -Skip path : DefaultTools minus skipped, in default order.
#   default    : DefaultTools unchanged.
# ---------------------------------------------------------------------------
function Resolve-FinalToolset {
    param(
        [string[]]$DefaultTools = @(),
        [string]$Only           = '',
        [bool]$OnlySet          = $false,
        [string]$Skip           = '',
        [bool]$SkipSet          = $false
    )
    [string[]]$finalTools = @()
    if ($OnlySet) {
        $names = @($Only.Split(',') | Where-Object { $_ -ne '' })
        # Preserve default order for requested defaults
        foreach ($tool in $DefaultTools) {
            if ($names -contains $tool) { $finalTools += $tool }
        }
        # Opt-ins (requested but not in DefaultTools): append alphabetically
        $optIn = @($names | Where-Object { $DefaultTools -notcontains $_ } | Sort-Object)
        foreach ($t in $optIn) { $finalTools += $t }
    } elseif ($SkipSet) {
        $names = @($Skip.Split(',') | Where-Object { $_ -ne '' })
        foreach ($tool in $DefaultTools) {
            if ($names -notcontains $tool) { $finalTools += $tool }
        }
    } else {
        $finalTools = $DefaultTools
    }
    return ,$finalTools
}

# ---------------------------------------------------------------------------
# Resolve-ToolSelection: map a checked bool-array onto a display-order items array.
# Input:  $Checked -- bool array parallel to $Items
#         $Items   -- tool names in display order (DefaultTools first, sorted opt-ins after)
# Output: comma-separated string of checked item names in display order.
# ---------------------------------------------------------------------------
function Resolve-ToolSelection {
    param(
        [bool[]]$Checked   = @(),
        [string[]]$Items   = @()
    )
    $selected = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Checked[$i]) { $selected += $Items[$i] }
    }
    return ($selected -join ',')
}

# ---------------------------------------------------------------------------
# Show-ToolMenu: interactive ASCII checkbox menu.
#
# Returns:
#   $null         -- user cancelled (Esc/Q) OR ReadKey failure (safe fallback)
#   [string[]]@() -- user confirmed with nothing checked
#   [string[]]    -- user confirmed; array of checked tool names in display order
#
# Display order: DefaultTools pre-checked (default), then sorted opt-ins unchecked.
# Keys: Up/Down = move cursor; Space = toggle; A = toggle all; Enter = confirm; Esc/Q = cancel.
# ---------------------------------------------------------------------------
function Show-ToolMenu {
    param(
        [string[]]$DefaultTools = @(),
        [string[]]$Available    = @()
    )

    # ponytail: test seams -- remove when TTY simulation is available in CI
    if ($env:_PS_TUI_MOCK -eq 'cancel') { return $null }
    if ($env:_PS_TUI_MOCK -eq 'empty')  { return ,@() }

    # Build display order: defaults (pre-checked) then sorted opt-ins (unchecked)
    $optIns  = @($Available | Where-Object { $DefaultTools -notcontains $_ } | Sort-Object)
    $items   = @($DefaultTools) + $optIns
    $nDef    = $DefaultTools.Count
    [bool[]]$checked = @()
    for ($i = 0; $i -lt $nDef;         $i++) { $checked += $true }
    for ($i = 0; $i -lt $optIns.Count; $i++) { $checked += $false }

    $cursor    = 0
    $confirmed = $false
    $cancelled = $false

    # Render-Menu as scriptblock (closure over $items, $checked, $cursor, $nDef)
    $renderMenu = {
        [Console]::WriteLine('Select tools to install (defaults pre-checked):')
        [Console]::WriteLine('')
        for ($i = 0; $i -lt $items.Count; $i++) {
            $mark  = if ($checked[$i]) { '[x]' } else { '[ ]' }
            $label = if ($i -lt $nDef)  { '(default)' } else { '(opt-in)' }
            $arrow = if ($i -eq $cursor) { '>' } else { ' ' }
            [Console]::WriteLine("  $arrow $mark $($items[$i]) $label")
        }
        [Console]::WriteLine('')
        [Console]::WriteLine('  Up/Down=move  Space=toggle  A=all  Enter=confirm  Esc/Q=cancel')
    }

    try {
        [Console]::Clear()
        & $renderMenu

        while (-not $confirmed -and -not $cancelled) {
            $key = [Console]::ReadKey($true)
            [Console]::Clear()
            switch ($key.Key) {
                'UpArrow'   { $cursor = [Math]::Max(0, $cursor - 1) }
                'DownArrow' { $cursor = [Math]::Min($items.Count - 1, $cursor + 1) }
                'Spacebar'  { $checked[$cursor] = -not $checked[$cursor] }
                'Enter'     { $confirmed = $true }
                'Escape'    { $cancelled = $true }
                'Q'         { $cancelled = $true }
                'A'         {
                    $anyUnchecked = $checked -contains $false
                    for ($i = 0; $i -lt $checked.Count; $i++) {
                        $checked[$i] = $anyUnchecked
                    }
                }
            }
            if (-not $confirmed -and -not $cancelled) { & $renderMenu }
        }
    } catch {
        # ReadKey failure in a nominally interactive host: one clear warning, safe fallback
        [Console]::Error.WriteLine(
            "WARNING: Console input unavailable ($($_.Exception.Message)). Proceeding non-interactively.")
        return $null
    }

    if ($cancelled) { return $null }

    [string[]]$selected = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($checked[$i]) { $selected += $items[$i] }
    }
    return ,$selected
}
