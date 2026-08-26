local _, D4 = ...
local UI = D4.UI

function UI.WindowMixin:AddSearch(tab)
    tab = tab or {}
    local win = self
    local name = UI:NextName(win, "Search")
    local box = CreateFrame("EditBox", name, win, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", win, "TOPLEFT", 18, -34)
    box:SetPoint("TOPRIGHT", win, "TOPRIGHT", -18, -34)
    box:SetHeight(UI.ROW)
    box:SetAutoFocus(false)
    box:SetMaxLetters(tab.maxLetters or 50)
    box.Hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    box.Hint:SetPoint("LEFT", box, "LEFT", 4, 0)
    box.Hint:SetText(UI:Text(tab.label or "LID_SEARCH"))
    box:SetScript(
        "OnTextChanged",
        function(sel)
            local text = sel:GetText()
            if text == "" then
                box.Hint:Show()
            else
                box.Hint:Hide()
            end

            win:Filter(text)
        end
    )

    box:SetScript(
        "OnEscapePressed",
        function(sel)
            sel:SetText("")
            sel:ClearFocus()
        end
    )

    box:SetScript("OnEnterPressed", function(sel) sel:ClearFocus() end)
    win.search = box
    win:SetScrollTop(UI.ROW + UI.SPACING * 2)

    return box
end
