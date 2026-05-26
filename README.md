# Quiver

A hunter class addon for **WoW TBC Classic Anniversary** (Interface 20504), modeled after the Necrosis warlock addon. The idea is a single draggable orb on screen that gives you one-click access to every hunter mechanic — aspects, traps, stings, pet management, and tracking — without cluttering your bars.

## How it works

A circular **sphere** sits on screen as your central hub. Five small buttons orbit it, one per mechanic category. Left-clicking a button opens that category's menu; right-clicking fires a quick-cast of your last selection from that menu. The sphere itself can be left- and right-click bound to any spell or macro via the settings panel (Alt+Right-click the sphere).

### The sphere

- **Color** reflects your active Aspect — green for Hawk, blue for Viper, yellow for Cheetah, and so on. No aspect = maroon pulse. Low mana without Viper active = blue pulse.
- **Ammo count** sits in the center. Turns red when you're running low.
- **Pet happiness** shows as a colored ring around the sphere edge (green/yellow/red).
- **Sting duration** bar runs along the bottom edge, tracking your active sting on the current target.
- **Click animation** — a ring ripples outward from the sphere on every click.

### Sphere click bindings

Left and right click can be bound to a **spell**, a **macro**, or left unbound. Configure via Alt+Right-click → Settings.

- **Spell** — pick from a scrollable list of every spell you know. Applies as `/cast SpellName`.
- **Macro** — type any multi-line macro body directly into the config panel. Supports everything a normal macro does: conditionals (`[mod:shift]`, `[@focus]`, `[@mouseover]`), `/cancelaura`, `/use`, multi-step sequences. Stored in your addon saved variables — no macro slots used.
- **None** — click does nothing.

Useful macro examples:
```
/cast [mod:shift] Feign Death; Hunter's Mark
```
```
/cast Feign Death
/cancelaura Feign Death
```
```
/cast [@focus,exists] Hunter's Mark; Hunter's Mark
```

### The menus

Each of the five orbit buttons opens a row of icons:

| Button | What it does |
|---|---|
| **Aspects** | Hawk, Viper, Cheetah, Pack, Wild, Monkey, Dragonhawk — only shows aspects you've learned |
| **Pet** | Call, Dismiss, Revive, Mend, Beast Training |
| **Traps** | Frost, Freezing, Immolation, Explosive, Snake — with live cooldown countdown |
| **Tracking** | Beasts, Humanoids, Demons, Undead, Giants, Elementals, Hidden |
| **Feed Pet** | Shows up to five suitable foods from your bags, sorted by item level |

For the spell menus (Aspects, Pet, Traps, Tracking): left-clicking a spell **selects** it as your quick-cast for that button; right-clicking casts it immediately. The orbit button's icon updates to show your current selection. If the selected spell is on cooldown, a dark overlay and live countdown (e.g. `9.3`) appear on the button.

Menus only show spells you've actually learned — if you haven't trained a spell yet, it doesn't appear.

### Feed Pet

The food picker shows foods your pet can actually eat (Meat, Fish, Bread, Cheese, Fruit, or Fungus depending on pet type), pulled from your bags and sorted by item level. Pet-buff treats (stat-boosting items) are listed first. Left-click a food in the picker to **select** it — the orbit button updates to that food's icon and shows a stack count badge. Right-click the orbit button at any time to feed immediately. Right-click a food in the open picker to feed with that food without changing your selection.

The stack count on the orbit button updates in real time as you feed or pick up food.

### Trap cooldowns

All traps share one cooldown timer in TBC. The countdown shows on both the individual trap icons in the open menu and on the traps orbit button itself, so you know at a glance whether you can drop a trap without opening the menu.

## Settings

Open with **Alt+Right-click** on the sphere.

Each click binding has three modes selectable via tabs:

- **Spell** — scrollable list of all your known spells with mouse-wheel support. Current selection highlighted in gold with a left-edge accent bar.
- **Macro** — multi-line text input. One command per line. No slot limits, persists automatically.
- **None** — disables that click.

## Installation

Drop the `Quiver` folder into your `Interface/AddOns/` directory and reload. The sphere appears in the center of screen on first load; drag it with Middle-click to reposition.

## Tech

- **Lua**, WoW API, Interface version `20504`
- [Ace3](https://www.wowace.com/projects/ace3) — AceAddon, AceEvent, AceDB, AceGUI
- Settings saved to `QuiverDB` (account-wide)
- Spell and macro bindings stored inline as secure button attributes — no macro slots consumed
