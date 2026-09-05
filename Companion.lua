local _, UnitFrameUtils = ...
local FRAME_NAME = "UnitFrameUtilsCompanionFrame"
local FRAME_WIDTH = 140
local FRAME_HEIGHT = 44
local POWER_HEIGHT = 7
local AURA_SIZE = 18
local AURA_GAP = 2
local AURA_INSET = 2
local MAX_BUFFS = 3
local MAX_DEBUFFS = 3
local MAX_AURA_INDEX = 40
local BUFF_FILTER = "HELPFUL|PLAYER"
local DEBUFF_FILTER = "HARMFUL"
local PARTY_SLOTS = 5
local HP_FONT_SIZE = 18
local STALE_ALPHA = 0.4
local SELECTION_SIZE = 2
local ROLE_SIZE = 14
local DEFAULT_SCALE = 1
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local ROLE_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local STYLE_SOURCE = "CompactPartyFrameMember1"
local FALLBACK_UNITS = {"target", "mouseover"}
local ROLE_COORDS = {
    ["TANK"] = {0, 67 / 256, 67 / 256, 134 / 256},
    ["HEALER"] = {67 / 256, 134 / 256, 0, 67 / 256},
    ["DAMAGER"] = {67 / 256, 134 / 256, 67 / 256, 134 / 256}
}
local ROLE_ATLAS = {
    ["TANK"] = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    ["HEALER"] = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    ["DAMAGER"] = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder"
}

local frame = nil
local ticker = nil
local focusHider = nil
local companionNames = nil
local companionGUID = nil
local currentUnit = nil
local currentKey = nil
local frameMode = "none"
local frameIsSecure = false
local pendingSecure = false
local frameScale = DEFAULT_SCALE
local UpdateVisuals = nil
local function IsRetail()
    return UnitFrameUtils:GetWoWBuild() == "RETAIL"
end

local function IsLocked()
    return frameIsSecure == true and InCombatLockdown()
end

local function SetVisible(region, shown)
    if region == nil then return end
    if shown then
        region:SetAlpha(1)
    else
        region:SetAlpha(0)
    end
end

local function HasCompanionContext()
    if not IsRetail() then return false end
    if C_DelvesUI == nil then return false end
    if C_DelvesUI.HasActiveDelve then
        local ok, has = pcall(C_DelvesUI.HasActiveDelve)
        if ok and has == true then return true end
        if ok and has == false then return false end
    end
    return IsInInstance() == true
end

local function AddCompanionName(names, factionID)
    if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local ok, rep = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
        if ok and rep and rep.name and rep.name ~= "" then names[rep.name] = true end
    end

    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and data and data.name and data.name ~= "" then names[data.name] = true end
    end
end

local function GetCompanionNames()
    if companionNames and next(companionNames) then return companionNames end
    local names = {}
    if C_DelvesUI and C_DelvesUI.GetFactionForCompanion then
        for companionID = 1, 20 do
            local ok, factionID = pcall(C_DelvesUI.GetFactionForCompanion, companionID)
            if ok and type(factionID) == "number" and factionID > 0 then AddCompanionName(names, factionID) end
        end
    end

    companionNames = names
    return names
end

local function GetReadableName(unit)
    local ok, name = pcall(function()
        local value = UnitName(unit)
        if value == nil or value == "" then return nil end
        return value
    end)

    if ok and not UnitFrameUtils:IsSecret(name) and type(name) == "string" then return name end
    return nil
end

local function MatchesCompanionName(unit)
    local names = GetCompanionNames()
    if next(names) == nil then return false end
    local name = GetReadableName(unit)
    if name == nil then return false end
    if names[name] then return true end
    for companion in pairs(names) do
        if strfind(name, companion, 1, true) then return true end
        if strfind(companion, name, 1, true) then return true end
    end
    return false
end

local function GetNpcID(unit)
    local ok, id = pcall(function()
        local guid = UnitGUID(unit)
        if guid == nil then return nil end
        local kind, _, _, _, _, npcID = strsplit("-", guid)
        if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
        local num = tonumber(npcID)
        if type(num) ~= "number" then return nil end
        if num <= 0 then return nil end
        return num
    end)

    if ok and type(id) == "number" then return id end
    return nil
