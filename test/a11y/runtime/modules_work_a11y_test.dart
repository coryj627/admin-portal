// Runtime accessibility audit: products, projects, tasks, vendors, purchase
// orders, expenses and recurring expenses.  See README.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';

import 'support/harness.dart';
import 'support/walk.dart';

void main() {
  for (final viewport in AuditViewport.values) {
    for (final (type, id) in const [
      (EntityType.product, 'prd_01'),
      (EntityType.project, 'prj_03'),
      (EntityType.task, 'tsk_04'),
      (EntityType.vendor, 'ven_01'),
      (EntityType.purchaseOrder, 'po_01'),
      (EntityType.expense, 'exp_02'),
      (EntityType.recurringExpense, 'rex_01'),
    ]) {
      testWidgets('${viewport.id}: ${type.snakeCase}', (tester) async {
        await withApp(tester, viewport, (app) async {
          await tourModule(app, type, recordId: id);
        });
      });
    }
  }
}
