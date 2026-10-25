# Stone Spirit Spy

Stone Spirit Spy adds the stone spirits stored in your ore box to a rock's native
hover text and right-click menu. For example:

```text
Mine Copper rock (248 Copper Stone Spirits)
```

Carry an unnoted ore box from Bronze through Elder Rune. The plugin reads your
character's shared ore-box spirit counts directly, so you do not need to inspect
or hover over the box first. Loose spirits in your backpack and bank are excluded.
Multiple boxes do not multiply the displayed count. Banking your boxes removes
the annotation.

Version **0.1.1** fixes a startup error caused by subscribing to a nonexistent
shutdown event. Shutdown uses the native global `PluginShutdown()` callback.
The test fixture now exposes only supported event names.

This is a development build. Local Lua checks pass against the supplied
configuration dumps. Hover rendering and server updates still need an in-game check.

## Install in the developer client

1. Open the [RuneScape plugin developer environment](https://developer.runescape.com/rs/tutorial/1helloworld.html).
2. Create a `StoneSpiritSpy` directory inside your client's `dev_plugins` directory.
   The documented Windows location is
   `C:\ProgramData\Jagex\RuneScape-BETA\dev_plugins\StoneSpiritSpy`.
   For Linux or a custom cache, use your client's actual plugin directory.
3. Extract the development ZIP into that directory. The directory must contain
   `main.lua`, `plugin.json`, and `lib/` directly.
4. Enter these commands in the developer console:

   ```text
   prf
   pon StoneSpiritSpy
   ```

For updates, replace the plugin files and run `prf`, then `prl StoneSpiritSpy`.
See the [Jagex plugin command reference](https://developer.runescape.com/rs/managing.html).

The plugin needs no additional plugins, permissions, or network access.

## Check the count in game

1. Carry an ore box containing a known amount of copper stone spirits.
2. Hover over a Copper rock. Check that its name has the same spirit count beside it.
3. Mine until a spirit is consumed, then hover again. Check that the count decreases.
4. Add more copper spirits to the box. Check that the count increases.
5. Put a different number of tin spirits in the box. Hover over a Tin rock and check
   that its count is separate from copper.
6. Empty the copper spirits. Check that Copper rocks show `0 Copper Stone Spirits`.
7. Bank the ore box. Check that rock annotations disappear. Withdraw it and check
   that they return.
8. Reload the plugin and repeat the hover check without inspecting the box first.

If a count says `unavailable`, the native field could not be read. This differs
from a confirmed empty box, which displays zero. A right-click menu keeps the
snapshot taken when it opened. Close it and hover again to refresh the count.

## Supported spirits

Copper, tin, iron, silver, gold, coal, mithril, luminite, adamantite, runite,
orichalcite, drakolith, necrite, phasmatite, banite, light animica, and dark animica.
Concentrated coal and gold rocks use their corresponding spirit count.

## Verify and package changes

Use Python with the `lupa` package's Lua 5.4 runtime:

```text
python tests/run.py
python tools/package.py
```

If `lupa` is installed in a separate directory, pass it with
`python tests/run.py --lua-packages PATH`.

The tests execute the actual entrypoint with substitutes for native API objects.
They also check every spirit variable name and ID against the supplied `VarPlayer`
dump and the backpack ID against `Inv`. They do not launch the RuneScape client.
The packaging script verifies each ZIP entry against the source file and writes
the result into `releases/`.

## Native data sources

`Inv` and `VarPlayer` are the supplied developer-console configuration dumps.
Backpack inventory `93` is `INV`. Spirit counts use
`MINING_OREBOX_<ORE>_STONE_SPIRIT_VAR`, with IDs `11514` through `11530`.
The mappings are explicit in `lib/catalog.lua`; luminite, silver, and gold are
not in the same order as their item IDs.

The ten unnoted box IDs are `44779` through `44797`, stepping by two. Their adjacent
noted IDs are excluded. Box and spirit item IDs were cross-checked against the
local RuneScape cache snapshot `2736`, build `950.1`.

The plugin uses [`VarType.value`](https://developer.runescape.com/rs/game/config/vartype.html)
for current counts and [`MiniMenuEntry.overrideText`](https://developer.runescape.com/rs/game/minimenu.html)
to append the label during `MiniMenuReady`. Inventory events invalidate the carried
box check. It has no Draw or Logic callback, persistent storage, or background scan.
