# Laptop

The laptop starts closed and switched off. Creation assigns one wallpaper
from `wallpaper_bliss` and `wallpaper_moonlake`; that selection stays with
the item through handoffs, lid changes and power cycles.

Self-use or right-click opens the lid, switches on and shows a
16:9 desktop. An already open laptop uses the same gesture to switch on
or show its desktop. Alt-click closes its lid without switching it off.
The desktop's Close lid control closes the lid and every reader's window.
The titlebar × dismisses only that reader's window and leaves the lid open.

Power switches the open laptop on or off. Switching off leaves the desktop
window available with a black screen and controls. All current readers see
power and slot changes together. Closed laptops reject stale desktop acts.

Apply an ID card or floppy disk to insert it; an occupied slot swaps its
previous item into the inserting hand. The desktop ejects either slot.
Ctrl+Shift-click ejects the floppy. Cards retain their identity and disks
retain their files; the desktop exposes no file browser or applications.

An open, powered laptop used on an exact networked device plays one of the
seven keyboard recordings, chosen uniformly. Closed or switched-off laptops
and targets without a network endpoint do not produce typing sounds.

## Reference

Paths below are relative to the read-only tgstation checkout.

- `code/modules/modular_computers/computers/item/laptop.dm:68-122`:
  self-use, right-click, Alt-click and independent lid state.
- `code/modules/modular_computers/computers/item/computer.dm:297-323`:
  ID insertion and swapping; `:557-562` and `:1023-1033`: disk gestures.
- `code/modules/modular_computers/computers/item/computer_ui.dm:40-44`
  and `:147-148`: boot on interaction and desktop shutdown.
- `code/game/sound/sound_keys/sound_keys.dm:458-467`: keyboard roster.

Opening and booting in one gesture is this pack's deliberate departure from
tg's separate closed-lid self-use and subsequent interaction. Battery drain,
modular hardware, programs and background computer audio are absent.
