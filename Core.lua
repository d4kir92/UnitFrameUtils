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
local flagOffset = {
    ["GROUP"] = 2,
    ["RAID"] = 2
}

local flagScale = {
    ["GROUP"] = 0.7,
    ["RAID"] = 0.5
}
local options = {
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
    ["SHOWCOMPANIONNOTFULL"] = false
}

local overlays = {}
local inspectQueue = {}
local nextInspect = 0
local inspectRunning = false
local StartInspectQueue = nil

local function IsForbiddenFrame(frame)
    if frame.IsForbidden == nil then return false end
    local ok, forbidden = pcall(frame.IsForbidden, frame)

    return not ok or forbidden == true
end

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

local function GetFlagContext()
    if IsInRaid() then return "RAID" end

    return "GROUP"
end

local function IsFlagVisible()
    local context = GetFlagContext()

    return IsFeatureVisible("SHOWFLAG" .. context, "FLAGHIDECOMBAT" .. context, "FLAGHIDEINSTANCE" .. context)
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

local function IsSecret(value)
    return UnitFrameUtils:IsSecret(value)
end

local function SafeNumber(value)
    if value == nil then return nil end
    if IsSecret(value) then return nil end
    if type(value) ~= "number" then return nil end

    return value
end

function UnitFrameUtils:SafeBool(func, ...)
    if func == nil then return nil end
    local ok, value = pcall(func, ...)
    if not ok then return nil end
    if IsSecret(value) then return nil end

    return value == true
end

function UnitFrameUtils:UnitExists(unit)
    if unit == nil then return false end
    local ok, exists = pcall(UnitExists, unit)
    if not ok then return false end
    if IsSecret(exists) then return true end

    return exists == true
end

local function GetUnit(frame)
    if frame == nil then return nil end
    local unit = frame.displayedUnit or frame.unit
    if unit == nil then return nil end
    if not UnitFrameUtils:UnitExists(unit) then return nil end
    if UnitFrameUtils:SafeBool(UnitIsPlayer, unit) ~= true then return nil end

    return unit
end

local function GetSafeGUID(unit)
    if unit == nil then return nil end
    local guid = UnitGUID(unit)
    if guid == nil then return nil end
    if IsSecret(guid) then return nil end

    return guid
end

local function IsSameGUID(unit, guid)
    if guid == nil then return false end
    if IsSecret(guid) then return false end
    local unitGUID = GetSafeGUID(unit)
    if unitGUID == nil then return false end

    return unitGUID == guid
end

local function GetRealmFlagForUnit(unit)
    local ok, _, realmName = pcall(UnitName, unit)
    if not ok or IsSecret(realmName) then realmName = nil end
    if realmName == nil or realmName == "" then realmName = GetRealmName() end
    if realmName == nil then return nil end
    local lang = UnitFrameUtils:GetRealmFlag(realmName)
    if lang == nil or lang == "" then return nil end

    return lang
end

local function GetItemLevelForUnit(unit)
    if UnitFrameUtils:SafeBool(UnitIsUnit, unit, "player") == true then
        local _, equipped = GetAverageItemLevel()
        if equipped and equipped > 0 then return math.floor(equipped) end

        return nil
    end

    local guid = GetSafeGUID(unit)
    if guid == nil then return nil end
    local ilvl = UnitFrameUtils:GetCachedItemLevel(guid)
    if ilvl and ilvl > 0 then return math.floor(ilvl) end

    return nil
end

local function GetRatingForUnit(unit)
    if C_PlayerInfo == nil then return nil end
    if C_PlayerInfo.GetPlayerMythicPlusRatingSummary == nil then return nil end
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if not ok or summary == nil or IsSecret(summary) then return nil end
    local score = SafeNumber(summary.currentSeasonScore)
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
    if UnitFrameUtils:SafeBool(UnitIsUnit, unit, "player") == true then return end
    if UnitFrameUtils:SafeBool(CanInspect, unit) ~= true then return end
    local guid = GetSafeGUID(unit)
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
            if UnitFrameUtils:UnitExists(unit) and IsSameGUID(unit, guid) and UnitFrameUtils:SafeBool(CanInspect, unit) == true then
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
    if unit and IsLeaderVisible() and UnitFrameUtils:SafeBool(UnitIsGroupLeader, unit) == true then
        overlay.leader:Show()
    else
        overlay.leader:Hide()
    end
