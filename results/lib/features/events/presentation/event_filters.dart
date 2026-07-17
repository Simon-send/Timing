import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:results/l10n/app_localizations.dart';

import '../../../app/app_theme.dart';
import '../domain/result_event.dart';

@immutable
class EventFilterCriteria {
  const EventFilterCriteria({
    this.country = '',
    this.sport = '',
    this.discipline = '',
    this.county = '',
    this.area = '',
    this.dateFrom,
    this.dateTo,
    this.participantsFrom,
    this.participantsTo,
    this.ageFrom,
    this.ageTo,
  });

  final String country;
  final String sport;
  final String discipline;
  final String county;
  final String area;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int? participantsFrom;
  final int? participantsTo;
  final int? ageFrom;
  final int? ageTo;

  int get activeCount {
    var count = 0;
    if (country.isNotEmpty) count++;
    if (sport.isNotEmpty) count++;
    if (discipline.isNotEmpty) count++;
    if (county.isNotEmpty) count++;
    if (area.trim().isNotEmpty) count++;
    if (dateFrom != null || dateTo != null) count++;
    if (participantsFrom != null || participantsTo != null) count++;
    if (ageFrom != null || ageTo != null) count++;
    return count;
  }

  bool matches(ResultEvent event, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      final searchable = [
        event.name,
        event.sportName,
        event.place,
        event.country,
        event.county,
        event.area,
        event.id,
        ...event.disciplines,
      ].join(' ').toLowerCase();
      if (!searchable.contains(query)) return false;
    }

    if (!_sameOrUnselected(country, event.country) ||
        !_sameOrUnselected(sport, event.sportName) ||
        !_sameOrUnselected(county, event.county)) {
      return false;
    }
    if (discipline.isNotEmpty &&
        !event.disciplines.any(
          (value) => value.toLowerCase() == discipline.toLowerCase(),
        )) {
      return false;
    }

    final areaQuery = area.trim().toLowerCase();
    if (areaQuery.isNotEmpty &&
        ![
          event.place,
          event.county,
          event.area,
        ].join(' ').toLowerCase().contains(areaQuery)) {
      return false;
    }

    if (dateFrom != null || dateTo != null) {
      final date = event.date;
      if (date == null) return false;
      final day = DateUtils.dateOnly(date);
      if (dateFrom != null && day.isBefore(DateUtils.dateOnly(dateFrom!))) {
        return false;
      }
      if (dateTo != null && day.isAfter(DateUtils.dateOnly(dateTo!))) {
        return false;
      }
    }

    if (!_numberInRange(
      event.participantCount,
      participantsFrom,
      participantsTo,
    )) {
      return false;
    }

    if (ageFrom != null || ageTo != null) {
      final eventAgeFrom = event.ageFrom ?? event.ageTo;
      final eventAgeTo = event.ageTo ?? event.ageFrom;
      if (eventAgeFrom == null || eventAgeTo == null) return false;
      if (ageFrom != null && eventAgeTo < ageFrom!) return false;
      if (ageTo != null && eventAgeFrom > ageTo!) return false;
    }

    return true;
  }

  EventFilterCriteria copyWith({
    String? country,
    String? sport,
    String? discipline,
    String? county,
    String? area,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDates = false,
    int? participantsFrom,
    int? participantsTo,
    bool clearParticipantsFrom = false,
    bool clearParticipantsTo = false,
    int? ageFrom,
    int? ageTo,
    bool clearAgeFrom = false,
    bool clearAgeTo = false,
  }) {
    return EventFilterCriteria(
      country: country ?? this.country,
      sport: sport ?? this.sport,
      discipline: discipline ?? this.discipline,
      county: county ?? this.county,
      area: area ?? this.area,
      dateFrom: clearDates ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDates ? null : dateTo ?? this.dateTo,
      participantsFrom: clearParticipantsFrom
          ? null
          : participantsFrom ?? this.participantsFrom,
      participantsTo: clearParticipantsTo
          ? null
          : participantsTo ?? this.participantsTo,
      ageFrom: clearAgeFrom ? null : ageFrom ?? this.ageFrom,
      ageTo: clearAgeTo ? null : ageTo ?? this.ageTo,
    );
  }
}

class EventFilterOptions {
  const EventFilterOptions({
    required this.countries,
    required this.sports,
    required this.disciplines,
    required this.counties,
  });

