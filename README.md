# Stone Spirit Spy

Stone Spirit Spy adds your ore-box stone spirits to the game's existing hover box
when you hover over a rock. It also adds the count to the right-click menu.
Enable **Number only** for a shorter label:

```text
Copper rock (17)
```

Carry an unnoted ore box from Bronze through Elder Rune. The plugin reads your
character's shared ore-box spirit counts directly, so you do not need to inspect
or hover over the box first. Loose spirits in your backpack and bank are excluded.
Multiple boxes do not multiply the displayed count. Banking your boxes removes
the annotation.

Version **0.3.3** adds a selectable diagnostic report in the plugin settings.
A working native hover fix has not yet been confirmed in game.

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

- **Show count on hover:** On by default. Adds the count to the existing game hover
  box without right-clicking. Turn it off to keep the count only in the right-click menu.
- **Number only:** Off by default. Turn it on for `Copper rock (17)` instead of
  `Copper rock (17 Copper Stone Spirits)`. This affects both displays.
- **Match carried ore-box tier:** Off by default. Turn it on to hide hover and
  menu counts for spirits your highest-tier carried box cannot hold. Banked boxes
  are ignored. Carrying only Bronze shows copper and tin; carrying Bronze and
  Elder Rune together allows all supported spirit types.

Settings are saved immediately and restored when the plugin reloads.
The client keeps control of the hover box's position, visibility, and styling.
The plugin updates its text and widens the existing box to fit the count. It restores
the original text and dimensions when the count no longer applies.

## Record the missing hover count

1. Install this build and reload it with `prf`, then `prl StoneSpiritSpy`.
2. Carry an ore box and turn **Show count on hover** on.
3. Open the plugin's gear settings and click **Record hover diagnostics (5 seconds)**.
4. Close settings and hold the cursor over a Copper rock for five seconds.
   Keep the right-click menu closed.
5. Reopen the gear settings and click **Show diagnostic report**.
6. Click inside the report field, then press **Ctrl+A** and **Ctrl+C**.
   Paste it into the development chat or save it as `HoverReport.txt` in this repository.

The completed report stays fixed while you select and copy it. Opening the report
again restores its captured text if the field was accidentally edited. It remains
available until the plugin is reloaded or a new recording finishes. No console
transcription is needed.

The report includes the selected menu target, active display settings, the native
hover update result, and rock-related text found in four candidate UI panels.
The recorder reads candidate components only while recording, with at most sixteen
lookups per Draw. Its scan does not modify candidate labels. This gives live evidence
to check the current `TEXT_TOOLTIP` assumption instead of repeating it in a test fixture.

## Check the count in game

1. Carry an ore box containing a known amount of copper stone spirits.
2. Hover over a Copper rock. Check that the existing game hover box includes the
   matching spirit count and that no additional floating box appears.
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
10. Turn **Show count on hover** off. Check that the game's normal hover text remains
    without the count, while the right-click count stays available.
11. Turn **Match carried ore-box tier** on. Bank all boxes except Bronze. Check
    that copper and tin show counts, while iron and higher-tier rocks do not.
12. Withdraw an Elder Rune box while keeping Bronze. Check that higher-tier counts
    return. Bank Elder Rune again and check that the limit returns to Bronze.

If a count says `unavailable`, the native field could not be read. This differs
from a confirmed empty box, which displays zero. A right-click menu keeps the
snapshot taken when it opened. Close it and hover again to refresh the count.
In number-only mode, an unavailable count displays `?`.

## Supported spirits

Copper, tin, iron, silver, gold, coal, mithril, luminite, adamantite, runite,
orichalcite, drakolith, necrite, phasmatite, banite, light animica, and dark animica.
Concentrated coal and gold rocks use their corresponding spirit count.

Tier matching follows the [ore-box storage table](https://runescape.wiki/w/Smithing/Smithing_tables#Ore_boxes).
Steel adds coal and silver, and Adamant adds adamantite, luminite, and gold.

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
the pending native hover annotation. `Draw` applies it to the existing `TEXT_TOOLTIP`
text component after the client generates the base hover text. The native layout
was checked against cache snapshot `2736`, build `950.1`: component `15` is the text,
and component `1` is its box. Component type, visibility, and rock-name checks keep
the annotation scoped to the matching tooltip. No hover UI components are created.
The [settings layer](https://developer.runescape.com/rs/core/events.html#settingslayerready)
contains the display toggles, saved as three PersistentDB booleans.
Inventory events invalidate the carried-box check. The Draw callback returns
without native lookups when there is no relevant hover target. There is no Logic
callback, stored spirit-count snapshot, or background scan.
