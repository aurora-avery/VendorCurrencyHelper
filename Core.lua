local addonName = ...
local VCH = CreateFrame("Frame", "VendorCurrencyHelperFrame", UIParent)

local display
local entries = {}

local function EnsureDisplayFrame()
    if display then return display end
    if not MerchantFrame then return nil end

    display = CreateFrame("Frame", "VCH_CurrencyDisplay", MerchantFrame)
    display:SetSize(220, 22)
    display:SetFrameStrata("HIGH")
    display:SetFrameLevel(100)

    if MerchantMoneyFrame then
        display:SetPoint("LEFT", MerchantFrame, "LEFT", 14, 0)
        display:SetPoint("BOTTOM", MerchantMoneyFrame, "BOTTOM", 0, 0)
    else
        display:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 14, 8)
    end

    for i = 1, 3 do
        local entry = CreateFrame("Frame", nil, display)
        entry:SetSize(65, 20)

        entry.text = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        entry.text:SetPoint("LEFT", entry, "LEFT", 0, 0)

        entry.icon = entry:CreateTexture(nil, "OVERLAY")
        entry.icon:SetSize(15, 15)
        entry.icon:SetPoint("LEFT", entry.text, "RIGHT", 4, 0)
        entry.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        entry:EnableMouse(true)
        entry:SetScript("OnEnter", function(self)
            if self.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        entry:SetScript("OnLeave", function() GameTooltip:Hide() end)

        entries[i] = entry
    end

    return display
end

local function GetNumVendorItems()
    if C_MerchantFrame and C_MerchantFrame.GetNumMerchantItems then
        return C_MerchantFrame.GetNumMerchantItems()
    elseif GetMerchantNumItems then
        return GetMerchantNumItems()
    end
    return 0
end

local function GetOwnedInfo(itemTexture, itemLink, currencyName)
    -- 1. Check Currency Link
    if itemLink and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyIDFromLink then
        local currencyID = C_CurrencyInfo.GetCurrencyIDFromLink(itemLink)
        if currencyID and currencyID > 0 then
            local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
            if info then
                return info.quantity or 0, info.iconFileID or itemTexture, "currency:" .. currencyID
            end
        end
    end

    -- 2. Check Bag/Warband Item via itemLink or currencyName
    local itemID
    if itemLink then
        itemID = tonumber(itemLink:match("item:(%d+)"))
        if not itemID and C_Item and C_Item.GetItemInfoInstant then
            itemID = C_Item.GetItemInfoInstant(itemLink)
        end
    end
    if not itemID and currencyName and C_Item and C_Item.GetItemInfoInstant then
        itemID = C_Item.GetItemInfoInstant(currencyName)
    end

    if itemID then
        local count = 0
        if C_Item and C_Item.GetItemCount then
            count = C_Item.GetItemCount(itemID, false, false, false, true) or C_Item.GetItemCount(itemID) or 0
        elseif GetItemCount then
            count = GetItemCount(itemID) or 0
        end
        return count, itemTexture, "item:" .. itemID
    end

    -- 3. Fallback if itemLink isn't cached yet but currencyName is provided
    if currencyName and itemTexture then
        local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(currencyName)) or 0
        return count, itemTexture, "name:" .. currencyName
    end

    return nil
end

local function UpdateVendorCurrencies(debugMode)
    local frame = EnsureDisplayFrame()
    if not frame or not MerchantFrame or not MerchantFrame:IsShown() then
        if frame then frame:Hide() end
        if debugMode then print("|cff00ccff[VCH]|r MerchantFrame is not open.") end
        return
    end

    local seen = {}
    local list = {}
    local numItems = GetNumVendorItems()

    if debugMode then
        print("|cff00ccff[VCH Debug]|r Scanning " .. tostring(numItems) .. " vendor items...")
    end

    for i = 1, numItems do
        local numCosts = GetMerchantItemCostInfo and GetMerchantItemCostInfo(i) or 0
        for c = 1, numCosts do
            local itemTexture, itemValue, itemLink, currencyName = GetMerchantItemCostItem(i, c)
            if debugMode and i == 1 then
                print(string.format("  Item 1 Cost %d: tex=%s, val=%s, link=%s, name=%s",
                    c, tostring(itemTexture), tostring(itemValue), tostring(itemLink), tostring(currencyName)))
            end
            local count, icon, key = GetOwnedInfo(itemTexture, itemLink, currencyName)
            if key and not seen[key] then
                seen[key] = true
                table.insert(list, {
                    count = count or 0,
                    icon = icon,
                    link = itemLink
                })
            end
        end
    end

    if #list == 0 then
        frame:Hide()
        return
    end

    frame:Show()
    local prevEntry = nil
    for i = 1, 3 do
        local entry = entries[i]
        local data = list[i]
        if data then
            local formatted = BreakUpLargeNumbers and BreakUpLargeNumbers(data.count) or tostring(data.count)
            entry.text:SetText(formatted)
            entry.icon:SetTexture(data.icon)
            entry.link = data.link
            entry:SetWidth(entry.text:GetStringWidth() + 20)
            entry:ClearAllPoints()
            if not prevEntry then
                entry:SetPoint("LEFT", frame, "LEFT", 0, 0)
            else
                entry:SetPoint("LEFT", prevEntry, "RIGHT", 10, 0)
            end
            entry:Show()
            prevEntry = entry
        else
            entry:Hide()
        end
    end
end

VCH:RegisterEvent("PLAYER_LOGIN")
VCH:RegisterEvent("MERCHANT_SHOW")
VCH:RegisterEvent("MERCHANT_UPDATE")
VCH:RegisterEvent("BAG_UPDATE_DELAYED")
VCH:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

VCH:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("|cff00ccff[VendorCurrencyHelper]|r Loaded! Type /vch debug at a vendor to inspect.")
    elseif event == "MERCHANT_SHOW" then
        UpdateVendorCurrencies()
        C_Timer.After(0.2, function() UpdateVendorCurrencies() end)
    else
        if MerchantFrame and MerchantFrame:IsShown() then
            UpdateVendorCurrencies()
        end
    end
end)

SLASH_VCH1 = "/vch"
SlashCmdList["VCH"] = function(msg)
    UpdateVendorCurrencies(true)
end