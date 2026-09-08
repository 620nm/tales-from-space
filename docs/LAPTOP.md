# Laptop

The laptop starts closed and switched off. Creation assigns one wallpaper
from `wallpaper_bliss` and `wallpaper_moonlake`; that selection stays with
the item through handoffs, lid changes and power cycles. Wallpapers fill the
16:9 screen with hard pixel scaling. An open, powered laptop uses an animated
green screen sprite in the world and inventory.

## Three steps, three presses

Opening a laptop is the lid, then the power button, then the screen, and no
press does two of them. The hover card names the step the next press takes:
Open lid on a closed one, Power on once the lid is up, Power off once it is
running.

- Self-use or right-click raises the lid of a closed laptop. Nothing boots
  and no window opens. A laptop that kept its charge comes up already
  running; an unpowered one shows its dark screen.
- The same gesture on an open laptop is its power button, on or off, with
  the startup or shutdown sound and a refresh for every current reader.
- Alt-click on an open laptop shows the 16:9 desktop, powered or not. On a
  closed one it says Lid closed and does nothing.

The desktop's Power control switches the same power the gesture does. Its
Close lid control closes the lid and every reader's window; that control is
the only way to close a lid. The titlebar × dismisses only that reader's
window and leaves the lid open. Closed laptops reject stale desktop acts.

Switching off leaves the desktop window available with a black screen and
controls. All current readers see power and slot changes together.

## Slots

Apply an ID card or floppy disk to insert it; an occupied slot swaps its
previous item into the inserting hand. A hand holding either one reads the
laptop's own row as Insert disk or Insert ID card rather than Take, which
is what that click does. That variant sits on `primary.held`, because the
insertion IS the plain click, and it reads the same on a closed laptop:
the interact route takes the card or the disk whatever the lid is doing.
The desktop ejects either slot. Shift+Ctrl-click
ejects the floppy and Shift+Ctrl right-click the card; each row is offered
only while that slot holds something, which the laptop keeps as its `media`
and `card` hint flags. Cards retain their identity and disks retain their
files; the desktop exposes no file browser or applications.

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

Where this departs from tg: Alt-click shows the desktop rather than closing
the lid, so the three steps each own a gesture and the lid closes from the
screen it opened. Battery drain, modular hardware, programs and background
computer audio are absent.