end

local function GetKnownNpcIDs()
    if type(UnitFrameUtilsDB) ~= "table" then return nil end
    if type(UnitFrameUtilsDB["COMPANIONNPCIDS"]) ~= "table" then UnitFrameUtilsDB["COMPANIONNPCIDS"] = {} end
    return UnitFrameUtilsDB["COMPANIONNPCIDS"]
end

local function LearnNpcID(unit)
    if not HasCompanionContext() then return end
    local known = GetKnownNpcIDs()
    if known == nil then return end
    local id = GetNpcID(unit)
    if id == nil then return end
    known[tostring(id)] = true
end

local function IsKnownNpcID(unit)
    local known = GetKnownNpcIDs()
    if known == nil then return false end
    if next(known) == nil then return false end
    local id = GetNpcID(unit)
    if id == nil then return false end
    return known[tostring(id)] == true
end

local function IsCompanionUnit(unit)
    if unit == nil then return false end
    if not UnitFrameUtils:UnitExists(unit) then return false end
    if UnitFrameUtils:SafeBool(UnitIsPlayer, unit) == true then return false end
    if UnitFrameUtils:SafeBool(UnitIsUnit, unit, "player") == true then return false end
    if UnitInPartyIsAI and UnitFrameUtils:SafeBool(UnitInPartyIsAI, unit) == true then
        LearnNpcID(unit)
        return true
    end

    if IsKnownNpcID(unit) then return true end
    return MatchesCompanionName(unit)
end

local function GetNameplateUnit(plate)
    if plate == nil then return nil end
    if plate.namePlateUnitToken then return plate.namePlateUnitToken end
    if plate.UnitFrame then return plate.UnitFrame.unit end
    return nil
end

local function FindPartyUnit()
    for i = 1, PARTY_SLOTS do
        local unit = "party" .. i
        if IsCompanionUnit(unit) then return unit end
    end
    return nil
end

local function FindNameplateUnit()
    if C_NamePlate == nil or C_NamePlate.GetNamePlates == nil then return nil end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return nil end
    for _, plate in ipairs(plates) do
        local unit = GetNameplateUnit(plate)
        if IsCompanionUnit(unit) then return unit end
    end
    return nil
end

local function ResolveCompanionUnit()
    if IsCompanionUnit("focus") then return "focus", true end
    local party = FindPartyUnit()
    if party then return party, true end
    local plate = FindNameplateUnit()
    if plate then return plate, false end
    if companionGUID and UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, companionGUID)
        if ok and IsCompanionUnit(unit) then return unit, false end
    end

    for _, unit in ipairs(FALLBACK_UNITS) do
        if IsCompanionUnit(unit) then return unit, false end
    end

    return nil, false
end

local function MemberShowsUnit(member, unit)
    if member == nil then return false end
    if not member:IsShown() then return false end
    local memberUnit = member.displayedUnit or member.unit
    if memberUnit == nil then return false end
    if not UnitFrameUtils:UnitExists(memberUnit) then return false end
    return UnitFrameUtils:SafeBool(UnitIsUnit, memberUnit, unit) == true
end

local function IsShownByBlizzard(unit)
    for i = 1, PARTY_SLOTS do
        if MemberShowsUnit(_G["CompactPartyFrameMember" .. i], unit) then return true end
        if MemberShowsUnit(_G["PartyMemberFrame" .. i], unit) then return true end
        if PartyFrame and MemberShowsUnit(PartyFrame["MemberFrame" .. i], unit) then return true end
    end
    return false
end

local function IsBlockedByBlizzard(unit)
    if UnitFrameUtils:GetOption("SHOWCOMPANIONNOTFULL") == true then return false end

    return IsShownByBlizzard(unit)
end

local function ShouldHideFocusFrame()
    return IsCompanionUnit("focus")
end

local function ApplyFocusFrameHide()
    if not IsRetail() then return end
    if FocusFrame == nil then return end
    if InCombatLockdown() then return end
    if ShouldHideFocusFrame() then
        if focusHider == nil then
            focusHider = CreateFrame("Frame", "UnitFrameUtilsFocusHider", UIParent)
            focusHider:Hide()
        end

        if FocusFrame:GetParent() ~= focusHider then pcall(FocusFrame.SetParent, FocusFrame, focusHider) end
        return
    end

    if focusHider and FocusFrame:GetParent() == focusHider then pcall(FocusFrame.SetParent, FocusFrame, UIParent) end
