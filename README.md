# scripts_2026

Lua scripts for the game client. `api.lua` and `slib.lua` are the client libraries.

## utils

Shared helpers used by `fisher.lua`, `woodcutter.lua`, `cooker.lua`, `smelter.lua`, `miner.lua`, `firemaker.lua` and `fletcher.lua`:

| Module | Require | Functions |
| --- | --- | --- |
| `utils/movement.lua` | `require("utils.movement")` | `isNear(tile, radius)`, `moveTo(tile)`, `copyTile(tile)` |
| `utils/items.lua` | `require("utils.items")` | `lowerName(item)`, `find(matches)`, `dropAll(matches)`, `fill(box, matches)` (wood/ore box) |
| `utils/objects.lua` | `require("utils.objects")` | `nearest(objects, matches)` |
| `utils/banking.lua` | `require("utils.banking")` | `TypeNames` (Auto, Bank booth, Bank chest, Banker), `find(typeName)`, `open(typeName)` (bank chests use "Use", booths and bankers "Bank"; returns `false` when no bank is nearby), `findItem(matches)` (first matching bank item), `close()` (presses Escape) |
| `utils/production.lua` | `require("utils.production")` | `isMakeXOpen()`, `confirm()` (Space) |
| `utils/gui.lua` | `require("utils.gui")` | `indexOf`, `combo(label, value, options)`, `tile`, `text`, `checkbox`, `controls(config, state)` (radius input only when `config.AreaRadius` is set), `show(title, draw)` |

Every banking script has a **Bank type** dropdown. Auto uses the nearest bank and the right action for it.

The modules are named `Banking` and `Items` so they don't shadow the client's `Bank` and `Inventory` globals.

## cooker.lua

Stand between a bank and a range or fire. Each trip deposits the inventory, withdraws one type of raw food from the bank and cooks it. It only takes raw foods from its RS3 Wiki table that are at or below your Cooking level, and it stops once there is nothing left to cook. It cooks with the wiki's cook action for each station, never the left-click option: "Cook at" (or the older "Cook-at") on ranges and clay ovens, "Cook on" on permanent bonfires and fire pits, and "Use" on player-lit fires. Permanent bonfires also have "Add logs to", which players can make their left-click option. `Station action` overrides the cook action.

## miner.lua

Mines one rock type at a wiki location. Locations run from Lumbridge copper up to Varrock adamantite, and "By level" moves to the best one your Mining level allows. When the inventory fills up, it fills the ore box first. Then it either banks (emptying the ore box too) or, in power mining mode, drops the ore. While mining it clicks rockertunity rocks, and clicks the rock again when stamina runs low. The rockertunity highlight IDs (7164/7165) and the stamina threshold come from community mining scripts, not from `api.lua`.

## fletcher.lua

Stand near a bank. Each trip withdraws the best logs your Fletching level allows, uses "Craft" on them and presses Space in the Make-X window to cut them into shafts. It stops once no logs are left. Make-X remembers the last product picked, so if a bow or crossbow stock comes out, the script stops and asks you to pick Shaft once by hand.

## firemaker.lua

Stand near a bank. Each trip withdraws the best logs your Firemaking level allows and adds them to a bonfire, and it stops once no burnable logs are left. It also clicks fire spirits when they appear (the "Collect fire spirits" checkbox, on by default). In **Make bonfire** mode it walks to the fire spot you set and lights a fire there. Pick a spot a few tiles from the bank, because fires can't be lit right next to one. In **Permanent bonfire** mode it uses the nearest "Bonfire" or "Fire pit", for example at Yeti Town, Prifddinas or Menaphos. Permanent bonfires and fire pits get the "Add logs to" action by name, because players can make "Cook on" their left-click option. Player-lit fires only have "Use", so logs are used on them instead (`0x24` with `API.GeneralObject_route_useon`).

## smelter.lua

Stand at a furnace with your ores in its metal bank. It opens the furnace's smelting window and picks the best bar your Smithing level allows that the metal bank has ores for. It smelts a batch, deposits the bars back into the metal bank, and stops once no bar can be made. The first time it opens the window, it clicks each slot in the bar list once to learn which slot holds which bar. The smelting window numbers (window 37 and values 8333, 8336 and 2228) come from community smelting scripts, not from `api.lua`.

## lodestones.lua

`require("lodestones")`, then `LODESTONES.<NAME>.Teleport()` or `LODESTONES.<NAME>.IsAtLocation()`.

## Tests

```sh
lua tests/utils_test.lua
# or, without a local Lua:
docker run --rm -v "$PWD":/w -w /w nickblah/lua:5.4 lua tests/utils_test.lua
```
