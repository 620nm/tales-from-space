# Laptop

The laptop starts closed and switched off. Creation assigns one wallpaper
from `wallpaper_bliss` and `wallpaper_moonlake`; that selection stays with
the item through handoffs, lid changes and power cycles. Wallpapers fill the
16:9 screen with hard pixel scaling. An open, powered laptop uses an animated
green screen sprite in the world and inventory.

## Three steps, three presses

Opening a laptop is the lid, then the power button, then the screen, and no
press does two of them. The hover card names the step the next press takes:
Open lid on a closed one, Power on once the lid is up, View interface once it is
running.

- Self-use or right-click raises the lid of a closed laptop. Nothing boots
  and no window opens. A laptop that kept its charge comes up already
  running; an unpowered one shows its dark screen.
- The same gesture on an unpowered open laptop switches it on, with the
  startup sound and a refresh for every current reader.
- Once powered, the same gesture shows the 16:9 desktop without toggling
  power. Alt-click offers Close lid only while open, powered or not; on a
  closed laptop that hint is absent and the gesture does nothing.

The desktop's Power control switches power on or off. Its Close lid control
and Alt-click both close the lid and every reader's window, preserving power.
The titlebar × dismisses only that reader's window and leaves the lid open.
Closed laptops reject stale desktop acts.

Switching off leaves the desktop window available with a black screen and
controls. All current readers see power and slot changes together.

## Slots

Hold an ID card or floppy cartridge in the active hand and click the laptop
to insert it; an occupied slot swaps its previous item into the inserting
hand. This works on the floor, in the other hand and inside an opened
container, including nested bags. A hand holding either one reads the
laptop's own row as Insert cartridge or Insert ID card.
The input glyphs show a plus and the active item's 32×32 sprite on this
row, in world and inventory hover cards. Inspect and unrelated shortcuts
stay key-only; descriptions retain one shared left edge.
Insertion actions select the held card or disk explicitly and use the
receiver route with `uses_held = true`. They read the same on a closed
laptop: insertion takes the card or disk whatever the lid is doing.
The desktop ejects either slot. Shift+Ctrl-click
ejects the floppy and Shift+Ctrl right-click the card; each row is offered
only while that slot holds something, which the laptop keeps as its `media`
and `card` hint flags. Cards retain their identity and disks retain their
files.

Inventory squares honor the same declared right-click, Alt-click and
Shift+Ctrl gestures as the laptop on the floor. Shift-click examines.
Undeclared modified presses never move an item or open a container. With
an empty active hand, bare clicks retain hand selection and container
navigation; using the active hand's own square does not apply it to itself.

## Files

The powered desktop shares the programming terminal's file workspace: A: is
the laptop's 64 KiB, 16-file store, and an inserted floppy appears as B:.
Native providers validate every file operation. Switching off revokes file
disclosure and actions without losing saved files. A desktop left open while
switched off has no native file workspace: composition follows power, not
the lid.

The screen below the trusted title bar stays 16:9. Its wallpaper lies beneath
translucent information, drive and reader frames. Drive panes resize locally;
removing B: expands the center reader. The title bar shows the actual owner
sprite and provides maximize/restore and reader-local dismissal.

New offers Markdown (`.md`), Luau source (`.disl`), atmosphere records (`.atmo`)
and access material (`.pem`). Source uses the trusted editor and native
diagnostics. Markdown is bounded, inert content. Valid ATMO JSON has a pack
reader; malformed or empty records stay editable. PEM files are ordinary
text: writing one grants no credentials or authentication authority.

Save/Discard/Cancel protects unsaved work when changing files or dismissing
the workspace. Save waits for a matching accepted revision before continuing.
Disk ejection guards only dirty work on B:. Revoked providers, lost media and
closed documents cancel pending continuations.

## Contact programming

Use an open, powered laptop on a reachable scriptable device to open its
programming workspace. A: belongs to the target. The source selector chooses
whether B: shows the laptop's own store or its inserted disk. Copy works in
both directions; edit target files and load or unload its sockets there.
Only host files run. Changing the source clears the file selection and stale
store bindings. Switching hands, dropping or closing the laptop, losing reach,
or the target losing power or access closes the contact workspace.

## Typing

An open, powered laptop used on an exact networked device plays one of the
seven keyboard recordings, chosen uniformly. Closed or switched-off laptops
and targets without a network endpoint do not produce typing sounds.

## Reference

Paths below are relative to the read-only tgstation checkout.

- `code/modules/modular_computers/computers/item/laptop.dm:68-72`:
  self-use on a closed lid raises the lid and stops there;
  `:74-85` the Toggle Open verb; `:89-95` Alt-click; `:95-105`
  right-click reaching self-use.
- `code/modules/modular_computers/computers/item/computer.dm:564-590`:
  the power button as its own press, with its start-up sound and message.
- `code/modules/modular_computers/computers/item/computer.dm:297-323`:
  ID insertion and swapping; `:557-562`: the Ctrl+Shift disk gesture.
- `code/game/sound/sound_keys/sound_keys.dm:458-467`: keyboard roster.

Lid, power and screen remain separate presses; Alt-click closes an open lid
as in the reference. Accessible inventory items support the same gestures,
including laptops in bags. Battery drain, modular hardware, programs and
background computer audio are absent.