  factory EventFilterOptions.fromEvents(List<ResultEvent> events) {
    return EventFilterOptions(
      countries: _options(events.map((event) => event.country)),
      sports: _options(events.map((event) => event.sportName)),
      disciplines: _options(events.expand((event) => event.disciplines)),
      counties: _options(events.map((event) => event.county)),
    );
  }

  final List<String> countries;
  final List<String> sports;
  final List<String> disciplines;
  final List<String> counties;
}

class EventFilters extends StatefulWidget {
  const EventFilters({
    super.key,
    required this.controller,
    required this.criteria,
    required this.options,
    required this.filteredCount,
    required this.totalCount,
    required this.onChanged,
    required this.onReset,
  });

  final TextEditingController controller;
  final EventFilterCriteria criteria;
  final EventFilterOptions options;
  final int filteredCount;
  final int totalCount;
  final ValueChanged<EventFilterCriteria> onChanged;
  final VoidCallback onReset;

  @override
  State<EventFilters> createState() => _EventFiltersState();
}

class _EventFiltersState extends State<EventFilters> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _FilterText.of(context);
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('event-search-field'),
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: l10n.searchEvents,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: text.clearSearch,
                    onPressed: widget.controller.clear,
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelAlt,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: palette.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.criteria.activeCount == 0
                            ? text.filters
                            : '${text.filters} (${widget.criteria.activeCount})',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (widget.criteria.activeCount > 0 ||
                        widget.controller.text.isNotEmpty)
                      TextButton.icon(
                        key: const Key('event-filters-reset'),
                        onPressed: widget.onReset,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(text.reset),
                      ),
                    IconButton(
                      tooltip: _expanded ? text.collapse : text.expand,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _expanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _FilterSelect(
                              key: const Key('event-filter-country'),
                              label: text.country,
                              value: widget.criteria.country,
                              options: widget.options.countries,
                              onChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(country: value),
                              ),
                            ),
                            _FilterSelect(
                              key: const Key('event-filter-sport'),
                              label: l10n.sport,
                              value: widget.criteria.sport,
                              options: widget.options.sports,
                              onChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(sport: value),
                              ),
                            ),
                            _FilterSelect(
                              key: const Key('event-filter-discipline'),
                              label: text.discipline,
                              value: widget.criteria.discipline,
                              options: widget.options.disciplines,
                              onChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(discipline: value),
                              ),
                            ),
                            _FilterSelect(
                              key: const Key('event-filter-county'),
                              label: text.county,
                              value: widget.criteria.county,
                              options: widget.options.counties,
                              onChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(county: value),
                              ),
                            ),
                            _AreaField(
                              value: widget.criteria.area,
                              label: text.area,
                              onChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(area: value),
                              ),
                            ),
                            _DateFilter(
                              from: widget.criteria.dateFrom,
                              to: widget.criteria.dateTo,
                              label: text.dateInterval,
                              allDates: text.allDates,
                              clearLabel: text.clear,
                              onChanged: (range) => widget.onChanged(
                                range == null
                                    ? widget.criteria.copyWith(clearDates: true)
                                    : widget.criteria.copyWith(
                                        dateFrom: range.start,
                                        dateTo: range.end,
                                      ),
                              ),
                            ),
                            _RangeFilter(
                              key: const Key('event-filter-participants'),
                              label: text.participants,
                              from: widget.criteria.participantsFrom,
                              to: widget.criteria.participantsTo,
                              fromLabel: text.minimum,
                              toLabel: text.maximum,
                              onFromChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(
                                  participantsFrom: value,
                                  clearParticipantsFrom: value == null,
                                ),
                              ),
                              onToChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(
                                  participantsTo: value,
                                  clearParticipantsTo: value == null,
                                ),
                              ),
                            ),
                            _RangeFilter(
                              key: const Key('event-filter-age'),
                              label: text.age,
                              from: widget.criteria.ageFrom,
                              to: widget.criteria.ageTo,
                              fromLabel: text.from,
                              toLabel: text.to,
                              onFromChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(
                                  ageFrom: value,
                                  clearAgeFrom: value == null,
                                ),
                              ),
                              onToChanged: (value) => widget.onChanged(
                                widget.criteria.copyWith(
                                  ageTo: value,
                                  clearAgeTo: value == null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text.showing(widget.filteredCount, widget.totalCount),
          key: const Key('event-filter-count'),
          style: TextStyle(
            color: palette.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = _FilterText.of(context);
    return SizedBox(
      width: 205,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: '', child: Text(text.all)),
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (selected) => onChanged(selected ?? ''),
          ),
        ),
      ),
    );
  }
}

