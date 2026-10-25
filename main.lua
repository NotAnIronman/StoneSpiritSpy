local Catalog = require("lib/catalog")
local Reader = require("lib/reader")
local hover = require("lib/hover").new()
local settings = require("lib/settings").new(PersistentDB, function() hover:hide() end)
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
    local hoverText
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
                if hasBox then
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
                        hoverText = name:gsub("<[^>]*>", "") .. " (" .. countLabel .. ")"
                    end
                end
            end
        end
    end
    if hoverText and settings.showHoverCount and focused and not MiniMenu.IsOpen() then
        hover:show(hoverText)
    else
        hover:hide()
    end
end)

subscribe("InventoryAdded", function(event) reader:inventoryChanged(event.inv) end)
subscribe("InventoryUpdated", function(event) reader:inventoryChanged(event.inv) end)
subscribe("InventoryRemoved", function(event) reader:inventoryChanged(event.inv) end)
subscribe("GameStateChanged", function() reader:reset(); hover:clear() end)
subscribe("MiniMenuOpened", function() hover:hide() end)
subscribe("WindowFocusChanged", function(event)
    focused = event.hasFocus
    if not focused then hover:hide() end
end)
subscribe("SettingsLayerReady", function(event) settings:build(event.component) end)

function PluginShutdown()
    for _, name in ipairs(subscriptions) do Event[name].Unsubscribe(reference) end
    hover:clear()
end

log("Stone Spirit Spy 0.2.0 loaded. Carry an ore box and hover over a rock.")
