# The endless Course is hand-built Sections, run by a forward input that is always held

Highjump becomes an endless runner. The **Runner** always moves forward because the game holds the forward input for the **Player**, relative to where they look. The movement model is unchanged: no new force pushes the Runner along the **Course**. What keeps the Runner on the Course is the **Look limit**: the view can turn at most 80° (tunable) either side of the **Course heading**, a fixed direction in the world. Strafing still works, and back does nothing. The Course itself is hand-built **Sections**, each its own scene, picked at random and laid end to end, added ahead of the Runner and removed behind it.

We chose a held input over a push along the Course so that ADR 0004 (momentum kept, input steers but never removes speed) and every movement rule built on input direction stay as they are. Those rules are the Wall-run's entry and follow angles, the Mantle's input angle and the Slide's turn rate. A push would have needed a new force in `RunnerMovement` and a rule for how it combines with each of them. We chose hand-built Sections over generating the Course from rules because obstacles must fit tight movement limits (Mantle reach, jump distance, Wall-run entry speed). Sections built by hand, with tests checking their sizes against the Runner's tuning, hit those limits reliably and match how the greybox is already built.

## Considered Options

- **A push along the Course heading**: the Runner moves along the Course whatever the view, and input only steers sideways. Looking around is free, but it changes the movement model and clashes with ADR 0004's rule that input never adds speed.
- **Generated Course shapes**: endless variety without authoring, but it's hard to guarantee every obstacle can be cleared, and hard to make obstacles that suit the moves.

## Consequences

- Looking to the side slows progress along the Course: at the full 80°, holding forward gains about a sixth of its speed along the Course. Steering is therefore part of the skill.
- Since every Section starts and ends at floor height 0, falling below a fixed height ends the **Attempt**.
- The Course is straight, so the Course heading is one fixed direction. Turning Courses would make the Look limit follow the Section the Runner is in.
- 32-bit floats lose precision far from the origin. This is accepted for now, since jitter only shows tens of kilometres out. If Attempts ever get that long, moving the world back toward the origin is the fix.
