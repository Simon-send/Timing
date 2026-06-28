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
    return AppShell(
      title: l10n.appTitle,
      subtitle: l10n.eventsSubtitle,
      actions: const [AccountMenu(), SettingsMenu()],
      child: ShellPanel(
        child: events.when(
          loading: () => LoadingState(label: l10n.loadingEvents),
          error: (error, _) =>
              ErrorState(title: l10n.couldNotReadEvents, error: error),
          data: (events) {
            if (events.isEmpty) {
              return EmptyState(
                title: l10n.noEventsTitle,
                message: l10n.noEventsMessage,
              );
            }
            return _EventGrid(
              events: events,
              searchController: _searchController,
              onEventTap: (event) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDefaultEvent(event.id);
                ref.read(resultSortModeProvider(event.id).notifier).state =
                    ResultSortMode.cumulative;
                ref.read(splitRangeSelectionProvider.notifier).state = null;
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
    required this.searchController,
    required this.onEventTap,
  });

  final List<ResultEvent> events;
  final TextEditingController searchController;
  final ValueChanged<ResultEvent> onEventTap;

  @override
  State<_EventGrid> createState() => _EventGridState();
}

class _EventGridState extends State<_EventGrid> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventFilters(controller: widget.searchController),
        const SizedBox(height: 14),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1080
                  ? 3
                  : constraints.maxWidth >= 700
                  ? 2
                  : 1;
              return GridView.builder(
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 2.4 : 1.7,
                ),
                itemBuilder: (context, index) {
                  final event = filtered[index];
                  return EventCard(
                    event: event,
                    onTap: () => widget.onEventTap(event),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<ResultEvent> _filteredEvents() {
    final query = widget.searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.events;
    return widget.events.where((event) {
      return event.name.toLowerCase().contains(query) ||
          event.sportName.toLowerCase().contains(query) ||
          event.place.toLowerCase().contains(query) ||
          event.id.toLowerCase().contains(query);
    }).toList();
  }

  void _onSearchChanged() {
    setState(() {});
  }
}
