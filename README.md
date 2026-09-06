# GlowIconPosition

Moves Glow's entire notification icon row below the notch by default, with an adjustable vertical offset in Settings. Every icon in the row moves together, including icons added by new notifications. Glow's date, time, battery and charging widgets stay in their original positions.

## Install

Keep Glow installed, install the rootless DEB from [Releases](https://github.com/551UK/GlowCompanion/releases), then respring. Open **Settings → GlowIconPosition** to adjust the row. Offset **0** keeps the working v1.0.0 position. Negative values move up and positive values move down. Use the slider, 10-point buttons or **Reset to default position**. Changes apply when Glow next appears without another respring. If you use Choicy, allow both Glow and GlowIconPosition in SpringBoard.

Remove GlowIconPosition and respring to restore Glow's original icon position.

## Compatibility

- Built for rootless iOS 15 and later, targeting iOS 16.2 / Dopamine on iPhone 12 Pro Max.
- Implementation based on inspection of Glow 0.6-12. Other versions must retain `GlowScene` and its `_appIconsNode` ivar.
- Glow is required separately. This package contains none of Glow's binaries and does not replace Glow or change its preferences.
- The user confirmed v1.0.0 works on-device. Version 1.1.0 preserves that position at offset 0 and adds Settings controls. Build and package checks are automated; the new controls still require device verification.

## Implementation

Hooks only `GlowScene` using the jailbreak's `MSHookMessageEx` API. Repositions the icon container after notification repopulation and at the end of SpriteKit's existing frame cycle. Converting between view and scene coordinates handles SpriteKit's inverted Y axis, anchor point and scaling. Safe-area clearance plus a 59-point minimum and 16-point gap keeps the full icon row below the notch, including badges. The preference value is cached and refreshed by Darwin notifications, with no preference reads per frame. No extra timer or background service is added. Settings uses a compiled Preferences bundle. The menu icon is packaged at 29/58/87 pixels beside its loader entry and inside its bundle, with a matching filename.

## Build

On macOS with Xcode's iPhoneOS SDK: `bash build.sh`.

The GitHub Actions workflow builds, signs, validates and publishes the DEB to Releases on pushes to `main` that change the tweak or its build files. Increase `Version` in `control` for a new release; an existing release asset is never overwritten automatically.

Made by 551.

## Settings icon

Version 1.1.1 uses Glow’s original blue icon, copied from the supplied Glow package as requested. The 87-pixel asset is preserved byte-for-byte, with 29- and 58-pixel variants for Settings. Icon artwork belongs to its original creator.
