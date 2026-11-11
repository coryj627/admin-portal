// Runtime accessibility audit: clients, invoices (with the editor's tabs),
// recurring invoices, quotes, credits and payments.  See README.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';

import 'support/harness.dart';
import 'support/walk.dart';

void main() {
  for (final viewport in AuditViewport.values) {
    for (final (type, id) in const [
      (EntityType.client, 'cli_03'),
      (EntityType.invoice, 'inv_05'),
      (EntityType.recurringInvoice, 'rec_01'),
      (EntityType.quote, 'quo_01'),
      (EntityType.credit, 'crd_02'),
      (EntityType.payment, 'pay_05'),
    ]) {
      testWidgets('${viewport.id}: ${type.snakeCase}', (tester) async {
        await withApp(tester, viewport, (app) async {
          await tourModule(app, type, recordId: id);
        });
      });
    }
  }
}
