// Runtime accessibility audit: a new account with no records: the empty
// dashboard and each module's empty list.  See README.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';

import 'support/harness.dart';
import 'support/walk.dart';

void main() {
  for (final viewport in AuditViewport.values) {
    testWidgets('${viewport.id}: empty account', (tester) async {
      await withApp(tester, viewport, withData: false, (app) async {
        await app.audit('empty/dashboard');
        for (final type in const [
          EntityType.client,
          EntityType.product,
          EntityType.invoice,
          EntityType.recurringInvoice,
          EntityType.payment,
          EntityType.quote,
          EntityType.credit,
          EntityType.project,
          EntityType.task,
          EntityType.vendor,
          EntityType.purchaseOrder,
          EntityType.expense,
          EntityType.recurringExpense,
        ]) {
          await screen(
            app,
            'empty/${type.snakeCase}/list',
            () => openList(app, type),
          );
        }
      });
    });
  }
}
