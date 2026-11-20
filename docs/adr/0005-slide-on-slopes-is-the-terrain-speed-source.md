# Sliding down slopes is the only way terrain adds speed; Apex Legends is the movement reference

Apex Legends' movement is the feel we aim for, and its core loop is ours: crouch at speed into a **Slide**, gain speed sliding downhill, jump out keeping all of it, and land back into a Slide to chain. Within that, only a **Slide** gains speed from terrain: running downhill does not, sliding uphill loses speed, and a tunable top slide speed bounds it. Air steering still never adds speed (ADR 0004), so slopes, the **Slide boost** and the **Vault** are the ways to go faster than **Run speed**, and gaining speed is about reading the level rather than mouse technique.

Amended by ADR 0006: jumping from wall to wall is also a speed source, bounded by the **Top wall-run speed**.

## Considered Options

- **Apex-style air strafing**: Apex lets the Player bend and slightly gain speed in the air. Rejected, as in ADR 0004: it rewards strafing technique over terrain and makes speed harder to bound in level design.
- **Slopes speed up running too**: simpler, but removes the reason to choose to slide, and makes every downhill an unbounded speed source.
- **A sprint key, as in Apex**: the Runner always moves at Run speed instead; a sprint key adds an input that a movement game's Player would hold down permanently anyway.

## Consequences

Levels are built around slopes as speed sources, so changing this later means revisiting level layouts. Tap-strafing is deliberately not reproduced.
