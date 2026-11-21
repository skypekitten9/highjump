# Music is an OGG Vorbis file cut at the loop end

A looping song plays its intro once, then loops a later stretch forever. The song is stored as an OGG Vorbis file, cut at the exact sample where the loop ends. It is played with the engine's native loop, whose loop offset is the loop start. When the engine reaches the end of the file it jumps back to the offset. So the intro plays once, the loop seam is sample-exact, and no script times the jump. Anything after the loop end in the original recording, like an outro, is cut away.

The loop end is exactly a whole number of beats after the loop start (for `music/retro.ogg`: 208 beats at 98 BPM, from sample 838,008 to 6,454,013). The music is the same there, so the jump can't be heard. The source MP3 was decoded, cut and encoded as OGG with a throwaway Python script (`miniaudio`, `soundfile`) outside the repo.

## Considered Options

- **The original MP3 with the native loop**: the engine's MP3 loop has no loop end, so the outro would play. MP3 can also only be cut at frame boundaries, about 26 ms apart, and its encoder padding adds silence that can be heard at the seam.
- **The full song, with a script seeking back at the loop end**: it keeps the outro in the file, but the seek happens on a game frame rather than at a sample, so the seam can click or drift.
- **A WAV with loop begin and end in its import settings**: sample-exact, but the source WAV is about 26 MB, which would stay in git history permanently.
- **Separate intro and loop files chained by `AudioStreamPlaylist` or `AudioStreamInteractive`**: more assets and setup for what one file and a loop offset already do.

## Consequences

- Changing where a song loops means re-cutting and re-encoding it from the source recording, not just editing an import setting.
- OGG is lossy, so re-encoding an MP3 loses a little quality. At the quality used (about 225 kbps) it can't be heard.
- The engine decodes Vorbis itself, so the loop works the same in the web build as on desktop.
- The import's `bpm` and `beat_count` stay 0. Setting them can change where the engine loops.
