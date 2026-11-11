// Runtime accessibility audit: the login screen in its states.  The app is
// launched as on a first run and nobody signs in.  See README.md.
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/walk.dart';

void main() {
  for (final viewport in AuditViewport.values) {
    testWidgets('${viewport.id}: login', (tester) async {
      await withApp(tester, viewport, signedIn: false, (app) async {
        // Hosted login: e-mail, password and the one-time password field.
        await app.audit('login/hosted');
        await screen(app, 'login/hosted-google', () => tapText(app, 'Google'));
        await tapText(app, 'Email');
        await screen(
          app,
          'login/hosted-sign-up',
          () => tapText(app, 'Create your account in seconds'),
        );
        await tapText(app, 'Login to an existing account');
        await screen(
          app,
          'login/recover-password',
          () => tapText(app, 'Recover Password'),
        );
        await tapText(app, 'Cancel');
        // Self-hosted login: adds the server URL and secret fields.
        await screen(
          app,
          'login/self-hosted',
          () => tapText(app, 'Self-Hosted'),
        );
        await screen(app, 'login/self-hosted-refused', () async {
          // What WebClient throws for a 401 from the server.
          app.server.loginError =
              '401: Unauthorized • These credentials do not match our records';
          await tester.enterText(
            fieldLabelled('URL'),
            'ninja.northwind.example',
          );
          await tapText(app, 'Login with email');
          await app.settle(10);
          app.server.loginError = null;
        });
      });
    });
  }
}
