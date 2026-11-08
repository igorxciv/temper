# Health replacement, not a recorder decision, keeps one Health workout per Workout

When a Watch records a Workout, the iPhone still saves its own Health workout at Stop, the same way it does with no Watch. The Watch saves under the same sync identifier, the Workout's ID, at sync version 1,000,000, so Health keeps the Watch's copy whichever save lands first. Nothing decides which device records. We used to pick one recorder 10 s after Start and never change it. That threw away the heart rate of a Watch that woke late (one run took 47.6 s), and the iPhone needed a "saved" confirmation from the Watch after the session had ended, when the link is already gone. Replacement became safe once a device run showed that the Watch app's saves carry the iPhone app as their source, so the documented same-source rule applies ([#108](https://github.com/igorxciv/temper/issues/108), decided in [#109](https://github.com/igorxciv/temper/issues/109)).

## Consequences

- Replacement in both orders is untested on a device, and everything here depends on it. It's the first item in the build's device check. If it fails, the one-recorder rule comes back.
- Whatever the Watch saves is what Health keeps, even a partial copy. So a Watch whose link drops for good, or that another workout app takes over, replaces the iPhone's complete copy with one that ends at that moment, heart rate included.
- Don't add a "which device records" step or have the iPhone skip its save when a Watch is present. The single save path is intentional.
