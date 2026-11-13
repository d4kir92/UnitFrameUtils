local _, UnitFrameUtils = ...
if not UnitFrameUtils:IsForever() then return end
local HOT = {
    ["UPDATE"] = 0.1,
    ["INTERVAL"] = 3,
    ["WINDOW"] = 0.45,
    ["SENT_TTL"] = 5,
    ["SENT_QUEUE"] = 8,
    ["VALIDATE_DELAY"] = 1,
    ["MISSING_GRACE"] = 0.6,
    ["VERIFY_WINDOW"] = 1.5,
    ["FRESH_TOLERANCE"] = 0.4,
    ["AURA_RECENT"] = 0.5,
    ["INSTANT_WINDOW"] = 0.3,
    ["INSTANT_DECAY"] = 0.85,
    ["INSTANT_MIN_CASTS"] = 1.8,
    ["INSTANT_RATIO"] = 0.75,
    ["MIN_RATIO"] = 0.85,
    ["MAX_RATIO"] = 3,
    ["SPAN_TEXTURE"] = "Interface\\Buttons\\WHITE8X8",
    ["DEBUG_COLOR"] = {0.2, 0.5, 1},
    ["UNIT_SEGMENTS"] = {"MyHealPredictionBar", "OtherHealPredictionBar"},
    ["TEXTURE_SEGMENTS"] = {"myHealPrediction", "otherHealPrediction"},
    ["PRD_TEXTURE"] = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
    ["PRD_COLOR"] = {0, 0.659, 0.608},
    ["RAID_COLOR"] = {11 / 255, 136 / 255, 105 / 255, 1},
    ["REPORT_DELAY"] = 1,
    ["report"] = false,
    ["LOCALES"] = {
        ["enUS"] = {
            ["heal"] = {"^Heals"},
            ["duration"] = {"(%d+%.?%d*) sec"},
            ["interval"] = "every (%d+%.?%d*) sec"
        },
        ["deDE"] = {
            ["heal"] = {"^Heilt"},
            ["duration"] = {"(%d+[,%.]?%d*) Sek"},
            ["amountAfter"] = true
        },
        ["frFR"] = {
            ["heal"] = {"^Rend %d+ points de vie", "^Soigne"},
            ["duration"] = {"(%d+) sec"}
        },
        ["esES"] = {
            ["heal"] = {"^Cura", "^Sana"},
            ["duration"] = {"(%d+) s%.", "(%d+) seg"}
        },
        ["esMX"] = {
            ["heal"] = {"^Cura", "^Sana"},
            ["duration"] = {"(%d+) s%.", "(%d+) seg"}
        },
        ["ptBR"] = {
            ["heal"] = {"^Cura"},
            ["duration"] = {"(%d+) s%.", "(%d+) seg"}
        },
        ["ruRU"] = {
            ["heal"] = {"^Излечение", "^Исцеление"},
            ["duration"] = {"(%d+) сек"}
        },
        ["koKR"] = {
            ["heal"] = {"생명력"},
            ["duration"] = {"(%d+)초"},
            ["amountAfter"] = true
        },
        ["zhCN"] = {
            ["heal"] = {"^治疗"},
            ["duration"] = {"(%d+)秒"},
            ["amountAfter"] = true
        },
        ["zhTW"] = {
            ["heal"] = {"^治療"},
            ["duration"] = {"(%d+)秒"},
            ["amountAfter"] = true
        }
    }
}

local sentTargets = {}
local sentQueue = {}
local hotsByKey = {}
local pendingChecks = {}
local recentAuraUnits = {}
local recentHeals = {}
local instantStats = {}
local learnedTicks = {}
local displays = {}
local combatSeen = {}
local combatSeenAt = nil
local debugMode = false
local colorDebug = false
local hotColor = {11 / 255, 136 / 255, 105 / 255, 1}
local candidates = {"mouseover", "target", "player", "focus"}
for i = 1, 4 do
    tinsert(candidates, "party" .. i)
end

for i = 1, 40 do
    tinsert(candidates, "raid" .. i)
end

local function IsSecret(value)
    return UnitFrameUtils:IsSecret(value)
end

local function Debug(msg)
    if debugMode then UnitFrameUtils:MSG("|cff55ff99HoT|r " .. msg) end
end

function HOT.Report(msg)
    if HOT.report then UnitFrameUtils:MSG("|cffff4040HoT error|r " .. msg) end
end

local function SafeString(value)
    if value == nil or IsSecret(value) or type(value) ~= "string" or value == "" then return nil end

    return value
end

local function SafeNumber(value)
    if value == nil or IsSecret(value) or type(value) ~= "number" then return nil end

    return value
end

local function UnitKey(unit)
    if unit == nil then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if ok and SafeString(guid) then return guid end
    local okName, name = pcall(UnitName, unit)
    if okName and SafeString(name) then return "name:" .. name end

    return nil
end

