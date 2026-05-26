# Changelog

## 0.2.0

### New features

- **Macro bindings** — the sphere's left and right click can now be set to a full macro instead of a single spell. Type any multi-line macro directly into the settings panel (conditionals, focus targets, cancel-aura, multi-step sequences — everything a normal macro supports). Macros are saved automatically and don't use any of your macro slots.
- **Sphere click animation** — a ring ripples outward from the sphere on every click.
- **Improved settings panel** — rebuilt from scratch with scrollable spell lists that support mouse wheel scrolling. Shows every spell you know rather than a fixed list, so nothing is ever missing.

### Bug fixes

- Food picker icons no longer vanish when you click a food to select it or hold the right mouse button to feed.
- The food picker no longer shows buttons in a stuck "pressed" state when reopened after a selection.
- Settings panel now opens correctly on all clients (fixed a backdrop API incompatibility with the Anniversary client).

---

## 0.1.0

Initial release.

- Sphere UI with aspect color, ammo count, pet happiness ring, and sting duration bar.
- Orbit buttons for Aspects, Pet actions, Traps, Tracking, and Feed Pet.
- Live trap cooldown countdown on the button and in the open menu.
- Food picker with diet filtering, item level sorting, pet-buff treats first, and live stack count badge.
- Sphere click bindings for any known spell via the settings panel.
