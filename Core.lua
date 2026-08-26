local _, UnitFrameUtils = ...
local MEDIA = "Interface\\AddOns\\UnitFrameUtils\\media\\"
local FLAG_SIZE = 32
local FLAG_CROP = 43 / 64
local INSPECT_DELAY = 2
local flagPoint = "TOPRIGHT"
local flagOffset = 2
local flagScale = 0.7
local options = {
    ["SHOWFLAG"] = true,
    ["FLAGHIDECOMBAT"] = true,
    ["FLAGHIDEINSTANCE"] = true,
    ["SHOWITEMLEVEL"] = true,
    ["ILVLHIDECOMBAT"] = true,
    ["ILVLHIDEINSTANCE"] = true,
    ["SHOWMYTHICRATING"] = true,
    ["RATINGHIDECOMBAT"] = true,
    ["RATINGHIDEINSTANCE"] = true
}

local overlays = {}
local inspectQueue = {}
local nextInspect = 0
local inspectRunning = false
local StartInspectQueue = nil

local function IsRaidFrame(name)
    if name == nil then return false end
    if string.find(name, "NamePlate") then return false end
    if string.find(name, "Compact") == nil then return false end

    return true
end

local function IsFeatureVisible(showKey, combatKey, instanceKey)
    if not options[showKey] then return false end
    if options[combatKey] and InCombatLockdown() then return false end
    if options[instanceKey] and IsInInstance() then return false end

    return true
end

local function IsFlagVisible()
    return IsFeatureVisible("SHOWFLAG", "FLAGHIDECOMBAT", "FLAGHIDEINSTANCE")
end

local function IsItemLevelVisible()
    return IsFeatureVisible("SHOWITEMLEVEL", "ILVLHIDECOMBAT", "ILVLHIDEINSTANCE")
end

local function IsRatingVisible()
    return IsFeatureVisible("SHOWMYTHICRATING", "RATINGHIDECOMBAT", "RATINGHIDEINSTANCE")
end

local function GetUnit(frame)
    if frame == nil then return nil end
    local unit = frame.displayedUnit or frame.unit
    if unit == nil then return nil end
    if not UnitExists(unit) then return nil end
    if not UnitIsPlayer(unit) then return nil end

    return unit
end

local function GetRealmFlagForUnit(unit)
    local _, realmName = UnitName(unit)
    if realmName == nil or realmName == "" then realmName = GetRealmName() end
    if realmName == nil then return nil end
    local lang = UnitFrameUtils:GetRealmFlag(realmName)
    if lang == nil or lang == "" then return nil end

    return lang
end

local function GetItemLevelForUnit(unit)
    if UnitIsUnit(unit, "player") then
        local _, equipped = GetAverageItemLevel()
        if equipped and equipped > 0 then return math.floor(equipped) end

        return nil
    end

    local guid = UnitGUID(unit)
    if guid == nil then return nil end
    local ilvl = UnitFrameUtils:GetCachedItemLevel(guid)
    if ilvl and ilvl > 0 then return math.floor(ilvl) end

    return nil
end

local function GetRatingForUnit(unit)
    if C_PlayerInfo == nil then return nil end
    if C_PlayerInfo.GetPlayerMythicPlusRatingSummary == nil then return nil end
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
    if summary == nil then return nil end
    local score = summary.currentSeasonScore
    if score == nil or score <= 0 then return nil end

    return score
end

local function GetInfoText(unit)
    local parts = {}
    if IsItemLevelVisible() then
        local ilvl = GetItemLevelForUnit(unit)
        if ilvl then tinsert(parts, UnitFrameUtils:Trans("LID_ILVL") .. ": " .. ilvl) end
    end

    if IsRatingVisible() then
        local score = GetRatingForUnit(unit)
        if score then tinsert(parts, UnitFrameUtils:Trans("LID_MYTHICSHORT") .. ": " .. score) end
    end

    if #parts == 0 then return nil end

    return table.concat(parts, "  ")
end

local function QueueInspect(unit)
    if not IsItemLevelVisible() then return end
    if InCombatLockdown() then return end
    if UnitIsUnit(unit, "player") then return end
    if not CanInspect(unit) then return end
    local guid = UnitGUID(unit)
    if guid == nil then return end
    if UnitFrameUtils:GetCachedItemLevel(guid) then return end
    if UnitFrameUtils:GetInspectCache(guid) then return end
    inspectQueue[guid] = unit
end

local function RunInspectQueue()
    inspectRunning = false
    if IsItemLevelVisible() and not InCombatLockdown() and GetTime() >= nextInspect then
        for guid, unit in pairs(inspectQueue) do
            inspectQueue[guid] = nil
            if UnitExists(unit) and UnitGUID(unit) == guid and CanInspect(unit) then
                nextInspect = GetTime() + INSPECT_DELAY
                UnitFrameUtils:SaveToInspectCache(guid)
                NotifyInspect(unit)
                break
            end
        end
    end

    StartInspectQueue()
end

function StartInspectQueue()
    if inspectRunning then return end
    if next(inspectQueue) == nil then return end
    inspectRunning = true
    UnitFrameUtils:After(INSPECT_DELAY, RunInspectQueue, "UnitFrameUtils:InspectQueue")
end

local function UpdateFlag(frame)
    local overlay = overlays[frame]
    if overlay == nil then return end
    local unit = GetUnit(frame)
    local lang = nil
    if unit and IsFlagVisible() then lang = GetRealmFlagForUnit(unit) end
    if lang then
        overlay.flag:SetTexture(MEDIA .. lang)
        overlay.flag:Show()
    else
        overlay.flag:SetTexture(nil)
        overlay.flag:Hide()
    end