local function GetUnitNames(unit)
    local names = {}
    local okName, name = pcall(UnitName, unit)
    if okName and SafeString(name) then tinsert(names, name) end
    if GetUnitName then
        local okShort, short = pcall(GetUnitName, unit, false)
        if okShort and SafeString(short) then tinsert(names, short) end
        local okFull, full = pcall(GetUnitName, unit, true)
        if okFull and SafeString(full) then tinsert(names, full) end
    end

    return names
end

local function NameMatches(unit, name, loose)
    local lowerName = string.lower(name)
    local shortName = string.lower(string.match(name, "^[^%-]+") or name)
    for _, unitName in ipairs(GetUnitNames(unit)) do
        local lowerUnit = string.lower(unitName)
        if loose then
            if string.sub(lowerName, 1, #lowerUnit + 1) == lowerUnit .. " " then return true end
        elseif lowerUnit == lowerName or lowerUnit == shortName then
            return true
        end
    end

    return false
end

local function FindUnitByName(name)
    for pass = 1, 2 do
        for _, unit in ipairs(candidates) do
            if UnitFrameUtils:UnitExists(unit) and NameMatches(unit, name, pass == 2) then return unit end
        end
    end

    return nil
end

local function CanAssist(unit)
    return UnitFrameUtils:UnitExists(unit) and UnitFrameUtils:SafeBool(UnitCanAssist, "player", unit) == true
end

local function GuessTargetKey()
    if CanAssist("mouseover") then return UnitKey("mouseover") end
    if CanAssist("target") then return UnitKey("target") end

    return UnitKey("player")
end

local function ResolveTargetKey(targetName)
    local name = SafeString(targetName)
    if name then
        local unit = FindUnitByName(name)
        if unit then return UnitKey(unit) end
        if debugMode then UnitFrameUtils:MSG("|cff55ff99HoT|r name not matched: " .. name .. " | player names: " .. table.concat(GetUnitNames("player"), ", ")) end
        HOT.Report("target name not found: " .. name .. " (guessing mouseover/target/player)")
    end

    return GuessTargetKey()
end

local function GetSpellNameAndDescription(spellID)
    local name, desc
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        name = GetSpellInfo(spellID)
    end

    local descFunc = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if descFunc then desc = descFunc(spellID) end

    return SafeString(name), SafeString(desc)
end

local function StripThousands(text)
    local result = text
    for _ = 1, 3 do
        result = string.gsub(result, "(%d)[%.,\194\160 ](%d%d%d)%f[%D]", "%1%2")
    end

    return result
end

local function HasMarker(desc, rules)
    for _, marker in ipairs(rules.heal) do
        if string.find(desc, marker) then return true end
    end

    return false
end

local function ParseHotWith(desc, rules)
    if not HasMarker(desc, rules) then return nil end
    local text = StripThousands(desc)
    local found, foundEnd, secs = nil, nil, nil
    for _, pattern in ipairs(rules.duration) do
        local s, e, value = string.find(text, pattern)
        if s and (found == nil or s > found) then found, foundEnd, secs = s, e, value end
    end

    if found == nil then return nil end
    local amount = nil
    if rules.amountAfter then
        amount = string.match(string.sub(text, foundEnd + 1), "(%d+)")
    else
        for value in string.gmatch(string.sub(text, 1, found - 1), "(%d+)") do
            amount = value
        end
    end

    local total = tonumber(amount)
    local secsText = string.gsub(secs, ",", ".")
    local duration = tonumber(secsText)
    if total == nil or duration == nil or total <= 0 or duration <= 0 then return nil end
    local interval = rules.interval and tonumber(string.match(text, rules.interval)) or HOT.INTERVAL
    if interval == nil or interval <= 0 then interval = HOT.INTERVAL end

    return total, duration, interval
end

local function ParseHot(desc)
    if desc == nil then return nil end
    local rules = HOT.LOCALES[GetLocale and GetLocale() or "enUS"]
    if rules then
        local total, duration, interval = ParseHotWith(desc, rules)
        if total then return total, duration, interval end
    end

    return ParseHotWith(desc, HOT.LOCALES.enUS)
end

local function NewHot(spellID, name, total, duration, interval, now)
    local ticks = math.max(1, math.floor(duration / interval + 0.5))

    return {
        ["spellID"] = spellID,
        ["name"] = name,
        ["baseTick"] = total / ticks,
        ["totalTicks"] = ticks,
        ["interval"] = interval,
        ["appliedAt"] = now,
        ["anchor"] = now,
        ["expiresAt"] = now + ticks * interval,
        ["nextTickAt"] = now + interval,
        ["lastTickIndex"] = 0,
        ["tickSum"] = 0,
        ["tickCount"] = 0
    }
end

local function ExpectedTick(hot)
    if hot.tickCount > 0 then return hot.tickSum / hot.tickCount end

    return learnedTicks[hot.spellID] or hot.baseTick
end

local function RemainingHeal(hot)
    if hot.nextTickAt > hot.expiresAt + hot.interval / 2 then return 0 end
    local left = math.floor((hot.expiresAt - hot.nextTickAt) / hot.interval + 0.5) + 1
    left = math.max(0, math.min(left, hot.totalTicks))

    return left * ExpectedTick(hot)
end

local function IsPlausibleTick(hot, amount)
    if amount == nil then return true end
    if amount < hot.baseTick * HOT.MIN_RATIO then return false end

    return amount <= ExpectedTick(hot) * HOT.MAX_RATIO
end

function HOT.IsLearnedInstant(name)
    local stats = instantStats[name]

    return stats ~= nil and stats.casts >= HOT.INSTANT_MIN_CASTS and stats.hits / stats.casts >= HOT.INSTANT_RATIO
end

function HOT.RecordInstant(hot, hit)
    if hot.instantRecorded then return end
    hot.instantRecorded = true
    local stats = instantStats[hot.name]
    if stats == nil then
        stats = {
            ["casts"] = 0,
            ["hits"] = 0
        }

        instantStats[hot.name] = stats
    end

    stats.casts = stats.casts * HOT.INSTANT_DECAY + 1
    stats.hits = stats.hits * HOT.INSTANT_DECAY + (hit and 1 or 0)
end

local function Housekeep(now)
    for guid, sent in pairs(sentTargets) do
        if now - sent.at > HOT.SENT_TTL then sentTargets[guid] = nil end
    end

    while sentQueue[1] and now - sentQueue[1].at > HOT.SENT_TTL do
        tremove(sentQueue, 1)
    end

    for i = #pendingChecks, 1, -1 do
        if now - pendingChecks[i].at > HOT.VERIFY_WINDOW then tremove(pendingChecks, i) end
    end

    for key, heal in pairs(recentHeals) do
        if now - heal.at > HOT.VERIFY_WINDOW then recentHeals[key] = nil end
    end

    for unit, at in pairs(recentAuraUnits) do
        if now - at > HOT.AURA_RECENT then recentAuraUnits[unit] = nil end
    end

    for key, hots in pairs(hotsByKey) do
        for name, hot in pairs(hots) do
            if not hot.instantRecorded and now - hot.appliedAt > HOT.INSTANT_WINDOW + HOT.UPDATE then HOT.RecordInstant(hot, false) end
            while hot.nextTickAt < now - HOT.WINDOW and hot.nextTickAt <= hot.expiresAt do
                hot.nextTickAt = hot.nextTickAt + hot.interval
            end

            if now > hot.expiresAt + HOT.WINDOW then
                hots[name] = nil
                Debug("expired " .. name)
            end
        end

        if next(hots) == nil then hotsByKey[key] = nil end
    end
end

local function Describe(value)
    if IsSecret(value) then return "<secret>" end

    return tostring(value)
end

local function OnCastSent(targetName, castGUID, spellID)
    local entry = {
        ["key"] = ResolveTargetKey(targetName),
        ["spellID"] = SafeNumber(spellID),
        ["at"] = GetTime()
    }

    tinsert(sentQueue, entry)
    while #sentQueue > HOT.SENT_QUEUE do
        tremove(sentQueue, 1)
    end

    if castGUID and not IsSecret(castGUID) then
        entry.guid = castGUID
        sentTargets[castGUID] = entry
    end
    if debugMode then Debug("sent " .. Describe(spellID) .. " target=" .. Describe(targetName) .. " guid=" .. Describe(castGUID) .. " key=" .. tostring(entry.key)) end
end

local function TakeQueuedSent(spellID, now)
    for i = #sentQueue, 1, -1 do
        local entry = sentQueue[i]
        if now - entry.at <= HOT.SENT_TTL and (entry.spellID == nil or entry.spellID == spellID) then
            tremove(sentQueue, i)

            return entry
        end
    end

    return nil
end

local function DropSent(castGUID)
    if castGUID == nil or IsSecret(castGUID) then return end
    local entry = sentTargets[castGUID]
    sentTargets[castGUID] = nil
    for i = #sentQueue, 1, -1 do
        if sentQueue[i] == entry or sentQueue[i].guid == castGUID then tremove(sentQueue, i) end
    end
end

local function ShiftToInstant(hot, amount)
    if hot.instant then return end
    hot.instant = true
    hot.anchor = hot.appliedAt - hot.interval
    hot.expiresAt = hot.anchor + hot.totalTicks * hot.interval
    hot.lastTickIndex = math.max(hot.lastTickIndex, 1)
    hot.nextTickAt = hot.anchor + (hot.lastTickIndex + 1) * hot.interval
    if amount then
        hot.tickSum = hot.tickSum + amount
        hot.tickCount = hot.tickCount + 1
        learnedTicks[hot.spellID] = hot.tickSum / hot.tickCount
    end

    Debug(string.format("instant tick %s %s", hot.name, tostring(amount)))
end

local function MatchesInstantHeal(hot, heal)
    return heal ~= nil and heal.amount ~= nil and math.abs(heal.at - hot.appliedAt) <= HOT.INSTANT_WINDOW and IsPlausibleTick(hot, heal.amount)
end

local function ObserveInstant(hot, heal)
    HOT.RecordInstant(hot, true)
    local amount = nil
    if not heal.crit then amount = heal.amount end
    if not hot.instant then
        if HOT.IsLearnedInstant(hot.name) then ShiftToInstant(hot, amount) end
    elseif amount then
        hot.tickSum = hot.tickSum + amount
        hot.tickCount = hot.tickCount + 1
        learnedTicks[hot.spellID] = hot.tickSum / hot.tickCount
    end
end

local function ApplyKnownInstant(key, hot)
    local heal = recentHeals[key]
    if not hot.instantRecorded and MatchesInstantHeal(hot, heal) then
        recentHeals[key] = nil
        ObserveInstant(hot, heal)
    elseif not hot.instant and HOT.IsLearnedInstant(hot.name) then
        ShiftToInstant(hot, nil)
    end
end

local function AuraAppliedOffset(unit, hot)
    if C_UnitAuras == nil or C_UnitAuras.GetAuraDataBySpellName == nil then return nil end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, hot.name, "HELPFUL|PLAYER")
    if not ok or IsSecret(aura) or type(aura) ~= "table" then return nil end
    local expires, duration = SafeNumber(aura.expirationTime), SafeNumber(aura.duration)
    if expires == nil or duration == nil or duration <= 0 then return nil end
    local offset = math.abs(expires - duration - hot.appliedAt)
    if offset > HOT.FRESH_TOLERANCE then return nil end

    return offset
