local _, D4 = ...
local UI = D4.UI
local windows = 0

function D4:CreateUIWindow(tab)
    tab = tab or {}
    windows = windows + 1
    local name = tab.name or ("D4UIWindow" .. windows)
    local width = tab.width or 420
    local height = tab.height or 520
    local win = D4:CreateFrame(name, tab.parent or UIParent, tab.templates)
    win:SetSize(width, height)
    win:SetPoint(unpack(tab.pTab or {"CENTER"}))
    win:SetFrameStrata("HIGH")
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    D4:SetClampedToScreen(win, true)
    if win.TitleText then win.TitleText:SetText(UI:Text(tab.title)) end
    local scroll = nil
    if D4:CheckTemplates("UIPanelScrollFrameTemplate") then
        scroll = CreateFrame("ScrollFrame", name .. "Scroll", win, "UIPanelScrollFrameTemplate")
    else
        scroll = CreateFrame("ScrollFrame", name .. "Scroll", win)
    end

    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -32, 12)
    local content = CreateFrame("Frame", name .. "Content", scroll)
    content:SetSize(width - 56, 1)
    scroll:SetScrollChild(content)
    win.scroll = scroll
    win.content = content
    win.contentWidth = width - 56
    win.elements = {}
    win.count = 0
    win.search = nil
    UI:ApplyWindow(win)
    win:HookScript("OnHide", function() UI:CloseDropdowns() end)
    win:Hide()

    return win
end

function UI.WindowMixin:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
