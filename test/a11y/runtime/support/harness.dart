/// Shared plumbing for the runtime accessibility audit under
/// `test/a11y/runtime/`: the fake server, the real store, the two viewports,
/// real fonts, booting and signing in to the real app, the audit call and the
/// per-screen log.
///
/// See `README.md` in `test/a11y/runtime/` for what each decision does to
/// findings.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_a11y_test/flutter_a11y_test.dart';
import 'package:built_value/serializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show MultipartFile;
import 'package:invoiceninja_flutter/constants.dart';
import 'package:invoiceninja_flutter/data/file_storage.dart';
import 'package:invoiceninja_flutter/data/models/company_gateway_model.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/data/models/serializers.dart';
import 'package:invoiceninja_flutter/data/repositories/auth_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/bank_account_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/client_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/company_gateway_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/credit_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/design_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/document_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/expense_category_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/expense_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/group_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/invoice_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/payment_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/payment_term_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/persistence_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/product_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/project_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/purchase_order_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/quote_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/recurring_expense_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/recurring_invoice_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/schedule_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/settings_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/subscription_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/task_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/task_status_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/tax_rate_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/token_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/transaction_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/transaction_rule_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/user_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/vendor_repository.dart';
import 'package:invoiceninja_flutter/data/repositories/webhook_repository.dart';
import 'package:invoiceninja_flutter/data/web_client.dart';
import 'package:invoiceninja_flutter/main_app.dart';
import 'package:invoiceninja_flutter/redux/app/app_middleware.dart';
import 'package:invoiceninja_flutter/redux/app/app_reducer.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/redux/auth/auth_middleware.dart';
import 'package:invoiceninja_flutter/redux/bank_account/bank_account_middleware.dart';
import 'package:invoiceninja_flutter/redux/client/client_middleware.dart';
import 'package:invoiceninja_flutter/redux/company_gateway/company_gateway_middleware.dart';
import 'package:invoiceninja_flutter/redux/credit/credit_middleware.dart';
import 'package:invoiceninja_flutter/redux/dashboard/dashboard_middleware.dart';
import 'package:invoiceninja_flutter/redux/design/design_middleware.dart';
import 'package:invoiceninja_flutter/redux/document/document_middleware.dart';
import 'package:invoiceninja_flutter/redux/expense/expense_middleware.dart';
import 'package:invoiceninja_flutter/redux/expense_category/expense_category_middleware.dart';
import 'package:invoiceninja_flutter/redux/group/group_middleware.dart';
import 'package:invoiceninja_flutter/redux/invoice/invoice_middleware.dart';
import 'package:invoiceninja_flutter/redux/payment/payment_middleware.dart';
import 'package:invoiceninja_flutter/redux/payment_term/payment_term_middleware.dart';
import 'package:invoiceninja_flutter/redux/product/product_middleware.dart';
import 'package:invoiceninja_flutter/redux/project/project_middleware.dart';
import 'package:invoiceninja_flutter/redux/purchase_order/purchase_order_middleware.dart';
import 'package:invoiceninja_flutter/redux/quote/quote_middleware.dart';
import 'package:invoiceninja_flutter/redux/recurring_expense/recurring_expense_middleware.dart';
import 'package:invoiceninja_flutter/redux/recurring_invoice/recurring_invoice_middleware.dart';
import 'package:invoiceninja_flutter/redux/reports/reports_middleware.dart';
import 'package:invoiceninja_flutter/redux/schedule/schedule_middleware.dart';
import 'package:invoiceninja_flutter/redux/settings/settings_middleware.dart';
import 'package:invoiceninja_flutter/redux/subscription/subscription_middleware.dart';
import 'package:invoiceninja_flutter/redux/task/task_middleware.dart';
import 'package:invoiceninja_flutter/redux/task_status/task_status_middleware.dart';
import 'package:invoiceninja_flutter/redux/tax_rate/tax_rate_middleware.dart';
import 'package:invoiceninja_flutter/redux/token/token_middleware.dart';
import 'package:invoiceninja_flutter/redux/transaction/transaction_middleware.dart';
import 'package:invoiceninja_flutter/redux/transaction_rule/transaction_rule_middleware.dart';
import 'package:invoiceninja_flutter/redux/ui/pref_state.dart';
import 'package:invoiceninja_flutter/redux/user/user_middleware.dart';
import 'package:invoiceninja_flutter/redux/vendor/vendor_middleware.dart';
import 'package:invoiceninja_flutter/redux/webhook/webhook_middleware.dart';
import 'package:invoiceninja_flutter/utils/completers.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture.dart';