end

local function Rehome(check, unit)
    local newKey = UnitKey(unit)
    if newKey == nil or newKey == check.key then return end
    local hot = check.hot
    local old = hotsByKey[check.key]
    if old and old[hot.name] == hot then
        old[hot.name] = nil
        if next(old) == nil then hotsByKey[check.key] = nil end
    end

    hotsByKey[newKey] = hotsByKey[newKey] or {}
    hotsByKey[newKey][hot.name] = hot
    Debug("moved " .. hot.name .. " from " .. tostring(check.key) .. " to " .. newKey .. " (" .. unit .. ")")
    check.key = newKey
    if not hot.instantRecorded then ApplyKnownInstant(newKey, hot) end
end

local function VerifyRecipient(unit, now)
    local bestIndex, bestOffset = nil, nil
    for i = #pendingChecks, 1, -1 do
        local check = pendingChecks[i]
        if now - check.at <= HOT.VERIFY_WINDOW then
            local offset = AuraAppliedOffset(unit, check.hot)
            if offset and (bestOffset == nil or offset < bestOffset) then bestIndex, bestOffset = i, offset end
        end
    end

    if bestIndex == nil then return end
    local check = tremove(pendingChecks, bestIndex)
    Rehome(check, unit)
end

local function IsTrackedAuraUnit(unit)
    if type(unit) ~= "string" or IsSecret(unit) then return false end
    if unit == "player" or unit == "target" or unit == "focus" or unit == "mouseover" then return true end

    return string.find(unit, "^party%d$") ~= nil or string.find(unit, "^raid%d+$") ~= nil
