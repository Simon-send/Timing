import 'package:flutter/material.dart';
import 'package:results/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/presentation/account_menu.dart';
import '../../results/domain/result_sort_mode.dart';
import '../../settings/presentation/settings_menu.dart';
import '../domain/result_event.dart';
import 'event_card.dart';
import 'event_filters.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(eventsProvider);
    final participatedEventIds = ref.watch(participatedEventIdsProvider);
    return AppShell(
      title: l10n.appTitle,
      subtitle: l10n.eventsSubtitle,
      actions: const [AccountMenu(), SettingsMenu()],
      child: ShellPanel(
        child: events.when(
          loading: () => LoadingState(label: l10n.loadingEvents),
          error: (error, _) => ErrorState(
            title: l10n.couldNotReadEvents,
            error: error,
            onRetry: () => refreshAppData(ref),
          ),
          data: (events) {
            if (events.isEmpty) {
              return EmptyState(
                title: l10n.noEventsTitle,
                message: l10n.noEventsMessage,
              );
            }
            return _EventGrid(
              events: events,
              participatedEventIds: participatedEventIds,
              searchController: _searchController,
              onEventTap: (event) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDefaultEvent(event.id);
                ref.read(resultSortModeProvider(event.id).notifier).state =
                    ResultSortMode.cumulative;
                context.go('/events/${event.id}/results');
              },
            );
          },
        ),
      ),
    );
  }
}

class _EventGrid extends StatefulWidget {
  const _EventGrid({
    required this.events,
    required this.participatedEventIds,
    required this.searchController,
    required this.onEventTap,
  });

  final List<ResultEvent> events;
  final Set<String> participatedEventIds;
  final TextEditingController searchController;
  final ValueChanged<ResultEvent> onEventTap;

  @override
  State<_EventGrid> createState() => _EventGridState();
}

class _EventGridState extends State<_EventGrid> {
  EventFilterCriteria _criteria = const EventFilterCriteria();

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant _EventGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController == widget.searchController) return;
    oldWidget.searchController.removeListener(_onSearchChanged);
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEvents();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        return SingleChildScrollView(
          key: const Key('events-page-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EventFilters(
                controller: widget.searchController,
                criteria: _criteria,
                options: EventFilterOptions.fromEvents(widget.events),
                filteredCount: filtered.length,
                totalCount: widget.events.length,
                onChanged: (criteria) => setState(() => _criteria = criteria),
                onReset: () {
                  widget.searchController.clear();
                  setState(() => _criteria = const EventFilterCriteria());
                },
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const SizedBox(height: 280, child: _NoFilteredEvents())
              else
                GridView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: columns == 1 ? 210 : null,
                    childAspectRatio: columns == 1 ? 1 : 1.7,
                  ),
                  itemBuilder: (context, index) {
                    final event = filtered[index];
                    return EventCard(
                      event: event,
                      participated: widget.participatedEventIds.contains(
                        event.id,
                      ),
                      onTap: () => widget.onEventTap(event),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<ResultEvent> _filteredEvents() {
    return widget.events
        .where(
          (event) => _criteria.matches(event, widget.searchController.text),
        )
        .toList();
  }

  void _onSearchChanged() {
    setState(() {});
  }
}

class _NoFilteredEvents extends StatelessWidget {
  const _NoFilteredEvents();

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final norwegian = language == 'nb' || language == 'no';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined, size: 38),
            const SizedBox(height: 10),
            Text(
              norwegian
                  ? 'Ingen events passer filtrene'
                  : 'No events match the filters',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              norwegian
                  ? 'Juster eller nullstill filtrene for å se flere.'
                  : 'Adjust or reset the filters to see more.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
