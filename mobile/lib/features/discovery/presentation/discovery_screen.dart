import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/models/place_suggestion.dart';
import '../../../shared/services/place_search_service.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/registered_account_gate.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../data/sample_stations.dart';
import '../data/national_charger_data.dart';
import '../../install/presentation/install_app_screen.dart';
import 'official_charger_results_view.dart';
import 'station_card.dart';
import 'station_details_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final searchController = TextEditingController();
  final placeSearchService = const PlaceSearchService();
  String query = '';
  bool availableOnly = false;
  bool fastOnly = false;
  bool locating = false;
  bool resolvingChargerResults = false;
  String? locationMessage;
  PlaceSuggestion? selectedPlace;
  String? officialResultsQuery;
  PlaceSuggestion? officialResultsCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usePreviouslyAllowedLocation();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ChargingStation> get filteredStations {
    final matches = sampleStations.where((station) {
      return _matchesSearch(station, query) &&
          (!availableOnly || station.available) &&
          (!fastOnly || station.isFast);
    }).toList(growable: false);

    if (query.trim().isNotEmpty) {
      matches.sort((a, b) {
        final pinComparison = a.postalCode.compareTo(b.postalCode);
        return pinComparison != 0 ? pinComparison : a.name.compareTo(b.name);
      });
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final stations = filteredStations;
    Widget buildStationCard(ChargingStation station) => RepaintBoundary(
          child: StationCard(
            station: station,
            isFavorite: appState.isFavorite(station.id),
            onFavorite: () async {
              if (await requireRegisteredAccount(
                context,
                appState,
                'Favorites',
              )) {
                await appState.toggleFavorite(station.id);
              }
            },
            onTap: () => _openDetails(station),
          ),
        );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final horizontalPadding = compact ? 16.0 : 28.0;
          final contentWidth =
              (constraints.maxWidth - horizontalPadding * 2).clamp(0.0, 1180.0);
          final centeredPadding = (constraints.maxWidth - contentWidth)
                  .clamp(0.0, double.infinity) /
              2;
          return CustomScrollView(
            key: const PageStorageKey('discoveryScrollView'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            scrollCacheExtent: const ScrollCacheExtent.pixels(1100),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  centeredPadding,
                  compact ? 14 : 26,
                  centeredPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DiscoveryHero(
                          searchController: searchController,
                          query: query,
                          onSearchChanged: _handleSearchChanged,
                          onSearchSubmitted: (_) => _showChargerResults(),
                          searchService: placeSearchService,
                          onLocationSelected: _selectLocation,
                          onUseLocation: () => _resolveCurrentLocation(
                            requestPermission: true,
                          ),
                          locating: locating,
                          locationMessage: locationMessage,
                          onClear: _clearSearch,
                        ),
                        const SizedBox(height: 22),
                        if (resolvingChargerResults)
                          const _InlineSearchProgress()
                        else if (officialResultsQuery != null)
                          OfficialChargerResultsView(
                            key: const Key('inlineOfficialChargerResults'),
                            query: officialResultsQuery!,
                            center: officialResultsCenter,
                            embedded: true,
                          )
                        else ...[
                          _NationalCoverageCard(query: query),
                          const SizedBox(height: 22),
                          _FilterRow(
                            availableOnly: availableOnly,
                            fastOnly: fastOnly,
                            onAvailableChanged: (value) =>
                                setState(() => availableOnly = value),
                            onFastChanged: (value) =>
                                setState(() => fastOnly = value),
                          ),
                          const SizedBox(height: 30),
                          _ResultsHeader(count: stations.length, query: query),
                          const SizedBox(height: 14),
                          if (query.trim().isNotEmpty && stations.isNotEmpty)
                            LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final twoColumns =
                                    gridConstraints.maxWidth >= 760;
                                final cardWidth = twoColumns
                                    ? (gridConstraints.maxWidth - 16) / 2
                                    : gridConstraints.maxWidth;
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    for (final station in stations)
                                      SizedBox(
                                        width: cardWidth,
                                        child: buildStationCard(station),
                                      ),
                                  ],
                                );
                              },
                            ),
                          if (query.trim().isNotEmpty && stations.isNotEmpty)
                            const SizedBox(height: 36),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (officialResultsQuery == null &&
                  !resolvingChargerResults &&
                  stations.isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    centeredPadding,
                    0,
                    centeredPadding,
                    36,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      width: contentWidth,
                      child: _EmptySearch(onReset: _resetFilters),
                    ),
                  ),
                )
              else if (officialResultsQuery == null &&
                  !resolvingChargerResults &&
                  query.trim().isEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    centeredPadding,
                    0,
                    centeredPadding,
                    36,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 580,
                      mainAxisExtent: 280,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final station = stations[index];
                        return buildStationCard(station);
                      },
                      childCount: stations.length,
                      addRepaintBoundaries: false,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _clearSearch() {
    searchController.clear();
    setState(() {
      query = '';
      selectedPlace = null;
      locationMessage = null;
      officialResultsQuery = null;
      officialResultsCenter = null;
    });
  }

  void _resetFilters() {
    searchController.clear();
    setState(() {
      query = '';
      selectedPlace = null;
      availableOnly = false;
      fastOnly = false;
      officialResultsQuery = null;
      officialResultsCenter = null;
    });
  }

  void _handleSearchChanged(String value) {
    setState(() {
      selectedPlace = null;
      query = value;
      officialResultsQuery = null;
      officialResultsCenter = null;
    });
  }

  void _openDetails(ChargingStation station) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailsScreen(station: station),
      ),
    );
  }

  Future<void> _selectLocation(PlaceSuggestion? place) async {
    if (place == null) {
      selectedPlace = null;
      return;
    }
    setState(() {
      query = place.displayName;
      selectedPlace = place;
      locationMessage = 'India location selected: ${place.primaryText}';
    });
    await _showChargerResults(preferredCenter: place);
  }

  Future<void> _showChargerResults({PlaceSuggestion? preferredCenter}) async {
    if (resolvingChargerResults) return;
    FocusScope.of(context).unfocus();
    final rawQuery = searchController.text.trim();
    if (rawQuery.isEmpty && preferredCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an India PIN code, city, or area first.'),
        ),
      );
      return;
    }
    setState(() => resolvingChargerResults = true);

    var center = preferredCenter ?? selectedPlace;
    if (center == null && rawQuery.isNotEmpty) {
      for (final station in sampleStations) {
        if (_matchesSearch(station, rawQuery)) {
          center = PlaceSuggestion(
            primaryText: station.name,
            secondaryText: station.formattedAddress,
            latitude: station.latitude,
            longitude: station.longitude,
            type: 'charging_station',
          );
          break;
        }
      }
      center ??= placeSearchService.localSuggestions(rawQuery).firstOrNull;
      if (center == null) {
        final remoteResults = await placeSearchService.searchIndia(rawQuery);
        center = remoteResults.firstOrNull;
      }
    }

    if (!mounted) return;
    setState(() => resolvingChargerResults = false);
    if (rawQuery.isNotEmpty && center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose an India location suggestion so nearby chargers can be found accurately.',
          ),
        ),
      );
      return;
    }
    setState(() {
      selectedPlace = center;
      officialResultsQuery = rawQuery.isEmpty ? center!.displayName : rawQuery;
      officialResultsCenter = center;
      locationMessage =
          'Showing chargers near ${center?.primaryText ?? rawQuery}';
    });
  }

  Future<void> _usePreviouslyAllowedLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        await _resolveCurrentLocation(requestPermission: false);
      }
    } catch (_) {
      // Search remains fully usable when geolocation is unsupported.
    }
  }

  Future<void> _resolveCurrentLocation({
    required bool requestPermission,
  }) async {
    if (locating) return;
    setState(() {
      locating = true;
      locationMessage = 'Finding your current area...';
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Turn on location services, then try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is off. Allow it to load your area automatically.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final place = await placeSearchService.reverseIndia(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      final displayName = place?.displayName ??
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}, India';
      final resolvedPlace = place ??
          PlaceSuggestion(
            primaryText: 'Current location',
            secondaryText: displayName,
            latitude: position.latitude,
            longitude: position.longitude,
            type: 'current_location',
          );
      searchController
        ..text = displayName
        ..selection = TextSelection.collapsed(offset: displayName.length);
      setState(() {
        query = displayName;
        selectedPlace = resolvedPlace;
        locating = false;
        locationMessage = place == null
            ? 'Using your current coordinates in India'
            : 'Near you: ${place.primaryText}';
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        locating = false;
        locationMessage = message;
      });
    }
  }
}