end

local function OnUnitAura(unit)
    if not IsTrackedAuraUnit(unit) then return end
    local now = GetTime()
    recentAuraUnits[unit] = now
    if pendingChecks[1] then VerifyRecipient(unit, now) end
end

local function OnCastSucceeded(castGUID, spellID)
    if spellID == nil or IsSecret(spellID) then
        Debug("cast: spellID " .. Describe(spellID))
        HOT.Report("cast with unreadable spellID " .. Describe(spellID) .. ", HoT cannot be tracked")

        return
    end

    local sent = nil
    if castGUID and not IsSecret(castGUID) then
        sent = sentTargets[castGUID]
        sentTargets[castGUID] = nil
    end

    if sent then
        for i = #sentQueue, 1, -1 do
            if sentQueue[i] == sent then tremove(sentQueue, i) end
        end
    else
        sent = TakeQueuedSent(spellID, GetTime())
    end

    local ok, name, desc = pcall(GetSpellNameAndDescription, spellID)
    if not ok or name == nil then
        Debug("cast " .. spellID .. ": no name (" .. Describe(name) .. ")")
        HOT.Report("cast " .. spellID .. ": spell name unreadable (" .. Describe(name) .. ")")

        return
    end

    local total, duration, interval = ParseHot(desc)
    if total == nil then
        Debug("cast " .. name .. " (" .. spellID .. "): not a HoT, desc=" .. Describe(desc))

        return
    end

    local key = nil
    if sent then
        key = sent.key
    else
        key = ResolveTargetKey(nil)
    end

    if key == nil then
        Debug("cast " .. name .. ": target not found (sent=" .. tostring(sent ~= nil) .. ")")
        HOT.Report(name .. ": no target assigned (sent=" .. tostring(sent ~= nil) .. ")")

        return
    end
    local now = GetTime()
    local hot = NewHot(spellID, name, total, duration, interval, now)
    hotsByKey[key] = hotsByKey[key] or {}
    hotsByKey[key][name] = hot
    Debug(string.format("cast %s (%d) on %s: %d over %ss, %d ticks, tick %.1f", name, spellID, key, total, duration, hot.totalTicks, ExpectedTick(hot)))
    ApplyKnownInstant(key, hot)
    tinsert(pendingChecks, {
        ["hot"] = hot,
        ["key"] = key,
        ["at"] = now
    })

    for unit, at in pairs(recentAuraUnits) do
        if now - at <= HOT.AURA_RECENT then VerifyRecipient(unit, now) end
    end
