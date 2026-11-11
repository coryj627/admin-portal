/// The settings home and its pages, for one viewport.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/constants.dart';

import 'harness.dart';
import 'walk.dart';

/// The settings pages, split in two so each test stays short.
const _basic = <String>[
  kSettingsCompanyDetails,
  kSettingsUserDetails,
  kSettingsLocalization,
  kSettingsPaymentSettings,
  kSettingsTaxSettings,
  kSettingsProducts,
  kSettingsTasks,
  kSettingsExpenses,
  kSettingsWorkflowSettings,
  kSettingsImportExport,
  kSettingsAccountManagement,
  kSettingsDeviceSettings,
];

const _advanced = <String>[
  kSettingsInvoiceDesign,
  kSettingsGeneratedNumbers,
  kSettingsCustomFields,
  kSettingsClientPortal,
  kSettingsEmailSettings,
  kSettingsGroupSettings,
  kSettingsUserManagement,
  kSettingsPaymentTerms,
  kSettingsTaxRates,
  kSettingsCompanyGateways,
  kSettingsExpenseCategories,
  kSettingsTaskStatuses,
  // Last, and last in its file: a later test in the same isolate that opens
  // this page again got "Duplicate GlobalKey" for the page's static form key
  // (see the README).
  kSettingsTemplatesAndReminders,
];

void settingsTests(AuditViewport viewport) {
  for (final (name, sections) in const [
    ('basic', _basic),
    ('advanced', _advanced),
  ]) {
    testWidgets('${viewport.id}: settings, $name', (tester) async {
      await withApp(tester, viewport, (app) async {
        if (name == 'basic') {
          await screen(app, 'settings/home', () => openSettings(app));
        }
        for (final section in sections) {
          final id = 'settings/${section.replaceAll('_', '-')}';
          await screen(app, id, () async {
            // On the phone each page is pushed on the one before it; go
            // back to the settings list first and let the old page go.
            if (!viewport.isDesktop) {
              await openSettings(app);
              await app.settle(12);
            }
            await openSettings(app, section);
          });
          await auditOtherTabs(app, id);
        }
      });
    });
  }
}
