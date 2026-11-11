/// Steps a user takes in the app: signing in, opening a module, a record, a
/// form.
///
/// Signing in, and everything inside a screen (tabs, menus, dialogs, the
/// filter and sort controls), is done with taps and typed text.  Moving
/// between modules and records calls the functions the app's own `onTap`
/// handlers call (`viewEntitiesByType`, `viewEntity`, `editEntity`,
/// `createEntityByType`, and the `ViewSettings` action), so the app's
/// middleware does the navigation exactly as it does for a tap.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/main_app.dart';
import 'package:invoiceninja_flutter/redux/app/app_actions.dart';
import 'package:invoiceninja_flutter/redux/settings/settings_actions.dart';

import 'fixture.dart';
import 'harness.dart';

/// The strings of the `Text` widgets on screen, in tree order.
List<String> visibleTexts(WidgetTester tester) => [
  for (final element in find.byType(Text).evaluate())
    (element.widget as Text).data ??
        (element.widget as Text).textSpan?.toPlainText() ??
        '',
];

/// Taps the [index]th hit-testable widget showing [text].
Future<void> tapText(App app, String text, {int index = 0}) async {
  final finder = find.text(text).hitTestable();
  if (finder.evaluate().length <= index) {
    throw StateError('no tappable "$text" on screen');
  }
  await app.tester.tap(finder.at(index));
  await app.settle();
}

/// Taps the first hit-testable widget with [icon].
Future<void> tapIcon(App app, IconData icon, {int index = 0}) async {
  final finder = find.byIcon(icon).hitTestable();
  if (finder.evaluate().length <= index) {
    throw StateError('no tappable icon $icon on screen');
  }
  await app.tester.tap(finder.at(index));
  await app.settle();
}

/// Taps the first hit-testable widget with the tooltip [message].
Future<void> tapTooltip(App app, String message) async {
  final finder = find.byTooltip(message).hitTestable();
  if (finder.evaluate().isEmpty) {
    throw StateError('no tappable tooltip "$message" on screen');
  }
  await app.tester.tap(finder.first);
  await app.settle();
}

/// The text field whose decoration label is [label].
Finder fieldLabelled(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

/// Fills in the self-hosted login form and signs in, as a user would.
Future<void> signIn(App app) async {
  final tester = app.tester;
  await tapText(app, 'Self-Hosted');
  await tester.enterText(fieldLabelled('Email'), kFixtureEmail);
  await tester.enterText(fieldLabelled('Password'), 'correct horse battery');
  await tester.enterText(fieldLabelled('URL'), kFixtureUrl);
  await app.settle(2);
  await tapText(app, 'Login with email');
  await app.waitFor(
    () => app.state.authState.isAuthenticated && !app.state.isLoading,
    what: 'the login to finish',
  );
  await app.settle(10);
}

/// Launches the app, signs in, runs [body] and takes the app down, whatever
/// [body] does.
///
/// Everything runs in a zone of its own, so an error the app lets escape
/// from a timer or a future is recorded on the next screen instead of
/// failing the test.
Future<void> withApp(
  WidgetTester tester,
  AuditViewport viewport,
  Future<void> Function(App app) body, {
  bool withData = true,
  bool signedIn = true,
  bool collapseMenu = true,
}) async {
  App? running;
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      try {
        final app = running = await App.launch(
          tester,
          viewport,
          withData: withData,
        );
        if (signedIn) {
          await signIn(app);
          if (collapseMenu && viewport.isDesktop) {
            // The chevron at the foot of the side menu.
            await tapIcon(app, Icons.chevron_left);
            // What the expanded menu reported belongs to the
            // `menu-expanded/` screens, not to the first screen audited
            // after it was collapsed.
            app.forgetExceptions();
          }
        }
        await body(app);
        done.complete();
      } on Object catch (error, stack) {
        done.completeError(error, stack);
      }
    },
    (error, stack) {
      running?.recordAsyncError(error, stack);
    },
  );
  try {
    await done.future;
  } finally {
    await running?.close();
  }
}

/// Runs [steps] and audits the screen under [id]; when a step throws, the
/// screen is recorded as not reached with the reason, and the walk goes on.
Future<void> screen(
  App app,
  String id,
  Future<void> Function() steps, {
  bool? grow,
}) async {
  try {
    await steps();
  } on Object catch (error) {
    app.notReached(id, error);
    return;
  }
  // A menu, dialog, sheet or drawer is audited in the viewport it opened
  // in; growing the view would stretch it over the page behind it.
  await app.audit(id, grow: grow ?? !_overlay.hasMatch(id));
}

final RegExp _overlay = RegExp(r'(menu|dialog|sheet|drawer|picker|sidebar)$');

BuildContext get _context => navigatorKey.currentContext!;

/// Every record of [type] in the signed-in company, in id order.
List<BaseEntity> records(App app, EntityType type) {
  final map = app.state.getEntityMap(type)!;
  final ids = map.keys.whereType<String>().toList()..sort();
  return [for (final id in ids) map[id]! as BaseEntity];
}

BaseEntity record(App app, EntityType type, String id) =>
    app.state.getEntityMap(type)![id]! as BaseEntity;

