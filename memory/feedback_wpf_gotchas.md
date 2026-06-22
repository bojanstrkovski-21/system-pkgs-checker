---
name: feedback-wpf-gotchas
description: "Non-obvious WPF/XAML pitfalls discovered building the inventory GUI, useful if extending it further"
metadata: 
  node_type: memory
  title: WPF Styling Gotchas Hit While Building SystemInventoryGUI
  date: 2026-06-22
  version: 1
  authors: 
    - Bojan Shtrkovski
    - Claude Code
  type: feedback
  originSessionId: 2a04348d-7ced-48b2-a9c0-2f73a636b3ed
---

Technical lessons from building [[project-overview]]'s WPF GUI, worth checking again before any further UI work on SystemInventoryGUI.ps1:

- `DataGridCheckBoxColumn` assigns its generated `CheckBox` an internal default style directly — implicit `Style TargetType="CheckBox"` (no `x:Key`) is silently ignored. Must give the style an `x:Key` and wire it explicitly via `ElementStyle`/`EditingElementStyle` on the column.
- A WPF `Style`'s `Setter` elements must stay contiguous — splitting them across a `<Style.Triggers>` block (some setters before, some after) throws `'Setters' property has already been set on 'Style'` at parse time. Keep all `Setter`s together, `Style.Triggers` last.
- A `ComboBox` custom `ControlTemplate` that binds visible text to `{TemplateBinding SelectionBoxItem}` does **not** reliably honor `DisplayMemberPath` — it falls back to the object's `ToString()` (e.g. shows `@{Name=x; Path=y; Key=z}` for a PSCustomObject). Bind directly to `SelectedItem.<Property>` via `RelativeSource TemplatedParent` instead.
- `TabControl` and `DataGrid` draw their own native border from the default template even when only `Background`/`BorderBrush` are set via `Setter`s (not a full template override) — wrapping their content in a custom rounded `Border` produces a visible double-border unless the control's own `BorderThickness` is also set to `0`.
- `Get-AppxPackage -AllUsers` throws a terminating `UnauthorizedAccessException` when not elevated — bypasses `-ErrorAction SilentlyContinue` since it's a real .NET exception, not a pipeline error. Must check `IsInRole(Administrator)` first and wrap in try/catch.

**How to apply:** check this list first if a new control added to the GUI looks unstyled, double-bordered, or shows raw object text instead of expected content — these are the same class of bug each time.
