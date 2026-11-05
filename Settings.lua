local _, UnitFrameUtils = ...
local ICON = UnitFrameUtils:GetAddonIcon()
local MIN_SCALE = 0.2
local DEFAULT_SCALE = {
    ["GROUP"] = 0.7,
    ["RAID"] = 0.5
}

local DEFAULT_OFFSET = 2
local COMPANION_SCALE = 1
local settings = nil
local DEFAULT_WIDTH = 460
local DEFAULT_HEIGHT = 520
local defaults = {
    ["SHOWFLAGGROUP"] = true,
    ["FLAGHIDECOMBATGROUP"] = true,
    ["FLAGHIDEINSTANCEGROUP"] = true,
    ["SHOWFLAGRAID"] = true,
    ["FLAGHIDECOMBATRAID"] = true,
    ["FLAGHIDEINSTANCERAID"] = true,
    ["SHOWITEMLEVEL"] = true,
    ["ILVLHIDECOMBAT"] = true,
    ["ILVLHIDEINSTANCE"] = true,
    ["SHOWMYTHICRATING"] = true,
    ["RATINGHIDECOMBAT"] = true,
    ["RATINGHIDEINSTANCE"] = true,
    ["RATINGHIDERAID"] = true,
    ["SHOWLEADER"] = true,
    ["SHOWRAIDICON"] = true,
    ["RAIDICONHIDECOMBAT"] = false,
    ["SHOWCOMPANION"] = true,
    ["SHOWCOMPANIONNOTFULL"] = false,
    ["SHOWHOTPREDICTION"] = true,
    ["SHOWHOTPREDICTIONPRD"] = true,
    ["SHOWHOTPREDICTIONUNIT"] = true,
    ["HOTCUSTOMCOLOR"] = false
}

local DEFAULT_HOTCOLOR = {
    ["r"] = 11 / 255,
    ["g"] = 136 / 255,
    ["b"] = 105 / 255,
    ["a"] = 1
}

local function ShowMinimapButtonDefault()
    return UnitFrameUtils:GetWoWBuild() ~= "RETAIL"
end

local function HasDelveCompanion()
    return UnitFrameUtils:GetWoWBuildNr() >= 110000
end

local function HasMythicPlus()
    return not UnitFrameUtils:IsForever() and UnitFrameUtils:GetWoWBuildNr() >= 50000
end

local function GetHotColor()
    local color = UnitFrameUtils:GV(UnitFrameUtilsDB, "HOTCOLOR", DEFAULT_HOTCOLOR)
    if type(color) ~= "table" then color = DEFAULT_HOTCOLOR end

    return color.r or DEFAULT_HOTCOLOR.r, color.g or DEFAULT_HOTCOLOR.g, color.b or DEFAULT_HOTCOLOR.b, color.a or DEFAULT_HOTCOLOR.a
end