end

local function GetFocusMacro(unit)
    local name = GetReadableName(unit)
    if name == nil then return nil end
    return "/focus " .. name
end

local function OnEnterFrame(sel)
    if currentUnit == nil then return end
    GameTooltip:SetOwner(sel, "ANCHOR_TOPLEFT")
    if not pcall(GameTooltip.SetUnit, GameTooltip, currentUnit) then return end
    if frameMode == "macro" then
        GameTooltip:AddLine(UnitFrameUtils:Trans("LID_COMPANIONFOCUSCLICK"), 1, 0.82, 0, true)
    elseif frameMode ~= "unit" then
        GameTooltip:AddLine(UnitFrameUtils:Trans("LID_COMPANIONFOCUSHINT"), 1, 0.82, 0, true)
    end

    GameTooltip:Show()
end

local function OnLeaveFrame()
    GameTooltip:Hide()
end

local function HasSavedPosition()
    local pos = UnitFrameUtils:GV(UnitFrameUtilsDB, "COMPANIONPOS", nil)
    return type(pos) == "table" and pos[1] ~= nil
end

local function UpdateMoveHint()
    if frame == nil or frame.moveHint == nil then return end
    if HasSavedPosition() then
        frame.moveHint:Hide()
    else
        frame.moveHint:Show()
    end
end

local function OnDragStart(sel)
    if InCombatLockdown() then
        UnitFrameUtils:MSG(UnitFrameUtils:Trans("LID_CANTBEMOVEDINCOMBAT"))
        return
    end

    UnitFrameUtils:ShowGrid(sel)
    sel:StartMoving()
end

local function OnDragStop(sel)
    UnitFrameUtils:HideGrid(sel)
    sel:StopMovingOrSizing()
    local p1, _, p3, p4, p5 = sel:GetPoint()
    p4 = UnitFrameUtils:Grid(p4)
    p5 = UnitFrameUtils:Grid(p5)
    UnitFrameUtils:SV(UnitFrameUtilsDB, "COMPANIONPOS", {p1, "UIParent", p3, p4, p5})
    sel:ClearAllPoints()
    sel:SetPoint(p1, UIParent, p3, p4, p5)
    UpdateMoveHint()
end

local function CopyBarTexture(src, target)
    if src == nil or target == nil then return end
    local texture = src:GetStatusBarTexture()
    if texture == nil then return end
    local atlas = texture.GetAtlas and texture:GetAtlas()
    if atlas then
        if target.SetStatusBarAtlas then
            target:SetStatusBarAtlas(atlas)
            return
        end

        local own = target:GetStatusBarTexture()
        if own and own.SetAtlas then own:SetAtlas(atlas) end
        return
    end

    local file = texture:GetTexture()
    if file then target:SetStatusBarTexture(file) end
end

local function SyncStyle()
    if frame == nil then return end
    local src = _G[STYLE_SOURCE]
    if src == nil then return end
    if not IsLocked() then
        pcall(function()
            local width, height = src:GetSize()
            if width and width > 0 and height and height > 0 then frame:SetSize(width, height) end
        end)

        pcall(function()
            local bar = src.powerBar
            if bar == nil then return end
            local height = bar:GetHeight()
            if height == nil or height <= 0 then return end
            frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, height)
        end)
    end

    pcall(CopyBarTexture, src.healthBar, frame.health)

    pcall(function()
        local background = src.background
        if background == nil then return end
        local file = background:GetTexture()
        if file then frame.healthBG:SetTexture(file) end
        local r, g, b, a = background:GetVertexColor()
        if r then frame.healthBG:SetVertexColor(r, g, b, a or 1) end
    end)

    pcall(CopyBarTexture, src.powerBar, frame.power)
end

