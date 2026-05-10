# Claude_Codex Tracker — Handover for Next Session

## Project
- Path: `/Users/sakthivelramasamy/Documents/Codex/claude_codex_tracker`
- Main UI file: `native/Launcher.swift`
- Build command: `./build.sh`
- Installed app target: `/Applications/Claude_Codex_Tracker.app`

## Current objective
Continue **UI/UX fine-tuning** of the menubar popup for Claude + Codex usage.

## Current UI direction (final agreed trend)
1. Low-noise layout (removed extra noise labels/chips/shortcuts where possible)
2. Primary rows retained:
- `5H`
- `WEEKLY`
- Progress bar
- Reset line with reset icon + absolute time on right
3. Action section simplified:
- `Show Remaining %`
- `Open Claude Analytics`
- `Open Codex Analytics`
- `Refresh now`
- `Quit`
4. Header text style:
- `Claude & Codex · Live`
- `Updated <time>`

## Important behavioral rules already requested
1. Menu bar color logic should match progress threshold logic:
- `> 80` => red
- `>= 50` => amber
- else green
2. Weekly 100% should be treated as capped-state signal (same semantics as session capped context where applicable).
3. Avoid introducing seam/gap artifacts between Claude and Codex blocks.
4. Avoid web-search for local UI change requests.

## Repeated UX pain points to preserve/avoid regressions
1. Tiny seam line between Claude and Codex blocks when not hovered
2. Inconsistent vertical spacing around:
- `5H` -> bar
- bar -> reset row
- reset row -> dotted divider
- dotted divider -> `WEEKLY`
3. Right-side alignment drift (percentage/reset times) after layout tweaks
4. Overly wide popup after noise reduction
5. Inconsistent hover vs non-hover fill treatment

## Last requested visual preferences (high priority)
1. Keep Claude and Codex as visually distinct block tints
2. No visible divider seam between Claude and Codex blocks
3. Maintain small but clear gap above Claude/Codex headers
4. Keep gap below reset line and above dotted line balanced and consistent in both blocks
5. Keep dotted divider spacing subtle (not touching `WEEKLY` label)
6. Minimal text noise (already reduced)

## Pending / open fine-tuning items for next session
1. Final color selection for Codex header (user still not fully satisfied)
2. Confirm exact micro-spacing balance in each sub-row under both providers
3. Final pass for consistent vertical rhythm across entire popup
4. Optional: decide whether weekly/session capped wording needs further simplification

## Compliance/security context (relevant to this app)
- If this app evolves into multi-provider key onboarding, use Keychain-only storage and no plaintext secrets.
- Prefer official APIs, avoid scraping if provider terms do not allow it.

## Files likely to touch next
- `native/Launcher.swift` (UI spacing/colors/row rendering)
- Possibly helper data formatting functions in same file

## Operational notes
- Rebuild/relaunch after each focused tweak using `./build.sh`
- Validate with screenshot after each change to avoid regressions

## Session discipline note
- For local UI tasks: do not use internet/web search.
- Keep edits surgical; do one micro-change at a time, verify, then proceed.

