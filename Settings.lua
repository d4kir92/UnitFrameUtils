local _, UnitFrameUtils = ...
local ICON = 135994
local DEFAULT_SCALE = 0.7
local DEFAULT_OFFSET = 2
local settings = nil

local function GetTocVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then return C_AddOns.GetAddOnMetadata("UnitFrameUtils", "Version") end
    if GetAddOnMetadata then return GetAddOnMetadata("UnitFrameUtils", "Version") end

    return "0.0.0"
end

local function ShowMinimapButtonDefault()
    return UnitFrameUtils:GetWoWBuild() ~= "RETAIL"
end

local function ApplyFlagSettings()
    UnitFrameUtils:SetRealmFlagScale(UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGSCALE", DEFAULT_SCALE))
    UnitFrameUtils:SetRealmFlagPosition(UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGPOINT", "TOPRIGHT"), UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGOFFSET", DEFAULT_OFFSET))
end

function UnitFrameUtils:ToggleSettings()
    if settings then settings:Toggle() end
end

function UnitFrameUtils:InitSettings()
    settings = UnitFrameUtils:CreateUIWindow(
        {
            ["name"] = "UnitFrameUtilsSettings",
            ["pTab"] = {"CENTER"},
            ["width"] = 460,
            ["height"] = 320,
            ["title"] = format("UnitFrameUtils v%s", GetTocVersion())
        }
    )

    settings:AddSearch()
    settings:AddCheckbox(
        {
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
        }
    )

    settings:AddSlider(
        {
            ["label"] = "LID_FLAGSCALE",
            ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGSCALE", DEFAULT_SCALE),
            ["min"] = 0.5,
            ["max"] = 2,
            ["step"] = 0.05,
            ["decimals"] = 2,
            ["func"] = function(value)
                UnitFrameUtils:SV(UnitFrameUtilsDB, "FLAGSCALE", value)
                UnitFrameUtils:SetRealmFlagScale(value)
            end
        }
    )

    settings:AddSlider(
        {
            ["label"] = "LID_FLAGOFFSET",
            ["value"] = UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGOFFSET", DEFAULT_OFFSET),
            ["min"] = 0,
            ["max"] = 20,
            ["step"] = 1,
            ["decimals"] = 0,
            ["func"] = function(value)
                UnitFrameUtils:SV(UnitFrameUtilsDB, "FLAGOFFSET", value)
                UnitFrameUtils:SetRealmFlagPosition(UnitFrameUtils:GV(UnitFrameUtilsDB, "FLAGPOINT", "TOPRIGHT"), value)
            end
        }
    )
end

local loader = CreateFrame("Frame", "UnitFrameUtilsSettingsLoader")
UnitFrameUtils:RegisterEvent(loader, "PLAYER_LOGIN")
loader:SetScript(
    "OnEvent",
    function()
        UnitFrameUtilsDB = UnitFrameUtilsDB or {}
        UnitFrameUtils:SetVersion(ICON, GetTocVersion())
        UnitFrameUtils:SetAddonOutput("UnitFrameUtils", ICON)
        UnitFrameUtils:CreateMinimapButton(
            {
                ["name"] = "UnitFrameUtils",
                ["icon"] = ICON,
                ["dbtab"] = UnitFrameUtilsDB,
                ["dbkey"] = "SHOWMINIMAPBUTTON",
                ["vTT"] = {
                    {"UnitFrameUtils", "v" .. GetTocVersion()},
                    {UnitFrameUtils:Trans("LID_LEFTCLICK"), UnitFrameUtils:Trans("LID_OPENSETTINGS")},
                    {UnitFrameUtils:Trans("LID_RIGHTCLICK"), UnitFrameUtils:Trans("LID_HIDEMINIMAPBUTTON")}
                },
                ["funcL"] = function() UnitFrameUtils:ToggleSettings() end,
                ["funcR"] = function()
                    UnitFrameUtils:SV(UnitFrameUtilsDB, "SHOWMINIMAPBUTTON", false)
                    UnitFrameUtils:HideMMBtn("UnitFrameUtils")
                end
            }
        )

        UnitFrameUtils:InitSettings()
        ApplyFlagSettings()
        UnitFrameUtils:AddSlash("ufu", function() UnitFrameUtils:ToggleSettings() end)
        UnitFrameUtils:AddSlash("unitframeutils", function() UnitFrameUtils:ToggleSettings() end)
    end
)
