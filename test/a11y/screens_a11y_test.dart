// Accessibility audit of a slice of screens (flutter_a11y_test, layer "runtime"),
// on this fork only: dogfood of https://github.com/coryj627/flutter-a11y.
//
// The admin portal has no widget tests of its own, so this builds the smallest
// harness that renders real screens: a redux Store over the real appReducer with no
// middleware (nothing is fetched or persisted), seeded with a self-hosted, logged-in
// state that has one company, inside a StoreProvider + MaterialApp with the app's
// localization delegates. MainScreen picks the screen from uiState.currentRoute, so
// each screen is reached by dispatching UpdateCurrentRoute. Findings are RECORDED,
// not asserted: the RuntimeFindingsSink in test/flutter_test_config.dart writes them
// to .a11y/flutter/runtime-findings.json and `a11y_check_flutter scan` decides,
// against the committed baseline, what fails CI.
import 'package:flutter/material.dart';
import 'package:flutter_a11y_test/flutter_a11y_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceninja_flutter/redux/app/app_reducer.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/redux/ui/pref_state.dart';
import 'package:invoiceninja_flutter/redux/ui/ui_actions.dart';
import 'package:invoiceninja_flutter/ui/app/main_screen.dart';
import 'package:invoiceninja_flutter/ui/auth/login_vm.dart';
import 'package:invoiceninja_flutter/ui/client/client_screen.dart';
import 'package:invoiceninja_flutter/ui/dashboard/dashboard_screen_vm.dart';
import 'package:invoiceninja_flutter/ui/expense/expense_screen.dart';
import 'package:invoiceninja_flutter/ui/invoice/invoice_screen.dart';
import 'package:invoiceninja_flutter/ui/payment/payment_screen.dart';
import 'package:invoiceninja_flutter/ui/product/product_screen.dart';
import 'package:invoiceninja_flutter/ui/project/project_screen.dart';
import 'package:invoiceninja_flutter/ui/quote/quote_screen.dart';
import 'package:invoiceninja_flutter/ui/reports/reports_screen.dart';
import 'package:invoiceninja_flutter/ui/settings/settings_screen.dart';
import 'package:invoiceninja_flutter/ui/task/task_screen.dart';
import 'package:invoiceninja_flutter/ui/vendor/vendor_screen.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:redux/redux.dart';

/// A self-hosted install (so the user needs no e-mail confirmation); logged in with
/// one company when [loggedIn].
AppState _state({required bool loggedIn}) {
  final state = AppState(
    prefState: PrefState(),
    reportErrors: false,
    isWhiteLabeled: false,
    url: 'https://ninja.self-hosted.example',
  );
  if (!loggedIn) {
    return state;
  }
  return state.rebuild(
    (b) => b
      ..authState.isAuthenticated = true
      ..userCompanyStates[0] = state.userCompanyStates[0].rebuild(
        (u) => u
          ..userCompany.company.id = 'company-1'
          ..userCompany.user.id = 'user-1'
          ..userCompany.user.firstName = 'Ada'
          ..userCompany.user.lastName = 'Lovelace'
          ..userCompany.user.email = 'ada@example.com'
          ..userCompany.user.emailVerifiedAt = 1,
      ),
  );
}

Future<void> _audit(
  WidgetTester tester,
  String screenId, {
  required bool loggedIn,
  String? route,
}) async {
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final store = Store<AppState>(
    appReducer,
    initialState: _state(loggedIn: loggedIn),
  );
  if (route != null) {
    store.dispatch(UpdateCurrentRoute(route));
  }
  await tester.pumpWidget(
    StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: loggedIn ? MainScreen() : const LoginScreen(),
      ),
    ),
  );
  // Fixed pumps rather than pumpAndSettle: progress indicators animate indefinitely.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 300));
  final result = await auditScreen(tester, screenId: screenId);
  // ignore: avoid_print
  print('a11y $screenId: ${result.findings.length} finding(s)');
}

void main() {
  testWidgets('login', (tester) async {
    await _audit(tester, 'login', loggedIn: false);
  });

  for (final (id, route) in [
    ('dashboard', DashboardScreenBuilder.route),
    ('clients', ClientScreen.route),
    ('invoices', InvoiceScreen.route),
    ('products', ProductScreen.route),
    ('payments', PaymentScreen.route),
    ('quotes', QuoteScreen.route),
    ('expenses', ExpenseScreen.route),
    ('vendors', VendorScreen.route),
    ('tasks', TaskScreen.route),
    ('projects', ProjectScreen.route),
    ('settings', SettingsScreen.route),
    ('reports', ReportsScreen.route),
  ]) {
    testWidgets(id, (tester) async {
      await _audit(tester, id, loggedIn: true, route: route);
    });
  }
}
