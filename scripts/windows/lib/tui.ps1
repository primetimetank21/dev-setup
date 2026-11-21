# scripts/windows/lib/tui.ps1 -- PS 5.1 ASCII menu and toolset resolution (#495 Slice 3)
#
# Dot-sourced by scripts/windows/setup.ps1.
# Exports: Resolve-FinalToolset, Show-ToolMenu
#
# PS 5.1 ASCII-only: no smart quotes, em-dashes, arrows, or non-ASCII characters.
# No Write-Host. Console output via [Console]::Write / [Console]::WriteLine only.

# ---------------------------------------------------------------------------
# Quiet Accent console styling. This remains deliberately local to the TUI:
# redirected/plain output is unchanged, and colors always restore immediately.
# Test seam: _PS_TUI_COLOR_OVERRIDE=0|1 forces plain or colored rendering.
# ---------------------------------------------------------------------------
$script:_TuiWriteOverride = $null

function Test-TuiColorEnabled {
    if ($env:_PS_TUI_COLOR_OVERRIDE -eq '0') { return $false }
    if (-not [string]::IsNullOrEmpty($env:NO_COLOR)) { return $false }

    try {
        if ($null -eq $Host.UI.RawUI) { return $false }
        $null = [Console]::ForegroundColor
    }
    catch {
        return $false
    }

    if ($env:_PS_TUI_COLOR_OVERRIDE -eq '1') { return $true }
    return -not [Console]::IsOutputRedirected
}

function Get-TuiRoleColor {
    param(
        [ValidateSet('Heading', 'Focus', 'Checked', 'OptIn', 'Confirmation', 'Warning', 'Cancel')]
        [string]$Role
    )

    switch ($Role) {
        'Heading'      { return [ConsoleColor]::Cyan }
        'Focus'        { return [ConsoleColor]::Cyan }
        'Checked'      { return [ConsoleColor]::Green }
        'OptIn'        { return [ConsoleColor]::Yellow }
        'Confirmation' { return [ConsoleColor]::Green }
        'Warning'      { return [ConsoleColor]::Yellow }
        'Cancel'       { return [ConsoleColor]::Yellow }
    }
}

function Write-TuiRaw {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '',
        Justification = 'The interactive TUI must write directly to the console without Write-Host.')]
    param(
        [string]$Text,
        [bool]$ErrorOutput = $false
    )

    if ($null -ne $script:_TuiWriteOverride) {
        & $script:_TuiWriteOverride $Text $ErrorOutput
        return
    }
    if ($ErrorOutput) {
        [Console]::Error.Write($Text)
    } else {
        [Console]::Write($Text)
    }
}

function Write-TuiStyled {
    param(
        [string]$Text,
        [ConsoleColor]$Color,
        [bool]$ErrorOutput = $false
    )

    if (-not (Test-TuiColorEnabled)) {
        Write-TuiRaw -Text $Text -ErrorOutput $ErrorOutput
        return
    }

    $previousColor = [Console]::ForegroundColor
    try {
        [Console]::ForegroundColor = $Color
        Write-TuiRaw -Text $Text -ErrorOutput $ErrorOutput
    }
    finally {
        [Console]::ForegroundColor = $previousColor
    }
}

function Write-TuiLine {
    param(
        [string]$Text,
        [ConsoleColor]$Color,
        [bool]$ErrorOutput = $false
    )

    Write-TuiStyled -Text $Text -Color $Color -ErrorOutput $ErrorOutput
    Write-TuiRaw -Text ([Environment]::NewLine) -ErrorOutput $ErrorOutput
}

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
# Show-ToolMenu: interactive ASCII checkbox menu.
#
# Returns:
#   $null         -- user cancelled (Esc/Q) OR ReadKey failure (safe cancel fallback)
#   [string[]]@() -- user confirmed with nothing checked
#   [string[]]    -- user confirmed; array of checked tool names in display order
#
# ponytail: $null vs @() return -- verified safe: cancel returns $null (no comma),
#   non-null returns use ,$selected (comma prefix) to prevent pipeline unrolling.
#   Caller assigns [string[]]$x = Show-ToolMenu; $null-eq-check and Count-check
#   are distinguishable. See test T_menu_noop_empty_ps.
#
# Display order: DefaultTools pre-checked (default), then sorted opt-ins unchecked.
# Keys: Up/Down = move cursor; Space = toggle; A = toggle all; Enter = confirm; Esc/Q = cancel.
# ---------------------------------------------------------------------------
function Show-ToolMenu {
    param(
        [string[]]$DefaultTools = @(),
        [string[]]$Available    = @()
    )

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
        Write-TuiLine -Text 'Select tools to install (defaults pre-checked):' `
            -Color (Get-TuiRoleColor -Role 'Heading')
        [Console]::WriteLine('')
        for ($i = 0; $i -lt $items.Count; $i++) {
            $mark  = if ($checked[$i]) { '[x]' } else { '[ ]' }
            $label = if ($i -lt $nDef)  { '(default)' } else { '(opt-in)' }
            $arrow = if ($i -eq $cursor) { '>' } else { ' ' }
            Write-TuiRaw -Text '  '
            if ($arrow -eq '>') {
                Write-TuiStyled -Text $arrow -Color (Get-TuiRoleColor -Role 'Focus')
            } else {
                Write-TuiRaw -Text $arrow
            }
            Write-TuiRaw -Text ' '
            if ($checked[$i]) {
                Write-TuiStyled -Text $mark -Color (Get-TuiRoleColor -Role 'Checked')
            } else {
                Write-TuiRaw -Text $mark
            }
            Write-TuiRaw -Text " $($items[$i]) "
            if ($i -lt $nDef) {
                [Console]::WriteLine($label)
            } else {
                Write-TuiStyled -Text $label -Color (Get-TuiRoleColor -Role 'OptIn')
                [Console]::WriteLine()
            }
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
        # ReadKey failure in a nominally interactive host: one clear warning, install cancelled
        Write-TuiLine -Text (
            "WARNING: Interactive menu failed ($($_.Exception.Message)). Installation is being cancelled.") `
            -Color (Get-TuiRoleColor -Role 'Warning') -ErrorOutput $true
        return $null
    }

    if ($cancelled) { return $null }

    [string[]]$selected = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($checked[$i]) { $selected += $items[$i] }
    }
    Write-TuiLine -Text 'Selection confirmed.' -Color (Get-TuiRoleColor -Role 'Confirmation')
    return ,$selected
}
