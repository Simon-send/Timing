import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/account_menu.dart';
import '../../auth/presentation/login_button.dart';
import '../../events/domain/result_event.dart';
import '../../results/presentation/result_locations.dart';
import '../../settings/presentation/settings_menu.dart';
import '../data/athlete_profile_repository.dart';
import '../domain/athlete_profile.dart';
import 'biathlon_comparison_panel.dart';
import 'race_pacing_profile_panel.dart';
import 'result_history_panel.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;

    return AppShell(
      title: 'Min side',
      subtitle: user?.email ?? user?.displayName ?? 'Koble konto til utøver',
      leading: IconButton.outlined(
        tooltip: 'Til løp',
        onPressed: () => context.go('/events'),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: const [AccountMenu(), SettingsMenu()],
      child: authState.when(
        loading: () =>
            const ShellPanel(child: LoadingState(label: 'Sjekker innlogging')),
        error: (error, _) => ShellPanel(
          child: ErrorState(
            title: 'Kunne ikke lese konto',
            error: error,
            onRetry: () => refreshAppData(ref),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const ShellPanel(child: _SignedOutPanel());
          }
          return _LoggedInMeContent(user: user);
        },
      ),
    );
  }
}

class _LoggedInMeContent extends ConsumerWidget {
  const _LoggedInMeContent({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedAthleteId = ref.watch(linkedAthleteIdProvider);
    return linkedAthleteId.when(
      skipLoadingOnReload: true,
      loading: () =>
          const ShellPanel(child: LoadingState(label: 'Laster utøverkobling')),
      error: (error, _) => ShellPanel(
        child: ErrorState(
          title: 'Kunne ikke lese utøverkobling',
          error: athleteProfileErrorMessage(error),
          onRetry: () => refreshAppData(ref),
        ),
      ),
      data: (athleteId) {
        if (athleteId == null) {
          return ShellPanel(child: AthleteConnectPanel(uid: user.uid));
        }

        final profile = ref.watch(athleteProfileProvider(athleteId));
        return profile.when(
          skipLoadingOnReload: true,
          loading: () =>
              const ShellPanel(child: LoadingState(label: 'Laster utøver')),
          error: (error, _) => ShellPanel(
            child: ErrorState(
              title: 'Kunne ikke lese utøver',
              error: athleteProfileErrorMessage(error),
              onRetry: () => refreshAppData(ref),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return ShellPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InlineNotice(
                      icon: Icons.info_outline,
                      text:
                          'Koblingen peker på $athleteId, men utøveren finnes ikke i databasen.',
                    ),
                    const SizedBox(height: 18),
                    AthleteConnectPanel(uid: user.uid),
                  ],
                ),
              );
            }

            final races = ref.watch(athleteRacesProvider(profile.athleteId));
            final affiliations = ref.watch(
              athleteAffiliationsProvider((
                clubId: profile.primaryClubId,
                teamId: profile.primaryTeamId,
              )),
            );
            final events = ref.watch(eventsProvider).asData?.value ?? const [];
            return _LinkedAthleteContent(
              user: user,
              profile: profile,
              races: races,
              affiliations: affiliations,
              events: events,
            );
          },
        );
      },
    );
  }
}

class _SignedOutPanel extends StatelessWidget {
  const _SignedOutPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            EmptyState(
              title: 'Logg inn for å bruke Min side',
              message:
                  'Når du er innlogget kan du koble kontoen til en utøver og se løpene dine.',
            ),
            SizedBox(height: 18),
            LoginButton(),
          ],
        ),
      ),
    );
  }
}

class _LinkedAthleteContent extends ConsumerWidget {
  const _LinkedAthleteContent({
    required this.user,
    required this.profile,
    required this.races,
    required this.affiliations,
    required this.events,
  });

  final User user;
  final AthleteProfile profile;
  final AsyncValue<List<AthleteRace>> races;
  final AsyncValue<AthleteAffiliations> affiliations;
  final List<ResultEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raceData = races.asData?.value ?? const <AthleteRace>[];
    final affiliationData = affiliations.asData?.value;
    final clubName = _firstNonEmpty([
      affiliationData?.clubName,
      for (final race in raceData) race.clubName,
    ]);
    final teamName = _firstNonEmpty([
      affiliationData?.teamName,
      for (final race in raceData) race.teamName,
    ]);