local function CreateAura(parent, name)
    local aura = CreateFrame("Frame", name, parent)
    aura:SetSize(AURA_SIZE, AURA_SIZE)
    aura.border = aura:CreateTexture(name .. ".Border", "BACKGROUND")
    aura.border:SetPoint("TOPLEFT", aura, "TOPLEFT", -1, 1)
    aura.border:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", 1, -1)
    aura.border:SetColorTexture(0, 0, 0, 1)
    aura.icon = aura:CreateTexture(name .. ".Icon", "ARTWORK")
    aura.icon:SetAllPoints(aura)
    aura.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if UnitFrameUtils:CheckTemplates("CooldownFrameTemplate") then
        aura.cd = CreateFrame("Cooldown", name .. ".CD", aura, "CooldownFrameTemplate")
        aura.cd:SetAllPoints(aura)
        aura.cd:SetDrawEdge(false)
        aura.cd:SetHideCountdownNumbers(true)
        aura.cd:SetReverse(true)
    end

    aura.count = aura:CreateFontString(name .. ".Count", "OVERLAY", "GameFontHighlightSmall")
    aura.count:SetPoint("BOTTOMRIGHT", aura, "BOTTOMRIGHT", 2, -1)
    UnitFrameUtils:SetFontSize(aura.count, 9, "OUTLINE")
    aura:SetAlpha(0)
    return aura
end

local function CreateAuraRow(parent, prefix, count, point, dir)
    local row = {}
    for i = 1, count do
        local aura = CreateAura(parent, FRAME_NAME .. "." .. prefix .. i)
        local offset = AURA_INSET + (i - 1) * (AURA_SIZE + AURA_GAP)
        aura:SetPoint(point, parent, point, dir * offset, AURA_INSET)
        row[i] = aura
    end
    return row
end

local function CreateSecureButton()
    local ok, button = pcall(CreateFrame, "Button", FRAME_NAME, UIParent, "SecureUnitButtonTemplate")
    if ok and button then
        frameIsSecure = true
        return button
    end

    frameIsSecure = false
    return CreateFrame("Button", FRAME_NAME, UIParent)
end

