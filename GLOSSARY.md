# Highjump

A first-person endless runner built around movement: vaulting with a pole, alongside other movement abilities like wall running and sliding, carries the **Runner** through the obstacles of an endless **Course**.

## Language

### Movement

**Runner**:
The body the **Player** controls in the world, seen from its own eyes.
_Avoid_: Character, avatar, pawn, player (for the body)

**Player**:
The human holding the controls.
_Avoid_: User

**Run speed**:
The fastest the **Runner** can move from the **Player**'s input alone; other moves, like a **Vault**, can carry it faster.
_Avoid_: Max speed, walk speed, sprint speed

**Crouch**:
The **Runner** moving low and slow.
_Avoid_: Duck, crouch-walk

**Slide**:
The **Runner** gliding low along the ground on its momentum, entered by crouching at or above the **Slide entry speed**. It gains speed downhill while the **Player** keeps crouching and loses it on flat ground and uphill.
_Avoid_: Power slide, crouch-slide

**Slide entry speed**:
The speed at or above which crouching on the ground begins a **Slide** rather than a **Crouch**.
_Avoid_: Slide threshold, minimum slide speed

**Released Slide**:
A **Slide** the **Player** has stopped crouching in: it winds down until it becomes a Run at **Run speed**. Crouching again continues the same Slide, with no new **Slide boost**.
_Avoid_: Slide-out, slide cancel

**Slide-hop**:
Landing with crouch held at or above the **Slide entry speed**, so the **Runner** goes straight into a **Slide** and keeps all its speed.
_Avoid_: Bunny hop, landing slide

**Top slide speed**:
The fastest a **Slide** can become by going downhill.
_Avoid_: Max slide speed, slide cap

**Slide boost**:
The burst of speed the **Runner** gets when a **Slide** begins.
_Avoid_: Slide burst, dash

**Vault**:
A jump in which the **Runner** plants a **Pole** and uses it to launch upward and over.
_Avoid_: High jump, pole jump

**Pole**:
The long, flexible pole the **Runner** carries and plants to perform a **Vault**.
_Avoid_: Stick, staff

**Wall-run**:
The **Runner** running along a near-vertical wall while in the air, on its momentum. It begins on its own when the Runner meets a wall at or above the **Wall-run entry speed**, at a glancing enough angle, while the **Player** holds a direction into or along it. All the Runner's speed turns to run along the wall, and it gains none; the Wall-run arcs up and back down. It ends when the Player jumps, the wall runs out, the Runner reaches the floor, or it slows too much. The Runner can't Wall-run the same wall again until it lands or Wall-runs a different one.
_Avoid_: Wall ride, wall slide

**Wall-jump**:
A jump off the wall during a **Wall-run**, pushing the **Runner** away from the wall and upward while keeping its speed along the wall. Wall-running another wall turns that push into speed along it too, so jumping from wall to wall gains speed, up to the **Top wall-run speed**.
_Avoid_: Wall kick, wall bounce

**Wall-run entry speed**:
The speed at or above which meeting a wall in the air begins a **Wall-run**.
_Avoid_: Wall-run threshold, minimum wall speed

**Top wall-run speed**:
The fastest jumping from wall to wall can take the **Runner**; a Runner already faster keeps its speed.
_Avoid_: Max wall speed, wall-run cap

**Mantle**:
The **Runner** leaping up onto a ledge: its jump carries on, lifted just enough to clear the edge, and is never cut short. It begins on its own when the Runner, in the air, meets a ledge within **Mantle reach** while the **Player** holds a direction into it, and there's room on top for at least a **Crouch**. During a **Wall-run**, holding a direction into the wall Mantles onto its top, and a ledge that could start either a Wall-run or a Mantle starts a Mantle. The Runner keeps all its horizontal speed, with speed into the wall turning to carry it over the top, and comes off at no less than **Run speed**. Landing on top ends the Mantle and is an ordinary landing.
_Avoid_: Vault (that's the **Pole**), ledge grab, climb, edge vault

**Mantle reach**:
How far above the **Runner**'s feet a ledge can be and still be Mantled.
_Avoid_: Mantle height, grab range

### The Course

**Course**:
The endless, straight way the **Runner** runs along during an **Attempt**, made of **Sections** laid end to end, new and random each Attempt.
_Avoid_: Level, track, map, run

**Course heading**:
The fixed direction the **Course** leads in, which the **Runner** is always moving along.
_Avoid_: Forward (alone), track direction

**Section**:
One piece of the **Course**, built by hand, holding one or more obstacles.
_Avoid_: Chunk, tile, segment, room

**Difficulty**:
How hard a **Section** is, from 1 to 5. Harder Sections begin to appear further along the **Course**, and easier ones keep appearing after them.
_Avoid_: Level, tier (alone), hardness

**Attempt**:
One go along the **Course**, from its start until the **Runner** falls or **Stalls**.
_Avoid_: Run (that's moving on the ground), round, life, try

**Stall**:
The **Runner** making almost no progress along the **Course heading** for a moment, such as when it's stuck against an obstacle; it ends the **Attempt**.
_Avoid_: Stuck, blocked

**Look limit**:
How far the **Player** can turn the view to either side of the **Course heading**; the **Runner** always runs where it looks, so this keeps it running along the **Course**.
_Avoid_: Yaw clamp, view lock

**Distance**:
How far along the **Course heading** the **Runner** has got in an **Attempt**: the **Player**'s score.
_Avoid_: Score, points, progress

**Best distance**:
The greatest **Distance** of any **Attempt** the **Player** has made, kept between sessions.
_Avoid_: High score, record

### Obstacles

Every obstacle spans the full width of the **Course**, so the **Runner** must go through it.

**Hurdle**:
A low barrier the **Runner** jumps or **Mantles** over.
_Avoid_: Fence, low wall

**Block**:
A barrier too tall to jump over, which the **Runner** must **Mantle** onto.
_Avoid_: Wall (that's what a **Wall-run** runs along), box, crate

**Overhead bar**:
A bar too low to run under standing, which the **Runner** must **Crouch** or **Slide** under.
_Avoid_: Low ceiling, beam, duck bar

**Gap**:
A stretch of the **Course** with no floor, which the **Runner** must jump across. It comes in three sizes, by the speed needed to jump it: a **Short gap**, a **Long gap** and a **Wide gap**.
_Avoid_: Pit, hole, chasm

**Short gap**:
A **Gap** the **Runner** can jump at **Run speed**.
_Avoid_: Small gap

**Long gap**:
A **Gap** too long to jump at **Run speed**, which needs the speed a **Slide** begins with.
_Avoid_: Big gap

**Wide gap**:
A **Gap** too long to jump with the speed a **Slide** begins with, which the **Runner** can only jump after Sliding down a **Slope** that runs right to its edge.
_Avoid_: Huge gap, slope gap

**Slope**:
A downhill stretch of the **Course** that the **Runner** **Slides** down to gain speed.
_Avoid_: Ramp, hill

**Wall-run gap**:
A **Gap** too long to jump, with a wall alongside that the **Runner** **Wall-runs** to cross it.
_Avoid_: Wall gap, wall-run section

**Chimney**:
Two facing walls along the **Course**, close enough together that the **Runner** reaches the other wall still rising. It climbs by **Wall-jumping** back and forth between them up to a ledge too high to **Mantle** from below, over a **Gap** it falls into if it fails.
_Avoid_: Wall climb, shaft

**Wall-jump gap**:
A **Gap** with short walls alternating sides along it, none long enough to cross on one **Wall-run**, so the **Runner** **Wall-jumps** from each wall to the next.
_Avoid_: Zigzag, wall chain
