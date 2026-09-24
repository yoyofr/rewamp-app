// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get navHome => 'Start';

  @override
  String get navSearch => 'Zoeken';

  @override
  String get navLocal => 'Lokaal';

  @override
  String get settingsTabsOrderTitle => 'Volgorde van tabbladen';

  @override
  String get settingsTabsOrderSubtitle =>
      'Sleep om te ordenen. De eerste vier staan in de onderbalk, de rest onder “Meer”.';

  @override
  String get settingsTabsInBar => 'In de balk';

  @override
  String get settingsTabsInMore => 'Onder “Meer”';

  @override
  String get settingsLaunchTab => 'Tabblad bij starten';

  @override
  String get settingsLaunchTabSubtitle => 'Met welk tabblad de app opent';

  @override
  String get navLibrary => 'Bibliotheek';

  @override
  String get noFileSelected => 'Geen bestand geselecteerd';

  @override
  String get openFile => 'Bestand openen';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Formaat niet ondersteund';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Niet-ondersteund formaat: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Niet op dit apparaat: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Bestand niet meer op de server: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file zit niet in het archief van het album — de rip noemt het bestand maar levert het niet.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host reageerde niet. Controleer je verbinding en probeer het opnieuw.';
  }

  @override
  String get failedToLoadFile => 'Kan het bestand niet laden';

  @override
  String get libraryEmptyHint =>
      'Je artiesten, albums en afspeellijsten\nverschijnen hier.';

  @override
  String get libraryPlaylists => 'Afspeellijsten';

  @override
  String get libraryArtists => 'Artiesten';

  @override
  String get libraryAlbums => 'Albums';

  @override
  String get libraryTracks => 'Nummers';

  @override
  String get libraryFavorites => 'Favorieten';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatische afspeellijst met je favoriete nummers';

  @override
  String get libraryRecentlyAdded => 'Onlangs toegevoegd';

  @override
  String get libraryEmpty => 'Nog niets hier';

  @override
  String get libraryRemoved => 'Verwijderd uit bibliotheek';

  @override
  String get searchHint => 'Zoeken…';

  @override
  String get searchTypePlaceholder => 'Typ een titel, artiest of album…';

  @override
  String get searchNoResults => 'Geen resultaten';

  @override
  String get searchDownloading => 'Downloaden…';

  @override
  String searchError(String message) {
    return 'Fout: $message';
  }

  @override
  String get tabAll => 'Nummers';

  @override
  String get tabArtists => 'Artiesten';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabProductions => 'Producties';

  @override
  String get filterWithVideo => 'Met video';

  @override
  String get videoUnavailable => 'Deze video is niet beschikbaar';

  @override
  String get noItems => 'Geen items';

  @override
  String get sortRelevance => 'Relevantie';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Onlangs afgespeeld';

  @override
  String get noRecentTracks => 'Geen onlangs afgespeelde nummers';

  @override
  String get playerSourceLocal => 'lokaal';

  @override
  String get homePlayFiles => 'Bestanden afspelen';

  @override
  String get homePlayFolder => 'Map afspelen';

  @override
  String get homeSectionsOrderTitle => 'Volgorde van secties';

  @override
  String get homeSectionsOrderSubtitle =>
      'Sleep om het startscherm naar wens te ordenen.';

  @override
  String get homeSectionsOrderReset => 'Standaardvolgorde';

  @override
  String get homeSectionsOrderSettings => 'Volgorde van startsecties';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total resultaten';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded geladen…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded resultaten';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded geladen — scroll voor meer';
  }

  @override
  String countNLoaded(int n) {
    return '$n geladen';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n bestand(en)';
  }

  @override
  String get browseFilterByTitle => 'Filter op titel…';

  @override
  String get browseNoSongs => 'Geen nummers beschikbaar';

  @override
  String get browseByFormat => 'Op formaat';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filter op formaat…';

  @override
  String get browseByPlatform => 'Op platform';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Platformnaam…';

  @override
  String get browseByChip => 'Op geluidschip';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'bijv. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Op artiest';

  @override
  String get browseByArtistSubtitle => 'Blader door de componisten';

  @override
  String get browseFilterByName => 'Filter op naam…';

  @override
  String get browseNoArtistFound => 'Geen artiest gevonden';

  @override
  String get browseNoArtistsAvailable => 'Geen artiesten beschikbaar';

  @override
  String get browseNoArtist => 'Geen artiesten';

  @override
  String get browseNoAlbum => 'Geen albums';

  @override
  String get browseTopPacks => 'Top packs';

  @override
  String get browseTopPacksSubtitle => 'De best beoordeelde packs';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Top packs — $collection';
  }

  @override
  String get browseLatestPacks => 'Nieuwste packs';

  @override
  String get browseLatestPacksSubtitle => 'De meest recente toevoegingen';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Nieuwste packs — $collection';
  }

  @override
  String get browseAllSongs => 'Alle nummers';

  @override
  String get browseAllSongsSubtitleAlpha => 'Blader in alfabetische volgorde';

  @override
  String get browseAlphabetical => 'In alfabetische volgorde';

  @override
  String browseAllLabel(String collection) {
    return 'Alle — $collection';
  }

  @override
  String get browseCollections => 'Collecties';

  @override
  String browseFilesCount(String count) {
    return '$count bestanden';
  }

  @override
  String get browseIndexing => 'Bezig met indexeren';

  @override
  String browseFilterFacet(String name) {
    return 'Filter $name…';
  }

  @override
  String get browseAllYears => 'Alle jaren';

  @override
  String get browseAllYearsSubtitle => 'Alle nummers van de party';

  @override
  String get browseNoCompo => 'Geen compo geïndexeerd voor deze party.';

  @override
  String get browseOthers => 'Overige';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n inzendingen — ranglijst',
      one: '$n inzending — ranglijst',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Afspeellijst afspelen';

  @override
  String get browsePlayAllRanked =>
      'Alles afspelen (op volgorde van de ranglijst)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers — volgorde van de ranglijst',
      one: '$n nummer — volgorde van de ranglijst',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Blader per album';

  @override
  String get browsePlayAll => 'Alles afspelen';

  @override
  String get browseShuffle => 'Shuffle';

  @override
  String get browseSearchInFolder => 'Zoek in deze map…';

  @override
  String get browseFilterThisList => 'Deze lijst filteren…';

  @override
  String get browseSearchSubfolders => 'In submappen zoeken';

  @override
  String get browseEmptyFolder => 'Lege map';

  @override
  String browsePlaybackError(String message) {
    return 'Afspelen mislukt: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Weergave';

  @override
  String get browseViewList => 'Lijst';

  @override
  String get browseViewGrid => 'Raster';

  @override
  String get browseViewGridCompact => 'Compact raster';

  @override
  String get browseSearchAlbum => 'Zoek een album…';

  @override
  String get browseSearchArtist => 'Zoek een artiest…';

  @override
  String get browsePlayAlbum => 'Album afspelen';

  @override
  String get searchDownloadingAlbum => 'Album downloaden…';

  @override
  String get searchCategoryChip => 'Chips';

  @override
  String get searchCategoryGroup => 'Groepen';

  @override
  String get artistRealName => 'Echte naam';

  @override
  String get artistAliases => 'Aliassen';

  @override
  String get artistBorn => 'Geboren';

  @override
  String get artistInterview => 'Interview';

  @override
  String get audioOutput => 'Audio-uitvoer';

  @override
  String get audioOutputSystemDefault => 'Systeemstandaard';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notities';

  @override
  String get notePlacedBadge => 'Geplaatst in de compo';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count leden',
      one: '$count lid',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Nummers bekijken';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modules',
      one: '$count module',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Parties';

  @override
  String get searchCategoryYear => 'Jaar';

  @override
  String get searchCategoryOrigin => 'Herkomst';

  @override
  String get searchCategoryProduction => 'Productie';

  @override
  String get searchCategoryProductionType => 'Prod-types';

  @override
  String get searchCategoryPublisher => 'Uitgevers';

  @override
  String get searchCategoryDeveloper => 'Ontwikkelaars';

  @override
  String get searchCategoryArcadeBoard => 'Arcadeborden';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'via de artiest';

  @override
  String get searchViaAlbum => 'via een album';

  @override
  String get searchViaSong => 'via een nummer';

  @override
  String get searchSortPopular => 'Populair';

  @override
  String get searchSortYear => 'Jaar';

  @override
  String get searchSortRandom => 'Willekeurig';

  @override
  String get searchSortRating => 'Beoordeling';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stemmen',
      one: '$count stem',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Oplopend';

  @override
  String get searchSortDesc => 'Aflopend';

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchExactSearch => 'Exact zoeken';

  @override
  String get searchExactSearchSubtitle =>
      'Schakelt het benaderende (fuzzy) zoeken uit';

  @override
  String get searchTags => 'Tags';

  @override
  String searchTagSearchHint(String category) {
    return 'Zoek een tag in « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Typ om tags te zoeken.';

  @override
  String get searchTagsAndLogic => 'Meerdere tags = logische EN.';

  @override
  String get searchFilterYear => 'Jaar';

  @override
  String get searchFilterAll => 'alle';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filteren op jaar sluit nummers zonder datum uit.';

  @override
  String get searchMinRating => 'Beoordeling ≥';

  @override
  String get searchPodium => 'Podium';

  @override
  String get searchPodiumAny => 'Elke podiumplaats';

  @override
  String get searchPodiumUnavailable =>
      'Het podiumfilter is nog niet beschikbaar op de server';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Annuleren';

  @override
  String get searchReset => 'Reset';

  @override
  String get searchApply => 'Toepassen';

  @override
  String get searchClearRecent => 'Recente zoekopdrachten wissen';

  @override
  String get searchBrowse => 'Bladeren';

  @override
  String get searchBrowseHint =>
      'Kies een facet (groep, chip, jaar…) om de catalogus te verkennen, of start hierboven Radio/Verrassing.';

  @override
  String get searchDidYouMean =>
      'Weinig resultaten — een benaderende zoekopdracht proberen?';

  @override
  String get searchYes => 'Ja';

  @override
  String get featuredCommunityTitle => 'Nieuw van de community';

  @override
  String get searchPlaylistSourceAll => 'Alle';

  @override
  String get searchPlaylistSourceUser => 'Community';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formaat';

  @override
  String get searchPlatform => 'Platform';

  @override
  String get filterCollection => 'Collectie';

  @override
  String get videoWatchDemo => 'Demo bekijken';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Collectie: $name';
  }

  @override
  String get searchCollectionAll => 'Alle';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip =>
      'Willekeurige wachtrij op basis van de huidige filters';

  @override
  String get searchSurprise => 'Verrassing';

  @override
  String get searchSurpriseTooltip => 'Een willekeurig nummer';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Geen nummers';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albums',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Kies een collectie';

  @override
  String get searchFilterCollections => 'Filter collecties…';

  @override
  String get searchFilterPlaceholder => 'Filter…';

  @override
  String searchAllOf(String label) {
    return 'Alle ($label)';
  }

  @override
  String get searchNoMatch => 'Geen overeenkomst';

  @override
  String get searchNoPlaylist => 'Geen afspeellijsten';

  @override
  String get engineDescOpenmpt => 'Tracker-modules (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Modules die libopenmpt niet leest (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — geluidschips, scope per kanaal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN-archieven';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — stemmen per kanaal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp-engine)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX-chiptunes (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Multi-chip chiptunes .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amiga custom-chip-formaten via 68k-emulatie (~320 ext.)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Standaard MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ-synth (16 stemmen)';

  @override
  String get engineDescV2m => 'V2M-synth (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — echte 68000-emulatie + YM2149 + STE-DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300-emulatie + RSP-audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ-emulatie';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound-chip';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — echte AY-3-8910/YM2149-synth';

  @override
  String get engineDescOrganya => 'Cave Story .org — de eigen engine van Pixel';

  @override
  String get engineDescPxtone => 'Tracker van Pixel — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — echte 68000 via emu68';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA-FM + SSG + PPZ8-samples';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ .pdx-samples), YM2151-FM';

  @override
  String get engineDescFmp => 'PC-98 FMP-driver — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612-FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Gestreamde game-audioformaten (700+, incl. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — terugvaldecoder';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total nummers',
      one: '$loaded / 1 nummer',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total albums',
      one: '$loaded / 1 album',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total artiesten',
      one: '$loaded / 1 artiest',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albums',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artiesten',
      one: '$n artiest',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n groepen',
      one: '$n groep',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Landen';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n landen',
      one: '$n land',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Mappen';

  @override
  String get featuredTitle => 'Vandaag uitgelicht';

  @override
  String featuredPartyNow(String party) {
    return '$party is nu bezig — podiums van eerdere edities';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party begint over $days dagen — podiums van eerdere edities',
      one: '$party begint morgen — podiums van eerdere edities',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'Het is $series-seizoen — podiums van eerdere edities';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Uitgebracht in $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age jaar geleden: de games van $year',
      one: 'Eén jaar geleden: de games van $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'De jaren $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age jaar geleden: de games van $year',
      one: 'Eén jaar geleden: de games van $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Uitgebracht in $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Jubilea';

  @override
  String get featuredBirthdayHeader => 'Verjaardagen van vandaag';

  @override
  String get featuredBirthdayWeekHeader => 'Verjaardagen deze week';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist is deze week jarig';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count afspeellijsten',
      one: '$count afspeellijst',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Opnieuw proberen';

  @override
  String get commonOptions => 'Opties';

  @override
  String get commonDownload => 'Downloaden';

  @override
  String get commonDeleteDownload => 'Download verwijderen';

  @override
  String get commonAddToPlaylist => 'Voeg toe aan afspeellijst';

  @override
  String get commonPlayNext => 'Speel hierna af';

  @override
  String get commonAddToQueueEnd => 'Voeg toe aan einde van wachtrij';

  @override
  String get commonAddToFavorites => 'Voeg toe aan favorieten';

  @override
  String get commonRemoveFromFavorites => 'Verwijder uit favorieten';

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
  String get subsongDeleteDownloadTitle => 'Deze download verwijderen?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Het bestand en de bijbehorende lokale gegevens (geschiedenis, nummers) worden verwijderd.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Kan de nummers niet lezen';

  @override
  String subsongTrackNumber(int number) {
    return 'Nummer $number';
  }

  @override
  String get subsongDefaultTrack => 'Standaardnummer';

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subsongs',
      one: '$count subsong',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Alles afspelen';

  @override
  String get albumDownloading => 'Album downloaden…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Album downloaden… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Download het album om de nummers te zien';

  @override
  String get albumNotDownloadedHint =>
      'Album niet gedownload — start het afspelen om het te downloaden';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nummers',
      one: '$count nummer',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Details laden…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Album afspelen';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Speel dit nummer eerst af vanuit de zoekresultaten om het te downloaden';

  @override
  String get libraryAddedTrack => 'Nummer toegevoegd aan je bibliotheek';

  @override
  String get libraryAddedAlbum => 'Album toegevoegd aan je bibliotheek';

  @override
  String get libraryAddedArtist => 'Artiest toegevoegd aan je bibliotheek';

  @override
  String get libraryRemovedTrack => 'Nummer verwijderd uit je bibliotheek';

  @override
  String get libraryRemovedAlbum => 'Album verwijderd uit je bibliotheek';

  @override
  String get libraryRemovedArtist => 'Artiest verwijderd uit je bibliotheek';

  @override
  String get libraryImportBeforeAddTitle => 'Eerst importeren?';

  @override
  String get libraryImportBeforeAddBody =>
      'Dit bestand speelt vanaf een tijdelijke locatie die het systeem kan legen. Importeren in je lokale bibliotheek zodat het item blijft bestaan?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'Dit nummer komt uit een archief dat naar een tijdelijke cache is uitgepakt. Het hele archief wordt in je lokale bibliotheek geïmporteerd, inclusief bijbehorende bestanden.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'Kan dit nummer niet toevoegen: de catalogus-id is onbekend op dit apparaat.';

  @override
  String songTilePlayFailed(String message) {
    return 'Afspelen mislukt: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Download mislukt — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Downloaden — $label';
  }

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmpty => 'Geen wachtende downloads';

  @override
  String get downloadsPause => 'Pauzeren';

  @override
  String get downloadsResume => 'Hervatten';

  @override
  String get downloadsCancel => 'Download annuleren';

  @override
  String get downloadsClear => 'Alles verwijderen';

  @override
  String get downloadsPausedBanner =>
      'Downloads gepauzeerd — het huidige bestand wordt eerst afgerond';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Downloaden — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Afspeellijst';

  @override
  String get miniPlayerHideQueue => 'Afspeellijst verbergen';

  @override
  String get transportShuffle => 'Shuffle';

  @override
  String get transportShuffleOn => 'Shuffle aan';

  @override
  String get transportLoopOff => 'Herhalen uit';

  @override
  String get transportLoopQueue => 'Herhaal: wachtrij';

  @override
  String get transportLoopTrack => 'Herhaal: huidige nummer';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spectrum';

  @override
  String get vizVoices => 'Stemmen';

  @override
  String get vizNotes => 'Noten';

  @override
  String get vizPiano => 'Piano';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Scrollmodus';

  @override
  String get patternSmoothScroll => 'Vloeiend scrollen';

  @override
  String get patternPinnedRow => 'Actieve regel vastgezet';

  @override
  String get patternVolumeBars => 'Volumebalken';

  @override
  String get patternColorScheme => 'Kleurenschema';

  @override
  String get patternSize => 'Grootte';

  @override
  String get patternColumns => 'Kolommen';

  @override
  String get patternColumnsAll => 'Volledig';

  @override
  String get patternColumnsNoteInstr => 'Beperkt';

  @override
  String get patternColumnsNote => 'Minimaal';

  @override
  String get vizClose => 'Visualizer sluiten';

  @override
  String get vizFullscreen => 'Volledig scherm';

  @override
  String get vizExitFullscreen => 'Volledig scherm verlaten';

  @override
  String get vizPrevPreset => 'Vorige preset';

  @override
  String get vizNextPreset => 'Volgende preset';

  @override
  String get vizProjectmUnavailable => 'projectM niet beschikbaar';

  @override
  String get voicesTitle => 'Stemmen';

  @override
  String get voicesNone => 'Geen stemmen voor dit nummer.';

  @override
  String get voicesLongPressSolo => 'lang indrukken = solo';

  @override
  String get voicesMuteAll => 'Alles dempen';

  @override
  String get voicesUnmuteAll => 'Alles inschakelen';

  @override
  String get voicesStereoOutput => 'Stereo-uitvoer';

  @override
  String get voicesLeft => 'Links';

  @override
  String get voicesRight => 'Rechts';

  @override
  String get enginesFormatsTitle => 'Afspeelbare formaten';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats afspeelbare formaten, verdeeld over $engines afspeelengines.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formaten',
      one: '$count formaat',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Cover van $title van $artist';
  }

  @override
  String stilCover(String work) {
    return 'Cover van $work';
  }

  @override
  String get playerQueue => 'Wachtrij';

  @override
  String get queueEdit => 'Bewerken';

  @override
  String get queueEditDone => 'Klaar';

  @override
  String get queueClear => 'Wachtrij wissen';

  @override
  String get queueClearConfirmTitle => 'Wachtrij wissen?';

  @override
  String get queueClearConfirmBody =>
      'De wachtrij wordt geleegd en het afspelen stopt.';

  @override
  String get queueClearConfirm => 'Wissen';

  @override
  String get queueRemoveSelected => 'Selectie verwijderen';

  @override
  String get queueRemoveTrack => 'Uit de wachtrij verwijderen';

  @override
  String get queueReorder => 'Herschikken';

  @override
  String get playerArtwork => 'Artwork';

  @override
  String get playerVisualizer => 'Visualizer';

  @override
  String get playerVoices => 'Stemmen';

  @override
  String get playerTrackInfo => 'Nummerinfo';

  @override
  String get playerShowQueue => 'Afspeellijst';

  @override
  String get playerHideQueue => 'Afspeellijst verbergen';

  @override
  String get playerNoTrackInfo => 'Geen informatie beschikbaar.';

  @override
  String get playerViewSubsongs => 'Bekijk de subsongs';

  @override
  String get playerViewAlbum => 'Bekijk het album';

  @override
  String get playerViewArtist => 'Bekijk de artiest';

  @override
  String get playerAddToPlaylist => 'Voeg toe aan afspeellijst';

  @override
  String get playerEngineSettings => 'Engine-instellingen';

  @override
  String get queueAddToPlaylist => 'Wachtrij aan een afspeellijst toevoegen';

  @override
  String get playerMoreOptions => 'Meer opties';

  @override
  String get playerClose => 'Sluiten';

  @override
  String get playerCancel => 'Annuleren';

  @override
  String get playerDelete => 'Verwijderen';

  @override
  String get playerAddFavorite => 'Voeg toe aan favorieten';

  @override
  String get playerRemoveFavorite => 'Verwijder uit favorieten';

  @override
  String get playerAddToLibrary => 'Voeg toe aan bibliotheek';

  @override
  String get playerRemoveFromLibrary => 'Verwijder uit bibliotheek';

  @override
  String get playerAddedToLibrary => 'Nummer toegevoegd aan de bibliotheek';

  @override
  String get playerRemovedFromLibrary => 'Nummer verwijderd uit de bibliotheek';

  @override
  String get playerDeleteDownload => 'Download verwijderen';

  @override
  String get playerRedownload => 'Bestand opnieuw downloaden';

  @override
  String get playerRedownloadUnavailable =>
      'Opnieuw downloaden niet beschikbaar voor dit bestand';

  @override
  String get playerDeleteDownloadTitle => 'Download verwijderen?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Het bestand en de bijbehorende lokale gegevens (geschiedenis, nummers) worden verwijderd.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Jouw trends';

  @override
  String get homeYourAllTimeTop => 'Jouw aller tijden-top';

  @override
  String get homeTrending => 'Trending';

  @override
  String get homeFeaturedPlaylists => 'Uitgelichte afspeellijsten';

  @override
  String get homeAllTimeTop => 'Top aller tijden';

  @override
  String get homePeriod7d => '7 d';

  @override
  String get homePeriod30d => '30 d';

  @override
  String get homePeriod90d => '90 d';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n keer afgespeeld',
      one: '$n keer afgespeeld',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Lege of onleesbare afspeellijst';

  @override
  String get homeExtractingArchive => 'Archief uitpakken…';

  @override
  String get homeArchiveEmpty => 'Geen afspeelbare bestanden in het archief';

  @override
  String get homeNothingPlayable => 'Niets afspeelbaars in de selectie';

  @override
  String get homeAlbumLoadFailed => 'Kan dit album niet laden';

  @override
  String get homeSongLoadFailed => 'Kan dit nummer niet laden';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Instellingen';

  @override
  String get playlistMoveUp => 'Naar bovenliggende map';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlists',
      one: '$n playlist',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n submappen',
      one: '$n submap',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Deze map en de volledige inhoud worden definitief verwijderd:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Deze map wordt verwijderd.';

  @override
  String get playlistFolderRoot => 'Hoofdmap';

  @override
  String get playlistMoveToFolder => 'Naar map verplaatsen';

  @override
  String playlistDeleteTitle(String name) {
    return '\"$name\" verwijderen?';
  }

  @override
  String get playlistDeleteBody =>
      'Deze afspeellijst wordt definitief verwijderd.';

  @override
  String get playlistRenameFolderTitle => 'Map hernoemen';

  @override
  String get playlistClearFavorites => 'Alle favorieten verwijderen';

  @override
  String get playlistClearFavoritesTitle => 'Alle favorieten verwijderen?';

  @override
  String get playlistClearFavoritesBody =>
      'Je verliest al je favoriete nummers. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get playlistRemoveFromLibrary => 'Uit bibliotheek verwijderen';

  @override
  String get playlistServerReadOnly => 'Serverplaylist · alleen-lezen';

  @override
  String get navAbout => 'Over';

  @override
  String get navMore => 'Meer';

  @override
  String get shellAlbumQueuedAtEnd =>
      'Album toegevoegd aan het einde van de wachtrij';

  @override
  String get shellAlbumQueuedNext => 'Album wordt hierna afgespeeld';

  @override
  String get shellAddingToQueue => 'Toevoegen aan de wachtrij…';

  @override
  String get shellAddingNext => 'Toevoegen om hierna af te spelen…';

  @override
  String shellDownloadFailed(String error) {
    return 'Download mislukt: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nummers aan de wachtrij toegevoegd',
      one: '$count nummer aan de wachtrij toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" toegevoegd aan het einde van de wachtrij';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" wordt hierna afgespeeld';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Download mislukt: $title — door naar het volgende nummer';
  }

  @override
  String get shellNetworkUnavailable =>
      'Afspelen gestopt: het netwerk lijkt niet beschikbaar te zijn.';

  @override
  String get statsTitle => 'Statistieken';

  @override
  String statsPeriodDays(int n) {
    return '$n dagen';
  }

  @override
  String get statsPeriodThisYear => 'Dit jaar';

  @override
  String get statsPeriodAll => 'Alles';

  @override
  String get statsByMonthOrYear => 'Per maand / jaar…';

  @override
  String get statsByYear => 'Per jaar';

  @override
  String get statsByMonth => 'Per maand';

  @override
  String get statsPlaysLabel => 'Afspeelbeurten';

  @override
  String get statsTracksLabel => 'Nummers';

  @override
  String get statsArtistsLabel => 'Artiesten';

  @override
  String get statsAlbumsLabel => 'Albums';

  @override
  String get statsListenTime => 'Luistertijd';

  @override
  String get statsByCollection => 'Per collectie';

  @override
  String get statsByFormat => 'Per formaat';

  @override
  String get statsByEngine => 'Per engine';

  @override
  String get statsPlaylistsLabel => 'Afspeellijsten';

  @override
  String get statsLocalFilesSection => 'Gedownloade bestanden';

  @override
  String get statsFilesLabel => 'Bestanden';

  @override
  String get statsSpaceLabel => 'Schijfruimte';

  @override
  String get statsNoPlaysInPeriod => 'Geen afspeelbeurten in deze periode';

  @override
  String get statsNoPlays => 'Geen afspeelbeurten';

  @override
  String get statsTopTracks => 'Topnummers';

  @override
  String get statsTopAlbums => 'Topalbums';

  @override
  String get statsTopArtists => 'Topartiesten';

  @override
  String statsTopTracksIn(String period) {
    return 'Topnummers — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Topalbums — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Topartiesten — $period';
  }

  @override
  String get statsSeeAll => 'Toon alles';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n keer afgespeeld',
      one: '$n keer afgespeeld',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max $n';
  }

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get commonCreate => 'Aanmaken';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Verwijderen';

  @override
  String get commonRename => 'Naam wijzigen';

  @override
  String get commonSort => 'Sorteren';

  @override
  String get commonPlayAll => 'Alles afspelen';

  @override
  String get sortName => 'Naam';

  @override
  String get sortTitle => 'Titel';

  @override
  String get sortArtist => 'Artiest';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Datum toegevoegd';

  @override
  String get commonClear => 'Wissen';

  @override
  String get sortRecentlyModified => 'Onlangs gewijzigd';

  @override
  String get sortCreationDate => 'Aanmaakdatum';

  @override
  String get playlistNameHint => 'Naam';

  @override
  String get playlistNew => 'Nieuwe afspeellijst';

  @override
  String get playlistNewFolder => 'Nieuwe map';

  @override
  String get playlistNewTooltip => 'Nieuwe afspeellijst / map';

  @override
  String get playlistAddTo => 'Voeg toe aan afspeellijst';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Voeg toe aan $n afspeellijsten',
      one: 'Voeg toe aan $n afspeellijst',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Selecteer een afspeellijst';

  @override
  String get playlistFilterHint => 'Filter afspeellijsten…';

  @override
  String get playlistSearchHint => 'Zoek een afspeellijst…';

  @override
  String get playlistNoMatch => 'Geen overeenkomende afspeellijst';

  @override
  String get playlistNoneCreateHint => 'Geen afspeellijst — maak er een met +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
      zero: 'Geen nummers',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Al aanwezig';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items staan al in de geselecteerde afspeellijsten.',
      one: '$n item staat al in de geselecteerde afspeellijsten.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Duplicaten overslaan';

  @override
  String get playlistAddAgain => 'Opnieuw toevoegen';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers toegevoegd',
      one: '$n nummer toegevoegd',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m afspeellijsten',
      one: '$n afspeellijst',
    );
    return '$_temp0 aan $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Toevoegen mislukt: $error';
  }

  @override
  String get playlistRenameTitle => 'Afspeellijst hernoemen';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'De map “$name” verwijderen?';
  }

  @override
  String get playlistDeleteFolderBody => 'De inhoud gaat één niveau omhoog.';

  @override
  String get playlistEmpty => 'Lege afspeellijst';

  @override
  String get trackOptionsAddToLibrary => 'Voeg toe aan bibliotheek';

  @override
  String get trackOptionsRemoveFromLibrary => 'Verwijder uit bibliotheek';

  @override
  String get trackOptionsAddedToLibrary =>
      'Nummer toegevoegd aan de bibliotheek';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'Nummer verwijderd uit de bibliotheek';

  @override
  String get trackOptionsViewAlbum => 'Bekijk het album';

  @override
  String get trackOptionsViewArtist => 'Bekijk de artiest';

  @override
  String get trackOptionsPlayNow => 'Nu afspelen';

  @override
  String get trackOptionsPlayNext => 'Speel hierna af';

  @override
  String get trackOptionsAddToQueueEnd => 'Voeg toe aan einde van wachtrij';

  @override
  String get trackOptionsPlayLast => 'Speel als laatste af';

  @override
  String get trackOptionsDeleteDownload => 'Download verwijderen';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Deze download verwijderen?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Het bestand en de bijbehorende lokale gegevens (geschiedenis, nummers) worden verwijderd.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Download verwijderd';

  @override
  String get trackOptionsAddToFavorites => 'Voeg toe aan favorieten';

  @override
  String get trackOptionsRemoveFromFavorites => 'Verwijder uit favorieten';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Album toegevoegd aan favorieten';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album verwijderd uit favorieten';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album niet gedownload — niets om te verwijderen';

  @override
  String get trackOptionsDeleteAlbumTitle =>
      'Het gedownloade album verwijderen?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'De map en al haar lokale gegevens (nummers, geschiedenis) worden verwijderd.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Album verwijderd uit de lokale opslag';

  @override
  String get trackOptionsRedownloadAlbum => 'Album opnieuw downloaden';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Overschrijft bestanden ÉN lokale gegevens';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Albumbestanden verwijderen';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Gedownloade map + lokale gegevens (geschiedenis)';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsGeneral => 'Algemeen';

  @override
  String get settingsGeneralSubtitle => 'Thema';

  @override
  String get settingsVisualisation => 'Visualisatie';

  @override
  String get settingsVisualisationSubtitle =>
      'Oscilloscopen, artwork als achtergrond';

  @override
  String get settingsPlayback => 'Afspelen';

  @override
  String get settingsPlaybackSubtitle => 'Loops, fade-out, stilte';

  @override
  String get settingsEngines => 'Engines';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Gegevens';

  @override
  String get settingsDataSubtitle => 'ID, geschiedenis, reset';

  @override
  String get settingsBackupExport => 'Back-up exporteren';

  @override
  String get settingsBackupExportSubtitle =>
      'Bewaar je bibliotheek, afspeellijsten en instellingen in een bestand';

  @override
  String get settingsBackupImport => 'Back-up importeren';

  @override
  String get settingsBackupImportSubtitle =>
      'Herstel je gegevens uit een back-upbestand';

  @override
  String get settingsBackupExportFailed => 'Exporteren van back-up mislukt';

  @override
  String get settingsBackupImportConfirmTitle => 'Back-up importeren?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Dit vervangt je bibliotheek, afspeellijsten en instellingen op dit apparaat. Gedownloade bestanden blijven behouden.';

  @override
  String get settingsBackupImportConfirm => 'Importeren';

  @override
  String get settingsBackupImportedTitle => 'Back-up geïmporteerd';

  @override
  String get settingsBackupImportedBody =>
      'Je gegevens zijn hersteld. Herstart de app om alles toe te passen.';

  @override
  String get settingsBackupTooNew =>
      'Deze back-up is gemaakt met een nieuwere versie van de app';

  @override
  String get settingsBackupInvalid => 'Geen geldige Rewamp-back-up';

  @override
  String get settingsBackupImportFailed => 'Importeren van back-up mislukt';

  @override
  String get settingsAbout => 'Over';

  @override
  String get settingsAboutSubtitle => 'Credits en licenties';

  @override
  String get settingsCreditsSubtitle => 'Bibliotheken, data en componenten';

  @override
  String get settingsSupport => 'Contact en support';

  @override
  String get settingsSupportSubtitle => 'Neem contact op, website';

  @override
  String get settingsSupportEmail => 'E-mail versturen';

  @override
  String get settingsSupportEmailSubtitle => 'Vraag, bug of suggestie';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — support';

  @override
  String get settingsSupportEmailIntro =>
      'Beschrijf hierboven je vraag, bug of suggestie. De informatie hieronder helpt ons om jou te helpen.';

  @override
  String get settingsSupportWebsite => 'Website';

  @override
  String get settingsDonation => 'Rewamp steunen';

  @override
  String get settingsDonationSubtitle => 'Een fooi, als je wilt';

  @override
  String get settingsDonationBlurb =>
      'Rewamp is gratis en advertentievrij — een passieproject gewijd aan het behoud van de demoscene- en retrocultuur. Donaties helpen de ontwikkeling van de app te financieren en de hostingkosten van de database te dekken. Geen verplichting: als de app je bevalt, is een klein gebaar altijd welkom.';

  @override
  String get settingsDonationFloppy => 'Een diskette';

  @override
  String get settingsDonationCartridge => 'Een cartridge';

  @override
  String get settingsDonationBox => 'Een spel in doos';

  @override
  String get settingsDonationCustom => 'Kies een bedrag';

  @override
  String get settingsCancel => 'Annuleren';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Verwijderen';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsRenew => 'Vernieuwen';

  @override
  String get settingsOff => 'Uit';

  @override
  String get settingsOn => 'Aan';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Oneindig';

  @override
  String get settingsDefault => 'Standaard';

  @override
  String get settingsCoreNoScope => 'geen oscilloscoop';

  @override
  String get settingsNone => 'Geen';

  @override
  String get settingsLevelLow => 'Laag';

  @override
  String get settingsLevelHigh => 'Hoog';

  @override
  String get settingsStereo => 'Stereo';

  @override
  String get settingsSurround => 'Surround';

  @override
  String settingsValuePercent(int value) {
    return '$value%';
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
  String get settingsTheme => 'Thema';

  @override
  String get settingsThemeLight => 'Licht';

  @override
  String get settingsThemeDark => 'Donker';

  @override
  String get settingsArtworkTintTitle => 'Speler tinten met het artwork';

  @override
  String get settingsArtworkTintSubtitle =>
      'De speler neemt de dominante kleur van de hoes over';

  @override
  String get settingsGlassEffectTitle => 'Liquid-glass-effect';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lens en vervaging op de onderste balken — uitschakelen op trage apparaten';

  @override
  String get settingsResetSection => 'Deze sectie resetten';

  @override
  String get settingsResetEngine => 'Deze engine resetten';

  @override
  String get settingsResetChoices => 'Deze keuzes resetten';

  @override
  String get settingsResetToDefault => 'Standaardwaarde';

  @override
  String get settingsStartInVizTitle => 'Starten in visualizermodus';

  @override
  String get settingsStartInVizSubtitle =>
      'De speler opent op de oscilloscopen in plaats van het artwork';

  @override
  String get settingsVoiceGridTitle => 'Raster van de stemmen-oscilloscoop';

  @override
  String get settingsVoiceGridSubtitle =>
      'Toont de randen die elke stem scheiden';

  @override
  String get settingsKeepAwakeTitle => 'Scherm aan houden';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Zolang een visualizer zichtbaar is, wordt het scherm niet gedimd of vergrendeld';

  @override
  String get settingsVoiceNamesTitle => 'Namen van de stemmen';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Toont de naam van elke stem in haar kader';

  @override
  String get settingsLineThickness => 'Lijndikte';

  @override
  String get settingsScopeVoiceColor => 'Stemmen-oscilloscoop';

  @override
  String get settingsStereoColors => 'Stereo: kleuren';

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
  String get settingsNotePalette => 'Kleurenpalet';

  @override
  String get settingsNoteBoxStyle => 'Blokstijl';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'Alle visualisaties';

  @override
  String get settingsVizScopes => 'Oscilloscopen (stereo en per stem)';

  @override
  String get settingsVizFrameRate => 'Beeldsnelheid';

  @override
  String get settingsVizFrameRateScreen => 'Scherm';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => 'Intensiteit / snelheid';

  @override
  String get settingsArtworkOpacity => 'Dekking van het achtergrond-artwork';

  @override
  String get settingsProjectMTitle => 'projectM-instellingen';

  @override
  String get settingsProjectMSubtitle =>
      'Presets, transities, kwaliteit, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Meldingen bij nummerwissel';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Systeemmelding met de titel van het nieuwe nummer';

  @override
  String get settingsSilenceDetection => 'Stiltedetectie';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get localActionPlay => 'Bestanden of map afspelen';

  @override
  String get localActionImport => 'Bestanden of map importeren';

  @override
  String localOpsImporting(String name) {
    return '$name importeren…';
  }

  @override
  String get localOpsImportingSelection =>
      'Geselecteerde bestanden importeren…';

  @override
  String localOpsDeleting(String name) {
    return '$name verwijderen…';
  }

  @override
  String get localOpsPhaseCopying => 'kopiëren';

  @override
  String get localOpsPhaseExtracting => 'uitpakken';

  @override
  String get localOpsPhaseRegistering => 'toevoegen aan bibliotheek';

  @override
  String get localOpsPhaseDeleting => 'bestanden verwijderen';

  @override
  String get localImportFiles => 'Bestanden importeren';

  @override
  String get storageLocalImports => 'Lokale imports';

  @override
  String get settingsVgmJapaneseTags => 'Japanse tags (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'Geeft de voorkeur aan de Japanse titel-/spel-/artiestvelden van VGM-tags indien aanwezig.';

  @override
  String get localImportFolder => 'Map importeren';

  @override
  String get localLibraryTitle => 'Op dit apparaat';

  @override
  String get libraryOnAnotherDevice => 'Op een ander apparaat';

  @override
  String get localLibraryEmpty =>
      'Nog geen lokale imports. Gebruik “Bestanden importeren” of “Map importeren” op het startscherm.';

  @override
  String queueLimitReached(int count) {
    return 'Wachtrij beperkt tot de eerste $count nummers';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return '“$name” verwijderen? Het bestand en bijbehorende bestanden (hoes…) worden gewist.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Map “$name” met $count nummers verwijderen?',
      one: 'Map “$name” met $count nummer verwijderen?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count track(s) geïmporteerd in de bibliotheek';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks nummer(s) geïmporteerd — $albums album(s)';
  }

  @override
  String localImportFailed(String error) {
    return 'Importeren mislukt: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'Laat het einde van elke track overvloeien in het begin van de volgende. Op 0 blijft het afspelen naadloos.';

  @override
  String get settingsMinSubsongSection => 'Te korte subsongs';

  @override
  String get settingsMinSubsongTitle => 'Minimale duur';

  @override
  String get settingsMinSubsongHelp =>
      'Kortere subsongs blijven buiten de lijst en de wachtrij — een spelbestand bevat vaak meer geluidseffecten dan muziek. Bij 0 wordt niets weggelaten; een onbekende duur geldt nooit als kort.';

  @override
  String get localNewFolder => 'Nieuwe map';

  @override
  String get localFolderName => 'Mapnaam';

  @override
  String get localRename => 'Hernoemen';

  @override
  String get localMoveTo => 'Verplaatsen naar…';

  @override
  String get localMove => 'Verplaatsen';

  @override
  String get localMoveNothing => 'Niets verplaatst';

  @override
  String get localNameInvalid => 'Ongeldige naam';

  @override
  String get localNameTaken => 'Die naam is al in gebruik';

  @override
  String get localMoveIntoItself =>
      'Een map kan niet naar zichzelf worden verplaatst';

  @override
  String get localManageFailed => 'Bewerking mislukt';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Niet in de wachtrij: korter dan $seconds s (Instellingen → Afspelen)';
  }

  @override
  String get settingsQueuePrefetchSection => 'Downloads van de wachtrij';

  @override
  String get settingsQueuePrefetchTitle => 'Hele wachtrij downloaden';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'Eén bestand tegelijk; het volgende ontbrekende nummer start zodra het vorige binnen is. Uit: alleen het volgende nummer.';

  @override
  String get settingsCdRipDeclickSection => 'Cd-rips';

  @override
  String get settingsCdRipDeclickTitle =>
      'Klikken aan het begin van de track verwijderen';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'Slechte cd-rips (mp3, ape, ogg, flac…) beginnen vaak met enkele beschadigde samples. Ze worden hersteld tot 200 ms echte muziek heeft gespeeld; daarna houdt het filter zich afzijdig.';

  @override
  String get settingsSilenceSkipTitle => 'Bij stilte naar het volgende nummer';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Gaat automatisch verder wanneer de uitvoer stil blijft';

  @override
  String get settingsSilenceDelay => 'Stiltevertraging';

  @override
  String get settingsDefaultDuration => 'Standaardduur';

  @override
  String get settingsDefaultDurationHelp =>
      'Wordt gebruikt wanneer een nummer geen bekende duur opgeeft (geen tag, geen servermetadata) — zo speelt of loopt het niet eindeloos door. Geldt nooit voor Amiga-nummers (UADE), die hun eigen songlength-database hebben.';

  @override
  String get settingsForcedLoopHeader => 'Geforceerde loop / fade-out';

  @override
  String get settingsForcedLoopHelp =>
      'Sommige formaten herhalen een specifiek gedeelte (VGM, tracker-modules…); andere niet. \"Oneindig\" negeert het natuurlijke einde van het nummer.';

  @override
  String get settingsForceLoopCount => 'Forceer het aantal loops';

  @override
  String get settingsLoopCount => 'Aantal loops';

  @override
  String get settingsForceFadeout => 'Forceer een fade-out';

  @override
  String get settingsFadeoutDuration => 'Duur van de fade';

  @override
  String get settingsResetEnginesTitle => 'Engine-instellingen resetten?';

  @override
  String get settingsResetEnginesBody =>
      'Alle engine-instellingen keren terug naar hun standaardwaarden.';

  @override
  String get settingsResetDefaultsTitle =>
      'Terugzetten naar de standaardwaarden';

  @override
  String get settingsResetDefaultsSubtitle => 'Alle engines';

  @override
  String get settingsDefaultDecoders => 'Standaarddecoders';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formaten die door meerdere engines gespeeld worden';

  @override
  String get settingsDecodersHelp =>
      'Sommige formaten kunnen door meerdere engines worden afgespeeld. Kies welke standaard wordt gebruikt — alle andere formaten worden automatisch gerouteerd.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga-trackers (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Modules die libopenmpt niet leest — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — kwaliteit, filters, opties per chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — hoogdoorlaatfilter';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont in gebruik';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolatie, laagdoorlaat, echo';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panning, hoofdtelefoon, gain, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — klok, model, ReSIDfp-filters';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — harmonische stereo-/surroundmodus';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, reverb';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612-, OPL3-, QSound-cores…';

  @override
  String get settingsMasterVolume => 'Hoofdvolume';

  @override
  String get settingsAmplification => 'Versterking';

  @override
  String get settingsAmigaFilter => 'Amiga-filter';

  @override
  String get settingsInterpolation => 'Interpolatie';

  @override
  String get settingsPolyphony => 'Polyfonie';

  @override
  String get settingsReverb => 'Galm';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'Deze MIDI is voor een Roland MT-32 geschreven. Zonder de ROM\'s speelt hij via de SoundFont, met de instrumenten omgezet naar General MIDI — importeer de ROM\'s in Instellingen › Engines › Munt.';

  @override
  String get settingsMidiMt32ToGm => 'MT-32-bestanden aanpassen';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'Een MIDI voor de Roland MT-32 nummert zijn programma\'s volgens de lijst van de MT-32: omgezet naar het dichtstbijzijnde General MIDI-instrument klinkt het aannemelijk in plaats van willekeurig.';

  @override
  String get settingsInterpNone => 'Geen';

  @override
  String get settingsInterpLinear => 'Lineair';

  @override
  String get settingsInterpCubic => 'Kubisch';

  @override
  String get settingsInterpSinc => 'Sinc (beste)';

  @override
  String get settingsStereoSeparation => 'Stereoscheiding';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Beëindigt het nummer wanneer de engine een lange stilte detecteert';

  @override
  String get settingsStereoDepth => 'Stereodiepte';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — geen effect op SPC';

  @override
  String get settingsBass => 'Lage tonen';

  @override
  String get settingsTreble => 'Hoge tonen';

  @override
  String get settingsAppliedLive =>
      'Direct toegepast, ook tijdens het afspelen.';

  @override
  String get settingsAppliedNextTrack =>
      'Wordt toegepast op het volgende geladen nummer.';

  @override
  String get settingsSidEmulation => 'Emulatie';

  @override
  String get settingsSidResidfp => 'ReSIDfp (nauwkeurig)';

  @override
  String get settingsSidLite => 'SIDLite (snel)';

  @override
  String get settingsSidSampling => 'Sampling';

  @override
  String get settingsSidSamplingInterp => 'Interpolatie (snel)';

  @override
  String get settingsSidSamplingResample => 'Resample (beste)';

  @override
  String get settingsSidClock => 'Klok';

  @override
  String get settingsSidModel => 'SID-model';

  @override
  String get settingsSidFilter => 'SID-filter';

  @override
  String get settingsSidForceSecond => 'Forceer een 2e SID';

  @override
  String get settingsSidSecondSubtitle => 'Stereo 2SID-nummers';

  @override
  String get settingsSidSecondAddr => 'Adres 2e SID';

  @override
  String get settingsSidForceThird => 'Forceer een 3e SID';

  @override
  String get settingsSidThirdAddr => 'Adres 3e SID';

  @override
  String get settingsSidAutoFilter => 'Automatisch 6581-filterbereik';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Aanbevolen waarde voor de auteur van het nummer (sidplayfp-tabellen)';

  @override
  String get settingsSid6581Range => '6581-filterbereik';

  @override
  String get settingsSid6581Curve => '6581-filtercurve';

  @override
  String get settingsSid8580Curve => '8580-filtercurve';

  @override
  String get settingsSidNote =>
      'SID-filter en -curves worden direct toegepast; emulatie/sampling/klok/model/2e-3e SID gelden vanaf het volgende nummer.';

  @override
  String get settingsAudioOutput => 'Audio-uitvoer';

  @override
  String get settingsAdplugNote =>
      'Surround: twee licht ontstemde OPL-chips. Wordt toegepast op het volgende nummer.';

  @override
  String get settingsHeSpuMain => 'Hoofdstemmen (SPU)';

  @override
  String get settingsHeSpuReverb => 'Reverb (SPU)';

  @override
  String get settingsNsfQuality => 'Kwaliteit (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Laagdoorlaatfilter';

  @override
  String get settingsHighpassFilter => 'Hoogdoorlaatfilter';

  @override
  String get settingsRegion => 'Regio';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC geforceerd';

  @override
  String get settingsNsfRegionPalForced => 'PAL geforceerd';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy geforceerd';

  @override
  String get settingsNsfForceIrq => 'Forceer IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulses (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — driehoek / ruis / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Dempen opheffen bij reset';

  @override
  String get settingsNsfPhaseRefresh => 'Fase verversen';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Reset de fase wanneer de periode wordt geschreven';

  @override
  String get settingsNsfNonlinearMixer => 'Niet-lineaire mixing';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'De echte mix van de 2A03 (anders lineair)';

  @override
  String get settingsNsfDutySwap => 'Duty cycles omwisselen';

  @override
  String get settingsNsfDutySwapSubtitle => 'Volgorde van de 25% / 50% duties';

  @override
  String get settingsNsfNegateSweep => 'Negatieve sweep bij init';

  @override
  String get settingsNsfEnable4011 => 'Register \$4011 ingeschakeld';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Directe DAC-uitvoer (originele clicks)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodieke ruis';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Korte modus van de ruisgenerator';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM anti-click';

  @override
  String get settingsNsfRandomizeNoise => 'Willekeurige ruis bij init';

  @override
  String get settingsNsfTriangleMute => 'Demp de driehoek';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Maakt de driehoek stil bij ultrasone periodes';

  @override
  String get settingsNsfRandomizeTri => 'Willekeurige driehoek bij init';

  @override
  String get settingsNsfDpcmReverse => 'Omgekeerde DPCM';

  @override
  String get settingsNsfN163Serial => 'Seriële multiplexing';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'De echte N163-bromtoon bij nummers met meerdere stemmen';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fase alleen-lezen';

  @override
  String get settingsNsfN163LimitWavelength => 'Beperk de golflengte';

  @override
  String get settingsNsfFdsCutoff => 'Laagdoorlaat-afsnijfrequentie';

  @override
  String get settingsNsfFds4085Reset => '\$4085-reset';

  @override
  String get settingsNsfFdsWriteProtect => 'Schrijfbeveiliging';

  @override
  String get settingsNsfVrc7Patch => 'Patchset';

  @override
  String get settingsNsfVrc7Opll => 'OPLL-modus';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Emuleert een YM2413 in plaats van de VRC7';

  @override
  String get settingsGbsHpFilter => 'Hoogdoorlaatfilter (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klassieke GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Echo';

  @override
  String get settingsUadePostfx => 'Nabewerking';

  @override
  String get settingsUadePostfxSubtitle =>
      'Schakelt de effectketen in (vereist voor alles hieronder)';

  @override
  String get settingsUadePan => 'Panning (stereoscheiding)';

  @override
  String get settingsUadePanValue => 'Mate van panning';

  @override
  String get settingsUadeHeadphones => 'Hoofdtelefoon';

  @override
  String get settingsUadeLed => 'LED (Paula-filter)';

  @override
  String get settingsUadeLedAuto => 'Auto (per nummer)';

  @override
  String get settingsUadeLedOn => 'Geforceerd AAN';

  @override
  String get settingsUadeLedOff => 'Geforceerd UIT';

  @override
  String get settingsUadeFilterType => 'Filtertype';

  @override
  String get settingsUadeGain => 'Gain';

  @override
  String get settingsUadeGainValue => 'Mate van gain';

  @override
  String get settingsSoundfontLoading => 'Catalogus laden…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Catalogus niet beschikbaar ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Download mislukt: $error';
  }

  @override
  String get settingsSoundfontImport => 'SoundFont importeren…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Kies een .sf2-bestand op dit apparaat';

  @override
  String get settingsSoundfontImported => 'Geïmporteerd';

  @override
  String get settingsSoundfontInvalid => 'Dit bestand is geen SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Importeren mislukt — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Verwijder het bestand';

  @override
  String get settingsCreditsHeader => 'Credits & licenties';

  @override
  String get settingsRightsNotice =>
      'Rewamp is een speler: het host geen bestanden en verspreidt geen muziek. De nummers komen uit online preservatie-archieven en blijven eigendom van hun rechthebbenden. Het is uw eigen verantwoordelijkheid om na te gaan of beluisteren, downloaden en bewaren in overeenstemming is met de geldende rechten en de wetgeving van uw land.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formaten ondersteund',
      one: '$count formaat ondersteund',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verdeeld over $count afspeelengines — bekijk de details',
      one: 'Verzorgd door $count afspeelengine — bekijk de details',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga-songlengths & metadata';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb door Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID-gegevens & hoesafbeeldingen';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadata en beeldmateriaal van C64-games.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2-lettertype';

  @override
  String get settingsFt2FontSubtitle =>
      'De FastTracker II-stijl van de patternvisualizer gebruikt het FT2-bitmaplettertype uit ft2-clone van 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url gekopieerd';
  }

  @override
  String get settingsOpenLink => 'Link openen';

  @override
  String get settingsEnginesHeader => 'Afspeelengines';

  @override
  String get settingsComponentsHeader => 'Overige componenten';

  @override
  String get settingsResetAll => 'Alle instellingen resetten';

  @override
  String get settingsResetAllSubtitle =>
      'Algemeen, Visualisatie, Afspelen, Engines — niet de bibliotheek';

  @override
  String get settingsResetAllTitle => 'Alle instellingen resetten?';

  @override
  String get settingsResetAllBody =>
      'Algemeen, Visualisatie, Afspelen en alle engines keren terug naar hun standaardwaarden. Je bibliotheek en geschiedenis blijven ongewijzigd.';

  @override
  String get settingsRenewUserId => 'Vernieuw de anonieme ID';

  @override
  String get settingsRenewUserIdTitle => 'De anonieme ID vernieuwen?';

  @override
  String get settingsRenewUserIdBody =>
      'Er wordt een nieuwe anonieme ID aangemaakt voor de serverstatistieken.\n\nDe oude wordt niet meer gebruikt. Je lokale geschiedenis en favorieten blijven ongewijzigd.';

  @override
  String get settingsRenewUserIdFailed => 'Mislukt — server onbereikbaar';

  @override
  String settingsNewUserId(String id) {
    return 'Nieuwe ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Geen ID geregistreerd';

  @override
  String get settingsCleanDb => 'De lokale database opschonen';

  @override
  String get settingsCleanDbSubtitle =>
      'Verwijdert gegevens waarvan het bestand niet meer bestaat (gewiste downloads, oude fouten)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verweesde vermeldingen verwijderd',
      one: '$count verweesde vermelding verwijderd',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'De lokale database is schoon — niets te verwijderen';

  @override
  String get settingsClearCache => 'De cache wissen (artwork & metadata)';

  @override
  String get settingsClearCacheSubtitle =>
      'Verwijdert hoezen uit de cache en opgehaalde metadata (STIL, songlengths) — worden bij het volgende afspelen opnieuw gedownload';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cache gewist ($count hoezen)',
      one: 'Cache gewist ($count hoes)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Opslag';

  @override
  String get storageSubtitle => 'Wat de app op schijf bewaart, met verwijderen';

  @override
  String get storageDownloads => 'Downloads';

  @override
  String get storageArtworkCache => 'Hoezencache';

  @override
  String get storageSoundfonts => 'SoundFonts';

  @override
  String get storagePresets => 'Visualizer-presets';

  @override
  String get storageOpenedFiles => 'Geopende bestanden';

  @override
  String get storageOpenedEmpty =>
      'Bestanden die van buitenaf worden geopend (delen, “Openen met”, kiezer op mobiel) worden hierheen gekopieerd.';

  @override
  String get storageInUse => 'in een afspeellijst of bibliotheek';

  @override
  String get storageDeleteAll => 'Alles verwijderen';

  @override
  String get storageClear => 'Wissen';

  @override
  String get storageDeleteSelection => 'Selectie verwijderen';

  @override
  String get storageSelectAll => 'Alles selecteren';

  @override
  String get storageFilterHint => 'Filteren op naam';

  @override
  String get storageNoMatch => 'Geen bestand komt overeen met dit filter.';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geselecteerd',
      one: '$count geselecteerd',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden verwijderen?',
      one: '$count bestand verwijderen?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count bestanden verwijderen? $inUse zijn in gebruik door een afspeellijst of de bibliotheek — die items verliezen hun bestand.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Alle gedownloade bestanden en hun bibliotheekregels verwijderen? Favorieten en afspeellijsten behouden hun items, maar de bestanden moeten opnieuw worden gedownload.';

  @override
  String get storageSoundfontsClearBody =>
      'Alle SoundFonts verwijderen, ook geïmporteerde? Catalogus-SoundFonts worden opnieuw gedownload; geïmporteerde gaan verloren.';

  @override
  String get storagePresetsClearBody =>
      'Gedownloade presetpacks en geïmporteerde presets verwijderen? Meegeleverde presets blijven; packs worden opnieuw gedownload, geïmporteerde gaan verloren.';

  @override
  String get storageOpenedDeleteAllTitle => 'Geopende bestanden verwijderen';

  @override
  String get storageInUseDeleteTitle => 'Bestand in gebruik';

  @override
  String get storageInUseDeleteBody =>
      'Een afspeellijst of de bibliotheek verwijst nog naar dit bestand. Na verwijderen blijven die items zonder bestand achter.';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden — $size',
      one: '$count bestand — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestanden — $size · beheer via albums en nummers',
      one: '$count bestand — $size · beheer via albums en nummers',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count bestanden verwijderen? Bestanden in een afspeellijst of bibliotheek blijven behouden.',
      one:
          '$count bestand verwijderen? Bestanden in een afspeellijst of bibliotheek blijven behouden.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'De statistieken resetten';

  @override
  String get settingsResetStatsSubtitle =>
      'Verwijdert de luistergeschiedenis en de afspeeltellers';

  @override
  String get settingsClearStatsTitle => 'De statistieken resetten?';

  @override
  String get settingsClearStatsBody =>
      'Dit verwijdert definitief:\n• de volledige luistergeschiedenis\n• de afspeeltellers\n\nJe favorieten en je bibliotheek blijven ongewijzigd.';

  @override
  String get settingsStatsCleared => 'Statistieken verwijderd';

  @override
  String get settingsResetDatabase => 'De database resetten';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Verwijdert alles: geschiedenis, favorieten, afspeellijsten, cache';

  @override
  String get settingsResetDbTitle => 'De database resetten?';

  @override
  String get settingsCleanLocalTitle => 'Onspeelbare lokale items opruimen';

  @override
  String get cleanStageScan => 'Items worden gescand…';

  @override
  String get cleanStageSync => 'Synchroniseren met je account…';

  @override
  String get cleanStagePurge => 'Verwijderen uit je account…';

  @override
  String get cleanStageDelete => 'Lokaal verwijderen…';

  @override
  String get settingsCleanLocalBody =>
      'Bibliotheekitems die verwijzen naar een bestand dat niet meer op dit apparaat staat. Ze worden ook uit je account verwijderd, dus van je andere apparaten.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items verwijderd',
      one: '$count item verwijderd',
      zero: 'Niets op te ruimen',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'Dit verwijdert definitief:\n• de volledige luistergeschiedenis\n• alle tellers\n• alle favorieten\n• alle afspeellijsten\n• alle metadata in de cache\n\nJe audiobestanden worden niet verwijderd.';

  @override
  String get settingsDbReset => 'Database gereset';

  @override
  String get settingsDeleteDownloads => 'De downloads verwijderen';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Verwijdert alle bestanden uit de online map (nummers, artwork)';

  @override
  String get settingsCleanAll => 'Lokale database en cache opschonen';

  @override
  String get settingsCleanAllSubtitle =>
      'Verwijdert items zonder bestand, bibliotheekitems die naar bestanden op een ander apparaat wijzen, en leegt de cache van hoezen en metadata';

  @override
  String get settingsCleanAllConfirmBody =>
      'Bibliotheekitems die naar bestanden op een ander apparaat wijzen worden ook uit je account verwijderd, dus van je andere apparaten. Hoezen en metadata worden bij het volgende afspelen opnieuw gedownload.';

  @override
  String get settingsDataAdvanced => 'Geavanceerd';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Elke opschoonstap apart, de cache en de resets';

  @override
  String get settingsDataGroupDb => 'Database';

  @override
  String get settingsDataGroupCache => 'Cache';

  @override
  String get settingsDataGroupReset => 'Resetten';

  @override
  String get settingsDeleteDownloadsTitle => 'De downloads verwijderen?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Dit verwijdert definitief elk gedownload bestand (nummers, albums, artwork) uit de online map.\n\nDe vermeldingen in de database blijven staan, maar verwijzen dan naar bestanden die niet meer bestaan.';

  @override
  String get settingsDownloadsDeleted => 'Downloads verwijderd';

  @override
  String get settingsColor => 'Kleur';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Willekeurige volgende preset';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Uit: speelt de presets op volgorde af';

  @override
  String get settingsPmLockPreset => 'De preset vergrendelen';

  @override
  String get settingsPmLockPresetSubtitle => 'Geen automatische wisseling';

  @override
  String get settingsPmPresetDuration => 'Tijd tussen presets';

  @override
  String get settingsPmTransitions => 'Transities';

  @override
  String get settingsPmBlend => 'Overgang met cross-fade';

  @override
  String get settingsPmBlendSubtitle => 'Uit: wissel direct van preset';

  @override
  String get settingsPmTransitionStyle => 'Overgangsstijl';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Het patroon dat de overvloeiing gebruikt';

  @override
  String get settingsPmTransitionRandom => 'Willekeurig';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Presetwisseling op de beat';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minimale tijd';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: gevoeligheid';

  @override
  String get settingsPmRendering => 'Rendering';

  @override
  String get settingsPmQuality => 'Kwaliteit';

  @override
  String get settingsPmQualitySubtitle =>
      'Renderresolutie (Max = native resolutie)';

  @override
  String get settingsPmBeatSensitivity => 'Beatgevoeligheid';

  @override
  String get settingsPmAspectRatio => 'Beeldverhouding respecteren';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'Voor de shaders die dit ondersteunen';

  @override
  String get settingsPmPermissive => 'Permissieve modus';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Laadt .milk-bestanden met scriptfouten';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSubtitle => 'Je bibliotheek bewaren en synchroniseren';

  @override
  String get accountAnonymous => 'Anoniem account';

  @override
  String get accountAnonymousExplain =>
      'Je favorieten en geschiedenis staan op de server, maar alleen dit apparaat komt erbij. Voeg een e-mailadres toe om ze elders terug te vinden.';

  @override
  String get accountEmailAttached =>
      'Adres bevestigd — dit account kan worden hersteld';

  @override
  String get accountEmailPending => 'Adres nog niet bevestigd';

  @override
  String get accountInsecureStorage =>
      'De beveiligde opslag van dit apparaat is niet beschikbaar: de account-id wordt onversleuteld bewaard.';

  @override
  String get accountSaveCta => 'Mijn account bewaren';

  @override
  String get accountStatSongs => 'Favoriete nummers';

  @override
  String get accountStatAlbums => 'Favoriete albums';

  @override
  String get accountStatPlays => 'Weergaven';

  @override
  String get accountCreatedLabel => 'Aangemaakt';

  @override
  String get accountSignOut => 'Afmelden';

  @override
  String get accountRevoke => 'Overal afmelden';

  @override
  String get accountRevokeSubtitle => 'Meldt alle andere apparaten af';

  @override
  String get accountRevokeBody =>
      'Alle andere apparaten worden afgemeld. Dit apparaat blijft verbonden.';

  @override
  String get accountRevokeDone => 'Andere apparaten afgemeld';

  @override
  String get accountDelete => 'Mijn account verwijderen';

  @override
  String get accountDeleteSubtitle =>
      'Wist het account en zijn gegevens op de server. Onomkeerbaar.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favorieten en $lists afspeellijsten worden van de server verwijderd. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Je downloads en de bibliotheek op dit apparaat blijven ongemoeid.';

  @override
  String get accountDeleteDone => 'Account verwijderd';

  @override
  String get accountSignOutSubtitle =>
      'Dit apparaat begint opnieuw met een leeg account';

  @override
  String get accountSignOutTitle => 'Afmelden?';

  @override
  String accountSignOutBody(String email) {
    return 'Je kunt naar dit account terugkeren met een code die naar $email wordt gestuurd.';
  }

  @override
  String get accountSignedOut => 'Afgemeld';

  @override
  String get accountNoSignOut => 'Afmelden niet beschikbaar';

  @override
  String get accountNoSignOutSubtitle =>
      'Zonder e-mailadres zou dit account voorgoed verloren gaan.';

  @override
  String get accountDetach => 'Adres ontkoppelen';

  @override
  String get accountDetachSubtitle =>
      'Het account wordt weer anoniem, er worden geen gegevens verwijderd';

  @override
  String get accountDetachBody =>
      'Zonder adres kan dit account niet meer vanaf een ander apparaat worden teruggevonden.';

  @override
  String get accountDetachDone => 'Adres ontkoppeld';

  @override
  String get accountOffline => 'Account offline niet beschikbaar';

  @override
  String get accountEmailTitle => 'E-mailadres';

  @override
  String get accountEmailExplain =>
      'We sturen je een code van 6 cijfers om het adres te bevestigen. Het dient alleen om je account terug te vinden.';

  @override
  String get accountEmailLabel => 'E-mailadres';

  @override
  String get accountCodeTitle => 'Bevestigingscode';

  @override
  String accountCodeExplain(String email) {
    return 'Code verstuurd naar $email. Hij is 10 minuten geldig.';
  }

  @override
  String get accountCodeLabel => 'Code van 6 cijfers';

  @override
  String get accountSendCode => 'Code versturen';

  @override
  String get accountVerify => 'Bevestigen';

  @override
  String get accountResend => 'Code opnieuw versturen';

  @override
  String accountResendIn(int n) {
    return 'Opnieuw versturen over $n s';
  }

  @override
  String get accountCheckSpam =>
      'De e-mail kan een minuut onderweg zijn — kijk ook in je spammap.';

  @override
  String get accountErrorInvalidEmail => 'Ongeldig adres';

  @override
  String get accountErrorTooMany =>
      'Te veel aanvragen, probeer het over een paar minuten opnieuw';

  @override
  String get accountErrorInvalidCode => 'Onjuiste of verlopen code';

  @override
  String get accountErrorCodeLength => 'De code bestaat uit 6 cijfers';

  @override
  String get albumOfflinePartial => 'Offline — dit staat al op dit apparaat';

  @override
  String get accountErrorNetwork => 'Verbinding mislukt, probeer het opnieuw';

  @override
  String get accountMergeTitle => 'Deze bibliotheek samenvoegen?';

  @override
  String accountMergeBody(String email) {
    return 'De favorieten en geschiedenis van dit apparaat worden toegevoegd aan het account $email. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get accountMergeConfirm => 'Samenvoegen';

  @override
  String get accountCarryLocal => 'Favorieten van dit apparaat behouden';

  @override
  String accountCarryLocalOn(int n) {
    return 'De $n favorieten en de afspeellijsten van dit apparaat worden aan het account toegevoegd.';
  }

  @override
  String get accountCarryLocalOff =>
      'Ze worden van dit apparaat verwijderd en vervangen door die van het account. Gedownloade bestanden blijven staan.';

  @override
  String get accountDropLocalTitle => 'Gegevens van dit apparaat verwijderen?';

  @override
  String get accountCreatedOk => 'Account bewaard, je bibliotheek staat veilig';

  @override
  String get accountMergedOk =>
      'Aangemeld — je lokale favorieten zijn toegevoegd';

  @override
  String get accountSignedInOk => 'Aangemeld';

  @override
  String get playlistEntryMissing => 'Bestand ontbreekt op dit apparaat';

  @override
  String get playlistEntryMissingRestorable =>
      'Bestand ontbreekt — opnieuw te downloaden';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ontbreken',
      one: '$n ontbreekt',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Opslaan in mijn account';

  @override
  String get playlistBackupSubtitle =>
      'Behoudt deze afspeellijst ook na een herinstallatie';

  @override
  String get playlistBackupUpdate => 'Back-up bijwerken';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Vervangt de accountkopie door deze versie';

  @override
  String get playlistBackupStop => 'Niet meer opslaan';

  @override
  String get playlistBackupStopped => 'Back-up verwijderd';

  @override
  String get playlistBackupDone => 'Afspeellijst opgeslagen';

  @override
  String get playlistBackupFailed => 'Opslaan mislukt';

  @override
  String get playlistBackupNoAccount => 'Geen account op dit apparaat';

  @override
  String get playlistSyncTooltip => 'Synchroniseren met mijn account';

  @override
  String get playlistSyncRunning => 'Synchroniseren…';

  @override
  String get playlistSyncDone => 'Afspeellijsten gesynchroniseerd';

  @override
  String get playlistSyncPartial =>
      'Sommige afspeellijsten konden niet worden opgeslagen';

  @override
  String get playlistFetchMissing => 'Ontbrekende nummers downloaden';

  @override
  String get playlistFetchDone => 'Ontbrekende nummers gedownload';

  @override
  String get playlistFetchPartial =>
      'Sommige nummers konden niet worden gedownload';

  @override
  String get playlistEntryFetchFailed =>
      'Dit nummer kon niet worden gedownload';

  @override
  String get accountStatPlaylists => 'Afspeellijsten';

  @override
  String get accountSyncNow => 'Nu synchroniseren';

  @override
  String get accountSyncAuto => 'Gebeurt vanzelf op de achtergrond';

  @override
  String get accountSyncAnonymous =>
      'Opgeslagen op de server. Voeg een e-mailadres toe om een ander apparaat te synchroniseren.';

  @override
  String get accountSyncPending => 'Wijzigingen wachten op verzending';

  @override
  String accountSyncLast(String when) {
    return 'Laatste synchronisatie: $when';
  }

  @override
  String get accountSyncDone => 'Synchronisatie voltooid';

  @override
  String get accountSyncFailed =>
      'Synchronisatie mislukt, wordt opnieuw geprobeerd';

  @override
  String get podiumFirst => '1e';

  @override
  String get podiumSecond => '2e';

  @override
  String get podiumThird => '3e';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'muziek van $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'bevat de $place van $compo';
  }

  @override
  String get competitionEmpty => 'Deze competitie heeft geen inzendingen';

  @override
  String get competitionEntryNoMusic =>
      'Geen muziek in de catalogus voor deze inzending';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nummers',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Overslaan';

  @override
  String get onboardingNext => 'Volgende';

  @override
  String get onboardingStart => 'Beginnen';

  @override
  String get onboardingBetaTitle => 'Bètaversie';

  @override
  String get onboardingBetaBody =>
      'Rewamp is nog in aanbouw. Lokale gegevens — bibliotheek, afspeellijsten, favorieten, statistieken — kunnen vóór versie 1.0 gewist worden. Je downloads lopen geen gevaar, maar bewaar wat je dierbaar is elders.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Versie $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Ontdekken';

  @override
  String get onboardingExploreBody =>
      'Blader en zoek door tienduizenden chiptunes en trackermodules uit de grote online archieven, op artiest, album, platform of party. Tik om te luisteren, download om te bewaren.';

  @override
  String get onboardingLibraryTitle => 'Je bibliotheek';

  @override
  String get onboardingLibraryBody =>
      'Bewaar wat je mooi vindt, maak afspeellijsten en orden ze in mappen. Gedownloade muziek speelt offline, en je bibliotheek volgt je tussen apparaten zodra je bent ingelogd.';

  @override
  String get onboardingPlayerTitle => 'De speler';

  @override
  String get onboardingPlayerBody =>
      'Veeg om van nummer te wisselen en open de visualisaties: oscilloscoop, stemmen, scrollende noten, trackerraster. Bestanden met meerdere nummers tonen hun subsongs en elke stem is apart te dempen.';

  @override
  String get onboardingReplayTitle => 'Rondleiding';

  @override
  String get onboardingReplaySubtitle =>
      'Bekijk de bètamelding en de rondleiding opnieuw';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Trackerraster: kleuren, kolommen, scrollen';

  @override
  String get patternOpaqueBg => 'Ondoorzichtige achtergrond';

  @override
  String get patternOpaqueBgSubtitle => 'Verbergt de hoes achter het raster';

  @override
  String get commonSave => 'Opslaan';

  @override
  String get commonImport => 'Importeren';

  @override
  String get accountDisplayName => 'Publieke naam';

  @override
  String get accountDisplayNameNotSet =>
      'Niet ingesteld — nodig om een afspeellijst te publiceren';

  @override
  String get accountDisplayNameHint =>
      'De naam waaronder je vermeld wilt worden.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Wijzigen stuurt al je gepubliceerde afspeellijsten terug naar de beoordeling.';

  @override
  String get accountDisplayNameTaken =>
      'Deze naam is al bezet. Kies een andere.';

  @override
  String get accountDisplayNameLength => 'Tussen 2 en 40 tekens.';

  @override
  String get accountDisplayNameSaved => 'Publieke naam opgeslagen';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Terug naar beoordeling gestuurde afspeellijsten: $n';
  }

  @override
  String get playlistPublish => 'Openbaar maken';

  @override
  String get playlistPublishSubtitle =>
      'Publicatie aanvragen (wordt beoordeeld)';

  @override
  String get playlistPublishTitle => 'Deze afspeellijst publiceren?';

  @override
  String get playlistPublishBody =>
      'Na goedkeuring is hij voor iedereen zichtbaar, op naam van je publieke naam. De hoes komt van de nummers.';

  @override
  String get playlistPublishCta => 'Aanvragen';

  @override
  String get playlistPublishSubmitted => 'Ter beoordeling verstuurd';

  @override
  String get playlistPublishPending => 'Wacht op goedkeuring';

  @override
  String get playlistPublishApproved => 'Openbaar';

  @override
  String playlistPublishRejected(String reason) {
    return 'Geweigerd: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Geweigerd';

  @override
  String get playlistPublishNeedName =>
      'Kies de naam waaronder je vermeld wilt worden';

  @override
  String get playlistPublishNeedTracks =>
      'Er zijn minstens 5 nummers nodig om te publiceren';

  @override
  String get playlistPublishHasLocal =>
      'Bestanden van je apparaat kunnen niet gepubliceerd worden — anderen kunnen ze niet afspelen';

  @override
  String get playlistPublishTooManyPending =>
      'Je hebt al 3 afspeellijsten die op goedkeuring wachten';

  @override
  String get playlistPublishRefused =>
      'Publicatie geweigerd: controleer de nummers en de openstaande aanvragen';

  @override
  String get playlistPublishFailed => 'Publiceren mislukt';

  @override
  String get playlistPublishWithdrawn => 'De afspeellijst is weer privé';

  @override
  String get playlistUnpublish => 'Privé maken';

  @override
  String get playlistUnpublishSubtitle =>
      'Haalt hem uit de openbare afspeellijsten';

  @override
  String get playlistRenamePublishedTitle =>
      'Gepubliceerde afspeellijst hernoemen?';

  @override
  String get playlistRenamePublishedBody =>
      'De naam is wat beoordeeld wordt: hernoemen stuurt de afspeellijst terug naar de beoordeling en haalt hem zolang offline. Nummers toevoegen of herschikken niet.';

  @override
  String playlistByAuthor(String author) {
    return 'van $author';
  }

  @override
  String get settingsSpectrumMode => 'Spectrummodus';

  @override
  String get settingsSpectrumModeStandard => 'Standaard';

  @override
  String get settingsSpectrumModeColored => 'Gekleurd';

  @override
  String get settingsSpectrumModeBeam => 'Bundel';

  @override
  String get settingsSpectrumModeLine => 'Lijn';

  @override
  String get settingsSpectrumModeRing => 'Ring';

  @override
  String get settingsPianoMode => 'Weergave van de piano';

  @override
  String get settingsPianoModeRoll => 'Klavieren';

  @override
  String get settingsPianoModeFalling => 'Vallende noten';

  @override
  String get settingsPianoColor => 'Kleuren';

  @override
  String get settingsPianoColorVoice => 'Per stem';

  @override
  String get settingsPianoColorInstrument => 'Per instrument';

  @override
  String get settingsPianoGlow => 'Gloed op aangeslagen toetsen';

  @override
  String get settingsPianoLighting => 'Licht en schaduw op de toetsen';

  @override
  String get settingsPianoVoiceNames => 'Namen van de stemmen';

  @override
  String get featuredAdditionsHeader => 'Nieuw in de catalogus';

  @override
  String get featuredAdditionsCard => 'Zojuist toegevoegd';

  @override
  String get featuredAdditionsPlaylist => 'De zojuist toegevoegde nummers';

  @override
  String get releaseNotesTitle => 'Nieuw';

  @override
  String get releaseNotesV7Cpu =>
      'De app werkt niet meer op de achtergrond als er niets speelt: veel minder processor en batterij.';

  @override
  String get releaseNotesV7VizIdle =>
      'Visualisaties staan stil zolang het afspelen gestopt is, en zijn begrensd op 60 beelden per seconde (instelbaar).';

  @override
  String get releaseNotesV7Subsongs =>
      'Opgelost: op PC Engine, Master System en Atari ST (.sndh) startten sommige nummers het liedje ernaast.';

  @override
  String get releaseNotesV7Piano =>
      'De pianovisualisatie bleef leeg bij PC Engine-muziek.';

  @override
  String get releaseNotesV7Database =>
      'Een database die door een update beschadigd raakte, herstelt zichzelf nu in plaats van de bibliotheek onbereikbaar te maken.';

  @override
  String get releaseNotesDataReset =>
      'De lokale gegevens zijn voor deze beta gewist. Bibliotheek en afspeellijsten worden vanaf je account opnieuw opgebouwd; downloads moeten opnieuw.';

  @override
  String get releaseNotesDismiss => 'Doorgaan';

  @override
  String get pmManagePresets => 'Presets beheren';

  @override
  String get pmPickTooltip => 'Kies een preset';

  @override
  String get pmPickFilter => 'Presets filteren';

  @override
  String get pmSourceTooltip => 'Presetbron';

  @override
  String get pmAddToPlaylistTooltip => 'Preset aan een afspeellijst toevoegen';

  @override
  String pmSlowPresetDropped(String name) {
    return '‘$name’ is te zwaar voor dit apparaat en is opzijgezet.';
  }

  @override
  String get pmSlowDeviceTitle => 'Dit apparaat is te traag';

  @override
  String get pmSlowDeviceOff =>
      'De visualizer is uitgeschakeld: dit apparaat kan Milkdrop-presets niet bijbenen.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets opzijgezet',
      one: '$count preset opzijgezet',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Te traag op dit apparaat. Ze worden overgeslagen.';

  @override
  String get settingsPmSlowPresetsRestore => 'Herstellen';

  @override
  String get pmSourceBundled => 'Ingebouwde presets';

  @override
  String get pmSourceImports => 'Mijn imports';

  @override
  String get pmSourceAll => 'Alle presets';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets',
      one: '$count preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Nieuwe afspeellijst…';

  @override
  String get pmPlaylistName => 'Naam van de afspeellijst';

  @override
  String get pmAddedToPlaylist => 'Toegevoegd aan de afspeellijst';

  @override
  String get pmAlreadyInPlaylist => 'Staat al in deze afspeellijst';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Bladeren';

  @override
  String get pmTabPlaylists => 'Afspeellijsten';

  @override
  String get pmTabPopular => 'Populair';

  @override
  String get pmTabSetAside => 'Opzijgezet';

  @override
  String get pmSetAsideEmpty =>
      'Niets opzijgezet. Presets waarbij dit apparaat onder 6 fps zakt, komen hier terecht.';

  @override
  String get pmSetAsideRestoreAll => 'Alles herstellen';

  @override
  String get pmInstall => 'Installeren';

  @override
  String get pmInstallQueued => 'Installatie in wachtrij';

  @override
  String get pmUninstall => 'Deïnstalleren';

  @override
  String get pmUninstalled => 'Pack verwijderd';

  @override
  String get pmUse => 'Gebruiken';

  @override
  String get pmDefaultPackBanner => 'Aanbevolen starterpack';

  @override
  String pmLicense(String license) {
    return 'Licentie: $license';
  }

  @override
  String get pmPacksOffline => 'Server onbereikbaar';

  @override
  String get pmSearchPresets => 'Presets zoeken…';

  @override
  String get pmPlayNow => 'Nu afspelen';

  @override
  String get pmDownloadAction => 'Downloaden';

  @override
  String get pmDownloaded => 'Preset gedownload';

  @override
  String get pmDownloadFailed => 'Download mislukt';

  @override
  String pmPreviewing(String name) {
    return 'Speelt af: $name';
  }

  @override
  String get pmLocalSection => 'Mijn afspeellijsten';

  @override
  String get pmCuratedSection => 'Rewamp-afspeellijsten';

  @override
  String get pmImportPlaylist => 'Downloaden en gebruiken';

  @override
  String get pmPlaylistImported => 'Afspeellijst klaar';

  @override
  String get pmImportFiles => 'Bestanden importeren…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets geïmporteerd',
      one: '$count preset geïmporteerd',
      zero: 'Geen preset geïmporteerd',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported =>
      'Presets toegevoegd aan de projectM-bibliotheek';

  @override
  String get pmNoPlaylists => 'Nog geen afspeellijsten met presets';

  @override
  String get pmSourceApplied => 'Presetbron toegepast';

  @override
  String get pmPlaylistEmpty => 'Deze afspeellijst is leeg';

  @override
  String get pmDays7 => '7 dagen';

  @override
  String get pmDays30 => '30 dagen';

  @override
  String get pmDays365 => '1 jaar';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weergaven',
      one: '$count weergave',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Installatie mislukt';

  @override
  String get pmSingleDownloads => 'Losse downloads';

  @override
  String pmAvailableIn(String pack) {
    return 'Beschikbaar in $pack';
  }

  @override
  String get pmCleanUp => 'Opruimen';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets verwijderd',
      one: '$count preset verwijderd',
      zero: 'Niets op te ruimen',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Deze preset vergrendelen';

  @override
  String get pmUnlockAction => 'Preset ontgrendelen';

  @override
  String get pmOrderRandom => 'Presets willekeurig';

  @override
  String get pmOrderSequential => 'Presets op volgorde';

  @override
  String get pmUpdateAvailable => 'Update beschikbaar';

  @override
  String get pmUpdate => 'Bijwerken';

  @override
  String get pmSelectAll => 'Alles selecteren';

  @override
  String get pmSelectNone => 'Selectie opheffen';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geselecteerd',
      one: '$count geselecteerd',
      zero: 'Niets geselecteerd',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Ongebruikte texturen';

  @override
  String pmTexturesFreed(String size) {
    return '$size vrijgemaakt';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texturen',
      one: '$count textuur',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'Charts';

  @override
  String get chartsGlobal => 'Globaal';

  @override
  String get chartsByCollection => 'Per collectie';

  @override
  String get chartsTopSongs => 'Topnummers';

  @override
  String get chartsTopAlbums => 'Topalbums';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Gepubliceerde lijsten';

  @override
  String chartsUpdated(String date) {
    return 'Bijgewerkt op $date';
  }

  @override
  String get chartsSource => 'Bron';

  @override
  String get settingsMidiSynth => 'MIDI-synthesizer';

  @override
  String get settingsMidiSynthAuto =>
      'Automatisch (MT-32 wanneer het bestand erom vraagt)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (emulatie)';

  @override
  String get settingsMt32Section => 'Roland MT-32-emulatie';

  @override
  String get settingsMt32RomsTitle => 'MT-32-ROM\'s';

  @override
  String get settingsMt32RomsMissing =>
      'Geen bruikbare ROM-set — importeer de control- en PCM-ROM van een MT-32 of CM-32L';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Actieve set: $set';
  }

  @override
  String get settingsMt32Import => 'ROM-bestanden importeren…';

  @override
  String get settingsMt32ImportSubtitle =>
      'Control- + PCM-ROM (.rom/.bin), MAME-helften worden geaccepteerd. ROM\'s worden niet met de app meegeleverd.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name is geen bekende MT-32-/CM-32L-ROM';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ROM-bestanden geïmporteerd',
      one: '$count ROM-bestand geïmporteerd',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Model';

  @override
  String get settingsMt32ModelAuto => 'Automatisch (CM-32L indien beschikbaar)';

  @override
  String get settingsMt32Reverb => 'Galm';

  @override
  String get engineDescMt32 =>
      'Roland MT-32-/CM-32L-emulatie voor MIDI (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Minispeler';

  @override
  String get miniWindowExit => 'Terug naar het hoofdvenster';

  @override
  String get miniWindowIdle => 'Er speelt niets';

  @override
  String get settingsAlwaysOnTopTitle => 'Altijd op voorgrond';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Houdt het venster boven alle andere — hoofdvenster én minispeler';

  @override
  String get windowAlwaysOnTopOn => 'Altijd op voorgrond: aan';

  @override
  String get miniWindowCoverFill => 'Hoes vullend inzoomen';

  @override
  String get miniWindowCoverFit => 'Hele hoes tonen';

  @override
  String get releaseNotesV7Mt32 =>
      'Nieuwe Roland MT-32-engine voor MIDI-gamemuziek, met je eigen ROM\'s. Zonder ROM\'s wordt een MIDI die voor de MT-32 is geschreven aangepast aan General MIDI.';

  @override
  String get releaseNotesV7Xmp =>
      'Tien zeldzame moduleformaten worden nu afgespeeld (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'AdLib-muziek van Westwood (.adl) speelt al haar nummers af, en BP SoundMon V1 wordt herkend op de Amiga.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac: een minispeler, compact of met de visualisatie, en de optie ‘Altijd op voorgrond’.';

  @override
  String get releaseNotesV7Instruments =>
      'Oscilloscoop, noten en piano kunnen elk instrument benoemen en kleuren, niet alleen elke stem.';

  @override
  String get releaseNotesV7Podium =>
      'Zoeken: filter de nummers die 1e, 2e of 3e werden in een demoscenewedstrijd.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'Te korte subsongs (geluidseffecten van games) blijven buiten ‘Alles afspelen’ — drempel in Instellingen → Afspelen.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Je imports: sleep een hele map erin (archieven uitgepakt), en maak, hernoem of verplaats mappen.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI: de drums klinken niet meer als een piano, en het volume vervormt niet meer.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM: presets herhalen zich niet meer van de ene start naar de volgende, en na een pauze wordt een preset niet meer onterecht uitgesloten.';

  @override
  String get libraryFileMissing => 'Bestand ontbreekt';
}
