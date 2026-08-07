class StateChargerCoverage {
  const StateChargerCoverage({
    required this.state,
    required this.stationCount,
    this.aliases = const [],
  });

  final String state;
  final int stationCount;
  final List<String> aliases;

  bool matches(String rawQuery) {
    final query = _normalize(rawQuery);
    if (query.isEmpty) return false;
    return <String>[state, ...aliases].map(_normalize).any(
        (candidate) => candidate.contains(query) || query.contains(candidate));
  }
}

const officialStationTotal = 29277;
const officialStationDataDate = '1 August 2025';
const officialStationSourceUrl =
    'https://sansad.in/getFile/annex/268/AU1521_5sMm07.pdf?source=pqars';
const evYatraUrl = 'https://evyatra.beeindia.gov.in/';

const stateChargerCoverage = <StateChargerCoverage>[
  StateChargerCoverage(state: 'Karnataka', stationCount: 6097),
  StateChargerCoverage(state: 'Maharashtra', stationCount: 4155),
  StateChargerCoverage(
    state: 'Uttar Pradesh',
    stationCount: 2326,
    aliases: ['UP', 'U.P'],
  ),
  StateChargerCoverage(state: 'Delhi', stationCount: 1967, aliases: ['NCR']),
  StateChargerCoverage(state: 'Tamil Nadu', stationCount: 1781),
  StateChargerCoverage(state: 'Rajasthan', stationCount: 1531),
  StateChargerCoverage(state: 'Kerala', stationCount: 1392),
  StateChargerCoverage(state: 'Gujarat', stationCount: 1208),
  StateChargerCoverage(state: 'Madhya Pradesh', stationCount: 1147),
  StateChargerCoverage(state: 'Telangana', stationCount: 1066),
  StateChargerCoverage(state: 'Haryana', stationCount: 935),
  StateChargerCoverage(state: 'West Bengal', stationCount: 903),
  StateChargerCoverage(state: 'Andhra Pradesh', stationCount: 793),
  StateChargerCoverage(state: 'Punjab', stationCount: 717),
  StateChargerCoverage(state: 'Odisha', stationCount: 623, aliases: ['Orissa']),
  StateChargerCoverage(state: 'Bihar', stationCount: 521),
  StateChargerCoverage(state: 'Jharkhand', stationCount: 353),
  StateChargerCoverage(state: 'Chhattisgarh', stationCount: 346),
  StateChargerCoverage(state: 'Assam', stationCount: 344),
  StateChargerCoverage(state: 'Uttarakhand', stationCount: 223),
  StateChargerCoverage(
    state: 'Jammu & Kashmir',
    stationCount: 185,
    aliases: ['Jammu and Kashmir', 'J&K'],
  ),
  StateChargerCoverage(state: 'Goa', stationCount: 158),
  StateChargerCoverage(state: 'Himachal Pradesh', stationCount: 137),
  StateChargerCoverage(state: 'Meghalaya', stationCount: 62),
  StateChargerCoverage(state: 'Manipur', stationCount: 58),
  StateChargerCoverage(state: 'Tripura', stationCount: 56),
  StateChargerCoverage(state: 'Puducherry', stationCount: 50),
  StateChargerCoverage(state: 'Arunachal Pradesh', stationCount: 47),
  StateChargerCoverage(state: 'Nagaland', stationCount: 42),
  StateChargerCoverage(state: 'Chandigarh', stationCount: 14),
  StateChargerCoverage(state: 'Mizoram', stationCount: 13),
  StateChargerCoverage(state: 'Sikkim', stationCount: 12),
  StateChargerCoverage(
    state: 'Dadra & Nagar Haveli and Daman & Diu',
    stationCount: 9,
    aliases: ['D&NH and D&D', 'Dadra Nagar Haveli', 'Daman Diu'],
  ),
  StateChargerCoverage(state: 'Andaman & Nicobar', stationCount: 4),
  StateChargerCoverage(state: 'Ladakh', stationCount: 1),
  StateChargerCoverage(state: 'Lakshadweep', stationCount: 1),
];

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