local function CreateCompanionFrame()
    if frame then return frame end
    frame = CreateSecureButton()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("AnyUp", "AnyDown")
    UnitFrameUtils:SetClampedToScreen(frame, true)
    frame:SetScript("OnDragStart", OnDragStart)
    frame:SetScript("OnDragStop", OnDragStop)
    frame:HookScript("OnEnter", OnEnterFrame)
    frame:HookScript("OnLeave", OnLeaveFrame)
    frame.selection = frame:CreateTexture(FRAME_NAME .. ".Selection", "BACKGROUND", nil, -1)
    frame.selection:SetPoint("TOPLEFT", frame, "TOPLEFT", -SELECTION_SIZE, SELECTION_SIZE)
    frame.selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", SELECTION_SIZE, -SELECTION_SIZE)
    frame.selection:SetColorTexture(1, 1, 1, 1)
    frame.selection:Hide()
    frame.border = frame:CreateTexture(FRAME_NAME .. ".Border", "BACKGROUND")
    frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    frame.border:SetColorTexture(0, 0, 0, 1)
    frame.bg = frame:CreateTexture(FRAME_NAME .. ".BG", "BACKGROUND", nil, 1)
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(0, 0, 0, 0.6)
    frame.health = CreateFrame("StatusBar", FRAME_NAME .. ".Health", frame)
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, POWER_HEIGHT)
    frame.health:SetStatusBarTexture(BAR_TEXTURE)
    frame.health:SetMinMaxValues(0, 1)
    frame.health:SetValue(1)
    frame.healthBG = frame.health:CreateTexture(FRAME_NAME .. ".HealthBG", "BACKGROUND")
    frame.healthBG:SetAllPoints(frame.health)
    frame.healthBG:SetColorTexture(0.12, 0.12, 0.12, 0.9)
    frame.power = CreateFrame("StatusBar", FRAME_NAME .. ".Power", frame)
    frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.power:SetPoint("TOP", frame.health, "BOTTOM", 0, 0)
    frame.power:SetStatusBarTexture(BAR_TEXTURE)
    frame.power:SetMinMaxValues(0, 1)
    frame.power:SetValue(0)
    frame.powerBG = frame.power:CreateTexture(FRAME_NAME .. ".PowerBG", "BACKGROUND")
    frame.powerBG:SetAllPoints(frame.power)
    frame.powerBG:SetColorTexture(0.12, 0.12, 0.12, 0.9)
    frame.role = frame.health:CreateTexture(FRAME_NAME .. ".Role", "OVERLAY")
    frame.role:SetSize(ROLE_SIZE, ROLE_SIZE)
    frame.role:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 2, -2)
    frame.role:Hide()
    frame.name = frame.health:CreateFontString(FRAME_NAME .. ".Name", "OVERLAY", "GameFontHighlightSmall")
    frame.name:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 3, -2)
    frame.name:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT", -3, -2)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetWordWrap(false)
    UnitFrameUtils:SetFontSize(frame.name, 10, "")
    frame.name:SetShadowColor(0, 0, 0, 1)
    frame.name:SetShadowOffset(1, -1)
    frame.hp = frame.health:CreateFontString(FRAME_NAME .. ".HP", "OVERLAY", "GameFontHighlightLarge")
    frame.hp:SetPoint("CENTER", frame.health, "CENTER", 0, -2)
    frame.hp:SetJustifyH("CENTER")
    UnitFrameUtils:SetFontSize(frame.hp, HP_FONT_SIZE, "")
    frame.hp:SetShadowColor(0, 0, 0, 1)
    frame.hp:SetShadowOffset(1, -1)
    frame.hint = frame.health:CreateFontString(FRAME_NAME .. ".Hint", "OVERLAY", "GameFontNormalSmall")
    frame.hint:SetPoint("LEFT", frame.health, "LEFT", 3, -2)
    frame.hint:SetPoint("RIGHT", frame.health, "RIGHT", -3, -2)
    frame.hint:SetJustifyH("CENTER")
    frame.hint:SetWordWrap(true)
    UnitFrameUtils:SetFontSize(frame.hint, 10, "")
    frame.hint:SetTextColor(1, 0.82, 0)
    frame.hint:SetShadowColor(0, 0, 0, 1)
    frame.hint:SetShadowOffset(1, -1)
    frame.hint:Hide()
    frame.moveHint = frame:CreateFontString(FRAME_NAME .. ".MoveHint", "OVERLAY", "GameFontNormalSmall")
    frame.moveHint:SetPoint("BOTTOM", frame, "TOP", 0, 4)
    frame.moveHint:SetJustifyH("CENTER")
    UnitFrameUtils:SetFontSize(frame.moveHint, 10, "")
    frame.moveHint:SetTextColor(1, 0.82, 0)
    frame.moveHint:SetShadowColor(0, 0, 0, 1)
    frame.moveHint:SetShadowOffset(1, -1)
    frame.moveHint:SetText(UnitFrameUtils:Trans("LID_COMPANIONDRAGHINT"))
    frame.moveHint:Hide()
    frame.buffs = CreateAuraRow(frame.health, "Buff", MAX_BUFFS, "BOTTOMRIGHT", -1)
    frame.debuffs = CreateAuraRow(frame.health, "Debuff", MAX_DEBUFFS, "BOTTOMLEFT", 1)
    frame:SetScale(frameScale)
    SyncStyle()
    local pos = UnitFrameUtils:GV(UnitFrameUtilsDB, "COMPANIONPOS", nil)
    if type(pos) == "table" and pos[1] then
        frame:ClearAllPoints()
        frame:SetPoint(pos[1], UIParent, pos[3], pos[4], pos[5])
    end

    UpdateMoveHint()
    frame:Hide()
    return frame
end

local function ClearSecure()
    frame:SetAttribute("unit", nil)
    frame:SetAttribute("type1", nil)
    frame:SetAttribute("type2", nil)
    frame:SetAttribute("type3", nil)
    frame:SetAttribute("*type1", nil)
    frame:SetAttribute("*type2", nil)
    frame:SetAttribute("*type3", nil)
    frame:SetAttribute("shift-type1", nil)
    frame:SetAttribute("macrotext", nil)
end