// ---------------------------------------------------------------------------
// Viewports
// ---------------------------------------------------------------------------

/// One of the two layouts every screen is audited in.
enum AuditViewport {
  /// A desktop browser window: 1280x800 logical px at DPR 1.  The app picks
  /// its desktop layout at this width, which is what most of its users see.
  desktop('desktop', Size(1280, 800), 1, TargetPlatform.macOS),

  /// The phone viewport the other real-app audits use: 412x915 at DPR 3.
  /// The app picks its mobile layout at this width.
  phone('phone', Size(412, 915), 3, TargetPlatform.android);

  const AuditViewport(this.id, this.size, this.dpr, this.platform);

  /// The prefix of every screen id audited in this viewport.
  final String id;
  final Size size;
  final double dpr;

  /// What `defaultTargetPlatform` is while the screen is pumped.
  final TargetPlatform platform;

  bool get isDesktop => this == AuditViewport.desktop;

  /// The audit configuration for this viewport.
  ///
  /// Library defaults except:
  /// - `platform`: on the desktop viewport `macOS`, a pointer platform, so
  ///   the 48 and 44 px touch-target guidelines are skipped and only the
  ///   24 px minimum of WCAG 2.5.8 is checked; on the phone viewport `null`,
  ///   so both touch guidelines run (the app ships on Android and iOS).
  /// - `sourceRoots`: the app's `lib/`, so a finding is never attributed to
  ///   this harness or to the vendored packages under `.flutter_3_47_compat/`.
  A11yAuditConfig get auditConfig => A11yAuditConfig(
    platform: isDesktop ? TargetPlatform.macOS : null,
    reflow: true,
    sourceRoots: ['${Directory.current.path}/lib/'],
  );
}

/// The tallest a view is ever grown to (logical px), which keeps the frame
/// the contrast rules rasterize under about 100 MB at DPR 3.
const double kMaxGrownHeight = 6000;

/// Where the per-screen log goes, next to the findings the sink writes.
const String kScreensLogPath = '.a11y/flutter/runtime-screens.json';

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

/// Loads Roboto and the two icon fonts, so text is measured as in a browser
/// rather than in the `FlutterTest` font (every glyph a 1 em square).
///
/// The web build sets `fontFamily: 'Roboto'` on its theme.  A VM test is not
/// a web build, so the theme falls back to the platform family; Roboto is
/// registered under those names as well, and every text renders in Roboto
/// as it does in the browser.
///
/// Set `A11Y_TEST_FONT=ahem` to skip this and compare with the default font.
Future<void> loadRealFonts() async {
  if (Platform.environment['A11Y_TEST_FONT'] == 'ahem') return;

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('a11y harness: font file missing: $path');
      }
      loader.addFont(
        file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('a11y harness: FLUTTER_ROOT is not set');
  }
  final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final roboto = [
    for (final style in ['Regular', 'Italic', 'Medium', 'Bold', 'Light'])
      '$materialFonts/Roboto-$style.ttf',
  ];
  for (final family in const [
    'Roboto',
    // What Typography resolves to when defaultTargetPlatform is macOS.
    '.AppleSystemUIFont',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF UI Text',
    '.SF UI Display',
    '.SF Pro Text',
    '.SF Pro Display',
    // The family the test engine uses for a TextStyle with no fontFamily
    // (the app bar title: `appBarTheme.titleTextStyle` names none).  In the
    // app such text falls back to the platform's default font; here it
    // would be drawn as solid boxes.
    'FlutterTest',
    'Ahem',
  ]) {
    await load(family, roboto);
  }
  await load('MaterialIcons', ['$materialFonts/MaterialIcons-Regular.otf']);
  await load('packages/material_design_icons_flutter/Material Design Icons', [
    '.flutter_3_47_compat/material_design_icons_flutter/lib/fonts/'
        'materialdesignicons-webfont.ttf',
  ]);
}

// ---------------------------------------------------------------------------
// Fake server
// ---------------------------------------------------------------------------

/// One request the app made to the fake server.
class ServerCall {
  ServerCall(this.method, this.url, this.answer);
  final String method;
  final String url;

  /// How the fake server answered: `login`, `entity`, `empty`, `pending`...
  final String answer;

