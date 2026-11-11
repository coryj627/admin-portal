/// The account the fake server returns at login: one company with a
/// realistic set of clients, invoices in every status, quotes, credits,
/// payments, products, expenses, tasks, vendors, projects, recurring
/// invoices and purchase orders.
///
/// Everything is built with the app's own model factories and builders, so
/// each entity is valid for the current models.  The static lists
/// (countries, currencies, languages, industries, sizes, payment types, date
/// formats, timezones) are the ones in the app's own
/// `lib/data/mock/mock_login.dart`; the rest of that file is not usable (see
/// the README).
///
/// Dates are relative to the day the test runs, so that "last 30 days" on
/// the dashboard has data and an overdue invoice stays overdue.
library;

import 'dart:convert';

import 'package:built_collection/built_collection.dart';
import 'package:built_value/serializer.dart';
import 'package:invoiceninja_flutter/constants.dart';
import 'package:invoiceninja_flutter/data/mock/mock_login.dart';
import 'package:invoiceninja_flutter/data/models/account_model.dart';
import 'package:invoiceninja_flutter/data/models/company_gateway_model.dart';
import 'package:invoiceninja_flutter/data/models/group_model.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/data/models/payment_term_model.dart';
import 'package:invoiceninja_flutter/data/models/serializers.dart';

const String kCompanyId = 'cmp_northwind';
const String kUserId = 'usr_ada';
const String kUser2Id = 'usr_grace';
const String kFixtureToken =
    'a11yFixtureTokenA11yFixtureTokenA11yFixtureTokenA11yFixtureToken';
const String kFixtureEmail = 'ada@northwind.example';
const String kFixtureUrl = 'https://ninja.northwind.example';

final DateTime _today = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