end

local function ApplySecretRaidIcon(icon, index)
    if not pcall(SetRaidTargetIconTexture, icon, index) then return false end
    if not pcall(function() icon:SetShown(index ~= nil) end) then icon:Show() end

    return true
end

local function UpdateRaidIcon(frame)
    local overlay = overlays[frame]
    if overlay == nil then return end
    local icon = overlay.raidIcon
    local unit = nil
    if IsRaidIconVisible() then unit = GetUnit(frame) end
    if unit == nil or SetRaidTargetIconTexture == nil then
        icon:Hide()

        return
    end

    local ok, index = pcall(GetRaidTargetIndex, unit)
    if not ok then
        icon:Hide()

        return
    end

    if IsSecret(index) then
        if not ApplySecretRaidIcon(icon, index) then icon:Hide() end

        return
    end

    if index then
        SetRaidTargetIconTexture(icon, index)
        icon:Show()
    else
        icon:Hide()
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
        if unit and IsSameGUID(unit, guid) then UpdateInfo(frame) end
    end
end

local function FindUnitByGUID(guid)
    for frame in pairs(overlays) do
        local unit = GetUnit(frame)
        if unit and IsSameGUID(unit, guid) then return unit end
    end

    return nil
end

local function OnInspectReady(guid)
    if guid == nil then return end
    if IsSecret(guid) then return end
    if UnitFrameUtils:GetCachedItemLevel(guid) then return end
    local unit = FindUnitByGUID(guid)
    if unit == nil then return end
    local ilvl = nil
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, value = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok then ilvl = SafeNumber(value) end
    end

    if ilvl == nil or ilvl <= 0 then
        local ok, value = pcall(UnitFrameUtils.GetInspectILvl, UnitFrameUtils, unit)
        ilvl = ok and SafeNumber(value) or nil
    end

    if ilvl and ilvl > 0 then
        UnitFrameUtils:SaveToItemLevelCache(guid, ilvl)
        UpdateByGUID(guid)
    end
end

local function ApplyFlagSize(icon)
    local scale = flagScale[GetFlagContext()]
    icon:SetSize(FLAG_SIZE * scale, FLAG_SIZE * FLAG_CROP * scale)
end

local function ApplyFlagPosition(icon, frame)
    local offset = flagOffset[GetFlagContext()]
    local x, y = offset, offset
    if string.find(flagPoint, "RIGHT") then x = -x end
    if string.find(flagPoint, "TOP") then y = -y end
    icon:ClearAllPoints()
    icon:SetPoint(flagPoint, frame, flagPoint, x, y)
end

local function AddOverlay(frame)
    if frame == nil then return end
    if overlays[frame] then return end
    if IsForbiddenFrame(frame) then return end
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

function UnitFrameUtils:SetRealmFlagPoint(point)
    flagPoint = point or "TOPRIGHT"
    for frame, overlay in pairs(overlays) do
        ApplyFlagPosition(overlay.flag, frame)
    end
end

function UnitFrameUtils:SetRealmFlagOffset(context, offset)
    if flagOffset[context] == nil then return end
    flagOffset[context] = offset or 2
    for frame, overlay in pairs(overlays) do
        ApplyFlagPosition(overlay.flag, frame)
    end
end

function UnitFrameUtils:SetRealmFlagScale(context, scale)
    if flagScale[context] == nil then return end
    flagScale[context] = scale or 0.7
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

    if UnitFrameUtils.ApplyCompanionOptions then UnitFrameUtils:ApplyCompanionOptions() end
    if UnitFrameUtils.UpdateCompanion then UnitFrameUtils:UpdateCompanion() end
end

function UnitFrameUtils:GetOption(key)
    if key == nil then return nil end

    return options[key]
end

local TAINT_FIELDS = {"unit", "displayedUnit", "menu", "healthBar", "powerBar", "name", "optionTable"}
local TAINT_GLOBALS = {"SetRaidTarget", "SetRaidTargetIcon", "SetRaidTargetIconTexture", "CompactUnitFrame_UpdateName", "CompactUnitFrame_SetUnit", "CompactUnitFrame_OnLoad", "SecureUnitButton_OnClick", "UnitPopup_OpenMenu", "UnitPopup_ShowMenu", "ToggleDropDownMenu"}
local TAINT_MAX_LINES = 40

