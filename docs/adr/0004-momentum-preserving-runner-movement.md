# Runner movement preserves momentum instead of snapping to input

Runner movement keeps any speed above run speed: in the air, input may steer it but never removes or adds to it, and on the ground it fades gradually rather than snapping back. We chose this over a snappy model, where velocity chases the input direction within about 0.15 s even in the air, even though snappy felt slightly better in play. The **Vault**, and planned rope swing and grappling hook mechanics, all hand the **Runner** speed above run speed, and a snappy model throws that speed away within a fraction of a second. Responsiveness comes from tuning instead: high ground and air acceleration within run speed.

Amended by the **Wall-jump** (ADR 0006): air acceleration is lowered from 45 to 20 m/s² for every jump, so held input doesn't cancel a Wall-jump's push away from the wall. We chose this over a Wall-jump-only steering fade, to avoid a special case, accepting a little less air responsiveness within run speed.

## Considered Options

- **Snappy**: velocity chases the input direction at run speed on the ground and in the air. Felt best in the prototype, but kills **Vault** and swing momentum whenever a direction is held.
- **Quake-style air strafing and bunny hopping**: keeps momentum, but lets the Player build speed through technique and makes landing without a hop brake hard. A bigger design commitment than this game needs; it can still be layered on later.

## Consequences

Any mechanic that changes the Runner's velocity (Vault, rope swing, grapple) hands its velocity to the movement model, which continues from it unchanged.
