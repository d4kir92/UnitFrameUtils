local _, UnitFrameUtils = ...
local MEDIA = "Interface\\AddOns\\UnitFrameUtils\\media\\"
local FLAG_SIZE = 32
local FLAG_CROP = 43 / 64
local flagPoint = "TOPRIGHT"
local flagOffset = 2
local flags = {}
local function IsRaidFrame(name)
    if name == nil then return false end
    if string.find(name, "NamePlate") then return false end
    if string.find(name, "Compact") == nil then return false end
    return true
end

local function GetFlagForUnit(unit)
    if unit == nil then return nil end
    if not UnitExists(unit) then return nil end
    if not UnitIsPlayer(unit) then return nil end
    local _, realmName = UnitName(unit)
    if realmName == nil or realmName == "" then realmName = GetRealmName() end
    if realmName == nil then return nil end
    local lang = UnitFrameUtils:GetRealmFlag(realmName)
    if lang == nil or lang == "" then return nil end
    return lang
end

local function UpdateFlag(frame)
    local icon = flags[frame]
    if icon == nil then return end
    local lang = GetFlagForUnit(frame.displayedUnit or frame.unit)
    if lang then
        icon:SetTexture(MEDIA .. lang)
        icon:Show()
    else
        icon:SetTexture(nil)
        icon:Hide()
    end
end

local function ApplyFlagPosition(icon, frame)
    local x, y = flagOffset, flagOffset
    if string.find(flagPoint, "RIGHT") then x = -x end
    if string.find(flagPoint, "TOP") then y = -y end
    icon:ClearAllPoints()
    icon:SetPoint(flagPoint, frame, flagPoint, x, y)
end

local function AddFlag(frame)
    if frame == nil then return end
    if flags[frame] then return end
    local name = frame:GetName()
    if not IsRaidFrame(name) then return end
    local icon = frame:CreateTexture(name .. ".UFU_Flag", "OVERLAY")
    icon:SetDrawLayer("OVERLAY", 7)
    icon:SetTexCoord(0, 1, 0, FLAG_CROP)
    icon:SetSize(FLAG_SIZE, FLAG_SIZE * FLAG_CROP)
    icon:SetScale(1)
    ApplyFlagPosition(icon, frame)
    flags[frame] = icon
    UpdateFlag(frame)
end

local function ScanFrames()
    for i = 1, 40 do
        AddFlag(_G["CompactRaidFrame" .. i])
        if i <= 5 then AddFlag(_G["CompactPartyFrameMember" .. i]) end
        if i <= 8 then
            for x = 1, 5 do
                AddFlag(_G["CompactRaidGroup" .. i .. "Member" .. x])
            end
        end
    end
end

function UnitFrameUtils:UpdateRealmFlags()
    ScanFrames()
    for frame in pairs(flags) do
        UpdateFlag(frame)
    end
end

function UnitFrameUtils:SetRealmFlagPosition(point, offset)
    flagPoint = point or "TOPRIGHT"
    flagOffset = offset or 2
    for frame, icon in pairs(flags) do
        ApplyFlagPosition(icon, frame)
    end
end

if _G["CompactUnitFrame_UpdateName"] then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if frame == nil then return end
        if flags[frame] == nil then AddFlag(frame) end
        UpdateFlag(frame)
    end)
end

local eventFrame = CreateFrame("Frame")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
UnitFrameUtils:RegisterEvent(eventFrame, "GROUP_ROSTER_UPDATE")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_NAME_UPDATE")
eventFrame:SetScript("OnEvent", function() UnitFrameUtils:After(0.1, function() UnitFrameUtils:UpdateRealmFlags() end, "UnitFrameUtils:UpdateRealmFlags") end)
