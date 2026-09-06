# GlowCompanion

Moves Glow's entire notification icon row to the top of the screen, below the notch. Every icon in the row moves together, including icons added by new notifications. Glow's date, time, battery and charging widgets stay in their original positions.

## Install

Keep Glow installed, install the rootless DEB from [Releases](https://github.com/551UK/GlowCompanion/releases), then respring. There are no settings to configure. If you use Choicy, allow both Glow and GlowCompanion in SpringBoard.

Remove GlowCompanion and respring to restore Glow's original icon position.

## Compatibility

- Built for rootless iOS 15 and later, targeting iOS 16.2 / Dopamine on iPhone 12 Pro Max.
- Implementation based on inspection of Glow 0.6-12. Other versions must retain `GlowScene` and its `_appIconsNode` ivar.
- Glow is required separately. This package contains none of Glow's binaries and does not replace Glow or change its preferences.
- Build and package checks are automated. Appearance and behavior still require validation on a jailbroken device; no on-device test is claimed.

## Implementation

Hooks only `GlowScene` using the jailbreak's `MSHookMessageEx` API. Repositions the icon container after notification repopulation and at the end of SpriteKit's existing frame cycle. Converting between view and scene coordinates handles SpriteKit's inverted Y axis, anchor point and scaling. Safe-area clearance plus a 59-point minimum and 16-point gap keeps the full icon row below the notch, including badges. No extra timer or background service is added.

## Build

On macOS with Xcode's iPhoneOS SDK: `bash build.sh`.

The GitHub Actions workflow builds, signs, validates and publishes the DEB to Releases on pushes to `main` that change the tweak or its build files. Increase `Version` in `control` for a new release; an existing release asset is never overwritten automatically.

Made by 551.
