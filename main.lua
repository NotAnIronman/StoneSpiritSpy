local Catalog = require("lib/catalog")
local Reader = require("lib/reader")
local hover = require("lib/native_hover").new()
local diagnostics = require("lib/hover_diagnostics").new(log)
local settings = require("lib/settings").new(PersistentDB, function() hover:clear() end, diagnostics)
local focused = true
local reference = "stone-spirit-spy"
local reader = Reader.new({
    backpackID = config.Inv.INV.id,
    available = function() return Player.IsAvailable() end,
    slots = function(id)
        local inventory = Inventory.Find(id)
        if not inventory or not inventory.isValid then return nil end
        return inventory:GetSlots()
    end,
    variableByName = function(name) return var.VarPlayer[name] end,
    variableByID = function(id) return var.VarPlayer.FromID(id) end,
})

local originals = setmetatable({}, {__mode="k"})
local subscriptions = {}
local function subscribe(name, callback)
    Event[name].Subscribe(reference, callback)
    subscriptions[#subscriptions + 1] = name
end

subscribe("MiniMenuReady", function(event)
    local hasBox
    local counts = {}
    local hoverName, hoverSuffix
    local entries = event.miniMenu.entries
    for index, entry in ipairs(entries) do
        local old = originals[entry]
        if old and entry.overrideText == old.rendered then entry.overrideText = old.original end
        originals[entry] = nil
        local loc = entry.locData
        if entry.actionEntryType == MiniMenuEntryType.LOC and loc then
            local spirit = Catalog.rock(entry.subjectText) or Catalog.rock(loc.config.name)
            if spirit then
                if hasBox == nil then hasBox = reader:hasBox() end
                if hasBox and (not settings.limitToBoxTier or reader:canHold(spirit)) then
                    local cached = counts[spirit.key]
                    if not cached then
                        cached = {value=reader:count(spirit)}
                        counts[spirit.key] = cached
                    end
                    local original = entry.overrideText or ""
                    local base = original
                    if not base or base == "" then base = entry.fullText end
                    local countLabel = Catalog.label(spirit, cached.value, settings.numberOnly)
                    local rendered = base .. " <col=80d8ff>(" .. countLabel .. ")</col>"
                    entry.overrideText = rendered
                    originals[entry] = {original=original, rendered=rendered}
                    if index == #entries then
                        local name = Catalog.rock(entry.subjectText) and entry.subjectText or loc.config.name
                        hoverName = name
                        hoverSuffix = " <col=80d8ff>(" .. countLabel .. ")</col>"
                    end
                end
            end
        end
    end
    if hoverName and settings.showHoverCount and focused and not MiniMenu.IsOpen() then
        hover:setTarget(hoverName, hoverSuffix)
    else
        hover:clear()
    end
    if diagnostics:active() then
        diagnostics:menu(entries, {enabled=settings.showHoverCount, focused=focused,
            menuOpen=MiniMenu.IsOpen(), hasBox=hasBox, tierFilter=settings.limitToBoxTier, target=hoverName})
    end
end)

subscribe("InventoryAdded", function(event) reader:inventoryChanged(event.inv) end)
subscribe("InventoryUpdated", function(event) reader:inventoryChanged(event.inv) end)
subscribe("InventoryRemoved", function(event) reader:inventoryChanged(event.inv) end)
subscribe("GameStateChanged", function() reader:reset(); hover:clear() end)
subscribe("Draw", function(event)
    hover:draw()
    if diagnostics:active() then diagnostics:draw(event.timeDeltaSecs, hover:diagnosticState()) end
end)
subscribe("MiniMenuOpened", function() hover:clear() end)
subscribe("WindowFocusChanged", function(event)
    focused = event.hasFocus
    if not focused then hover:clear() end
end)
subscribe("SettingsLayerReady", function(event) settings:build(event.component) end)

function PluginShutdown()
    for _, name in ipairs(subscriptions) do Event[name].Unsubscribe(reference) end
    hover:clear()
end

log("Stone Spirit Spy 0.3.8 loaded. Carry an ore box and hover over a rock.")
