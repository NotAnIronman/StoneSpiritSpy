local Catalog = require("lib/catalog")
local Reader = require("lib/reader")
local total = 0
local function equal(actual, expected)
    assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    fn()
    total = total + 1
    print("PASS " .. name)
end
local function field(spirit, value)
    return {id=spirit.varID, configName=spirit.varName, value=value}
end
local bag, variables, online, reads, reader
local function reset()
    bag, variables, online, reads = {}, {}, true, 0
    reader = Reader.new({
        backpackID=93,
        available=function() return online end,
        slots=function(id) reads=reads+1; return bag end,
        variableByName=function(name) return variables[name] end,
        variableByID=function(id)
            for _, cfg in pairs(variables) do if cfg.id == id then return cfg end end
        end,
    })
end
local copper = Catalog.rock("Copper rock")

test("all 17 storage bindings agree with the supplied native VarPlayer dump", function()
    equal(#Catalog.spirits, 17)
    for _, spirit in ipairs(Catalog.spirits) do
        equal(dumpVariables[spirit.varName], spirit.varID)
    end
end)

test("every supported rock resolves its own spirit", function()
    for _, spirit in ipairs(Catalog.spirits) do
        equal(Catalog.rock(spirit.name .. " rock"), spirit)
        equal(Catalog.item(spirit.id), spirit)
        equal(Catalog.rock("<col=ffff00>" .. spirit.name .. " rocks</col>"), spirit)
    end
    equal(Catalog.rock("Concentrated gold rocks").key, "gold")
    equal(Catalog.rock("Concentrated coal rocks").key, "coal")
    equal(Catalog.rock("Sandstone rock"), nil)
    equal(Catalog.rock("Gem rock"), nil)
    equal(Catalog.rock("Copper ore box"), nil)
end)

test("all ten unnoted ore boxes are detected and noted IDs are excluded", function()
    for id=44779,44797,2 do
        reset()
        bag = {{obj={id=id}, count=1}}
        equal(reader:hasBox(), true)
        bag = {{obj={id=id+1}, count=1}}
        reader:inventoryChanged({id=93})
        equal(reader:hasBox(), false)
    end
end)

test("empty backpack and zero-count box slots are not carried boxes", function()
    reset()
    equal(reader:hasBox(), false)
    bag = {{obj={id=44779}, count=0}}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), false)
end)

test("current spirit values update without opening or hovering an ore box", function()
    reset()
    local value = field(copper, 248)
    variables[copper.varName] = value
    equal(reader:count(copper), 248)
    value.value = 247
    equal(reader:count(copper), 247)
    value.value = 0
    equal(reader:count(copper), 0)
    value.value = 2147483647
    equal(reader:count(copper), 2147483647)
end)

test("missing, unreadable and invalid values remain unavailable", function()
    reset()
    equal(reader:count(copper), nil)
    for _, value in ipairs({-1, 1.5, math.huge, "248", 2147483648}) do
        variables[copper.varName] = field(copper, value)
        equal(reader:count(copper), nil)
    end
    variables[copper.varName] = setmetatable({}, {__index=function() error("unavailable") end})
    equal(reader:count(copper), nil)
end)

test("numeric fallback verifies the exact native field name", function()
    local cfg = field(copper, 248)
    local fallback = Reader.new({
        variableByName=function() error("name unavailable") end,
        variableByID=function(id) equal(id, 11514); return cfg end,
    })
    equal(fallback:count(copper), 248)
    cfg.configName = "SOME_OTHER_VARIABLE"
    equal(fallback:count(copper), nil)
end)

test("backpack spirits and ore counts cannot inflate stored spirits", function()
    reset()
    bag = {{obj={id=44797}, count=1}, {obj={id=copper.id}, count=1000}, {obj={id=436}, count=150}}
    variables[copper.varName] = field(copper, 248)
    equal(reader:hasBox(), true)
    equal(reader:count(copper), 248)
end)

test("multiple ore boxes share one count", function()
    reset()
    bag = {{obj={id=44779}, count=1}, {obj={id=44797}, count=1}}
    variables[copper.varName] = field(copper, 248)
    equal(reader:hasBox(), true)
    equal(reader:count(copper), 248)
end)