local function ApplySettings()
    if UnitFrameUtils.SetHotColor then UnitFrameUtils:SetHotColor(GetHotColor()) end
    for key, default in pairs(defaults) do
        UnitFrameUtils:SetOption(key, UnitFrameUtils:GV(UnitFrameUtilsDB, key, default))
    end

    UnitFrameUtils:SetCompanionScale(UnitFrameUtils:GV(UnitFrameUtilsDB, "COMPANIONSCALE", COMPANION_SCALE))
    UnitFrameUtils:SetRealmFlagPoint(UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGPOINT", "TOPRIGHT"))
    for _, context in ipairs({"GROUP", "RAID"}) do
        UnitFrameUtils:SetRealmFlagScale(context, UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGSCALE" .. context, DEFAULT_SCALE[context]))
        UnitFrameUtils:SetRealmFlagOffset(context, UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGOFFSET" .. context, DEFAULT_OFFSET))
    end
end

local function AddScaleSlider(label, key, context)
    settings:AddSlider({
        ["label"] = label,
        ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, key, DEFAULT_SCALE[context]),
        ["min"] = MIN_SCALE,
        ["max"] = 2,
        ["step"] = 0.05,
        ["decimals"] = 2,
        ["func"] = function(value)
            UnitFrameUtils:SV(UnitFrameUtilsDB, key, value)
            ApplySettings()
        end
    })
end

local function AddOffsetSlider(label, key)
    settings:AddSlider({
        ["label"] = label,
        ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, key, DEFAULT_OFFSET),
        ["min"] = 0,
        ["max"] = 20,
        ["step"] = 1,
        ["decimals"] = 0,
        ["func"] = function(value)
            UnitFrameUtils:SV(UnitFrameUtilsDB, key, value)
            ApplySettings()
        end
    })
end

local function GetCollapsed(key)
    if key == nil then return nil end
    if type(UnitFrameUtilsDB) ~= "table" then return nil end
    if type(UnitFrameUtilsDB["COLLAPSED"]) ~= "table" then return nil end

    return UnitFrameUtilsDB["COLLAPSED"][key]
end

local function SetCollapsed(key, collapsed)
    if key == nil then return end
    if type(UnitFrameUtilsDB) ~= "table" then return end
    if type(UnitFrameUtilsDB["COLLAPSED"]) ~= "table" then UnitFrameUtilsDB["COLLAPSED"] = {} end
    if collapsed then
        UnitFrameUtilsDB["COLLAPSED"][key] = true
    else
        UnitFrameUtilsDB["COLLAPSED"][key] = nil
    end
end

local function AddToggle(label, key, added, onChange)
    return settings:AddCheckbox({
        ["label"] = label,
        ["added"] = added,
        ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, key, defaults[key]),
        ["func"] = function(value)
            UnitFrameUtils:SV(UnitFrameUtilsDB, key, value)
            UnitFrameUtils:SetOption(key, value)
            if onChange then onChange(value) end
        end
    })
end

local function AddHotColorSettings()
    local customColor = AddToggle("LID_HOTCUSTOMCOLOR", "HOTCUSTOMCOLOR", "2026-11-05", function() settings:UpdateDependencies() end)
    local r, g, b, a = GetHotColor()
    local picker = settings:AddColorPicker({
        ["label"] = "LID_HOTCOLOR",
        ["added"] = "2026-11-05",
        ["value"] = {
            ["r"] = r,
            ["g"] = g,
            ["b"] = b,
            ["a"] = a
        },
        ["func"] = function(red, green, blue, alpha)
            UnitFrameUtils:SV(
                UnitFrameUtilsDB,
                "HOTCOLOR",
                {
                    ["r"] = red,
                    ["g"] = green,
                    ["b"] = blue,
                    ["a"] = alpha
                }
            )

            if UnitFrameUtils.SetHotColor then UnitFrameUtils:SetHotColor(red, green, blue, alpha) end
        end
    })

    settings:AddDependency(picker, function() return UnitFrameUtils:GV(UnitFrameUtilsDB, "HOTCUSTOMCOLOR", defaults["HOTCUSTOMCOLOR"]) == true end)
    settings:AddRequirement(picker, customColor)
end

function UnitFrameUtils:ToggleSettings()
    if settings then settings:Toggle() end
end

local function HandleSlash(msg)
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "companionreset" then
        UnitFrameUtils:ResetCompanionPosition()
        UnitFrameUtils:MSG(UnitFrameUtils:Trans("LID_COMPANION"), UnitFrameUtils:Trans("LID_RESET"))

        return
    end

    if cmd == "taint" then
        UnitFrameUtils:ReportTaint()

        return
    end

    if cmd == "marker" then
        UnitFrameUtils:ReportRaidIcon()

        return
    end

    if cmd == "debug" and UnitFrameUtils.ToggleHotColorDebug then
        UnitFrameUtils:ToggleHotColorDebug()

        return
    end

    if cmd == "hot" and UnitFrameUtils.ToggleHotDebug then
        UnitFrameUtils:ToggleHotDebug()

        return
    end

    UnitFrameUtils:ToggleSettings()
end