end

local function OnUnitCombat(unit, action, flag, amount)
    if IsSecret(action) or action ~= "HEAL" then return end
    local isCrit = not IsSecret(flag) and flag == "CRITICAL"
    local key = UnitKey(unit)
    if key == nil then return end
    local now = GetTime()
    amount = SafeNumber(amount)
    recentHeals[key] = {
        ["at"] = now,
        ["amount"] = amount,
        ["crit"] = isCrit
    }

    local hots = hotsByKey[key]
    if hots == nil then return end
    if combatSeenAt ~= now then
        wipe(combatSeen)
        combatSeenAt = now
    end

    local signature = key .. ":" .. tostring(amount)
    if combatSeen[signature] and combatSeen[signature] ~= unit then return end
    combatSeen[signature] = unit
    for _, hot in pairs(hots) do
        if not hot.instantRecorded and MatchesInstantHeal(hot, recentHeals[key]) then
            local heal = recentHeals[key]
            ObserveInstant(hot, heal)
            if hot.instant then
                recentHeals[key] = nil

                return
            end
        end
    end

    local best, bestIndex, bestDistance = nil, nil, nil
    for _, hot in pairs(hots) do
        local index = math.max(1, math.floor((now - hot.anchor) / hot.interval + 0.5))
        local distance = math.abs(now - (hot.anchor + index * hot.interval))
        if index > hot.lastTickIndex and index <= hot.totalTicks and distance <= HOT.WINDOW and IsPlausibleTick(hot, amount) and (bestDistance == nil or distance < bestDistance) then best, bestIndex, bestDistance = hot, index, distance end
    end

    if best == nil then return end
    if best.lastTickIndex == 0 then
        best.anchor = now - bestIndex * best.interval
        best.expiresAt = best.anchor + best.totalTicks * best.interval
    end

    best.lastTickIndex = bestIndex
    best.nextTickAt = best.anchor + (bestIndex + 1) * best.interval
    if amount and not isCrit then
        best.tickSum = best.tickSum + amount
        best.tickCount = best.tickCount + 1
        learnedTicks[best.spellID] = best.tickSum / best.tickCount
    end

    Debug(string.format("tick %s %s%s on %s (%d/%d)", best.name, tostring(amount), isCrit and " CRIT" or "", unit, bestIndex, best.totalTicks))
end

local function AurasReadable()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or IsSecret(secret) or secret == true then return false end
    end

    return true
end

local function ValidateHot(unit, hot, now)
    if now - hot.appliedAt < HOT.VALIDATE_DELAY then return true end
    if C_UnitAuras == nil or C_UnitAuras.GetAuraDataBySpellName == nil then return true end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, hot.name, "HELPFUL|PLAYER")
    if not ok or IsSecret(aura) then return true end
    if aura == nil then
        hot.missingSince = hot.missingSince or now

        return now - hot.missingSince < HOT.MISSING_GRACE
    end

    hot.missingSince = nil
    if type(aura) ~= "table" or hot.lastTickIndex > 0 then return true end
    local expires = SafeNumber(aura.expirationTime)
    if expires == nil or expires <= 0 or math.abs(expires - hot.expiresAt) < 0.3 then return true end
    hot.expiresAt = expires
    hot.anchor = expires - hot.totalTicks * hot.interval
    hot.nextTickAt = hot.anchor + math.max(1, math.floor((now - hot.anchor) / hot.interval) + 1) * hot.interval

    return true
end

local function GetUnitHots(unit, now, readable)
    local key = UnitKey(unit)
    local hots = key and hotsByKey[key]
    if hots == nil then return 0 end
    if UnitFrameUtils:SafeBool(UnitIsDeadOrGhost, unit) == true then
        hotsByKey[key] = nil

        return 0
    end

    local total = 0
    for name, hot in pairs(hots) do
        if readable and not ValidateHot(unit, hot, now) then
            hots[name] = nil
            Debug("aura gone " .. name)
            HOT.Report(name .. ": removed from " .. key .. " (" .. unit .. "), aura not found after " .. string.format("%.1f", now - hot.appliedAt) .. "s")
        else
            total = total + RemainingHeal(hot)
        end
    end

    return total
end

local function CopyBlizzardStyle(texture, healthBar)
    local segment = healthBar.MyHealPredictionBar
    local source = segment and segment.Fill
    if source == nil then return false end
    local atlas = source.GetAtlas and source:GetAtlas()
    if SafeString(atlas) then
        texture:SetAtlas(atlas, false)
    else
        local file = source:GetTexture()
        if file == nil or IsSecret(file) then return false end
        texture:SetTexture(file)
    end

    local r, g, b, a = source:GetVertexColor()
    if SafeNumber(r) and SafeNumber(g) and SafeNumber(b) then texture:SetVertexColor(r, g, b, SafeNumber(a) or 1) end

    return true