/// `yyyy-MM-dd` for [daysAgo] days before today (negative: in the future).
String day(int daysAgo) {
  final d = _today.subtract(Duration(days: daysAgo));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Seconds since the epoch, [daysAgo] days before today.
int ts(int daysAgo, [int hour = 10]) =>
    DateTime(
      _today.year,
      _today.month,
      _today.day,
      hour,
    ).subtract(Duration(days: daysAgo)).millisecondsSinceEpoch ~/
    1000;

double _round(double v) => (v * 100).round() / 100;

// ---------------------------------------------------------------------------
// Static data
// ---------------------------------------------------------------------------

/// The `static` section of the app's mock login, deserialized list by list
/// (the file as a whole no longer matches the models).
StaticDataEntity buildStatic() {
  // The mock has one stray character that makes it invalid JSON.
  final decoded =
      json.decode(
            (kMockLogin as String).replaceFirst(
              'h"invoice_design_id"',
              '"invoice_design_id"',
            ),
          )
          as Map<String, dynamic>;
  final source = decoded['static'] as Map<String, dynamic>;

  // Each record of the mock laid over the model's own defaults, so a field
  // the mock leaves null or does not have yet takes the default.
  List<dynamic> over<T>(Serializer<T> serializer, T blank, String key) {
    final defaults =
        serializers.serializeWith(serializer, blank) as Map<String, dynamic>;
    return [
      for (final record in source[key] as List<dynamic>)
        <String, dynamic>{
          ...defaults,
          for (final entry in (record as Map<String, dynamic>).entries)
            if (entry.value != null) entry.key: entry.value,
        },
    ];
  }

  final merged =
      serializers.serializeWith(StaticDataEntity.serializer, StaticDataEntity())
          as Map<String, dynamic>;
  merged['currencies'] = over(
    CurrencyEntity.serializer,
    CurrencyEntity(),
    'currencies',
  );
  merged['countries'] = over(
    CountryEntity.serializer,
    CountryEntity(),
    'countries',
  );
  merged['sizes'] = over(SizeEntity.serializer, SizeEntity(), 'sizes');
  merged['industries'] = over(
    IndustryEntity.serializer,
    IndustryEntity(),
    'industries',
  );
  merged['timezones'] = over(
    TimezoneEntity.serializer,
    TimezoneEntity(),
    'timezones',
  );
  merged['date_formats'] = over(
    DateFormatEntity.serializer,
    DateFormatEntity(),
    'date_formats',
  );
  merged['languages'] = over(
    LanguageEntity.serializer,
    LanguageEntity(),
    'languages',
  );
  merged['payment_types'] = over(
    PaymentTypeEntity.serializer,
    PaymentTypeEntity(),
    'payment_types',
  );
  final data = serializers.deserializeWith(
    StaticDataEntity.serializer,
    merged,
  )!;
  return data.rebuild(
    (b) => b
      ..gateways.replace([
        GatewayEntity().rebuild(
          (g) => g
            ..id = kGatewayStripe
            ..name = 'Stripe'
            ..isOffsite = false
            ..isVisible = true
            ..sortOrder = 1
            ..siteUrl = 'https://stripe.com'
            ..fields =
                '{"publishableKey":"","apiKey":"","appleDomainVerification":""}',
        ),
      ]),
  );
}

// ---------------------------------------------------------------------------
// Company
// ---------------------------------------------------------------------------

class _Client {
  const _Client(
    this.id,
    this.name,
    this.first,
    this.last,
    this.email,
    this.city,
    this.state,
    this.country,
    this.balance,
    this.paid,
  );
  final String id, name, first, last, email, city, state, country;
  final double balance, paid;
}

const _clients = <_Client>[
  _Client(
    'cli_01',
    'Acme Hardware Supply',
    'Maria',
    'Gonzalez',
    'maria@acmehardware.example',
    'Portland',
    'Oregon',
    '840',
    2480.50,
    12340,
  ),
  _Client(
    'cli_02',
    'Blue Harbor Dental',
    'James',
    'Okafor',
    'james@blueharbor.example',
    'Seattle',
    'Washington',
    '840',
    0,
    8650,
  ),
  _Client(
    'cli_03',
    'Cedar & Pine Architects',
    'Hannah',
    'Lindqvist',
    'hannah@cedarpine.example',
    'Minneapolis',
    'Minnesota',
    '840',
    5400,
    21900,
  ),
  _Client(
    'cli_04',
    'Dunmore Logistics Ltd',
    'Oliver',
    'Bennett',
    'oliver@dunmore.example',
    'Manchester',
    '',
    '826',
    1210.75,
    4300,
  ),
  _Client(
    'cli_05',
    'Evergreen Community Clinic',
    'Priya',
    'Raman',
    'priya@evergreenclinic.example',
    'Austin',
    'Texas',
    '840',
    0,
    1560,
  ),
  _Client(
    'cli_06',
    'Foxglove Bakery',
    'Lucas',
    'Moreau',
    'lucas@foxglove.example',
    'Montreal',
    'Quebec',
    '124',
    318,
    2975.25,
  ),
  _Client(
    'cli_07',
    'Granite Peak Outfitters',
    'Sofia',
    'Marino',
    'sofia@granitepeak.example',
    'Denver',
    'Colorado',
    '840',
    7625,
    15800,
  ),
  _Client(
    'cli_08',
    'Harbourview Law Group',
    'Daniel',
    'Schwartz',
    'daniel@harbourview.example',
    'Boston',
    'Massachusetts',
    '840',
    0,
    30210,
  ),
  _Client(
    'cli_09',
    'Ironbridge Fabrication',
    'Aiko',
    'Tanaka',
    'aiko@ironbridge.example',
    'Cleveland',
    'Ohio',
    '840',
    940,
    6120,
  ),
  _Client(
    'cli_10',
    'Juniper Street Books',
    'Fatima',
    'Haddad',
    'fatima@juniperbooks.example',
    'Chicago',
    'Illinois',
    '840',
    0,
    0,
  ),
  _Client(
    'cli_11',
    'Kestrel Aviation Services',
    'Tomás',
    'Herrera',
    'tomas@kestrelaviation.example',
    'Phoenix',
    'Arizona',
    '840',
    13250,
    48700,
  ),
  _Client(
    'cli_12',
    'Lakeside Veterinary Hospital',
    'Emily',
    'Carter',
    'emily@lakesidevet.example',
    'Madison',
    'Wisconsin',
    '840',
    425,
    3890,
  ),
];

class _Product {
  const _Product(
    this.id,
    this.key,
    this.notes,
    this.price,
    this.cost,
    this.qty,
  );
  final String id, key, notes;
  final double price, cost;
  final int qty;
}

const _products = <_Product>[
  _Product(
    'prd_01',
    'Website design',
    'Custom responsive website, up to 8 pages',
    4200,
    1800,
    0,
  ),
  _Product(
    'prd_02',
    'Logo package',
    'Three concepts, two revision rounds, final files',
    950,
    300,
    0,
  ),
  _Product(
    'prd_03',
    'Monthly maintenance',
    'Updates, backups and uptime monitoring',
    180,
    40,
    0,
  ),
  _Product(
    'prd_04',
    'Hosting (annual)',
    'Managed hosting with daily backups',
    360,
    120,
    0,
  ),
  _Product(
    'prd_05',
    'SEO audit',
    'Technical and content audit with action plan',
    1200,
    400,
    0,
  ),
  _Product(
    'prd_06',
    'Copywriting (per page)',
    'Researched and edited web copy',
    140,
    60,
    0,
  ),
  _Product(
    'prd_07',
    'Photography half-day',
    'On-site shoot, 40 edited images',
    780,
    250,
    0,
  ),
  _Product(
    'prd_08',
    'Consulting hour',
    'Strategy and technical consulting',
    165,
    0,
    0,
  ),
  _Product(
    'prd_09',
    'Accessibility review',
    'WCAG 2.2 AA review with remediation list',
    2400,
    900,
    0,
  ),
  _Product(
    'prd_10',
    'Email template set',
    'Five responsive transactional templates',
    640,
    200,
    0,
  ),
  _Product(
    'prd_11',
    'Printed brochures (500)',
    'Tri-fold, full colour, 150 gsm',
    420,
    260,
    35,
  ),
  _Product(
    'prd_12',
    'Business cards (250)',
    'Double-sided, matte laminate',
    95,
    48,
    120,
  ),
  _Product(
    'prd_13',
    'Domain registration',
    'One year, .com or .org',
    18,
    11,
    0,
  ),
  _Product(
    'prd_14',
    'Training workshop',
    'Half-day content management training',
    850,
    150,
    0,
  ),
];

class _Line {
  const _Line(this.product, this.qty);
  final int product;
  final double qty;
}

class _Invoice {
  const _Invoice(
    this.id,
    this.number,
    this.client,
    this.status,
    this.daysAgo,
    this.dueIn,
    this.lines, {
    this.paidFraction = 0,
    this.tax = 0,
    this.po = '',
    this.notes = '',
  });
  final String id, number, status, po, notes;
  final int client, daysAgo, dueIn;
  final List<_Line> lines;
  final double paidFraction, tax;
}

const _invoices = <_Invoice>[
  _Invoice(
    'inv_01',
    '0001',
    0,
    kInvoiceStatusPaid,
    86,
    30,
    [_Line(0, 1), _Line(3, 1)],
    paidFraction: 1,
    tax: 8.5,
  ),
  _Invoice('inv_02', '0002', 1, kInvoiceStatusPaid, 74, 30, [
    _Line(1, 1),
    _Line(11, 4),
  ], paidFraction: 1),
  _Invoice(
    'inv_03',
    '0003',
    2,
    kInvoiceStatusPaid,
    61,
    15,
    [_Line(8, 1), _Line(7, 6)],
    paidFraction: 1,
    tax: 7,
  ),
  _Invoice('inv_04', '0004', 3, kInvoiceStatusSent, 52, 30, [
    _Line(2, 6),
    _Line(12, 2),
  ], po: 'PO-7741'),
  _Invoice(
    'inv_05',
    '0005',
    6,
    kInvoiceStatusPartial,
    44,
    30,
    [_Line(0, 1), _Line(5, 12), _Line(6, 1)],
    paidFraction: 0.4,
    tax: 8.5,
  ),
  _Invoice('inv_06', '0006', 7, kInvoiceStatusPaid, 40, 30, [
    _Line(4, 1),
    _Line(7, 10),
  ], paidFraction: 1),
  _Invoice(
    'inv_07',
    '0007',
    10,
    kInvoiceStatusSent,
    33,
    30,
    [_Line(8, 2), _Line(13, 3), _Line(7, 20)],
    tax: 5,
    po: 'KAS-2291',
    notes: 'Second phase of the booking system review.',
  ),
  _Invoice('inv_08', '0008', 0, kInvoiceStatusSent, 28, 14, [
    _Line(2, 3),
    _Line(9, 1),
  ], tax: 8.5),
  _Invoice('inv_09', '0009', 5, kInvoiceStatusSent, 21, 30, [
    _Line(10, 1),
    _Line(11, 2),
  ]),
  _Invoice('inv_10', '0010', 8, kInvoiceStatusPartial, 19, 30, [
    _Line(6, 2),
    _Line(5, 4),
  ], paidFraction: 0.5),
  _Invoice('inv_11', '0011', 2, kInvoiceStatusSent, 14, 30, [
    _Line(0, 1),
    _Line(4, 1),
  ], tax: 7),
  _Invoice('inv_12', '0012', 11, kInvoiceStatusSent, 12, 30, [
    _Line(2, 2),
    _Line(12, 1),
    _Line(11, 1),
  ]),
  _Invoice('inv_13', '0013', 4, kInvoiceStatusPaid, 10, 30, [
    _Line(13, 1),
    _Line(7, 4),
  ], paidFraction: 1),
  _Invoice('inv_14', '0014', 10, kInvoiceStatusSent, 8, 30, [
    _Line(0, 1),
    _Line(8, 1),
    _Line(3, 1),
  ], tax: 5),
  _Invoice('inv_15', '0015', 1, kInvoiceStatusPaid, 6, 30, [
    _Line(2, 12),
  ], paidFraction: 1),
  _Invoice('inv_16', '0016', 6, kInvoiceStatusDraft, 3, 30, [
    _Line(9, 2),
    _Line(5, 8),
  ], tax: 8.5),
  _Invoice('inv_17', '0017', 9, kInvoiceStatusDraft, 1, 30, [_Line(1, 1)]),
  _Invoice('inv_18', '0018', 3, kInvoiceStatusCancelled, 48, 30, [_Line(6, 1)]),
];

const _quotes = <_Invoice>[
  _Invoice('quo_01', 'Q-0001', 9, kQuoteStatusSent, 9, 21, [
    _Line(0, 1),
    _Line(1, 1),
    _Line(5, 10),
  ], tax: 6.25),
  _Invoice('quo_02', 'Q-0002', 4, kQuoteStatusApproved, 16, 30, [_Line(8, 1)]),
  _Invoice('quo_03', 'Q-0003', 10, kQuoteStatusConverted, 40, 30, [
    _Line(0, 1),
    _Line(8, 1),
    _Line(3, 1),
  ], tax: 5),
  _Invoice('quo_04', 'Q-0004', 7, kQuoteStatusDraft, 2, 30, [
    _Line(13, 2),
    _Line(7, 8),
  ]),
  _Invoice('quo_05', 'Q-0005', 11, kQuoteStatusSent, 45, 14, [
    _Line(4, 1),
    _Line(2, 12),
  ]),
  _Invoice('quo_06', 'Q-0006', 2, kQuoteStatusSent, 5, 30, [
    _Line(6, 2),
    _Line(9, 1),
  ], tax: 7),
  _Invoice('quo_07', 'Q-0007', 5, kQuoteStatusDraft, 0, 30, [_Line(10, 2)]),
];

const _credits = <_Invoice>[
  _Invoice('crd_01', 'C-0001', 0, kCreditStatusSent, 25, 0, [_Line(11, 1)]),
  _Invoice('crd_02', 'C-0002', 6, kCreditStatusPartial, 30, 0, [
    _Line(7, 3),
  ], paidFraction: 0.5),
  _Invoice('crd_03', 'C-0003', 7, kCreditStatusApplied, 37, 0, [
    _Line(5, 2),
  ], paidFraction: 1),
  _Invoice('crd_04', 'C-0004', 2, kCreditStatusDraft, 4, 0, [_Line(12, 3)]),
];

const _purchaseOrders = <_Invoice>[
  _Invoice('po_01', 'PO-0001', 0, kPurchaseOrderStatusSent, 18, 30, [
    _Line(10, 4),
  ]),
  _Invoice('po_02', 'PO-0002', 2, kPurchaseOrderStatusAccepted, 27, 30, [
    _Line(11, 10),
  ]),
  _Invoice('po_03', 'PO-0003', 1, kPurchaseOrderStatusDraft, 2, 30, [
    _Line(3, 1),
    _Line(12, 5),
  ]),
];

class _Vendor {
  const _Vendor(
    this.id,
    this.name,
    this.first,
    this.last,
    this.email,
    this.city,
    this.state,
  );
  final String id, name, first, last, email, city, state;
}

const _vendors = <_Vendor>[
  _Vendor(
    'ven_01',
    'Brightline Print Co.',
    'Rosa',
    'Delgado',
    'rosa@brightline.example',
    'Portland',
    'Oregon',
  ),
  _Vendor(
    'ven_02',
    'Cloudreach Hosting',
    'Noah',
    'Fischer',
    'billing@cloudreach.example',
    'Dublin',
    '',
  ),
  _Vendor(
    'ven_03',
    'Meridian Office Supply',
    'Chloe',
    'Nguyen',
    'chloe@meridianoffice.example',
    'Seattle',
    'Washington',
  ),
  _Vendor(
    'ven_04',
    'Parkside Co-working',
    'Ethan',
    'Brooks',
    'ethan@parkside.example',
    'Portland',
    'Oregon',
  ),
  _Vendor(
    'ven_05',
    'Quill Freelance Collective',
    'Ingrid',
    'Solberg',
    'ingrid@quillcollective.example',
    'Oslo',
    '',
  ),
  _Vendor(
    'ven_06',
    'Summit Insurance Brokers',
    'Marcus',
    'Reid',
    'marcus@summitbrokers.example',
    'Denver',
    'Colorado',
  ),
];

class _Expense {
  const _Expense(
    this.id,
    this.number,
    this.vendor,
    this.category,
    this.amount,
    this.daysAgo,
    this.notes, {
    this.client = -1,
    this.paid = true,
    this.billable = false,
  });
  final String id, number, notes;
  final int vendor, category, daysAgo, client;
  final double amount;
  final bool paid, billable;
}

const _expenses = <_Expense>[
  _Expense(
    'exp_01',
    '0001',
    1,
    0,
    360,
    58,
    'Annual hosting plan, client sites',
  ),
  _Expense(
    'exp_02',
    '0002',
    0,
    1,
    512.40,
    47,
    'Brochure print run for Granite Peak',
    client: 6,
    billable: true,
  ),
  _Expense('exp_03', '0003', 3, 2, 450, 31, 'Co-working desk, monthly'),
  _Expense('exp_04', '0004', 2, 3, 86.15, 26, 'Printer paper and toner'),
  _Expense(
    'exp_05',
    '0005',
    4,
    4,
    1250,
    22,
    'Copywriting subcontract, Kestrel site',
    client: 10,
    billable: true,
    paid: false,
  ),
  _Expense('exp_06', '0006', 5, 5, 298, 17, 'Professional liability premium'),
  _Expense('exp_07', '0007', 1, 0, 24.99, 11, 'Domain renewals'),
  _Expense(
    'exp_08',
    '0008',
    3,
    2,
    450,
    1,
    'Co-working desk, monthly',
    paid: false,
  ),
  _Expense(
    'exp_09',
    '0009',
    0,
    1,
    118,
    7,
    'Business cards, Acme Hardware',
    client: 0,
    billable: true,
  ),
  _Expense('exp_10', '0010', 2, 3, 42.5, 4, 'Whiteboard markers and notebooks'),
];

const _expenseCategories = <List<String>>[
  ['cat_01', 'Hosting & domains', '#0277BD'],
  ['cat_02', 'Printing', '#AD1457'],
  ['cat_03', 'Rent', '#2E7D32'],
  ['cat_04', 'Office supplies', '#EF6C00'],
  ['cat_05', 'Subcontractors', '#6A1B9A'],
  ['cat_06', 'Insurance', '#455A64'],
];

class _Project {
  const _Project(
    this.id,
    this.number,
    this.name,
    this.client,
    this.hours,
    this.rate,
    this.dueIn,
  );
  final String id, number, name;
  final int client, dueIn;
  final double hours, rate;
}

const _projects = <_Project>[
  _Project('prj_01', '0001', 'Acme online catalogue', 0, 120, 140, 45),
  _Project('prj_02', '0002', 'Cedar & Pine portfolio refresh', 2, 60, 150, 20),
  _Project('prj_03', '0003', 'Granite Peak store redesign', 6, 200, 135, 75),
  _Project('prj_04', '0004', 'Kestrel booking system review', 10, 80, 165, 30),
  _Project('prj_05', '0005', 'Lakeside appointment reminders', 11, 40, 140, 10),
];

class _Task {
  const _Task(
    this.id,
    this.number,
    this.description,
    this.client,
    this.project,
    this.status,
    this.daysAgo,
    this.minutes, {
    this.invoiced = false,
  });
  final String id, number, description;
  final int client, project, status, daysAgo;
  final List<int> minutes;
  final bool invoiced;
}

const _tasks = <_Task>[
  _Task(
    'tsk_01',
    '0001',
    'Wireframes for catalogue landing page',
    0,
    0,
    2,
    12,
    [150, 95],
  ),
  _Task('tsk_02', '0002', 'Product data import script', 0, 0, 1, 9, [210]),
  _Task('tsk_03', '0003', 'Portfolio photo selection with client', 2, 1, 2, 8, [
    60,
    45,
  ], invoiced: true),
  _Task('tsk_04', '0004', 'Store navigation prototype', 6, 2, 1, 6, [
    180,
    120,
    75,
  ]),
  _Task('tsk_05', '0005', 'Checkout accessibility fixes', 6, 2, 0, 5, [90]),
  _Task('tsk_06', '0006', 'Booking flow usability interviews', 10, 3, 1, 4, [
    240,
    200,
  ]),
  _Task('tsk_07', '0007', 'Reminder email copy review', 11, 4, 0, 2, [50]),
  _Task('tsk_08', '0008', 'Quarterly analytics report', 7, -1, 2, 15, [135]),
  _Task('tsk_09', '0009', 'Staff training session prep', 4, -1, 0, 1, [70, 40]),
];

const _taskStatuses = <List<String>>[
  ['tst_01', 'Backlog', '#78909C'],
  ['tst_02', 'In progress', '#1565C0'],
  ['tst_03', 'Ready to invoice', '#2E7D32'],
];

double _lineCost(_Line l) => _products[l.product].price;

double _subtotal(_Invoice i) =>
    i.lines.fold(0, (sum, l) => sum + _lineCost(l) * l.qty);

double _total(_Invoice i) => _round(_subtotal(i) * (1 + i.tax / 100));

InvoiceEntity _invoice(_Invoice i, EntityType type) {
  final client = _clients[i.client];
  final total = _total(i);
  final paid = _round(total * i.paidFraction);
  final isDraft = i.status == kInvoiceStatusDraft;
  return InvoiceEntity(id: i.id, entityType: type).rebuild(
    (b) => b
      ..number = i.number
      ..clientId = type == EntityType.purchaseOrder ? '' : client.id
      ..vendorId = type == EntityType.purchaseOrder ? _vendors[i.client].id : ''
      ..statusId = i.status
      ..date = day(i.daysAgo)
      ..dueDate = type == EntityType.credit ? '' : day(i.daysAgo - i.dueIn)
      ..amount = total
      ..balance = isDraft || i.status == kInvoiceStatusCancelled
          ? 0
          : _round(total - paid)
      ..paidToDate = paid
      ..poNumber = i.po
      ..publicNotes = i.notes
      ..terms = type == EntityType.invoice
          ? 'Payment is due within ${i.dueIn} days of the invoice date.'
          : ''
      ..footer = type == EntityType.invoice
          ? 'Thank you for your business.'
          : ''
      ..taxName1 = i.tax > 0 ? 'Sales tax' : ''
      ..taxRate1 = i.tax
      ..taxAmount = _round(total - _subtotal(i))
      ..designId = 'dsg_01'
      ..lastSentDate = isDraft ? '' : day(i.daysAgo)
      ..createdAt = ts(i.daysAgo)
      ..updatedAt = ts(i.daysAgo > 2 ? i.daysAgo - 1 : i.daysAgo)
      ..createdUserId = kUserId
      ..assignedUserId = i.client.isEven ? kUserId : kUser2Id
      ..lineItems.replace([
        for (final l in i.lines)
          InvoiceItemEntity(productKey: _products[l.product].key).rebuild(
            (item) => item
              ..notes = _products[l.product].notes
              ..cost = _lineCost(l)
              ..quantity = l.qty
              ..createdAt = ts(i.daysAgo),
          ),
      ])
      ..invitations.replace([
        InvitationEntity(
          clientContactId: type == EntityType.purchaseOrder
              ? null
              : 'con_${client.id}',
          vendorContactId: type == EntityType.purchaseOrder
              ? 'vcon_${_vendors[i.client].id}'
              : null,
        ).rebuild(
          (inv) => inv
            ..id = 'ivt_${i.id}'
            ..key = 'key${i.id}'
            ..link = '$kFixtureUrl/client/${type.snakeCase}/key${i.id}'
            ..sentDate = isDraft ? '' : day(i.daysAgo)
            ..viewedDate = i.paidFraction > 0 ? day(i.daysAgo - 1) : '',
        ),
      ]),
  );
}

/// The company the logged-in user sees.
CompanyEntity buildCompany() {
  final settings = SettingsEntity().rebuild(
    (b) => b
      ..name = 'Northwind Studio LLC'
      ..address1 = '418 Alder Street'
      ..address2 = 'Suite 210'
      ..city = 'Portland'
      ..state = 'Oregon'
      ..postalCode = '97205'
      ..countryId = '840'
      ..phone = '(503) 555-0142'
      ..email = 'hello@northwind.example'
      ..website = 'https://northwind.example'
      ..vatNumber = 'US-93-1184420'
      ..idNumber = '1184420'
      ..currencyId = kCurrencyUSDollar
      ..languageId = kLanguageEnglish
      ..timezoneId = '15'
      ..dateFormatId = kDefaultDateFormat
      ..enableMilitaryTime = false
      ..defaultTaskRate = 140
      ..defaultPaymentTerms = '30'
      ..defaultValidUntil = '30'
      ..defaultInvoiceDesignId = 'dsg_01'
      ..defaultQuoteDesignId = 'dsg_01'
      ..defaultCreditDesignId = 'dsg_01'
      ..defaultInvoiceTerms =
          'Payment is due within 30 days of the invoice date.'
      ..defaultInvoiceFooter = 'Thank you for your business.'
      ..defaultTaxName1 = 'Sales tax'
      ..defaultTaxRate1 = 8.5
      ..emailSignature = 'Ada Lovelace\nNorthwind Studio LLC'
      // Company settings the server always sends and the app reads without
      // a null check.
      ..showTaskItemDescription = false
      ..allowBillableTaskItems = false
      ..enableInclusiveTaxes = false
      ..emailStyleCustom = ''
      ..companyLogo = ''
      ..companyLogoSize = ''
      ..companyGatewayIds = ''
      ..pdfVariables.replace(<String, BuiltList<String>>{
        'client_details': BuiltList<String>(const [
          r'$client.name',
          r'$client.number',
          r'$client.address1',
          r'$client.city_state_postal',
          r'$client.country',
          r'$contact.email',
        ]),
        'company_details': BuiltList<String>(const [
          r'$company.name',
          r'$company.phone',
          r'$company.email',
          r'$company.website',
        ]),
        'company_address': BuiltList<String>(const [
          r'$company.address1',
          r'$company.address2',
          r'$company.city_state_postal',
          r'$company.country',
        ]),
        'invoice_details': BuiltList<String>(const [
          r'$invoice.number',
          r'$invoice.po_number',
          r'$invoice.date',
          r'$invoice.due_date',
          r'$invoice.total',
          r'$invoice.balance_due',
        ]),
        'quote_details': BuiltList<String>(const [
          r'$quote.number',
          r'$quote.date',
          r'$quote.valid_until',
          r'$quote.total',
        ]),
        'credit_details': BuiltList<String>(const [
          r'$credit.number',
          r'$credit.date',
          r'$credit.total',
          r'$credit.balance',
        ]),
        'product_columns': BuiltList<String>(const [
          r'$product.item',
          r'$product.description',
          r'$product.unit_cost',
          r'$product.quantity',
          r'$product.line_total',
        ]),
        'task_columns': BuiltList<String>(const [
          r'$task.service',
          r'$task.description',
          r'$task.rate',
          r'$task.hours',
          r'$task.line_total',
        ]),
        'total_columns': BuiltList<String>(const [
          r'$subtotal',
          r'$discount',
          r'$total_taxes',
          r'$total',
          r'$paid_to_date',
          r'$outstanding',
        ]),
      })
      // The server always sends this map, empty when nothing is renamed.
      ..translations = MapBuilder<String?, String>(),
  );

  final clients = [
    for (final c in _clients)
      ClientEntity(id: c.id).rebuild(
        (b) => b
          ..name = c.name
          ..displayName = c.name
          ..number = c.id.substring(4).padLeft(4, '0')
          ..balance = c.balance
          ..paidToDate = c.paid
          ..creditBalance = c.id == 'cli_01' ? 95 : 0
          ..address1 = '${100 + c.id.hashCode % 800} ${c.last} Avenue'
          ..city = c.city
          ..state = c.state
          ..postalCode = '9${c.id.substring(4)}05'
          ..countryId = c.country
          ..phone = '(555) 01${c.id.substring(4)}-4400'
          ..website = 'https://${c.email.split('@').last}'
          ..vatNumber = c.country == '826' ? 'GB 284 7719 05' : ''
          ..idNumber = ''
          ..privateNotes = c.id == 'cli_03'
              ? 'Prefers invoices on the first of the month.'
              : ''
          ..createdAt = ts(200 - _clients.indexOf(c) * 9)
          ..updatedAt = ts(30 - _clients.indexOf(c) * 2)
          ..createdUserId = kUserId
          ..assignedUserId = _clients.indexOf(c).isEven ? kUserId : kUser2Id
          ..settings.currencyId = c.country == '826'
              ? '2'
              : c.country == '124'
              ? '9'
              : kCurrencyUSDollar
          ..contacts.replace([
            ClientContactEntity().rebuild(
              (contact) => contact
                ..id = 'con_${c.id}'
                ..firstName = c.first
                ..lastName = c.last
                ..email = c.email
                ..phone = '(555) 01${c.id.substring(4)}-4401'
                ..isPrimary = true
                ..sendEmail = true
                ..contactKey = 'ck${c.id}'
                ..createdAt = ts(200),
            ),
            if (c.id == 'cli_03' || c.id == 'cli_11')
              ClientContactEntity().rebuild(
                (contact) => contact
                  ..id = 'con2_${c.id}'
                  ..firstName = 'Accounts'
                  ..lastName = 'Payable'
                  ..email = 'accounts@${c.email.split('@').last}'
                  ..isPrimary = false
                  ..sendEmail = true
                  ..contactKey = 'ck2${c.id}'
                  ..createdAt = ts(180),
              ),
          ]),
      ),
  ];

  final products = [
    for (final p in _products)
      ProductEntity(id: p.id).rebuild(
        (b) => b
          ..productKey = p.key
          ..notes = p.notes
          ..price = p.price
          ..cost = p.cost
          ..quantity = 1
          ..stockQuantity = p.qty
          ..createdAt = ts(220)
          ..updatedAt = ts(40)
          ..createdUserId = kUserId,
      ),
  ];

  final invoices = [for (final i in _invoices) _invoice(i, EntityType.invoice)];
  final quotes = [for (final i in _quotes) _invoice(i, EntityType.quote)];
  final credits = [for (final i in _credits) _invoice(i, EntityType.credit)];
  final purchaseOrders = [
    for (final i in _purchaseOrders) _invoice(i, EntityType.purchaseOrder),
  ];

  final recurring = [
    for (final (index, r) in const [
      ['rec_01', 'R-0001', '1', kRecurringInvoiceStatusActive],
      ['rec_02', 'R-0002', '4', kRecurringInvoiceStatusActive],
      ['rec_03', 'R-0003', '11', kRecurringInvoiceStatusPaused],
      ['rec_04', 'R-0004', '7', kRecurringInvoiceStatusDraft],
    ].indexed)
      _invoice(
        _Invoice(r[0], r[1], int.parse(r[2]), r[3], 60 + index * 15, 30, const [
          _Line(2, 1),
          _Line(3, 1),
        ]),
        EntityType.recurringInvoice,
      ).rebuild(
        (b) => b
          ..frequencyId = kFrequencyMonthly
          ..remainingCycles = -1
          ..dueDateDays = 'terms'
          ..autoBill = 'off'
          ..autoBillEnabled = false
          ..balance = 0
          ..nextSendDate = r[3] == kRecurringInvoiceStatusActive
              ? day(-(12 + index * 3))
              : ''
          ..nextSendDatetime = r[3] == kRecurringInvoiceStatusActive
              ? '${day(-(12 + index * 3))} 09:00:00'
              : '',
      ),
  ];

  final payments = <PaymentEntity>[];
  var paymentNumber = 1;
  for (final i in _invoices) {
    if (i.paidFraction <= 0) {
      continue;
    }
    final amount = _round(_total(i) * i.paidFraction);
    final n = paymentNumber++;
    payments.add(
      PaymentEntity(id: 'pay_${n.toString().padLeft(2, '0')}').rebuild(
        (b) => b
          ..number = n.toString().padLeft(4, '0')
          ..clientId = _clients[i.client].id
          ..amount = amount
          ..applied = amount
          ..refunded = i.id == 'inv_06' ? 165 : 0
          ..statusId = i.id == 'inv_06'
              ? kPaymentStatusPartiallyRefunded
              : kPaymentStatusCompleted
          ..date = day(i.daysAgo - 5)
          ..typeId = n.isEven ? '1' : '5'
          ..transactionReference = n.isEven ? 'TRF-48${n}19' : 'ch_3P${n}xQ2e'
          ..currencyId = kCurrencyUSDollar
          ..isManual = true
          ..createdAt = ts(i.daysAgo - 5)
          ..updatedAt = ts(i.daysAgo - 5)
          ..createdUserId = kUserId
          ..paymentables.replace([
            PaymentableEntity(invoiceId: i.id, amount: amount).rebuild(
              (p) => p
                ..id = 'pbl_$n'
                ..createdAt = ts(i.daysAgo - 5),
            ),
          ]),
      ),
    );
  }
  // One payment that has not been applied to an invoice yet.
  payments.add(
    PaymentEntity(id: 'pay_99').rebuild(
      (b) => b
        ..number = paymentNumber.toString().padLeft(4, '0')
        ..clientId = 'cli_12'
        ..amount = 500
        ..applied = 0
        ..statusId = kPaymentStatusCompleted
        ..date = day(2)
        ..typeId = '1'
        ..transactionReference = 'TRF-551204'
        ..currencyId = kCurrencyUSDollar
        ..isManual = true
        ..createdAt = ts(2)
        ..updatedAt = ts(2)
        ..createdUserId = kUserId,
    ),
  );

  final vendors = [
    for (final v in _vendors)
      VendorEntity(id: v.id).rebuild(
        (b) => b
          ..name = v.name
          ..displayName = v.name
          ..number = v.id.substring(4).padLeft(4, '0')
          ..address1 = '${20 + v.id.hashCode % 400} Market Street'
          ..city = v.city
          ..state = v.state
          ..postalCode = '97${v.id.substring(4)}1'
          ..countryId = v.city == 'Dublin'
              ? '372'
              : v.city == 'Oslo'
              ? '578'
              : '840'
          ..phone = '(555) 02${v.id.substring(4)}-7700'
          ..website = 'https://${v.email.split('@').last}'
          ..currencyId = kCurrencyUSDollar
          ..createdAt = ts(190)
          ..updatedAt = ts(35)
          ..createdUserId = kUserId
          ..contacts.replace([
            VendorContactEntity().rebuild(
              (c) => c
                ..id = 'vcon_${v.id}'
                ..firstName = v.first
                ..lastName = v.last
                ..email = v.email
                ..phone = '(555) 02${v.id.substring(4)}-7701'
                ..isPrimary = true
                ..createdAt = ts(190),
            ),
          ]),
      ),
  ];

  final expenseCategories = [
    for (final c in _expenseCategories)
      ExpenseCategoryEntity(id: c[0]).rebuild(
        (b) => b
          ..name = c[1]
          ..color = c[2]
          ..createdAt = ts(220)
          ..updatedAt = ts(220),
      ),
  ];

  final expenses = [
    for (final e in _expenses)
      ExpenseEntity(id: e.id).rebuild(
        (b) => b
          ..number = e.number
          ..vendorId = _vendors[e.vendor].id
          ..categoryId = _expenseCategories[e.category][0]
          ..clientId = e.client >= 0 ? _clients[e.client].id : ''
          ..invoiceId = ''
          ..projectId = ''
          ..statusId = e.paid ? kExpenseStatusPaid : kExpenseStatusLogged
          ..amount = e.amount
          ..date = day(e.daysAgo)
          ..paymentDate = e.paid ? day(e.daysAgo) : ''
          ..paymentTypeId = e.paid ? '5' : ''
          ..publicNotes = e.notes
          ..shouldBeInvoiced = e.billable
          ..currencyId = kCurrencyUSDollar
          ..invoiceCurrencyId = kCurrencyUSDollar
          ..createdAt = ts(e.daysAgo)
          ..updatedAt = ts(e.daysAgo)
          ..createdUserId = kUserId,
      ),
  ];

  final recurringExpenses = [
    ExpenseEntity(
      id: 'rex_01',
      entityType: EntityType.recurringExpense,
    ).rebuild(
      (b) => b
        ..number = 'RE-0001'
        ..vendorId = 'ven_04'
        ..clientId = ''
        ..invoiceId = ''
        ..projectId = ''
        ..categoryId = 'cat_03'
        ..amount = 450
        ..date = day(90)
        ..publicNotes = 'Co-working desk, monthly'
        ..frequencyId = kFrequencyMonthly
        ..remainingCycles = -1
        ..nextSendDate = day(-29)
        ..statusId = kRecurringExpenseStatusActive
        ..currencyId = kCurrencyUSDollar
        ..createdAt = ts(90)
        ..updatedAt = ts(1)
        ..createdUserId = kUserId,
    ),
    ExpenseEntity(
      id: 'rex_02',
      entityType: EntityType.recurringExpense,
    ).rebuild(
      (b) => b
        ..number = 'RE-0002'
        ..vendorId = 'ven_06'
        ..clientId = ''
        ..invoiceId = ''
        ..projectId = ''
        ..categoryId = 'cat_06'
        ..amount = 298
        ..date = day(77)
        ..publicNotes = 'Professional liability premium'
        ..frequencyId = kFrequencyMonthly
        ..remainingCycles = -1
        ..nextSendDate = day(-13)
        ..statusId = kRecurringExpenseStatusActive
        ..currencyId = kCurrencyUSDollar
        ..createdAt = ts(77)
        ..updatedAt = ts(17)
        ..createdUserId = kUserId,
    ),
  ];

  final projects = [
    for (final p in _projects)
      ProjectEntity(id: p.id).rebuild(
        (b) => b
          ..number = p.number
          ..name = p.name
          ..clientId = _clients[p.client].id
          ..budgetedHours = p.hours
          ..taskRate = p.rate
          ..dueDate = day(-p.dueIn)
          ..color = '#1565C0'
          ..publicNotes = ''
          ..createdAt = ts(70)
          ..updatedAt = ts(12)
          ..createdUserId = kUserId
          ..assignedUserId = kUserId,
      ),
  ];

  final taskStatuses = [
    for (final (index, s) in _taskStatuses.indexed)
      TaskStatusEntity(id: s[0]).rebuild(
        (b) => b
          ..name = s[1]
          ..color = s[2]
          ..statusOrder = index
          ..createdAt = ts(220)
          ..updatedAt = ts(220),
      ),
  ];

  final tasks = [
    for (final (index, t) in _tasks.indexed)
      TaskEntity(id: t.id).rebuild((b) {
        var start = ts(t.daysAgo, 9);
        final log = <List<dynamic>>[];
        for (final minutes in t.minutes) {
          log.add(<dynamic>[start, start + minutes * 60, '', true]);
          start += minutes * 60 + 1800;
        }
        b
          ..number = t.number
          ..description = t.description
          ..clientId = _clients[t.client].id
          ..projectId = t.project >= 0 ? _projects[t.project].id : ''
          ..statusId = _taskStatuses[t.status][0]
          ..statusOrder = index
          ..rate = t.project >= 0 ? _projects[t.project].rate : 140
          ..invoiceId = t.invoiced ? 'inv_11' : ''
          ..timeLog = jsonEncode(log)
          ..createdAt = ts(t.daysAgo)
          ..updatedAt = ts(t.daysAgo)
          ..createdUserId = kUserId
          ..assignedUserId = index.isEven ? kUserId : kUser2Id;
      }),
  ];

  final users = [
    UserEntity(id: kUserId).rebuild(
      (b) => b
        ..firstName = 'Ada'
        ..lastName = 'Lovelace'
        ..email = kFixtureEmail
        ..phone = '(503) 555-0142'
        ..emailVerifiedAt = ts(300)
        ..hasPassword = true
        ..createdAt = ts(300)
        ..updatedAt = ts(20),
    ),
    UserEntity(id: kUser2Id).rebuild(
      (b) => b
        ..firstName = 'Grace'
        ..lastName = 'Hopper'
        ..email = 'grace@northwind.example'
        ..phone = '(503) 555-0177'
        ..emailVerifiedAt = ts(250)
        ..hasPassword = true
        ..createdAt = ts(250)
        ..updatedAt = ts(20),
    ),
  ];

  final activities = <ActivityEntity>[
    for (final (index, a) in <List<String?>>[
      [kActivityCreatePayment, 'cli_02', 'inv_15', 'pay_07'],
      [kActivityEmailInvoice, 'cli_11', 'inv_14', null],
      [kActivityCreateInvoice, 'cli_11', 'inv_14', null],
      [kActivityViewInvoice, 'cli_12', 'inv_12', null],
      [kActivityCreatePayment, 'cli_05', 'inv_13', 'pay_06'],
      [kActivityEmailInvoice, 'cli_03', 'inv_11', null],
      [kActivityCreateInvoice, 'cli_03', 'inv_11', null],
      [kActivityCreateClient, 'cli_12', null, null],
    ].indexed)
      ActivityEntity(
        (b) => b
          ..key = 'act_${index + 1}'
          ..notes = ''
          ..activityTypeId = a[0]
          ..userId = kUserId
          ..clientId = a[1]
          ..invoiceId = a[2]
          ..paymentId = a[3]
          ..isSystem = false
          ..ip = '203.0.113.24'
          ..createdAt = ts(index + 1, 14)
          ..updatedAt = ts(index + 1, 14),
      ),
  ];

  final designs = [
    for (final (index, name) in const [
      'Clean',
      'Bold',
      'Modern',
      'Elegant',
      'Business',
    ].indexed)
      DesignEntity(
        id: 'dsg_0${index + 1}',
        design: BuiltMap<String, String>(),
      ).rebuild(
        (b) => b
          ..name = name
          ..isCustom = false
          ..isFree = true
          ..createdAt = ts(400)
          ..updatedAt = ts(400),
      ),
  ];

  // A factory that ignores its id would hand out a temporary one, and the
  // app treats a record with a temporary id as unsaved.
  for (final entity in <BaseEntity>[
    ...clients,
    ...products,
    ...invoices,
    ...quotes,
    ...credits,
    ...purchaseOrders,
    ...recurring,
    ...payments,
    ...vendors,
    ...expenses,
    ...recurringExpenses,
    ...expenseCategories,
    ...projects,
    ...taskStatuses,
    ...tasks,
    ...users,
    ...designs,
  ]) {
    if (entity.isNew) {
      throw StateError('fixture: ${entity.entityType} has a temporary id');
    }
  }

  return CompanyEntity().rebuild(
    (b) => b
      ..id = kCompanyId
      ..companyKey = 'northwindCompanyKey0000000000000'
      ..settings.replace(settings)
      ..sizeId = '2'
      ..industryId = '15'
      ..subdomain = 'northwind'
      ..firstMonthOfYear = '1'
      ..enabledModules =
          kModuleRecurringInvoices |
          kModuleCredits |
          kModuleQuotes |
          kModuleTasks |
          kModuleExpenses |
          kModuleProjects |
          kModuleVendors |
          kModuleDocuments |
          kModuleRecurringExpenses |
          kModuleInvoices |
          kModulePurchaseOrders
      ..numberOfInvoiceTaxRates = 1
      ..numberOfItemTaxRates = 0
      ..enableProductCost = true
      ..showTaskEndDate = true
      ..createdAt = ts(300)
      ..updatedAt = ts(1)
      ..users.replace(users)
      ..clients.replace(clients)
      ..products.replace(products)
      ..invoices.replace(invoices)
      ..quotes.replace(quotes)
      ..credits.replace(credits)
      ..purchaseOrders.replace(purchaseOrders)
      ..recurringInvoices.replace(recurring)
      ..payments.replace(payments)
      ..vendors.replace(vendors)
      ..expenses.replace(expenses)
      ..recurringExpenses.replace(recurringExpenses)
      ..expenseCategories.replace(expenseCategories)
      ..projects.replace(projects)
      ..tasks.replace(tasks)
      ..taskStatuses.replace(taskStatuses)
      ..activities.replace(activities)
      ..designs.replace(designs)
      ..taxRates.replace([
        TaxRateEntity(id: 'tax_01', name: 'Sales tax', rate: 8.5).rebuild(
          (t) => t
            ..id = 'tax_01'
            ..createdAt = ts(300)
            ..updatedAt = ts(300),
        ),
        TaxRateEntity(id: 'tax_02', name: 'GST', rate: 5).rebuild(
          (t) => t
            ..id = 'tax_02'
            ..createdAt = ts(300)
            ..updatedAt = ts(300),
        ),
        TaxRateEntity(id: 'tax_03', name: 'VAT', rate: 20).rebuild(
          (t) => t
            ..id = 'tax_03'
            ..createdAt = ts(300)
            ..updatedAt = ts(300),
        ),
      ])
      ..paymentTerms.replace([
        for (final days in const [7, 15, 30, 60])
          PaymentTermEntity(id: 'trm_$days').rebuild(
            (t) => t
              ..name = 'Net $days'
              ..numDays = days
              ..createdAt = ts(300)
              ..updatedAt = ts(300),
          ),
      ])
      ..groups.replace([
        GroupEntity(id: 'grp_01').rebuild(
          (g) => g
            ..name = 'Retainer clients'
            ..createdAt = ts(150)
            ..updatedAt = ts(150),
        ),
      ])
      ..companyGateways.replace([
        CompanyGatewayEntity(id: 'cgw_01').rebuild(
          (g) => g
            ..gatewayId = kGatewayStripe
            ..label = 'Stripe (cards)'
            ..isTestMode = true
            ..createdAt = ts(120)
            ..updatedAt = ts(120),
        ),
      ]),
  );
}

/// What the fake server answers to `POST /api/v1/login`.
LoginResponse buildLoginResponse({bool withData = true}) {
  final company = withData
      ? buildCompany()
      : buildCompany().rebuild(
          (b) => b
            ..clients.clear()
            ..products.clear()
            ..invoices.clear()
            ..quotes.clear()
            ..credits.clear()
            ..purchaseOrders.clear()
            ..recurringInvoices.clear()
            ..payments.clear()
            ..vendors.clear()
            ..expenses.clear()
            ..recurringExpenses.clear()
            ..projects.clear()
            ..tasks.clear()
            ..activities.clear()
            ..groups.clear()
            ..companyGateways.clear(),
        );
  // The server nests each user's own company settings in the user.
  final companyUser = UserCompanyEntity(false).rebuild(
    (b) => b
      ..isAdmin = true
      ..isOwner = true,
  );
  final user = company.users.first.rebuild(
    (b) => b..userCompany.replace(companyUser),
  );
  final userCompany = UserCompanyEntity(false).rebuild(
    (b) => b
      ..isAdmin = true
      ..isOwner = true
      ..permissionsUpdatedAt = 0
      ..company.replace(
        company.rebuild(
          (c) => c.users.map(
            (u) => u.rebuild((b) => b..userCompany.replace(companyUser)),
          ),
        ),
      )
      ..user.replace(user)
      ..token.replace(
        TokenEntity().rebuild(
          (t) => t
            ..id = 'tok_01'
            ..name = 'web_client'
            ..token = kFixtureToken
            ..isSystem = true
            ..createdAt = ts(300)
            ..updatedAt = ts(300),
        ),
      )
      ..account.replace(
        AccountEntity(false, id: 'acc_northwind').rebuild(
          (a) => a
            ..key = 'northwindAccountKey0000000000000'
            ..defaultUrl = kFixtureUrl
            ..defaultCompanyId = kCompanyId
            ..currentVersion = '5.12.38'
            ..latestVersion = '5.12.38'
            ..isHosted = false
            ..isSchedulerRunning = true
            ..accountSmsVerified = true
            ..plan = ''
            ..hostedClientCount = 0
            ..hostedCompanyCount = 0,
        ),
      ),
  );
  return LoginResponse(
    (b) => b
      ..userCompanies.add(userCompany)
      ..static.replace(buildStatic()),
  );
}

/// [buildLoginResponse] in the wire format the server sends.
Map<String, dynamic> buildLoginJson({bool withData = true}) =>
    serializers.serializeWith(
          LoginResponse.serializer,
          buildLoginResponse(withData: withData),
        )
        as Map<String, dynamic>;
