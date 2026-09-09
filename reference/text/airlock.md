# Airlock controller

Join two doors, two wall buttons and a dual-port vent to one powered access
point or air alarm. The default program expects the interior door west of
the exterior door. Connect the vent's intake to pipe layer 2 and its effluent
to layer 4.

Insert this disk into an open, powered laptop. Hold the laptop and click the
host. Select the laptop disk as the source, copy airlock.disl to the host,
then load that copy into its controller socket.

Both buttons advance the same sequence: entry, exit, entry again. A press
can interrupt a running cycle. Entry closes and bolts the exterior before
filling to at least 100 kPa and opening the interior. Exit closes and bolts
the interior before draining below 10 kPa and opening the exterior.

Edit the host copy to change the program. The permitted function accepts
everyone by default; returning request.engineering restricts each press
to engineering access. Originals on this disk are fixed; copies are editable.
