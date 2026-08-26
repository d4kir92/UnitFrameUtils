# D4Lib UI

Small, reusable settings UI for D4Lib addons. Every label goes through `D4:TryTrans`,
so any string starting with `LID_` is translated and any other string is used as-is.

## Files

| File | Contains |
| --- | --- |
| `D4UICore.lua` | element list, layout, search filtering, shared helpers |
| `D4UITranslations.lua` | translations the UI itself needs (`LID_SEARCH`) |
| `D4UIWindow.lua` | `D4:CreateUIWindow` |
| `D4UISearch.lua` | `win:AddSearch` |
| `D4UICheckbox.lua` | `win:AddCheckbox` |
| `D4UISlider.lua` | `win:AddSlider` |
| `D4UIDropdown.lua` | `win:AddDropdown` |

## Usage

```lua
local win = D4:CreateUIWindow({
    name = "MyAddonWindow",
    title = "LID_MYADDON",
    width = 420,
    height = 520,
})

win:AddCheckbox({
    label = "LID_ALWAYSVISIBLE",
    value = MyAddonDB.alwaysVisible,
    func = function(value) MyAddonDB.alwaysVisible = value end,
})

win:AddSearch()

win:AddSlider({
    label = "LID_SCALE",
    value = MyAddonDB.scale,
    min = 0.5,
    max = 2,
    step = 0.05,
    decimals = 2,
    func = function(value) MyAddonDB.scale = value end,
})

win:AddDropdown({
    label = "LID_FLAGPOSITION",
    value = MyAddonDB.flagPoint,
    choices = {
        {value = "TOPLEFT", label = "LID_TOPLEFT"},
        {value = "TOPRIGHT", label = "LID_TOPRIGHT"},
        {value = "BOTTOMLEFT", label = "LID_BOTTOMLEFT"},
        {value = "BOTTOMRIGHT", label = "LID_BOTTOMRIGHT"},
    },
    func = function(value) MyAddonDB.flagPoint = value end,
})

win:Show()
```

## Search

`win:AddSearch()` filters every element that is added **after** it. Elements added
before the search box are always visible, which is the place for things that must
never disappear. Matching is case-insensitive against the translated label.

Options: `label` (defaults to `LID_SEARCH`), `maxLetters`.

## Elements

All `Add*` calls take one options table and return the created frame.

- `AddCheckbox`: `label`, `value`, `func(value)`
- `AddSlider`: `label`, `value`, `min`, `max`, `step`, `decimals`, `func(value)`.
  If the translated label contains a format placeholder (`%s`, `%.2f`), the value is
  inserted there; otherwise it is appended as `label: value`.
- `AddDropdown`: `label`, `value`, `width`, `choices`, `func(value)`.
  `choices` is an ordered array of `{value = ..., label = "LID_..."}`.
  The returned frame has `holder:SetValue(value)` to change the selection without
  firing `func`.

## Window

`D4:CreateUIWindow` options: `name`, `title`, `width`, `height`, `parent`, `pTab`,
`templates`. The window is movable, scrollable and starts hidden. `win:Toggle()`
shows or hides it.
