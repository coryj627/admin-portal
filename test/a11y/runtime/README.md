# Runtime accessibility audit (a11y-dogfood-runtime branch)

This directory is not part of upstream admin-portal. It is a dogfood of
[flutter-a11y](https://github.com/coryj627/flutter-a11y) (private): widget
tests that start the real app over a fake server, sign in through the login
form, walk to each screen, and record what `flutter_a11y_test` 0.4.1 finds on
the rendered semantics tree.

**This is a VM widget-test run (`flutter test`), not a browser run.** Nothing
here builds the web app or looks at a DOM. It audits the semantics tree Flutter
builds, which is the tree a web build turns into its accessibility DOM, in a
view sized like a desktop browser window and like a phone.

The findings are meant to be labelled by people afterwards. The tests
**record** findings and never assert on them: no rule is disabled, no screen is
skipped because it has findings, and a screen with findings passes.

## Run it

```sh
cp lib/.env.dart.example lib/.env.dart   # once; the file is git-ignored
flutter pub get                          # needs read access to coryj627/flutter-a11y
flutter test test/a11y/runtime           # about 55 s on Flutter 3.47.9
```

Outputs, both git-ignored and rewritten on every run:

- `.a11y/flutter/runtime-findings.json`: the findings, in the format
  `a11y_check_flutter scan` reads.
- `.a11y/flutter/runtime-screens.json`: one entry per screen id with its
  viewport, the view size it was audited at, how far its lists could still
  scroll, the app route, the finding count per rule, audit diagnostics, the
  exceptions caught while the screen was pumped, which reflow passes were
  aborted and why, and the requests the app made to the fake server.
  Two more keys list the plugin calls that were answered with `null` and the
  exceptions reported while an app was being closed.

Delete both files before a run whose numbers you will quote: screens that no
longer exist stay in them otherwise.

Options, as environment variables:

- `A11Y_SCREENSHOT_DIR=/some/dir` also writes a PNG of each screen as it was
  audited. Use it to check by eye that a screen is the one its id says.
- `A11Y_TEST_FONT=ahem` skips loading real fonts, to compare with the default
  test font.

Two consecutive runs on one machine produced byte-identical output files:
13,406 findings on 482 audited screen ids (2 more ids were not reached).

`flutter test test/a11y` also runs the older `test/a11y/screens_a11y_test.dart`
one directory up. Its 13 tests fail (see "The older harness"), so that command
exits 1; the tests in this directory all pass.

## Why this branch changes `pubspec.yaml`

The app pins Flutter 3.41.9 and `flutter_a11y_test` needs Flutter 3.47. On
3.47.9 the app did not compile, because of two dependencies. `pubspec.yaml`
now overrides them with patched copies in `.flutter_3_47_compat/`; that
directory's README has the errors and the two patches.
`pubspec.lock` changes only for those two packages. No file under `lib/` and
no existing test was changed.

Running on 3.47 instead of 3.41 has one visible cost. Flutter 3.47 added a
debug assertion to `DropdownButton` ("The selectedItemBuilder must return a
list of widgets with the same length as the items list"), and the company
switcher at the top of the expanded side menu
(`lib/ui/app/menu_drawer.dart:291`) trips it. In a debug build, which is what
`flutter test` is, the switcher is replaced by Flutter's red error box. See
"The side menu on the desktop viewport" for what was done about it.

## The older harness

`test/a11y/screens_a11y_test.dart` and `test/flutter_test_config.dart` were
written on 2026-11-08 and are unchanged. That test never ran: it did not
compile on Flutter 3.47, which is why the app contributed no runtime findings
to the 2026-11-09 label sample. With the two packages patched it compiles, and
all 13 of its tests fail:

- `login` throws `MissingPluginException(No implementation found for method
  getAll on channel plugins.flutter.io/shared_preferences)`, and
  `lib/ui/app/forms/app_toggle_buttons.dart:52` builds a `Container` with a
  negative width at the 320 px reflow pass.
- The other 12 (dashboard, clients, invoices, products, payments, quotes,
  expenses, vendors, tasks, projects, settings, reports) fail on `A RenderFlex
  overflowed by 24 pixels on the right` in `lib/ui/app/menu_drawer.dart:1106`,
  an effect of the square test font.

Each of the 12 does record findings before it fails (8 to 24 a screen), but
they are not worth labelling: every screen is pumped over an empty company,
inside a plain `MaterialApp` with Flutter's default Material 3 theme instead
of the app's own theme, in the test font, with shadows drawn as black
outlines. Its screen ids (`login`, `dashboard`, `clients`, ...) have no
viewport prefix, so they can be told apart from the ids of this directory.

## How a screen is pumped

Each test:

1. builds the store `lib/main.dart` builds: the real `appReducer` and every
   real middleware in the same order, with each repository given a fake
   `WebClient` (`FakeServer` in `support/harness.dart`);
2. pumps the real `InvoiceNinjaApp`, so the theme, localizations, navigator,
   routes and observers are the app's. It shows its splash screen, finds no
   saved session and lands on the login screen;
3. signs in as a user does: taps Self-Hosted, types the e-mail, password and
   URL, taps "Login with email". The fake server answers `POST /login` with a
   full account, the app's own code deserializes it and fills the state;
4. walks to screens and calls `auditScreen` on each;
5. takes the app down.

No screen is a stub and no state is written into the store by the tests.

Inside a screen (tabs of the login form, menus, dialogs, the search field,
filter and sort sheets, multiselect) the tests tap and type. To move between
modules and records they call the functions the app's own `onTap` handlers
call (`viewEntitiesByType`, `viewEntity`, `editEntity`, `createEntityByType`,
and the `ViewSettings`, `ViewReports` and `ViewDashboard` actions), so the
app's middleware does the navigation. The other tabs of a tab bar are selected
through the bar's own controller, because a tab scrolled out of a scrolling
bar cannot be tapped.

## The data

`support/fixture.dart` builds the account with the app's own model factories
and builders: Northwind Studio LLC with 12 clients (three currencies), 18
invoices (draft, sent, partial, paid, past due, cancelled), 7 quotes, 4
credits, 3 purchase orders, 4 recurring invoices, 9 payments (one partly
refunded, one unapplied), 14 products, 6 vendors, 10 expenses in 6 categories,
2 recurring expenses, 5 projects, 9 tasks in 3 statuses, 2 users, 3 tax rates,
4 payment terms, 5 designs, a client group, a Stripe gateway and 8 activity
records. The "empty" screens use the same company with no records.

Dates are relative to the day the test runs, so the dashboard's "last 30 days"
has data and a past-due invoice stays past due. Texts that contain a date
therefore change from day to day; two runs on the same day are identical.

The app has test data of its own, `lib/data/mock/mock_login.dart`, used when
`Config.DEMO_MODE` is on. It could not be used as the account: the string is
not valid JSON (a stray `h` before `"invoice_design_id"`), and after removing
that it no longer deserializes (`Tried to construct class "ClientEntity" with
null for non-nullable field "clientHash"`); it also holds one client and one
invoice. Its `static` section is used: 249 countries, 79 currencies, 28
languages, 33 industries, 6 sizes, 31 payment types, 14 date formats and 113
timezones, each record laid over the model's defaults because the mock leaves
some required fields null.

## What is faked

- **The server.** `FakeServer` answers `POST /login` and `/refresh` with the
  account, `GET /<records>/<id>` with the record, any other `GET` of a
  collection with an empty list, and leaves everything else pending (PDF
  previews, saves, e-mail), which shows the app's own "loading" state. A
  refused login is the string `WebClient` throws for a 401. The log lists the
  requests made on the way to each screen.
- **Requests that do not go through a repository.** A few widgets call
  `WebClient()` directly, for example the invoice PDF preview (`POST
  /live_preview`). Those reach `flutter_test`'s built-in HTTP client, which
  answers 400 without touching the network. So the PDF tab shows the app's
  empty preview area.
- **Saved state.** The persistence middleware is the real one; its files go to
  a temporary directory that is deleted afterwards.
- **Plugins.** `SharedPreferences` uses its own in-memory test double, with
  `beta_promo_done` set (a user who has dismissed the desktop-beta
  invitation, which the web build never shows). Every other plugin channel is
  answered with `null`, and the window manager's `isFocused` and similar with
  plausible values; the calls are listed in the log
  (`_pluginCallsAnsweredWithNull`).

## Harness decisions that affect findings

- **Two viewports, two id prefixes.** `desktop/...` is 1280x800 at DPR 1 with
  `defaultTargetPlatform` macOS (pointer input, compact visual density), and
  the app's desktop layout. `phone/...` is 412x915 at DPR 3 with
  `defaultTargetPlatform` Android, and the app's mobile layout. The app picks
  its layout once, at sign-in, from the window width, and stores it as a
  preference; it does not switch when the window is resized. So the audit's
  320 px reflow pass lays the desktop layout out at 320 px on `desktop/`
  screens, which is what a desktop user who zooms to 400 % gets.
- **Host platform.** The tests run on the machine's own OS, so `Platform` in
  the app says macOS (or Linux in CI) in both viewports: the app wraps itself
  in its desktop window manager, and features it reserves for iOS and Android
  (for example biometric lock) are not offered on `phone/` screens.
- **Audit config.** Library defaults with `platform: TargetPlatform.macOS` on
  `desktop/` (the 48 and 44 px touch guidelines are skipped; the 24 px minimum
  of WCAG 2.5.8 still runs) and `platform: null` on `phone/` (both touch
  guidelines run, so one small control is reported twice). `sourceRoots` is
  the app's `lib/`, so nothing is attributed to the harness or to vendored
  code.
- **Real fonts.** Roboto and MaterialIcons from the Flutter SDK and the
  Material Design Icons font are loaded, and Roboto is also registered under
  the macOS system font names, because the web build sets `fontFamily:
  'Roboto'` and a VM run does not. **Known gap:** text whose style names no
  font family still renders in the test font, as solid boxes one em wide. That
  is the app bar title and the state-filter dropdowns in the app bar
  (`appBarTheme.titleTextStyle` in `lib/main_app.dart` names no family). An
  overflow or contrast finding on that text deserves a second look.
- **Shadows.** `debugDisableShadows` is turned off while a screen is pumped;
  `flutter_test` otherwise paints every shadow as a solid black outline around
  each card and dialog.
- **Growing the view.** Before an audit the view is made as tall as its
  scrollable content (up to 6000 px), so a long form or list is audited whole;
  the size is in the log. Menus, dialogs, sheets and drawers are audited at
  the viewport size instead.
- **Debug banner** off.
- **Debug-build login screen.** Outside release mode the login form is
  prefilled from `lib/.env.dart` (`demo@invoiceninja.com`) and offers the
  Google, Microsoft and Apple methods on any platform.

### The side menu on the desktop viewport

`flutter_a11y_test` 0.3.0 and 0.4.0 rethrew any error other than an overflow
that a screen reported while it was re-laid out at 200 % text or at 320 px,
and then recorded nothing for that screen. 0.4.1 aborts only the pass that
raised it, runs the others, records the screen's findings and throws
`A11yReflowException`. With the side menu expanded, the company switcher
reports its assertion on every rebuild, so every desktop screen would lose its
text-scale pass.

What the harness does:

- Desktop screens are audited with the **side menu collapsed** to its icon
  rail (one tap on the chevron at its foot; a setting the app remembers). The
  collapsed menu has no dropdown, and the full battery runs.
- Five screens are audited with the menu expanded, under
  `desktop/menu-expanded/...`; their text-scale pass aborts on the
  assertion.
- Generally: when `auditScreen` throws `A11yReflowException`, the exception's
  `result` is the screen's result (the completed passes' findings, and a
  `reflow-pass-aborted` diagnostic), and the aborted passes are written to the
  log as `reflowPassesAborted`, one `<pass>: <error>` per pass, separated by
  `; ` (the pass is `width 320 px`, `text scale 2.0x` or `restoring after
  text scale 2.0x`). This happened on 51 screens (see "Exceptions"). Any other
  error from `auditScreen` keeps the fallback the harness had at 0.3.0 and
  0.4.0: the screen is audited again with `reflow: false`, and the error is
  logged under the same key without a pass name. In this run no screen took
  that fallback.

Consequences for labelling: `desktop/` screens have about 150 px more content
width than a user with the default menu sees, and the icon rail's findings
(`lib/ui/app/menu_drawer.dart:962`) repeat on every desktop screen: 3,700 of
the 13,406 findings are that one line.

## Screens audited

482 screen ids audited, 237 on desktop and 245 on the phone. The full list
with sizes is `.a11y/flutter/runtime-screens.json`. `<m>` below is each of
`client`, `invoice`, `recurring_invoice`, `quote`, `credit`, `payment`,
`product`, `project`, `task`, `vendor`, `purchase_order`, `expense`,
`recurring_expense`.

| Ids (under `desktop/` and `phone/`) | What |
|---|---|
| `login/hosted`, `login/hosted-google`, `login/hosted-sign-up`, `login/recover-password`, `login/self-hosted`, `login/self-hosted-refused` | The login form: e-mail, password and the one-time password (2FA) field; Google method; sign-up with the two consent checkboxes; password recovery; self-hosted with URL and secret; a refused login with its error text |
| `dashboard`, `dashboard/tab-*` | Dashboard with totals, charts and the upcoming and past-due lists; Activity and System Logs; each tab of the right-hand panel |
| `dashboard/settings-dialog` (desktop) | The dashboard's settings dialog |
| `menu-expanded/dashboard`, `menu-expanded/client/list`, `menu-expanded/invoice/edit`, `menu-expanded/contact-us-dialog`, `menu-expanded/about-dialog` (desktop) | The expanded side menu, and its Contact us and About dialogs |
| `menu/drawer` (phone) | The navigation drawer |
| `history-sidebar` (desktop) | The history sidebar after some records were opened |
| `reports` | Reports, client report |
| `<m>/list` | Each module's list with data (a table on desktop, cards on the phone) |
| `<m>/view`, `<m>/view/tab-*` | A record and each of its tabs (overview, details, contacts, documents, ledger, activity, history, schedule, system logs, as the module has them). On desktop the record opens beside the list |
| `<m>/edit`, `<m>/edit/tab-*` | The record's form and each of its tabs |
| `<m>/new` | A blank form |
| `invoice/edit` and tabs | Desktop: the one-page editor (client and contacts, details, items table, totals, PDF placeholder) with its Terms, Footer, Public Notes, Private Notes, Settings and Documents tabs. Phone: the Details, Contacts, Items, Notes and PDF tabs. The same for quotes, credits, recurring invoices and purchase orders |
| `invoice/edit/date-picker`, `invoice/edit/more-menu`, `invoice/edit/discard-changes-dialog`, `invoice/edit/add-item-dialog` (phone), `invoice/view/actions-menu` | Dialogs and menus of the invoice form and record |
| `client/list/search`, `client/list/multiselect`, `client/list/state-filter-menu` (desktop), `client/list/row-menu` (desktop), `client/list/columns-dialog` (desktop), `client/list/card-layout` (desktop), `client/list/filter-sheet` (phone), `client/list/sort-sheet` (phone), `client/list/multiselect-actions-menu` (phone), `client/list/table-layout` (phone) | Searching, filtering, sorting, choosing columns, selecting several rows, a row's menu, and the other list layout |
| `empty/dashboard`, `empty/<m>/list` | A new account: the dashboard and each module's empty list |
| `settings/home` and 25 pages with their tabs | company-details, user-details, localization, payment-settings, tax-settings, product-settings, task-settings, expense-settings, workflow-settings, import-export, account-management, device-settings, invoice-design, generated-numbers, custom-fields, client-portal, email-settings, templates-and-reminders, group-settings, user-management, payment-terms, tax-settings-rates, company-gateways, expense-category, task-status |

## Not audited

Recorded as not reached (2 ids):

- `settings/templates-and-reminders/tab-preview`, both viewports: selecting
  the Preview tab replaces the page's tab bar ("the tab bar is gone"), and the
  preview is a server-rendered template the fake server leaves pending.

Not attempted:

- **Dark theme and languages other than English.** Out of scope for this run.
- **Documents, transactions, bank accounts, transaction rules, subscriptions
  (payment links), schedules, tokens, webhooks, custom designs, e-invoice
  settings.** Secondary modules; the fixture has no records for them.
- **Settings sub-forms**: editing a single tax rate, payment term, expense
  category, task status, user, group or gateway. Only their lists are
  audited.
- **PDF viewer and e-mail composer** (`/invoice/pdf`, `/invoice/email`): both
  show server-rendered content; the fake server leaves it pending, so they
  would be audited as spinners.
- **Kanban board for tasks, the refund form, the payment "apply" form, the
  statement screen, the upgrade and beta-promo dialogs, the lock screen.**
- **OAuth sign-in flows** and anything that leaves the app (client portal).
- **Entity pickers opened from a form** (client, product, vendor selectors)
  other than the phone's add-item dialog.
- **Report types other than the default client report**, and report export.
- **A real browser.** Web-only code paths (`kIsWeb`) are not taken: the web
  session timeout, the browser-route handling, the web font setting.

## Exceptions

Nothing fails a test; what the framework or the app reports is recorded on the
screen it happened on. 17 audited screens carry exceptions, and on 51 one
reflow pass was aborted (at 0.3.0 and 0.4.0 both passes were dropped on those
51; at 0.4.1 the pass that did not raise the error runs, which added one
finding: `text-overflow-at-scale` at
`lib/ui/app/autobill_dropdown_menu_item.dart:14` on
`desktop/settings/payment-settings`).

| Count | Where | What |
|---|---|---|
| 39 screens, 320 px pass aborted | desktop: every `*/view/tab-documents`, `edit/tab-settings` of the invoice-like forms, and 23 settings pages and tabs | `Trailing widget consumes the entire tile width (including ListTile.contentPadding)` when laid out at 320 px. A real reflow failure; 0.4.1 still runs the text-scale pass |
| 1 screen, 320 px pass aborted | `desktop/client/view/tab-ledger` | `Leading widget consumes the entire tile width` at 320 px |
| 5 screens, text-scale pass aborted | `desktop/expense/new`, `desktop/payment/new`, `desktop/recurring_expense/new`, `desktop/task/new`, `desktop/history-sidebar` | `ListTile background color or ink splashes may be invisible. The ListTile is wrapped in a ColoredBox...`, a Flutter 3.47 debug check |
| 6 screens, text-scale pass aborted | the 5 `desktop/menu-expanded/*` and `phone/menu/drawer` | The company switcher's `DropdownButton` assertion described above |
| 3 screens, audited in full | `phone/client/list/filter-sheet`, `phone/client/list/sort-sheet`, `phone/client/list/multiselect` | The same `ListTile ... ColoredBox` debug check, reported at the normal layout |
| 1 screen, audited in full | `phone/reports` | The company switcher's assertion, reported while the drawer audited just before it was closing |
| 2 screens | `login/self-hosted-refused` | The refused login, which the app rethrows by design |

The app's own code also threw on data that was merely incomplete while the
fixture was being written (`settings.translations!`,
`user.userCompany!.settings`, `expense.invoiceId!`,
`settings.showTaskItemDescription!`): the server always sends those fields,
and the fixture now does too.

One effect between tests was found and worked around: a test that opened
Templates & Reminders after an earlier test in the same file had opened it got
`Duplicate GlobalKey detected ... _templatesAndReminders` (the page's form key
is a static). The settings tests are therefore one file per viewport, with
that page last.
