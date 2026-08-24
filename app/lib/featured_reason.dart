import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';
import 'rewamp_db.dart';

/// Renders a featured slot's reason label from `reason_key` + `reason_params`,
/// through our own ARB/ICU catalogue.
///
/// We deliberately ignore the server's pre-rendered `reason` string (except as a
/// fallback): the server can only pick between a singular and a plural form,
/// while Russian, Polish and Czech have three. Rendering client-side is the
/// reference contract — it also means a new UI language needs no server change.
///
/// The server's own label is used only when this build does not know the key —
/// a slot type added server-side still shows something sensible.
/// The reason label of a featured *card* (party/month/anniversary card).
String featuredReasonText(BuildContext context, FeaturedSlot slot) =>
    _renderReason(context, slot.reasonKey, slot.reasonParams, slot.reason);

/// The header label of a featured *series* (the section that groups several
/// playlists). Same ICU catalogue as the card reason — party.* keys are shared;
/// sections additionally use month.header / anniversary.header.
String featuredGroupReasonText(BuildContext context, FeaturedSlot slot) =>
    _renderReason(context, slot.groupReasonKey ?? '', slot.groupReasonParams,
        slot.groupReason ?? '');

/// A SHORT title for a series group card on the home rail — the party/series
/// name ("Assembly 2024"), the month name ("July"), or "Anniversaries" — NOT
/// the full header sentence ([featuredGroupReasonText]), which is too long for a
/// 110pt card and is instead shown inside the series screen.
String featuredGroupLabel(BuildContext context, FeaturedSlot slot) {
  final l10n   = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final key    = slot.groupReasonKey ?? '';
  final gp     = slot.groupReasonParams;

  if (key.startsWith('party')) {
    final p = gp['party'] ?? gp['series'];
    if (p != null && '$p'.isNotEmpty) return '$p';
  }
  if (key == 'month.header') {
    final m = (gp['month'] is num)
        ? (gp['month'] as num).toInt()
        : int.tryParse('${gp['month']}') ?? 1;
    final date = DateTime(2000, m.clamp(1, 12));
    try {
      return DateFormat.LLLL(locale).format(date);
    } catch (_) {
      return DateFormat.LLLL('en').format(date);
    }
  }
  if (key == 'anniversary.header') return l10n.featuredAnniversaryHeader;
  if (key == 'birthday.header') return l10n.featuredBirthdayHeader;
  if (key == 'birthday.week.header') return l10n.featuredBirthdayWeekHeader;

  // Fallback: strip the "party:"/"month:" prefix off group_key, else the header.
  final gk = slot.groupKey ?? '';
  final colon = gk.indexOf(':');
  if (colon >= 0 && colon < gk.length - 1) return gk.substring(colon + 1);
  return featuredGroupReasonText(context, slot);
}

/// Renders any featured reason/header key + params through the ARB/ICU
/// catalogue. Serves both the per-card reason and the per-series header, so the
/// two never drift.
///
/// `fallback` is the server's pre-rendered string, used only for a key this
/// build doesn't know yet (a type added server-side still shows something).
String _renderReason(BuildContext context, String key,
    Map<String, dynamic> p, String fallback) {
  final l10n   = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();

  // Month arrives as 1-12; the localized name comes from intl, not from a table
  // of 12 strings per language.
  //
  // LLLL (stand-alone), NOT MMMM (in-date form): Slavic languages inflect month
  // names, and MMMM yields the genitive used inside a full date ("5 июля").
  // Here the month stands on its own, which wants the nominative ("июль").
  // The messages are phrased without a preposition for the same reason — no
  // amount of formatting can produce the case a preposition would demand.
  String monthName(int m) {
    final date = DateTime(2000, m.clamp(1, 12));
    try {
      return DateFormat.LLLL(locale).format(date);
    } catch (_) {
      return DateFormat.LLLL('en').format(date);
    }
  }

  // Years/decades must NOT be rendered as int placeholders: intl would group
  // them ("1 991"). They travel as plain strings.
  String str(Object? v) => v?.toString() ?? '';
  int num_(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  // Birthday day+month → a localized "day month" ("19 July" / "19 juillet" /
  // "19 июля"). Here MMMMd is correct (NOT LLLL): with a day present, Slavic
  // languages want the genitive month, which is exactly what the in-date form
  // gives. '' when the server didn't send the date (older rows).
  String birthdayDate() {
    final d = num_(p['day']);
    final m = num_(p['month']);
    if (d < 1 || m < 1) return '';
    final date = DateTime(2000, m.clamp(1, 12), d.clamp(1, 31));
    try {
      return DateFormat.MMMMd(locale).format(date);
    } catch (_) {
      return DateFormat.MMMMd('en').format(date);
    }
  }

  switch (key) {
    // ── cards ──────────────────────────────────────────────────────────────
    case 'party.now':
      return l10n.featuredPartyNow(str(p['party']));
    case 'party.starts_in':
      return l10n.featuredPartyStartsIn(num_(p['days']), str(p['party']));
    case 'party.season':
      return l10n.featuredPartySeason(str(p['series']));
    case 'month.decade':
      return l10n.featuredMonthDecade(str(p['decade']));
    case 'anniversary.age':
      return l10n.featuredAnniversaryAge(num_(p['age']), str(p['year']));
    case 'birthday.artist':       // today's birthday
    case 'birthday.week.artist':  // a birthday somewhere this week
      // The card title already says "Happy Birthday — <artist>" and the section
      // header says today/this-week, so the subtitle is just the date. Falls
      // back to the artist phrasing for a row that predates the date field.
      final dt = birthdayDate();
      return dt.isNotEmpty ? dt : l10n.featuredBirthdayWeekArtist(str(p['artist']));
    // ── section headers ──────────────────────────────────────────────────────
    case 'month.header':
      return l10n.featuredMonthHeader(monthName(num_(p['month'])));
    case 'anniversary.header':
      return l10n.featuredAnniversaryHeader;
    case 'birthday.header':
      return l10n.featuredBirthdayHeader;
    case 'birthday.week.header':
      // week_start/week_end arrive as ISO dates ('2026-07-13'). Real dates
      // inside a sentence → in-date month form (MMMd), locale-ordered; this is
      // the one place the genitive IS correct (unlike stand-alone LLLL above).
      final ws = DateTime.tryParse(str(p['week_start']));
      final we = DateTime.tryParse(str(p['week_end']));
      if (ws != null && we != null) {
        String d(DateTime x) {
          try {
            return DateFormat.MMMd(locale).format(x);
          } catch (_) {
            return DateFormat.MMMd('en').format(x);
          }
        }
        return l10n.featuredBirthdayWeekHeaderRange(
            l10n.featuredBirthdayWeekHeader, d(ws), d(we));
      }
      return l10n.featuredBirthdayWeekHeader;
    // ── legacy (pre-v2), kept as fallback during a server transition ─────────
    case 'month.released':
      return l10n.featuredMonthReleased(monthName(num_(p['month'])), str(p['year']));
    case 'anniversary.years_ago':
      return l10n.featuredAnniversaryYearsAgo(num_(p['age']), str(p['year']));
    default:
      return fallback;
  }
}
