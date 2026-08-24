// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navHome => 'Start';

  @override
  String get navSearch => 'Suche';

  @override
  String get navLibrary => 'Mediathek';

  @override
  String get noFileSelected => 'Keine Datei ausgewählt';

  @override
  String get openFile => 'Datei öffnen';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Format nicht unterstützt';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Nicht unterstütztes Format: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Nicht auf diesem Gerät: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Datei nicht mehr auf dem Server: $file';
  }

  @override
  String get failedToLoadFile => 'Datei konnte nicht geladen werden';

  @override
  String get libraryEmptyHint =>
      'Deine Künstler, Alben und Wiedergabelisten\nerscheinen hier.';

  @override
  String get libraryPlaylists => 'Wiedergabelisten';

  @override
  String get libraryArtists => 'Künstler';

  @override
  String get libraryAlbums => 'Alben';

  @override
  String get libraryTracks => 'Titel';

  @override
  String get libraryFavorites => 'Favoriten';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatische Wiedergabeliste deiner Lieblingstitel';

  @override
  String get libraryRecentlyAdded => 'Zuletzt hinzugefügt';

  @override
  String get libraryEmpty => 'Noch nichts vorhanden';

  @override
  String get libraryRemoved => 'Aus der Bibliothek entfernt';

  @override
  String get searchHint => 'Suchen…';

  @override
  String get searchTypePlaceholder => 'Titel, Künstler oder Album eingeben…';

  @override
  String get searchNoResults => 'Keine Ergebnisse';

  @override
  String get searchDownloading => 'Wird geladen…';

  @override
  String searchError(String message) {
    return 'Fehler: $message';
  }

  @override
  String get tabAll => 'Titel';

  @override
  String get tabArtists => 'Künstler';

  @override
  String get tabAlbums => 'Alben';

  @override
  String get tabProductions => 'Produktionen';

  @override
  String get filterWithVideo => 'Mit Video';

  @override
  String get videoUnavailable => 'Dieses Video ist nicht verfügbar';

  @override
  String get noItems => 'Keine Einträge';

  @override
  String get sortRelevance => 'Relevanz';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Zuletzt gespielt';

  @override
  String get noRecentTracks => 'Keine zuletzt gespielten Titel';

  @override
  String get openLocalFile => 'Lokale Datei öffnen';

  @override
  String get playerSourceLocal => 'lokal';

  @override
  String get browseFiles => 'Dateien durchsuchen';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total Ergebnisse';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded geladen…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded Ergebnisse';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded geladen — für mehr scrollen';
  }

  @override
  String countNLoaded(int n) {
    return '$n geladen';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n Datei(en)';
  }

  @override
  String get browseFilterByTitle => 'Nach Titel filtern…';

  @override
  String get browseNoSongs => 'Keine Songs verfügbar';

  @override
  String get browseByFormat => 'Nach Format';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Nach Format filtern…';

  @override
  String get browseByPlatform => 'Nach Plattform';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Name der Plattform…';

  @override
  String get browseByChip => 'Nach Soundchip';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'z. B. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Nach Künstler';

  @override
  String get browseByArtistSubtitle => 'Die Komponisten durchsuchen';

  @override
  String get browseFilterByName => 'Nach Name filtern…';

  @override
  String get browseNoArtistFound => 'Kein Künstler gefunden';

  @override
  String get browseNoArtistsAvailable => 'Keine Künstler verfügbar';

  @override
  String get browseNoArtist => 'Keine Künstler';

  @override
  String get browseNoAlbum => 'Keine Alben';

  @override
  String get browseTopPacks => 'Top-Packs';

  @override
  String get browseTopPacksSubtitle => 'Die bestbewerteten Packs';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Top-Packs — $collection';
  }

  @override
  String get browseLatestPacks => 'Neueste Packs';

  @override
  String get browseLatestPacksSubtitle => 'Die neuesten Zugänge';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Neueste Packs — $collection';
  }

  @override
  String get browseAllSongs => 'Alle Songs';

  @override
  String get browseAllSongsSubtitleAlpha =>
      'In alphabetischer Reihenfolge durchsuchen';

  @override
  String get browseAlphabetical => 'In alphabetischer Reihenfolge';

  @override
  String browseAllLabel(String collection) {
    return 'Alle — $collection';
  }

  @override
  String get browseCollections => 'Sammlungen';

  @override
  String browseFilesCount(String count) {
    return '$count Dateien';
  }

  @override
  String get browseIndexing => 'Indexierung läuft';

  @override
  String browseFilterFacet(String name) {
    return '$name filtern…';
  }

  @override
  String get browseAllYears => 'Alle Jahre';

  @override
  String get browseAllYearsSubtitle => 'Alle Songs der Demoparty';

  @override
  String get browseNoCompo => 'Keine Compo für diese Demoparty indexiert.';

  @override
  String get browseOthers => 'Andere';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Beiträge — Rangliste',
      one: '$n Beitrag — Rangliste',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Wiedergabeliste abspielen';

  @override
  String get browsePlayAllRanked =>
      'Alle abspielen (in Reihenfolge der Rangliste)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel — Reihenfolge der Rangliste',
      one: '$n Titel — Reihenfolge der Rangliste',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Nach Album durchsuchen';

  @override
  String get browsePlayAll => 'Alle abspielen';

  @override
  String get browseShuffle => 'Zufallswiedergabe';

  @override
  String get browseSearchInFolder => 'In diesem Ordner suchen…';

  @override
  String get browseFilterThisList => 'Diese Liste filtern…';

  @override
  String get browseSearchSubfolders => 'In Unterordnern suchen';

  @override
  String get browseEmptyFolder => 'Leerer Ordner';

  @override
  String browsePlaybackError(String message) {
    return 'Wiedergabe fehlgeschlagen: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel',
      one: '$n Titel',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Ansicht';

  @override
  String get browseViewList => 'Liste';

  @override
  String get browseViewGrid => 'Raster';

  @override
  String get browseViewGridCompact => 'Kompaktes Raster';

  @override
  String get browseSearchAlbum => 'Nach einem Album suchen…';

  @override
  String get browseSearchArtist => 'Nach einem Künstler suchen…';

  @override
  String get browsePlayAlbum => 'Album abspielen';

  @override
  String get searchDownloadingAlbum => 'Album wird geladen…';

  @override
  String get searchCategoryChip => 'Chips';

  @override
  String get searchCategoryGroup => 'Gruppen';

  @override
  String get artistRealName => 'Echter Name';

  @override
  String get artistAliases => 'Aliase';

  @override
  String get artistBorn => 'Geboren';

  @override
  String get artistInterview => 'Interview';

  @override
  String get audioOutput => 'Audioausgabe';

  @override
  String get audioOutputSystemDefault => 'Systemstandard';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Anmerkungen';

  @override
  String get notePlacedBadge => 'In der Compo platziert';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '$count Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Titel anzeigen';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Module',
      one: '$count Modul',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Demopartys';

  @override
  String get searchCategoryYear => 'Jahr';

  @override
  String get searchCategoryOrigin => 'Herkunft';

  @override
  String get searchCategoryProduction => 'Produktion';

  @override
  String get searchCategoryProductionType => 'Prod-Typen';

  @override
  String get searchCategoryPublisher => 'Publisher';

  @override
  String get searchCategoryDeveloper => 'Entwickler';

  @override
  String get searchCategoryArcadeBoard => 'Arcade-Boards';

  @override
  String get searchCategorySaga => 'Reihe';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'über Künstler';

  @override
  String get searchViaAlbum => 'über ein Album';

  @override
  String get searchViaSong => 'über einen Song';

  @override
  String get searchSortPopular => 'Beliebt';

  @override
  String get searchSortYear => 'Jahr';

  @override
  String get searchSortRandom => 'Zufällig';

  @override
  String get searchSortRating => 'Bewertung';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen',
      one: '$count Stimme',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Aufsteigend';

  @override
  String get searchSortDesc => 'Absteigend';

  @override
  String get searchFilters => 'Filter';

  @override
  String get searchExactSearch => 'Exakte Suche';

  @override
  String get searchExactSearchSubtitle =>
      'Deaktiviert die unscharfe (Fuzzy-)Suche';

  @override
  String get searchTags => 'Tags';

  @override
  String searchTagSearchHint(String category) {
    return 'Tag in « $category » suchen…';
  }

  @override
  String get searchTagTypeToSearch => 'Tippen, um nach Tags zu suchen.';

  @override
  String get searchTagsAndLogic => 'Mehrere Tags = logisches UND.';

  @override
  String get searchFilterYear => 'Jahr';

  @override
  String get searchFilterAll => 'alle';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Das Filtern nach Jahr schließt undatierte Songs aus.';

  @override
  String get searchMinRating => 'Bewertung ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Abbrechen';

  @override
  String get searchReset => 'Zurücksetzen';

  @override
  String get searchApply => 'Anwenden';

  @override
  String get searchClearRecent => 'Letzte Suchanfragen löschen';

  @override
  String get searchBrowse => 'Durchsuchen';

  @override
  String get searchBrowseHint =>
      'Wähle eine Facette (Gruppe, Chip, Jahr…), um den Katalog zu erkunden, oder starte oben Radio/Überraschung.';

  @override
  String get searchDidYouMean =>
      'Wenige Ergebnisse — eine unscharfe Suche versuchen?';

  @override
  String get searchYes => 'Ja';

  @override
  String get featuredCommunityTitle => 'Neu aus der Community';

  @override
  String get searchPlaylistSourceAll => 'Alle';

  @override
  String get searchPlaylistSourceUser => 'Community';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Plattform';

  @override
  String get filterCollection => 'Sammlung';

  @override
  String get videoWatchDemo => 'Demo ansehen';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Sammlung: $name';
  }

  @override
  String get searchCollectionAll => 'Alle';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip =>
      'Zufällige Warteschlange nach den aktuellen Filtern';

  @override
  String get searchSurprise => 'Überraschung';

  @override
  String get searchSurpriseTooltip => 'Ein zufälliger Song';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Keine Songs';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Songs',
      one: '$n Song',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Alben',
      one: '$n Album',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Sammlung wählen';

  @override
  String get searchFilterCollections => 'Sammlungen filtern…';

  @override
  String get searchFilterPlaceholder => 'Filtern…';

  @override
  String searchAllOf(String label) {
    return 'Alle ($label)';
  }

  @override
  String get searchNoMatch => 'Keine Übereinstimmung';

  @override
  String get searchNoPlaylist => 'Keine Wiedergabelisten';

  @override
  String get engineDescOpenmpt => 'Tracker-Module (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — Soundchips, Scope pro Kanal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN-Archive';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — Stimmen pro Kanal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp-Engine)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX-Chiptunes (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Multi-Chip-Chiptunes .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amiga-Custom-Chip-Formate via 68k-Emulation (~320 Endungen)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Standard-MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ-Synth (16 Stimmen)';

  @override
  String get engineDescV2m => 'V2M-Synth (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — echte 68000-Emulation + YM2149 + STE-DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300-Emulation + RSP-Audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC-V30MZ-Emulation';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound-Chip';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — echter AY-3-8910/YM2149-Synth';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixels eigene Engine';

  @override
  String get engineDescPxtone => 'Pixels Tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — echter 68000 via emu68';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA-FM + SSG + PPZ8-Samples';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ .pdx-Samples), YM2151-FM';

  @override
  String get engineDescFmp =>
      'PC-98-FMP-Treiber — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM-Towns-EUPHONY — YM2612-FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Gestreamte Spiele-Audioformate (700+, inkl. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — Ausweichdecoder';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total Songs',
      one: '$loaded / 1 Song',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total Alben',
      one: '$loaded / 1 Album',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total Künstler',
      one: '$loaded / 1 Künstler',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Songs',
      one: '$n Song',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Alben',
      one: '$n Album',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Künstler',
      one: '$n Künstler',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Gruppen',
      one: '$n Gruppe',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Länder';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Länder',
      one: '$n Land',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Ordner';

  @override
  String get featuredTitle => 'Heute empfohlen';

  @override
  String featuredPartyNow(String party) {
    return '$party läuft gerade — Podien vergangener Ausgaben';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party beginnt in $days Tagen — Podien vergangener Ausgaben',
      one: '$party beginnt morgen — Podien vergangener Ausgaben',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series-Saison — Podien vergangener Ausgaben';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Erschienen im $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Vor $age Jahren: die Spiele von $year',
      one: 'Vor einem Jahr: die Spiele von $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Die ${decade}er';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Vor $age Jahren: die Spiele von $year',
      one: 'Vor einem Jahr: die Spiele von $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Erschienen im $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Jahrestage';

  @override
  String get featuredBirthdayHeader => 'Geburtstage heute';

  @override
  String get featuredBirthdayWeekHeader => 'Geburtstage dieser Woche';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist hat diese Woche Geburtstag';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Playlists',
      one: '$count Playlist',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonOptions => 'Optionen';

  @override
  String get commonDownload => 'Laden';

  @override
  String get commonDeleteDownload => 'Download löschen';

  @override
  String get commonAddToPlaylist => 'Zur Wiedergabeliste hinzufügen';

  @override
  String get commonPlayNext => 'Als Nächstes spielen';

  @override
  String get commonAddToQueueEnd => 'Am Ende der Warteschlange hinzufügen';

  @override
  String get commonAddToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get commonRemoveFromFavorites => 'Aus Favoriten entfernen';

  @override
  String unitBytes(String value) {
    return '$value B';
  }

  @override
  String unitKilobytes(String value) {
    return '$value KB';
  }

  @override
  String unitMegabytes(String value) {
    return '$value MB';
  }

  @override
  String get subsongDeleteDownloadTitle => 'Diesen Download löschen?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Die Datei und ihre lokalen Einträge (Verlauf, Titel) werden gelöscht.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed =>
      'Die Titel konnten nicht gelesen werden';

  @override
  String subsongTrackNumber(int number) {
    return 'Titel $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Subsongs',
      one: '$count Subsong',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Alle abspielen';

  @override
  String get albumDownloading => 'Album wird geladen…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Album wird geladen… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks => 'Album laden, um die Titel zu sehen';

  @override
  String get albumNotDownloadedHint =>
      'Album nicht geladen — Wiedergabe starten, um es zu laden';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '$count Titel',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Details werden geladen…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Album abspielen';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '$count Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Diesen Titel zuerst aus der Suche abspielen, um ihn zu laden';

  @override
  String get libraryAddedTrack => 'Titel zur Mediathek hinzugefügt';

  @override
  String get libraryAddedAlbum => 'Album zur Mediathek hinzugefügt';

  @override
  String get libraryAddedArtist => 'Künstler zur Mediathek hinzugefügt';

  @override
  String get libraryRemovedTrack => 'Titel aus der Mediathek entfernt';

  @override
  String get libraryRemovedAlbum => 'Album aus der Mediathek entfernt';

  @override
  String get libraryRemovedArtist => 'Künstler aus der Mediathek entfernt';

  @override
  String songTilePlayFailed(String message) {
    return 'Wiedergabe fehlgeschlagen: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Download fehlgeschlagen — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Wird geladen — $label';
  }

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmpty => 'Keine ausstehenden Downloads';

  @override
  String get downloadsPause => 'Pausieren';

  @override
  String get downloadsResume => 'Fortsetzen';

  @override
  String get downloadsCancel => 'Download abbrechen';

  @override
  String get downloadsClear => 'Alle entfernen';

  @override
  String get downloadsPausedBanner =>
      'Downloads pausiert — die aktuelle Datei wird noch beendet';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Wird geladen — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Wiedergabeliste';

  @override
  String get miniPlayerHideQueue => 'Wiedergabeliste ausblenden';

  @override
  String get transportShuffle => 'Zufallswiedergabe';

  @override
  String get transportShuffleOn => 'Zufallswiedergabe aktiviert';

  @override
  String get transportLoopOff => 'Wiederholen aus';

  @override
  String get transportLoopQueue => 'Wiederholen: Warteschlange';

  @override
  String get transportLoopTrack => 'Wiederholen: aktueller Titel';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spektrum';

  @override
  String get vizVoices => 'Stimmen';

  @override
  String get vizNotes => 'Noten';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Bildlaufmodus';

  @override
  String get patternSmoothScroll => 'Sanftes Scrollen';

  @override
  String get patternVolumeBars => 'Lautstärkebalken';

  @override
  String get patternColorScheme => 'Farbschema';

  @override
  String get patternSize => 'Größe';

  @override
  String get patternColumns => 'Spalten';

  @override
  String get patternColumnsAll => 'Vollständig';

  @override
  String get patternColumnsNoteInstr => 'Reduziert';

  @override
  String get patternColumnsNote => 'Minimal';

  @override
  String get vizClose => 'Visualisierung schließen';

  @override
  String get vizFullscreen => 'Vollbild';

  @override
  String get vizExitFullscreen => 'Vollbild beenden';

  @override
  String get vizPrevPreset => 'Vorheriges Preset';

  @override
  String get vizNextPreset => 'Nächstes Preset';

  @override
  String get vizProjectmUnavailable => 'projectM nicht verfügbar';

  @override
  String get voicesTitle => 'Stimmen';

  @override
  String get voicesNone => 'Keine Stimmen für diesen Titel.';

  @override
  String get voicesLongPressSolo => 'langer Druck = Solo';

  @override
  String get voicesMuteAll => 'Alle stummschalten';

  @override
  String get voicesUnmuteAll => 'Alle aktivieren';

  @override
  String get voicesStereoOutput => 'Stereoausgabe';

  @override
  String get voicesLeft => 'Links';

  @override
  String get voicesRight => 'Rechts';

  @override
  String get enginesFormatsTitle => 'Abspielbare Formate';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats abspielbare Formate, verteilt auf $engines Wiedergabe-Engines.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Formate',
      one: '1 Format',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Coverversion von $title von $artist';
  }

  @override
  String stilCover(String work) {
    return 'Coverversion von $work';
  }

  @override
  String get playerQueue => 'Warteschlange';

  @override
  String get queueEdit => 'Bearbeiten';

  @override
  String get queueEditDone => 'Fertig';

  @override
  String get queueClear => 'Warteschlange leeren';

  @override
  String get queueClearConfirmTitle => 'Warteschlange leeren?';

  @override
  String get queueClearConfirmBody =>
      'Die Warteschlange wird geleert und die Wiedergabe gestoppt.';

  @override
  String get queueClearConfirm => 'Leeren';

  @override
  String get queueRemoveSelected => 'Auswahl entfernen';

  @override
  String get queueRemoveTrack => 'Aus der Warteschlange entfernen';

  @override
  String get queueReorder => 'Neu anordnen';

  @override
  String get playerArtwork => 'Cover';

  @override
  String get playerVisualizer => 'Visualisierung';

  @override
  String get playerVoices => 'Stimmen';

  @override
  String get playerTrackInfo => 'Titelinfos';

  @override
  String get playerShowQueue => 'Wiedergabeliste';

  @override
  String get playerHideQueue => 'Wiedergabeliste ausblenden';

  @override
  String get playerNoTrackInfo => 'Keine Informationen verfügbar.';

  @override
  String get playerViewSubsongs => 'Subsongs anzeigen';

  @override
  String get playerViewAlbum => 'Album anzeigen';

  @override
  String get playerViewArtist => 'Künstler anzeigen';

  @override
  String get playerAddToPlaylist => 'Zur Wiedergabeliste hinzufügen';

  @override
  String get queueAddToPlaylist => 'Warteschlange zu einer Playlist hinzufügen';

  @override
  String get playerMoreOptions => 'Weitere Optionen';

  @override
  String get playerClose => 'Schließen';

  @override
  String get playerCancel => 'Abbrechen';

  @override
  String get playerDelete => 'Löschen';

  @override
  String get playerAddFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get playerRemoveFavorite => 'Aus Favoriten entfernen';

  @override
  String get playerAddToLibrary => 'Zur Mediathek hinzufügen';

  @override
  String get playerRemoveFromLibrary => 'Aus Mediathek entfernen';

  @override
  String get playerAddedToLibrary => 'Titel zur Mediathek hinzugefügt';

  @override
  String get playerRemovedFromLibrary => 'Titel aus der Mediathek entfernt';

  @override
  String get playerDeleteDownload => 'Download löschen';

  @override
  String get playerRedownload => 'Datei erneut herunterladen';

  @override
  String get playerRedownloadUnavailable =>
      'Erneuter Download für diese Datei nicht verfügbar';

  @override
  String get playerDeleteDownloadTitle => 'Download löschen?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Die Datei und ihre lokalen Einträge (Verlauf, Titel) werden gelöscht.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Deine Trends';

  @override
  String get homeYourAllTimeTop => 'Deine Top-Titel aller Zeiten';

  @override
  String get homeTrending => 'Im Trend';

  @override
  String get homeFeaturedPlaylists => 'Empfohlene Wiedergabelisten';

  @override
  String get homeAllTimeTop => 'Top aller Zeiten';

  @override
  String get homePeriod7d => '7 T';

  @override
  String get homePeriod30d => '30 T';

  @override
  String get homePeriod90d => '90 T';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wiedergaben',
      one: '$n Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel',
      one: '$n Titel',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Leere oder unlesbare Wiedergabeliste';

  @override
  String get homeExtractingArchive => 'Archiv wird entpackt…';

  @override
  String get homeArchiveEmpty => 'Keine abspielbaren Dateien im Archiv';

  @override
  String get homeNothingPlayable => 'Nichts Abspielbares in der Auswahl';

  @override
  String get homeAlbumLoadFailed => 'Dieses Album konnte nicht geladen werden';

  @override
  String get homeSongLoadFailed => 'Dieser Titel konnte nicht geladen werden';

  @override
  String get navStats => 'Statistik';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get playlistMoveUp => 'In übergeordneten Ordner';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Playlists',
      one: '$n Playlist',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Unterordner',
      one: '$n Unterordner',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Dieser Ordner und sein gesamter Inhalt werden endgültig gelöscht:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Dieser Ordner wird gelöscht.';

  @override
  String get playlistFolderRoot => 'Stamm';

  @override
  String get playlistMoveToFolder => 'In Ordner verschieben';

  @override
  String playlistDeleteTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get playlistDeleteBody => 'Diese Playlist wird endgültig gelöscht.';

  @override
  String get playlistRenameFolderTitle => 'Ordner umbenennen';

  @override
  String get playlistClearFavorites => 'Alle Favoriten löschen';

  @override
  String get playlistClearFavoritesTitle => 'Alle Favoriten löschen?';

  @override
  String get playlistClearFavoritesBody =>
      'Du verlierst alle deine Lieblingstitel. Das kann nicht rückgängig gemacht werden.';

  @override
  String get playlistRemoveFromLibrary => 'Aus Bibliothek entfernen';

  @override
  String get playlistServerReadOnly => 'Server-Playlist · schreibgeschützt';

  @override
  String get navAbout => 'Über';

  @override
  String get navMore => 'Mehr';

  @override
  String get shellAlbumQueuedAtEnd =>
      'Album am Ende der Warteschlange hinzugefügt';

  @override
  String get shellAlbumQueuedNext => 'Album wird als Nächstes gespielt';

  @override
  String get shellAddingToQueue => 'Wird zur Warteschlange hinzugefügt…';

  @override
  String get shellAddingNext => 'Wird als Nächstes eingereiht…';

  @override
  String shellDownloadFailed(String error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel zur Warteschlange hinzugefügt',
      one: '$count Titel zur Warteschlange hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" am Ende der Warteschlange hinzugefügt';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" wird als Nächstes gespielt';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Download fehlgeschlagen: $title — weiter zum nächsten Titel';
  }

  @override
  String get shellNetworkUnavailable =>
      'Wiedergabe gestoppt: Das Netzwerk scheint nicht verfügbar zu sein.';

  @override
  String get statsTitle => 'Statistik';

  @override
  String statsPeriodDays(int n) {
    return '$n Tage';
  }

  @override
  String get statsPeriodThisYear => 'Dieses Jahr';

  @override
  String get statsPeriodAll => 'Gesamt';

  @override
  String get statsByMonthOrYear => 'Nach Monat / Jahr…';

  @override
  String get statsByYear => 'Nach Jahr';

  @override
  String get statsByMonth => 'Nach Monat';

  @override
  String get statsPlaysLabel => 'Wiedergaben';

  @override
  String get statsTracksLabel => 'Titel';

  @override
  String get statsArtistsLabel => 'Künstler';

  @override
  String get statsAlbumsLabel => 'Alben';

  @override
  String get statsListenTime => 'Hörzeit';

  @override
  String get statsByCollection => 'Nach Sammlung';

  @override
  String get statsByFormat => 'Nach Format';

  @override
  String get statsByEngine => 'Nach Engine';

  @override
  String get statsPlaylistsLabel => 'Playlists';

  @override
  String get statsLocalFilesSection => 'Heruntergeladene Dateien';

  @override
  String get statsFilesLabel => 'Dateien';

  @override
  String get statsSpaceLabel => 'Speicherplatz';

  @override
  String get statsNoPlaysInPeriod => 'Keine Wiedergaben in diesem Zeitraum';

  @override
  String get statsNoPlays => 'Keine Wiedergaben';

  @override
  String get statsTopTracks => 'Top-Titel';

  @override
  String get statsTopAlbums => 'Top-Alben';

  @override
  String get statsTopArtists => 'Top-Künstler';

  @override
  String statsTopTracksIn(String period) {
    return 'Top-Titel — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top-Alben — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top-Künstler — $period';
  }

  @override
  String get statsSeeAll => 'Alle anzeigen';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Wiedergaben',
      one: '$n Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel',
      one: '$n Titel',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max. $n';
  }

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonCreate => 'Erstellen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get commonSort => 'Sortieren';

  @override
  String get commonPlayAll => 'Alle abspielen';

  @override
  String get sortName => 'Name';

  @override
  String get sortTitle => 'Titel';

  @override
  String get sortArtist => 'Künstler';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Hinzugefügt am';

  @override
  String get commonClear => 'Löschen';

  @override
  String get sortRecentlyModified => 'Zuletzt geändert';

  @override
  String get sortCreationDate => 'Erstellungsdatum';

  @override
  String get playlistNameHint => 'Name';

  @override
  String get playlistNew => 'Neue Wiedergabeliste';

  @override
  String get playlistNewFolder => 'Neuer Ordner';

  @override
  String get playlistNewTooltip => 'Neue Wiedergabeliste / neuer Ordner';

  @override
  String get playlistAddTo => 'Zur Wiedergabeliste hinzufügen';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Zu $n Wiedergabelisten hinzufügen',
      one: 'Zu $n Wiedergabeliste hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Wiedergabeliste auswählen';

  @override
  String get playlistFilterHint => 'Wiedergabelisten filtern…';

  @override
  String get playlistSearchHint => 'Wiedergabeliste suchen…';

  @override
  String get playlistNoMatch => 'Keine passende Wiedergabeliste';

  @override
  String get playlistNoneCreateHint =>
      'Keine Wiedergabeliste — mit + eine erstellen';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel',
      one: '$n Titel',
      zero: 'Keine Titel',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Bereits vorhanden';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Einträge sind bereits in den ausgewählten Wiedergabelisten.',
      one: '$n Eintrag ist bereits in den ausgewählten Wiedergabelisten.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Duplikate überspringen';

  @override
  String get playlistAddAgain => 'Erneut hinzufügen';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Titel',
      one: '$n Titel',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m Wiedergabelisten',
      one: '$n Wiedergabeliste',
    );
    return '$_temp0 zu $_temp1 hinzugefügt';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Hinzufügen fehlgeschlagen: $error';
  }

  @override
  String get playlistRenameTitle => 'Wiedergabeliste umbenennen';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Ordner „$name“ löschen?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'Sein Inhalt rückt eine Ebene nach oben.';

  @override
  String get playlistEmpty => 'Leere Wiedergabeliste';

  @override
  String get playlistRemoveEntry => 'Aus Wiedergabeliste entfernen';

  @override
  String get trackOptionsAddToLibrary => 'Zur Mediathek hinzufügen';

  @override
  String get trackOptionsRemoveFromLibrary => 'Aus Mediathek entfernen';

  @override
  String get trackOptionsAddedToLibrary => 'Titel zur Mediathek hinzugefügt';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'Titel aus der Mediathek entfernt';

  @override
  String get trackOptionsViewAlbum => 'Album anzeigen';

  @override
  String get trackOptionsViewArtist => 'Künstler anzeigen';

  @override
  String get trackOptionsPlayNow => 'Jetzt abspielen';

  @override
  String get trackOptionsPlayNext => 'Als Nächstes spielen';

  @override
  String get trackOptionsAddToQueueEnd =>
      'Am Ende der Warteschlange hinzufügen';

  @override
  String get trackOptionsPlayLast => 'Zuletzt spielen';

  @override
  String get trackOptionsDeleteDownload => 'Download löschen';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Diesen Download löschen?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Die Datei und ihre lokalen Einträge (Verlauf, Titel) werden gelöscht.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Download gelöscht';

  @override
  String get trackOptionsAddToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get trackOptionsRemoveFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Album zu Favoriten hinzugefügt';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album aus Favoriten entfernt';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album nicht geladen — nichts zu löschen';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Geladenes Album löschen?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Der Ordner und alle lokalen Einträge (Titel, Verlauf) werden gelöscht.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Album aus dem lokalen Speicher gelöscht';

  @override
  String get trackOptionsRedownloadAlbum => 'Album erneut laden';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Überschreibt Dateien UND lokale Einträge';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Albumdateien löschen';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Geladener Ordner + lokale Einträge (Verlauf)';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGeneral => 'Allgemein';

  @override
  String get settingsGeneralSubtitle => 'Design';

  @override
  String get settingsVisualisation => 'Visualisierung';

  @override
  String get settingsVisualisationSubtitle =>
      'Oszilloskope, Cover als Hintergrund';

  @override
  String get settingsPlayback => 'Wiedergabe';

  @override
  String get settingsPlaybackSubtitle => 'Schleifen, Ausblenden, Stille';

  @override
  String get settingsEngines => 'Engines';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Daten';

  @override
  String get settingsDataSubtitle => 'Kennung, Verlauf, Zurücksetzen';

  @override
  String get settingsBackupExport => 'Sicherung exportieren';

  @override
  String get settingsBackupExportSubtitle =>
      'Bibliothek, Playlists und Einstellungen in eine Datei speichern';

  @override
  String get settingsBackupImport => 'Sicherung importieren';

  @override
  String get settingsBackupImportSubtitle =>
      'Daten aus einer Sicherungsdatei wiederherstellen';

  @override
  String get settingsBackupExportFailed =>
      'Export der Sicherung fehlgeschlagen';

  @override
  String get settingsBackupImportConfirmTitle => 'Sicherung importieren?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Dies ersetzt Bibliothek, Playlists und Einstellungen auf diesem Gerät. Heruntergeladene Dateien bleiben erhalten.';

  @override
  String get settingsBackupImportConfirm => 'Importieren';

  @override
  String get settingsBackupImportedTitle => 'Sicherung importiert';

  @override
  String get settingsBackupImportedBody =>
      'Deine Daten wurden wiederhergestellt. Starte die App neu, um alles zu übernehmen.';

  @override
  String get settingsBackupTooNew =>
      'Diese Sicherung stammt aus einer neueren App-Version';

  @override
  String get settingsBackupInvalid => 'Keine gültige Rewamp-Sicherung';

  @override
  String get settingsBackupImportFailed =>
      'Import der Sicherung fehlgeschlagen';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsAboutSubtitle => 'Credits und Lizenzen';

  @override
  String get settingsCreditsSubtitle => 'Bibliotheken, Daten & Komponenten';

  @override
  String get settingsSupport => 'Kontakt & Support';

  @override
  String get settingsSupportSubtitle => 'Kontakt, Website';

  @override
  String get settingsSupportEmail => 'E-Mail senden';

  @override
  String get settingsSupportEmailSubtitle => 'Frage, Fehler oder Vorschlag';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — Support';

  @override
  String get settingsSupportEmailIntro =>
      'Beschreibe oben deine Frage, deinen Fehler oder Vorschlag. Die Angaben unten helfen uns, dir zu helfen.';

  @override
  String get settingsSupportWebsite => 'Website';

  @override
  String get settingsDonation => 'Rewamp unterstützen';

  @override
  String get settingsDonationSubtitle => 'Ein Trinkgeld, wenn du magst';

  @override
  String get settingsDonationBlurb =>
      'Rewamp ist kostenlos und werbefrei — eine Herzensangelegenheit für die Bewahrung der Demoscene- und Retro-Kultur. Spenden helfen, die Entwicklung der App zu finanzieren und die Hosting-Kosten der Datenbank zu decken. Ohne Verpflichtung: Wenn dir die App Freude bereitet, ist eine kleine Geste immer willkommen.';

  @override
  String get settingsDonationFloppy => 'Eine Diskette';

  @override
  String get settingsDonationCartridge => 'Eine Cartridge';

  @override
  String get settingsDonationBox => 'Ein Spiel in der Box';

  @override
  String get settingsDonationCustom => 'Betrag wählen';

  @override
  String get settingsCancel => 'Abbrechen';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Löschen';

  @override
  String get settingsReset => 'Zurücksetzen';

  @override
  String get settingsRenew => 'Erneuern';

  @override
  String get settingsOff => 'Aus';

  @override
  String get settingsOn => 'Ein';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Endlos';

  @override
  String get settingsDefault => 'Standard';

  @override
  String get settingsCoreNoScope => 'ohne Oszilloskop';

  @override
  String get settingsNone => 'Keine';

  @override
  String get settingsLevelLow => 'Niedrig';

  @override
  String get settingsLevelHigh => 'Hoch';

  @override
  String get settingsStereo => 'Stereo';

  @override
  String get settingsSurround => 'Surround';

  @override
  String settingsValuePercent(int value) {
    return '$value %';
  }

  @override
  String settingsValueSeconds(int value) {
    return '$value s';
  }

  @override
  String settingsValueSecondsFrac(String value) {
    return '$value s';
  }

  @override
  String settingsValueHz(int value) {
    return '$value Hz';
  }

  @override
  String settingsValueDb(int value) {
    return '$value dB';
  }

  @override
  String settingsValueTimes(String value) {
    return '×$value';
  }

  @override
  String settingsSizeMb(String value) {
    return '$value MB';
  }

  @override
  String settingsSizeKb(String value) {
    return '$value kB';
  }

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsArtworkTintTitle => 'Player im Farbton des Covers';

  @override
  String get settingsArtworkTintSubtitle =>
      'Der Player übernimmt die dominante Farbe des Covers';

  @override
  String get settingsGlassEffectTitle => 'Liquid-Glass-Effekt';

  @override
  String get settingsGlassEffectSubtitle =>
      'Linse und Unschärfe auf den unteren Leisten — auf langsamen Geräten ausschalten';

  @override
  String get settingsResetSection => 'Diesen Abschnitt zurücksetzen';

  @override
  String get settingsResetEngine => 'Diese Engine zurücksetzen';

  @override
  String get settingsResetChoices => 'Diese Auswahl zurücksetzen';

  @override
  String get settingsResetToDefault => 'Standardwert';

  @override
  String get settingsStartInVizTitle => 'Im Visualisierungsmodus starten';

  @override
  String get settingsStartInVizSubtitle =>
      'Der Player öffnet die Oszilloskope statt des Covers';

  @override
  String get settingsVoiceGridTitle => 'Raster des Stimmen-Oszilloskops';

  @override
  String get settingsVoiceGridSubtitle =>
      'Zeigt die Trennlinien zwischen den Stimmen';

  @override
  String get settingsKeepAwakeTitle => 'Bildschirm anlassen';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Solange ein Visualizer läuft, wird der Bildschirm nicht abgedunkelt oder gesperrt';

  @override
  String get settingsVoiceNamesTitle => 'Stimmennamen';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Zeigt den Namen jeder Stimme in ihrem Rahmen';

  @override
  String get settingsLineThickness => 'Linienstärke';

  @override
  String get settingsColors => 'Farben';

  @override
  String get settingsScopeVoiceColor => 'Stimmen-Oszilloskop';

  @override
  String get settingsStereoColors => 'Stereo: Farben';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo links';

  @override
  String get settingsStereoRightColor => 'Stereo rechts';

  @override
  String get settingsNotation => 'Notation (Noten)';

  @override
  String get settingsNotePalette => 'Farbpalette';

  @override
  String get settingsNoteBoxStyle => 'Blockstil';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'CRT-Effekte';

  @override
  String get settingsCrtGlow => 'Glow';

  @override
  String get settingsCrtSpeed => 'Intensität / Geschwindigkeit';

  @override
  String get settingsArtworkOpacity => 'Deckkraft des Hintergrundcovers';

  @override
  String get settingsProjectMTitle => 'projectM-Einstellungen';

  @override
  String get settingsProjectMSubtitle => 'Presets, Übergänge, Qualität, Mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Benachrichtigung bei Titelwechsel';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Systembenachrichtigung mit dem Titel des neuen Stücks';

  @override
  String get settingsSilenceDetection => 'Stille-Erkennung';

  @override
  String get settingsSilenceSkipTitle =>
      'Bei Stille zum nächsten Titel springen';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Springt automatisch weiter, wenn die Ausgabe still bleibt';

  @override
  String get settingsSilenceDelay => 'Stille-Verzögerung';

  @override
  String get settingsDefaultDuration => 'Standarddauer';

  @override
  String get settingsDefaultDurationHelp =>
      'Wird verwendet, wenn ein Titel keine bekannte Dauer liefert (kein Tag, keine Server-Metadaten) — verhindert endloses Spielen oder Schleifen. Gilt nie für Amiga-Titel (UADE), die eine eigene Songlength-Datenbank haben.';

  @override
  String get settingsForcedLoopHeader => 'Erzwungene Schleife / Ausblenden';

  @override
  String get settingsForcedLoopHelp =>
      'Manche Formate wiederholen einen bestimmten Abschnitt (VGM, Tracker-Module…), andere nicht. \"Endlos\" ignoriert das natürliche Ende des Titels.';

  @override
  String get settingsForceLoopCount => 'Anzahl der Schleifen erzwingen';

  @override
  String get settingsLoopCount => 'Anzahl der Schleifen';

  @override
  String get settingsForceFadeout => 'Ausblenden erzwingen';

  @override
  String get settingsFadeoutDuration => 'Dauer des Ausblendens';

  @override
  String get settingsResetEnginesTitle => 'Engine-Einstellungen zurücksetzen?';

  @override
  String get settingsResetEnginesBody =>
      'Alle Engine-Einstellungen kehren zu ihren Standardwerten zurück.';

  @override
  String get settingsResetDefaultsTitle => 'Auf Standardwerte zurücksetzen';

  @override
  String get settingsResetDefaultsSubtitle => 'Alle Engines';

  @override
  String get settingsDefaultDecoders => 'Standard-Decoder';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formate, die mehrere Engines abspielen können';

  @override
  String get settingsDecodersHelp =>
      'Manche Formate können von mehreren Engines abgespielt werden. Wähle, welche standardmäßig verwendet wird — alle anderen Formate werden automatisch zugeordnet.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga-Tracker (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Tracker — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, Stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — Qualität, Filter, Optionen pro Chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — Hochpassfilter';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — verwendete SoundFont';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — Interpolation, Tiefpass, Echo';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — Panorama, Kopfhörer, Gain, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — Takt, Modell, ReSIDfp-Filter';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — harmonischer Stereo-/Surround-Modus';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, Hall';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612-, OPL3-, QSound-Cores…';

  @override
  String get settingsMasterVolume => 'Gesamtlautstärke';

  @override
  String get settingsAmigaFilter => 'Amiga-Filter';

  @override
  String get settingsInterpolation => 'Interpolation';

  @override
  String get settingsPolyphony => 'Polyphonie';

  @override
  String get settingsReverb => 'Nachhall';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Keine';

  @override
  String get settingsInterpLinear => 'Linear';

  @override
  String get settingsInterpCubic => 'Kubisch';

  @override
  String get settingsInterpSinc => 'Sinc (beste)';

  @override
  String get settingsStereoSeparation => 'Stereo-Trennung';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Beendet den Titel, wenn die Engine eine lange Stille erkennt';

  @override
  String get settingsStereoDepth => 'Stereo-Tiefe';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — keine Wirkung auf SPC';

  @override
  String get settingsBass => 'Bässe';

  @override
  String get settingsTreble => 'Höhen';

  @override
  String get settingsAppliedLive =>
      'Wird sofort angewendet, auch während der Wiedergabe.';

  @override
  String get settingsAppliedNextTrack =>
      'Wird beim nächsten geladenen Titel angewendet.';

  @override
  String get settingsSidEmulation => 'Emulation';

  @override
  String get settingsSidResidfp => 'ReSIDfp (genau)';

  @override
  String get settingsSidLite => 'SIDLite (schnell)';

  @override
  String get settingsSidSampling => 'Sampling';

  @override
  String get settingsSidSamplingInterp => 'Interpolation (schnell)';

  @override
  String get settingsSidSamplingResample => 'Resample (beste)';

  @override
  String get settingsSidClock => 'Takt';

  @override
  String get settingsSidModel => 'SID-Modell';

  @override
  String get settingsSidFilter => 'SID-Filter';

  @override
  String get settingsSidForceSecond => '2. SID erzwingen';

  @override
  String get settingsSidSecondSubtitle => 'Stereo-2SID-Titel';

  @override
  String get settingsSidSecondAddr => 'Adresse des 2. SID';

  @override
  String get settingsSidForceThird => '3. SID erzwingen';

  @override
  String get settingsSidThirdAddr => 'Adresse des 3. SID';

  @override
  String get settingsSidAutoFilter => '6581-Filterbereich automatisch';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Empfohlener Wert je nach Autor des Titels (sidplayfp-Tabellen)';

  @override
  String get settingsSid6581Range => '6581-Filterbereich';

  @override
  String get settingsSid6581Curve => '6581-Filterkurve';

  @override
  String get settingsSid8580Curve => '8580-Filterkurve';

  @override
  String get settingsSidNote =>
      'SID-Filter und -Kurven werden live angewendet; Emulation/Sampling/Takt/Modell/2.-3. SID beim nächsten Titel.';

  @override
  String get settingsAudioOutput => 'Audioausgabe';

  @override
  String get settingsAdplugNote =>
      'Surround: zwei leicht verstimmte OPL-Chips. Wird beim nächsten Titel angewendet.';

  @override
  String get settingsHeSpuMain => 'Hauptstimmen (SPU)';

  @override
  String get settingsHeSpuReverb => 'Hall (SPU)';

  @override
  String get settingsNsfQuality => 'Qualität (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Tiefpassfilter';

  @override
  String get settingsHighpassFilter => 'Hochpassfilter';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC erzwungen';

  @override
  String get settingsNsfRegionPalForced => 'PAL erzwungen';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy erzwungen';

  @override
  String get settingsNsfForceIrq => 'IRQ erzwingen';

  @override
  String get settingsNsfApu1Title => '2A03 — Pulse (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — Dreieck / Rauschen / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Beim Reset Stummschaltung aufheben';

  @override
  String get settingsNsfPhaseRefresh => 'Phase auffrischen';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Phase beim Schreiben der Periode zurücksetzen';

  @override
  String get settingsNsfNonlinearMixer => 'Nichtlineares Mischen';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'Die echte Mischung des 2A03 (sonst linear)';

  @override
  String get settingsNsfDutySwap => 'Duty Cycles tauschen';

  @override
  String get settingsNsfDutySwapSubtitle =>
      'Reihenfolge der 25-%- / 50-%-Duties';

  @override
  String get settingsNsfNegateSweep => 'Negativer Sweep bei der Init';

  @override
  String get settingsNsfEnable4011 => 'Register \$4011 aktiv';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Direkte DAC-Ausgabe (originale Klicks)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodisches Rauschen';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Kurzer Modus des Rauschgenerators';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM-Anti-Klick';

  @override
  String get settingsNsfRandomizeNoise =>
      'Rauschen bei der Init zufällig setzen';

  @override
  String get settingsNsfTriangleMute => 'Dreieck stummschalten';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Schaltet das Dreieck bei Ultraschall-Perioden stumm';

  @override
  String get settingsNsfRandomizeTri => 'Dreieck bei der Init zufällig setzen';

  @override
  String get settingsNsfDpcmReverse => 'Umgekehrtes DPCM';

  @override
  String get settingsNsfN163Serial => 'Serielles Multiplexing';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Das echte N163-Brummen bei mehrstimmigen Titeln';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Phase schreibgeschützt';

  @override
  String get settingsNsfN163LimitWavelength => 'Wellenlänge begrenzen';

  @override
  String get settingsNsfFdsCutoff => 'Tiefpass-Grenzfrequenz';

  @override
  String get settingsNsfFds4085Reset => '\$4085-Reset';

  @override
  String get settingsNsfFdsWriteProtect => 'Schreibschutz';

  @override
  String get settingsNsfVrc7Patch => 'Patch-Satz';

  @override
  String get settingsNsfVrc7Opll => 'OPLL-Modus';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Emuliert einen YM2413 statt des VRC7';

  @override
  String get settingsGbsHpFilter => 'Hochpassfilter (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klassischer GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Echo';

  @override
  String get settingsUadePostfx => 'Nachbearbeitung';

  @override
  String get settingsUadePostfxSubtitle =>
      'Aktiviert die Effektkette (für alles Weitere erforderlich)';

  @override
  String get settingsUadePan => 'Panorama (Stereo-Trennung)';

  @override
  String get settingsUadePanValue => 'Panorama-Wert';

  @override
  String get settingsUadeHeadphones => 'Kopfhörer';

  @override
  String get settingsUadeLed => 'LED (Paula-Filter)';

  @override
  String get settingsUadeLedAuto => 'Auto (pro Titel)';

  @override
  String get settingsUadeLedOn => 'Erzwungen EIN';

  @override
  String get settingsUadeLedOff => 'Erzwungen AUS';

  @override
  String get settingsUadeFilterType => 'Filtertyp';

  @override
  String get settingsUadeGain => 'Gain';

  @override
  String get settingsUadeGainValue => 'Gain-Wert';

  @override
  String get settingsSoundfontLoading => 'Katalog wird geladen…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Katalog nicht verfügbar ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String get settingsSoundfontImport => 'SoundFont importieren…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Eine .sf2-Datei auf diesem Gerät auswählen';

  @override
  String get settingsSoundfontImported => 'Importiert';

  @override
  String get settingsSoundfontInvalid =>
      'Diese Datei ist keine SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Import fehlgeschlagen — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Datei löschen';

  @override
  String get settingsCreditsHeader => 'Credits & Lizenzen';

  @override
  String get settingsRightsNotice =>
      'Rewamp ist ein Player: Es hostet keine Dateien und verbreitet keine Musik. Die Stücke stammen aus Online-Archiven zur Bewahrung und bleiben Eigentum ihrer Rechteinhaber. Sie sind selbst dafür verantwortlich, dass Anhören, Herunterladen und Aufbewahren mit den geltenden Rechten und den Gesetzen Ihres Landes vereinbar sind.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unterstützte Formate',
      one: '$count unterstütztes Format',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verteilt auf $count Wiedergabe-Engines — Details anzeigen',
      one: 'Von $count Wiedergabe-Engine abgedeckt — Details anzeigen',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga-Songlängen & -Metadaten';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb von Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64-/SID-Daten & Cover';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — Metadaten und Grafiken zu C64-Spielen.';

  @override
  String get settingsFt2FontTitle => 'FastTracker-2-Schrift';

  @override
  String get settingsFt2FontSubtitle =>
      'Der FastTracker-II-Stil des Pattern-Visualizers verwendet die FT2-Bitmap-Schrift aus ft2-clone von 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url kopiert';
  }

  @override
  String get settingsOpenLink => 'Link öffnen';

  @override
  String get settingsEnginesHeader => 'Wiedergabe-Engines';

  @override
  String get settingsComponentsHeader => 'Weitere Komponenten';

  @override
  String get settingsResetAll => 'Alle Einstellungen zurücksetzen';

  @override
  String get settingsResetAllSubtitle =>
      'Allgemein, Visualisierung, Wiedergabe, Engines — nicht die Mediathek';

  @override
  String get settingsResetAllTitle => 'Alle Einstellungen zurücksetzen?';

  @override
  String get settingsResetAllBody =>
      'Allgemein, Visualisierung, Wiedergabe und alle Engines kehren zu ihren Standardwerten zurück. Mediathek und Verlauf bleiben unverändert.';

  @override
  String get settingsRenewUserId => 'Anonyme Kennung erneuern';

  @override
  String get settingsRenewUserIdTitle => 'Anonyme Kennung erneuern?';

  @override
  String get settingsRenewUserIdBody =>
      'Für die Serverstatistiken wird eine neue anonyme Kennung erstellt.\n\nDie alte wird nicht mehr verwendet. Lokaler Verlauf und Favoriten bleiben unverändert.';

  @override
  String get settingsRenewUserIdFailed =>
      'Fehlgeschlagen — Server nicht erreichbar';

  @override
  String settingsNewUserId(String id) {
    return 'Neue Kennung: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Keine Kennung registriert';

  @override
  String get settingsCleanDb => 'Lokale Datenbank bereinigen';

  @override
  String get settingsCleanDbSubtitle =>
      'Entfernt Einträge, deren Datei nicht mehr existiert (gelöschte Downloads, alte Fehler)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verwaiste Einträge entfernt',
      one: '$count verwaister Eintrag entfernt',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'Lokale Datenbank ist sauber — nichts zu entfernen';

  @override
  String get settingsClearCache => 'Cache leeren (Cover & Metadaten)';

  @override
  String get settingsClearCacheSubtitle =>
      'Entfernt zwischengespeicherte Cover und abgerufene Metadaten (STIL, Songlängen) — werden bei der nächsten Wiedergabe erneut geladen';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cache geleert ($count Cover)',
      one: 'Cache geleert ($count Cover)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Statistik zurücksetzen';

  @override
  String get settingsResetStatsSubtitle =>
      'Entfernt den Wiedergabeverlauf und die Zähler';

  @override
  String get settingsClearStatsTitle => 'Statistik zurücksetzen?';

  @override
  String get settingsClearStatsBody =>
      'Dies löscht endgültig:\n• den gesamten Wiedergabeverlauf\n• die Wiedergabezähler\n\nFavoriten und Mediathek bleiben unverändert.';

  @override
  String get settingsStatsCleared => 'Statistik gelöscht';

  @override
  String get settingsResetDatabase => 'Datenbank zurücksetzen';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Löscht alles: Verlauf, Favoriten, Wiedergabelisten, Cache';

  @override
  String get settingsResetDbTitle => 'Datenbank zurücksetzen?';

  @override
  String get settingsResetDbBody =>
      'Dies löscht endgültig:\n• den gesamten Wiedergabeverlauf\n• alle Zähler\n• alle Favoriten\n• alle Wiedergabelisten\n• alle zwischengespeicherten Metadaten\n\nDeine Audiodateien werden nicht gelöscht.';

  @override
  String get settingsDbReset => 'Datenbank zurückgesetzt';

  @override
  String get settingsDeleteDownloads => 'Downloads löschen';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Löscht alle Dateien im Online-Ordner (Titel, Cover)';

  @override
  String get settingsDeleteDownloadsTitle => 'Downloads löschen?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Dies löscht endgültig alle geladenen Dateien (Titel, Alben, Cover) aus dem Online-Ordner.\n\nDie Datenbankeinträge bleiben erhalten, verweisen aber auf nicht mehr vorhandene Dateien.';

  @override
  String get settingsDownloadsDeleted => 'Downloads gelöscht';

  @override
  String get settingsColor => 'Farbe';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Zufälliges nächstes Preset';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Aus: die Presets der Reihe nach abspielen';

  @override
  String get settingsPmLockPreset => 'Preset sperren';

  @override
  String get settingsPmLockPresetSubtitle => 'Kein automatischer Wechsel';

  @override
  String get settingsPmPresetDuration => 'Zeit zwischen den Presets';

  @override
  String get settingsPmTransitions => 'Übergänge';

  @override
  String get settingsPmBlend => 'Überblendung';

  @override
  String get settingsPmBlendSubtitle => 'Aus: Presets sofort wechseln';

  @override
  String get settingsPmTransitionStyle => 'Übergangsstil';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Das Muster, das die Überblendung verwendet';

  @override
  String get settingsPmTransitionRandom => 'Zufällig';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Beat-synchroner Preset-Wechsel';

  @override
  String get settingsPmHardcutTime => 'Hardcut: Mindestzeit';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: Empfindlichkeit';

  @override
  String get settingsPmRendering => 'Rendering';

  @override
  String get settingsPmQuality => 'Qualität';

  @override
  String get settingsPmQualitySubtitle =>
      'Renderauflösung (Max = native Auflösung)';

  @override
  String get settingsPmBeatSensitivity => 'Beat-Empfindlichkeit';

  @override
  String get settingsPmAspectRatio => 'Seitenverhältnis beibehalten';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'Für die Shader, die es unterstützen';

  @override
  String get settingsPmPermissive => 'Permissiver Modus';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Lädt .milk-Dateien mit Skriptfehlern';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountSubtitle => 'Bibliothek sichern und synchronisieren';

  @override
  String get accountAnonymous => 'Anonymes Konto';

  @override
  String get accountAnonymousExplain =>
      'Favoriten und Verlauf liegen auf dem Server, aber nur dieses Gerät kommt daran. Mit einer E-Mail-Adresse findest du sie auch anderswo wieder.';

  @override
  String get accountEmailAttached =>
      'Adresse bestätigt — dieses Konto lässt sich wiederherstellen';

  @override
  String get accountEmailPending => 'Adresse noch nicht bestätigt';

  @override
  String get accountInsecureStorage =>
      'Der sichere Speicher dieses Geräts ist nicht verfügbar: die Konto-Kennung wird unverschlüsselt abgelegt.';

  @override
  String get accountSaveCta => 'Mein Konto sichern';

  @override
  String get accountStatSongs => 'Lieblingstitel';

  @override
  String get accountStatAlbums => 'Lieblingsalben';

  @override
  String get accountStatPlays => 'Wiedergaben';

  @override
  String get accountCreatedLabel => 'Erstellt';

  @override
  String get accountSignOut => 'Abmelden';

  @override
  String get accountRevoke => 'Überall abmelden';

  @override
  String get accountRevokeSubtitle => 'Meldet alle anderen Geräte ab';

  @override
  String get accountRevokeBody =>
      'Alle anderen Geräte werden abgemeldet. Dieses bleibt angemeldet.';

  @override
  String get accountRevokeDone => 'Andere Geräte abgemeldet';

  @override
  String get accountDelete => 'Konto löschen';

  @override
  String get accountDeleteSubtitle =>
      'Löscht das Konto und seine Daten auf dem Server. Unwiderruflich.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items Favoriten und $lists Playlists werden vom Server gelöscht. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Deine Downloads und die Bibliothek dieses Geräts bleiben unberührt.';

  @override
  String get accountDeleteDone => 'Konto gelöscht';

  @override
  String get accountSignOutSubtitle =>
      'Dieses Gerät startet mit einem neuen, leeren Konto';

  @override
  String get accountSignOutTitle => 'Abmelden?';

  @override
  String accountSignOutBody(String email) {
    return 'Du kannst mit einem Code an $email zu diesem Konto zurückkehren.';
  }

  @override
  String get accountSignedOut => 'Abgemeldet';

  @override
  String get accountNoSignOut => 'Abmelden nicht möglich';

  @override
  String get accountNoSignOutSubtitle =>
      'Ohne E-Mail-Adresse wäre dieses Konto endgültig verloren.';

  @override
  String get accountDetach => 'Adresse trennen';

  @override
  String get accountDetachSubtitle =>
      'Das Konto wird wieder anonym, es werden keine Daten gelöscht';

  @override
  String get accountDetachBody =>
      'Ohne Adresse lässt sich dieses Konto von einem anderen Gerät nicht mehr wiederfinden.';

  @override
  String get accountDetachDone => 'Adresse getrennt';

  @override
  String get accountOffline => 'Konto offline nicht verfügbar';

  @override
  String get accountEmailTitle => 'E-Mail-Adresse';

  @override
  String get accountEmailExplain =>
      'Wir senden dir einen 6-stelligen Code zur Bestätigung. Die Adresse dient nur der Wiederherstellung deines Kontos.';

  @override
  String get accountEmailLabel => 'E-Mail-Adresse';

  @override
  String get accountCodeTitle => 'Bestätigungscode';

  @override
  String accountCodeExplain(String email) {
    return 'Code an $email gesendet. Er gilt 10 Minuten.';
  }

  @override
  String get accountCodeLabel => '6-stelliger Code';

  @override
  String get accountSendCode => 'Code senden';

  @override
  String get accountVerify => 'Bestätigen';

  @override
  String get accountResend => 'Code erneut senden';

  @override
  String accountResendIn(int n) {
    return 'Erneut senden in $n s';
  }

  @override
  String get accountCheckSpam =>
      'Die E-Mail kann eine Minute brauchen — sieh auch im Spam-Ordner nach.';

  @override
  String get accountErrorInvalidEmail => 'Ungültige Adresse';

  @override
  String get accountErrorTooMany =>
      'Zu viele Anfragen, versuche es in ein paar Minuten erneut';

  @override
  String get accountErrorInvalidCode => 'Falscher oder abgelaufener Code';

  @override
  String get accountErrorCodeLength => 'Der Code hat 6 Ziffern';

  @override
  String get accountErrorNetwork =>
      'Verbindung fehlgeschlagen, bitte erneut versuchen';

  @override
  String get accountMergeTitle => 'Diese Bibliothek zusammenführen?';

  @override
  String accountMergeBody(String email) {
    return 'Favoriten und Verlauf dieses Geräts werden dem Konto $email hinzugefügt. Das lässt sich nicht rückgängig machen.';
  }

  @override
  String get accountMergeConfirm => 'Zusammenführen';

  @override
  String get accountCarryLocal => 'Favoriten dieses Geräts behalten';

  @override
  String accountCarryLocalOn(int n) {
    return 'Die $n Favoriten und die Playlists dieses Geräts werden dem Konto hinzugefügt.';
  }

  @override
  String get accountCarryLocalOff =>
      'Sie werden von diesem Gerät gelöscht und durch die des Kontos ersetzt. Heruntergeladene Dateien bleiben erhalten.';

  @override
  String get accountDropLocalTitle => 'Daten dieses Geräts löschen?';

  @override
  String get accountCreatedOk =>
      'Konto gesichert, deine Bibliothek ist geschützt';

  @override
  String get accountMergedOk =>
      'Angemeldet — deine lokalen Favoriten wurden übernommen';

  @override
  String get accountSignedInOk => 'Angemeldet';

  @override
  String get playlistEntryMissing => 'Datei auf diesem Gerät nicht vorhanden';

  @override
  String get playlistEntryMissingRestorable =>
      'Datei fehlt — kann erneut geladen werden';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fehlen',
      one: '$n fehlt',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'In meinem Konto sichern';

  @override
  String get playlistBackupSubtitle =>
      'Behält diese Playlist auch nach einer Neuinstallation';

  @override
  String get playlistBackupUpdate => 'Sicherung aktualisieren';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Ersetzt die Kontokopie durch diese Fassung';

  @override
  String get playlistBackupStop => 'Nicht mehr sichern';

  @override
  String get playlistBackupStopped => 'Sicherung entfernt';

  @override
  String get playlistBackupDone => 'Playlist gesichert';

  @override
  String get playlistBackupFailed => 'Sicherung fehlgeschlagen';

  @override
  String get playlistBackupNoAccount => 'Kein Konto auf diesem Gerät';

  @override
  String get playlistSyncTooltip => 'Mit meinem Konto abgleichen';

  @override
  String get playlistSyncRunning => 'Abgleich läuft…';

  @override
  String get playlistSyncDone => 'Playlists abgeglichen';

  @override
  String get playlistSyncPartial =>
      'Einige Playlists konnten nicht gesichert werden';

  @override
  String get playlistFetchMissing => 'Fehlende Titel herunterladen';

  @override
  String get playlistFetchDone => 'Fehlende Titel geladen';

  @override
  String get playlistFetchPartial =>
      'Einige Titel konnten nicht geladen werden';

  @override
  String get playlistEntryFetchFailed =>
      'Dieser Titel konnte nicht geladen werden';

  @override
  String get accountStatPlaylists => 'Playlists';

  @override
  String get accountSyncNow => 'Jetzt abgleichen';

  @override
  String get accountSyncAuto => 'Läuft von selbst im Hintergrund';

  @override
  String get accountSyncAnonymous =>
      'Auf dem Server gesichert. Für ein zweites Gerät eine E-Mail hinterlegen.';

  @override
  String get accountSyncPending => 'Änderungen warten auf den Versand';

  @override
  String accountSyncLast(String when) {
    return 'Letzter Abgleich: $when';
  }

  @override
  String get accountSyncDone => 'Abgleich abgeschlossen';

  @override
  String get accountSyncFailed => 'Abgleich fehlgeschlagen, wird wiederholt';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'Musik von $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'enthält den $place von $compo';
  }

  @override
  String get competitionEmpty => 'Dieser Wettbewerb hat keine Einträge';

  @override
  String get competitionEntryNoMusic =>
      'Zu diesem Eintrag gibt es keine Musik im Katalog';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Stücke',
      one: '$n Stück',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht\'s';

  @override
  String get onboardingBetaTitle => 'Beta-Version';

  @override
  String get onboardingBetaBody =>
      'Rewamp ist noch im Aufbau. Lokale Daten — Bibliothek, Playlists, Favoriten, Hörstatistiken — können vor Version 1.0 gelöscht werden. Deine Downloads sind sicher, aber sichere Wichtiges anderswo.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Version $version (Build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Entdecken';

  @override
  String get onboardingExploreBody =>
      'Durchsuche Zehntausende Chiptunes und Tracker-Module aus den großen Online-Archiven — nach Künstler, Album, Plattform oder Party. Antippen zum Hören, herunterladen zum Behalten.';

  @override
  String get onboardingLibraryTitle => 'Deine Bibliothek';

  @override
  String get onboardingLibraryBody =>
      'Speichere, was dir gefällt, erstelle Playlists und ordne sie in Ordnern. Heruntergeladenes läuft offline, und deine Bibliothek folgt dir nach der Anmeldung auf alle Geräte.';

  @override
  String get onboardingPlayerTitle => 'Der Player';

  @override
  String get onboardingPlayerBody =>
      'Wische zum Titelwechsel und öffne die Visualisierungen: Oszilloskop, Kanal-Scopes, scrollende Noten, Tracker-Raster. Mehrteilige Dateien zeigen ihre Subsongs, jede Stimme lässt sich einzeln stummschalten.';

  @override
  String get onboardingReplayTitle => 'Einführung';

  @override
  String get onboardingReplaySubtitle =>
      'Beta-Hinweis und Funktionstour erneut ansehen';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Tracker-Raster: Farben, Spalten, Scrollen';

  @override
  String get patternOpaqueBg => 'Undurchsichtiger Hintergrund';

  @override
  String get patternOpaqueBgSubtitle =>
      'Blendet das Cover hinter dem Raster aus';

  @override
  String get commonSave => 'Speichern';

  @override
  String get accountDisplayName => 'Öffentlicher Name';

  @override
  String get accountDisplayNameNotSet =>
      'Nicht festgelegt — nötig, um eine Playlist zu veröffentlichen';

  @override
  String get accountDisplayNameHint =>
      'Der Name, unter dem du genannt werden möchtest.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Eine Änderung schickt alle veröffentlichten Playlists zurück in die Prüfung.';

  @override
  String get accountDisplayNameTaken =>
      'Dieser Name ist vergeben. Wähle einen anderen.';

  @override
  String get accountDisplayNameLength => 'Zwischen 2 und 40 Zeichen.';

  @override
  String get accountDisplayNameSaved => 'Öffentlicher Name gespeichert';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Zurück in die Prüfung geschickte Playlists: $n';
  }

  @override
  String get playlistPublish => 'Öffentlich machen';

  @override
  String get playlistPublishSubtitle =>
      'Veröffentlichung beantragen (wird geprüft)';

  @override
  String get playlistPublishTitle => 'Diese Playlist veröffentlichen?';

  @override
  String get playlistPublishBody =>
      'Nach der Freigabe ist sie für alle sichtbar und wird deinem öffentlichen Namen zugeschrieben. Das Cover stammt aus den Titeln.';

  @override
  String get playlistPublishCta => 'Beantragen';

  @override
  String get playlistPublishSubmitted => 'Zur Prüfung gesendet';

  @override
  String get playlistPublishPending => 'Wartet auf Freigabe';

  @override
  String get playlistPublishApproved => 'Öffentlich';

  @override
  String playlistPublishRejected(String reason) {
    return 'Abgelehnt: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Abgelehnt';

  @override
  String get playlistPublishNeedName =>
      'Wähle den Namen, unter dem du genannt werden möchtest';

  @override
  String get playlistPublishNeedTracks =>
      'Zum Veröffentlichen sind mindestens 5 Titel nötig';

  @override
  String get playlistPublishHasLocal =>
      'Dateien von deinem Gerät können nicht veröffentlicht werden — andere können sie nicht abspielen';

  @override
  String get playlistPublishTooManyPending =>
      'Du hast bereits 3 Playlists in der Prüfung';

  @override
  String get playlistPublishRefused =>
      'Veröffentlichung abgelehnt: prüfe die Titel und die offenen Anträge';

  @override
  String get playlistPublishFailed => 'Veröffentlichung fehlgeschlagen';

  @override
  String get playlistPublishWithdrawn => 'Die Playlist ist wieder privat';

  @override
  String get playlistUnpublish => 'Privat machen';

  @override
  String get playlistUnpublishSubtitle =>
      'Entfernt sie aus den öffentlichen Playlists';

  @override
  String get playlistRenamePublishedTitle =>
      'Veröffentlichte Playlist umbenennen?';

  @override
  String get playlistRenamePublishedBody =>
      'Geprüft wird der Name: Umbenennen schickt die Playlist zurück in die Prüfung und nimmt sie so lange offline. Titel hinzufügen oder umsortieren nicht.';

  @override
  String playlistByAuthor(String author) {
    return 'von $author';
  }

  @override
  String get settingsSpectrumMode => 'Spektrum-Modus';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Farbig';

  @override
  String get settingsSpectrumModeBeam => 'Strahl';

  @override
  String get settingsSpectrumModeLine => 'Linie';

  @override
  String get settingsSpectrumModeRing => 'Ring';

  @override
  String get releaseNotesTitle => 'Neuerungen';

  @override
  String get releaseNotesV4Downloads =>
      'Downloads: ein langer lässt sich laufend abbrechen, und ein Albumarchiv wird nicht mehr mehrfach geladen.';

  @override
  String get releaseNotesV4Queue =>
      'Warteschlange: eine Schaltfläche zum Leeren, mit Rückfrage — sie stoppt auch die Wiedergabe.';

  @override
  String get releaseNotesV4DropFiles =>
      'Auf das Fenster gezogene Dateien: jetzt, als Nächstes oder am Ende abspielen; Cover und Begleitdateien bleiben draußen, und eine im Archiv mitgelieferte Wiedergabeliste wird beachtet (echte Titel, keine toten Einträge).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: eigene SoundFont vom Gerät importieren, neben denen vom Server.';

  @override
  String get releaseNotesV4Formats =>
      'Wwise-, FSB- und OGL-Spielstreams spielen endlich (eigenes Vorbis).';

  @override
  String get releaseNotesV4Chips =>
      'Sechs weitere Soundchips, ein wählbarer Emulationskern pro Chip (SameBoy für Game Boy) und korrekte Tonhöhe bei Sample-Chips.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: .vt2 spielt, und Noten- und Patternansicht decken die ganze ZX-Familie ab.';

  @override
  String get releaseNotesV4Loop =>
      'Titel wiederholen loopt das Stück wirklich, statt es neu zu laden, und der Zähler friert bei Endlosschleife nicht mehr ein.';

  @override
  String get releaseNotesV4Info =>
      'Das ⓘ-Panel listet die Dateien, die ein Stück wirklich geöffnet hat — samt Begleitern und Bibliotheken.';

  @override
  String get releaseNotesV4Linux => 'Linux-Desktop-Version.';

  @override
  String get releaseNotesDataReset =>
      'Die lokalen Daten wurden für diese Beta zurückgesetzt. Mediathek und Playlists werden aus dem Konto wiederhergestellt; Downloads müssen erneut erfolgen.';

  @override
  String get releaseNotesDismiss => 'Weiter';

  @override
  String get pmManagePresets => 'Presets verwalten';

  @override
  String get pmPickTooltip => 'Preset auswählen';

  @override
  String get pmPickFilter => 'Presets filtern';

  @override
  String get pmSourceTooltip => 'Preset-Quelle';

  @override
  String get pmAddToPlaylistTooltip =>
      'Preset zu einer Wiedergabeliste hinzufügen';

  @override
  String pmSlowPresetDropped(String name) {
    return '„$name“ ist für dieses Gerät zu aufwendig und wurde aussortiert.';
  }

  @override
  String get pmSlowDeviceTitle => 'Dieses Gerät ist zu langsam';

  @override
  String get pmSlowDeviceOff =>
      'Der Visualizer wurde abgeschaltet: Dieses Gerät kommt mit Milkdrop-Presets nicht mit.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Presets aussortiert',
      one: '1 Preset aussortiert',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Auf diesem Gerät zu langsam. Die Wiedergabe überspringt sie.';

  @override
  String get settingsPmSlowPresetsRestore => 'Wiederherstellen';

  @override
  String get pmSourceBundled => 'Integrierte Presets';

  @override
  String get pmSourceImports => 'Meine Importe';

  @override
  String get pmSourceAll => 'Alle Presets';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Presets',
      one: '$count Preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Neue Wiedergabeliste…';

  @override
  String get pmPlaylistName => 'Name der Wiedergabeliste';

  @override
  String get pmAddedToPlaylist => 'Zur Wiedergabeliste hinzugefügt';

  @override
  String get pmAlreadyInPlaylist => 'Bereits in dieser Wiedergabeliste';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Durchsuchen';

  @override
  String get pmTabPlaylists => 'Wiedergabelisten';

  @override
  String get pmTabPopular => 'Beliebt';

  @override
  String get pmTabSetAside => 'Aussortiert';

  @override
  String get pmSetAsideEmpty =>
      'Nichts aussortiert. Presets, bei denen dieses Gerät unter 6 fps fällt, landen hier.';

  @override
  String get pmSetAsideRestoreAll => 'Alle wiederherstellen';

  @override
  String get pmInstall => 'Installieren';

  @override
  String get pmInstallQueued => 'Installation eingereiht';

  @override
  String get pmUninstall => 'Deinstallieren';

  @override
  String get pmUninstalled => 'Pack entfernt';

  @override
  String get pmUse => 'Verwenden';

  @override
  String get pmDefaultPackBanner => 'Empfohlenes Starterpack';

  @override
  String pmLicense(String license) {
    return 'Lizenz: $license';
  }

  @override
  String get pmPacksOffline => 'Server nicht erreichbar';

  @override
  String get pmSearchPresets => 'Presets suchen…';

  @override
  String get pmPlayNow => 'Jetzt abspielen';

  @override
  String get pmDownloadAction => 'Herunterladen';

  @override
  String get pmDownloaded => 'Preset heruntergeladen';

  @override
  String get pmDownloadFailed => 'Download fehlgeschlagen';

  @override
  String pmPreviewing(String name) {
    return 'Wiedergabe: $name';
  }

  @override
  String get pmLocalSection => 'Meine Wiedergabelisten';

  @override
  String get pmCuratedSection => 'Rewamp-Wiedergabelisten';

  @override
  String get pmImportPlaylist => 'Herunterladen und verwenden';

  @override
  String get pmPlaylistImported => 'Wiedergabeliste bereit';

  @override
  String get pmImportFiles => 'Dateien importieren…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Presets importiert',
      one: '$count Preset importiert',
      zero: 'Kein Preset importiert',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets zur projectM-Bibliothek hinzugefügt';

  @override
  String get pmNoPlaylists => 'Noch keine Preset-Wiedergabelisten';

  @override
  String get pmSourceApplied => 'Preset-Quelle angewendet';

  @override
  String get pmPlaylistEmpty => 'Diese Wiedergabeliste ist leer';

  @override
  String get pmDays7 => '7 Tage';

  @override
  String get pmDays30 => '30 Tage';

  @override
  String get pmDays365 => '1 Jahr';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben',
      one: '$count Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Installation fehlgeschlagen';

  @override
  String get pmSingleDownloads => 'Einzelne Downloads';

  @override
  String pmAvailableIn(String pack) {
    return 'Verfügbar in $pack';
  }

  @override
  String get pmCleanUp => 'Aufräumen';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Presets gelöscht',
      one: '$count Preset gelöscht',
      zero: 'Nichts aufzuräumen',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Dieses Preset sperren';

  @override
  String get pmUnlockAction => 'Preset entsperren';

  @override
  String get pmOrderRandom => 'Presets zufällig';

  @override
  String get pmOrderSequential => 'Presets der Reihe nach';

  @override
  String get pmUpdateAvailable => 'Update verfügbar';

  @override
  String get pmUpdate => 'Aktualisieren';

  @override
  String get pmSelectAll => 'Alle auswählen';

  @override
  String get pmSelectNone => 'Auswahl aufheben';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '$count ausgewählt',
      zero: 'Nichts ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Nicht genutzte Texturen';

  @override
  String pmTexturesFreed(String size) {
    return '$size freigegeben';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Texturen',
      one: '$count Textur',
    );
    return '$_temp0';
  }
}
