# FloatNote

FloatNote is now a native macOS app built with Swift, SwiftUI, and AppKit.

The repository keeps the product and UX documents at the root, and the app itself follows the same layout style as `Glacier`:

- `project.yml` at the root
- `FloatNote/` for app source
- `FloatNote.xcodeproj` generated from XcodeGen
- `FloatNote.entitlements` at the root

## Run

Open the project directly:

```bash
cd /Users/fran/Workspace/FloatNote
open FloatNote.xcodeproj
```

Regenerate the Xcode project only if you change `project.yml`:

```bash
cd /Users/fran/Workspace/FloatNote
xcodegen generate
```

Build from the command line:

```bash
xcodebuild -project FloatNote.xcodeproj -scheme FloatNote -configuration Debug build
```

Every successful build also installs `FloatNote.app` into the first writable app location, preferring `~/Applications` and falling back to `~/Workspace/Applications`, then re-registers it with LaunchServices and Spotlight so `FloatNote` appears in Spotlight search.

## Current Native MVP

- floating macOS window
- global toggle hotkey with default `Control + A`
- local older / newer shortcuts with default `Control + Shift + Left/Right`
- live markdown styling for headings, lists, quotes, emphasis, links, and fenced code
- last viewed note restore
- note navigation in creation order
- new note creation from the right edge
- footer `Created` / `Updated`
- onboarding overlay
- settings overlay with shortcut capture and window size
- local JSON persistence in Application Support

## Docs

- [PRODUCT_PLAN.md](/Users/fran/Workspace/FloatNote/PRODUCT_PLAN.md)
- [UX_FLOW.md](/Users/fran/Workspace/FloatNote/UX_FLOW.md)
- [WIREFRAMES.md](/Users/fran/Workspace/FloatNote/WIREFRAMES.md)
- [README.md](/Users/fran/Workspace/FloatNote/design/lowfi/README.md)