function UnitFrameUtils:InitSettings()
    settings = UnitFrameUtils:CreateUIWindow({
        ["name"] = "UnitFrameUtilsSettings",
        ["pTab"] = {"CENTER"},
        ["width"] = UnitFrameUtils:GV(UnitFrameUtilsDB, "WINDOWWIDTH", DEFAULT_WIDTH),
        ["height"] = UnitFrameUtils:GV(UnitFrameUtilsDB, "WINDOWHEIGHT", DEFAULT_HEIGHT),
        ["minWidth"] = 360,
        ["minHeight"] = 240,
        ["onResize"] = function(width, height)
            UnitFrameUtils:SV(UnitFrameUtilsDB, "WINDOWWIDTH", width)
            UnitFrameUtils:SV(UnitFrameUtilsDB, "WINDOWHEIGHT", height)
        end,
        ["getCollapsed"] = function(key) return GetCollapsed(key) end,
        ["setCollapsed"] = function(key, collapsed) SetCollapsed(key, collapsed) end,
        ["title"] = format("|T%s:16:16:0:0|t UnitFrameUtils v%s", ICON, UnitFrameUtils:GetAddonVersion())
    })

    settings:AddSearch()
    settings:AddCategory({
        ["label"] = "LID_GENERAL",
        ["key"] = "GENERAL"
    })

    settings:AddCheckbox({
        ["label"] = "LID_SHOWMINIMAPBUTTON",
        ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, "SHOWMINIMAPBUTTON", ShowMinimapButtonDefault()),
        ["func"] = function(value)
            UnitFrameUtils:SV(UnitFrameUtilsDB, "SHOWMINIMAPBUTTON", value)
            if value then
                UnitFrameUtils:ShowMMBtn("UnitFrameUtils")
            else
                UnitFrameUtils:HideMMBtn("UnitFrameUtils")
            end
        end
    })

    settings:AddCategory({
        ["label"] = "LID_RAIDICON",
        ["key"] = "RAIDICON"
    })

    AddToggle("LID_SHOWRAIDICON", "SHOWRAIDICON")
    AddToggle("LID_HIDEINCOMBAT", "RAIDICONHIDECOMBAT")
    settings:AddCategory({
        ["label"] = "LID_LEADER",
        ["key"] = "LEADER"
    })

    AddToggle("LID_SHOWLEADER", "SHOWLEADER")
    if UnitFrameUtils:IsForever() then
        settings:AddCategory({
            ["label"] = "LID_HOTPREDICTION",
            ["key"] = "HOTPREDICTION",
            ["added"] = "2026-11-05"
        })

        AddToggle("LID_SHOWHOTPREDICTION", "SHOWHOTPREDICTION", "2026-11-05")
        AddToggle("LID_SHOWHOTPREDICTIONPRD", "SHOWHOTPREDICTIONPRD", "2026-11-05")
        AddToggle("LID_SHOWHOTPREDICTIONUNIT", "SHOWHOTPREDICTIONUNIT", "2026-11-05")
        AddHotColorSettings()
    end

    if HasDelveCompanion() then
        settings:AddCategory({
            ["label"] = "LID_COMPANION",
            ["key"] = "COMPANION"
        })

        AddToggle("LID_SHOWCOMPANION", "SHOWCOMPANION")
        AddToggle("LID_SHOWCOMPANIONNOTFULL", "SHOWCOMPANIONNOTFULL")
        settings:AddSlider({
            ["label"] = "LID_COMPANIONSCALE",
            ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, "COMPANIONSCALE", COMPANION_SCALE),
            ["min"] = MIN_SCALE,
            ["max"] = 2,
            ["step"] = 0.05,
            ["decimals"] = 2,
            ["func"] = function(value)
                UnitFrameUtils:SV(UnitFrameUtilsDB, "COMPANIONSCALE", value)
                UnitFrameUtils:SetCompanionScale(value)
            end
        })
    end

    if HasMythicPlus() then
        settings:AddCategory({
            ["label"] = "LID_MYTHICRATING",
            ["key"] = "MYTHICRATING"
        })

        AddToggle("LID_SHOWMYTHICRATING", "SHOWMYTHICRATING")
        AddToggle("LID_HIDEINCOMBAT", "RATINGHIDECOMBAT")
        AddToggle("LID_HIDEININSTANCE", "RATINGHIDEINSTANCE")
        AddToggle("LID_HIDEINRAID", "RATINGHIDERAID")
    end

    settings:AddCategory({
        ["label"] = "LID_ITEMLEVEL",
        ["key"] = "ITEMLEVEL"
    })

    AddToggle("LID_SHOWITEMLEVEL", "SHOWITEMLEVEL")
    AddToggle("LID_HIDEINCOMBAT", "ILVLHIDECOMBAT")
    AddToggle("LID_HIDEININSTANCE", "ILVLHIDEINSTANCE")
    if not UnitFrameUtils:IsForever() then
        settings:AddCategory({
            ["label"] = "LID_FLAG",
            ["key"] = "FLAG"
        })

        settings:AddCategory({
            ["label"] = "LID_GROUP",
            ["key"] = "FLAGGROUP",
            ["sub"] = true
        })

        AddToggle("LID_SHOWFLAG", "SHOWFLAGGROUP")
        AddToggle("LID_HIDEINCOMBAT", "FLAGHIDECOMBATGROUP")
        AddToggle("LID_HIDEININSTANCE", "FLAGHIDEINSTANCEGROUP")
        AddScaleSlider("LID_FLAGSCALE", "FLAGSCALEGROUP", "GROUP")
        AddOffsetSlider("LID_FLAGOFFSET", "FLAGOFFSETGROUP")
        settings:AddCategory({
            ["label"] = "LID_RAID",
            ["key"] = "FLAGRAID",
            ["sub"] = true
        })

        AddToggle("LID_SHOWFLAG", "SHOWFLAGRAID")
        AddToggle("LID_HIDEINCOMBAT", "FLAGHIDECOMBATRAID")
        AddToggle("LID_HIDEININSTANCE", "FLAGHIDEINSTANCERAID")
        AddScaleSlider("LID_FLAGSCALE", "FLAGSCALERAID", "RAID")
        AddOffsetSlider("LID_FLAGOFFSET", "FLAGOFFSETRAID")
    end

    settings:UpdateDependencies()