test("box deposit, withdrawal, logout and re-login invalidate carried state", function()
    reset()
    bag = {{obj={id=44779}, count=1}}
    equal(reader:hasBox(), true)
    equal(reader:hasBox(), true)
    equal(reads, 1)
    bag = {}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), false)
    bag = {{obj={id=44797}, count=1}}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), true)
    online = false
    equal(reader:hasBox(), false)
    bag, online = {}, true
    equal(reader:hasBox(), false)
end)

test("labels preserve full counts and distinguish zero from unavailable", function()
    equal(Catalog.label(copper, 248), "248 Copper Stone Spirits")
    equal(Catalog.label(copper, 0), "0 Copper Stone Spirits")
    equal(Catalog.label(copper, 1), "1 Copper Stone Spirit")
    equal(Catalog.label(copper, 2147483647), "2,147,483,647 Copper Stone Spirits")
    equal(Catalog.label(copper, nil), "Copper Stone Spirits: unavailable")
end)

local handlers, logs, available, nativeBag, nativeValues, widgets, uiRoot, settingsHost, mouse, menuOpen, saved
local function boot(preferences)
    handlers, logs, available, nativeBag, nativeValues = {}, {}, true, {}, {}
    widgets, mouse, menuOpen, saved = {}, {x=200, y=200}, false, preferences or {}
    Event = {}
    for _, name in ipairs({"MiniMenuReady", "InventoryAdded", "InventoryUpdated", "InventoryRemoved", "GameStateChanged",
        "MiniMenuOpened", "WindowFocusChanged", "SettingsLayerReady"}) do
        Event[name] = {
            Subscribe=function(reference, callback) handlers[name]=callback end,
            Unsubscribe=function(reference) handlers[name]=nil end,
        }
    end
    PluginShutdown = nil
    config = {Inv={INV={id=93}}}
    config.Font = {FromID=function() return {GetStringWidth=function(_, content) return #content * 7 end} end}
    PersistentDB = {
        GetBool=function(_, key) if type(saved[key]) == "boolean" then return saved[key] end end,
        SetBool=function(_, key, value) saved[key]=value; return true end,
    }
    game = {options={InterfaceScale={setting=100}}}
    id = {Font={MUSEO_SANS_15PT_REGULAR=1}, StyleSheet={BUTTON_DEFAULT=2},
        Component={TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP=3}}
    local function component(kind, parent)
        local control = {kind=kind, parent=parent, children={}, hooks={}, hidden=false, text={}}
        function control:SetPos(x, y) self.x, self.y=x, y end
        function control:SetSize(w, h, wp, hp)
            self.width, self.height=w+(wp or 0)*(self.parent.width or 0), h+(hp or 0)*(self.parent.height or 0)
        end
        function control:Subscribe(hook, callback) self.hooks[hook]=callback end
        function control:Destroy()
            self.destroyed, self.hidden = true, true
            for _, child in ipairs(self.children) do child:Destroy() end
        end
        if parent then parent.children[#parent.children+1]=control end
        widgets[#widgets+1]=control
        return control
    end
    uiRoot = component("Host")
    uiRoot.width, uiRoot.height, uiRoot.xyGlobal = 1024, 768, {x=0,y=0}
    settingsHost = component("SettingsHost")
    settingsHost.width, settingsHost.height = 420, 300
    ui = {Hook={ONBUTTONPRESSED=1}, Interfaces={GetComponent=function(_, componentID)
        equal(componentID, 3); return uiRoot
    end}}
    for _, kind in ipairs({"Layer", "Rectangle", "Text", "Button"}) do
        ui[kind] = {new=function(parent) return component(kind, parent) end}
    end
    Mouse = {IsAvailable=function() return true end, GetPosition=function() return mouse end}
    MiniMenu = {IsOpen=function() return menuOpen end}
    var = {VarPlayer=setmetatable({FromID=function(id)
        for _, cfg in pairs(nativeValues) do if cfg.id == id then return cfg end end
    end}, {__index=function(_, name) return nativeValues[name] end})}
    Player = {IsAvailable=function() return available end}
    Inventory = {Find=function(id)
        equal(id, 93)
        return {isValid=true, GetSlots=function() return nativeBag end}
    end}
    MiniMenuEntryType = {LOC=3, NPC=4, OBJ=2, INTERFACE=1}
    log = function(message) logs[#logs+1]=message end
    dofile(pluginRoot .. "/main.lua")
end
local function rock(name)
    return {actionEntryType=3, subjectText=name, locData={config={name=name}},
        fullText="Mine <col=ffff00>" .. name .. "</col>", actionType=3}
end
local function hover(entries) handlers.MiniMenuReady({miniMenu={entries=entries}}) end
local function overlay()
    for _, control in ipairs(widgets) do
        if control.kind == "Layer" and control.parent == uiRoot and not control.destroyed then return control end
    end
end
local function overlayLabel()
    local layer = overlay()
    for _, child in ipairs(layer and layer.children or {}) do
        if child.kind == "Text" then return child end
    end
end
local function clickSetting(prefix)
    for _, child in ipairs(settingsHost.children) do child:Destroy() end
    settingsHost.children = {}
    handlers.SettingsLayerReady({component=settingsHost})
    for _, control in ipairs(widgets) do
        if control.kind == "Button" and not control.destroyed and control.label:find(prefix, 1, true) == 1 then
            control.hooks[ui.Hook.ONBUTTONPRESSED](control)
            return control
        end
    end
    error("Missing setting: " .. prefix)
end

test("real entrypoint shows the requested 248 Copper Stone Spirits next to the rock", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    local value = field(copper, 248)
    nativeValues[copper.varName] = value
    local entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, "Mine <col=ffff00>Copper rock</col> <col=80d8ff>(248 Copper Stone Spirits)</col>")
    equal(entry.actionType, 3)
    value.value = 247
    hover({entry})
    equal(entry.overrideText, "Mine <col=ffff00>Copper rock</col> <col=80d8ff>(247 Copper Stone Spirits)</col>")
end)

test("hover displays the rock and count without a right click and allows mining through it", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    hover({rock("Copper rock")})
    equal(menuOpen, false)
    equal(overlay().hidden, false)
    equal(overlayLabel().content, "Copper rock (17 Copper Stone Spirits)")
    equal(overlay().clickthrough, true)
    for _, child in ipairs(overlay().children) do equal(child.clickthrough, true) end
    nativeValues[copper.varName].value = 16
    hover({rock("Copper rock")})
    equal(overlayLabel().content, "Copper rock (16 Copper Stone Spirits)")
end)

test("number only setting changes both hover and menu to Copper rock (17)", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local button = clickSetting("Number only")
    equal(button.label, "Number only: On")
    equal(saved.numberOnly, true)
    local entry = rock("Copper rock")
    hover({entry})
    equal(overlayLabel().content, "Copper rock (17)")
    equal(entry.overrideText, "Mine <col=ffff00>Copper rock</col> <col=80d8ff>(17)</col>")
    nativeValues[copper.varName].value = 0
    hover({entry})
    equal(overlayLabel().content, "Copper rock (0)")
    nativeValues[copper.varName] = nil
    hover({entry})
    equal(overlayLabel().content, "Copper rock (?)")
end)

test("hover toggle hides the label while preserving the context menu count", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    hover({rock("Copper rock")})
    local button = clickSetting("Show count on hover")
    equal(button.label, "Show count on hover: Off")
    equal(overlay().hidden, true)
    equal(saved.showHoverCount, false)
    local entry = rock("Copper rock")
    hover({entry})
    equal(overlay().hidden, true)
    assert(entry.overrideText:find("17 Copper Stone Spirits", 1, true))
end)

test("both display settings survive plugin reload", function()
    boot({showHoverCount=false, numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    equal(overlay(), nil)
    assert(entry.overrideText:find("(17)", 1, true))
    clickSetting("Show count on hover")
    hover({entry})
    equal(overlayLabel().content, "Copper rock (17)")
    local persisted = saved
    PluginShutdown()
    boot(persisted)
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    hover({rock("Copper rock")})
    equal(overlayLabel().content, "Copper rock (17)")
end)

test("hover hides over unrelated UI, empty menus, right-click menus and lost focus", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    hover({entry, {actionEntryType=1}})
    equal(overlay().hidden, true)
    hover({entry})
    hover({})
    equal(overlay().hidden, true)
    hover({entry})
    menuOpen = true
    handlers.MiniMenuOpened({})
    equal(overlay().hidden, true)
    hover({entry})
    equal(overlay().hidden, true)
    menuOpen = false
    hover({entry})
    handlers.WindowFocusChanged({hasFocus=false})
    equal(overlay().hidden, true)
    hover({entry})
    equal(overlay().hidden, true)
    handlers.WindowFocusChanged({hasFocus=true})
    hover({entry})
    equal(overlay().hidden, false)
end)

test("hover follows the mouse, stays on screen and handles interface scaling", function()
    boot({numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    game.options.InterfaceScale.setting = 150
    mouse = {x=300, y=300}
    hover({entry})
    equal(overlay().x, 216)
    equal(overlay().y, 228)
    mouse = {x=1530, y=1140}
    hover({entry})
    assert(overlay().x >= 0 and overlay().x + overlay().width <= uiRoot.width)
    assert(overlay().y >= 0 and overlay().y + overlay().height <= uiRoot.height)
end)

test("game state changes discard old overlay components and build on the current interface", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    local previous = overlay()
    handlers.GameStateChanged({})
    equal(previous.destroyed, true)
    hover({entry})
    assert(overlay() ~= previous)
    PluginShutdown()
    equal(overlay(), nil)
end)

test("real entrypoint reads all 17 spirits using the actual dump bindings", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    for index, spirit in ipairs(Catalog.spirits) do
        nativeValues[spirit.varName] = field(spirit, index)
        local entry = rock(spirit.name .. " rock")
        hover({entry})
        assert(entry.overrideText:find(Catalog.label(spirit, index), 1, true))
    end
end)

test("real entrypoint annotates mine and examine without changing either action", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 248)
    local mine, examine = rock("Copper rock"), rock("Copper rock")
    examine.fullText, examine.actionType = "Examine Copper rock", 1002
    hover({mine, examine})
    assert(mine.overrideText:find("248 Copper Stone Spirits", 1, true))
    assert(examine.overrideText:find("248 Copper Stone Spirits", 1, true))
    equal(mine.actionType, 3)
    equal(examine.actionType, 1002)
end)

test("real entrypoint leaves unrelated menus and missing boxes unchanged", function()
    boot()
    local entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, nil)
    nativeBag = {{obj={id=44779}, count=1}}
    handlers.InventoryUpdated({inv={id=93}})
    local npc, item, sand = rock("Copper rock"), rock("Copper rock"), rock("Sandstone rock")
    npc.actionEntryType, item.actionEntryType = 4, 2
    hover({npc, item, sand})
    equal(npc.overrideText, nil)
    equal(item.overrideText, nil)
    equal(sand.overrideText, nil)
end)

test("real entrypoint preserves other plugin text and reports unknown storage", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    local entry = rock("Copper rock")
    entry.overrideText = "Mine Copper rock [other plugin]"
    hover({entry})
    equal(entry.overrideText, "Mine Copper rock [other plugin] <col=80d8ff>(Copper Stone Spirits: unavailable)</col>")
end)

test("real entrypoint updates after deposit and resumes on withdrawal", function()
    boot()
    nativeValues[copper.varName] = field(copper, 248)
    nativeBag = {{obj={id=44779}, count=1}}
    local entry = rock("Copper rock")
    hover({entry})
    assert(entry.overrideText)
    nativeBag = {}
    handlers.InventoryUpdated({inv={id=93}})
    hover({entry})
    equal(entry.overrideText, "")
    equal(overlay().hidden, true)
    entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, nil)
    nativeBag = {{obj={id=44797}, count=1}}
    handlers.InventoryAdded({inv={id=93}})
    entry = rock("Copper rock")
    hover({entry})
    assert(entry.overrideText:find("248 Copper Stone Spirits", 1, true))
end)

test("real entrypoint performs no Draw or Logic work and unsubscribes on shutdown", function()
    boot()
    equal(handlers.Draw, nil)
    equal(handlers.Logic, nil)
    equal(Event.PluginShutdown, nil)
    equal(type(PluginShutdown), "function")
    PluginShutdown()
    equal(next(handlers), nil)
end)

print(string.format("%d checks passed. Native hover rendering still requires in-game validation.", total))