class _AreaField extends StatefulWidget {
  const _AreaField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_AreaField> createState() => _AreaFieldState();
}

class _AreaFieldState extends State<_AreaField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _AreaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: TextField(
        key: const Key('event-filter-area'),
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        ),
      ),
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.from,
    required this.to,
    required this.label,
    required this.allDates,
    required this.clearLabel,
    required this.onChanged,
  });

  final DateTime? from;
  final DateTime? to;
  final String label;
  final String allDates;
  final String clearLabel;
  final ValueChanged<DateTimeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final hasRange = from != null || to != null;
    final rangeStart = from ?? to;
    final rangeEnd = to ?? from;
    final value = hasRange
        ? '${localizations.formatShortDate(rangeStart!)} – '
              '${localizations.formatShortDate(rangeEnd!)}'
        : allDates;
    return SizedBox(
      key: const Key('event-filter-date'),
      width: 205,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            const Icon(Icons.date_range_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _pick(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            if (hasRange)
              InkWell(
                onTap: () => onChanged(null),
                child: Tooltip(
                  message: clearLabel,
                  child: const Icon(Icons.close, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5, 12, 31),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from!, end: to!)
          : null,
    );
    if (result != null) onChanged(result);
  }
}

class _RangeFilter extends StatefulWidget {
  const _RangeFilter({
    super.key,
    required this.label,
    required this.from,
    required this.to,
    required this.fromLabel,
    required this.toLabel,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final String label;
  final int? from;
  final int? to;
  final String fromLabel;
  final String toLabel;
  final ValueChanged<int?> onFromChanged;
  final ValueChanged<int?> onToChanged;

  @override
  State<_RangeFilter> createState() => _RangeFilterState();
}

class _RangeFilterState extends State<_RangeFilter> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(
      text: widget.from?.toString() ?? '',
    );
    _toController = TextEditingController(text: widget.to?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _RangeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_fromController, widget.from);
    _sync(_toController, widget.to);
  }

  void _sync(TextEditingController controller, int? value) {
    final text = value?.toString() ?? '';
    if (controller.text != text) controller.text = text;
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _fromController,
                  label: widget.fromLabel,
                  onChanged: widget.onFromChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Text('–'),
              ),
              Expanded(
                child: _NumberField(
                  controller: _toController,
                  label: widget.toLabel,
                  onChanged: widget.onToChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) => onChanged(int.tryParse(value)),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

bool _sameOrUnselected(String selected, String actual) {
  return selected.isEmpty || selected.toLowerCase() == actual.toLowerCase();
}

bool _numberInRange(int? value, int? from, int? to) {
  if (from == null && to == null) return true;
  if (value == null) return false;
  return (from == null || value >= from) && (to == null || value <= to);
}

List<String> _options(Iterable<String> values) {
  final normalized = <String, String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && trimmed != 'Ukjent idrett') {
      normalized.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }
  }
  final result = normalized.values.toList();
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

class _FilterText {
  const _FilterText({required this.norwegian});

  factory _FilterText.of(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return _FilterText(norwegian: language == 'nb' || language == 'no');
  }

  final bool norwegian;

  String get filters => norwegian ? 'Filtrer events' : 'Filter events';
  String get reset => norwegian ? 'Nullstill' : 'Reset';
  String get country => norwegian ? 'Land' : 'Country';
  String get discipline => norwegian ? 'Disiplin' : 'Discipline';
  String get county => norwegian ? 'Fylke / region' : 'County / region';
  String get area =>
      norwegian ? 'Sted, kommune eller område' : 'Place, municipality or area';
  String get dateInterval => norwegian ? 'Kalenderintervall' : 'Date range';
  String get participants => norwegian ? 'Antall deltakere' : 'Participants';
  String get age => norwegian ? 'Alder' : 'Age';
  String get minimum => 'Min.';
  String get maximum => 'Maks.';
  String get from => norwegian ? 'Fra' : 'From';
  String get to => norwegian ? 'Til' : 'To';
  String get all => norwegian ? 'Alle' : 'All';
  String get allDates => norwegian ? 'Alle datoer' : 'All dates';
  String get clear => norwegian ? 'Fjern' : 'Clear';
  String get clearSearch => norwegian ? 'Tøm søk' : 'Clear search';
  String get collapse => norwegian ? 'Skjul filtre' : 'Hide filters';
  String get expand => norwegian ? 'Vis filtre' : 'Show filters';

  String showing(int filtered, int total) => norwegian
      ? 'Viser $filtered av $total events'
      : 'Showing $filtered of $total events';
}
