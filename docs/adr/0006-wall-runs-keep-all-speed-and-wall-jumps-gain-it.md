# A Wall-run keeps all the Runner's speed, so wall-to-wall jumps gain speed

When a **Wall-run** begins, all of the Runner's horizontal speed turns along the wall, rather than losing the part that went into it as an ordinary collision would. Losing it felt sluggish when chaining a Slide into a wall. A maximum entry angle stops head-on hits from becoming Wall-runs. A **Wall-jump**'s push away from the wall therefore becomes speed along the next wall, so jumping from wall to wall gains speed up to the **Top wall-run speed**. This is deliberate, to reward parkour, and it amends ADR 0005's list of speed sources.

## Considered Options

- **Keep only the speed along the wall**: the steeper the approach, the more speed it loses.
- **Each Wall-run keeps at most the previous wall's speed**: keeps ADR 0005 intact, but jumping between walls then earns nothing.

## Consequences

Wall placement, gap widths and corridor lengths decide how much speed walls hand out. A Wall-jump with no forward speed meets the opposite wall head-on, so a narrow shaft can't be climbed forever.
