local _, D4 = ...
local UI = D4.UI
local windows = 0
local TOP_INSET = 32

local function FindInset(win)
    if win.InsetBg then return win.InsetBg end
    if win.Inset then return win.Inset end
    local nam = D4:GetName(win, true)
    if nam ~= "" and _G[nam .. "Inset"] then return _G[nam .. "Inset"] end
    local found = nil
    D4:ForeachRegions(
        win,
        function(region)
            if found then return end
            local regionName = D4:GetName(region)
            if regionName and string.find(regionName, "Inset") then found = region end
        end,
        "[D4UI] FindInset"
    )

    if found then return found end
    D4:ForeachChildren(
        win,
        function(child)
            if found then return end
            local childName = D4:GetName(child)
            if childName and string.find(childName, "Inset") then found = child end
        end,
        "[D4UI] FindInset"
    )

    return found
end

local function CaptureInset(win)
    if win.insetFrame == nil then win.insetFrame = FindInset(win) end
    if win.insetFrame == nil then return end
    if win.insetAnchors then return end
    local anchors = {}
    for i = 1, win.insetFrame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = win.insetFrame:GetPoint(i)
        tinsert(anchors, {point, relativeTo, relativePoint, x, y})
    end

    if #anchors == 0 then
        anchors = {
            {"TOPLEFT", win, "TOPLEFT", 4, -25},
            {"BOTTOMRIGHT", win, "BOTTOMRIGHT", -6, 4}
        }
    end

    win.insetAnchors = anchors
end

function UI.WindowMixin:SetInsetTop(extra)
    CaptureInset(self)
    if self.insetAnchors == nil then return end
    self.insetFrame:ClearAllPoints()
    for _, anchor in ipairs(self.insetAnchors) do
        local point, relativeTo, relativePoint, x, y = anchor[1], anchor[2], anchor[3], anchor[4], anchor[5]
        if string.find(point, "TOP") then y = y - extra end
        self.insetFrame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

function UI.WindowMixin:SetScrollTop(extra)
    self:SetInsetTop(extra)
    if self.scrollFrame == nil then return end
    if self.scrollInset == nil then return end
    self.scrollFrame:ClearAllPoints()
    self.scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", self.scrollInset.left, -(TOP_INSET + extra))
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", self.scrollInset.right, self.scrollInset.bottom)
end

local function HasModernScroll()
    if ScrollUtil == nil then return false end
    if ScrollUtil.InitScrollBoxWithScrollBar == nil then return false end
    if CreateScrollBoxLinearView == nil then return false end

    return D4:CheckTemplates("WowScrollBox, MinimalScrollBar")
end

local function CreateModernScroll(win, name)
    local scrollBox = CreateFrame("Frame", name .. "ScrollBox", win, "WowScrollBox")
    win.scrollFrame = scrollBox
    win.scrollInset = {
        ["left"] = 12,
        ["right"] = -28,
        ["bottom"] = 22
    }

    win:SetScrollTop(0)
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

    win.scrollFrame = scroll
    win.scrollInset = {
        ["left"] = 12,
        ["right"] = -32,
        ["bottom"] = 22
    }

    win:SetScrollTop(0)
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
    UI:ApplyWindow(win)
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
    win.rootCategory = nil
    win.searching = false
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
