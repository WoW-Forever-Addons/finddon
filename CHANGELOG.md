# Changes

## 0.7.0

- **What a vendor sells, with prices:** click a vendor in the list and a narrow window opens beside the search window with everything it sells: the game's icon, the name in its quality colour and the price. Click another vendor and it shows that one's goods; an NPC without goods closes it.
- **Limited supply marked:** goods a vendor does not always have in stock say so.
- **Already known and not usable:** a recipe your character knows, or an item it cannot use, has a red icon as at the vendor, and "Already known" under its name.
- **The game's own tooltip** on every item; Shift-click links it in chat, Ctrl-click tries it on.
- **Event NPCs hidden:** NPCs that are only there during a world event (Feast of Winter Veil, Hallow's End, Lunar Festival, Darkmoon Faire and others) no longer show up all year. The new option "Show event NPCs" lists them again, with the event's name in the row.
- Prices are the base prices without reputation discount; once you have opened a vendor's window, Finddon shows the prices seen there.
- **Nearby overview:** with no role and no search text picked, the list shows the nearest NPC of each of your favourite roles; without favourites it shows the nearest inn, bank, flight master, repair vendor and mailbox.
- **Goods of the new Forever vendors:** vendors added by Forever now list what they sell, so the goods window is no longer nearly empty in the new zones such as Riverglades.
- **Learning at vendors fixed:** Finddon learns what a vendor sells again when the vendor window is filtered to your class; it adds the filtered part to its list, and "All" gives the whole list.
- **Smoother login:** NPCs and goods are read in small steps after login instead of in one go.
- **Data of 24 November:** NPC and goods data refreshed.
- **Tabs and list headers in the game's look:** group headers in lists are the game's own bars, with plus and minus on the right.
- **Options open in their own window:** the options button, the cog, the minimap button and `/fd options` open only Finddon's own options window. Tooltips of wide rows now sit beside the mouse and no longer cover the search box.

## 0.6.4

- **Smoother play:** with the window open the list no longer searches everything again every 2 seconds while you move. The hits keep their place and only get new distances; the list is drawn again only when the order changes.
- **The list holds still under the mouse:** while the mouse is on the hits they are not reordered, so no row moves away under the cursor.
- **Faster searches:** a search draws the list once instead of three times, and setting or clearing the arrow no longer rebuilds the whole window.

## 0.6.3

- **Fix:** an error after login ("Data.lua:183: attempt to perform indexed assignment on upvalue 'npcById'") when the NPC data was looked up before the first search.

## 0.6.2

- **Data of 21 November:** NPC data refreshed with the recordings of more players.

## 0.6.1

- **Smoother first vendor visit:** the vendor and NPC data are read a few seconds after login instead of at the first vendor, and an unchanged vendor list is not stored again.

## 0.6.0

- **What a profession trainer teaches:** every trainer row says what the NPC really teaches, for example "Skill 150-225, learnable from 125, level 20". Also Expert books at vendors, Artisan through quests (fishing, cooking, first aid) and specialisations.
- **Special crafting places in dungeons:** the Black Anvil, the Black Forge, the alchemy lab and the Icebellow Anvil can be found; the arrow and the pin lead to the dungeon entrance.
- **Transmog:** a new role under services finds the transmog NPCs in Stormwind, Orgrimmar and Dalaran in Alterac.
- **Data of 21 November:** about 3,900 NPCs, more learned from play.
- **One option for the window style:** the switch "Windows in the game's look" is now the choice "Window style" with "Don look" and "Blizzard look", named the same in every Don addon. Your setting stays as it was.
- **Shared Don library:** updated to the current version of the Don addons.

## 0.5.0

- **Finddon in the game's look:** the search window now has the game's own frame, buttons, search box and lists. The options open in the game's settings (Options > AddOns > Finddon). This is the new default; the Don look is one switch away under General, "Windows in the game's look".
- **`/fd diag`:** the report opens in a window you can copy from, in the game's look. `/fd diag chat` prints it in the chat as before.
- **Shared Don library:** updated to the current version of the Don addons.

## 0.4.3

- **Map pin:** the name under the pin on the world map no longer sits on a dark plate; an outline keeps it readable.

## 0.4.2

- **Search with a role chosen:** with a role picked on the left, the search box no longer hides everything else. What the text finds outside that role follows below in a part of its own, "Other roles", nearest first; the footer counts it.
- **Shared kit:** small fixes of the common window kit (table heads, options).

## 0.4.1

- **Cleaner text in narrow places:** text that is shrunk to fit keeps one font and size, also after the game window changes its size.

## 0.4.0

- **Search by goods:** type what you want to buy ("thread", "apple", "recipe") and the list shows the nearest vendors that sell it, with the item in the row and everything that matches in the tooltip. About 2,000 items of all vendors; limited supply is marked.
- **Groups of goods:** the new group "Goods" in the role list: drinks, meat, fish, fruit, bread, cheese, mushrooms (what a hunter's pet eats), trade goods, recipes and bags (`/fd drinks`, `/fd go meat`).
- **Learns in the game:** when you open a vendor's window, Finddon reads what it really sells and uses that list from then on. The shipped lists come from Classic data and ForeverDB and can differ for some vendors.
- **Large preview off by default:** the big 3D model under the role list is an option now ("Large NPC preview"); the small pictures in the rows stay.
- Item names are English in the data; in other languages the game's own names are loaded bit by bit and searched as well.

## 0.3.0

- **All NPCs with a function:** quest NPCs and every other NPC you can talk to are in the data now, about 3,500 NPCs instead of 1,950. Type a part of the name and click the hit for arrow and pin.
- **New roles:** "Quest NPCs" and "Other NPCs" in the role list (`/fd quest`); a small quest symbol behind the name shows that a vendor or trainer also has quests.

## 0.2.0

- **NPC pictures:** every hit shows the NPC's 3D model instead of the role symbol, and a large preview appears over the lower part of the role list while the mouse is on a hit (window tall enough; option "NPC pictures"). WoW Forever's new NPCs may have none.
- **Cooking fires:** the new role "Cooking fire" lists the campfires, braziers and stoves around you, nearest first (`/fd cooking fire`).
- **Show on map:** the button "Map" in every row (or `/fd map <text>`) sets arrow and pin and opens the world map on that zone.
- **A pin you can see:** the map pin is the role's symbol in a gold frame with the NPC's name on a dark plate.
- **The game's own symbols:** bank, auction house, innkeeper, flight master, repair, reagents, food, ammunition, stable master and mailbox carry the symbols of the minimap search; the pin is round in a gold ring.
- **More places:** mailboxes, anvils and forges are roles of their own (group "Places"), and a cooking fire says what it is (campfire, fireplace, brazier, stove, cauldron).
- **The list in parts:** "In this zone", "Neighbouring zones" and "Further away", each to fold; the distance is green when near and yellow a bit further, and a hit on another continent names that continent.
- **Other roles at a glance:** small symbols behind the name show what else an NPC does (a vendor who also repairs).
- **Favourites:** right-click a role to put it into a group at the top; your own class trainer stands in your class colour.
- **Preview:** title, zone and a rare's level under the model, which turns slowly.
- **Footer:** click "Arrow: name" to drop arrow and pin.
- **Fold the role groups:** click a group header (Trainers, Vendors ...) to fold it.
- **Role names in full:** the names in the role list were cut after a few letters ("Rep...", "Innk..."); they now use the whole row.

## 0.1.1

- Not released on its own (the role names went into 0.2.0).

## 0.1.0

- **First version.** Find the nearest NPC by role: class trainers (your own class first), profession trainers, weapon masters, riding and pet trainers, vendors, repair, reagents, food and drink, ammunition, innkeepers, banks, auction houses, flight masters, stable masters and rares.
- **Search by name or title:** type a part of a name or a title such as "Weaponsmith"; `/fd <text>` does the same from the chat.
- **Nearest first:** hits are sorted by the distance from where you stand, with zone and distance in each row; your own faction and neutral NPCs (the other faction as an option).
- **Arrow and pin:** a click on a hit sets DonMap's direction arrow and a pin on the world map and the minimap. A right click, `/fd clear` or arriving drops them. `/fd go <text>` sets the arrow to the nearest hit at once.
- About 1,950 NPCs; NPC names are English in this version, roles and the interface in nine languages.
