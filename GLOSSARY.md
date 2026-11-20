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
The **Runner** moving low and slow; a **Slide** that loses its speed becomes a Crouch.
_Avoid_: Duck, crouch-walk

**Slide**:
The **Runner** gliding low along the ground on its momentum, entered by crouching at or above the **Slide entry speed**. It gains speed downhill while the **Player** keeps crouching and loses it on flat ground and uphill. Held, it becomes a **Crouch** once its speed runs out; released, it becomes a **Released Slide**.
_Avoid_: Power slide, crouch-slide

**Slide entry speed**:
The speed at or above which crouching on the ground, or landing with crouch held, begins a **Slide** rather than a **Crouch**.
_Avoid_: Slide threshold, minimum slide speed

**Released Slide**:
A **Slide** the **Player** has stopped crouching in: it winds down until it becomes a Run at **Run speed**. Crouching again continues the same Slide, with no new **Slide boost**.
_Avoid_: Slide-out, slide cancel

**Slide-hop**:
Landing with crouch held at or above the **Slide entry speed**, so the **Runner** goes straight into a **Slide** and keeps all its speed.
_Avoid_: Bunny hop, landing slide

**Top slide speed**:
The fastest a **Slide** can become by going downhill; a Slide entered faster keeps its speed.
_Avoid_: Max slide speed, slide cap

**Slide boost**:
The burst of speed the **Runner** gets when a **Slide** begins, weakened if another Slide began shortly before. It never carries the Runner beyond a set speed above **Run speed**, so only slopes take a Slide faster.
_Avoid_: Slide burst, dash

**Vault**:
A jump in which the **Runner** plants a **Pole** and uses it to launch upward and over.
_Avoid_: High jump, pole jump

**Pole**:
The long, flexible pole the **Runner** carries and plants to perform a **Vault**.
_Avoid_: Stick, staff
