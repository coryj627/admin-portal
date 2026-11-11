// Runtime accessibility audit: the settings home and its pages, phone
// viewport.  One file per viewport so that the two run in separate isolates.
// See README.md.
import 'support/harness.dart';
import 'support/settings_tour.dart';

void main() => settingsTests(AuditViewport.phone);
