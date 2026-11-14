## Purpose


The moment-to-moment mowing loop: cutting grass, carrying it under a storage limit, and selling it. This is the behavior every other system feeds into or rewards.

**Phase:** Phase 1 (v1) — variants complete in Phase 3

## ADDED Requirements

### Requirement: Cutting grass
The player SHALL be able to swing or drive their equipped tool to cut grass tufts near them, with the server validating tool cooldown, reach, and the player's unlocked areas before any grass is harvested.

#### Scenario: Successful cut
- **WHEN** a player swings a tool next to grass in an area they have unlocked and their storage is not full
- **THEN** the tuft loses health equal to the tool's power, and when its health reaches zero the player gains grass units

#### Scenario: Storage full blocks cutting
- **WHEN** a player tries to cut while their carried grass equals their storage capacity
- **THEN** nothing is harvested and the player is told their storage is full

#### Scenario: Locked area cannot be farmed
- **WHEN** a player swings at grass inside an expansion they have not unlocked
- **THEN** no grass is harvested from that tuft

### Requirement: Tagged-variant inventory
Carried grass SHALL be tracked as a count per variant (for example Normal, Golden, Rainbow), and storage capacity SHALL count the total units across all variants.

#### Scenario: Carrying mixed variants
- **WHEN** a player harvests normal and Golden grass
- **THEN** their inventory shows both counts separately while the total respects the storage cap

### Requirement: Selling grass
The player SHALL sell grass through the hay yard at their base: carried grass is loaded into the baler, the baler presses it into hay bales that pile up on a stack, and the player sells bales by clicking them, receiving Coins where each variant pays its own value multiplier and the area value applies. Sold bales SHALL go into the silo, and customers SHALL buy from the silo (never loose grass from the player), paying a tip on top of the sale. Each step (machine working, bales stacking, bales entering the silo, customers walking) SHALL be animated.

#### Scenario: Loading the baler
- **WHEN** a player with carried grass steps onto the baler's loading deck, or onto an island's drop-off pad
- **THEN** all carried grass is removed from storage and added to the baler's hopper with its value

#### Scenario: Baling
- **WHEN** the hopper holds grass and the stack has room
- **THEN** the baler turns it into bales over time, each worth its share of the loaded grass, and occasionally a golden bale worth several times more

#### Scenario: Stack full
- **WHEN** the stack holds as many bales as the baler's level allows
- **THEN** the baler waits and the remaining grass stays in the hopper

#### Scenario: Selling a bale
- **WHEN** a player near the stack clicks one of their bales
- **THEN** Coins are credited for that bale, it leaves the stack and is added to the silo's stock

#### Scenario: Customers
- **WHEN** the silo has stock
- **THEN** customers arrive from time to time, remove bales from the stock and pay the player a tip

#### Scenario: Loading with empty storage
- **WHEN** a player steps onto the loading deck or a drop-off pad carrying no grass
- **THEN** no grass or currency changes

### Requirement: Legible illustrated HUD
The HUD SHALL use original transparent icon assets with editable vector masters for navigation, Coins, Clovers, fuel, storage and all five weather states. Coins and Clovers SHALL be prominent icon/value indicators below the left navigation. Weather and fuel SHALL be stacked as independent icon/value indicators on the right. Navigation SHALL sit below the upper-left system controls with a compact layout on short screens. The weather name SHALL be available on hover or activation.

#### Scenario: Weather changes
- **WHEN** the server changes between clear, rain, golden sun, moon night and storm
- **THEN** the corresponding distinct icon and countdown appear while currencies remain independently readable

### Requirement: Dedicated passes menu and exclusive panels
The HUD Shop SHALL open a passes catalog. Equipment purchases SHALL remain at physical map stalls. Unpublished or unimplemented pass offers SHALL show Coming soon with checkout disabled; prices SHALL NOT be invented. Menus SHALL have one visible owner, a backdrop and close controls, and rewards SHALL reflow without overlapping values or claim actions on narrow screens.

#### Scenario: Open passes from HUD
- **WHEN** the player activates Shop in the HUD
- **THEN** the passes catalog opens, other menus close, and the equipment shop remains available through world stalls

#### Scenario: Unpublished offer
- **WHEN** an offer has no configured ID or entitlement checkout is disabled
- **THEN** it displays Coming soon and cannot prompt a purchase

#### Scenario: Narrow rewards menu
- **WHEN** the rewards panel has insufficient width for seven daily tiles
- **THEN** the tiles wrap into two rows and the claim button occupies its own row below the currency rewards
