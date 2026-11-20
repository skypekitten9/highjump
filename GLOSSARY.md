# Highjump

A first-person movement game built around vaulting with a pole, alongside other movement abilities like wall running and sliding.

## Language

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
