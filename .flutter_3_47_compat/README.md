# Two packages patched so the app compiles on Flutter 3.47

The app pins Flutter 3.41.9 (`.flutter-version`). The runtime accessibility
audit under `test/a11y/runtime/` needs `flutter_a11y_test`, which needs
Flutter 3.47 or later, and on Flutter 3.47.9 the app does not compile:

```
material_design_icons_flutter-7.0.7296/lib/icon_map.dart:7302:28: Error: The class 'IconData' can't be extended outside of its library because it's a final class.
super_editor/lib/src/default_editor/document_ime/document_ime_communication.dart:22:7: Error: The non-abstract class 'DocumentImeInputClient' is missing implementations for these members:
 - TextInputConnection.updateStyle
```

Neither package has a release that fixes this (7.0.7296 is the newest
`material_design_icons_flutter`; `super_editor` main, 068a20d, still lacks
`updateStyle` and no longer matches `super_editor_markdown` at the pinned
commit). So `pubspec.yaml` overrides both with the copies here:

- `material_design_icons_flutter/`: `lib/`, licence and pubspec of 7.0.7296.
  In `lib/icon_map.dart` each `_MdiIconData(0x…)` is written out as
  `IconData(0x…, fontFamily: 'Material Design Icons', fontPackage:
  'material_design_icons_flutter')` and the `_MdiIconData` class is removed.
  The icons and the font are unchanged.
- `super_editor/`: `lib/`, licence and pubspec (without `dev_dependencies`)
  of commit 9655c7f987968d680f83fc095a604f86d9ad15a1, the commit the app
  already pinned. One method is added to `TextInputConnectionDecorator` in
  `lib/src/default_editor/document_ime/ime_decoration.dart`:
  `updateStyle`, forwarded to the wrapped connection like its neighbours.

The directory name starts with a dot so that `a11y_check_flutter scan`, which
skips hidden directories, does not report on vendored code.

Remove this directory and the two overrides when the app moves to a Flutter
on which the upstream packages compile.