/// Opens a module's list, as the side menu does.
Future<void> openList(App app, EntityType type) async {
  viewEntitiesByType(entityType: type);
  await app.settle(8);
}

/// Opens a record, as tapping its row does.
Future<void> openRecord(App app, BaseEntity entity) async {
  viewEntity(entity: entity);
  await app.settle(8);
}

/// Opens a record's form, as its Edit button does.
Future<void> openEditor(App app, BaseEntity entity) async {
  editEntity(entity: entity);
  await app.settle(8);
}

/// Opens a blank form, as the module's New button does.
Future<void> openNew(App app, EntityType type) async {
  createEntityByType(context: _context, entityType: type);
  await app.settle(8);
}

/// Opens a settings page, as tapping it in the settings list does.
Future<void> openSettings(App app, [String? section]) async {
  app.store.dispatch(
    ViewSettings(
      company: app.state.company,
      user: app.state.user,
      section: section,
      force: true,
    ),
  );
  await app.settle(8);
}

/// Leaves a form the way its Cancel button does, discarding changes.
Future<void> cancelEditor(App app) async {
  if (find.text('Cancel').hitTestable().evaluate().isNotEmpty) {
    await tapText(app, 'Cancel');
  } else if (find.byType(BackButton).hitTestable().evaluate().isNotEmpty) {
    await app.tester.tap(find.byType(BackButton).hitTestable().first);
    await app.settle();
  } else if (find
      .byIcon(Icons.arrow_back)
      .hitTestable()
      .evaluate()
      .isNotEmpty) {
    await tapIcon(app, Icons.arrow_back);
  }
  // "Discard changes?" when the form was touched.
  if (find.text('Discard Changes').hitTestable().evaluate().isNotEmpty) {
    await tapText(app, 'Discard Changes');
  }
}

/// `Overview` -> `overview`, `Billing Address` -> `billing-address`.
String slug(String label) => label
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _tabLabel(Widget tab) {
  if (tab is Tab) {
    final child = tab.child;
    return tab.text ?? (child is Text ? child.data ?? '' : '');
  }
  return '';
}

/// Shows every tab after the first of each tab bar on screen in turn and
/// audits it under `<baseId>/tab-<label>`; then returns to the first tab.
///
/// The tab is selected through the bar's own controller, which is what a tap
/// on the tab does; a tab scrolled out of a scrolling bar cannot be tapped
/// without scrolling the bar first.
Future<void> auditOtherTabs(App app, String baseId, {int maxTabs = 12}) async {
  final tester = app.tester;
  final barCount = find.byType(TabBar).evaluate().length;
  for (var bar = 0; bar < barCount; bar++) {
    TabController? controllerOf() {
      final elements = find.byType(TabBar).evaluate().toList();
      if (bar >= elements.length) return null;
      final widget = elements[bar].widget as TabBar;
      return widget.controller ?? DefaultTabController.maybeOf(elements[bar]);
    }

    final first = find.byType(TabBar).evaluate().toList()[bar].widget as TabBar;
    final labels = [for (final tab in first.tabs) _tabLabel(tab)];
    for (var i = 1; i < labels.length && i <= maxTabs; i++) {
      final label = slug(labels[i]).isEmpty ? '$i' : slug(labels[i]);
      await screen(app, '$baseId/tab-$label', () async {
        final controller = controllerOf();
        if (controller == null) {
          throw StateError('the tab bar is gone');
        }
        controller.animateTo(i);
        await app.settle(6);
      });
    }
    controllerOf()?.animateTo(0);
    await app.settle(4);
  }
  await tester.pump();
}

/// Closes whatever menu, dialog or sheet is open, after it was audited.
Future<void> closeOverlays(App app) async {
  navigatorKey.currentState!.popUntil((route) => route is! PopupRoute);
  await app.settle(4);
}

/// The usual round of one module: its list, a record, the record's other
/// tabs, its form and the form's other tabs, and a blank form.
Future<void> tourModule(
  App app,
  EntityType type, {
  String? recordId,
  bool viewTabs = true,
  bool editTabs = true,
}) async {
  final name = type.snakeCase;
  await screen(app, '$name/list', () => openList(app, type));
  final all = records(app, type);
  if (all.isEmpty) {
    app.notReached('$name/view', 'the account has no ${type.snakeCase}');
    return;
  }
  final entity = recordId == null ? all.first : record(app, type, recordId);
  await screen(app, '$name/view', () => openRecord(app, entity));
  if (viewTabs) {
    await auditOtherTabs(app, '$name/view');
  }
  await screen(app, '$name/edit', () => openEditor(app, entity));
  if (editTabs) {
    await auditOtherTabs(app, '$name/edit');
  }
  await cancelEditor(app);
  await screen(app, '$name/new', () => openNew(app, type));
  await cancelEditor(app);
}

/// Closes an open drawer (the phone's menu, the history sidebar), which is
/// an entry on its route rather than a route of its own.
Future<void> closeDrawer(App app) async {
  final drawers = find.byType(Drawer).evaluate();
  if (drawers.isNotEmpty) {
    Navigator.of(drawers.first).pop();
    await app.settle(4);
  }
}
