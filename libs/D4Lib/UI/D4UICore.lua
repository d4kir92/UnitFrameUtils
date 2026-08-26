local _, D4 = ...
D4.UI = D4.UI or {}
local UI = D4.UI
UI.PADDING = 4
UI.SPACING = 10
UI.ROW = 24
UI.WindowMixin = {}

function UI:Text(key, ...)
    if key == nil then return "" end
    return D4:TryTrans(key, nil, ...)
end

function UI:NextName(win, kind)
    win.count = win.count + 1

    return D4:GetName(win, true) .. kind .. win.count
end

function UI:SetSolidColor(texture, r, g, b, a)
    if texture == nil then return end
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

function UI:ApplyWindow(win)
    for key, value in pairs(UI.WindowMixin) do
        win[key] = value
    end
end

function UI:Add(win, frame, height, label)
    local element = {
        ["frame"] = frame,
        ["height"] = height or UI.ROW,
        ["label"] = string.lower(label or ""),
        ["filter"] = win.search ~= nil,
        ["shown"] = true,
    }

    tinsert(win.elements, element)
    frame.uiElement = element
    win:Layout()

    return element
end

function UI:CloseDropdowns()
    if UI.openList then
        UI.openList:Hide()
        UI.openList = nil
    end
end

function UI.WindowMixin:Layout()
    local y = -UI.PADDING
    for _, element in ipairs(self.elements) do
        if element.shown then
            element.frame:ClearAllPoints()
            element.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", UI.PADDING, y)
            element.frame:Show()
            y = y - element.height - UI.SPACING
        else
            element.frame:Hide()
        end
    end

    self.content:SetHeight(math.max(1, -y + UI.PADDING))
    self:UpdateScroll()
end

function UI.WindowMixin:UpdateScroll()
    if self.scrollBox == nil then return end
    if self.scrollBox.FullUpdate == nil then return end
    if ScrollBoxConstants == nil then return end
    self.scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
end

function UI.WindowMixin:Filter(text)
    text = string.lower(strtrim(text or ""))
    for _, element in ipairs(self.elements) do
        if element.filter then
            element.shown = text == "" or string.find(element.label, text, 1, true) ~= nil
        end
    end

    self:Layout()
end
