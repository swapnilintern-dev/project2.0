# App launcher icon source art

Drop the VS Arogya logo here, then generate the platform icons.

## Required files
| File | Size | Notes |
|------|------|-------|
| `app_icon.png` | 1024×1024 | The full logo, **opaque** background. Used for iOS and the Android legacy/round icon. |
| `app_icon_foreground.png` | 1024×1024 | **Transparent** PNG with the mortar-&-pestle emblem centred at ~70% of the canvas (leave ~15% padding on every side). Used as the Android **adaptive** foreground so the launcher mask never crops it. The `#FFFFFF` adaptive background is set in `pubspec.yaml`. |

> Tip: the small "SWASTHYA HI JEEVAN HAI" tagline is unreadable at icon sizes —
> for `app_icon_foreground.png` use just the bowl/emblem (no tagline) for a clean
> adaptive icon. `app_icon.png` can keep the full lockup if you like.

## Generate
```bash
flutter pub get
dart run flutter_launcher_icons
```
This writes all Android mipmap densities (incl. `mipmap-anydpi-v26` adaptive XML)
and the iOS `AppIcon.appiconset`. Nothing in app code changes.
