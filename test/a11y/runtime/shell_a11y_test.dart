// Runtime accessibility audit: the dashboard, the side menu in its expanded
// and collapsed forms (the drawer on the phone), the menu's dialogs, and the
// reports screen.  See README.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/dashboard/dashboard_actions.dart';
import 'package:invoiceninja_flutter/redux/reports/reports_actions.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'support/harness.dart';
import 'support/walk.dart';

void main() {
  testWidgets('desktop: expanded side menu', (tester) async {
    await withApp(tester, AuditViewport.desktop, collapseMenu: false, (
      app,
    ) async {
      await app.audit('menu-expanded/dashboard');
      await screen(
        app,
        'menu-expanded/client/list',
        () => openList(app, EntityType.client),
      );
      await screen(
        app,
        'menu-expanded/invoice/edit',
        () => openEditor(app, record(app, EntityType.invoice, 'inv_05')),
      );
      await cancelEditor(app);
      await openList(app, EntityType.client);
      await screen(
        app,
        'menu-expanded/contact-us-dialog',
        () => tapIcon(app, Icons.mail),
      );
      await closeOverlays(app);
      await screen(
        app,
        'menu-expanded/about-dialog',
        () => tapIcon(app, Icons.info_outline),
      );
      await closeOverlays(app);
    });
  });

  for (final viewport in AuditViewport.values) {
    testWidgets('${viewport.id}: dashboard and reports', (tester) async {
      await withApp(tester, viewport, (app) async {
        await app.audit('dashboard');
        await auditOtherTabs(app, 'dashboard');
        if (viewport.isDesktop) {
          await screen(
            app,
            'dashboard/settings-dialog',
            () => tapIcon(app, MdiIcons.tuneVariant),
          );
          await closeOverlays(app);
        } else {
          await screen(app, 'menu/drawer', () => tapIcon(app, Icons.menu));
          await closeDrawer(app);
        }
        await screen(app, 'reports', () async {
          app.store.dispatch(ViewReports(force: true));
          await app.settle(8);
        });
        app.store.dispatch(ViewDashboard(force: true));
        await app.settle(8);
      });
    });
  }
}
