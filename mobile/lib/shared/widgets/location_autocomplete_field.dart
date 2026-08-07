import 'dart:async';

import 'package:flutter/material.dart';

import '../models/place_suggestion.dart';
import '../services/place_search_service.dart';

class LocationAutocompleteField extends StatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.searchService,
    required this.onSelected,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final PlaceSearchService searchService;
  final ValueChanged<PlaceSuggestion?> onSelected;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  Timer? _closeTimer;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _showSuggestions = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _closeTimer?.cancel();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canShow = _showSuggestions &&
        widget.controller.text.trim().length >= 2 &&
        (_suggestions.isNotEmpty || _searching);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('locationField_${widget.label}'),
          controller: widget.controller,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction,
          onChanged: _search,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.suffixIcon,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: canShow
              ? Container(
                  key: const Key('locationSuggestions'),
                  constraints: const BoxConstraints(maxHeight: 310),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        for (final suggestion in _suggestions)
                          ListTile(
                            key: ValueKey('place_${suggestion.identity}'),
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              child: Icon(
                                _iconForType(suggestion.type),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              suggestion.primaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              suggestion.secondaryText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _select(suggestion),
                          ),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                            child: Text(
                              'Searching more places across India…',
                              style: TextStyle(fontSize: 11),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                            child: Row(
                              children: [
                                Icon(Icons.public_rounded, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'India-wide results • OpenStreetMap / Photon',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _handleFocusChange() {
    _closeTimer?.cancel();
    if (_focusNode.hasFocus) {
      if (mounted) setState(() => _showSuggestions = true);
      final value = widget.controller.text;
      if (value.trim().length >= 2) _search(value);
      return;
    }
    _debounce?.cancel();
    _requestId++;
    if (_searching && mounted) setState(() => _searching = false);
    _closeTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted && !_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  void _search(String value) {
    widget.onChanged?.call(value);
    widget.onSelected(null);
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }

    final local = widget.searchService.localSuggestions(query);
    final requestId = ++_requestId;
    setState(() {
      _suggestions = local;
      _searching = query.length >= 3;
      _showSuggestions = true;
    });
    if (query.length < 3) return;

    _debounce = Timer(const Duration(milliseconds: 420), () async {
      final results = await widget.searchService.searchIndia(query);
      if (!mounted ||
          requestId != _requestId ||
          widget.controller.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _select(PlaceSuggestion suggestion) {
    _debounce?.cancel();
    widget.controller
      ..text = suggestion.displayName
      ..selection = TextSelection.collapsed(
        offset: suggestion.displayName.length,
      );
    widget.onSelected(suggestion);
    setState(() {
      _suggestions = const [];
      _searching = false;
      _showSuggestions = false;
    });
    _focusNode.unfocus();
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'city' || 'town' || 'village' => Icons.location_city_rounded,
      'house' => Icons.home_work_outlined,
      'street' => Icons.add_road_rounded,
      _ => Icons.place_outlined,
    };
  }
}