end

local function UpdateInfo(frame)
    local overlay = overlays[frame]
    if overlay == nil then return end
    local unit = GetUnit(frame)
    local text = nil
    if unit then
        QueueInspect(unit)
        StartInspectQueue()
        text = GetInfoText(unit)
    end

    if text then
        overlay.info:SetText(text)
        overlay.info:Show()
    else
        overlay.info:SetText("")
        overlay.info:Hide()
    end
end

local function UpdateFrame(frame)
    UpdateFlag(frame)
    UpdateInfo(frame)
end

local function UpdateByGUID(guid)
    for frame in pairs(overlays) do
        local unit = GetUnit(frame)
        if unit and UnitGUID(unit) == guid then UpdateInfo(frame) end
    end
end

local function FindUnitByGUID(guid)
    for frame in pairs(overlays) do
        local unit = GetUnit(frame)
        if unit and UnitGUID(unit) == guid then return unit end
    end

    return nil
end

local function OnInspectReady(guid)
    if guid == nil then return end
    if UnitFrameUtils:GetCachedItemLevel(guid) then return end
    local unit = FindUnitByGUID(guid)
    if unit == nil then return end
    local ilvl = nil
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then ilvl = C_PaperDollInfo.GetInspectItemLevel(unit) end
    if ilvl == nil or ilvl <= 0 then ilvl = UnitFrameUtils:GetInspectILvl(unit) end
    if ilvl and ilvl > 0 then
        UnitFrameUtils:SaveToItemLevelCache(guid, ilvl)
        UpdateByGUID(guid)
    end
end

local function ApplyFlagSize(icon)
    icon:SetSize(FLAG_SIZE * flagScale, FLAG_SIZE * FLAG_CROP * flagScale)
end

local function ApplyFlagPosition(icon, frame)
    local x, y = flagOffset, flagOffset
    if string.find(flagPoint, "RIGHT") then x = -x end
    if string.find(flagPoint, "TOP") then y = -y end
    icon:ClearAllPoints()
    icon:SetPoint(flagPoint, frame, flagPoint, x, y)
end

local function AddOverlay(frame)
    if frame == nil then return end
    if overlays[frame] then return end
    local name = frame:GetName()
    if not IsRaidFrame(name) then return end
    local icon = frame:CreateTexture(name .. ".UFU_Flag", "OVERLAY")
    icon:SetDrawLayer("OVERLAY", 7)
    icon:SetTexCoord(0, 1, 0, FLAG_CROP)
    icon:SetScale(1)
    ApplyFlagSize(icon)
    ApplyFlagPosition(icon, frame)
    local info = frame:CreateFontString(name .. ".UFU_Info", "OVERLAY", "GameFontHighlightSmall")
    info:SetDrawLayer("OVERLAY", 7)
    info:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    info:SetJustifyH("CENTER")
    UnitFrameUtils:SetFontSize(info, 10, "THINOUTLINE")
    overlays[frame] = {
        ["flag"] = icon,
        ["info"] = info
    }

    UpdateFrame(frame)
end

local function ScanFrames()
    for i = 1, 40 do
        AddOverlay(_G["CompactRaidFrame" .. i])
        if i <= 5 then AddOverlay(_G["CompactPartyFrameMember" .. i]) end
        if i <= 8 then
            for x = 1, 5 do
                AddOverlay(_G["CompactRaidGroup" .. i .. "Member" .. x])
            end
        end
    end
end

function UnitFrameUtils:UpdateRaidFrames()
    ScanFrames()
    for frame in pairs(overlays) do
        UpdateFrame(frame)
    end
end

function UnitFrameUtils:SetRealmFlagPosition(point, offset)
    flagPoint = point or "TOPRIGHT"
    flagOffset = offset or 2
    for frame, overlay in pairs(overlays) do
        ApplyFlagPosition(overlay.flag, frame)
    end
end

function UnitFrameUtils:SetRealmFlagScale(scale)
    flagScale = scale or 0.7
    for _, overlay in pairs(overlays) do
        ApplyFlagSize(overlay.flag)
    end
end

function UnitFrameUtils:SetOption(key, value)
    if key == nil then return end
    if options[key] == nil then return end
    options[key] = value == true
    for frame in pairs(overlays) do
        UpdateFrame(frame)
    end
end

function UnitFrameUtils:GetOption(key)
    if key == nil then return nil end

    return options[key]
end

if _G["CompactUnitFrame_UpdateName"] then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if frame == nil then return end
        if overlays[frame] == nil then AddOverlay(frame) end
        UpdateFrame(frame)
    end)
end

local eventFrame = CreateFrame("Frame")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
UnitFrameUtils:RegisterEvent(eventFrame, "GROUP_ROSTER_UPDATE")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_REGEN_DISABLED")
UnitFrameUtils:RegisterEvent(eventFrame, "ZONE_CHANGED_NEW_AREA")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_NAME_UPDATE")
UnitFrameUtils:RegisterEvent(eventFrame, "INSPECT_READY")
eventFrame:SetScript(
    "OnEvent",
    function(sel, event, ...)
        if event == "INSPECT_READY" then
            local guid = ...
            OnInspectReady(guid)

            return
        end

        UnitFrameUtils:After(0.1, function() UnitFrameUtils:UpdateRaidFrames() end, "UnitFrameUtils:UpdateRaidFrames")
    end
)
