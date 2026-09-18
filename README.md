# GlowIconPosition

Moves Glow's entire notification icon row below the notch by default, with an adjustable vertical offset in Settings. Every icon in the row moves together, including icons added by new notifications. Glow's date, time, battery and charging widgets stay in their original positions. 

I run just the icons on Glow and disable all the other stuff. Running my tweak moves these icons to the upper screen. It reminds me of an old tweak called Dots 2 on rootful. Its pretty neat. 

## Install

Keep Glow installed, install the rootless DEB from [Releases](https://github.com/551UK/GlowCompanion/releases), then respring. Open **Settings → GlowIconPosition** to adjust the row. Offset **0** keeps the working position. Negative values move up and positive values move down. You can also use the slider. Changes apply when Glow next appears without another respring. If you use Choicy, allow both Glow and GlowIconPosition in SpringBoard.

Disable the tweak in settings to restore Glow's original icon position.

GlowIconPosition also patches `/var/jb/Library/PreferenceBundles/Glow.bundle/NotificationIcons.plist` at install time. Glow's **Notification Icon Scale** specifier default is changed to **2.20** and its maximum is changed from **2.5** to **3.0**. The installer also sets the saved `net.limneos.glow` → `iconsScale` preference to **2.20** when it is unset or still at Glow's original **1.30** value, while preserving a custom value a user has already chosen. The minimum (**0.8**) and all other Glow settings are left unchanged.

## Compatibility

- Built for rootless iOS 15 and later, targeting iOS 16.2 / Dopamine on iPhone 12 Pro Max.
- Implementation based on inspection of Glow 0.6-12. Other versions must retain `GlowScene` and its `_appIconsNode` ivar.
- Glow is required separately. This package contains none of Glow's binaries and does not replace Glow or change its preferences.

## Implementation

Hooks only `GlowScene` using the jailbreak's `MSHookMessageEx` API. Repositions the icon container after notification repopulation and at the end of SpriteKit's existing frame cycle. Converting between view and scene coordinates handles SpriteKit's inverted Y axis, anchor point and scaling. Safe-area clearance plus a 59-point minimum and 16-point gap keeps the full icon row below the notch, including badges. The preference value is cached and refreshed by Darwin notifications, with no preference reads per frame. No extra timer or background service is added. Settings uses a compiled Preferences bundle.