class _InlineSearchProgress extends StatelessWidget {
  const _InlineSearchProgress();

  @override
  Widget build(BuildContext context) {
    return const Card(
      key: Key('inlineChargerSearchProgress'),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('Finding official chargers nearby...')),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryHero extends StatelessWidget {
  const _DiscoveryHero({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.searchService,
    required this.onLocationSelected,
    required this.onUseLocation,
    required this.locating,
    required this.locationMessage,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final PlaceSearchService searchService;
  final ValueChanged<PlaceSuggestion?> onLocationSelected;
  final VoidCallback onUseLocation;
  final bool locating;
  final String? locationMessage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final availableConnectors = sampleStations.fold<int>(
      0,
      (total, station) => total + station.availableConnectors,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
            ),
            borderRadius: BorderRadius.circular(compact ? 26 : 34),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26071D17),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -90,
                top: -120,
                child: _GlowOrb(size: 310, color: Color(0x3320C77A)),
              ),
              const Positioned(
                right: 170,
                bottom: -110,
                child: _GlowOrb(size: 230, color: Color(0x20C8F45B)),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 22 : 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  AppTheme.brandGreen.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulseDot(),
                              SizedBox(width: 8),
                              Text(
                                'LIVE DEMO NETWORK',
                                style: TextStyle(
                                  color: Color(0xFFD8FFE9),
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.brandLime,
                                size: 17,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Across India',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('homeInstallAppButton'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const InstallAppScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.install_mobile_rounded,
                            color: AppTheme.brandLime,
                            size: 17,
                          ),
                          label: const Text(
                            'Install app',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 28 : 38),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        'Find the right charger, faster.',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: compact ? 34 : 52,
                                  letterSpacing: compact ? -1.1 : -1.8,
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'Search official charging-station records for any PIN code, city, state, or area across India. Results appear here instantly.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFB8CEC4),
                              fontSize: compact ? 15 : 17,
                            ),
                      ),
                    ),
                    SizedBox(height: compact ? 24 : 30),
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        const _HeroMetric(
                          value: '29,277',
                          label: 'verified public stations',
                        ),
                        _HeroMetric(
                          value: '${sampleStations.length}',
                          label: 'detailed demos',
                        ),
                        _HeroMetric(
                          value: '$availableConnectors',
                          label: 'demo connectors ready',
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 26 : 34),
                    Container(
                      padding: EdgeInsets.all(compact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: LocationAutocompleteField(
                        controller: searchController,
                        label: 'Search across India',
                        hint: 'Area, city, station, or 6-digit PIN',
                        prefixIcon: Icons.search_rounded,
                        textInputAction: TextInputAction.search,
                        searchService: searchService,
                        onChanged: onSearchChanged,
                        onSubmitted: onSearchSubmitted,
                        onSelected: onLocationSelected,
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (query.isNotEmpty)
                              IconButton(
                                tooltip: 'Clear search',
                                onPressed: onClear,
                                icon: const Icon(Icons.close),
                              ),
                            if (query.isNotEmpty)
                              IconButton(
                                key: const Key('submitChargerSearchButton'),
                                tooltip: 'Show charger results',
                                onPressed: () =>
                                    onSearchSubmitted(searchController.text),
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                            IconButton(
                              key: const Key('useCurrentLocationButton'),
                              tooltip: 'Use my current location',
                              onPressed: locating ? null : onUseLocation,
                              icon: locating
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        locationMessage ??
                            'Try 500079, Whitefield, or Tamil Nadu. Choose a suggestion or tap Search; charger results appear below.',
                        style: TextStyle(
                          color: locationMessage != null
                              ? AppTheme.brandLime
                              : const Color(0xFF9FB8AD),
                          fontSize: 11,
                          fontWeight: locationMessage != null
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NationalCoverageCard extends StatelessWidget {
  const _NationalCoverageCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = query.trim();
    final searchLabel = _compactLocationLabel(trimmedQuery);
    final matchingStates = trimmedQuery.isEmpty
        ? const <StateChargerCoverage>[]
        : stateChargerCoverage
            .where((coverage) => coverage.matches(trimmedQuery))
            .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'GOVERNMENT OF INDIA DATA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Updated $officialStationDataDate',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${_withCommas(officialStationTotal)} public charging stations',
                  key: const Key('officialStationTotal'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  matchingStates.isNotEmpty
                      ? '${matchingStates.first.state} has ${_withCommas(matchingStates.first.stationCount)} officially reported public stations. Use the search above to show individual chargers near “$searchLabel” on this page.'
                      : trimmedQuery.isEmpty
                          ? 'Verified totals cover every State and Union Territory. Search above to see official station records without leaving this page.'
                          : 'The bundled detailed catalog may not include “$searchLabel”. Tap the search arrow above to show official chargers for this PIN or area here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('allStateTotalsButton'),
                      onPressed: () => _showAllStateTotals(context),
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('View all state totals'),
                    ),
                    TextButton.icon(
                      onPressed: () => _openUrl(
                        context,
                        Uri.parse(evYatraUrl),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Official EV Yatra'),
                    ),
                  ],
                ),
              ],
            );

            if (compact) return content;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.brandLime, AppTheme.brandGreen],
                    ),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: AppTheme.brandNavy,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the external directory.')),
      );
    }
  }

