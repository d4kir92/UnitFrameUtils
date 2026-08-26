local _, D4 = ...
local UI = D4.UI
local windows = 0

local function HasModernScroll()
    if ScrollUtil == nil then return false end
    if ScrollUtil.InitScrollBoxWithScrollBar == nil then return false end
    if CreateScrollBoxLinearView == nil then return false end

    return D4:CheckTemplates("WowScrollBox, MinimalScrollBar")
end

local function CreateModernScroll(win, name)
    local scrollBox = CreateFrame("Frame", name .. "ScrollBox", win, "WowScrollBox")
    scrollBox:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -32)
    scrollBox:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -28, 12)
    local scrollBar = CreateFrame("EventFrame", name .. "ScrollBar", win, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local content = CreateFrame("Frame", name .. "Content", scrollBox)
    content.scrollable = true
    content:SetSize(win.contentWidth, 1)
    local view = CreateScrollBoxLinearView()
    view:SetPanExtent(50)
    ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)
    win.scrollBox = scrollBox
    win.scrollBar = scrollBar

    return content
end

local function CreateLegacyScroll(win, name)
    local scroll = nil
    if D4:CheckTemplates("UIPanelScrollFrameTemplate") then
        scroll = CreateFrame("ScrollFrame", name .. "Scroll", win, "UIPanelScrollFrameTemplate")
    else
        scroll = CreateFrame("ScrollFrame", name .. "Scroll", win)
    end

    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -32, 12)
    local content = CreateFrame("Frame", name .. "Content", scroll)
    content:SetSize(win.contentWidth, 1)
    scroll:SetScrollChild(content)
    win.scroll = scroll

    return content
end

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
    win.contentWidth = width - 56
    if HasModernScroll() then
        win.content = CreateModernScroll(win, name)
    else
        win.content = CreateLegacyScroll(win, name)
    end

    win.elements = {}
    win.count = 0
    win.search = nil
    win.category = nil
    win.searching = false
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