end

local function ApplyBaseStyle(texture, spec)
    if spec.style == "RAID" then
        local color = _G["CUF_MY_HEAL_PREDICTION_COLOR"]
        if color and color.GetRGBA then
            texture:SetColorTexture(color:GetRGBA())
        else
            texture:SetColorTexture(HOT.RAID_COLOR[1], HOT.RAID_COLOR[2], HOT.RAID_COLOR[3], HOT.RAID_COLOR[4])
        end

        return
    end

    if spec.style == "UNIT" and CopyBlizzardStyle(texture, spec.bar) then return end
    texture:SetTexture(HOT.PRD_TEXTURE)
    local color = _G["HEALTHBAR_MY_HEAL_PREDICTION_COLOR"]
    if spec.style == "UNIT" and color and color.GetRGB then
        texture:SetVertexColor(color:GetRGB())
    else
        texture:SetVertexColor(HOT.PRD_COLOR[1], HOT.PRD_COLOR[2], HOT.PRD_COLOR[3])
    end
end

local function ApplyColorOverride(texture, spec, r, g, b, a)
    if spec.style == "RAID" then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetVertexColor(r, g, b, a)
    end
end

local function ApplyStyle(texture, spec)
    ApplyBaseStyle(texture, spec)
    if colorDebug then
        ApplyColorOverride(texture, spec, HOT.DEBUG_COLOR[1], HOT.DEBUG_COLOR[2], HOT.DEBUG_COLOR[3], 1)
    elseif UnitFrameUtils:GetOption("HOTCUSTOMCOLOR") == true then
        ApplyColorOverride(texture, spec, hotColor[1], hotColor[2], hotColor[3], hotColor[4])
    end
end

local function RestyleAll()
    for _, display in pairs(displays) do
        display.texture:SetVertexColor(1, 1, 1, 1)
        ApplyStyle(display.texture, display.spec)
    end
end

