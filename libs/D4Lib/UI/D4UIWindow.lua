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
    scrollBox:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -28, 22)
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

local function MakeResizable(win, name, tab)
    win:SetResizable(true)
    local minWidth = tab.minWidth or 300
    local minHeight = tab.minHeight or 200
    if win.SetResizeBounds then
        win:SetResizeBounds(minWidth, minHeight)
    elseif win.SetMinResize then
        win:SetMinResize(minWidth, minHeight)
    end

    local grip = CreateFrame("Button", name .. "Resize", win)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript(
        "OnMouseUp",
        function()
            win:StopMovingOrSizing()
            if tab.onResize then tab.onResize(math.floor(win:GetWidth() + 0.5), math.floor(win:GetHeight() + 0.5)) end
        end
    )

    win:SetScript(
        "OnSizeChanged",
        function(sel, width)
            sel.contentWidth = width - 56
            sel:Layout()
        end
    )

    win.grip = grip
end

local function CreateLegacyScroll(win, name)
    local scroll = nil
    if D4:CheckTemplates("UIPanelScrollFrameTemplate") then
        scroll = CreateFrame("ScrollFrame", name .. "Scroll", win, "UIPanelScrollFrameTemplate")
    else
        scroll = CreateFrame("ScrollFrame", name .. "Scroll", win)
    end

    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -32, 22)
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
    if tab.resizable ~= false then MakeResizable(win, name, tab) end
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
