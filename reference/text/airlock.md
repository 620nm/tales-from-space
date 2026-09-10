# Airlock controller

Join two doors, two wall buttons and a external airlock pump to one powered access
point or air alarm. The default program expects the interior door west of
the exterior door. Connect the vent's intake to pipe layer 2 and its effluent
to layer 4.

Insert this disk into the access point or air alarm. Open and power on the
laptop, then hold it and click that host. Drive A is the host's internal
storage; drive B is the disk inside the host. Copy airlock.disl from B to A,
then load the A copy into the controller socket. The laptop provides the
screen and keyboard; its own disk is not shown while connected to a device.

The orange disk holds read-only originals. The box of disks supplies eight
blank disks for your own copies. To read a disk on the laptop itself, insert
it into the laptop and open its file manager.

Both buttons advance the same sequence: entry, exit, entry again. A press
can interrupt a running cycle. Entry closes and bolts the exterior before
filling to at least 100 kPa and opening the interior. Exit closes and bolts
the interior before draining below 10 kPa and opening the exterior.

Edit the host copy to change the program. The permitted function accepts
everyone by default; returning request.engineering restricts each press
to engineering access. Originals on this disk are fixed; copies are editable.

The program is written in Luau. Lines starting with -- are notes for you.
Start with the permitted function near the top, then follow BUTTON PRESS
and CYCLE STEPS. Each report runs the program again; mem keeps track of
which step is waiting for a reply.
