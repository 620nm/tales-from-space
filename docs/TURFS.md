# Decks and infrastructure

`content/compositions.luau` declares the visual tree, substrate and installed
components, cover controls, network channels, and composition presets.
Maps retain an optional authored substrate and an ordered installed component
list. An omitted substrate inherits the selected environment. Installing or
removing deck components preserves that choice and the independently authored
outdoor flag.

Ordinary flooring consists of station base and opaque removable floor tiles.
Grid flooring uses the same base with a transparent protective cover. Each
cover independently controls power and pipe disclosure and tool access. A
closed grid permits seeing and examining the runs beneath it, but prevents
tooling or installing them. Removing either cover leaves the base and opens
access. Reinforcement has the same physical properties in its closed and open
cover states. Bare space, ground, and station base have no cover controls.

Removing bare base with a welder exposes the retained substrate. The action
uses the existing four-second, two-fuel welding step and returns no material.
An unsupported final network placement rejects the operation. Installing a
new supported component never exposes an intermediate unsupported state.

Lattice and catwalk supply support without sealing the substrate or changing
outdoors. Catwalk support is integrated. A power cable requires supporting
ground, station base, or catwalk; lattice alone does not permit it. Explicit
catwalk removal declares removal of power cables that lose support. Pipes
have no corresponding support requirement and remain installed.

The power network declares three channels and the pipe network five. Their
channel identities, preferences, kind connectivity, paints, and shape artwork
are content data. Heat-exchanging pipe fits channels two through four and
joins its own kind. Pipe paints preserve the existing same-colour and omni
connectivity rules. Maps and exports store authored network identities.

Thermal profiles retain the existing capacities, conductivities, and
emissivities. The last installed component declaring a profile supplies it;
otherwise the substrate does. Substrate vacuum boundaries are independent of
support, horizontal gas blocking, and outdoor forcing. Station base seals the
boundary; an exposed space substrate remains a boundary below a catwalk.
