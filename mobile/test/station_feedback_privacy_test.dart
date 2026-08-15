import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/shared/models/charger_submission.dart';
import 'package:voltmap/shared/models/station_feedback.dart';
import 'package:voltmap/shared/state/app_state.dart';

void main() {
  test('station correction email has exactly the admin recipient', () {
    final feedback = StationFeedbackDraft(
      feedbackId: 'FB-1',
      stationId: 'station-1',
      stationName: 'Karmanghat Charge Hub',
      operatorName: 'Example CPO',
      address: '500079, Telangana',
      latitude: 17.3366,
      longitude: 78.5349,
      category: StationFeedbackCategory.notWorking,
      details: 'Visited today and both CCS2 connectors were unavailable.',
      observedAt: DateTime.utc(2026, 8, 15, 12),
      createdAt: DateTime.utc(2026, 8, 15, 12, 5),
      sourceNames: const ['Operator OCPI', 'BEE'],
    );

    final uri = feedback.privateAdminEmailUri(AppState.adminIdentifier);

    expect(uri.scheme, 'mailto');
    expect(uri.path, AppState.adminIdentifier);
    expect(uri.queryParameters, isNot(contains('cc')));
    expect(uri.queryParameters, isNot(contains('bcc')));
    expect(uri.queryParameters['body'], contains('both CCS2 connectors'));
    expect(uri.queryParameters['body'], contains('Operator OCPI, BEE'));
    expect(uri.queryParameters['body'], contains('addressed only'));
  });

  test('missing station report is private rather than a public issue', () {
    final report = ChargerSubmission(
      id: 'CHG-1',
      stationName: 'Missing Highway Charger',
      operatorName: 'Example CPO',
      address: 'NH 44',
      city: 'Hyderabad',
      state: 'Telangana',
      postalCode: '500079',
      connectorTypes: const ['CCS2'],
      reportedStatus: 'Working',
      notes: 'Operator app confirms the site.',
      createdAt: DateTime.utc(2026, 8, 15),
    );

    final uri = report.privateAdminEmailUri(AppState.adminIdentifier);

    expect(uri.scheme, 'mailto');
    expect(uri.host, isEmpty);
    expect(uri.path, AppState.adminIdentifier);
    expect(uri.toString(), isNot(contains('github.com')));
    expect(uri.queryParameters['body'], contains('private'));
  });
}