local function ApplySecure(unit, secure)
    if frame == nil then return end
    if frame.SetAttribute == nil then return end
    local mode = "none"
    local macro = nil
    if unit and secure == true then
        mode = "unit"
    elseif unit then
        macro = GetFocusMacro(unit)
        if macro then mode = "macro" end
    end

    frameMode = mode
    local key = mode .. "|" .. tostring(unit) .. "|" .. tostring(macro)
    if currentKey == key then return end
    if InCombatLockdown() then
        pendingSecure = true
        return
    end

    pendingSecure = false
    currentKey = key
    frame:SetAttribute("useparent-unit", false)
    ClearSecure()
    if mode == "unit" then
        frame:SetAttribute("unit", unit)
        frame:SetAttribute("type1", "target")
        frame:SetAttribute("*type1", "target")
        frame:SetAttribute("type2", "togglemenu")
        frame:SetAttribute("*type2", "togglemenu")
        frame:SetAttribute("type3", "focus")
        frame:SetAttribute("*type3", "focus")
        frame:SetAttribute("shift-type1", "focus")
        frame:SetAttribute("toggleForVehicle", true)
        frame:SetAttribute("allowVehicleTarget", true)
        return
    end

    if mode == "macro" then
        frame:SetAttribute("type1", "macro")
        frame:SetAttribute("*type1", "macro")
        frame:SetAttribute("macrotext", macro)
    end
end

local function IsTrusted()
    if frameIsSecure ~= true then return true end
    return pendingSecure ~= true
end

local function SetShown(shown)
    if frame == nil then return end
    if frame:IsShown() == shown then return end
    if IsLocked() then return end
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function ApplyTrust()
    if frame == nil then return end
    local trusted = IsTrusted()
    if not IsLocked() then frame:EnableMouse(trusted) end
    if trusted then
        frame:SetAlpha(1)
    else
        frame:SetAlpha(STALE_ALPHA)
    end
end

local function GetUnitColor(unit)
    local ok, r, g, b = pcall(function()
        local _, class = UnitClass(unit)
        if class == nil then return nil end
        local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        if colors == nil then return nil end
        local color = colors[class]
        if color == nil then return nil end
        return color.r, color.g, color.b
    end)

    if ok and r then return r, g, b end
    if UnitSelectionColor then
        local okSel, sr, sg, sb = pcall(UnitSelectionColor, unit)
        if okSel and sr then return sr, sg, sb end
    end
    return 0.2, 0.8, 0.2
end

local function GetHealthPercentText(hp, maxHP)
    local ok, text = pcall(function()
        if maxHP == nil or maxHP <= 0 then return "" end
        return floor(hp / maxHP * 100) .. "%"
    end)

    if ok and type(text) == "string" then return text end
    return ""
end

local function UpdateHealth(unit)
    local maxHP = UnitHealthMax(unit) or 0
    local hp = UnitHealth(unit) or 0
    frame.health:SetMinMaxValues(0, maxHP)
    frame.health:SetValue(hp)
    local dead = false
    local okDead, isDead = pcall(UnitIsDeadOrGhost, unit)
    if okDead then dead = isDead == true end
    if dead then
        frame.health:SetStatusBarColor(0.4, 0.4, 0.4, 1)
        frame.hp:SetText(DEAD or "")
        return
    end

    local r, g, b = GetUnitColor(unit)
    frame.health:SetStatusBarColor(r, g, b, 1)
    frame.hp:SetText(GetHealthPercentText(hp, maxHP))
end

local function HasPower(maxPower)
    local ok, empty = pcall(function() return maxPower <= 0 end)
    if not ok then return true end
    return empty ~= true
end

local function GetPowerColor(unit)
    local ok, r, g, b = pcall(function()
        if PowerBarColor == nil then return nil end
        local powerType, powerToken = UnitPowerType(unit)
        local color = PowerBarColor[powerToken] or PowerBarColor[powerType]
        if color == nil then return nil end
        return color.r, color.g, color.b
    end)

    if ok and r then return r, g, b end
    return 0.2, 0.4, 0.9
end

local function UpdatePower(unit)
    local maxPower = UnitPowerMax(unit) or 0
    if not HasPower(maxPower) then
        SetVisible(frame.power, false)
        return
    end

    local r, g, b = GetPowerColor(unit)
    frame.power:SetStatusBarColor(r, g, b, 1)
    frame.power:SetMinMaxValues(0, maxPower)
    frame.power:SetValue(UnitPower(unit) or 0)
    SetVisible(frame.power, true)
end

