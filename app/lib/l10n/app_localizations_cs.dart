// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get navHome => 'Domů';

  @override
  String get navSearch => 'Hledat';

  @override
  String get navLibrary => 'Knihovna';

  @override
  String get noFileSelected => 'Není vybrán žádný soubor';

  @override
  String get openFile => 'Otevřít soubor';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Nepodporovaný formát';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Nepodporovaný formát: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Není v tomto zařízení: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Soubor už na serveru není: $file';
  }

  @override
  String get failedToLoadFile => 'Soubor se nepodařilo načíst';

  @override
  String get libraryEmptyHint =>
      'Vaši interpreti, alba a playlisty\nse zobrazí zde.';

  @override
  String get libraryPlaylists => 'Playlisty';

  @override
  String get libraryArtists => 'Interpreti';

  @override
  String get libraryAlbums => 'Alba';

  @override
  String get libraryTracks => 'Skladby';

  @override
  String get libraryFavorites => 'Oblíbené';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatický playlist z vašich oblíbených skladeb';

  @override
  String get libraryRecentlyAdded => 'Nedávno přidané';

  @override
  String get libraryEmpty => 'Zatím tu nic není';

  @override
  String get libraryRemoved => 'Odebráno z knihovny';

  @override
  String get searchHint => 'Hledat…';

  @override
  String get searchTypePlaceholder => 'Zadejte název, interpreta nebo album…';

  @override
  String get searchNoResults => 'Žádné výsledky';

  @override
  String get searchDownloading => 'Stahování…';

  @override
  String searchError(String message) {
    return 'Chyba: $message';
  }

  @override
  String get tabAll => 'Skladby';

  @override
  String get tabArtists => 'Interpreti';

  @override
  String get tabAlbums => 'Alba';

  @override
  String get tabProductions => 'Produkce';

  @override
  String get filterWithVideo => 'S videem';

  @override
  String get videoUnavailable => 'Toto video není dostupné';

  @override
  String get noItems => 'Žádné položky';

  @override
  String get sortRelevance => 'Relevance';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Nedávno přehrané';

  @override
  String get noRecentTracks => 'Žádné nedávno přehrané skladby';

  @override
  String get openLocalFile => 'Otevřít místní soubor';

  @override
  String get playerSourceLocal => 'místní';

  @override
  String get browseFiles => 'Procházet soubory';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total výsledků';
  }

  @override
  String countLoadingMore(int loaded) {
    return 'Načteno: $loaded…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded výsledků';
  }

  @override
  String countScrollMore(int loaded) {
    return 'Načteno: $loaded — posunutím načtete další';
  }

  @override
  String countNLoaded(int n) {
    return 'Načteno: $n';
  }

  @override
  String countFilesLoaded(int n) {
    return 'Souborů: $n';
  }

  @override
  String get browseFilterByTitle => 'Filtrovat podle názvu…';

  @override
  String get browseNoSongs => 'Nejsou k dispozici žádné skladby';

  @override
  String get browseByFormat => 'Podle formátu';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtrovat podle formátu…';

  @override
  String get browseByPlatform => 'Podle platformy';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Název platformy…';

  @override
  String get browseByChip => 'Podle zvukového čipu';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'např. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Podle interpreta';

  @override
  String get browseByArtistSubtitle => 'Procházet skladatele';

  @override
  String get browseFilterByName => 'Filtrovat podle jména…';

  @override
  String get browseNoArtistFound => 'Nenalezen žádný interpret';

  @override
  String get browseNoArtistsAvailable => 'Nejsou k dispozici žádní interpreti';

  @override
  String get browseNoArtist => 'Žádní interpreti';

  @override
  String get browseNoAlbum => 'Žádná alba';

  @override
  String get browseTopPacks => 'Nejlepší packy';

  @override
  String get browseTopPacksSubtitle => 'Nejlépe hodnocené packy';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Nejlepší packy — $collection';
  }

  @override
  String get browseLatestPacks => 'Nejnovější packy';

  @override
  String get browseLatestPacksSubtitle => 'Nejnovější přírůstky';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Nejnovější packy — $collection';
  }

  @override
  String get browseAllSongs => 'Všechny skladby';

  @override
  String get browseAllSongsSubtitleAlpha => 'Procházet v abecedním pořadí';

  @override
  String get browseAlphabetical => 'V abecedním pořadí';

  @override
  String browseAllLabel(String collection) {
    return 'Vše — $collection';
  }

  @override
  String get browseCollections => 'Kolekce';

  @override
  String browseFilesCount(String count) {
    return 'Souborů: $count';
  }

  @override
  String get browseIndexing => 'Probíhá indexování';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrovat $name…';
  }

  @override
  String get browseAllYears => 'Všechny ročníky';

  @override
  String get browseAllYearsSubtitle => 'Všechny skladby z této party';

  @override
  String get browseNoCompo => 'Pro tuto party není zaindexováno žádné compo.';

  @override
  String get browseOthers => 'Ostatní';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n příspěvků — žebříček',
      many: '$n příspěvku — žebříček',
      few: '$n příspěvky — žebříček',
      one: '$n příspěvek — žebříček',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Přehrát playlist';

  @override
  String get browsePlayAllRanked => 'Přehrát vše (v pořadí žebříčku)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb — pořadí žebříčku',
      many: '$n skladby — pořadí žebříčku',
      few: '$n skladby — pořadí žebříčku',
      one: '$n skladba — pořadí žebříčku',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Procházet podle alb';

  @override
  String get browsePlayAll => 'Přehrát vše';

  @override
  String get browseShuffle => 'Náhodné přehrávání';

  @override
  String get browseSearchInFolder => 'Hledat v této složce…';

  @override
  String get browseFilterThisList => 'Filtrovat tento seznam…';

  @override
  String get browseSearchSubfolders => 'Hledat v podsložkách';

  @override
  String get browseEmptyFolder => 'Prázdná složka';

  @override
  String browsePlaybackError(String message) {
    return 'Přehrávání selhalo: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Zobrazení';

  @override
  String get browseViewList => 'Seznam';

  @override
  String get browseViewGrid => 'Mřížka';

  @override
  String get browseViewGridCompact => 'Kompaktní mřížka';

  @override
  String get browseSearchAlbum => 'Hledat album…';

  @override
  String get browseSearchArtist => 'Hledat interpreta…';

  @override
  String get browsePlayAlbum => 'Přehrát album';

  @override
  String get searchDownloadingAlbum => 'Stahování alba…';

  @override
  String get searchCategoryChip => 'Čipy';

  @override
  String get searchCategoryGroup => 'Skupiny';

  @override
  String get artistRealName => 'Skutečné jméno';

  @override
  String get artistAliases => 'Přezdívky';

  @override
  String get artistBorn => 'Narození';

  @override
  String get artistInterview => 'Rozhovor';

  @override
  String get audioOutput => 'Zvukový výstup';

  @override
  String get audioOutputSystemDefault => 'Výchozí systémové';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Poznámky';

  @override
  String get notePlacedBadge => 'Umístila se v soutěži';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count členů',
      many: '$count člena',
      few: '$count členové',
      one: '$count člen',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Zobrazit skladby';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modulů',
      many: '$count modulu',
      few: '$count moduly',
      one: '$count modul',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Party';

  @override
  String get searchCategoryYear => 'Rok';

  @override
  String get searchCategoryOrigin => 'Původ';

  @override
  String get searchCategoryProduction => 'Produkce';

  @override
  String get searchCategoryProductionType => 'Typy produkcí';

  @override
  String get searchCategoryPublisher => 'Vydavatelé';

  @override
  String get searchCategoryDeveloper => 'Vývojáři';

  @override
  String get searchCategoryArcadeBoard => 'Arkádové desky';

  @override
  String get searchCategorySaga => 'Sága';

  @override
  String get searchCategoryGenre => 'Žánr';

  @override
  String get searchViaArtist => 'přes interpreta';

  @override
  String get searchViaAlbum => 'přes album';

  @override
  String get searchViaSong => 'přes skladbu';

  @override
  String get searchSortPopular => 'Populární';

  @override
  String get searchSortYear => 'Rok';

  @override
  String get searchSortRandom => 'Náhodně';

  @override
  String get searchSortRating => 'Hodnocení';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hlasů',
      many: '$count hlasu',
      few: '$count hlasy',
      one: '$count hlas',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Vzestupně';

  @override
  String get searchSortDesc => 'Sestupně';

  @override
  String get searchFilters => 'Filtry';

  @override
  String get searchExactSearch => 'Přesné hledání';

  @override
  String get searchExactSearchSubtitle => 'Vypne přibližné (fuzzy) hledání';

  @override
  String get searchTags => 'Tagy';

  @override
  String searchTagSearchHint(String category) {
    return 'Hledat tag v « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Začněte psát a vyhledejte tagy.';

  @override
  String get searchTagsAndLogic => 'Více tagů = logické A.';

  @override
  String get searchFilterYear => 'Rok';

  @override
  String get searchFilterAll => 'vše';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrování podle roku vynechá skladby bez data.';

  @override
  String get searchMinRating => 'Hodnocení ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Zrušit';

  @override
  String get searchReset => 'Resetovat';

  @override
  String get searchApply => 'Použít';

  @override
  String get searchClearRecent => 'Vymazat nedávná hledání';

  @override
  String get searchBrowse => 'Procházet';

  @override
  String get searchBrowseHint =>
      'Vyberte facetu (skupina, čip, rok…) a prozkoumejte katalog, nebo výše spusťte Rádio / Překvapení.';

  @override
  String get searchDidYouMean => 'Málo výsledků — zkusit přibližné hledání?';

  @override
  String get searchYes => 'Ano';

  @override
  String get featuredCommunityTitle => 'Novinky od komunity';

  @override
  String get searchPlaylistSourceAll => 'Vše';

  @override
  String get searchPlaylistSourceUser => 'Komunita';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formát';

  @override
  String get searchPlatform => 'Platforma';

  @override
  String get filterCollection => 'Kolekce';

  @override
  String get videoWatchDemo => 'Přehrát demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Kolekce: $name';
  }

  @override
  String get searchCollectionAll => 'Vše';

  @override
  String get searchRadio => 'Rádio';

  @override
  String get searchRadioTooltip => 'Náhodná fronta podle aktuálních filtrů';

  @override
  String get searchSurprise => 'Překvapení';

  @override
  String get searchSurpriseTooltip => 'Náhodná skladba';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Žádné skladby';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n alb',
      many: '$n alba',
      few: '$n alba',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Vybrat kolekci';

  @override
  String get searchFilterCollections => 'Filtrovat kolekce…';

  @override
  String get searchFilterPlaceholder => 'Filtrovat…';

  @override
  String searchAllOf(String label) {
    return 'Vše ($label)';
  }

  @override
  String get searchNoMatch => 'Žádná shoda';

  @override
  String get searchNoPlaylist => 'Žádné playlisty';

  @override
  String get engineDescOpenmpt => 'Tracker moduly (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — zvukové čipy, osciloskop po kanálech';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archivy RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — hlasy po kanálech';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (engine reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX chiptune (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace => 'Vícečipové chiptune .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Formáty Amiga s custom čipy přes emulaci 68k (~320 přípon)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Standardní MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — syntezátor SDAT/SSEQ (16 hlasů)';

  @override
  String get engineDescV2m => 'Syntezátor V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — skutečná emulace 68000 + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — emulace R4300 + RSP audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — emulace NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + čip QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — skutečný syntezátor AY-3-8910/YM2149';

  @override
  String get engineDescOrganya =>
      'Cave Story .org — vlastní engine autora Pixel';

  @override
  String get engineDescPxtone => 'Pixelův tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — skutečný 68000 přes emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver pro PC-98 — FM OPNA + SSG + vzorky PPZ8';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ vzorky .pdx), FM YM2151';

  @override
  String get engineDescFmp =>
      'Ovladač FMP pro PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY pro FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Bezztrátový .ape';

  @override
  String get engineDescVgmstream =>
      'Streamované herní zvukové formáty (700+, včetně .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — záložní dekodér';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total skladeb',
      many: '$loaded / $total skladby',
      few: '$loaded / $total skladby',
      one: '$loaded / 1 skladba',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total alb',
      many: '$loaded / $total alba',
      few: '$loaded / $total alba',
      one: '$loaded / 1 album',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total interpretů',
      many: '$loaded / $total interpreta',
      few: '$loaded / $total interpreti',
      one: '$loaded / 1 interpret',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n alb',
      many: '$n alba',
      few: '$n alba',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n interpretů',
      many: '$n interpreta',
      few: '$n interpreti',
      one: '$n interpret',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skupin',
      many: '$n skupiny',
      few: '$n skupiny',
      one: '$n skupina',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Země';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n zemí',
      many: '$n země',
      few: '$n země',
      one: '$n země',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Složky';

  @override
  String get featuredTitle => 'Dnes doporučujeme';

  @override
  String featuredPartyNow(String party) {
    return '$party právě probíhá — stupně vítězů z minulých ročníků';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party začíná za $days dní — stupně vítězů z minulých ročníků',
      many: '$party začíná za $days dne — stupně vítězů z minulých ročníků',
      few: '$party začíná za $days dny — stupně vítězů z minulých ročníků',
      one: '$party začíná zítra — stupně vítězů z minulých ročníků',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'Sezóna $series — stupně vítězů z minulých ročníků';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Vydáno: $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Před $age lety: hry z roku $year',
      many: 'Před $age rokem: hry z roku $year',
      few: 'Před $age lety: hry z roku $year',
      one: 'Před rokem: hry z roku $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Léta $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Před $age lety: hry z roku $year',
      many: 'Před $age rokem: hry z roku $year',
      few: 'Před $age lety: hry z roku $year',
      one: 'Před rokem: hry z roku $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Premiéry: $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Výročí';

  @override
  String get featuredBirthdayHeader => 'Dnešní narozeniny';

  @override
  String get featuredBirthdayWeekHeader => 'Narozeniny tohoto týdne';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist má tento týden narozeniny';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlistů',
      many: '$count playlistů',
      few: '$count playlisty',
      one: '$count playlist',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Zkusit znovu';

  @override
  String get commonOptions => 'Možnosti';

  @override
  String get commonDownload => 'Stáhnout';

  @override
  String get commonDeleteDownload => 'Smazat stažený soubor';

  @override
  String get commonAddToPlaylist => 'Přidat do playlistu';

  @override
  String get commonPlayNext => 'Přehrát jako další';

  @override
  String get commonAddToQueueEnd => 'Přidat na konec fronty';

  @override
  String get commonAddToFavorites => 'Přidat k oblíbeným';

  @override
  String get commonRemoveFromFavorites => 'Odebrat z oblíbených';

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
  String get subsongDeleteDownloadTitle => 'Smazat tento stažený soubor?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Soubor a jeho místní záznamy (historie, skladby) budou smazány.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Skladby se nepodařilo načíst';

  @override
  String subsongTrackNumber(int number) {
    return 'Skladba $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subsongů',
      many: '$count subsongu',
      few: '$count subsongy',
      one: '$count subsong',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Přehrát vše';

  @override
  String get albumDownloading => 'Stahování alba…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Stahování alba… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Stáhněte album, abyste viděli jeho skladby';

  @override
  String get albumNotDownloadedHint =>
      'Album není stažené — spusťte přehrávání a stáhne se';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skladeb',
      many: '$count skladby',
      few: '$count skladby',
      one: '$count skladba',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Načítání podrobností…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Přehrát album';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek',
      many: '$count položky',
      few: '$count položky',
      one: '$count položka',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Nejprve tuto skladbu přehrajte z vyhledávání, aby se stáhla';

  @override
  String get libraryAddedTrack => 'Skladba přidána do knihovny';

  @override
  String get libraryAddedAlbum => 'Album přidáno do knihovny';

  @override
  String get libraryAddedArtist => 'Interpret přidán do knihovny';

  @override
  String get libraryRemovedTrack => 'Skladba odebrána z knihovny';

  @override
  String get libraryRemovedAlbum => 'Album odebráno z knihovny';

  @override
  String get libraryRemovedArtist => 'Interpret odebrán z knihovny';

  @override
  String songTilePlayFailed(String message) {
    return 'Přehrávání selhalo: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Stahování selhalo — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Stahování — $label';
  }

  @override
  String get downloadsTitle => 'Stahování';

  @override
  String get downloadsEmpty => 'Žádná čekající stahování';

  @override
  String get downloadsPause => 'Pozastavit';

  @override
  String get downloadsResume => 'Pokračovat';

  @override
  String get downloadsCancel => 'Zrušit stahování';

  @override
  String get downloadsClear => 'Odebrat vše';

  @override
  String get downloadsPausedBanner =>
      'Stahování pozastaveno — aktuální soubor se nejprve dokončí';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Stahování — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Playlist';

  @override
  String get miniPlayerHideQueue => 'Skrýt playlist';

  @override
  String get transportShuffle => 'Náhodné přehrávání';

  @override
  String get transportShuffleOn => 'Náhodné přehrávání zapnuto';

  @override
  String get transportLoopOff => 'Opakování vypnuto';

  @override
  String get transportLoopQueue => 'Opakování: fronta';

  @override
  String get transportLoopTrack => 'Opakování: aktuální skladba';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spektrum';

  @override
  String get vizVoices => 'Hlasy';

  @override
  String get vizNotes => 'Noty';

  @override
  String get vizPatterns => 'Patterny';

  @override
  String get patternScrollMode => 'Režim posouvání';

  @override
  String get patternSmoothScroll => 'Plynulé posouvání';

  @override
  String get patternVolumeBars => 'Sloupce hlasitosti';

  @override
  String get patternColorScheme => 'Barevné schéma';

  @override
  String get patternSize => 'Velikost';

  @override
  String get patternColumns => 'Sloupce';

  @override
  String get patternColumnsAll => 'Úplné';

  @override
  String get patternColumnsNoteInstr => 'Zkrácené';

  @override
  String get patternColumnsNote => 'Minimální';

  @override
  String get vizClose => 'Zavřít vizualizér';

  @override
  String get vizFullscreen => 'Celá obrazovka';

  @override
  String get vizExitFullscreen => 'Ukončit celou obrazovku';

  @override
  String get vizPrevPreset => 'Předchozí preset';

  @override
  String get vizNextPreset => 'Další preset';

  @override
  String get vizProjectmUnavailable => 'projectM není k dispozici';

  @override
  String get voicesTitle => 'Hlasy';

  @override
  String get voicesNone => 'Pro tuto skladbu nejsou žádné hlasy.';

  @override
  String get voicesLongPressSolo => 'dlouhé podržení = sólo';

  @override
  String get voicesMuteAll => 'Ztlumit vše';

  @override
  String get voicesUnmuteAll => 'Zrušit ztlumení všech';

  @override
  String get voicesStereoOutput => 'Stereo výstup';

  @override
  String get voicesLeft => 'Levý';

  @override
  String get voicesRight => 'Pravý';

  @override
  String get enginesFormatsTitle => 'Přehratelné formáty';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats přehratelných formátů v $engines přehrávacích enginech.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formátů',
      many: '$count formátu',
      few: '$count formáty',
      one: '1 formát',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Převzato z $title od $artist';
  }

  @override
  String stilCover(String work) {
    return 'Převzato z $work';
  }

  @override
  String get playerQueue => 'Fronta';

  @override
  String get queueEdit => 'Upravit';

  @override
  String get queueEditDone => 'Hotovo';

  @override
  String get queueClear => 'Vyprázdnit frontu';

  @override
  String get queueClearConfirmTitle => 'Vyprázdnit frontu?';

  @override
  String get queueClearConfirmBody =>
      'Fronta se vyprázdní a přehrávání se zastaví.';

  @override
  String get queueClearConfirm => 'Vyprázdnit';

  @override
  String get queueRemoveSelected => 'Odebrat vybrané';

  @override
  String get queueRemoveTrack => 'Odebrat z fronty';

  @override
  String get queueReorder => 'Změnit pořadí';

  @override
  String get playerArtwork => 'Obal';

  @override
  String get playerVisualizer => 'Vizualizér';

  @override
  String get playerVoices => 'Hlasy';

  @override
  String get playerTrackInfo => 'Informace o skladbě';

  @override
  String get playerShowQueue => 'Playlist';

  @override
  String get playerHideQueue => 'Skrýt playlist';

  @override
  String get playerNoTrackInfo => 'Nejsou k dispozici žádné informace.';

  @override
  String get playerViewSubsongs => 'Zobrazit subsongy';

  @override
  String get playerViewAlbum => 'Zobrazit album';

  @override
  String get playerViewArtist => 'Zobrazit interpreta';

  @override
  String get playerAddToPlaylist => 'Přidat do playlistu';

  @override
  String get queueAddToPlaylist => 'Přidat frontu do playlistu';

  @override
  String get playerMoreOptions => 'Další možnosti';

  @override
  String get playerClose => 'Zavřít';

  @override
  String get playerCancel => 'Zrušit';

  @override
  String get playerDelete => 'Smazat';

  @override
  String get playerAddFavorite => 'Přidat k oblíbeným';

  @override
  String get playerRemoveFavorite => 'Odebrat z oblíbených';

  @override
  String get playerAddToLibrary => 'Přidat do knihovny';

  @override
  String get playerRemoveFromLibrary => 'Odebrat z knihovny';

  @override
  String get playerAddedToLibrary => 'Skladba přidána do knihovny';

  @override
  String get playerRemovedFromLibrary => 'Skladba odebrána z knihovny';

  @override
  String get playerDeleteDownload => 'Smazat stažený soubor';

  @override
  String get playerRedownload => 'Stáhnout soubor znovu';

  @override
  String get playerRedownloadUnavailable =>
      'Opětovné stažení není pro tento soubor k dispozici';

  @override
  String get playerDeleteDownloadTitle => 'Smazat stažený soubor?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Soubor a jeho místní záznamy (historie, skladby) budou smazány.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Vaše trendy';

  @override
  String get homeYourAllTimeTop => 'Váš žebříček všech dob';

  @override
  String get homeTrending => 'Trendy';

  @override
  String get homeFeaturedPlaylists => 'Doporučené playlisty';

  @override
  String get homeAllTimeTop => 'Žebříček všech dob';

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
      other: '$n přehrání',
      many: '$n přehrání',
      few: '$n přehrání',
      one: '$n přehrání',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Prázdný nebo nečitelný playlist';

  @override
  String get homeExtractingArchive => 'Rozbaluji archiv…';

  @override
  String get homeArchiveEmpty => 'V archivu nejsou žádné přehratelné soubory';

  @override
  String get homeNothingPlayable => 'Ve výběru není nic přehratelného';

  @override
  String get homeAlbumLoadFailed => 'Toto album se nepodařilo načíst';

  @override
  String get homeSongLoadFailed => 'Tuto skladbu se nepodařilo načíst';

  @override
  String get navStats => 'Statistiky';

  @override
  String get navSettings => 'Nastavení';

  @override
  String get playlistMoveUp => 'Přesunout do nadřazené složky';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlistů',
      many: '$n playlistů',
      few: '$n playlisty',
      one: '$n playlist',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n podsložek',
      many: '$n podsložek',
      few: '$n podsložky',
      one: '$n podsložka',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Tato složka a celý její obsah budou trvale odstraněny:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Tato složka bude odstraněna.';

  @override
  String get playlistFolderRoot => 'Kořen';

  @override
  String get playlistMoveToFolder => 'Přesunout do složky';

  @override
  String playlistDeleteTitle(String name) {
    return 'Odstranit „$name“?';
  }

  @override
  String get playlistDeleteBody => 'Tento playlist bude trvale odstraněn.';

  @override
  String get playlistRenameFolderTitle => 'Přejmenovat složku';

  @override
  String get playlistClearFavorites => 'Odstranit všechny oblíbené';

  @override
  String get playlistClearFavoritesTitle => 'Odstranit všechny oblíbené?';

  @override
  String get playlistClearFavoritesBody =>
      'Přijdeš o všechny oblíbené skladby. Tuto akci nelze vzít zpět.';

  @override
  String get playlistRemoveFromLibrary => 'Odebrat z knihovny';

  @override
  String get playlistServerReadOnly => 'Serverový playlist · jen ke čtení';

  @override
  String get navAbout => 'O aplikaci';

  @override
  String get navMore => 'Více';

  @override
  String get shellAlbumQueuedAtEnd => 'Album přidáno na konec fronty';

  @override
  String get shellAlbumQueuedNext => 'Album se přehraje jako další';

  @override
  String get shellAddingToQueue => 'Přidávání do fronty…';

  @override
  String get shellAddingNext => 'Přidávání jako další…';

  @override
  String shellDownloadFailed(String error) {
    return 'Stahování selhalo: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skladeb přidáno do fronty',
      many: '$count skladby přidáno do fronty',
      few: '$count skladby přidány do fronty',
      one: '$count skladba přidána do fronty',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" přidáno na konec fronty';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" se přehraje jako další';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Stahování selhalo: $title — přeskakuji na další skladbu';
  }

  @override
  String get shellNetworkUnavailable =>
      'Přehrávání zastaveno: síť se zdá být nedostupná.';

  @override
  String get statsTitle => 'Statistiky';

  @override
  String statsPeriodDays(int n) {
    return '$n dní';
  }

  @override
  String get statsPeriodThisYear => 'Letos';

  @override
  String get statsPeriodAll => 'Celkově';

  @override
  String get statsByMonthOrYear => 'Podle měsíce / roku…';

  @override
  String get statsByYear => 'Podle roku';

  @override
  String get statsByMonth => 'Podle měsíce';

  @override
  String get statsPlaysLabel => 'Přehrání';

  @override
  String get statsTracksLabel => 'Skladby';

  @override
  String get statsArtistsLabel => 'Interpreti';

  @override
  String get statsAlbumsLabel => 'Alba';

  @override
  String get statsListenTime => 'Doba poslechu';

  @override
  String get statsByCollection => 'Podle kolekce';

  @override
  String get statsByFormat => 'Podle formátu';

  @override
  String get statsByEngine => 'Podle enginu';

  @override
  String get statsPlaylistsLabel => 'Playlisty';

  @override
  String get statsLocalFilesSection => 'Stažené soubory';

  @override
  String get statsFilesLabel => 'Soubory';

  @override
  String get statsSpaceLabel => 'Místo na disku';

  @override
  String get statsNoPlaysInPeriod => 'V tomto období žádná přehrání';

  @override
  String get statsNoPlays => 'Žádná přehrání';

  @override
  String get statsTopTracks => 'Top skladby';

  @override
  String get statsTopAlbums => 'Top alba';

  @override
  String get statsTopArtists => 'Top interpreti';

  @override
  String statsTopTracksIn(String period) {
    return 'Top skladby — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top alba — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top interpreti — $period';
  }

  @override
  String get statsSeeAll => 'Zobrazit vše';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n přehrání',
      many: '$n přehrání',
      few: '$n přehrání',
      one: '$n přehrání',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max $n';
  }

  @override
  String get commonCancel => 'Zrušit';

  @override
  String get commonCreate => 'Vytvořit';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Smazat';

  @override
  String get commonRename => 'Přejmenovat';

  @override
  String get commonSort => 'Seřadit';

  @override
  String get commonPlayAll => 'Přehrát vše';

  @override
  String get sortName => 'Název';

  @override
  String get sortTitle => 'Název';

  @override
  String get sortArtist => 'Interpret';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Datum přidání';

  @override
  String get commonClear => 'Vymazat';

  @override
  String get sortRecentlyModified => 'Nedávno upravené';

  @override
  String get sortCreationDate => 'Datum vytvoření';

  @override
  String get playlistNameHint => 'Název';

  @override
  String get playlistNew => 'Nový playlist';

  @override
  String get playlistNewFolder => 'Nová složka';

  @override
  String get playlistNewTooltip => 'Nový playlist / složka';

  @override
  String get playlistAddTo => 'Přidat do playlistu';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Přidat do $n playlistů',
      many: 'Přidat do $n playlistu',
      few: 'Přidat do $n playlistů',
      one: 'Přidat do $n playlistu',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Vyberte playlist';

  @override
  String get playlistFilterHint => 'Filtrovat playlisty…';

  @override
  String get playlistSearchHint => 'Hledat playlist…';

  @override
  String get playlistNoMatch => 'Žádný odpovídající playlist';

  @override
  String get playlistNoneCreateHint =>
      'Žádný playlist — vytvořte ho tlačítkem +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
      zero: 'Žádné skladby',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Už jsou přidané';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n položek už je ve vybraných playlistech.',
      many: '$n položky už je ve vybraných playlistech.',
      few: '$n položky už jsou ve vybraných playlistech.',
      one: '$n položka už je ve vybraných playlistech.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Přeskočit duplicity';

  @override
  String get playlistAddAgain => 'Přidat znovu';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Přidáno $n skladeb',
      many: 'Přidáno $n skladby',
      few: 'Přidány $n skladby',
      one: 'Přidána $n skladba',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m playlistů',
      many: '$m playlistu',
      few: '$m playlistů',
      one: '$n playlistu',
    );
    return '$_temp0 do $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Nepodařilo se přidat: $error';
  }

  @override
  String get playlistRenameTitle => 'Přejmenovat playlist';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Smazat složku „$name“?';
  }

  @override
  String get playlistDeleteFolderBody => 'Její obsah se přesune o úroveň výš.';

  @override
  String get playlistEmpty => 'Prázdný playlist';

  @override
  String get playlistRemoveEntry => 'Odebrat z playlistu';

  @override
  String get trackOptionsAddToLibrary => 'Přidat do knihovny';

  @override
  String get trackOptionsRemoveFromLibrary => 'Odebrat z knihovny';

  @override
  String get trackOptionsAddedToLibrary => 'Skladba přidána do knihovny';

  @override
  String get trackOptionsRemovedFromLibrary => 'Skladba odebrána z knihovny';

  @override
  String get trackOptionsViewAlbum => 'Zobrazit album';

  @override
  String get trackOptionsViewArtist => 'Zobrazit interpreta';

  @override
  String get trackOptionsPlayNow => 'Přehrát nyní';

  @override
  String get trackOptionsPlayNext => 'Přehrát jako další';

  @override
  String get trackOptionsAddToQueueEnd => 'Přidat na konec fronty';

  @override
  String get trackOptionsPlayLast => 'Přehrát jako poslední';

  @override
  String get trackOptionsDeleteDownload => 'Smazat stažený soubor';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Smazat tento stažený soubor?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Soubor a jeho místní záznamy (historie, skladby) budou smazány.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Stažený soubor smazán';

  @override
  String get trackOptionsAddToFavorites => 'Přidat k oblíbeným';

  @override
  String get trackOptionsRemoveFromFavorites => 'Odebrat z oblíbených';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Album přidáno k oblíbeným';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album odebráno z oblíbených';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album není stažené — není co mazat';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Smazat stažené album?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Složka a všechny její místní záznamy (skladby, historie) budou smazány.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Album smazáno z místního úložiště';

  @override
  String get trackOptionsRedownloadAlbum => 'Stáhnout album znovu';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Přepíše soubory I místní záznamy';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Smazat soubory alba';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Stažená složka + místní záznamy (historie)';

  @override
  String get settingsTitle => 'Nastavení';

  @override
  String get settingsGeneral => 'Obecné';

  @override
  String get settingsGeneralSubtitle => 'Motiv';

  @override
  String get settingsVisualisation => 'Vizualizace';

  @override
  String get settingsVisualisationSubtitle => 'Osciloskopy, obal na pozadí';

  @override
  String get settingsPlayback => 'Přehrávání';

  @override
  String get settingsPlaybackSubtitle => 'Smyčky, ztišení, ticho';

  @override
  String get settingsEngines => 'Enginy';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDataSubtitle => 'Identifikátor, historie, reset';

  @override
  String get settingsBackupExport => 'Exportovat zálohu';

  @override
  String get settingsBackupExportSubtitle =>
      'Ulož knihovnu, playlisty a nastavení do souboru';

  @override
  String get settingsBackupImport => 'Importovat zálohu';

  @override
  String get settingsBackupImportSubtitle => 'Obnov data ze záložního souboru';

  @override
  String get settingsBackupExportFailed => 'Export zálohy se nezdařil';

  @override
  String get settingsBackupImportConfirmTitle => 'Importovat zálohu?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Nahradí to knihovnu, playlisty a nastavení v tomto zařízení. Stažené soubory zůstanou zachovány.';

  @override
  String get settingsBackupImportConfirm => 'Importovat';

  @override
  String get settingsBackupImportedTitle => 'Záloha importována';

  @override
  String get settingsBackupImportedBody =>
      'Tvoje data byla obnovena. Restartuj aplikaci, aby se vše projevilo.';

  @override
  String get settingsBackupTooNew =>
      'Tato záloha byla vytvořena novější verzí aplikace';

  @override
  String get settingsBackupInvalid => 'Neplatná záloha Rewamp';

  @override
  String get settingsBackupImportFailed => 'Import zálohy se nezdařil';

  @override
  String get settingsAbout => 'O aplikaci';

  @override
  String get settingsAboutSubtitle => 'Poděkování a licence';

  @override
  String get settingsCreditsSubtitle => 'Knihovny, data a komponenty';

  @override
  String get settingsSupport => 'Kontakt a podpora';

  @override
  String get settingsSupportSubtitle => 'Napište nám, web';

  @override
  String get settingsSupportEmail => 'Odeslat e-mail';

  @override
  String get settingsSupportEmailSubtitle => 'Dotaz, chyba nebo návrh';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — podpora';

  @override
  String get settingsSupportEmailIntro =>
      'Popište výše svůj dotaz, chybu nebo návrh. Informace níže nám pomáhají vám pomoci.';

  @override
  String get settingsSupportWebsite => 'Webové stránky';

  @override
  String get settingsDonation => 'Podpořit Rewamp';

  @override
  String get settingsDonationSubtitle => 'Spropitné, pokud chcete';

  @override
  String get settingsDonationBlurb =>
      'Rewamp je zdarma a bez reklam — práce ze srdce věnovaná zachování kultury demoscene a retra. Dary pomáhají financovat vývoj aplikace a pokrýt náklady na hosting databáze. Bez závazků: pokud vám aplikace dělá radost, drobné gesto vždy potěší.';

  @override
  String get settingsDonationFloppy => 'Disketa';

  @override
  String get settingsDonationCartridge => 'Cartridge';

  @override
  String get settingsDonationBox => 'Hra v krabici';

  @override
  String get settingsDonationCustom => 'Zvolit částku';

  @override
  String get settingsCancel => 'Zrušit';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Smazat';

  @override
  String get settingsReset => 'Resetovat';

  @override
  String get settingsRenew => 'Obnovit';

  @override
  String get settingsOff => 'Vyp.';

  @override
  String get settingsOn => 'Zap.';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Nekonečná';

  @override
  String get settingsDefault => 'Výchozí';

  @override
  String get settingsCoreNoScope => 'bez osciloskopu';

  @override
  String get settingsNone => 'Žádné';

  @override
  String get settingsLevelLow => 'Nízká';

  @override
  String get settingsLevelHigh => 'Vysoká';

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
  String get settingsTheme => 'Motiv';

  @override
  String get settingsThemeLight => 'Světlý';

  @override
  String get settingsThemeDark => 'Tmavý';

  @override
  String get settingsArtworkTintTitle => 'Zabarvit přehrávač podle obalu';

  @override
  String get settingsArtworkTintSubtitle =>
      'Přehrávač převezme dominantní barvu obalu';

  @override
  String get settingsGlassEffectTitle => 'Efekt liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Čočka a rozostření dolních lišt — na pomalých zařízeních vypněte';

  @override
  String get settingsResetSection => 'Resetovat tuto sekci';

  @override
  String get settingsResetEngine => 'Resetovat tento engine';

  @override
  String get settingsResetChoices => 'Resetovat tyto volby';

  @override
  String get settingsResetToDefault => 'Výchozí hodnota';

  @override
  String get settingsStartInVizTitle => 'Spouštět v režimu vizualizace';

  @override
  String get settingsStartInVizSubtitle =>
      'Přehrávač se otevře na osciloskopech místo obalu';

  @override
  String get settingsVoiceGridTitle => 'Mřížka osciloskopu hlasů';

  @override
  String get settingsVoiceGridSubtitle =>
      'Zobrazovat okraje oddělující jednotlivé hlasy';

  @override
  String get settingsKeepAwakeTitle => 'Ponechat obrazovku zapnutou';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Když je zobrazena vizualizace, obrazovka neztmavne ani se nezamkne';

  @override
  String get settingsVoiceNamesTitle => 'Názvy hlasů';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Zobrazovat název každého hlasu v jeho rámečku';

  @override
  String get settingsLineThickness => 'Tloušťka čáry';

  @override
  String get settingsColors => 'Barvy';

  @override
  String get settingsScopeVoiceColor => 'Osciloskop hlasů';

  @override
  String get settingsStereoColors => 'Stereo: barvy';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo levý';

  @override
  String get settingsStereoRightColor => 'Stereo pravý';

  @override
  String get settingsNotation => 'Notace (noty)';

  @override
  String get settingsNotePalette => 'Barevná paleta';

  @override
  String get settingsNoteBoxStyle => 'Styl bloků';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'CRT efekty';

  @override
  String get settingsCrtGlow => 'Záře (glow)';

  @override
  String get settingsCrtSpeed => 'Intenzita / rychlost';

  @override
  String get settingsArtworkOpacity => 'Krytí obalu na pozadí';

  @override
  String get settingsProjectMTitle => 'Nastavení projectM';

  @override
  String get settingsProjectMSubtitle => 'Presety, přechody, kvalita, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Oznámení při změně skladby';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Systémové oznámení s názvem nové skladby';

  @override
  String get settingsSilenceDetection => 'Detekce ticha';

  @override
  String get settingsSilenceSkipTitle => 'Při tichu přejít na další skladbu';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Automaticky přejde dál, když výstup zůstává tichý';

  @override
  String get settingsSilenceDelay => 'Prodleva ticha';

  @override
  String get settingsDefaultDuration => 'Výchozí délka';

  @override
  String get settingsDefaultDurationHelp =>
      'Použije se, když skladba neuvádí žádnou známou délku (žádný tag, žádná metadata ze serveru) — zabrání tomu, aby hrála nebo se opakovala donekonečna. Nikdy se nepoužije u skladeb z Amigy (UADE), které mají vlastní databázi délek.';

  @override
  String get settingsForcedLoopHeader => 'Vynucená smyčka / ztišení';

  @override
  String get settingsForcedLoopHelp =>
      'Některé formáty opakují konkrétní úsek (VGM, tracker moduly…), jiné ne. „Nekonečná“ ignoruje přirozený konec skladby.';

  @override
  String get settingsForceLoopCount => 'Vynutit počet smyček';

  @override
  String get settingsLoopCount => 'Počet smyček';

  @override
  String get settingsForceFadeout => 'Vynutit postupné ztišení';

  @override
  String get settingsFadeoutDuration => 'Délka ztišení';

  @override
  String get settingsResetEnginesTitle => 'Resetovat nastavení enginů?';

  @override
  String get settingsResetEnginesBody =>
      'Všechna nastavení enginů se vrátí na výchozí hodnoty.';

  @override
  String get settingsResetDefaultsTitle => 'Obnovit výchozí hodnoty';

  @override
  String get settingsResetDefaultsSubtitle => 'Všechny enginy';

  @override
  String get settingsDefaultDecoders => 'Výchozí dekodéry';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formáty, které umí přehrát více enginů';

  @override
  String get settingsDecodersHelp =>
      'Některé formáty umí přehrát více enginů. Vyberte, který se má použít jako výchozí — všechny ostatní formáty se směrují automaticky.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga trackery (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackery — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — ekvalizér, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — kvalita, filtry, volby jednotlivých čipů';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — horní propust';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — používaný SoundFont';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolace, dolní propust, echo';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorama, sluchátka, zesílení, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — hodiny, model, filtry ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — harmonický režim stereo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, dozvuk';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — jádra YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Hlavní hlasitost';

  @override
  String get settingsAmigaFilter => 'Filtr Amiga';

  @override
  String get settingsInterpolation => 'Interpolace';

  @override
  String get settingsPolyphony => 'Polyfonie';

  @override
  String get settingsReverb => 'Dozvuk';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Žádná';

  @override
  String get settingsInterpLinear => 'Lineární';

  @override
  String get settingsInterpCubic => 'Kubická';

  @override
  String get settingsInterpSinc => 'Sinc (nejlepší)';

  @override
  String get settingsStereoSeparation => 'Stereo separace';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Ukončí skladbu, když engine zjistí dlouhé ticho';

  @override
  String get settingsStereoDepth => 'Hloubka sterea';

  @override
  String get settingsEqualizer => 'Ekvalizér';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — bez vlivu na SPC';

  @override
  String get settingsBass => 'Basy';

  @override
  String get settingsTreble => 'Výšky';

  @override
  String get settingsAppliedLive => 'Použije se okamžitě, i během přehrávání.';

  @override
  String get settingsAppliedNextTrack => 'Použije se u další načtené skladby.';

  @override
  String get settingsSidEmulation => 'Emulace';

  @override
  String get settingsSidResidfp => 'ReSIDfp (přesná)';

  @override
  String get settingsSidLite => 'SIDLite (rychlá)';

  @override
  String get settingsSidSampling => 'Vzorkování';

  @override
  String get settingsSidSamplingInterp => 'Interpolace (rychlá)';

  @override
  String get settingsSidSamplingResample => 'Resample (nejlepší)';

  @override
  String get settingsSidClock => 'Hodiny';

  @override
  String get settingsSidModel => 'Model SID';

  @override
  String get settingsSidFilter => 'Filtr SID';

  @override
  String get settingsSidForceSecond => 'Vynutit 2. SID';

  @override
  String get settingsSidSecondSubtitle => 'Stereo skladby 2SID';

  @override
  String get settingsSidSecondAddr => 'Adresa 2. SID';

  @override
  String get settingsSidForceThird => 'Vynutit 3. SID';

  @override
  String get settingsSidThirdAddr => 'Adresa 3. SID';

  @override
  String get settingsSidAutoFilter => 'Automatický rozsah filtru 6581';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Hodnota doporučená pro autora skladby (tabulky sidplayfp)';

  @override
  String get settingsSid6581Range => 'Rozsah filtru 6581';

  @override
  String get settingsSid6581Curve => 'Křivka filtru 6581';

  @override
  String get settingsSid8580Curve => 'Křivka filtru 8580';

  @override
  String get settingsSidNote =>
      'Filtr SID a křivky se použijí okamžitě; emulace/vzorkování/hodiny/model/2. a 3. SID se projeví u další skladby.';

  @override
  String get settingsAudioOutput => 'Zvukový výstup';

  @override
  String get settingsAdplugNote =>
      'Surround: dva mírně rozladěné čipy OPL. Použije se u další skladby.';

  @override
  String get settingsHeSpuMain => 'Hlavní hlasy (SPU)';

  @override
  String get settingsHeSpuReverb => 'Dozvuk (SPU)';

  @override
  String get settingsNsfQuality => 'Kvalita (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Dolní propust';

  @override
  String get settingsHighpassFilter => 'Horní propust';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsNsfRegionNtscForced => 'Vynucené NTSC';

  @override
  String get settingsNsfRegionPalForced => 'Vynucené PAL';

  @override
  String get settingsNsfRegionDendyForced => 'Vynucené Dendy';

  @override
  String get settingsNsfForceIrq => 'Vynutit IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulzy (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — trojúhelník / šum / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Zrušit ztlumení při resetu';

  @override
  String get settingsNsfPhaseRefresh => 'Obnovovat fázi';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Resetovat fázi při zápisu periody';

  @override
  String get settingsNsfNonlinearMixer => 'Nelineární mixáž';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'Skutečná mixáž čipu 2A03 (jinak lineární)';

  @override
  String get settingsNsfDutySwap => 'Prohodit duty cykly';

  @override
  String get settingsNsfDutySwapSubtitle => 'Pořadí duty 25 % / 50 %';

  @override
  String get settingsNsfNegateSweep => 'Záporný sweep při inicializaci';

  @override
  String get settingsNsfEnable4011 => 'Registr \$4011 zapnutý';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Přímý výstup DAC (původní cvakání)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodický šum';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => 'Krátký režim generátoru šumu';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM anti-click';

  @override
  String get settingsNsfRandomizeNoise => 'Náhodný šum při inicializaci';

  @override
  String get settingsNsfTriangleMute => 'Ztlumit trojúhelník';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Ztiší trojúhelník při ultrazvukových periodách';

  @override
  String get settingsNsfRandomizeTri => 'Náhodný trojúhelník při inicializaci';

  @override
  String get settingsNsfDpcmReverse => 'Obrácené DPCM';

  @override
  String get settingsNsfN163Serial => 'Sériové multiplexování';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Skutečné bzučení N163 u vícehlasých skladeb';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fáze jen pro čtení';

  @override
  String get settingsNsfN163LimitWavelength => 'Omezit vlnovou délku';

  @override
  String get settingsNsfFdsCutoff => 'Mezní frekvence dolní propusti';

  @override
  String get settingsNsfFds4085Reset => 'Reset \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Ochrana proti zápisu';

  @override
  String get settingsNsfVrc7Patch => 'Sada patchů';

  @override
  String get settingsNsfVrc7Opll => 'Režim OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Emulovat YM2413 místo VRC7';

  @override
  String get settingsGbsHpFilter => 'Horní propust (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klasický GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Echo';

  @override
  String get settingsUadePostfx => 'Následné zpracování';

  @override
  String get settingsUadePostfxSubtitle =>
      'Zapne řetězec efektů (nutné pro vše níže)';

  @override
  String get settingsUadePan => 'Panorama (stereo separace)';

  @override
  String get settingsUadePanValue => 'Míra panoramatu';

  @override
  String get settingsUadeHeadphones => 'Sluchátka';

  @override
  String get settingsUadeLed => 'LED (filtr Paula)';

  @override
  String get settingsUadeLedAuto => 'Auto (podle skladby)';

  @override
  String get settingsUadeLedOn => 'Vynuceně ZAP';

  @override
  String get settingsUadeLedOff => 'Vynuceně VYP';

  @override
  String get settingsUadeFilterType => 'Typ filtru';

  @override
  String get settingsUadeGain => 'Zesílení';

  @override
  String get settingsUadeGainValue => 'Míra zesílení';

  @override
  String get settingsSoundfontLoading => 'Načítání katalogu…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Katalog není k dispozici ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Stahování selhalo: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importovat SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Vyberte soubor .sf2 v tomto zařízení';

  @override
  String get settingsSoundfontImported => 'Importováno';

  @override
  String get settingsSoundfontInvalid => 'Tento soubor není SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Import se nezdařil — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Smazat soubor';

  @override
  String get settingsCreditsHeader => 'Poděkování a licence';

  @override
  String get settingsRightsNotice =>
      'Rewamp je přehrávač: nehostuje žádné soubory ani nešíří hudbu. Skladby pocházejí z online archivů uchovávajících dědictví a zůstávají majetkem svých držitelů práv. Je na vás, abyste ověřili, že jejich poslech, stahování a uchovávání je v souladu s platnými právy a s předpisy vaší země.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podporovaných formátů',
      many: '$count podporovaného formátu',
      few: '$count podporované formáty',
      one: '$count podporovaný formát',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rozděleno do $count přehrávacích enginů — zobrazit podrobnosti',
      many: 'Rozděleno do $count přehrávacího enginu — zobrazit podrobnosti',
      few: 'Rozděleno do $count přehrávacích enginů — zobrazit podrobnosti',
      one: 'Zpracovává $count přehrávací engine — zobrazit podrobnosti',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Délky skladeb a metadata pro Amigu';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb od Mattiho Tiainena (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Data a obaly C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadata a grafika her pro C64.';

  @override
  String get settingsFt2FontTitle => 'Písmo FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'Styl FastTracker II vizualizéru patternů používá bitmapové písmo FT2 z ft2-clone od 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url zkopírováno';
  }

  @override
  String get settingsOpenLink => 'Otevřít odkaz';

  @override
  String get settingsEnginesHeader => 'Přehrávací enginy';

  @override
  String get settingsComponentsHeader => 'Další komponenty';

  @override
  String get settingsResetAll => 'Resetovat všechna nastavení';

  @override
  String get settingsResetAllSubtitle =>
      'Obecné, Vizualizace, Přehrávání, Enginy — kromě knihovny';

  @override
  String get settingsResetAllTitle => 'Resetovat všechna nastavení?';

  @override
  String get settingsResetAllBody =>
      'Obecné, Vizualizace, Přehrávání a všechny enginy se vrátí na výchozí hodnoty. Vaše knihovna a historie zůstanou beze změny.';

  @override
  String get settingsRenewUserId => 'Obnovit anonymní identifikátor';

  @override
  String get settingsRenewUserIdTitle => 'Obnovit anonymní identifikátor?';

  @override
  String get settingsRenewUserIdBody =>
      'Pro serverové statistiky bude vytvořen nový anonymní identifikátor.\n\nStarý se už nebude používat. Vaše místní historie a oblíbené položky zůstanou beze změny.';

  @override
  String get settingsRenewUserIdFailed => 'Selhalo — server je nedostupný';

  @override
  String settingsNewUserId(String id) {
    return 'Nový identifikátor: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Žádný registrovaný identifikátor';

  @override
  String get settingsCleanDb => 'Vyčistit místní databázi';

  @override
  String get settingsCleanDbSubtitle =>
      'Odstraní záznamy, jejichž soubor už neexistuje (smazaná stahování, staré chyby)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odstraněno $count osiřelých záznamů',
      many: 'Odstraněno $count osiřelého záznamu',
      few: 'Odstraněny $count osiřelé záznamy',
      one: 'Odstraněn $count osiřelý záznam',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'Místní databáze je čistá — není co odstraňovat';

  @override
  String get settingsClearCache => 'Vymazat mezipaměť (obaly a metadata)';

  @override
  String get settingsClearCacheSubtitle =>
      'Odstraní obaly z mezipaměti a stažená metadata (STIL, délky skladeb) — znovu se stáhnou při dalším přehrání';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mezipaměť vymazána ($count obalů)',
      many: 'Mezipaměť vymazána ($count obalu)',
      few: 'Mezipaměť vymazána ($count obaly)',
      one: 'Mezipaměť vymazána ($count obal)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Resetovat statistiky';

  @override
  String get settingsResetStatsSubtitle =>
      'Odstraní historii poslechu a počítadla přehrání';

  @override
  String get settingsClearStatsTitle => 'Resetovat statistiky?';

  @override
  String get settingsClearStatsBody =>
      'Trvale se smaže:\n• celá historie poslechu\n• počítadla přehrání\n\nVaše oblíbené položky a knihovna zůstanou beze změny.';

  @override
  String get settingsStatsCleared => 'Statistiky smazány';

  @override
  String get settingsResetDatabase => 'Resetovat databázi';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Smaže vše: historii, oblíbené, playlisty, mezipaměť';

  @override
  String get settingsResetDbTitle => 'Resetovat databázi?';

  @override
  String get settingsResetDbBody =>
      'Trvale se smaže:\n• celá historie poslechu\n• všechna počítadla\n• všechny oblíbené položky\n• všechny playlisty\n• všechna metadata v mezipaměti\n\nVaše zvukové soubory smazány nebudou.';

  @override
  String get settingsDbReset => 'Databáze resetována';

  @override
  String get settingsDeleteDownloads => 'Smazat stažené soubory';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Smaže všechny soubory ve složce online (skladby, obaly)';

  @override
  String get settingsDeleteDownloadsTitle => 'Smazat stažené soubory?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Trvale se smažou všechny stažené soubory (skladby, alba, obaly) ze složky online.\n\nZáznamy v databázi zůstanou, ale budou odkazovat na neexistující soubory.';

  @override
  String get settingsDownloadsDeleted => 'Stažené soubory smazány';

  @override
  String get settingsColor => 'Barva';

  @override
  String get settingsPmPresets => 'Presety';

  @override
  String get settingsPmRandomNext => 'Náhodný další preset';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Vyp.: presety se přehrávají v pořadí';

  @override
  String get settingsPmLockPreset => 'Zamknout preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Bez automatického přepínání';

  @override
  String get settingsPmPresetDuration => 'Čas mezi presety';

  @override
  String get settingsPmTransitions => 'Přechody';

  @override
  String get settingsPmBlend => 'Přechod prolnutím';

  @override
  String get settingsPmBlendSubtitle => 'Vyp.: okamžité přepnutí presetu';

  @override
  String get settingsPmTransitionStyle => 'Styl přechodu';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Vzor, který používá prolínání';

  @override
  String get settingsPmTransitionRandom => 'Náhodně';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Přepínání presetů synchronizované s beatem';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minimální čas';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: citlivost';

  @override
  String get settingsPmRendering => 'Vykreslování';

  @override
  String get settingsPmQuality => 'Kvalita';

  @override
  String get settingsPmQualitySubtitle =>
      'Rozlišení vykreslování (Max = nativní rozlišení)';

  @override
  String get settingsPmBeatSensitivity => 'Citlivost na beat';

  @override
  String get settingsPmAspectRatio => 'Zachovat poměr stran';

  @override
  String get settingsPmAspectRatioSubtitle => 'Pro shadery, které to podporují';

  @override
  String get settingsPmPermissive => 'Permisivní režim';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Načítat soubory .milk s chybami ve skriptech';

  @override
  String get accountTitle => 'Účet';

  @override
  String get accountSubtitle => 'Zálohuj a synchronizuj svou knihovnu';

  @override
  String get accountAnonymous => 'Anonymní účet';

  @override
  String get accountAnonymousExplain =>
      'Oblíbené a historie jsou uložené na serveru, ale dostane se k nim jen toto zařízení. Přidej e-mailovou adresu, ať je najdeš i jinde.';

  @override
  String get accountEmailAttached => 'Adresa potvrzena — účet lze obnovit';

  @override
  String get accountEmailPending => 'Adresa zatím nepotvrzena';

  @override
  String get accountInsecureStorage =>
      'Zabezpečené úložiště zařízení není dostupné: identifikátor účtu je uložen nešifrovaně.';

  @override
  String get accountSaveCta => 'Uložit můj účet';

  @override
  String get accountStatSongs => 'Oblíbené skladby';

  @override
  String get accountStatAlbums => 'Oblíbená alba';

  @override
  String get accountStatPlays => 'Přehrání';

  @override
  String get accountCreatedLabel => 'Vytvořeno';

  @override
  String get accountSignOut => 'Odhlásit se';

  @override
  String get accountRevoke => 'Odhlásit všude';

  @override
  String get accountRevokeSubtitle => 'Odhlásí všechna ostatní zařízení';

  @override
  String get accountRevokeBody =>
      'Všechna ostatní zařízení budou odhlášena. Toto zůstane přihlášené.';

  @override
  String get accountRevokeDone => 'Ostatní zařízení odhlášena';

  @override
  String get accountDelete => 'Smazat můj účet';

  @override
  String get accountDeleteSubtitle =>
      'Smaže účet a jeho data na serveru. Nevratné.';

  @override
  String accountDeleteBody(int items, int lists) {
    return 'Ze serveru bude smazáno $items oblíbených a $lists playlistů. Akci nelze vrátit zpět.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Vaše stažené soubory a knihovna v tomto zařízení zůstanou nedotčeny.';

  @override
  String get accountDeleteDone => 'Účet smazán';

  @override
  String get accountSignOutSubtitle => 'Zařízení začne znovu s prázdným účtem';

  @override
  String get accountSignOutTitle => 'Odhlásit se?';

  @override
  String accountSignOutBody(String email) {
    return 'K tomuto účtu se vrátíš pomocí kódu zaslaného na $email.';
  }

  @override
  String get accountSignedOut => 'Odhlášeno';

  @override
  String get accountNoSignOut => 'Odhlášení není dostupné';

  @override
  String get accountNoSignOutSubtitle =>
      'Bez e-mailové adresy by byl tento účet nenávratně ztracen.';

  @override
  String get accountDetach => 'Odpojit adresu';

  @override
  String get accountDetachSubtitle =>
      'Účet bude opět anonymní, žádná data se nemažou';

  @override
  String get accountDetachBody =>
      'Bez adresy už tento účet nepůjde obnovit z jiného zařízení.';

  @override
  String get accountDetachDone => 'Adresa odpojena';

  @override
  String get accountOffline => 'Účet není offline dostupný';

  @override
  String get accountEmailTitle => 'E-mailová adresa';

  @override
  String get accountEmailExplain =>
      'Pošleme ti šestimístný kód pro potvrzení adresy. Slouží pouze k obnovení účtu.';

  @override
  String get accountEmailLabel => 'E-mailová adresa';

  @override
  String get accountCodeTitle => 'Potvrzovací kód';

  @override
  String accountCodeExplain(String email) {
    return 'Kód odeslán na $email. Platí 10 minut.';
  }

  @override
  String get accountCodeLabel => 'Šestimístný kód';

  @override
  String get accountSendCode => 'Odeslat kód';

  @override
  String get accountVerify => 'Potvrdit';

  @override
  String get accountResend => 'Odeslat kód znovu';

  @override
  String accountResendIn(int n) {
    return 'Znovu odeslat za $n s';
  }

  @override
  String get accountCheckSpam => 'E-mail může chvíli trvat — mrkni i do spamu.';

  @override
  String get accountErrorInvalidEmail => 'Neplatná adresa';

  @override
  String get accountErrorTooMany =>
      'Příliš mnoho požadavků, zkus to za pár minut';

  @override
  String get accountErrorInvalidCode => 'Nesprávný nebo vypršelý kód';

  @override
  String get accountErrorCodeLength => 'Kód má 6 číslic';

  @override
  String get accountErrorNetwork => 'Připojení selhalo, zkus to znovu';

  @override
  String get accountMergeTitle => 'Sloučit tuto knihovnu?';

  @override
  String accountMergeBody(String email) {
    return 'Oblíbené a historie z tohoto zařízení se přidají k účtu $email. Operaci nelze vzít zpět.';
  }

  @override
  String get accountMergeConfirm => 'Sloučit';

  @override
  String get accountCarryLocal => 'Zachovat oblíbené z tohoto zařízení';

  @override
  String accountCarryLocalOn(int n) {
    return 'Oblíbené ($n) a playlisty z tohoto zařízení budou přidány k účtu.';
  }

  @override
  String get accountCarryLocalOff =>
      'Budou z tohoto zařízení smazány a nahrazeny těmi z účtu. Stažené soubory zůstanou.';

  @override
  String get accountDropLocalTitle => 'Smazat data z tohoto zařízení?';

  @override
  String get accountCreatedOk => 'Účet uložen, knihovna je v bezpečí';

  @override
  String get accountMergedOk => 'Přihlášeno — místní oblíbené byly přidány';

  @override
  String get accountSignedInOk => 'Přihlášeno';

  @override
  String get playlistEntryMissing => 'Soubor v tomto zařízení chybí';

  @override
  String get playlistEntryMissingRestorable =>
      'Soubor chybí — lze stáhnout znovu';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n chybí',
      many: '$n chybí',
      few: '$n chybí',
      one: '$n chybí',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Uložit do mého účtu';

  @override
  String get playlistBackupSubtitle =>
      'Zachová tento playlist i po přeinstalaci';

  @override
  String get playlistBackupUpdate => 'Aktualizovat zálohu';

  @override
  String get playlistBackupUpdateSubtitle => 'Nahradí kopii v účtu touto verzí';

  @override
  String get playlistBackupStop => 'Přestat zálohovat';

  @override
  String get playlistBackupStopped => 'Záloha odstraněna';

  @override
  String get playlistBackupDone => 'Playlist uložen';

  @override
  String get playlistBackupFailed => 'Uložení se nezdařilo';

  @override
  String get playlistBackupNoAccount => 'V tomto zařízení není účet';

  @override
  String get playlistSyncTooltip => 'Synchronizovat s mým účtem';

  @override
  String get playlistSyncRunning => 'Synchronizuji…';

  @override
  String get playlistSyncDone => 'Playlisty synchronizovány';

  @override
  String get playlistSyncPartial => 'Některé playlisty se nepodařilo uložit';

  @override
  String get playlistFetchMissing => 'Stáhnout chybějící skladby';

  @override
  String get playlistFetchDone => 'Chybějící skladby staženy';

  @override
  String get playlistFetchPartial => 'Některé skladby se nepodařilo stáhnout';

  @override
  String get playlistEntryFetchFailed => 'Tuto skladbu se nepodařilo stáhnout';

  @override
  String get accountStatPlaylists => 'Playlisty';

  @override
  String get accountSyncNow => 'Synchronizovat teď';

  @override
  String get accountSyncAuto => 'Probíhá sama na pozadí';

  @override
  String get accountSyncAnonymous =>
      'Zálohováno na server. Přidejte e-mail, abyste mohli synchronizovat další zařízení.';

  @override
  String get accountSyncPending => 'Změny čekají na odeslání';

  @override
  String accountSyncLast(String when) {
    return 'Poslední synchronizace: $when';
  }

  @override
  String get accountSyncDone => 'Synchronizace dokončena';

  @override
  String get accountSyncFailed => 'Synchronizace selhala, zkusíme to znovu';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'hudba z $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'obsahuje $place soutěže $compo';
  }

  @override
  String get competitionEmpty => 'Tato soutěž nemá žádné příspěvky';

  @override
  String get competitionEntryNoMusic =>
      'Pro tento příspěvek není v katalogu hudba';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n skladeb',
      many: '$n skladby',
      few: '$n skladby',
      one: '$n skladba',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Přeskočit';

  @override
  String get onboardingNext => 'Další';

  @override
  String get onboardingStart => 'Začít';

  @override
  String get onboardingBetaTitle => 'Beta verze';

  @override
  String get onboardingBetaBody =>
      'Rewamp se stále staví. Místní data — knihovna, playlisty, oblíbené, statistiky — mohou být před verzí 1.0 vymazána. Stažené soubory nic neohrožuje, ale to, na čem vám záleží, si uložte i jinam.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Verze $version (sestavení $build)';
  }

  @override
  String get onboardingExploreTitle => 'Objevujte';

  @override
  String get onboardingExploreBody =>
      'Procházejte a hledejte desetitisíce chiptunů a trackerových modulů z velkých online archivů — podle interpreta, alba, platformy nebo party. Klepnutím přehrajete, stažením si necháte.';

  @override
  String get onboardingLibraryTitle => 'Vaše knihovna';

  @override
  String get onboardingLibraryBody =>
      'Ukládejte, co se vám líbí, tvořte playlisty a řaďte je do složek. Stažené hraje offline a knihovna vás po přihlášení provází mezi zařízeními.';

  @override
  String get onboardingPlayerTitle => 'Přehrávač';

  @override
  String get onboardingPlayerBody =>
      'Přejetím změníte skladbu a otevřete vizualizace: osciloskop, kanály, plynoucí noty, trackerovou mřížku. Vícestopé soubory ukazují své podskladby a každý hlas lze ztlumit zvlášť.';

  @override
  String get onboardingReplayTitle => 'Představení';

  @override
  String get onboardingReplaySubtitle =>
      'Znovu zobrazit upozornění na beta verzi a průvodce';

  @override
  String get settingsPatternTitle => 'Patterny';

  @override
  String get settingsPatternSubtitle =>
      'Trackerová mřížka: barvy, sloupce, posun';

  @override
  String get patternOpaqueBg => 'Neprůhledné pozadí';

  @override
  String get patternOpaqueBgSubtitle => 'Skryje obal za mřížkou';

  @override
  String get commonSave => 'Uložit';

  @override
  String get accountDisplayName => 'Veřejné jméno';

  @override
  String get accountDisplayNameNotSet =>
      'Nenastaveno — je potřeba k publikování playlistu';

  @override
  String get accountDisplayNameHint => 'Jméno, pod kterým chceš být uveden.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Změna vrátí všechny tvé publikované playlisty zpět ke schválení.';

  @override
  String get accountDisplayNameTaken => 'Toto jméno je obsazené. Vyber jiné.';

  @override
  String get accountDisplayNameLength => '2 až 40 znaků.';

  @override
  String get accountDisplayNameSaved => 'Veřejné jméno uloženo';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlisty vrácené ke schválení: $n';
  }

  @override
  String get playlistPublish => 'Zveřejnit';

  @override
  String get playlistPublishSubtitle => 'Požádat o publikování (po schválení)';

  @override
  String get playlistPublishTitle => 'Publikovat tento playlist?';

  @override
  String get playlistPublishBody =>
      'Po schválení bude viditelný pro všechny a uveden pod tvým veřejným jménem. Obal vzniká ze skladeb.';

  @override
  String get playlistPublishCta => 'Požádat';

  @override
  String get playlistPublishSubmitted => 'Odesláno ke schválení';

  @override
  String get playlistPublishPending => 'Čeká na schválení';

  @override
  String get playlistPublishApproved => 'Veřejný';

  @override
  String playlistPublishRejected(String reason) {
    return 'Zamítnuto: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Zamítnuto';

  @override
  String get playlistPublishNeedName =>
      'Vyber jméno, pod kterým chceš být uveden';

  @override
  String get playlistPublishNeedTracks =>
      'K publikování je potřeba alespoň 5 skladeb';

  @override
  String get playlistPublishHasLocal =>
      'Soubory z tvého zařízení nelze publikovat — ostatní je nepřehrají';

  @override
  String get playlistPublishTooManyPending =>
      'Už máš 3 playlisty čekající na schválení';

  @override
  String get playlistPublishRefused =>
      'Publikování zamítnuto: zkontroluj skladby a čekající žádosti';

  @override
  String get playlistPublishFailed => 'Publikování selhalo';

  @override
  String get playlistPublishWithdrawn => 'Playlist je zase soukromý';

  @override
  String get playlistUnpublish => 'Nastavit jako soukromý';

  @override
  String get playlistUnpublishSubtitle => 'Odebere ho z veřejných playlistů';

  @override
  String get playlistRenamePublishedTitle =>
      'Přejmenovat publikovaný playlist?';

  @override
  String get playlistRenamePublishedBody =>
      'Schvaluje se právě název: přejmenování vrátí playlist ke schválení a mezitím ho skryje. Přidání nebo přeskládání skladeb ne.';

  @override
  String playlistByAuthor(String author) {
    return 'od $author';
  }

  @override
  String get settingsSpectrumMode => 'Režim spektra';

  @override
  String get settingsSpectrumModeStandard => 'Standardní';

  @override
  String get settingsSpectrumModeColored => 'Barevný';

  @override
  String get settingsSpectrumModeBeam => 'Paprsek';

  @override
  String get settingsSpectrumModeLine => 'Čára';

  @override
  String get settingsSpectrumModeRing => 'Prstenec';

  @override
  String get releaseNotesTitle => 'Novinky';

  @override
  String get releaseNotesV4Downloads =>
      'Stahování: dlouhé stahování lze zrušit v průběhu a archiv alba se už nestahuje několikrát.';

  @override
  String get releaseNotesV4Queue =>
      'Fronta: tlačítko pro její vyprázdnění, s potvrzením — zastaví také přehrávání.';

  @override
  String get releaseNotesV4DropFiles =>
      'Soubory přetažené na okno: přehrát teď, jako další nebo na konec; obaly a doprovodné soubory se vynechají a seznam skladeb přiložený v archivu se respektuje (skutečné názvy, žádné mrtvé stopy).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: importujte vlastní SoundFont ze zařízení, vedle těch ze serveru.';

  @override
  String get releaseNotesV4Formats =>
      'Herní streamy Wwise, FSB a OGL konečně hrají (vlastní Vorbis).';

  @override
  String get releaseNotesV4Chips =>
      'Šest zvukových čipů navíc, volba emulačního jádra pro každý čip (SameBoy pro Game Boy) a správná výška tónu u vzorkovacích čipů.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: soubory .vt2 hrají a pohledy na noty a patterny pokrývají celou rodinu ZX.';

  @override
  String get releaseNotesV4Loop =>
      'Opakování skladby ji skutečně zacyklí místo znovunačtení a počitadlo už nezamrzá v nekonečné smyčce.';

  @override
  String get releaseNotesV4Info =>
      'Panel ⓘ vypíše soubory, které skladba skutečně otevřela — včetně doprovodných a knihoven.';

  @override
  String get releaseNotesV4Linux => 'Verze pro Linux.';

  @override
  String get releaseNotesDataReset =>
      'Místní data byla pro tuto betu vymazána. Knihovna a playlisty se obnoví z účtu; stahování je třeba zopakovat.';

  @override
  String get releaseNotesDismiss => 'Pokračovat';

  @override
  String get pmManagePresets => 'Spravovat presety';

  @override
  String get pmPickTooltip => 'Vybrat preset';

  @override
  String get pmPickFilter => 'Filtrovat presety';

  @override
  String get pmSourceTooltip => 'Zdroj presetů';

  @override
  String get pmAddToPlaylistTooltip => 'Přidat preset do playlistu';

  @override
  String pmSlowPresetDropped(String name) {
    return '„$name“ je pro toto zařízení příliš náročný a byl vyřazen.';
  }

  @override
  String get pmSlowDeviceTitle => 'Toto zařízení je příliš pomalé';

  @override
  String get pmSlowDeviceOff =>
      'Vizualizace byla vypnuta: toto zařízení nestačí na presety Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vyřazených presetů',
      many: '$count vyřazených presetů',
      few: '$count vyřazené presety',
      one: '1 vyřazený preset',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Na tomto zařízení příliš pomalé. Přehrávání je přeskakuje.';

  @override
  String get settingsPmSlowPresetsRestore => 'Obnovit';

  @override
  String get pmSourceBundled => 'Vestavěné presety';

  @override
  String get pmSourceImports => 'Moje importy';

  @override
  String get pmSourceAll => 'Všechny presety';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presetů',
      many: '$count presetu',
      few: '$count presety',
      one: '$count preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Nový playlist…';

  @override
  String get pmPlaylistName => 'Název playlistu';

  @override
  String get pmAddedToPlaylist => 'Přidáno do playlistu';

  @override
  String get pmAlreadyInPlaylist => 'V tomto playlistu už je';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Procházet';

  @override
  String get pmTabPlaylists => 'Playlisty';

  @override
  String get pmTabPopular => 'Populární';

  @override
  String get pmTabSetAside => 'Vyřazené';

  @override
  String get pmSetAsideEmpty =>
      'Nic není vyřazeno. Sem se dostanou presety, u kterých zařízení klesne pod 6 sn./s.';

  @override
  String get pmSetAsideRestoreAll => 'Obnovit vše';

  @override
  String get pmInstall => 'Nainstalovat';

  @override
  String get pmInstallQueued => 'Instalace zařazena do fronty';

  @override
  String get pmUninstall => 'Odinstalovat';

  @override
  String get pmUninstalled => 'Pack odebrán';

  @override
  String get pmUse => 'Použít';

  @override
  String get pmDefaultPackBanner => 'Doporučený startovní pack';

  @override
  String pmLicense(String license) {
    return 'Licence: $license';
  }

  @override
  String get pmPacksOffline => 'Server je nedostupný';

  @override
  String get pmSearchPresets => 'Hledat presety…';

  @override
  String get pmPlayNow => 'Přehrát nyní';

  @override
  String get pmDownloadAction => 'Stáhnout';

  @override
  String get pmDownloaded => 'Preset stažen';

  @override
  String get pmDownloadFailed => 'Stahování se nezdařilo';

  @override
  String pmPreviewing(String name) {
    return 'Přehrává se: $name';
  }

  @override
  String get pmLocalSection => 'Moje playlisty';

  @override
  String get pmCuratedSection => 'Playlisty Rewamp';

  @override
  String get pmImportPlaylist => 'Stáhnout a použít';

  @override
  String get pmPlaylistImported => 'Playlist je připraven';

  @override
  String get pmImportFiles => 'Importovat soubory…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presetů importováno',
      many: '$count presetu importováno',
      few: '$count presety importovány',
      one: '$count preset importován',
      zero: 'Žádný preset nebyl importován',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presety přidány do knihovny projectM';

  @override
  String get pmNoPlaylists => 'Zatím žádné playlisty presetů';

  @override
  String get pmSourceApplied => 'Zdroj presetů použit';

  @override
  String get pmPlaylistEmpty => 'Tento playlist je prázdný';

  @override
  String get pmDays7 => '7 dní';

  @override
  String get pmDays30 => '30 dní';

  @override
  String get pmDays365 => '1 rok';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count přehrání',
      many: '$count přehrání',
      few: '$count přehrání',
      one: '$count přehrání',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Instalace se nezdařila';

  @override
  String get pmSingleDownloads => 'Jednotlivá stažení';

  @override
  String pmAvailableIn(String pack) {
    return 'Dostupné v $pack';
  }

  @override
  String get pmCleanUp => 'Vyčistit';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Smazáno $count presetů',
      many: 'Smazáno $count presetu',
      few: 'Smazány $count presety',
      one: 'Smazán $count preset',
      zero: 'Není co čistit',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Uzamknout tento preset';

  @override
  String get pmUnlockAction => 'Odemknout preset';

  @override
  String get pmOrderRandom => 'Presety náhodně';

  @override
  String get pmOrderSequential => 'Presety po pořadí';

  @override
  String get pmUpdateAvailable => 'K dispozici je aktualizace';

  @override
  String get pmUpdate => 'Aktualizovat';

  @override
  String get pmSelectAll => 'Vybrat vše';

  @override
  String get pmSelectNone => 'Zrušit výběr';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vybraných',
      many: '$count vybraných',
      few: '$count vybrané',
      one: '$count vybrán',
      zero: 'Nic nevybráno',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Nepoužívané textury';

  @override
  String pmTexturesFreed(String size) {
    return 'Uvolněno $size';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count textur',
      many: '$count textury',
      few: '$count textury',
      one: '$count textura',
    );
    return '$_temp0';
  }
}
