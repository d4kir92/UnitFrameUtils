local _, UnitFrameUtils = ...
local ICON = 236373
local DEFAULT_SCALE = 0.7
local DEFAULT_OFFSET = 2
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
    ["RAIDICONHIDECOMBAT"] = false
}

local function GetTocVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata("UnitFrameUtils", "Version") end
    if GetAddOnMetadata then return GetAddOnMetadata("UnitFrameUtils", "Version") end
    return "0.0.0"
end

local function ShowMinimapButtonDefault()
    return UnitFrameUtils:GetWoWBuild() ~= "RETAIL"
end

local function ApplySettings()
    for key, default in pairs(defaults) do
        UnitFrameUtils:SetOption(key, UnitFrameUtils:GV(UnitFrameUtilsDB, key, default))
    end

    UnitFrameUtils:SetRealmFlagPoint(UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGPOINT", "TOPRIGHT"))
    for _, context in ipairs({"GROUP", "RAID"}) do
        UnitFrameUtils:SetRealmFlagScale(context, UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGSCALE" .. context, DEFAULT_SCALE))
        UnitFrameUtils:SetRealmFlagOffset(context, UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGOFFSET" .. context, DEFAULT_OFFSET))
    end
end

local function AddScaleSlider(label, key)
    settings:AddSlider(
        {
            ["label"] = label,
            ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, key, DEFAULT_SCALE),
            ["min"] = 0.5,
            ["max"] = 2,
            ["step"] = 0.05,
            ["decimals"] = 2,
            ["func"] = function(value)
                UnitFrameUtils:SV(UnitFrameUtilsDB, key, value)
                ApplySettings()
            end
        }
    )
end

local function AddOffsetSlider(label, key)
    settings:AddSlider(
        {
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
        }
    )
end

local function AddToggle(label, key)
    settings:AddCheckbox({
        ["label"] = label,
        ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, key, defaults[key]),
        ["func"] = function(value)
            UnitFrameUtils:SV(UnitFrameUtilsDB, key, value)
            UnitFrameUtils:SetOption(key, value)
        end
    })
end

function UnitFrameUtils:ToggleSettings()
    if settings then settings:Toggle() end
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
        ["title"] = format("UnitFrameUtils v%s", GetTocVersion())
    })

    settings:AddSearch()
    settings:AddCategory({
        ["label"] = "LID_GENERAL"
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
        ["label"] = "LID_RAIDICON"
    })

    AddToggle("LID_SHOWRAIDICON", "SHOWRAIDICON")
    AddToggle("LID_HIDEINCOMBAT", "RAIDICONHIDECOMBAT")
    settings:AddCategory({
        ["label"] = "LID_LEADER"
    })

    AddToggle("LID_SHOWLEADER", "SHOWLEADER")
    settings:AddCategory({
        ["label"] = "LID_MYTHICRATING"
    })

    AddToggle("LID_SHOWMYTHICRATING", "SHOWMYTHICRATING")
    AddToggle("LID_HIDEINCOMBAT", "RATINGHIDECOMBAT")
    AddToggle("LID_HIDEININSTANCE", "RATINGHIDEINSTANCE")
    AddToggle("LID_HIDEINRAID", "RATINGHIDERAID")
    settings:AddCategory({
        ["label"] = "LID_ITEMLEVEL"
    })

    AddToggle("LID_SHOWITEMLEVEL", "SHOWITEMLEVEL")
    AddToggle("LID_HIDEINCOMBAT", "ILVLHIDECOMBAT")
    AddToggle("LID_HIDEININSTANCE", "ILVLHIDEINSTANCE")
    settings:AddCategory({
        ["label"] = "LID_FLAG"
    })

    settings:AddCategory({
        ["label"] = "LID_GROUP",
        ["sub"] = true
    })

    AddToggle("LID_SHOWFLAG", "SHOWFLAGGROUP")
    AddToggle("LID_HIDEINCOMBAT", "FLAGHIDECOMBATGROUP")
    AddToggle("LID_HIDEININSTANCE", "FLAGHIDEINSTANCEGROUP")
    AddScaleSlider("LID_FLAGSCALE", "FLAGSCALEGROUP")
    AddOffsetSlider("LID_FLAGOFFSET", "FLAGOFFSETGROUP")
    settings:AddCategory({
        ["label"] = "LID_RAID",
        ["sub"] = true
    })

    AddToggle("LID_SHOWFLAG", "SHOWFLAGRAID")
    AddToggle("LID_HIDEINCOMBAT", "FLAGHIDECOMBATRAID")
    AddToggle("LID_HIDEININSTANCE", "FLAGHIDEINSTANCERAID")
    AddScaleSlider("LID_FLAGSCALE", "FLAGSCALERAID")
    AddOffsetSlider("LID_FLAGOFFSET", "FLAGOFFSETRAID")
end

local loader = CreateFrame("Frame", "UnitFrameUtilsSettingsLoader")
UnitFrameUtils:RegisterEvent(loader, "PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    UnitFrameUtilsDB = UnitFrameUtilsDB or {}
    UnitFrameUtils:SetVersion(ICON, GetTocVersion())
    UnitFrameUtils:SetAddonOutput("UnitFrameUtils", ICON)
    UnitFrameUtils:CreateMinimapButton({
        ["name"] = "UnitFrameUtils",
        ["icon"] = ICON,
        ["dbtab"] = UnitFrameUtilsDB,
        ["dbkey"] = "SHOWMINIMAPBUTTON",
        ["vTT"] = {{"UnitFrameUtils", "v" .. GetTocVersion()}, {UnitFrameUtils:Trans("LID_LEFTCLICK"), UnitFrameUtils:Trans("LID_OPENSETTINGS")}, {UnitFrameUtils:Trans("LID_RIGHTCLICK"), UnitFrameUtils:Trans("LID_HIDEMINIMAPBUTTON")}},
        ["funcL"] = function() UnitFrameUtils:ToggleSettings() end,
        ["funcR"] = function()
            UnitFrameUtils:SV(UnitFrameUtilsDB, "SHOWMINIMAPBUTTON", false)
            UnitFrameUtils:HideMMBtn("UnitFrameUtils")
        end
    })

    UnitFrameUtils:InitSettings()
    ApplySettings()
    UnitFrameUtils:AddSlash("ufu", function() UnitFrameUtils:ToggleSettings() end)
    UnitFrameUtils:AddSlash("unitframeutils", function() UnitFrameUtils:ToggleSettings() end)
    print("LOADED")
end)

print("HÄ")