local function QueryRole(unit)
    if UnitGroupRolesAssigned == nil then return nil end
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if not ok then return nil end
    if UnitFrameUtils:IsSecret(role) then return nil end
    if role == nil or role == "NONE" then return nil end
    return role
end

local function GetUnitRole(unit)
    local role = QueryRole(unit)
    if role then return role end
    for i = 1, PARTY_SLOTS do
        local partyUnit = "party" .. i
        if UnitFrameUtils:UnitExists(partyUnit) and UnitFrameUtils:SafeBool(UnitIsUnit, partyUnit, unit) == true then
            role = QueryRole(partyUnit)
            if role then return role end
        end
    end
    return nil
end

local function AnchorName(withRole)
    frame.name:ClearAllPoints()
    if withRole then
        frame.name:SetPoint("TOPLEFT", frame.role, "TOPRIGHT", 3, 0)
    else
        frame.name:SetPoint("TOPLEFT", frame.health, "TOPLEFT", 3, -2)
    end

    frame.name:SetPoint("TOPRIGHT", frame.health, "TOPRIGHT", -3, -2)
end

local function ApplyRoleTexture(role)
    local atlas = ROLE_ATLAS[role]
    if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        frame.role:SetTexCoord(0, 1, 0, 1)
        frame.role:SetAtlas(atlas)

        return true
    end

    local coords = ROLE_COORDS[role]
    if coords == nil then return false end
    frame.role:SetTexture(ROLE_TEXTURE)
    frame.role:SetTexCoord(coords[1], coords[2], coords[3], coords[4])

    return true
end

local function UpdateRole(unit)
    if not ApplyRoleTexture(GetUnitRole(unit) or "NONE") then
        frame.role:Hide()
        AnchorName(false)

        return
    end

    frame.role:Show()
    AnchorName(true)
end

local function UpdateHint()
    if frameMode == "macro" then
        frame.hint:SetText(UnitFrameUtils:Trans("LID_COMPANIONFOCUSCLICK"))
        frame.hint:Show()
        frame.hp:Hide()
        return
    end

    frame.hint:Hide()
    frame.hp:Show()
end

local function UpdateSelection(unit)
    local ok, isTarget = pcall(UnitIsUnit, unit, "target")
    if ok and isTarget == true then
        frame.selection:Show()
    else
        frame.selection:Hide()
    end
end

local function UpdateAggro(unit)
    local status = nil
    if UnitThreatSituation then status = UnitThreatSituation(unit) end
    if status and status > 0 and GetThreatStatusColor then
        local r, g, b = GetThreatStatusColor(status)
        frame.border:SetColorTexture(r, g, b, 1)
    else
        frame.border:SetColorTexture(0, 0, 0, 1)
    end
end

local function ShouldShowBuff(aura)
    return AuraUtil.ShouldDisplayBuff(aura.sourceUnit, aura.spellId, aura.canApplyAura)
end

local function ShouldShowDebuff(data)
    return data.isBossAura == true or data.isRaid == true
end

local function UpdateAuraRow(row, unit, filter, maxCount, accept)
    local shown = 0
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, MAX_AURA_INDEX do
            if shown >= maxCount then break end
            local data = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
            if data == nil then break end
            if data.icon and accept(data) then
                shown = shown + 1
                local aura = row[shown]
                aura.icon:SetTexture(data.icon)
                local count = data.applications or 0
                if count > 1 then
                    aura.count:SetText(count)
                else
                    aura.count:SetText("")
                end

                if aura.cd then
                    if data.duration and data.duration > 0 and data.expirationTime and data.expirationTime > 0 then
                        aura.cd:SetCooldown(data.expirationTime - data.duration, data.duration)
                    else
                        aura.cd:SetCooldown(0, 0)
                    end
                end

                local r, g, b = 0, 0, 0
                if filter == DEBUFF_FILTER and DebuffTypeColor then
                    local color = DebuffTypeColor[data.dispelName or "none"]
                    if color then r, g, b = color.r, color.g, color.b end
                end

                aura.border:SetColorTexture(r, g, b, 1)
                SetVisible(aura, true)
            end
        end
    end

    for i = shown + 1, #row do
        SetVisible(row[i], false)
    end
end