  @override
  String toString() => '$method ${_path(url)} -> $answer';

  static String _path(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ? url : uri.path;
  }
}

/// Stands in for the Invoice Ninja server behind every repository.
///
/// It is the app's own seam: each `createStore…Middleware` takes a
/// repository, and each repository takes a [WebClient].  Nothing here opens
/// a socket.
class FakeServer extends WebClient {
  FakeServer({this.withData = true});

  /// Whether the account the server returns has any records in it.
  final bool withData;

  /// Every request since the last [takeCalls].
  final List<ServerCall> calls = [];

  /// When set, the next login is refused with this message.
  String? loginError;

  late final LoginResponse _account = buildLoginResponse(withData: withData);
  late final Map<String, dynamic> _accountJson =
      serializers.serializeWith(LoginResponse.serializer, _account)
          as Map<String, dynamic>;

  List<ServerCall> takeCalls() {
    final taken = List<ServerCall>.of(calls);
    calls.clear();
    return taken;
  }

  Future<dynamic> _answer(String method, String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    final apiIndex = segments.indexOf('v1');
    final path = apiIndex >= 0 ? segments.sublist(apiIndex + 1) : segments;

    dynamic done(String answer, dynamic body) {
      calls.add(ServerCall(method, url, answer));
      return body;
    }

    if (path.isNotEmpty && path.first == 'login') {
      if (loginError != null) {
        calls.add(ServerCall(method, url, 'refused'));
        // The shape WebClient._checkResponse throws for a 4xx answer.
        return Future<dynamic>.error(loginError!);
      }
      return Future<dynamic>.value(done('account', _accountJson));
    }
    if (path.isNotEmpty && path.first == 'refresh') {
      return Future<dynamic>.value(done('account', _accountJson));
    }

    // GET /api/v1/<entities>/<id>: the record as the account holds it.
    if (method == 'GET' && path.length == 2) {
      final body = _entity(path[0], path[1]);
      if (body != null) {
        return Future<dynamic>.value(
          done('entity', <String, dynamic>{'data': body}),
        );
      }
    }

    // GET /api/v1/activities?…, /api/v1/system_logs…: an empty page.
    if (method == 'GET' && path.length == 1) {
      return Future<dynamic>.value(
        done('empty list', <String, dynamic>{'data': <dynamic>[]}),
      );
    }

    // Anything else (PDF previews, chart totals, saves, e-mail) is left
    // pending: the app shows the state it shows while a request is in
    // flight.
    calls.add(ServerCall(method, url, 'pending'));
    return Completer<dynamic>().future;
  }

  dynamic _entity(String collection, String id) {
    final company = _account.userCompanies.first.company;
    T? find<T extends BaseEntity>(Iterable<T> all) {
      for (final entity in all) {
        if (entity.id == id) return entity;
      }
      return null;
    }

    dynamic encode<T>(Serializer<T> serializer, T? entity) =>
        entity == null ? null : serializers.serializeWith(serializer, entity);

    switch (collection) {
      case 'clients':
        return encode(ClientEntity.serializer, find(company.clients));
      case 'invoices':
        return encode(InvoiceEntity.serializer, find(company.invoices));
      case 'quotes':
        return encode(InvoiceEntity.serializer, find(company.quotes));
      case 'credits':
        return encode(InvoiceEntity.serializer, find(company.credits));
      case 'recurring_invoices':
        return encode(
          InvoiceEntity.serializer,
          find(company.recurringInvoices),
        );
      case 'purchase_orders':
        return encode(InvoiceEntity.serializer, find(company.purchaseOrders));
      case 'payments':
        return encode(PaymentEntity.serializer, find(company.payments));
      case 'products':
        return encode(ProductEntity.serializer, find(company.products));
      case 'expenses':
        return encode(ExpenseEntity.serializer, find(company.expenses));
      case 'recurring_expenses':
        return encode(
          ExpenseEntity.serializer,
          find(company.recurringExpenses),
        );
      case 'vendors':
        return encode(VendorEntity.serializer, find(company.vendors));
      case 'projects':
        return encode(ProjectEntity.serializer, find(company.projects));
      case 'tasks':
        return encode(TaskEntity.serializer, find(company.tasks));
      case 'users':
        return encode(UserEntity.serializer, find(company.users));
      case 'company_gateways':
        return encode(
          CompanyGatewayEntity.serializer,
          find(company.companyGateways),
        );
    }
    return null;
  }