    return SingleChildScrollView(
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellPanel(
            child: _ProfileHeader(
              profile: profile,
              clubName: clubName,
              teamName: teamName,
              raceCount: raceData.length,
              loadingAffiliations:
                  affiliations.isLoading && affiliationData == null,
              onSwitchAthlete: () => _showSwitchAthleteDialog(context),
              onClearLink: () => _clearAthleteLink(context, ref),
            ),
          ),
          const SizedBox(height: 14),
          races.when(
            skipLoadingOnReload: true,
            loading: () => const ShellPanel(
              child: SizedBox(
                height: 220,
                child: LoadingState(label: 'Laster løp'),
              ),
            ),
            error: (error, _) => ShellPanel(
              child: SizedBox(
                height: 260,
                child: ErrorState(
                  title: 'Kunne ikke lese løp',
                  error: athleteProfileErrorMessage(error),
                  onRetry: () => refreshAppData(ref),
                ),
              ),
            ),
            data: (races) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (races.isNotEmpty) ...[
                  ShellPanel(
                    child: ResultHistoryPanel(
                      entries: _historyEntries(profile, races, events),
                      onEntryTap: (entry) {
                        if (entry.eventId.isEmpty ||
                            entry.classId.isEmpty ||
                            entry.resultId.isEmpty) {
                          return;
                        }
                        context.go(
                          athleteLocation(
                            eventId: entry.eventId,
                            classId: entry.classId,
                            resultId: entry.resultId,
                            stageId: entry.stageId,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (races.any(
                    (race) => race.isCompletedIndividualBiathlonRace,
                  )) ...[
                    ShellPanel(
                      child: BiathlonComparisonPanel(
                        races: races,
                        events: events,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ShellPanel(child: RacePacingProfilePanel(races: races)),
                  const SizedBox(height: 14),
                ],
                ShellPanel(
                  child: _RaceList(
                    profile: profile,
                    races: races,
                    events: events,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSwitchAthleteDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Koble til utøver'),
        content: SizedBox(
          width: 520,
          child: AthleteConnectPanel(
            uid: user.uid,
            showTitle: false,
            onLinked: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _clearAthleteLink(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fjern utøverkobling?'),
        content: Text(
          'Dette fjerner koblingen mellom kontoen din og ${profile.displayName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Fjern'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(athleteProfileRepositoryProvider)
          .clearLinkedAthlete(user.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utøverkoblingen ble fjernet')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(athleteProfileErrorMessage(error))),
      );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.clubName,
    required this.teamName,
    required this.raceCount,
    required this.loadingAffiliations,
    required this.onSwitchAthlete,
    required this.onClearLink,
  });

  final AthleteProfile profile;
  final String? clubName;
  final String? teamName;
  final int raceCount;
  final bool loadingAffiliations;
  final VoidCallback onSwitchAthlete;
  final VoidCallback onClearLink;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final affiliationFallback = loadingAffiliations ? 'Laster...' : '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                profile.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onSwitchAthlete,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Bytt utøver'),
                ),
                TextButton.icon(
                  onPressed: onClearLink,
                  icon: Icon(Icons.link_off, color: palette.danger),
                  label: Text(
                    'Fjern kobling',
                    style: TextStyle(color: palette.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ProfileFact(
              icon: Icons.badge_outlined,
              label: 'Athlete ID',
              value: profile.athleteId,
            ),
            _ProfileFact(
              icon: Icons.groups_outlined,
              label: 'Klubb',
              value: clubName ?? affiliationFallback,
            ),
            _ProfileFact(
              icon: Icons.flag_outlined,
              label: 'Team',
              value: teamName ?? affiliationFallback,
            ),
            _ProfileFact(
              icon: Icons.timer_outlined,
              label: 'Løp',
              value: '$raceCount',
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceList extends StatelessWidget {
  const _RaceList({
    required this.profile,
    required this.races,
    required this.events,
  });

  final AthleteProfile profile;
  final List<AthleteRace> races;
  final List<ResultEvent> events;

  @override
  Widget build(BuildContext context) {
    if (races.isEmpty) {
      return const SizedBox(
        height: 260,
        child: EmptyState(
          title: 'Ingen løp funnet',
          message: 'Når resultatene har athlete ID på deg, vises de her.',
        ),
      );
    }

    final displayedRaces = _displayedRaces(profile, races, events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Løp du har gått',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < displayedRaces.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _RaceTile(displayedRace: displayedRaces[index]),
        ],
      ],
    );
  }
}

class _RaceTile extends StatelessWidget {
  const _RaceTile({required this.displayedRace});

  final _DisplayedRace displayedRace;

  @override
  Widget build(BuildContext context) {
    final race = displayedRace.race;
    final palette = context.palette;
    final canOpen =
        race.eventId.isNotEmpty &&
        race.classId.isNotEmpty &&
        race.resultId.isNotEmpty;

    return Material(
      color: palette.panelAlt,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: canOpen
            ? () => context.go(
                athleteLocation(
                  eventId: race.eventId,
                  classId: race.classId,
                  resultId: race.resultId,
                  stageId: race.stageId,
                ),
              )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timer_outlined, color: palette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayedRace.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayedRace.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _RaceFact(label: 'Plass', value: race.placementLabel),
                        _RaceFact(
                          label: 'Tid',
                          value: race.totalText.isEmpty ? '-' : race.totalText,
                        ),
                        _RaceFact(
                          label: 'Startnr.',
                          value: race.bib.isEmpty ? '-' : race.bib,
                        ),
                        if (race.shooting.isNotEmpty)
                          _RaceFact(label: 'Skyting', value: race.shooting),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: palette.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaceFact extends StatelessWidget {
  const _RaceFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: palette.mutedText, fontWeight: FontWeight.w600),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class AthleteConnectPanel extends ConsumerStatefulWidget {
  const AthleteConnectPanel({
    super.key,
    required this.uid,
    this.initialName = '',
    this.showTitle = true,
    this.allowSkip = false,
    this.onLinked,
    this.onSkipped,
  });

  final String uid;
  final String initialName;
  final bool showTitle;
  final bool allowSkip;
  final VoidCallback? onLinked;
  final VoidCallback? onSkipped;

  @override
  ConsumerState<AthleteConnectPanel> createState() =>
      _AthleteConnectPanelState();
}

class _AthleteConnectPanelState extends ConsumerState<AthleteConnectPanel> {
  late final TextEditingController _nameController;
  var _isSearching = false;
  var _hasSearched = false;
  String? _error;
  String? _linkingAthleteId;
  List<AthleteProfile> _matches = const [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text(
            l10n.connectAthlete,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.connectAthleteDescription,
            style: TextStyle(color: palette.mutedText),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: l10n.fullName,
            prefixIcon: const Icon(Icons.search),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _isSearching ? null : _search,
            icon: const Icon(Icons.search),
            label: Text(l10n.findAthlete),
          ),
        ),
        if (_isSearching) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          _InlineNotice(icon: Icons.error_outline, text: _error!, danger: true),
        ],
        if (_hasSearched && !_isSearching && _matches.isEmpty) ...[
          const SizedBox(height: 14),
          _InlineNotice(icon: Icons.search_off, text: l10n.noAthleteMatches),
        ],
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var index = 0; index < _matches.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _AthleteMatchTile(
              athlete: _matches[index],
              isLinking: _linkingAthleteId == _matches[index].athleteId,
              onLink: () => _linkAthlete(_matches[index]),
            ),
          ],
        ],
        if (widget.allowSkip) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isSearching || _linkingAthleteId != null
                ? null
                : _skipForNow,
            child: Text(l10n.notNow),
          ),
        ],
      ],
    );
  }

  Future<void> _search() async {
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context).enterFullName;
        _matches = const [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = false;
      _error = null;
    });

    try {
      final matches = await ref
          .read(athleteProfileRepositoryProvider)
          .searchAthletesByFullName(query);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _hasSearched = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = athleteProfileErrorMessage(error);
        _matches = const [];
        _hasSearched = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _linkAthlete(AthleteProfile athlete) async {
    setState(() {
      _linkingAthleteId = athlete.athleteId;
      _error = null;
    });

    try {
      await ref
          .read(athleteProfileRepositoryProvider)
          .linkAthlete(uid: widget.uid, athlete: athlete);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).athleteLinked(athlete.displayName),
          ),
        ),
      );
      widget.onLinked?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = athleteProfileErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _linkingAthleteId = null);
      }
    }
  }

  Future<void> _skipForNow() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      await ref
          .read(athleteProfileRepositoryProvider)
          .completeAthleteLinkOnboarding(widget.uid);
      if (!mounted) return;
      widget.onSkipped?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = athleteProfileErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }
}

class _AthleteMatchTile extends StatelessWidget {
  const _AthleteMatchTile({
    required this.athlete,
    required this.isLinking,
    required this.onLink,
  });

  final AthleteProfile athlete;
  final bool isLinking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  athlete.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${athlete.athleteId} - ${athlete.events.length} løp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: isLinking ? null : onLink,
            child: isLinking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context).connectAthlete),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = danger ? palette.danger : palette.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayedRace {
  const _DisplayedRace({
    required this.race,
    required this.eventName,
    required this.subtitle,
    required this.eventDate,
  });

  final AthleteRace race;
  final String eventName;
  final String subtitle;
  final DateTime? eventDate;
}

List<_DisplayedRace> _displayedRaces(
  AthleteProfile profile,
  List<AthleteRace> races,
  List<ResultEvent> events,
) {
  final eventsById = {for (final event in events) event.id: event};
  final athleteEventsByKey = {
    for (final event in profile.events) event.key: event,
  };

  final displayed = [
    for (final race in races)
      () {
        final event = eventsById[race.eventId];
        final athleteEvent =
            athleteEventsByKey[race.key] ??
            _athleteEventForEvent(profile, race.eventId);
        final eventName = _firstNonEmpty([
          event?.name,
          athleteEvent?.name,
          'Event ${race.eventId}',
        ])!;
        final className = _firstNonEmpty([
          race.className,
          athleteEvent?.className,
          race.classId.isEmpty ? null : 'Klasse ${race.classId}',
        ]);
        final dateLabel = _firstNonEmpty([event?.dateLabel]);
        final subtitleParts = [
          ?className,
          ?dateLabel,
          'Event ID ${race.eventId}',
        ];
        return _DisplayedRace(
          race: race,
          eventName: eventName,
          subtitle: subtitleParts.join(' - '),
          eventDate: event?.date,
        );
      }(),
  ]..sort(_compareDisplayedRaces);

  return displayed;
}

List<ResultHistoryEntry> _historyEntries(
  AthleteProfile profile,
  List<AthleteRace> races,
  List<ResultEvent> events,
) {
  return [
    for (final displayed in _displayedRaces(profile, races, events).reversed)
      if ((displayed.race.finishRank ?? displayed.race.rank ?? 0) > 0)
        ResultHistoryEntry(
          eventId: displayed.race.eventId,
          classId: displayed.race.classId,
          resultId: displayed.race.resultId,
          stageId: displayed.race.stageId,
          eventName: displayed.eventName,
          className: displayed.race.className,
          date: displayed.eventDate,
          rank: displayed.race.finishRank ?? displayed.race.rank!,
          participantCount: displayed.race.participantCount,
          totalText: displayed.race.totalText,
        ),
  ];
}

AthleteEvent? _athleteEventForEvent(AthleteProfile profile, String eventId) {
  for (final event in profile.events) {
    if (event.eventId == eventId) return event;
  }
  return null;
}

int _compareDisplayedRaces(_DisplayedRace a, _DisplayedRace b) {
  final dateCompare = _compareNullableDateDesc(a.eventDate, b.eventDate);
  if (dateCompare != 0) return dateCompare;

  final aEventId = int.tryParse(a.race.eventId);
  final bEventId = int.tryParse(b.race.eventId);
  if (aEventId != null && bEventId != null && aEventId != bEventId) {
    return bEventId.compareTo(aEventId);
  }

  final eventCompare = b.race.eventId.compareTo(a.race.eventId);
  if (eventCompare != 0) return eventCompare;
  final classCompare = a.race.className.compareTo(b.race.className);
  if (classCompare != 0) return classCompare;
  return a.race.resultId.compareTo(b.race.resultId);
}

int _compareNullableDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
