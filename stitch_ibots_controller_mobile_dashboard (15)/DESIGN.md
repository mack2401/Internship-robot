---
name: Telemetry Stream
colors:
  surface: '#0b1229'
  surface-dim: '#0b1229'
  surface-bright: '#323851'
  surface-container-lowest: '#060d24'
  surface-container-low: '#141a32'
  surface-container: '#181e36'
  surface-container-high: '#222941'
  surface-container-highest: '#2d344c'
  on-surface: '#dce1ff'
  on-surface-variant: '#bac9cc'
  inverse-surface: '#dce1ff'
  inverse-on-surface: '#292f48'
  outline: '#849396'
  outline-variant: '#3b494c'
  surface-tint: '#00daf3'
  primary: '#c3f5ff'
  on-primary: '#00363d'
  primary-container: '#00e5ff'
  on-primary-container: '#00626e'
  inverse-primary: '#006875'
  secondary: '#bdc5e9'
  on-secondary: '#262f4c'
  secondary-container: '#3d4664'
  on-secondary-container: '#abb4d7'
  tertiary: '#ffe7e5'
  on-tertiary: '#68000a'
  tertiary-container: '#ffc1bc'
  on-tertiary-container: '#b1121f'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#9cf0ff'
  primary-fixed-dim: '#00daf3'
  on-primary-fixed: '#001f24'
  on-primary-fixed-variant: '#004f58'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#bdc5e9'
  on-secondary-fixed: '#111a36'
  on-secondary-fixed-variant: '#3d4664'
  tertiary-fixed: '#ffdad7'
  tertiary-fixed-dim: '#ffb3ad'
  on-tertiary-fixed: '#410004'
  on-tertiary-fixed-variant: '#930013'
  background: '#0b1229'
  on-background: '#dce1ff'
  surface-variant: '#2d344c'
typography:
  headline-xl:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-xl-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  gutter-lg: 1.5rem
  margin: 1rem
  margin-sm: 0.75rem
  margin-lg: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system targets robotics enthusiasts, embedded systems engineers, and IoT operators navigating low-latency ESP32-CAM feeds and hardware telemetry. The UI evokes mission-control precision, tactical utility, and real-time responsiveness.

The aesthetic fuses modern telemetry minimalism with technical HUD clarity:
- **Base Canvas:** Deep, cold oceanic night tones engineered for OLED battery optimization and glare-free field usage.
- **Micro-Interactions:** Snappy, low-overhead visual feedback mirroring native Flutter performance.
- **Accents:** High-potency electric cyan triggers and sharp status indicators against structural slate architecture.
- **Atmosphere:** Rigorous, uncluttered, and instrumental—avoiding decorative fluff to prioritize live camera throughput and device status.

## Colors

The palette prioritizes rapid state identification under varied lighting environments:

- **Primary (`#00e5ff`):** Electric Cyan drives critical interactive affordances, selected states, signal telemetry tracks, and active stream feeds.
- **Secondary (`#1c2541`):** Deep Navy Surface anchors cards, panels, and stream overlays.
- **Tertiary (`#ef4444`):** Pulse Red is reserved exclusively for live video capture recording markers, thermal overages, and emergency halt switches.
- **Neutral (`#0a1128`):** Ultra-deep Navy Canvas provides absolute baseline contrast.
- **Borders & Dividers (`#334155`):** Subtle Slate delineates surface perimeters and hardware data clusters without creating visual noise.
- **Text & Data Tokens:** Crisp White (`#f8fafc`) for primary metrics and titles; Slate Muted (`#94a3b8`) for passive telemetry markers and secondary data values.

## Typography

The type system balances general readability with monospaced numerical stability:

- **Primary Interface (Inter):** Deployed across all navigation elements, control labels, device configuration titles, and system dialogs for instant recognition.
- **Telemetry & Metadata (JetBrains Mono):** Applied to FPS readouts, IP/MAC configurations, Wi-Fi RSSI (dBm), frame latencies, and sensor metrics to prevent visual layout shifting as continuous stream values update.
- **Hierarchy Rules:** High-contrast crisp white (`#f8fafc`) for headline tiers; high-readability muted slate (`#94a3b8`) for data labels and secondary body text.

## Layout & Spacing

Designed around a fluid, touch-first grid model tailored for dual-orientation mobile and tablet controller viewports:

- **Grid Architecture:** 
  - Mobile Portrait: 4-column fluid layout with `margin-sm` (12px) edge bounds and `gutter-sm` (12px) column splits.
  - Mobile Landscape / Telemetry HUD: 8-column layout dedicating 5–6 columns to the primary camera viewport, with flanking columns reserved for directional controls and hardware telemetry.
  - Tablet/Desktop Operations: 12-column layout with `gutter-lg` (24px) for multi-device fleet views.
- **Rhythm:** An 8pt spatial baseline controls all padding scales. Component interiors rely on `space-sm` (8px) and `space-md` (16px) for tight information density without compromising touch target reliability (minimum 48x48px hit area for runtime buttons).

## Elevation & Depth

Visual separation relies on tonal layering and low-contrast outlines rather than heavy drop shadows:

- **Base Layer (Level 0):** Canvas `#0a1128`.
- **Card & Container Layer (Level 1):** `#1c2541` surface bounded by a crisp 1px stroke of `#334155`.
- **Raised HUD Overlays & Floating D-Pads (Level 2):** Semi-transparent `#1c2541` at 85% opacity with an active `backdrop-filter: blur(8px)` and a 1px border of `#00e5ff` at 20% opacity.
- **Active / Focused Layer:** 1px stroke of `#00e5ff` with a localized, soft ambient glow (`box-shadow: 0 0 12px rgba(0, 229, 255, 0.25)`).
- **Shadow Philosophy:** Natural dark shadows are suppressed in favor of ambient luminescence and border luminance to maintain tactical clarity against the navy backdrop.

## Shapes

The interface balances sleek contemporary ergonomics with industrial utility:

- **Containers & Surfaces:** Medium roundedness (`0.5rem` / 8px) on standard telemetry cards, modal sheets, and stream wrappers.
- **Floating Controls & D-Pads:** Level 2 roundedness (`0.5rem` to `1rem` on composite pads) preserves structural definition while remaining comfortable for thumb-driven manipulation.
- **Status Pills & Chips:** Level 3 treatment (`rounded-full` / 9999px) for recording status badges, Wi-Fi strength tags, and baud-rate selectors.
- **Outlines:** All strokes maintain a precise 1px gauge to preserve clean architectural lines.

## Components

### Buttons & Hardware Triggers
- **Primary Action (Stream Connect / Flashlight Toggle):** Solid `#00e5ff` background with `#0a1128` bold text. Radius: 8px. Hover/focus states emit a `0 0 16px rgba(0, 229, 255, 0.4)` aura.
- **Secondary (Resolution / Framing Controls):** Surface `#1c2541` with a 1px border of `#334155` and white text. Active state transitions border to `#00e5ff`.
- **Critical Interlock (E-Stop / Format SD):** Ghost button with a 1px `#ef4444` border and `#ef4444` label. Pressed state fills `#ef4444` with `#ffffff` text.

### Recording Indicator & Telemetry Chips
- **Live Stream Badge:** Pill shape (`rounded-full`) with `#1c2541` background, 1px `#334155` stroke, featuring an animated 6px `#ef4444` circular dot blinking at 1Hz alongside monospaced "REC" text.
- **Telemetry Chips:** JetBrains Mono metrics enclosed in low-profile pills (`padding: 4px 10px`) with subtle teal indicators for link quality and voltage levels.

### Camera Viewport & Stream HUD
- **Video Canvas:** Contained inside an 8px radius card with overflow hidden, framed by a 1px `#334155` border.
- **Overlay HUD:** Anchored inside the viewport corners with semi-transparent frosted surfaces (`rgba(28, 37, 65, 0.75)`), projecting current FPS, stream latency (ms), and resolution (e.g., SVGA 800x600).

### Virtual Joysticks & Directional Steppers
- **D-Pad Cluster:** 4-way direction pad with segmented `#1c2541` directional triggers, separated by 2px gaps, edged in `#334155`, with `#00e5ff` visual press feedback.
- **Pan-Tilt Sliders:** Thin 4px tracks in `#334155` with an electric cyan filled segment and a circular 16px thumb indicator with a centered cyan core.

### Inputs & Toggles
- **Config Fields (IP / Port / RTSP URL):** Background `#0a1128`, 1px `#334155` border, JetBrains Mono font. Active focus triggers a 1px `#00e5ff` border glow.
- **Toggle Switches (LED Flash / Face Detection):** 24px height track in `#334155` shifting to `#00e5ff` when toggled; knob slides with a smooth 150ms ease curve.