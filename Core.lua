local _, UnitFrameUtils = ...
local MEDIA = "Interface\\AddOns\\UnitFrameUtils\\media\\"
local FLAG_SIZE = 32
local FLAG_CROP = 43 / 64
local INSPECT_DELAY = 2
local LEADER_ATLAS = "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
local LEADER_TEXTURE = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local LEADER_SIZE = 16
local LEADER_OFFSET = -4
local RAIDICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local RAIDICON_SIZE = 16
local RAIDICON_OFFSET = 2
local flagPoint = "TOPRIGHT"
local flagOffset = 2
local flagScale = 0.7
local raidFlagOffset = 2
local raidFlagScale = 0.7
local options = {
    ["SHOWFLAG"] = true,
    ["FLAGHIDECOMBAT"] = true,
    ["FLAGHIDEINSTANCE"] = true,
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

local function IsFeatureVisible(showKey, combatKey, instanceKey, raidKey)
    if not options[showKey] then return false end
    if combatKey and options[combatKey] and InCombatLockdown() then return false end
    if instanceKey and options[instanceKey] and IsInInstance() then return false end
    if raidKey and options[raidKey] and IsInRaid() then return false end

    return true
end

local function IsFlagVisible()
    return IsFeatureVisible("SHOWFLAG", "FLAGHIDECOMBAT", "FLAGHIDEINSTANCE")
end

local function IsItemLevelVisible()
    return IsFeatureVisible("SHOWITEMLEVEL", "ILVLHIDECOMBAT", "ILVLHIDEINSTANCE")
end

local function IsRatingVisible()
    return IsFeatureVisible("SHOWMYTHICRATING", "RATINGHIDECOMBAT", "RATINGHIDEINSTANCE", "RATINGHIDERAID")
end

local function IsLeaderVisible()
    return options["SHOWLEADER"] == true
end

local function IsRaidIconVisible()
    return IsFeatureVisible("SHOWRAIDICON", "RAIDICONHIDECOMBAT", nil)
end

local function ApplyLeaderTexture(icon)
    if icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(LEADER_ATLAS) then
        icon:SetAtlas(LEADER_ATLAS)

        return
    end

    icon:SetTexture(LEADER_TEXTURE)
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

local function UpdateLeader(frame)
    local overlay = overlays[frame]
    if overlay == nil then return end
    local unit = GetUnit(frame)
    if unit and IsLeaderVisible() and UnitIsGroupLeader(unit) then
        overlay.leader:Show()
    else
        overlay.leader:Hide()
    end
end

local function UpdateRaidIcon(frame)
    local overlay = overlays[frame]
    if overlay == nil then return end
    local unit = GetUnit(frame)
    local index = nil
    if unit and IsRaidIconVisible() then index = GetRaidTargetIndex(unit) end
    if index and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(overlay.raidIcon, index)
        overlay.raidIcon:Show()
    else
        overlay.raidIcon:Hide()
    end
end

local function UpdateFrame(frame)
    UpdateFlag(frame)
    UpdateRaidIcon(frame)
    UpdateLeader(frame)
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

local function GetFlagScale()
    if IsInRaid() then return raidFlagScale end

    return flagScale
end

local function GetFlagOffset()
    if IsInRaid() then return raidFlagOffset end

    return flagOffset
end

local function ApplyFlagSize(icon)
    local scale = GetFlagScale()
    icon:SetSize(FLAG_SIZE * scale, FLAG_SIZE * FLAG_CROP * scale)
end

local function ApplyFlagPosition(icon, frame)
    local offset = GetFlagOffset()
    local x, y = offset, offset
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
    local raidIcon = frame:CreateTexture(name .. ".UFU_RaidIcon", "OVERLAY")
    raidIcon:SetDrawLayer("OVERLAY", 7)
    raidIcon:SetSize(RAIDICON_SIZE, RAIDICON_SIZE)
    raidIcon:SetPoint("TOP", frame, "TOP", 0, -RAIDICON_OFFSET)
    raidIcon:SetTexture(RAIDICON_TEXTURE)
    raidIcon:Hide()
    local leader = frame:CreateTexture(name .. ".UFU_Leader", "OVERLAY")
    leader:SetDrawLayer("OVERLAY", 7)
    leader:SetSize(LEADER_SIZE, LEADER_SIZE)
    leader:SetPoint("BOTTOM", raidIcon, "TOP", 0, LEADER_OFFSET)
    ApplyLeaderTexture(leader)
    leader:Hide()
    local info = frame:CreateFontString(name .. ".UFU_Info", "OVERLAY", "GameFontHighlightSmall")
    info:SetDrawLayer("OVERLAY", 7)
    local healthBar = _G[name .. "HealthBarBackground"] or frame.healthBar or frame
    info:SetPoint("BOTTOM", healthBar, "BOTTOM", 0, 2)
    info:SetJustifyH("CENTER")
    UnitFrameUtils:SetFontSize(info, 10, "")
    info:SetShadowColor(0, 0, 0, 1)
    info:SetShadowOffset(1, -1)
    overlays[frame] = {
        ["flag"] = icon,
        ["raidIcon"] = raidIcon,
        ["leader"] = leader,
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
    for frame, overlay in pairs(overlays) do
        ApplyFlagSize(overlay.flag)
        ApplyFlagPosition(overlay.flag, frame)
        UpdateFrame(frame)
    end
end

function UnitFrameUtils:SetRealmFlagPosition(point, offset, raidOffset)
    flagPoint = point or "TOPRIGHT"
    flagOffset = offset or 2
    raidFlagOffset = raidOffset or flagOffset
    for frame, overlay in pairs(overlays) do
        ApplyFlagPosition(overlay.flag, frame)
    end
end

function UnitFrameUtils:SetRealmFlagScale(scale, raidScale)
    flagScale = scale or 0.7
    raidFlagScale = raidScale or flagScale
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
UnitFrameUtils:RegisterEvent(eventFrame, "PARTY_LEADER_CHANGED")
UnitFrameUtils:RegisterEvent(eventFrame, "RAID_TARGET_UPDATE")
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
