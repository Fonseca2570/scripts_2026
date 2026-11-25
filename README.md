# scripts_2026

Lua scripts for the game client. `api.lua` and `slib.lua` are the client libraries.

## utils

Shared helpers used by `fisher.lua`, `woodcutter.lua`, `cooker.lua`, `smelter.lua`, `miner.lua`, `firemaker.lua`, `fletcher.lua`, `smither.lua` and `gemminer.lua`:

| Module | Require | Functions |
| --- | --- | --- |
| `utils/movement.lua` | `require("utils.movement")` | `isNear(tile, radius)`, `moveTo(tile)` (Slib:MoveTo to 3 tiles short of it on the player's side, since spot tiles are usually the object itself and can't be stood on), `copyTile(tile)`, `isUnderground(tile)` (y above 6400), `goTo(tile, radius, entrance)` (walks and returns true on arrival; with `entrance = { Tile, Object }` it climbs down the object at that surface tile, or up the nearest one, to cross between the surface and an underground map) |
| `utils/items.lua` | `require("utils.items")` | `lowerName(item)`, `find(matches)`, `dropAll(matches)`, `fill(box, matches)` (wood/ore box) |
| `utils/objects.lua` | `require("utils.objects")` | `nearest(objects, matches)`, `nearestTo(objects, tile, maxDistance, matches)` (measured from a tile, not the player) |
| `utils/player.lua` | `require("utils.player")` | `isBusy()` (animating, moving or processing), `waitUntilBusy()` (waits up to ~3s after a click so the next loop doesn't click again), `waitUntilIdle()` (waits up to ~10s for an action already under way to finish) |
| `utils/banking.lua` | `require("utils.banking")` | `TypeNames` (Auto, Bank booth, Bank chest, Banker), `find(typeName)`, `open(typeName)` (bank chests use "Use", booths and bankers "Bank"; returns `false` when no bank is nearby), `findItem(matches)` (first matching bank item), `close()` (presses Escape) |
| `utils/production.lua` | `require("utils.production")` | `isMakeXOpen()`, `confirm()` (Space) |
| `utils/gui.lua` | `require("utils.gui")` | `indexOf`, `combo(label, value, options)`, `tile`, `text`, `checkbox`, `controls(config, state)` (radius input only when `config.AreaRadius` is set), `show(title, draw)` |

Every banking script has a **Bank type** dropdown. Auto uses the nearest bank and the right action for it.

The modules are named `Banking` and `Items` so they don't shadow the client's `Bank` and `Inventory` globals.

## cooker.lua

Stand between a bank and a range or fire. Each trip deposits the inventory, withdraws one type of raw food from the bank and cooks it. It only takes raw foods from its RS3 Wiki table that are at or below your Cooking level, and it stops once there is nothing left to cook. It cooks with the wiki's cook action for each station, never the left-click option: "Cook at" (or the older "Cook-at") on ranges and clay ovens, "Cook on" on permanent bonfires and fire pits, and "Use" on player-lit fires. Permanent bonfires also have "Add logs to", which players can make their left-click option. `Station action` overrides the cook action.

## miner.lua

Mines one rock type at a wiki location. Locations run from Lumbridge copper up to Varrock adamantite (iron is the Varrock south-west mine, banking at Varrock west), and "By level" moves to the best one your Mining level allows.

The Location dropdown also has **bar combinations**, which mine both ores of a bar at one mine. Each bar takes one of each ore (RS3 Wiki):

| Combination | Mine | Bank |
| --- | --- | --- |
| Bronze: copper + tin | Lumbridge SE | Al Kharid |
| Steel: iron + coal | Lumbridge SW | Draynor |
| Mithril: mithril + coal | Legends' Guild SW (members) | Ardougne south |
| Adamant: adamantite + luminite | Anachronia Western Ruins (members) | Anachronia base camp chest (must be unlocked) |
| Rune (F2P): runite + luminite | Mining Guild (60 Mining, ladder in SE Falador) and the Dwarven luminite mine (staircase in NE Falador) | Falador east |
| Adamant (F2P): adamantite + luminite | Varrock SE (adamantite) and the Dwarven luminite mine | Varrock east for adamantite, Falador east for luminite |

Adamant and rune use luminite instead of coal since the 2019 rework. Free-to-play luminite only exists in the Dwarven mines under Falador, so the F2P combinations climb down an entrance (`Ladder` at 3020,3339 for the Mining Guild, `Staircase` at 3060,3378 for the Dwarven mines) and climb back up to bank. Each ore of a combination can have its own bank. Each trip mines one ore until the inventory is full. After banking, the next trip picks whichever ore the bank has fewer of, so the two even out over the trips. The first trip starts with the first ore. "By level" never picks a combination. When the inventory fills up, it fills the ore box first. Then it either banks (emptying the ore box too) or, in power mining mode, drops the ore. While mining it clicks rockertunity rocks, and clicks the rock again when stamina runs low. A rockertunity is a nameless highlight object (type 4) on top of a rock, so the script clicks the rock of the chosen type nearest to the highlight (within 2 tiles), on the rock's own tile. After every click it waits for the player to start moving or mining, so it doesn't click the rock again straight away. Stamina counts as low at 30% of the highest stamina reading seen this run, because maximum stamina grows with Mining level; the GUI shows the current reading and that maximum. The rockertunity highlight IDs (7164/7165) come from community mining scripts, not from `api.lua`.

## gemminer.lua

Power mines gems in Burthorpe mine, which only has common gem rocks (RS3 Wiki). Start it inside the mine: it mines the nearest "Common gem rock" and never walks or banks. When the backpack is full it cuts every uncut gem your Crafting level allows ("Craft" on the gem, using the tool belt's chisel, confirmed in the Make-X window), then drops all uncut, cut and crushed gems. Opal, jade and red topaz can be crushed while cutting. It stops if the backpack is full of anything else.

| Gem | Crafting level |
| --- | --- |
| Uncut lapis lazuli | 1 |
| Uncut opal | 1 |
| Uncut jade | 13 |
| Uncut red topaz | 16 |

## fletcher.lua

Stand near a bank and pick a **Product**:

- **Shafts:** each trip withdraws the best logs your Fletching level allows, uses "Craft" on them and presses Space in the Make-X window. It stops once no logs are left. Make-X remembers the last product picked, so if a bow or crossbow stock comes out, the script stops and asks you to pick Shaft once by hand.
- **Headless arrows:** each trip withdraws all shafts and feathers, uses a feather on the shafts and presses Space in the Make-X window. It stops once the bank runs out of either.

## firemaker.lua

Stand near a bank. Each trip withdraws the best logs your Firemaking level allows and adds them to a bonfire, and it stops once no burnable logs are left. It also clicks fire spirits when they appear (the "Collect fire spirits" checkbox, on by default). In **Make bonfire** mode it lights a fire where you stand, so start a few tiles from the bank, because fires can't be lit right next to one. After every click on a fire it waits for the player to start moving or burning, so it doesn't keep clicking the bonfire. In **Permanent bonfire** mode it uses the nearest "Bonfire" or "Fire pit", for example at Yeti Town, Prifddinas or Menaphos. Permanent bonfires and fire pits get the "Add logs to" action by name, because players can make "Cook on" their left-click option. Player-lit fires only have "Use", so logs are used on them instead (`0x24` with `API.GeneralObject_route_useon`).

## smelter.lua

Stand at a furnace with your ores in its metal bank. The furnace ("Furnace") and its "Smelt" and "Deposit-all (into metal bank)" actions are fixed in the script. It opens the furnace's smelting window and picks the best bar your Smithing level allows that the metal bank has ores for. It smelts a batch, deposits the bars back into the metal bank, and stops once no bar can be made. The first time it opens the window, it clicks each slot in the bar list once to learn which slot holds which bar. The smelting window numbers (window 37 and values 8333, 8336 and 2228) come from community smelting scripts, not from `api.lua`.

## smither.lua

Stand between an anvil and a forge, for example in the Artisans' Workshop. Pick the item in the smithing window once by hand.

- **Unfinished item in the backpack:** it keeps smithing it with "Smith" on the anvil.
- **No unfinished item:** it opens the smithing window ("Open smithing interface" on the anvil) and presses Begin Project, which repeats the last item picked. If no item appears, for example because the bars ran out, it stops.
- **Heat:** while smithing, it reheats with "Heat" on the forge whenever the heat drops below the threshold, and waits for the heating to finish before going back to the anvil.
- **Full heat start:** pick the **Metal** in the GUI. Once your Smithing level reaches the level where new items of that metal start at maximum heat (RS3 Wiki Heat page: bronze 6, iron 16, steel 28, mithril 36, adamant 41, rune 59, orikalkum 63, necronium 76, bane 87, elder rune 98, primal 108), it never goes to the forge and only smiths at the anvil.

High heat, where each strike makes double progress, starts at two thirds of the maximum heat (RS3 Wiki). The heat is read from the bar over the player (`API.LocalPlayer_HoverProgress()`), which isn't in the wiki's heat units, so the script reheats once the bar drops below two thirds of the highest reading seen this run. A visit to the forge fills the bar, so the maximum settles after the first reheat. The GUI shows the reading, the maximum and the threshold, and **Reheat below** sets a fixed threshold instead. The smithing window numbers (interface 37, Begin Project 163, status 85) are the same community values `smelter.lua` uses.

## lodestones.lua

`require("lodestones")`, then `LODESTONES.<NAME>.Teleport()` or `LODESTONES.<NAME>.IsAtLocation()`.

## Tests

```sh
lua tests/utils_test.lua
# or, without a local Lua:
docker run --rm -v "$PWD":/w -w /w nickblah/lua:5.4 lua tests/utils_test.lua
```