  @override
  Future<dynamic> get(String url, String? token, {bool rawResponse = false}) =>
      _answer('GET', url);

  @override
  Future<dynamic> post(
    String url,
    String? token, {
    dynamic data,
    List<MultipartFile>? multipartFiles,
    String? secret,
    String? password,
    String? idToken,
    bool rawResponse = false,
  }) => _answer('POST', url);

  @override
  Future<dynamic> put(
    String url,
    String? token, {
    dynamic data,
    MultipartFile? multipartFile,
    String? password,
    String? idToken,
  }) => _answer('PUT', url);

  @override
  Future<dynamic> delete(
    String url,
    String? token, {
    String? password,
    String? idToken,
    dynamic data,
  }) => _answer('DELETE', url);
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

/// The store `lib/main.dart` builds: the real reducer and every real
/// middleware, in the same order.  The only differences are the repositories'
/// web client ([server]) and the directory persisted state is written to.
Store<AppState> buildStore(FakeServer server, Directory stateDirectory) {
  PersistenceRepository persisted(String tag) => PersistenceRepository(
    fileStorage: FileStorage(tag, () async => stateDirectory),
  );

  return Store<AppState>(
    appReducer,
    // What `_initialState` in lib/main.dart returns on a first launch
    // outside the browser: default preferences, no URL, no deep link.
    initialState: AppState(
      prefState: PrefState(),
      url: '',
      referralCode: '',
      reportErrors: false,
      isWhiteLabeled: false,
      currentRoute: null,
    ),
    middleware: [
      ...createStoreAuthMiddleware(AuthRepository(webClient: server)),
      ...createStoreDocumentsMiddleware(DocumentRepository(webClient: server)),
      ...createStoreDashboardMiddleware(),
      ...createStoreProductsMiddleware(ProductRepository(webClient: server)),
      ...createStoreClientsMiddleware(ClientRepository(webClient: server)),
      ...createStoreInvoicesMiddleware(InvoiceRepository(webClient: server)),
      ...createStoreExpensesMiddleware(ExpenseRepository(webClient: server)),
      ...createStoreVendorsMiddleware(VendorRepository(webClient: server)),
      ...createStoreTasksMiddleware(TaskRepository(webClient: server)),
      ...createStoreProjectsMiddleware(ProjectRepository(webClient: server)),
      ...createStorePaymentsMiddleware(PaymentRepository(webClient: server)),
      ...createStoreQuotesMiddleware(QuoteRepository(webClient: server)),
      ...createStoreSettingsMiddleware(SettingsRepository(webClient: server)),
      ...createStoreReportsMiddleware(),
      ...createStoreSchedulesMiddleware(ScheduleRepository(webClient: server)),
      ...createStoreTransactionRulesMiddleware(
        TransactionRuleRepository(webClient: server),
      ),
      ...createStoreTransactionsMiddleware(
        TransactionRepository(webClient: server),
      ),
      ...createStoreBankAccountsMiddleware(
        BankAccountRepository(webClient: server),
      ),
      ...createStorePurchaseOrdersMiddleware(
        PurchaseOrderRepository(webClient: server),
      ),
      ...createStoreRecurringExpensesMiddleware(
        RecurringExpenseRepository(webClient: server),
      ),
      ...createStoreSubscriptionsMiddleware(
        SubscriptionRepository(webClient: server),
      ),
      ...createStoreTaskStatusesMiddleware(
        TaskStatusRepository(webClient: server),
      ),
      ...createStoreExpenseCategoriesMiddleware(
        ExpenseCategoryRepository(webClient: server),
      ),
      ...createStoreRecurringInvoicesMiddleware(
        RecurringInvoiceRepository(webClient: server),
      ),
      ...createStoreWebhooksMiddleware(WebhookRepository(webClient: server)),
      ...createStoreTokensMiddleware(TokenRepository(webClient: server)),
      ...createStorePaymentTermsMiddleware(
        PaymentTermRepository(webClient: server),
      ),
      ...createStoreDesignsMiddleware(DesignRepository(webClient: server)),
      ...createStoreCreditsMiddleware(CreditRepository(webClient: server)),
      ...createStoreUsersMiddleware(UserRepository(webClient: server)),
      ...createStoreTaxRatesMiddleware(TaxRateRepository(webClient: server)),
      ...createStoreCompanyGatewaysMiddleware(
        CompanyGatewayRepository(webClient: server),
      ),
      ...createStoreGroupsMiddleware(GroupRepository(webClient: server)),
      ...createStorePersistenceMiddleware(
        persisted('auth_state'),
        persisted('ui_state'),
        persisted('static_state'),
        [for (var i = 0; i < 10; i++) persisted('company_state_$i')],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Platform channels
// ---------------------------------------------------------------------------

/// Plugin calls the app made that have no implementation under
/// `flutter test`, by channel and method.  Each was answered with `null`.
final Set<String> unansweredPluginCalls = <String>{};

/// Answers every plugin channel that has no handler, so a missing plugin is
/// a recorded fact about the run instead of a `MissingPluginException`.
///
/// Channels the test binding or a plugin's own test double already handles
/// are passed through untouched.
void answerPluginChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.allMessagesHandler = (channel, handler, message) async {
    if (handler != null) {
      return handler(message);
    }
    if (channel.startsWith('flutter/')) {
      return null;
    }
    if (channel.startsWith('dev.flutter.pigeon.')) {
      unansweredPluginCalls.add(channel);
      // A pigeon reply is a list: [result] on success.
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    }
    var method = '';
    try {
      method = const StandardMethodCodec().decodeMethodCall(message).method;
    } on Object {
      // Not a standard method call; answer it all the same.
    }
    final call = '$channel${method.isEmpty ? '' : '.$method'}';
    // The desktop window: it has the focus and is not maximized.
    const windowAnswers = <String, Object?>{
      'window_manager.isFocused': true,
      'window_manager.isPreventClose': true,
      'window_manager.isMaximized': false,
      'window_manager.isFullScreen': false,
      'window_manager.isMinimized': false,
      'window_manager.isVisible': true,
    };
    if (windowAnswers.containsKey(call)) {
      return const StandardMethodCodec().encodeSuccessEnvelope(
        windowAnswers[call],
      );
    }
    unansweredPluginCalls.add(call);
    return const StandardMethodCodec().encodeSuccessEnvelope(null);
  };
}

// ---------------------------------------------------------------------------
// The running app
// ---------------------------------------------------------------------------

/// The real app, pumped in one [AuditViewport] over a [FakeServer].
class App {
  App._(this.tester, this.viewport, this.server, this.store, this._directory);

  final WidgetTester tester;
  final AuditViewport viewport;
  final FakeServer server;
  final Store<AppState> store;
  final Directory _directory;
  final List<Timer> _periodicTimers = [];

  /// Exceptions caught since the last audit, carried into the next one.
  final List<String> _exceptions = [];

  FlutterExceptionHandler? _testHandler;

  /// Drops what was caught so far; see `withApp`.
  void forgetExceptions() {
    takeExceptions(tester);
    _exceptions.clear();
  }

  /// Records an error the app let escape from a timer or a future.
  void recordAsyncError(Object error, StackTrace stack) {
    var text = 'uncaught: ${describeException(error)}';
    final frame = RegExp(
      r'package:invoiceninja_flutter/(\S+?\.dart)[: ](\d+)',
    ).firstMatch('$stack');
    if (frame != null) {
      text = '$text [lib/${frame.group(1)}:${frame.group(2)}]';
    }
    if (!_exceptions.contains(text)) {
      _exceptions.add(text);
    }
  }

  /// Collects what the framework reports (a build assertion, an overflow)
  /// instead of letting flutter_test fail the test on it: a second report
  /// before the first is taken is otherwise an unrecoverable "Multiple
  /// exceptions" failure, and one screen of this app reports on every build.
  /// Restored in [close], as flutter_test requires.
  void _collectFrameworkErrors() {
    _testHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      var text = describeException(details.exception);
      // Where in the app it came from: the first app frame of the stack, or
      // the widget the framework names as the cause.
      final frame = RegExp(
        r'package:invoiceninja_flutter/(\S+?\.dart)[: ](\d+)',
      ).firstMatch('${details.stack}');
      if (frame != null) {
        text = '$text [lib/${frame.group(1)}:${frame.group(2)}]';
      } else {
        final cause = RegExp(r'/lib/(\S+?\.dart):(\d+)').firstMatch(
          (details.informationCollector?.call() ?? const [])
              .map((node) => node.toStringDeep())
              .join('\n'),
        );
        if (cause != null) {
          text = '$text [lib/${cause.group(1)}:${cause.group(2)}]';
        }
      }
      if (!_exceptions.contains(text)) {
        _exceptions.add(text);
      }
    };
  }

  /// Starts the app as `lib/main.dart` does on a first launch: it shows its
  /// splash screen, finds no saved session and lands on the login screen.
  static Future<App> launch(
    WidgetTester tester,
    AuditViewport viewport, {
    bool withData = true,
  }) async {
    // The debug banner covers the top-right app bar actions.
    WidgetsApp.debugAllowBannerOverride = false;
    // flutter_test paints every shadow as a solid black outline; with this
    // off, cards and dialogs get the soft shadow they have in the app.
    debugDisableShadows = false;
    debugDefaultTargetPlatformOverride = viewport.platform;
    tester.view.devicePixelRatio = viewport.dpr;
    tester.view.physicalSize = viewport.size * viewport.dpr;
    addTearDown(tester.view.reset);

    // A returning user who has already dismissed the desktop-beta invitation
    // (it is not shown on the web at all).
    SharedPreferences.setMockInitialValues(<String, Object>{
      kSharedPrefBetaPromoDone: true,
    });
    answerPluginChannels();

    final directory = Directory.systemTemp.createTempSync('admin-portal-a11y-');
    final server = FakeServer(withData: withData);
    final store = buildStore(server, directory);
    final app = App._(tester, viewport, server, store, directory);
    app._collectFrameworkErrors();

    // InvoiceNinjaApp starts a periodic refresh timer in initState and never
    // cancels it; the zone lets close() cancel it.
    await runZoned(
      () => tester.pumpWidget(InvoiceNinjaApp(store: store)),
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, period, f) {
          final timer = parent.createPeriodicTimer(zone, period, f);
          app._periodicTimers.add(timer);
          return timer;
        },
      ),
    );
    await app.settle();
    return app;
  }

  /// Lets the app finish what it is doing: a few frames, then the route and
  /// ink animations.  Never `pumpAndSettle`: progress indicators and the
  /// refresh timer keep the app busy forever.
  Future<void> settle([int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    _exceptions.addAll(takeExceptions(tester));
  }

  /// Lets work that runs outside the test's fake clock finish: the login
  /// response is decoded on another isolate (`compute`).
  Future<void> waitFor(bool Function() condition, {String? what}) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    if (!condition()) {
      throw StateError('a11y harness: timed out waiting for ${what ?? '?'}');
    }
  }

  AppState get state => store.state;

  /// Takes the app down and lets its one-shot timers run out.
  Future<void> close() async {
    for (final timer in _periodicTimers) {
      timer.cancel();
    }
    // Navigator pops still run their animations.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    // Debounced writes of the UI state (statics in the app).
    PersistDebouncer.timer?.cancel();
    Debouncer.timer?.cancel();
    await tester.pump(const Duration(seconds: 10));
    // What the app reported while it was torn down.  It cannot belong to a
    // screen, but it can leave the framework in a state that changes the
    // next test in this file, so it is kept in the log.
    ScreenLog.teardown([..._exceptions, ...takeExceptions(tester)]);
    _exceptions.clear();
    FlutterError.onError = _testHandler;
    debugDefaultTargetPlatformOverride = null;
    debugDisableShadows = true;
    try {
      _directory.deleteSync(recursive: true);
    } on FileSystemException {
      // A write may still be in flight; the directory is in the system temp.
    }
  }

  /// Audits the screen as it stands under `<viewport>/<id>` and records it.
  ///
  /// [grow] first makes the view tall enough to lay a lazily built list out
  /// in full.
  Future<A11yAuditResult> audit(String id, {bool grow = true}) async {
    final screenId = '${viewport.id}/$id';
    final exceptions = [..._exceptions, ...takeExceptions(tester)];
    _exceptions.clear();
    final original = tester.view.physicalSize;
    var viewSize = original / tester.view.devicePixelRatio;
    if (grow) {
      viewSize = await growViewToFit(tester);
      exceptions.addAll(takeExceptions(tester));
    }
    final remaining = remainingScrollPx(tester);
    await maybeScreenshot(tester, screenId);

    // flutter_a11y_test 0.3.0 rethrows any error other than an overflow that
    // a screen reports while it is re-laid out at 200 % text or at 320 px,
    // and records nothing for the screen.  Such a screen is audited again
    // without the two reflow passes, and the error is kept in the log.
    A11yAuditResult result;
    String? reflowAborted;
    try {
      result = await auditScreen(
        tester,
        screenId: screenId,
        config: viewport.auditConfig,
      );
    } on Object catch (error) {
      reflowAborted = describeException(error);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      result = await auditScreen(
        tester,
        screenId: screenId,
        config: A11yAuditConfig(
          platform: viewport.auditConfig.platform,
          reflow: false,
          sourceRoots: viewport.auditConfig.sourceRoots,
        ),
      );
    }
    exceptions.addAll(_exceptions);
    _exceptions.clear();
    exceptions.addAll(takeExceptions(tester));

    ScreenLog.audited(
      screenId,
      result,
      viewport: viewport,
      viewSize: viewSize,
      remainingScroll: remaining,
      exceptions: exceptions,
      serverCalls: [for (final call in server.takeCalls()) '$call'],
      route: state.uiState.currentRoute,
      reflowAborted: reflowAborted,
    );
    // ignore: avoid_print
    print(
      'a11y $screenId: ${result.findings.length} finding(s)'
      '${exceptions.isEmpty ? '' : ', ${exceptions.length} exception(s)'}'
      '${reflowAborted == null ? '' : ', NO REFLOW: $reflowAborted'}',
    );

    if (tester.view.physicalSize != original) {
      tester.view.physicalSize = original;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      takeExceptions(tester);
    }
    return result;
  }

  /// Records that [id] could not be reached, and why, without failing the
  /// run.
  void notReached(String id, Object reason) {
    final screenId = '${viewport.id}/$id';
    ScreenLog.notReached(screenId, viewport, describeException(reason));
    // ignore: avoid_print
    print('a11y $screenId: NOT REACHED: ${describeException(reason)}');
  }
}

// ---------------------------------------------------------------------------
// View growth, exceptions, screenshots
// ---------------------------------------------------------------------------

/// How far the vertical scrollables on screen can still scroll, in total.
double remainingScrollPx(WidgetTester tester) {
  var total = 0.0;
  for (final element in find.byType(Scrollable).evaluate()) {
    final position =
        ((element as StatefulElement).state as ScrollableState).position;
    if (!position.hasContentDimensions || position.axis != Axis.vertical) {
      continue;
    }
    total += position.maxScrollExtent - position.minScrollExtent;
  }
  return total;
}

/// Grows the view's height until no vertical scrollable has anything left to
/// scroll, so a lazily built list or a long form is laid out (and audited)
/// in full.  Stops at [kMaxGrownHeight].  Returns the final logical size.
Future<Size> growViewToFit(WidgetTester tester) async {
  var size = tester.view.physicalSize / tester.view.devicePixelRatio;
  var previous = double.infinity;
  for (var i = 0; i < 12; i++) {
    final remaining = remainingScrollPx(tester);
    // Growing has stopped helping: what is left is a list that sizes itself
    // to the view (a picker wheel, an endless calendar).
    if (remaining <= 0.5 ||
        remaining >= previous ||
        size.height >= kMaxGrownHeight) {
      break;
    }
    previous = remaining;
    size = Size(
      size.width,
      (size.height + remaining).ceilToDouble().clamp(0, kMaxGrownHeight),
    );
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return size;
}

/// Takes every exception the framework has caught since the last call.
List<String> takeExceptions(WidgetTester tester) {
  final result = <String>[];
  while (true) {
    final Object? exception = tester.takeException();
    if (exception == null) break;
    result.add(describeException(exception));
  }
  return result;
}

/// The first line of an exception, without memory addresses or hash codes.
String describeException(Object exception) {
  final text = exception is FlutterError
      ? exception.message
      : exception.toString();
  // The first two lines: a FlutterError's second line names the widget or
  // the key it is about.
  final firstLine = text
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .take(3)
      .map((l) => l.trim())
      .join(' ');
  final type = exception is String ? '' : '${exception.runtimeType}: ';
  return '$type${firstLine.replaceAll(RegExp(r'#[0-9a-f]{5}\b'), '#…')}';
}

/// Writes a PNG of the screen to `$A11Y_SCREENSHOT_DIR/<screenId>.png`, when
/// that variable is set.  For checking by eye that a screen was reached and
/// looks as it does in the app; not part of the audit.
Future<void> maybeScreenshot(WidgetTester tester, String screenId) async {
  final dir = Platform.environment['A11Y_SCREENSHOT_DIR'];
  if (dir == null || dir.isEmpty) return;
  final renderView = tester.binding.renderViews.first;
  // ignore: invalid_use_of_protected_member
  final layer = renderView.layer! as OffsetLayer;
  final size = tester.view.physicalSize;
  final dpr = tester.view.devicePixelRatio;
  await tester.runAsync(() async {
    // One image pixel per logical pixel on the desktop viewport, two on the
    // phone.
    final image = await layer.toImage(
      Offset.zero & size,
      pixelRatio: dpr >= 3 ? 2 / 3 : 1,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$dir/${screenId.replaceAll('/', '__')}.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

// ---------------------------------------------------------------------------
// Per-screen log
// ---------------------------------------------------------------------------

/// Per-isolate log of the screens this run audited, merged into
/// [kScreensLogPath] by [flush].
abstract final class ScreenLog {
  static final Map<String, Map<String, Object>> _screens = {};

  static void audited(
    String screenId,
    A11yAuditResult result, {
    required AuditViewport viewport,
    required Size viewSize,
    required double remainingScroll,
    required List<String> exceptions,
    required List<String> serverCalls,
    required String route,
    String? reflowAborted,
  }) {
    final perRule = <String, int>{};
    var inLib = 0;
    for (final finding in result.findings) {
      perRule[finding.ruleID] = (perRule[finding.ruleID] ?? 0) + 1;
      if (finding.filePath.startsWith('lib/') ||
          finding.filePath.contains('/lib/')) {
        inLib++;
      }
    }
    if (_screens.containsKey(screenId)) {
      throw StateError('a11y harness: screen id used twice: $screenId');
    }
    _screens[screenId] = <String, Object>{
      'status': 'audited',
      'viewport': viewport.id,
      'devicePixelRatio': viewport.dpr,
      'viewSize': '${viewSize.width.round()}x${viewSize.height.round()}',
      'remainingScrollPx': remainingScroll.round(),
      'route': route,
      'findingCount': result.findings.length,
      'findingsInLib': inLib,
      'rules': Map.fromEntries(
        perRule.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
      if (result.diagnostics.isNotEmpty)
        'diagnostics': [for (final d in result.diagnostics) d.id]..sort(),
      if (exceptions.isNotEmpty) 'exceptions': exceptions.toSet().toList(),
      if (reflowAborted != null) 'reflowPassesAborted': reflowAborted,
      if (serverCalls.isNotEmpty) 'serverCalls': serverCalls,
    };
  }

  static final Set<String> _teardown = <String>{};

  static void teardown(List<String> exceptions) => _teardown.addAll(exceptions);

  static void notReached(
    String screenId,
    AuditViewport viewport,
    String reason,
  ) {
    _screens[screenId] = <String, Object>{
      'status': 'not reached',
      'viewport': viewport.id,
      'reason': reason,
    };
  }

  /// Merges this isolate's screens into [kScreensLogPath].
  ///
  /// Test files run in separate isolates at the same time, so the file is
  /// locked while it is read and rewritten.
  static Future<void> flush() async {
    if (_screens.isEmpty && _teardown.isEmpty) return;
    final file = File(kScreensLogPath);
    file.parent.createSync(recursive: true);
    final lock = File('$kScreensLogPath.lock').openSync(mode: FileMode.write);
    try {
      lock.lockSync(FileLock.blockingExclusive);
      final merged = <String, Object?>{};
      if (file.existsSync()) {
        try {
          merged.addAll(
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
          );
        } on Object {
          // An unreadable log is replaced.
        }
      }
      merged.addAll(_screens);
      if (_teardown.isNotEmpty) {
        final known = <String>{
          ...((merged['_exceptionsWhileClosingTheApp'] as List?) ?? const [])
              .cast<String>(),
          ..._teardown,
        }.toList()..sort();
        merged['_exceptionsWhileClosingTheApp'] = known;
      }
      if (unansweredPluginCalls.isNotEmpty) {
        final known = <String>{
          ...((merged['_pluginCallsAnsweredWithNull'] as List?) ?? const [])
              .cast<String>(),
          ...unansweredPluginCalls,
        }.toList()..sort();
        merged['_pluginCallsAnsweredWithNull'] = known;
      }
      final sorted = Map.fromEntries(
        merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
      );
    } finally {
      lock.unlockSync();
      lock.closeSync();
    }
  }
}