end

local loader = CreateFrame("Frame", "UnitFrameUtilsSettingsLoader")
UnitFrameUtils:RegisterEvent(loader, "PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    UnitFrameUtilsDB = UnitFrameUtilsDB or {}
    UnitFrameUtils:SetVersion()
    UnitFrameUtils:SetAddonOutput()
    UnitFrameUtils:CreateMinimapButton({
        ["name"] = "UnitFrameUtils",
        ["icon"] = ICON,
        ["dbtab"] = UnitFrameUtilsDB,
        ["dbkey"] = "SHOWMINIMAPBUTTON",
        ["vTT"] = {{format("|T%s:16:16:0:0|t UnitFrameUtils", ICON), "v" .. UnitFrameUtils:GetAddonVersion()}, {UnitFrameUtils:Trans("LID_LEFTCLICK"), UnitFrameUtils:Trans("LID_OPENSETTINGS")}, {UnitFrameUtils:Trans("LID_RIGHTCLICK"), UnitFrameUtils:Trans("LID_HIDEMINIMAPBUTTON")}},
        ["funcL"] = function() UnitFrameUtils:ToggleSettings() end,
        ["funcR"] = function()
            UnitFrameUtils:SV(UnitFrameUtilsDB, "SHOWMINIMAPBUTTON", false)
            UnitFrameUtils:HideMMBtn("UnitFrameUtils")
        end
    })

    UnitFrameUtils:InitSettings()
    ApplySettings()
    UnitFrameUtils:AddSlash("ufu", HandleSlash)
    UnitFrameUtils:AddSlash("unitframeutils", HandleSlash)
end)
