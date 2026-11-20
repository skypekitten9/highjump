# A Mantle keeps all the Runner's speed and leaves at no less than Run speed

A **Mantle** keeps all of the Runner's horizontal speed. The part heading into the wall, which an ordinary collision would throw away, turns to carry the Runner over the top, and the Runner comes off at no less than **Run speed**. Apex Legends, our movement reference (ADR 0005), stops the Player dead on a mantle; we don't. A slide-jump into a ledge should flow on at full speed, and a Mantle from a standstill should leave at a full run rather than a crawl. The floor only lifts the Runner up to Run speed, never above it, so the Mantle is not a new way to go faster than Run speed, and ADR 0005's list of speed sources is unchanged. This follows ADR 0006, where a Wall-run likewise keeps the speed that a collision would lose.

## Considered Options

- **Stop dead, as in Apex**: simple and familiar, but every ledge becomes a speed sink, which punishes fast play and goes against ADR 0004.
- **Lose the speed into the wall, then add a boost like the Slide boost, with a cooldown**: the obvious fix for a stop, but a boost sized like the Slide boost (2 m/s) leaves a stopped Runner far below Run speed. A bigger boost becomes a speed source that a row of small ledges can farm, with only the cooldown to limit it.

## Consequences

Ledges never cost the Runner speed and never add to it above Run speed, so level designers can place them freely without changing a route's pace. A Runner that Mantles head-on at high speed comes off the top at that speed, so the space beyond a ledge must leave room to land and keep running.