local function UpdateName(unit)
    frame.name:SetText(GetReadableName(unit) or "")
end

function UpdateVisuals(unit)
    if frame == nil then return end
    if unit == nil or not UnitFrameUtils:UnitExists(unit) then return end
    pcall(UpdateName, unit)
    pcall(UpdateRole, unit)
    pcall(UpdateHealth, unit)
    pcall(UpdateHint)
    pcall(UpdatePower, unit)
    pcall(UpdateSelection, unit)
    pcall(UpdateAggro, unit)
    pcall(UpdateAuraRow, frame.buffs, unit, BUFF_FILTER, MAX_BUFFS, ShouldShowBuff)
    pcall(UpdateAuraRow, frame.debuffs, unit, DEBUFF_FILTER, MAX_DEBUFFS, ShouldShowDebuff)
end

function UnitFrameUtils:UpdateCompanion()
    if not IsRetail() then return end
    if frame == nil then return end
    local unit, secure = nil, false
    if HasCompanionContext() then unit, secure = ResolveCompanionUnit() end
    if unit then companionGUID = UnitGUID(unit) end
    if unit == nil or UnitFrameUtils:GetOption("SHOWCOMPANION") ~= true or IsBlockedByBlizzard(unit) then
        currentUnit = nil
        ApplySecure(nil, false)
        SetShown(false)
        return
    end

    currentUnit = unit
    ApplySecure(unit, secure)
    ApplyTrust()
    UpdateVisuals(unit)
    SetShown(true)
end

function UnitFrameUtils:SetCompanionScale(value)
    frameScale = value or DEFAULT_SCALE
    if frame == nil then return end
    if IsLocked() then return end
    frame:SetScale(frameScale)
end

function UnitFrameUtils:ResetCompanionPosition()
    UnitFrameUtils:SV(UnitFrameUtilsDB, "COMPANIONPOS", nil)
    if frame == nil then return end
    if IsLocked() then
        UnitFrameUtils:MSG(UnitFrameUtils:Trans("LID_CANTBEMOVEDINCOMBAT"))
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    UpdateMoveHint()
end

function UnitFrameUtils:ApplyCompanionOptions()
    ApplyFocusFrameHide()
end

local function Refresh()
    UnitFrameUtils:After(0.1, function() UnitFrameUtils:UpdateCompanion() end, "UnitFrameUtils:UpdateCompanion")
end

local eventFrame = CreateFrame("Frame", "UnitFrameUtilsCompanionEvents")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_LOGIN")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
UnitFrameUtils:RegisterEvent(eventFrame, "GROUP_ROSTER_UPDATE")
UnitFrameUtils:RegisterEvent(eventFrame, "NAME_PLATE_UNIT_ADDED")
UnitFrameUtils:RegisterEvent(eventFrame, "NAME_PLATE_UNIT_REMOVED")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_TARGET_CHANGED")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_FOCUS_CHANGED")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
UnitFrameUtils:RegisterEvent(eventFrame, "PLAYER_REGEN_DISABLED")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_HEALTH")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_MAXHEALTH")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_POWER_UPDATE")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_MAXPOWER")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_AURA")
UnitFrameUtils:RegisterEvent(eventFrame, "UNIT_THREAT_SITUATION_UPDATE")
eventFrame:SetScript("OnEvent", function(sel, event, arg1)
    if event == "PLAYER_LOGIN" then
        if not IsRetail() then return end
        UnitFrameUtilsDB = UnitFrameUtilsDB or {}
        CreateCompanionFrame()
        if ticker == nil then ticker = C_Timer.NewTicker(1, function() if HasCompanionContext() then Refresh() end end) end
        Refresh()
        return
    end

    if not IsRetail() then return end
    if event == "PLAYER_REGEN_ENABLED" then
        UnitFrameUtils:ApplyCompanionOptions()
        Refresh()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        UnitFrameUtils:ApplyCompanionOptions()
        SyncStyle()
        Refresh()
        return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
        ApplyFocusFrameHide()
        Refresh()
        return
    end

    if strsub(event, 1, 5) == "UNIT_" then
        if currentUnit == nil then return end
        if arg1 ~= currentUnit then return end
        UpdateVisuals(currentUnit)
        return
    end

    Refresh()
end)