local function GetDisplay(spec)
    local healthBar = spec.bar
    local display = displays[healthBar]
    if display then return display end
    local regionParent = spec.parent
    if healthBar.GetStatusBarTexture == nil or regionParent == nil or regionParent.CreateTexture == nil then return nil end
    local fill = healthBar:GetStatusBarTexture()
    if fill == nil then return nil end
    local span = CreateFrame("StatusBar", nil, healthBar)
    span:SetStatusBarTexture(HOT.SPAN_TEXTURE)
    span:SetStatusBarColor(0, 0, 0, 0)
    span:SetMinMaxValues(0, 1)
    span:SetValue(0)
    local texture = regionParent:CreateTexture(nil, spec.layer, nil, spec.sublevel)
    ApplyStyle(texture, spec)
    local mask = spec.mask
    if mask == nil and regionParent.CreateMaskTexture then
        mask = regionParent:CreateMaskTexture()
        mask:SetTexture(HOT.SPAN_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(healthBar)
    end

    if mask and texture.AddMaskTexture then pcall(texture.AddMaskTexture, texture, mask) end
    texture:Hide()
    display = {
        ["span"] = span,
        ["texture"] = texture,
        ["healthBar"] = healthBar,
        ["fill"] = fill,
        ["spec"] = spec,
        ["width"] = 0
    }

    displays[healthBar] = display

    return display
end

local function IsShownSafe(region)
    if region == nil or region.IsShown == nil then return false end
    local ok, shown = pcall(region.IsShown, region)

    return ok and not IsSecret(shown) and shown == true
end

local function GetChainEnd(spec, fill)
    local owner = spec.bar
    local keys = HOT.UNIT_SEGMENTS
    if spec.style ~= "UNIT" then keys = HOT.TEXTURE_SEGMENTS end
    if spec.style == "RAID" then owner = spec.parent end
    local last = fill
    for _, key in ipairs(keys) do
        local segment = owner[key]
        if IsShownSafe(segment) then
            local edge = segment
            if spec.style == "UNIT" then edge = segment.FillMask end
            if edge then last = edge end
        end
    end

    return last
end

local function SetStart(display, region)
    if display.start == region then return end
    if debugMode and display.start then
        local where = "fill"
        if region ~= display.fill then where = "prediction segment" end
        UnitFrameUtils:MSG("|cff55ff99HoT|r " .. HOT.Label(display.spec) .. " now starts at " .. where)
    end

    display.start = region
    local span = display.span
    span:ClearAllPoints()
    span:SetPoint("TOPLEFT", region, "TOPRIGHT", 0, 0)
    span:SetPoint("BOTTOMLEFT", region, "BOTTOMRIGHT", 0, 0)
    display.texture:ClearAllPoints()
    display.texture:SetPoint("TOPLEFT", region, "TOPRIGHT", 0, 0)
    display.texture:SetPoint("BOTTOMRIGHT", span:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
end

local function HideDisplay(spec)
    local display = displays[spec.bar]
    if display then display.texture:Hide() end
end

local function ShowDisplay(spec, unit, total)
    local display = GetDisplay(spec)
    if display == nil then return end
    SetStart(display, GetChainEnd(spec, display.fill))
    local width = SafeNumber(spec.bar:GetWidth())
    if width and width > 0 and width ~= display.width then
        display.width = width
        display.span:SetWidth(width)
    end

    local ok = pcall(
        function()
            display.span:SetMinMaxValues(0, UnitHealthMax(unit))
            display.span:SetValue(total)
        end
    )

    display.texture:SetShown(ok)

    return ok
end

function HOT.MarkShown(spec, unit)
    local key = UnitKey(unit)
    local hots = key and hotsByKey[key]
    if hots == nil then return end
    for name, hot in pairs(hots) do
        hot.shownOn = hot.shownOn or {}
        if not hot.shownOn[spec.key] then
            hot.shownOn[spec.key] = true
            local display = displays[spec.bar]
            local okHp, hp = pcall(UnitHealth, unit)
            local okMax, maxHp = pcall(UnitHealthMax, unit)
            local okW, width = pcall(spec.bar.GetWidth, spec.bar)
            local start = display and display.start
            local startName = "fill"
            if start and start ~= display.fill then startName = "prediction segment" end
            UnitFrameUtils:MSG(string.format("|cff55ff99HoT|r shown %s on %s (%s): %.0f, health %s/%s, bar width %s, starts at %s, texture shown %s", name, HOT.Label(spec), unit, RemainingHeal(hot), okHp and Describe(hp) or "?", okMax and Describe(maxHp) or "?", okW and Describe(width) or "?", startName, display and tostring(display.texture:IsShown()) or "?"))
        end

        hot.shown = true
    end

    if spec.failed then
        spec.failed = nil
        HOT.Report("frame " .. HOT.Label(spec) .. " works again")
    end
end

function HOT.CheckShown(now)
    if not HOT.report and not debugMode then return end
    for key, hots in pairs(hotsByKey) do
        for name, hot in pairs(hots) do
            if not hot.reported and now - hot.appliedAt > HOT.REPORT_DELAY then
                hot.reported = true
                if hot.shown then
                    UnitFrameUtils:MSG("|cff55ff99HoT|r " .. name .. " on " .. key .. ", frames checked: " .. table.concat(HOT.hosts, ", "))
                else
                    UnitFrameUtils:MSG("|cffff4040HoT error|r " .. name .. " on " .. key .. ": not shown on any frame. Frames checked: " .. table.concat(HOT.hosts, ", "))
                end
            end
        end
    end
end

function HOT.Label(spec)
    local key = spec.key
    if type(key) == "table" and key.GetName then
        local ok, name = pcall(key.GetName, key)
        if ok and SafeString(name) then return name end
    end

    return tostring(key)
end

function HOT.TrackHost(spec, unit, enabled)
    local state = "off"
    if enabled then state = tostring(UnitKey(unit) or "no key") end
    tinsert(HOT.hosts, HOT.Label(spec) .. "=" .. Describe(unit) .. " [" .. state .. "]")
end

local function UpdateHost(spec, unit, enabled, now, readable)
    if spec == nil or spec.bar == nil then return end
    if HOT.report or debugMode then HOT.TrackHost(spec, unit, enabled) end
    local total = 0
    if enabled and SafeString(unit) and UnitFrameUtils:UnitExists(unit) then total = GetUnitHots(unit, now, readable) end
    if total > 0 then
        if ShowDisplay(spec, unit, total) then
            if HOT.report or debugMode then HOT.MarkShown(spec, unit) end
        elseif HOT.report and not spec.failed then
            spec.failed = true
            HOT.Report("frame " .. HOT.Label(spec) .. " (" .. tostring(unit) .. "): could not draw " .. string.format("%.0f", total))
        end
    else
        HideDisplay(spec)
    end
end

local specs = {}
local function GetSpec(key, bar, parent, style, layer, sublevel, mask)
    if bar == nil then return nil end
    local spec = specs[key]
    if spec and spec.bar == bar then return spec end
    spec = {
        ["key"] = key,
        ["bar"] = bar,
        ["parent"] = parent,
        ["style"] = style,
        ["layer"] = layer,
        ["sublevel"] = sublevel,
        ["mask"] = mask
    }

    specs[key] = spec

    return spec
end

local function GetContainerSpec(key, container)
    local bar = container and container.HealthBar

    return GetSpec(key, bar, bar, "UNIT", "BACKGROUND", 3, container and container.HealthBarMask)
end

local function GetUnitFrameSpec(key, frame, content)
    local main = frame and frame[content] and frame[content][content .. "Main"]

    return GetContainerSpec(key, main and main.HealthBarsContainer)
end

local function UpdatePartyFrames(enabled, now, readable)
    local partyFrame = _G["PartyFrame"]
    if partyFrame == nil then return end
    for i = 1, 5 do
        local member = partyFrame["MemberFrame" .. i]
        if member then UpdateHost(GetContainerSpec("PARTY" .. i, member.HealthBarContainer), member.displayedUnit or member.unit, enabled, now, readable) end
    end
end

local function IsGroupUnit(unit)
    if not UnitFrameUtils:UnitExists(unit) then return false end
    if UnitFrameUtils:SafeBool(UnitIsUnit, unit, "player") == true then return true end
    if UnitFrameUtils:SafeBool(UnitInParty, unit) == true then return true end
    local ok, index = pcall(UnitInRaid, unit)

    return ok and SafeNumber(index) ~= nil
end

local function UpdateDisplays()
    local now = GetTime()
    HOT.hosts = {}
    local readable = AurasReadable()
    local raidEnabled = UnitFrameUtils:GetOption("SHOWHOTPREDICTION") == true
    local frames = UnitFrameUtils.GetRaidOverlayFrames and UnitFrameUtils:GetRaidOverlayFrames()
    if frames then
        for frame in pairs(frames) do
            UpdateHost(GetSpec(frame, frame.healthBar, frame, "RAID", "BORDER", 5), frame.displayedUnit or frame.unit, raidEnabled, now, readable)
        end
    end

    UpdatePartyFrames(raidEnabled, now, readable)

    local prd = _G["PersonalResourceDisplayFrame"]
    local prdBar = prd and prd.HealthBarsContainer and prd.HealthBarsContainer.healthBar
    UpdateHost(GetSpec("PRD", prdBar, prdBar, "PRD", "BORDER", 5), "player", UnitFrameUtils:GetOption("SHOWHOTPREDICTIONPRD") == true, now, readable)
    local unitEnabled = UnitFrameUtils:GetOption("SHOWHOTPREDICTIONUNIT") == true
    UpdateHost(GetUnitFrameSpec("PLAYER", _G["PlayerFrame"], "PlayerFrameContent"), "player", unitEnabled, now, readable)
    UpdateHost(GetUnitFrameSpec("TARGET", _G["TargetFrame"], "TargetFrameContent"), "target", unitEnabled and IsGroupUnit("target"), now, readable)
    HOT.CheckShown(now)
end

function UnitFrameUtils:UpdateHotPrediction()
    RestyleAll()
    UpdateDisplays()
end

function UnitFrameUtils:SetHotColor(r, g, b, a)
    hotColor = {r or hotColor[1], g or hotColor[2], b or hotColor[3], a or hotColor[4]}
    RestyleAll()
end

function UnitFrameUtils:ToggleHotColorDebug()
    colorDebug = not colorDebug
    HOT.report = colorDebug
    RestyleAll()

    UnitFrameUtils:MSG("HoT prediction debug color (blue) + error report: " .. tostring(colorDebug))
end

function UnitFrameUtils:ToggleHotDebug()
    debugMode = not debugMode
    UnitFrameUtils:MSG("HoT debug: " .. tostring(debugMode))
    local count = 0
    for key, hots in pairs(hotsByKey) do
        for name, hot in pairs(hots) do
            count = count + 1
            UnitFrameUtils:MSG(string.format("%s on %s: %.0f left, tick %.1f, %d/%d", name, key, RemainingHeal(hot), ExpectedTick(hot), hot.lastTickIndex, hot.totalTicks))
        end
    end

    for spellID, tick in pairs(learnedTicks) do
        UnitFrameUtils:MSG(string.format("learned %d: %.1f", spellID, tick))
    end

    for name, stats in pairs(instantStats) do
        UnitFrameUtils:MSG(string.format("instant %s: %.1f of %.1f casts, learned %s", name, stats.hits, stats.casts, tostring(HOT.IsLearnedInstant(name))))
    end

    if count == 0 then UnitFrameUtils:MSG("no HoTs tracked") end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
eventFrame:RegisterEvent("UNIT_COMBAT")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:SetScript(
    "OnEvent",
    function(sel, event, ...)
        if event == "UNIT_SPELLCAST_SENT" then
            local _, targetName, castGUID, spellID = ...
            OnCastSent(targetName, castGUID, spellID)
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, castGUID, spellID = ...
            OnCastSucceeded(castGUID, spellID)
            UpdateDisplays()
        elseif event == "UNIT_COMBAT" then
            local unit, action, flag, amount = ...
            OnUnitCombat(unit, action, flag, amount)
        elseif event == "UNIT_AURA" then
            OnUnitAura(...)
        else
            local _, castGUID = ...
            DropSent(castGUID)
        end
    end
)

local sinceUpdate = 0
local wasActive = false
eventFrame:SetScript(
    "OnUpdate",
    function(sel, elapsed)
        sinceUpdate = sinceUpdate + elapsed
        if sinceUpdate < HOT.UPDATE then return end
        sinceUpdate = 0
        local active = next(hotsByKey) ~= nil
        if not active and not wasActive then return end
        wasActive = active
        Housekeep(GetTime())
        UpdateDisplays()
    end
)
