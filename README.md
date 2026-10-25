# Stone Spirit Spy

Stone Spirit Spy shows your ore-box stone spirits beside the cursor when you hover
over a rock, without clicking. It also adds the count to the right-click menu.
Enable **Number only** for a shorter label:

```text
Copper rock (17)
```

Carry an unnoted ore box from Bronze through Elder Rune. The plugin reads your
character's shared ore-box spirit counts directly, so you do not need to inspect
or hover over the box first. Loose spirits in your backpack and bank are excluded.
Multiple boxes do not multiply the displayed count. Banking your boxes removes
the annotation.

Version **0.2.0** adds a cursor-side hover label and saved display settings.

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

## Change the display

Open **Plugin Hub > Manage > Stone Spirit Spy** and select its gear icon.

- **Show count on hover:** On by default. Shows the rock name and spirit count
  beside the cursor without right-clicking. Turn it off to keep only the menu count.
- **Number only:** Off by default. Turn it on for `Copper rock (17)` instead of
  `Copper rock (17 Copper Stone Spirits)`. This affects both displays.

Both settings are saved immediately and restored when the plugin reloads.
The hover label lets clicks pass through, so you can mine normally. It hides when
you move off the rock, open a right-click menu, or switch away from the game window.

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
9. Enable **Number only** in the plugin settings. Check that hover and right-click
   counts both use the shorter label. Reload and confirm the setting stays on.
10. Turn **Show count on hover** off. Check that the cursor label disappears while
    the right-click count remains available.

If a count says `unavailable`, the native field could not be read. This differs
from a confirmed empty box, which displays zero. A right-click menu keeps the
snapshot taken when it opened. Close it and hover again to refresh the count.
In number-only mode, an unavailable count displays `?`.

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

The tests execute the actual entrypoint with substitutes for native API and UI objects.
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
to append menu labels during `MiniMenuReady`. The highest-priority entry supplies
the cursor-side label. The label uses native Text, Layer, and Rectangle components.
The [settings layer](https://developer.runescape.com/rs/core/events.html#settingslayerready)
contains the display toggles, saved as two PersistentDB booleans.
Inventory events invalidate the carried-box check. There are no Draw or Logic
callbacks, stored spirit-count snapshots, or background scans.
