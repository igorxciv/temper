---
name: liquid-glass
description: Liquid Glass rules for Temper's screens on iOS 27. Use when building or reviewing SwiftUI screens, controls, toolbars, or sheets.
---

Glass belongs to the functional layer: controls and navigation floating above the content layer.

## Layers

- **Content layer, no glass:** the countdown, the Phase, the Round number, and app backgrounds. Use standard materials here if a surface is needed.
- **Functional layer:** Pause, Resume, Stop, and any bars.

## Standard components first

- Standard bars, sheets, popovers, and controls adopt glass with no code. Remove custom backgrounds from them.
- For buttons, use `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)`.
- Keep the system's control sizes and spacing, without hard-coded metrics.
- For a settings layout, use `Form` with the `grouped` style and title-style section headers.

## Custom glass

Use `glassEffect(_:in:)` only when no standard control fits, and only on the most important functional elements.

- Apply it after other modifiers that affect the view's appearance.
- Put neighbouring glass views in one `GlassEffectContainer`.
- Keep glass elements apart, with no glass stacked on glass.
- Use the regular variant. Clear is for components over visually rich media, which Temper does not have.

## Shape and color

- Use `ConcentricRectangle` for shapes nested near a container's edge.
- Tint only to suggest prominence, with system colors or a custom color that has light, dark, and increased-contrast variants.

## Legibility

The running screen must read at a glance mid-Workout. Test custom elements, colors, and animations with:

- Light and dark appearance
- Increase Contrast, Reduce Transparency, and Reduce Motion
- The system's preferred Liquid Glass look

## Presentation

Attach Stop's `confirmationDialog` to the Stop button so it originates from that control.

## Sources

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) in the Human Interface Guidelines

Check any API not named here against the SDK, as the `temper-ios` skill's source order says.
