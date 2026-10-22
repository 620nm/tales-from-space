# Pathogen disinfection

The pack inactivates contagion in known infected containers by sampling their
liquid contents. Only non-body contagion arrivals enter the registry. When
ev.body identifies a bloodstream, the caller leaves it on illness exposure
handling; these liquid fractions never clear it.

## Liquid potency

For each sample, the denominator is the sum of liquid_ml for every substance in
the container. A listed agent contributes its own liquid_ml divided by that
total; gases, solids and headspace contribute nothing to either side. A sample
with no measurable liquid has no potency. Only agents in the active rule
contribute.

The default minimum fractions are pack judgments, not tg virucide values:

| agent | minimum liquid fraction | percent |
|---|---:|---:|
| chlorine | 0.001 | 0.1% |
| bromine | 0.001 | 0.1% |
| fluorine | 0.001 | 0.1% |
| iodine | 0.01 | 1% |
| ethanol | 0.70 | 70% |
| space_cleaner | 0.10 | 10% |
| phenol | 0.05 | 5% |

Potency is the sum, for each agent in the active rule, of its liquid fraction
divided by its minimum fraction. A sample qualifies when that sum is at least
one. Agents combine additively; an agent absent from the rule adds nothing.

## Sampled contact

The contagion arrival path enrolls a known infected container and samples it
immediately. A completed global clock.second event emits bounded notifications
for the live registry pages. Each page holds at most 32 registrations, and one
clock event attempts at most 16 page notifications. The handler samples the
current native tick, including liquid changes that carry no rider, such as
disinfectant added after contamination. Thus both addition orders reach the
same rule without a native composition-change tracker.

Pages keep insertion order and use bounded adjacent-page compaction while more
than 16 pages remain. A page pair moves at most 32 registrations per clock
event. With stable membership and at most 512 registrations over N nonempty
pages, compaction reaches 16 or fewer pages within at most 2N completed clock
events; a 33-page registry with one registration per page takes 17 events.
Sparse registries can therefore take multiple events to fit within the
dispatch limit. Queue refusal or a dropped notification leaves registrations
eligible for later attempts. Repacking does not guarantee a sample every second
or progress under native queue overload. A missed observation longer than one
simulated second starts a fresh contact interval.

Each illness has its own contact clock. Qualifying samples must span at least
10 seconds by default. An observed below-dose sample resets that illness's
clock. A gap longer than one simulated second between qualifying samples also
starts a fresh interval. The rule measures sampled contact and makes no claim
about uninterrupted contact between subsecond changes.

The sweep acts on the holder handle without a player actor or a floor-tile
position. A registered container can therefore clear while held or stowed in a
backpack.

## Illness rules

An illness may set an inactivation rule with min_fractions and
contact_seconds. If min_fractions is nil or omitted, the full default table
applies. A supplied min_fractions map replaces that table completely; an
empty map disables every default agent for that illness. contact_seconds is
independent: if omitted it is 10, even when min_fractions replaces the
defaults.

Each configured fraction must be finite, greater than zero and at most one.
contact_seconds must be finite and greater than zero. A malformed rule fails
closed: it cannot inactivate the illness. When one illness clears, other
indices remain on the contagion rider, including indices without a known
inactivation rule.

## Rider effects

When every illness on a container clears, the pack clears its contagion rider.
When others remain, it writes the remaining illness indices back to that
rider. Both operations use native rider effects and land attributed in the
round ledger.
