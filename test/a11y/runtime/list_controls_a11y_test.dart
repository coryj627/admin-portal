// Runtime accessibility audit: what a user does with a list: search it,
// filter it by state, sort it, pick columns, select several rows, open a
// row's menu; and the menus and dialogs of a record and of a form.
// See README.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';

import 'support/harness.dart';
import 'support/walk.dart';

void main() {
  testWidgets('desktop: list controls', (tester) async {
    await withApp(tester, AuditViewport.desktop, (app) async {
      await openList(app, EntityType.client);
      await screen(app, 'client/list/search', () async {
        await tester.enterText(find.byType(TextField).first, 'ar');
        await app.settle();
      });
      await tester.enterText(find.byType(TextField).first, '');
      await app.settle();
      await screen(
        app,
        'client/list/state-filter-menu',
        () => tapIcon(app, Icons.arrow_drop_down),
      );
      await closeOverlays(app);
      await screen(
        app,
        'client/list/row-menu',
        () => tapIcon(app, Icons.more_vert),
      );
      await closeOverlays(app);
      await screen(
        app,
        'client/list/columns-dialog',
        () => tapText(app, 'Columns'),
      );
      await closeOverlays(app);
      await screen(app, 'client/list/multiselect', () async {
        await tapIcon(app, Icons.check_box);
        await tester.tap(find.byType(Checkbox).hitTestable().at(1));
        await tester.tap(find.byType(Checkbox).hitTestable().at(2));
        await app.settle();
      });
      // Leave multiselect with the toggle that entered it.
      await tapIcon(app, Icons.check_box);
      // The same list as cards instead of a table.
      await screen(
        app,
        'client/list/card-layout',
        () => tapIcon(app, Icons.view_list),
      );
      await tapIcon(app, Icons.table_chart);

      // A record's own menu, and the dialogs of the invoice form.
      await openList(app, EntityType.invoice);
      await openRecord(app, record(app, EntityType.invoice, 'inv_05'));
      await screen(app, 'invoice/view/actions-menu', () async {
        final menus = find.byIcon(Icons.more_vert).hitTestable();
        await tester.tap(menus.last);
        await app.settle();
      });
      await closeOverlays(app);
      await openEditor(app, record(app, EntityType.invoice, 'inv_05'));
      await screen(
        app,
        'invoice/edit/date-picker',
        () => tapIcon(app, Icons.date_range),
      );
      await closeOverlays(app);
      await screen(app, 'invoice/edit/more-menu', () => tapText(app, 'More'));
      await closeOverlays(app);
      await screen(app, 'invoice/edit/discard-changes-dialog', () async {
        await tester.enterText(fieldLabelled('PO Number'), 'PO-1');
        await app.settle(2);
        await tapText(app, 'Back');
      });
      await closeOverlays(app);
      await cancelEditor(app);
      // The history sidebar, now that some records have been opened.
      await openList(app, EntityType.invoice);
      await screen(app, 'history-sidebar', () => tapIcon(app, Icons.history));
      await closeDrawer(app);
    });
  });

  testWidgets('phone: list controls', (tester) async {
    await withApp(tester, AuditViewport.phone, (app) async {
      await openList(app, EntityType.client);
      await screen(app, 'client/list/search', () async {
        await tester.enterText(find.byType(TextField).first, 'ar');
        await app.settle();
      });
      await tester.enterText(find.byType(TextField).first, '');
      await app.settle();
      // The filter and sort sheets stay open until their button is tapped
      // again.
      await screen(
        app,
        'client/list/filter-sheet',
        () => tapIcon(app, Icons.filter_list),
      );
      await tapIcon(app, Icons.filter_list);
      await screen(
        app,
        'client/list/sort-sheet',
        () => tapIcon(app, Icons.sort_by_alpha),
      );
      await tapIcon(app, Icons.sort_by_alpha);
      await screen(app, 'client/list/multiselect', () async {
        await tapIcon(app, Icons.check_box);
        await tapText(app, 'Acme Hardware Supply');
        await tapText(app, 'Blue Harbor Dental');
      });
      await screen(
        app,
        'client/list/multiselect-actions-menu',
        () => tapText(app, 'Actions'),
      );
      await closeOverlays(app);
      await tapText(app, 'Cancel');
      await screen(
        app,
        'client/list/table-layout',
        () => tapIcon(app, Icons.table_chart),
      );
      await tapIcon(app, Icons.view_list);

      await openList(app, EntityType.invoice);
      await openRecord(app, record(app, EntityType.invoice, 'inv_05'));
      await screen(
        app,
        'invoice/view/actions-menu',
        () => tapIcon(app, Icons.more_vert),
      );
      await closeOverlays(app);
      await openEditor(app, record(app, EntityType.invoice, 'inv_05'));
      await screen(
        app,
        'invoice/edit/date-picker',
        () => tapIcon(app, Icons.date_range),
      );
      await closeOverlays(app);
      await screen(
        app,
        'invoice/edit/more-menu',
        () => tapIcon(app, Icons.more_vert),
      );
      await closeOverlays(app);
      await screen(
        app,
        'invoice/edit/add-item-dialog',
        () => tapIcon(app, Icons.add),
      );
      await closeOverlays(app);
      await screen(app, 'invoice/edit/discard-changes-dialog', () async {
        await tester.enterText(fieldLabelled('PO Number'), 'PO-1');
        await app.settle(2);
        await tapIcon(app, Icons.arrow_back);
      });
      await closeOverlays(app);
    });
  });
}