  void _showAllStateTotals(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Official public stations by state'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_withCommas(officialStationTotal)} stations reported as of $officialStationDataDate.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: stateChargerCoverage.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final coverage = stateChargerCoverage[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(coverage.state),
                      trailing: Text(
                        _withCommas(coverage.stationCount),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openUrl(
              context,
              Uri.parse(officialStationSourceUrl),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('View official source'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

String _withCommas(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.availableOnly,
    required this.fastOnly,
    required this.onAvailableChanged,
    required this.onFastChanged,
  });

  final bool availableOnly;
  final bool fastOnly;
  final ValueChanged<bool> onAvailableChanged;
  final ValueChanged<bool> onFastChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Quick filters',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        FilterChip(
          selected: availableOnly,
          onSelected: onAvailableChanged,
          avatar: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Available now'),
        ),
        FilterChip(
          selected: fastOnly,
          onSelected: onFastChanged,
          avatar: const Icon(Icons.bolt_rounded, size: 18),
          label: const Text('100+ kW'),
        ),
        Chip(
          avatar: const Icon(Icons.tune_rounded, size: 17),
          label: const Text('45 detailed demos'),
          side: BorderSide.none,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.query});

  final int count;
  final String query;

  @override
  Widget build(BuildContext context) {
    final searchLabel = _compactLocationLabel(query);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                query.trim().isEmpty
                    ? 'Detailed VoltMapEV locations'
                    : 'Detailed demo matches',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                query.trim().isEmpty
                    ? 'Explore 45 bundled locations with full connector, price, and charging details'
                    : 'Bundled locations matching “$searchLabel”; use the live map above for community results near the area',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count ${count == 1 ? 'demo' : 'demos'}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}

bool _matchesSearch(ChargingStation station, String rawQuery) {
  final terms = rawQuery
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((term) => term.replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  if (terms.isEmpty) return true;

  final searchableText = [
    station.name,
    station.network,
    station.address,
    station.city,
    station.state,
    station.postalCode,
    ...station.connectorTypes,
    ...station.searchAliases,
  ].join(' ').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  return terms.every(searchableText.contains);
}

String _compactLocationLabel(String rawQuery) {
  final trimmed = rawQuery.trim();
  final pin = RegExp(r'\b\d{6}\b').firstMatch(trimmed)?.group(0);
  if (pin != null) return 'PIN $pin';
  final firstSegment = trimmed.split(',').first.trim();
  if (firstSegment.length <= 40) return firstSegment;
  return '${firstSegment.substring(0, 37)}…';
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(38),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              'No demo stations match that search',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Try another city, state, area, or PIN code. The bundled catalog is representative and does not yet include every charger in India.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppTheme.brandGreen,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppTheme.brandGreen, blurRadius: 7)],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.brandLime,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFACC2B8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
