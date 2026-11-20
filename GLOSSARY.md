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
The **Runner** gliding low along the ground on its momentum, entered by crouching at speed. It gains speed downhill while the **Player** keeps crouching, loses it on flat ground and uphill, and ends when its speed runs out.
_Avoid_: Power slide, crouch-slide

**Slide boost**:
The burst of speed the **Runner** gets when a **Slide** begins, weakened if another Slide began shortly before.
_Avoid_: Slide burst, dash

**Vault**:
A jump in which the **Runner** plants a **Pole** and uses it to launch upward and over.
_Avoid_: High jump, pole jump

**Pole**:
The long, flexible pole the **Runner** carries and plants to perform a **Vault**.
_Avoid_: Stick, staff