local function ReportInsecure(state, label, ...)
    if state.lines >= TAINT_MAX_LINES then return false end
    local ok, secure, owner = pcall(issecurevariable, ...)
    if not ok then return false end
    if secure ~= false then return false end
    state.lines = state.lines + 1
    UnitFrameUtils:MSG("|cffff4040TAINT|r " .. label .. " |cffffff00<-|r " .. tostring(owner))

    return true
end

local function ReportFrameTaint(state, name)
    local frame = _G[name]
    if frame == nil then return end
    if IsForbiddenFrame(frame) then return end
    state.frames = state.frames + 1
    ReportInsecure(state, "_G." .. name, name)
    for _, field in ipairs(TAINT_FIELDS) do
        ReportInsecure(state, name .. "." .. field, frame, field)
    end
end

local probeIcon = nil

local function GetProbeIcon()
    if probeIcon == nil then
        local probeFrame = CreateFrame("Frame")
        probeFrame:Hide()
        probeIcon = probeFrame:CreateTexture(nil, "OVERLAY")
        probeIcon:SetTexture(RAIDICON_TEXTURE)
    end

    return probeIcon
end

function UnitFrameUtils:ReportRaidIcon()
    UnitFrameUtils:MSG("SetRaidTargetIconTexture: " .. tostring(SetRaidTargetIconTexture ~= nil) .. "  issecretvalue: " .. tostring(issecretvalue ~= nil))
    local probe = GetProbeIcon()
    local units = {"player", "target", "focus"}
    for i = 1, 4 do
        tinsert(units, "party" .. i)
    end

    for i = 1, 40 do
        tinsert(units, "raid" .. i)
    end

    local lines = 0
    for _, unit in ipairs(units) do
        if lines < 12 and UnitFrameUtils:UnitExists(unit) then
            local ok, index = pcall(GetRaidTargetIndex, unit)
            local state
            if not ok then
                state = "|cffff4040call failed|r"
            elseif IsSecret(index) then
                local okTexture = pcall(SetRaidTargetIconTexture, probe, index)
                local okShown = pcall(function() probe:SetShown(index ~= nil) end)
                state = "|cffffff00secret|r  texture:" .. tostring(okTexture) .. "  setshown:" .. tostring(okShown)
            else
                state = tostring(index)
            end

            lines = lines + 1
            UnitFrameUtils:MSG(unit .. " |cffffff00->|r " .. state)
        end
    end

    if lines == 0 then UnitFrameUtils:MSG("no units found") end
end

function UnitFrameUtils:ReportTaint()
    if issecurevariable == nil then
        UnitFrameUtils:MSG("issecurevariable is not available on this client")

        return
    end

    local state = {
        ["lines"] = 0,
        ["frames"] = 0
    }

    for _, name in ipairs(TAINT_GLOBALS) do
        ReportInsecure(state, name, name)
    end

    for i = 1, 40 do
        ReportFrameTaint(state, "CompactRaidFrame" .. i)
        if i <= 5 then ReportFrameTaint(state, "CompactPartyFrameMember" .. i) end
        if i <= 8 then
            for x = 1, 5 do
                ReportFrameTaint(state, "CompactRaidGroup" .. i .. "Member" .. x)
            end
        end
    end

    ReportFrameTaint(state, "CompactPartyFrame")
    ReportFrameTaint(state, "CompactRaidFrameContainer")
    ReportFrameTaint(state, "TargetFrame")
    ReportFrameTaint(state, "FocusFrame")
    if state.lines >= TAINT_MAX_LINES then UnitFrameUtils:MSG("output truncated at " .. TAINT_MAX_LINES .. " lines") end
    UnitFrameUtils:MSG("taint scan done: " .. state.frames .. " frames, " .. state.lines .. " insecure values")
end

if _G["CompactUnitFrame_UpdateName"] then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if frame == nil then return end
        if overlays[frame] == nil then
            if IsForbiddenFrame(frame) then return end
            AddOverlay(frame)
        end

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
