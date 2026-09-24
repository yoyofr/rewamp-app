// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get navHome => 'Kezdőlap';

  @override
  String get navSearch => 'Keresés';

  @override
  String get navLocal => 'Helyi';

  @override
  String get settingsTabsOrderTitle => 'Lapok sorrendje';

  @override
  String get settingsTabsOrderSubtitle =>
      'Húzással rendezhető. Az első négy az alsó sávban van, a többi a „Továbbiak” alatt.';

  @override
  String get settingsTabsInBar => 'A sávban';

  @override
  String get settingsTabsInMore => 'A „Továbbiak” alatt';

  @override
  String get settingsLaunchTab => 'Lap induláskor';

  @override
  String get settingsLaunchTabSubtitle => 'Melyik lapon nyíljon az alkalmazás';

  @override
  String get navLibrary => 'Könyvtár';

  @override
  String get noFileSelected => 'Nincs kiválasztott fájl';

  @override
  String get openFile => 'Fájl megnyitása';

  @override
  String get pickerLabelAudio => 'Hang';

  @override
  String get formatNotSupported => 'Nem támogatott formátum';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Nem támogatott formátum: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Nincs ezen az eszközön: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'A fájl már nincs a szerveren: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return 'A(z) $file nincs az album archívumában — a rip felsorolja, de nem tartalmazza.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return 'A(z) $host nem válaszolt. Ellenőrizze a kapcsolatot, majd próbálja újra.';
  }

  @override
  String get failedToLoadFile => 'A fájl betöltése nem sikerült';

  @override
  String get libraryEmptyHint =>
      'Az előadóid, albumaid és lejátszási listáid\nitt jelennek meg.';

  @override
  String get libraryPlaylists => 'Lejátszási listák';

  @override
  String get libraryArtists => 'Előadók';

  @override
  String get libraryAlbums => 'Albumok';

  @override
  String get libraryTracks => 'Számok';

  @override
  String get libraryFavorites => 'Kedvencek';

  @override
  String get libraryFavoritesSubtitle =>
      'A kedvenc számaidból készülő automatikus lejátszási lista';

  @override
  String get libraryRecentlyAdded => 'Nemrég hozzáadva';

  @override
  String get libraryEmpty => 'Itt még nincs semmi';

  @override
  String get libraryRemoved => 'Eltávolítva a könyvtárból';

  @override
  String get searchHint => 'Keresés…';

  @override
  String get searchTypePlaceholder => 'Írj be egy címet, előadót vagy albumot…';

  @override
  String get searchNoResults => 'Nincs találat';

  @override
  String get searchDownloading => 'Letöltés…';

  @override
  String searchError(String message) {
    return 'Hiba: $message';
  }

  @override
  String get tabAll => 'Számok';

  @override
  String get tabArtists => 'Előadók';

  @override
  String get tabAlbums => 'Albumok';

  @override
  String get tabProductions => 'Produkciók';

  @override
  String get filterWithVideo => 'Videóval';

  @override
  String get videoUnavailable => 'Ez a videó nem érhető el';

  @override
  String get noItems => 'Nincsenek elemek';

  @override
  String get sortRelevance => 'Relevancia';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Nemrég hallgatott';

  @override
  String get noRecentTracks => 'Nincs nemrég hallgatott szám';

  @override
  String get playerSourceLocal => 'helyi';

  @override
  String get homePlayFiles => 'Fájlok lejátszása';

  @override
  String get homePlayFolder => 'Mappa lejátszása';

  @override
  String get homeSectionsOrderTitle => 'Szakaszok sorrendje';

  @override
  String get homeSectionsOrderSubtitle =>
      'Húzással rendezheted a kezdőképernyőt tetszés szerint.';

  @override
  String get homeSectionsOrderReset => 'Alapértelmezett sorrend';

  @override
  String get homeSectionsOrderSettings =>
      'A kezdőképernyő szakaszainak sorrendje';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total találat';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded betöltve…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded találat';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded betöltve — görgess a többiért';
  }

  @override
  String countNLoaded(int n) {
    return '$n betöltve';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n fájl';
  }

  @override
  String get browseFilterByTitle => 'Szűrés cím szerint…';

  @override
  String get browseNoSongs => 'Nincs elérhető szám';

  @override
  String get browseByFormat => 'Formátum szerint';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Szűrés formátum szerint…';

  @override
  String get browseByPlatform => 'Platform szerint';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Platform neve…';

  @override
  String get browseByChip => 'Hangchip szerint';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'pl. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Előadó szerint';

  @override
  String get browseByArtistSubtitle => 'Zeneszerzők böngészése';

  @override
  String get browseFilterByName => 'Szűrés név szerint…';

  @override
  String get browseNoArtistFound => 'Nem található előadó';

  @override
  String get browseNoArtistsAvailable => 'Nincs elérhető előadó';

  @override
  String get browseNoArtist => 'Nincsenek előadók';

  @override
  String get browseNoAlbum => 'Nincsenek albumok';

  @override
  String get browseTopPacks => 'Legjobb csomagok';

  @override
  String get browseTopPacksSubtitle => 'A legjobbra értékelt csomagok';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Legjobb csomagok — $collection';
  }

  @override
  String get browseLatestPacks => 'Legújabb csomagok';

  @override
  String get browseLatestPacksSubtitle => 'A legfrissebb bővítések';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Legújabb csomagok — $collection';
  }

  @override
  String get browseAllSongs => 'Összes szám';

  @override
  String get browseAllSongsSubtitleAlpha => 'Böngészés ábécésorrendben';

  @override
  String get browseAlphabetical => 'Ábécésorrendben';

  @override
  String browseAllLabel(String collection) {
    return 'Összes — $collection';
  }

  @override
  String get browseCollections => 'Gyűjtemények';

  @override
  String browseFilesCount(String count) {
    return '$count fájl';
  }

  @override
  String get browseIndexing => 'Indexelés folyamatban';

  @override
  String browseFilterFacet(String name) {
    return 'Szűrés: $name…';
  }

  @override
  String get browseAllYears => 'Összes év';

  @override
  String get browseAllYearsSubtitle => 'A party összes száma';

  @override
  String get browseNoCompo => 'Ehhez a partyhoz nincs indexelt compo.';

  @override
  String get browseOthers => 'Egyéb';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nevezés — helyezés szerint',
      one: '$n nevezés — helyezés szerint',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Lejátszási lista lejátszása';

  @override
  String get browsePlayAllRanked =>
      'Összes lejátszása (helyezés szerinti sorrendben)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám — helyezés szerinti sorrend',
      one: '$n szám — helyezés szerinti sorrend',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Böngészés albumok szerint';

  @override
  String get browsePlayAll => 'Összes lejátszása';

  @override
  String get browseShuffle => 'Véletlenszerű lejátszás';

  @override
  String get browseSearchInFolder => 'Keresés ebben a mappában…';

  @override
  String get browseFilterThisList => 'Lista szűrése…';

  @override
  String get browseSearchSubfolders => 'Keresés almappákban';

  @override
  String get browseEmptyFolder => 'Üres mappa';

  @override
  String browsePlaybackError(String message) {
    return 'A lejátszás nem sikerült: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Nézet';

  @override
  String get browseViewList => 'Lista';

  @override
  String get browseViewGrid => 'Rács';

  @override
  String get browseViewGridCompact => 'Kompakt rács';

  @override
  String get browseSearchAlbum => 'Album keresése…';

  @override
  String get browseSearchArtist => 'Előadó keresése…';

  @override
  String get browsePlayAlbum => 'Album lejátszása';

  @override
  String get searchDownloadingAlbum => 'Album letöltése…';

  @override
  String get searchCategoryChip => 'Chipek';

  @override
  String get searchCategoryGroup => 'Csoportok';

  @override
  String get artistRealName => 'Valódi név';

  @override
  String get artistAliases => 'Álnevek';

  @override
  String get artistBorn => 'Született';

  @override
  String get artistInterview => 'Interjú';

  @override
  String get audioOutput => 'Hangkimenet';

  @override
  String get audioOutputSystemDefault => 'Rendszer alapértelmezés';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Jegyzetek';

  @override
  String get notePlacedBadge => 'Helyezést ért el a versenyen';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tag',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Dalok megtekintése';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modul',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Partyk';

  @override
  String get searchCategoryYear => 'Év';

  @override
  String get searchCategoryOrigin => 'Eredet';

  @override
  String get searchCategoryProduction => 'Produkció';

  @override
  String get searchCategoryProductionType => 'Produkciótípusok';

  @override
  String get searchCategoryPublisher => 'Kiadók';

  @override
  String get searchCategoryDeveloper => 'Fejlesztők';

  @override
  String get searchCategoryArcadeBoard => 'Játéktermi panelek';

  @override
  String get searchCategorySaga => 'Sorozat';

  @override
  String get searchCategoryGenre => 'Műfaj';

  @override
  String get searchViaArtist => 'előadón keresztül';

  @override
  String get searchViaAlbum => 'albumon keresztül';

  @override
  String get searchViaSong => 'számon keresztül';

  @override
  String get searchSortPopular => 'Népszerű';

  @override
  String get searchSortYear => 'Év';

  @override
  String get searchSortRandom => 'Véletlenszerű';

  @override
  String get searchSortRating => 'Értékelés';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count szavazat',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Növekvő';

  @override
  String get searchSortDesc => 'Csökkenő';

  @override
  String get searchFilters => 'Szűrők';

  @override
  String get searchExactSearch => 'Pontos keresés';

  @override
  String get searchExactSearchSubtitle =>
      'Kikapcsolja a közelítő (fuzzy) keresést';

  @override
  String get searchTags => 'Címkék';

  @override
  String searchTagSearchHint(String category) {
    return 'Címke keresése a « $category » kategóriában…';
  }

  @override
  String get searchTagTypeToSearch => 'Írj be valamit a címkék kereséséhez.';

  @override
  String get searchTagsAndLogic => 'Több címke = logikai ÉS.';

  @override
  String get searchFilterYear => 'Év';

  @override
  String get searchFilterAll => 'összes';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Az év szerinti szűrés kihagyja a dátum nélküli számokat.';

  @override
  String get searchMinRating => 'Értékelés ≥';

  @override
  String get searchPodium => 'Dobogó';

  @override
  String get searchPodiumAny => 'Bármely dobogós hely';

  @override
  String get searchPodiumUnavailable =>
      'A dobogós szűrő még nem érhető el a szerveren';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Mégse';

  @override
  String get searchReset => 'Alaphelyzet';

  @override
  String get searchApply => 'Alkalmaz';

  @override
  String get searchClearRecent => 'Legutóbbi keresések törlése';

  @override
  String get searchBrowse => 'Böngészés';

  @override
  String get searchBrowseHint =>
      'Válassz egy szempontot (csoport, chip, év…) a katalógus felfedezéséhez, vagy indítsd el fent a Rádiót / Meglepetést.';

  @override
  String get searchDidYouMean =>
      'Kevés a találat — kipróbálod a közelítő keresést?';

  @override
  String get searchYes => 'Igen';

  @override
  String get featuredCommunityTitle => 'Újdonságok a közösségtől';

  @override
  String get searchPlaylistSourceAll => 'Összes';

  @override
  String get searchPlaylistSourceUser => 'Közösség';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formátum';

  @override
  String get searchPlatform => 'Platform';

  @override
  String get filterCollection => 'Gyűjtemény';

  @override
  String get videoWatchDemo => 'Demó megtekintése';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Gyűjtemény: $name';
  }

  @override
  String get searchCollectionAll => 'Összes';

  @override
  String get searchRadio => 'Rádió';

  @override
  String get searchRadioTooltip =>
      'Véletlenszerű lejátszási sor a jelenlegi szűrőkkel';

  @override
  String get searchSurprise => 'Meglepetés';

  @override
  String get searchSurpriseTooltip => 'Egy véletlenszerű szám';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Nincsenek számok';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n album',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'más néven $name';
  }

  @override
  String get searchChooseCollection => 'Gyűjtemény választása';

  @override
  String get searchFilterCollections => 'Gyűjtemények szűrése…';

  @override
  String get searchFilterPlaceholder => 'Szűrés…';

  @override
  String searchAllOf(String label) {
    return 'Összes ($label)';
  }

  @override
  String get searchNoMatch => 'Nincs egyezés';

  @override
  String get searchNoPlaylist => 'Nincsenek lejátszási listák';

  @override
  String get engineDescOpenmpt => 'Tracker modulok (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Modulok, amelyeket a libopenmpt nem olvas (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — hangchipek, csatornánkénti szkóp';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN archívumok';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — csatornánkénti szólamok';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp motor)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX chiptune-ok (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Több chipes chiptune-ok .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amiga egyedi chipes formátumok 68k emulációval (~320 kiterjesztés)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Szabványos MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ szintetizátor (16 szólam)';

  @override
  String get engineDescV2m => 'V2M szintetizátor (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — valódi 68000 emuláció + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300 emuláció + RSP hang';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ emuláció';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound chip';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — valódi AY-3-8910/YM2149 szintetizátor';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixel saját motorja';

  @override
  String get engineDescPxtone => 'Pixel trackere — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — valódi 68000 az emu68-cal';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA FM + SSG + PPZ8 minták';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ .pdx minták), YM2151 FM';

  @override
  String get engineDescFmp =>
      'PC-98 FMP meghajtó — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612 FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Veszteségmentes .ape';

  @override
  String get engineDescVgmstream =>
      'Streamelt játékhang-formátumok (700+, köztük .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — tartalék dekóder';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total szám',
      one: '$loaded / 1 szám',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total album',
      one: '$loaded / 1 album',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total előadó',
      one: '$loaded / 1 előadó',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n album',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n előadó',
      one: '$n előadó',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n csoport',
      one: '$n csoport',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Országok';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ország',
      one: '$n ország',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Mappák';

  @override
  String get featuredTitle => 'A mai ajánlat';

  @override
  String featuredPartyNow(String party) {
    return '$party éppen most zajlik — a korábbi kiadások dobogósai';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party $days nap múlva kezdődik — a korábbi kiadások dobogósai',
      one: '$party holnap kezdődik — a korábbi kiadások dobogósai',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series szezon — a korábbi kiadások dobogósai';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Megjelent: $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age éve: $year játékai',
      one: 'Egy éve: $year játékai',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade-es évek';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age éve: $year játékai',
      one: 'Egy éve: $year játékai',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Megjelenés: $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Évfordulók';

  @override
  String get featuredBirthdayHeader => 'Mai születésnapok';

  @override
  String get featuredBirthdayWeekHeader => 'A hét születésnapjai';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist születésnapja ezen a héten';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lejátszási lista',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Újra';

  @override
  String get commonOptions => 'Opciók';

  @override
  String get commonDownload => 'Letöltés';

  @override
  String get commonDeleteDownload => 'Letöltés törlése';

  @override
  String get commonAddToPlaylist => 'Hozzáadás lejátszási listához';

  @override
  String get commonPlayNext => 'Lejátszás következőként';

  @override
  String get commonAddToQueueEnd => 'Hozzáadás a sor végéhez';

  @override
  String get commonAddToFavorites => 'Hozzáadás a kedvencekhez';

  @override
  String get commonRemoveFromFavorites => 'Eltávolítás a kedvencekből';

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
  String get subsongDeleteDownloadTitle => 'Törlöd ezt a letöltést?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'A fájl és a hozzá tartozó helyi bejegyzések (előzmények, számok) törlődnek.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'A számokat nem sikerült beolvasni';

  @override
  String subsongTrackNumber(int number) {
    return '$number. sáv';
  }

  @override
  String get subsongDefaultTrack => 'Alapértelmezett szám';

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alszám',
      one: '$count alszám',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Összes lejátszása';

  @override
  String get albumDownloading => 'Album letöltése…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Album letöltése… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Töltsd le az albumot a számai megtekintéséhez';

  @override
  String get albumNotDownloadedHint =>
      'Az album nincs letöltve — indítsd el a lejátszást a letöltéshez';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count szám',
      one: '$count szám',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Részletek betöltése…';

  @override
  String albumAka(String label) {
    return 'más néven $label';
  }

  @override
  String get albumPlayAlbum => 'Album lejátszása';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elem',
      one: '$count elem',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Előbb játszd le ezt a számot a keresésből, hogy letöltődjön';

  @override
  String get libraryAddedTrack => 'A szám bekerült a könyvtáradba';

  @override
  String get libraryAddedAlbum => 'Az album bekerült a könyvtáradba';

  @override
  String get libraryAddedArtist => 'Az előadó bekerült a könyvtáradba';

  @override
  String get libraryRemovedTrack => 'A szám eltávolítva a könyvtáradból';

  @override
  String get libraryRemovedAlbum => 'Az album eltávolítva a könyvtáradból';

  @override
  String get libraryRemovedArtist => 'Az előadó eltávolítva a könyvtáradból';

  @override
  String get libraryImportBeforeAddTitle => 'Előbb importálod?';

  @override
  String get libraryImportBeforeAddBody =>
      'Ez a fájl ideiglenes helyről szól, amelyet a rendszer bármikor kiüríthet. Importálod a helyi könyvtárba, hogy a bejegyzés megmaradjon?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'Ez a szám egy ideiglenes gyorsítótárba kibontott archívumból származik. A teljes archívum a kísérőfájlokkal együtt a helyi könyvtárba kerül.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'A szám nem adható hozzá: a katalógusazonosítója ismeretlen ezen az eszközön.';

  @override
  String songTilePlayFailed(String message) {
    return 'A lejátszás nem sikerült: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'A letöltés nem sikerült — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Letöltés — $label';
  }

  @override
  String get downloadsTitle => 'Letöltések';

  @override
  String get downloadsEmpty => 'Nincs függő letöltés';

  @override
  String get downloadsPause => 'Szüneteltetés';

  @override
  String get downloadsResume => 'Folytatás';

  @override
  String get downloadsCancel => 'Letöltés megszakítása';

  @override
  String get downloadsClear => 'Összes eltávolítása';

  @override
  String get downloadsPausedBanner =>
      'Letöltések szüneteltetve — az aktuális fájl előbb befejeződik';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Letöltés — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Lejátszási lista';

  @override
  String get miniPlayerHideQueue => 'Lejátszási lista elrejtése';

  @override
  String get transportShuffle => 'Véletlenszerű lejátszás';

  @override
  String get transportShuffleOn => 'Véletlenszerű lejátszás bekapcsolva';

  @override
  String get transportLoopOff => 'Ismétlés kikapcsolva';

  @override
  String get transportLoopQueue => 'Ismétlés: lejátszási sor';

  @override
  String get transportLoopTrack => 'Ismétlés: aktuális szám';

  @override
  String get vizStereo => 'Sztereó';

  @override
  String get vizSpectrum => 'Spektrum';

  @override
  String get vizVoices => 'Szólamok';

  @override
  String get vizNotes => 'Hangjegyek';

  @override
  String get vizPiano => 'Zongora';

  @override
  String get vizPatterns => 'Patternek';

  @override
  String get patternScrollMode => 'Görgetési mód';

  @override
  String get patternSmoothScroll => 'Sima görgetés';

  @override
  String get patternPinnedRow => 'Rögzített aktív sor';

  @override
  String get patternVolumeBars => 'Hangerősávok';

  @override
  String get patternColorScheme => 'Színséma';

  @override
  String get patternSize => 'Méret';

  @override
  String get patternColumns => 'Oszlopok';

  @override
  String get patternColumnsAll => 'Teljes';

  @override
  String get patternColumnsNoteInstr => 'Csökkentett';

  @override
  String get patternColumnsNote => 'Minimális';

  @override
  String get vizClose => 'Vizualizáció bezárása';

  @override
  String get vizFullscreen => 'Teljes képernyő';

  @override
  String get vizExitFullscreen => 'Kilépés a teljes képernyőből';

  @override
  String get vizPrevPreset => 'Előző preset';

  @override
  String get vizNextPreset => 'Következő preset';

  @override
  String get vizProjectmUnavailable => 'A projectM nem érhető el';

  @override
  String get voicesTitle => 'Szólamok';

  @override
  String get voicesNone => 'Ehhez a számhoz nincsenek szólamok.';

  @override
  String get voicesLongPressSolo => 'hosszú nyomás = szóló';

  @override
  String get voicesMuteAll => 'Összes némítása';

  @override
  String get voicesUnmuteAll => 'Az összes némításának feloldása';

  @override
  String get voicesStereoOutput => 'Sztereó kimenet';

  @override
  String get voicesLeft => 'Bal';

  @override
  String get voicesRight => 'Jobb';

  @override
  String get enginesFormatsTitle => 'Lejátszható formátumok';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats lejátszható formátum, $engines lejátszómotorra elosztva.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formátum',
      one: '$count formátum',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Feldolgozás: $title – $artist';
  }

  @override
  String stilCover(String work) {
    return 'Feldolgozás: $work';
  }

  @override
  String get playerQueue => 'Lejátszási sor';

  @override
  String get queueEdit => 'Szerkesztés';

  @override
  String get queueEditDone => 'Kész';

  @override
  String get queueClear => 'Várólista ürítése';

  @override
  String get queueClearConfirmTitle => 'Üríti a várólistát?';

  @override
  String get queueClearConfirmBody =>
      'A várólista kiürül, és a lejátszás leáll.';

  @override
  String get queueClearConfirm => 'Ürítés';

  @override
  String get queueRemoveSelected => 'Kijelöltek eltávolítása';

  @override
  String get queueRemoveTrack => 'Eltávolítás a sorból';

  @override
  String get queueReorder => 'Átrendezés';

  @override
  String get playerArtwork => 'Borító';

  @override
  String get playerVisualizer => 'Vizualizáció';

  @override
  String get playerVoices => 'Szólamok';

  @override
  String get playerTrackInfo => 'Száminformációk';

  @override
  String get playerShowQueue => 'Lejátszási lista';

  @override
  String get playerHideQueue => 'Lejátszási lista elrejtése';

  @override
  String get playerNoTrackInfo => 'Nincs elérhető információ.';

  @override
  String get playerViewSubsongs => 'Alszámok megtekintése';

  @override
  String get playerViewAlbum => 'Album megtekintése';

  @override
  String get playerViewArtist => 'Előadó megtekintése';

  @override
  String get playerAddToPlaylist => 'Hozzáadás lejátszási listához';

  @override
  String get playerEngineSettings => 'Motor beállításai';

  @override
  String get queueAddToPlaylist => 'Várólista hozzáadása lejátszási listához';

  @override
  String get playerMoreOptions => 'További lehetőségek';

  @override
  String get playerClose => 'Bezárás';

  @override
  String get playerCancel => 'Mégse';

  @override
  String get playerDelete => 'Törlés';

  @override
  String get playerAddFavorite => 'Hozzáadás a kedvencekhez';

  @override
  String get playerRemoveFavorite => 'Eltávolítás a kedvencekből';

  @override
  String get playerAddToLibrary => 'Hozzáadás a könyvtárhoz';

  @override
  String get playerRemoveFromLibrary => 'Eltávolítás a könyvtárból';

  @override
  String get playerAddedToLibrary => 'A szám hozzáadva a könyvtárhoz';

  @override
  String get playerRemovedFromLibrary => 'A szám eltávolítva a könyvtárból';

  @override
  String get playerDeleteDownload => 'Letöltés törlése';

  @override
  String get playerRedownload => 'Fájl újraletöltése';

  @override
  String get playerRedownloadUnavailable =>
      'Ehhez a fájlhoz nem érhető el az újraletöltés';

  @override
  String get playerDeleteDownloadTitle => 'Törlöd a letöltést?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'A fájl és a hozzá tartozó helyi bejegyzések (előzmények, számok) törlődnek.\n\n$path';
  }

  @override
  String get homeYourTrends => 'A te trendjeid';

  @override
  String get homeYourAllTimeTop => 'Minden idők toplistád';

  @override
  String get homeTrending => 'Felkapott';

  @override
  String get homeFeaturedPlaylists => 'Kiemelt lejátszási listák';

  @override
  String get homeAllTimeTop => 'Minden idők toplistája';

  @override
  String get homePeriod7d => '7 nap';

  @override
  String get homePeriod30d => '30 nap';

  @override
  String get homePeriod90d => '90 nap';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lejátszás',
      one: '$n lejátszás',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable =>
      'Üres vagy olvashatatlan lejátszási lista';

  @override
  String get homeExtractingArchive => 'Archívum kibontása…';

  @override
  String get homeArchiveEmpty => 'Nincs lejátszható fájl az archívumban';

  @override
  String get homeNothingPlayable => 'A kijelölésben nincs lejátszható elem';

  @override
  String get homeAlbumLoadFailed => 'Ezt az albumot nem sikerült betölteni';

  @override
  String get homeSongLoadFailed => 'Ezt a számot nem sikerült betölteni';

  @override
  String get navStats => 'Statisztika';

  @override
  String get navSettings => 'Beállítások';

  @override
  String get playlistMoveUp => 'Áthelyezés a szülőmappába';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lejátszási lista',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n almappa',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Ez a mappa és teljes tartalma véglegesen törlődik:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Ez a mappa törlődik.';

  @override
  String get playlistFolderRoot => 'Gyökér';

  @override
  String get playlistMoveToFolder => 'Áthelyezés mappába';

  @override
  String playlistDeleteTitle(String name) {
    return 'Törlöd a(z) „$name” listát?';
  }

  @override
  String get playlistDeleteBody => 'Ez a lejátszási lista véglegesen törlődik.';

  @override
  String get playlistRenameFolderTitle => 'Mappa átnevezése';

  @override
  String get playlistClearFavorites => 'Összes kedvenc törlése';

  @override
  String get playlistClearFavoritesTitle => 'Törlöd az összes kedvencet?';

  @override
  String get playlistClearFavoritesBody =>
      'Elveszíted az összes kedvenc számodat. A művelet nem vonható vissza.';

  @override
  String get playlistRemoveFromLibrary => 'Eltávolítás a könyvtárból';

  @override
  String get playlistServerReadOnly =>
      'Kiszolgálói lejátszási lista · csak olvasható';

  @override
  String get navAbout => 'Névjegy';

  @override
  String get navMore => 'Továbbiak';

  @override
  String get shellAlbumQueuedAtEnd => 'Az album a sor végére került';

  @override
  String get shellAlbumQueuedNext => 'Az album következőként szól';

  @override
  String get shellAddingToQueue => 'Hozzáadás a sorhoz…';

  @override
  String get shellAddingNext => 'Hozzáadás következőként…';

  @override
  String shellDownloadFailed(String error) {
    return 'A letöltés nem sikerült: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count szám hozzáadva a sorhoz',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return 'A(z) \"$title\" a sor végére került';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return 'A(z) \"$title\" következőként szól';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'A letöltés nem sikerült: $title — ugrás a következő számra';
  }

  @override
  String get shellNetworkUnavailable =>
      'A lejátszás leállt: úgy tűnik, nincs hálózati kapcsolat.';

  @override
  String get statsTitle => 'Statisztika';

  @override
  String statsPeriodDays(int n) {
    return '$n nap';
  }

  @override
  String get statsPeriodThisYear => 'Idén';

  @override
  String get statsPeriodAll => 'Teljes időszak';

  @override
  String get statsByMonthOrYear => 'Hónap / év szerint…';

  @override
  String get statsByYear => 'Év szerint';

  @override
  String get statsByMonth => 'Hónap szerint';

  @override
  String get statsPlaysLabel => 'Lejátszások';

  @override
  String get statsTracksLabel => 'Számok';

  @override
  String get statsArtistsLabel => 'Előadók';

  @override
  String get statsAlbumsLabel => 'Albumok';

  @override
  String get statsListenTime => 'Hallgatási idő';

  @override
  String get statsByCollection => 'Gyűjtemény szerint';

  @override
  String get statsByFormat => 'Formátum szerint';

  @override
  String get statsByEngine => 'Motor szerint';

  @override
  String get statsPlaylistsLabel => 'Lejátszási listák';

  @override
  String get statsLocalFilesSection => 'Letöltött fájlok';

  @override
  String get statsFilesLabel => 'Fájlok';

  @override
  String get statsSpaceLabel => 'Lemezterület';

  @override
  String get statsNoPlaysInPeriod => 'Ebben az időszakban nincs lejátszás';

  @override
  String get statsNoPlays => 'Nincs lejátszás';

  @override
  String get statsTopTracks => 'Top számok';

  @override
  String get statsTopAlbums => 'Top albumok';

  @override
  String get statsTopArtists => 'Top előadók';

  @override
  String statsTopTracksIn(String period) {
    return 'Top számok — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top albumok — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top előadók — $period';
  }

  @override
  String get statsSeeAll => 'Összes megtekintése';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lejátszás',
      one: '$n lejátszás',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max. $n';
  }

  @override
  String get commonCancel => 'Mégse';

  @override
  String get commonCreate => 'Létrehozás';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Törlés';

  @override
  String get commonRename => 'Átnevezés';

  @override
  String get commonSort => 'Rendezés';

  @override
  String get commonPlayAll => 'Összes lejátszása';

  @override
  String get sortName => 'Név';

  @override
  String get sortTitle => 'Cím';

  @override
  String get sortArtist => 'Előadó';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Hozzáadás dátuma';

  @override
  String get commonClear => 'Törlés';

  @override
  String get sortRecentlyModified => 'Nemrég módosított';

  @override
  String get sortCreationDate => 'Létrehozás dátuma';

  @override
  String get playlistNameHint => 'Név';

  @override
  String get playlistNew => 'Új lejátszási lista';

  @override
  String get playlistNewFolder => 'Új mappa';

  @override
  String get playlistNewTooltip => 'Új lejátszási lista / mappa';

  @override
  String get playlistAddTo => 'Hozzáadás lejátszási listához';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Hozzáadás $n lejátszási listához',
      one: 'Hozzáadás $n lejátszási listához',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Válassz egy lejátszási listát';

  @override
  String get playlistFilterHint => 'Lejátszási listák szűrése…';

  @override
  String get playlistSearchHint => 'Lejátszási lista keresése…';

  @override
  String get playlistNoMatch => 'Nincs egyező lejátszási lista';

  @override
  String get playlistNoneCreateHint =>
      'Nincs lejátszási lista — hozz létre egyet a + gombbal';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
      zero: 'Nincsenek számok',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Már szerepel';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elem már szerepel a kijelölt lejátszási listákban.',
      one: '$n elem már szerepel a kijelölt lejátszási listákban.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Duplikátumok kihagyása';

  @override
  String get playlistAddAgain => 'Hozzáadás mégis';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m lejátszási listához',
      one: '$n lejátszási listához',
    );
    return '$_temp0 hozzáadva $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'A hozzáadás nem sikerült: $error';
  }

  @override
  String get playlistRenameTitle => 'Lejátszási lista átnevezése';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Törlöd a(z) „$name” mappát?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'A tartalma egy szinttel feljebb kerül.';

  @override
  String get playlistEmpty => 'Üres lejátszási lista';

  @override
  String get trackOptionsAddToLibrary => 'Hozzáadás a könyvtárhoz';

  @override
  String get trackOptionsRemoveFromLibrary => 'Eltávolítás a könyvtárból';

  @override
  String get trackOptionsAddedToLibrary => 'A szám hozzáadva a könyvtárhoz';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'A szám eltávolítva a könyvtárból';

  @override
  String get trackOptionsViewAlbum => 'Album megtekintése';

  @override
  String get trackOptionsViewArtist => 'Előadó megtekintése';

  @override
  String get trackOptionsPlayNow => 'Lejátszás most';

  @override
  String get trackOptionsPlayNext => 'Lejátszás következőként';

  @override
  String get trackOptionsAddToQueueEnd => 'Hozzáadás a sor végéhez';

  @override
  String get trackOptionsPlayLast => 'Lejátszás utolsóként';

  @override
  String get trackOptionsDeleteDownload => 'Letöltés törlése';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Törlöd ezt a letöltést?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'A fájl és a hozzá tartozó helyi bejegyzések (előzmények, számok) törlődnek.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'A letöltés törölve';

  @override
  String get trackOptionsAddToFavorites => 'Hozzáadás a kedvencekhez';

  @override
  String get trackOptionsRemoveFromFavorites => 'Eltávolítás a kedvencekből';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Az album hozzáadva a kedvencekhez';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Az album eltávolítva a kedvencekből';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Az album nincs letöltve — nincs mit törölni';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Törlöd a letöltött albumot?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'A mappa és az összes hozzá tartozó helyi bejegyzés (számok, előzmények) törlődik.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Az album törölve a helyi tárhelyről';

  @override
  String get trackOptionsRedownloadAlbum => 'Album újraletöltése';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Felülírja a fájlokat ÉS a helyi bejegyzéseket';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Az album fájljainak törlése';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Letöltött mappa + helyi bejegyzések (előzmények)';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get settingsGeneral => 'Általános';

  @override
  String get settingsGeneralSubtitle => 'Téma';

  @override
  String get settingsVisualisation => 'Vizualizáció';

  @override
  String get settingsVisualisationSubtitle =>
      'Oszcilloszkópok, borító a háttérben';

  @override
  String get settingsPlayback => 'Lejátszás';

  @override
  String get settingsPlaybackSubtitle => 'Ismétlés, elhalkulás, csend';

  @override
  String get settingsEngines => 'Motorok';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Adatok';

  @override
  String get settingsDataSubtitle => 'Azonosító, előzmények, visszaállítás';

  @override
  String get settingsBackupExport => 'Biztonsági mentés exportálása';

  @override
  String get settingsBackupExportSubtitle =>
      'Mentsd a könyvtárat, lejátszási listákat és beállításokat egy fájlba';

  @override
  String get settingsBackupImport => 'Biztonsági mentés importálása';

  @override
  String get settingsBackupImportSubtitle =>
      'Állítsd vissza az adataidat egy biztonsági mentésből';

  @override
  String get settingsBackupExportFailed =>
      'A biztonsági mentés exportálása sikertelen';

  @override
  String get settingsBackupImportConfirmTitle =>
      'Importálod a biztonsági mentést?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Ez lecseréli a könyvtárat, a lejátszási listákat és a beállításokat ezen az eszközön. A letöltött fájlok megmaradnak.';

  @override
  String get settingsBackupImportConfirm => 'Importálás';

  @override
  String get settingsBackupImportedTitle => 'Biztonsági mentés importálva';

  @override
  String get settingsBackupImportedBody =>
      'Az adataid visszaálltak. Indítsd újra az alkalmazást a teljes érvényesítéshez.';

  @override
  String get settingsBackupTooNew =>
      'Ezt a mentést az alkalmazás újabb verziója készítette';

  @override
  String get settingsBackupInvalid => 'Nem érvényes Rewamp biztonsági mentés';

  @override
  String get settingsBackupImportFailed =>
      'A biztonsági mentés importálása sikertelen';

  @override
  String get settingsAbout => 'Névjegy';

  @override
  String get settingsAboutSubtitle => 'Közreműködők és licencek';

  @override
  String get settingsCreditsSubtitle => 'Könyvtárak, adatok és összetevők';

  @override
  String get settingsSupport => 'Kapcsolat és támogatás';

  @override
  String get settingsSupportSubtitle => 'Írj nekünk, weboldal';

  @override
  String get settingsSupportEmail => 'E-mail küldése';

  @override
  String get settingsSupportEmailSubtitle => 'Kérdés, hiba vagy javaslat';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — támogatás';

  @override
  String get settingsSupportEmailIntro =>
      'Írd le fent a kérdésed, a hibát vagy a javaslatod. Az alábbi információk segítenek nekünk segíteni neked.';

  @override
  String get settingsSupportWebsite => 'Weboldal';

  @override
  String get settingsDonation => 'Rewamp támogatása';

  @override
  String get settingsDonationSubtitle => 'Egy kis borravaló, ha szeretnéd';

  @override
  String get settingsDonationBlurb =>
      'A Rewamp ingyenes és reklámmentes — szenvedélyből készült munka a demoscene és retró kultúra megőrzéséért. Az adományok segítenek finanszírozni az alkalmazás fejlesztését és fedezni az adatbázis tárhelyének költségeit. Semmi kötelezettség: ha örömödet leled az appban, egy apró gesztus mindig jólesik.';

  @override
  String get settingsDonationFloppy => 'Egy floppylemez';

  @override
  String get settingsDonationCartridge => 'Egy játékkazetta';

  @override
  String get settingsDonationBox => 'Egy dobozos játék';

  @override
  String get settingsDonationCustom => 'Összeg megadása';

  @override
  String get settingsCancel => 'Mégse';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Törlés';

  @override
  String get settingsReset => 'Visszaállítás';

  @override
  String get settingsRenew => 'Megújítás';

  @override
  String get settingsOff => 'Ki';

  @override
  String get settingsOn => 'Be';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Végtelen';

  @override
  String get settingsDefault => 'Alapértelmezett';

  @override
  String get settingsCoreNoScope => 'nincs oszcilloszkóp';

  @override
  String get settingsNone => 'Nincs';

  @override
  String get settingsLevelLow => 'Alacsony';

  @override
  String get settingsLevelHigh => 'Magas';

  @override
  String get settingsStereo => 'Sztereó';

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
  String get settingsTheme => 'Téma';

  @override
  String get settingsThemeLight => 'Világos';

  @override
  String get settingsThemeDark => 'Sötét';

  @override
  String get settingsArtworkTintTitle => 'A lejátszó színezése a borítóval';

  @override
  String get settingsArtworkTintSubtitle =>
      'A lejátszó átveszi a borító uralkodó színét';

  @override
  String get settingsGlassEffectTitle => 'Liquid glass effekt';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lencse és elmosás az alsó sávokon — lassú eszközön kapcsold ki';

  @override
  String get settingsResetSection => 'Szakasz visszaállítása';

  @override
  String get settingsResetEngine => 'Motor visszaállítása';

  @override
  String get settingsResetChoices => 'Választások visszaállítása';

  @override
  String get settingsResetToDefault => 'Alapértelmezett érték';

  @override
  String get settingsStartInVizTitle => 'Indítás vizualizációs módban';

  @override
  String get settingsStartInVizSubtitle =>
      'A lejátszó a borító helyett az oszcilloszkópokkal nyílik meg';

  @override
  String get settingsVoiceGridTitle => 'Szólamoszcilloszkóp rácsa';

  @override
  String get settingsVoiceGridSubtitle =>
      'Az egyes szólamokat elválasztó keretek megjelenítése';

  @override
  String get settingsKeepAwakeTitle => 'Képernyő ébren tartása';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Amíg vizualizáció látható, a képernyő nem halványul el és nem zárol';

  @override
  String get settingsVoiceNamesTitle => 'Szólamnevek';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Az egyes szólamok nevének megjelenítése a saját keretükben';

  @override
  String get settingsLineThickness => 'Vonalvastagság';

  @override
  String get settingsScopeVoiceColor => 'Szólamoszcilloszkóp';

  @override
  String get settingsStereoColors => 'Sztereó: színek';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Sztereó (mono)';

  @override
  String get settingsStereoLeftColor => 'Sztereó bal';

  @override
  String get settingsStereoRightColor => 'Sztereó jobb';

  @override
  String get settingsNotePalette => 'Színpaletta';

  @override
  String get settingsNoteBoxStyle => 'Blokkok stílusa';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'Minden vizualizáció';

  @override
  String get settingsVizScopes => 'Oszcilloszkópok (sztereó és hangonként)';

  @override
  String get settingsVizFrameRate => 'Képkockasebesség';

  @override
  String get settingsVizFrameRateScreen => 'Képernyő';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => 'Intenzitás / sebesség';

  @override
  String get settingsArtworkOpacity => 'A háttérborító átlátszatlansága';

  @override
  String get settingsProjectMTitle => 'projectM beállításai';

  @override
  String get settingsProjectMSubtitle => 'Presetek, átmenetek, minőség, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Értesítés számváltáskor';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Rendszerértesítés az új szám címével';

  @override
  String get settingsSilenceDetection => 'Csendfelismerés';

  @override
  String get settingsCrossfade => 'Áttűnés';

  @override
  String get localActionPlay => 'Fájlok vagy mappa lejátszása';

  @override
  String get localActionImport => 'Fájlok vagy mappa importálása';

  @override
  String localOpsImporting(String name) {
    return '$name importálása…';
  }

  @override
  String get localOpsImportingSelection => 'A kijelölt fájlok importálása…';

  @override
  String localOpsDeleting(String name) {
    return '$name törlése…';
  }

  @override
  String get localOpsPhaseCopying => 'másolás';

  @override
  String get localOpsPhaseExtracting => 'kibontás';

  @override
  String get localOpsPhaseRegistering => 'hozzáadás a könyvtárhoz';

  @override
  String get localOpsPhaseDeleting => 'fájlok eltávolítása';

  @override
  String get localImportFiles => 'Fájlok importálása';

  @override
  String get storageLocalImports => 'Helyi importok';

  @override
  String get settingsVgmJapaneseTags => 'Japán címkék (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'A VGM-címkék japán mezőit (cím, játék, előadó) részesíti előnyben, ha léteznek.';

  @override
  String get localImportFolder => 'Mappa importálása';

  @override
  String get localLibraryTitle => 'Ezen az eszközön';

  @override
  String get libraryOnAnotherDevice => 'Egy másik eszközön';

  @override
  String get localLibraryEmpty =>
      'Még nincs helyi importálás. Használd a kezdőképernyő „Fájlok importálása” vagy „Mappa importálása” gombját.';

  @override
  String queueLimitReached(int count) {
    return 'A sor az első $count számra korlátozva';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return 'Törlöd a(z) „$name” elemet? A fájl és a kísérőfájljai (borító…) is törlődnek.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Törlöd a(z) „$name” mappát és $count számát?',
      one: 'Törlöd a(z) „$name” mappát és $count számát?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count szám importálva a könyvtárba';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks szám importálva – $albums album';
  }

  @override
  String localImportFailed(String error) {
    return 'Az importálás nem sikerült: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'A számok végét átúsztatja a következő elejébe. 0-nál a lejátszás továbbra is szünetmentes.';

  @override
  String get settingsMinSubsongSection => 'Túl rövid alzeneszámok';

  @override
  String get settingsMinSubsongTitle => 'Legrövidebb hossz';

  @override
  String get settingsMinSubsongHelp =>
      'Az ennél rövidebb alzeneszámok kimaradnak a listából és a sorból – egy játékfájl gyakran több hangeffektet tartalmaz, mint zenét. 0 esetén semmi sem marad ki; az ismeretlen hossz sosem számít rövidnek.';

  @override
  String get localNewFolder => 'Új mappa';

  @override
  String get localFolderName => 'Mappa neve';

  @override
  String get localRename => 'Átnevezés';

  @override
  String get localMoveTo => 'Áthelyezés ide…';

  @override
  String get localMove => 'Áthelyezés';

  @override
  String get localMoveNothing => 'Semmi sem lett áthelyezve';

  @override
  String get localNameInvalid => 'Érvénytelen név';

  @override
  String get localNameTaken => 'Ez a név már foglalt';

  @override
  String get localMoveIntoItself => 'Egy mappa nem helyezhető át önmagába';

  @override
  String get localManageFailed => 'A művelet nem sikerült';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Nem kerül a sorba: $seconds s alatt (Beállítások → Lejátszás)';
  }

  @override
  String get settingsQueuePrefetchSection => 'A sor letöltései';

  @override
  String get settingsQueuePrefetchTitle => 'A teljes sor letöltése';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'Egyszerre egy fájl; a következő hiányzó szám akkor indul, amint az előző megérkezett. Kikapcsolva: csak a következő szám.';

  @override
  String get settingsCdRipDeclickSection => 'CD-ripek';

  @override
  String get settingsCdRipDeclickTitle =>
      'Kattanások eltávolítása a szám elején';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'A hibás CD-ripek (mp3, ape, ogg, flac…) gyakran néhány sérült mintával kezdődnek. Ezeket a szűrő kijavítja, amíg 200 ms valódi zene le nem szólt; utána félreáll.';

  @override
  String get settingsSilenceSkipTitle =>
      'Ugrás a következő számra csend esetén';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Automatikusan továbblép, ha a kimenet néma marad';

  @override
  String get settingsSilenceDelay => 'Csend késleltetése';

  @override
  String get settingsDefaultDuration => 'Alapértelmezett hossz';

  @override
  String get settingsDefaultDurationHelp =>
      'Akkor lép életbe, ha egy szám nem közöl ismert hosszt (nincs tag, nincs kiszolgálói metaadat) — így nem szól vagy ismétlődik a végtelenségig. Az Amiga számokra (UADE) soha nem vonatkozik, mert azoknak saját hosszadatbázisuk van.';

  @override
  String get settingsForcedLoopHeader => 'Kényszerített ismétlés / elhalkulás';

  @override
  String get settingsForcedLoopHelp =>
      'Egyes formátumok egy adott szakaszt ismételnek (VGM, tracker modulok…), mások nem. A \"Végtelen\" figyelmen kívül hagyja a szám természetes végét.';

  @override
  String get settingsForceLoopCount => 'Az ismétlések számának kényszerítése';

  @override
  String get settingsLoopCount => 'Ismétlések száma';

  @override
  String get settingsForceFadeout => 'Elhalkulás kényszerítése';

  @override
  String get settingsFadeoutDuration => 'Az elhalkulás hossza';

  @override
  String get settingsResetEnginesTitle => 'Visszaállítod a motorbeállításokat?';

  @override
  String get settingsResetEnginesBody =>
      'Az összes motorbeállítás visszaáll az alapértelmezett értékére.';

  @override
  String get settingsResetDefaultsTitle =>
      'Visszaállítás az alapértelmezett értékekre';

  @override
  String get settingsResetDefaultsSubtitle => 'Minden motor';

  @override
  String get settingsDefaultDecoders => 'Alapértelmezett dekóderek';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Több motor által is lejátszható formátumok';

  @override
  String get settingsDecodersHelp =>
      'Egyes formátumokat több motor is le tud játszani. Válaszd ki, melyik legyen az alapértelmezett — a többi formátum útvonala automatikus.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga trackerek (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackerek — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Modulok, amelyeket a libopenmpt nem olvas — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, sztereó';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — minőség, szűrők, chipenkénti beállítások';

  @override
  String get settingsEngineGbsSubtitle =>
      'Game Boy / GBS — felüláteresztő szűrő';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — a használt SoundFont';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpoláció, aluláteresztő, visszhang';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panoráma, fejhallgató, erősítés, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — órajel, modell, ReSIDfp szűrők';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — sztereó/surround harmonikus mód';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, zengetés';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612, OPL3, QSound magok…';

  @override
  String get settingsMasterVolume => 'Fő hangerő';

  @override
  String get settingsAmplification => 'Erősítés';

  @override
  String get settingsAmigaFilter => 'Amiga szűrő';

  @override
  String get settingsInterpolation => 'Interpoláció';

  @override
  String get settingsPolyphony => 'Polifónia';

  @override
  String get settingsReverb => 'Zengetés';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'Ez a MIDI Roland MT-32-re készült. A ROM-ok nélkül a SoundFonton szól, General MIDI-re fordított hangszerekkel — importáld a ROM-okat itt: Beállítások › Motorok › Munt.';

  @override
  String get settingsMidiMt32ToGm => 'MT-32-fájlok igazítása';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'A Roland MT-32-re írt MIDI a saját listája szerint számozza a programjait: a legközelebbi General MIDI hangszerre fordítva hihetően szól, nem véletlenszerűen.';

  @override
  String get settingsInterpNone => 'Nincs';

  @override
  String get settingsInterpLinear => 'Lineáris';

  @override
  String get settingsInterpCubic => 'Köbös';

  @override
  String get settingsInterpSinc => 'Sinc (legjobb)';

  @override
  String get settingsStereoSeparation => 'Sztereó szétválasztás';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Befejezi a számot, ha a motor hosszú csendet észlel';

  @override
  String get settingsStereoDepth => 'Sztereó mélység';

  @override
  String get settingsEqualizer => 'Hangszínszabályzó';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — az SPC-re nincs hatással';

  @override
  String get settingsBass => 'Mély';

  @override
  String get settingsTreble => 'Magas';

  @override
  String get settingsAppliedLive =>
      'Azonnal érvénybe lép, lejátszás közben is.';

  @override
  String get settingsAppliedNextTrack =>
      'A következőként betöltött számnál lép érvénybe.';

  @override
  String get settingsSidEmulation => 'Emuláció';

  @override
  String get settingsSidResidfp => 'ReSIDfp (pontos)';

  @override
  String get settingsSidLite => 'SIDLite (gyors)';

  @override
  String get settingsSidSampling => 'Mintavételezés';

  @override
  String get settingsSidSamplingInterp => 'Interpoláció (gyors)';

  @override
  String get settingsSidSamplingResample => 'Resample (legjobb)';

  @override
  String get settingsSidClock => 'Órajel';

  @override
  String get settingsSidModel => 'SID modell';

  @override
  String get settingsSidFilter => 'SID szűrő';

  @override
  String get settingsSidForceSecond => '2. SID kényszerítése';

  @override
  String get settingsSidSecondSubtitle => 'Sztereó 2SID számok';

  @override
  String get settingsSidSecondAddr => 'A 2. SID címe';

  @override
  String get settingsSidForceThird => '3. SID kényszerítése';

  @override
  String get settingsSidThirdAddr => 'A 3. SID címe';

  @override
  String get settingsSidAutoFilter => 'Automatikus 6581 szűrőtartomány';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'A szám szerzőjéhez ajánlott érték (sidplayfp táblázatok)';

  @override
  String get settingsSid6581Range => '6581 szűrőtartomány';

  @override
  String get settingsSid6581Curve => '6581 szűrőgörbe';

  @override
  String get settingsSid8580Curve => '8580 szűrőgörbe';

  @override
  String get settingsSidNote =>
      'A SID szűrő és a görbék azonnal érvénybe lépnek; az emuláció, a mintavételezés, az órajel, a modell és a 2./3. SID csak a következő számnál.';

  @override
  String get settingsAudioOutput => 'Hangkimenet';

  @override
  String get settingsAdplugNote =>
      'Surround: két, egymáshoz képest kissé elhangolt OPL chip. A következő számnál lép érvénybe.';

  @override
  String get settingsHeSpuMain => 'Fő szólamok (SPU)';

  @override
  String get settingsHeSpuReverb => 'Zengetés (SPU)';

  @override
  String get settingsNsfQuality => 'Minőség (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Aluláteresztő szűrő';

  @override
  String get settingsHighpassFilter => 'Felüláteresztő szűrő';

  @override
  String get settingsRegion => 'Régió';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC kényszerítve';

  @override
  String get settingsNsfRegionPalForced => 'PAL kényszerítve';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy kényszerítve';

  @override
  String get settingsNsfForceIrq => 'IRQ kényszerítése';

  @override
  String get settingsNsfApu1Title => '2A03 — pulzusok (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — háromszög / zaj / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Némítás feloldása visszaállításkor';

  @override
  String get settingsNsfPhaseRefresh => 'Fázis frissítése';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'A fázis nullázása a periódus írásakor';

  @override
  String get settingsNsfNonlinearMixer => 'Nemlineáris keverés';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'A 2A03 valódi keverése (egyébként lineáris)';

  @override
  String get settingsNsfDutySwap => 'Duty ciklusok felcserélése';

  @override
  String get settingsNsfDutySwapSubtitle =>
      'A 25%-os és az 50%-os duty sorrendje';

  @override
  String get settingsNsfNegateSweep => 'Negatív sweep indításkor';

  @override
  String get settingsNsfEnable4011 => 'A \$4011 regiszter engedélyezve';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Közvetlen DAC kimenet (az eredeti kattanásokkal)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodikus zaj';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => 'A zajgenerátor rövid módja';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM kattanásgátló';

  @override
  String get settingsNsfRandomizeNoise =>
      'A zaj véletlenszerűsítése indításkor';

  @override
  String get settingsNsfTriangleMute => 'A háromszög némítása';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Elnémítja a háromszöget ultrahangos periódusoknál';

  @override
  String get settingsNsfRandomizeTri =>
      'A háromszög véletlenszerűsítése indításkor';

  @override
  String get settingsNsfDpcmReverse => 'Fordított DPCM';

  @override
  String get settingsNsfN163Serial => 'Soros multiplexelés';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Az N163 valódi zümmögése többszólamú számoknál';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Csak olvasható fázis';

  @override
  String get settingsNsfN163LimitWavelength => 'A hullámhossz korlátozása';

  @override
  String get settingsNsfFdsCutoff => 'Aluláteresztő vágási frekvencia';

  @override
  String get settingsNsfFds4085Reset => '\$4085 visszaállítás';

  @override
  String get settingsNsfFdsWriteProtect => 'Írásvédelem';

  @override
  String get settingsNsfVrc7Patch => 'Patch-készlet';

  @override
  String get settingsNsfVrc7Opll => 'OPLL mód';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'YM2413 emulálása a VRC7 helyett';

  @override
  String get settingsGbsHpFilter => 'Felüláteresztő szűrő (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klasszikus GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Visszhang';

  @override
  String get settingsUadePostfx => 'Utófeldolgozás';

  @override
  String get settingsUadePostfxSubtitle =>
      'Bekapcsolja az effektláncot (az alábbiakhoz szükséges)';

  @override
  String get settingsUadePan => 'Panoráma (sztereó szétválasztás)';

  @override
  String get settingsUadePanValue => 'A panoráma mértéke';

  @override
  String get settingsUadeHeadphones => 'Fejhallgató';

  @override
  String get settingsUadeLed => 'LED (Paula szűrő)';

  @override
  String get settingsUadeLedAuto => 'Auto (számonként)';

  @override
  String get settingsUadeLedOn => 'Kényszerítve BE';

  @override
  String get settingsUadeLedOff => 'Kényszerítve KI';

  @override
  String get settingsUadeFilterType => 'Szűrő típusa';

  @override
  String get settingsUadeGain => 'Erősítés';

  @override
  String get settingsUadeGainValue => 'Az erősítés mértéke';

  @override
  String get settingsSoundfontLoading => 'Katalógus betöltése…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'A katalógus nem érhető el ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'A letöltés nem sikerült: $error';
  }

  @override
  String get settingsSoundfontImport => 'SoundFont importálása…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Válasszon .sf2 fájlt ezen az eszközön';

  @override
  String get settingsSoundfontImported => 'Importálva';

  @override
  String get settingsSoundfontInvalid => 'Ez a fájl nem SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Az importálás nem sikerült — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Fájl törlése';

  @override
  String get settingsCreditsHeader => 'Közreműködők és licencek';

  @override
  String get settingsRightsNotice =>
      'A Rewamp lejátszó: nem tárol fájlokat és nem terjeszt zenét. A számok online megőrzési archívumokból származnak, és a jogtulajdonosaik tulajdonában maradnak. Az Ön felelőssége meggyőződni arról, hogy a meghallgatásuk, letöltésük és megőrzésük megfelel az alkalmazandó jogoknak és az Ön országának jogszabályainak.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count támogatott formátum',
      one: '$count támogatott formátum',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lejátszómotor között elosztva — lásd a részleteket',
      one: '$count lejátszómotor kezeli — lásd a részleteket',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga hosszak és metaadatok';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb, készítette Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID adatok és borítók';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — C64 játékok metaadatai és képei.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 betűtípus';

  @override
  String get settingsFt2FontSubtitle =>
      'A patternvizualizáló FastTracker II stílusa az ft2-clone FT2 bitmap betűtípusát használja, készítette 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url kimásolva';
  }

  @override
  String get settingsOpenLink => 'Hivatkozás megnyitása';

  @override
  String get settingsEnginesHeader => 'Lejátszómotorok';

  @override
  String get settingsComponentsHeader => 'További összetevők';

  @override
  String get settingsResetAll => 'Minden beállítás visszaállítása';

  @override
  String get settingsResetAllSubtitle =>
      'Általános, Vizualizáció, Lejátszás, Motorok — a könyvtár nem';

  @override
  String get settingsResetAllTitle => 'Visszaállítod az összes beállítást?';

  @override
  String get settingsResetAllBody =>
      'Az Általános, a Vizualizáció, a Lejátszás és minden motor visszaáll az alapértelmezett értékére. A könyvtárad és az előzményeid érintetlenek maradnak.';

  @override
  String get settingsRenewUserId => 'Az anonim azonosító megújítása';

  @override
  String get settingsRenewUserIdTitle => 'Megújítod az anonim azonosítót?';

  @override
  String get settingsRenewUserIdBody =>
      'Új anonim azonosító jön létre a kiszolgálói statisztikákhoz.\n\nA régit többé nem használjuk. A helyi előzményeidet és a kedvenceidet ez nem érinti.';

  @override
  String get settingsRenewUserIdFailed =>
      'Sikertelen — a kiszolgáló nem érhető el';

  @override
  String settingsNewUserId(String id) {
    return 'Új azonosító: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'Azonosító: $id';
  }

  @override
  String get settingsNoUserId => 'Nincs regisztrált azonosító';

  @override
  String get settingsCleanDb => 'A helyi adatbázis megtisztítása';

  @override
  String get settingsCleanDbSubtitle =>
      'Eltávolítja azokat a bejegyzéseket, amelyek fájlja már nem létezik (törölt letöltések, régi hibák)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count árva bejegyzés eltávolítva',
      one: '$count árva bejegyzés eltávolítva',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'A helyi adatbázis rendben van — nincs mit eltávolítani';

  @override
  String get settingsClearCache =>
      'Gyorsítótár ürítése (borítók és metaadatok)';

  @override
  String get settingsClearCacheSubtitle =>
      'Eltávolítja a gyorsítótárazott borítókat és a letöltött metaadatokat (STIL, hosszak) — a következő lejátszáskor újra letöltődnek';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gyorsítótár ürítve ($count borító)',
      one: 'Gyorsítótár ürítve ($count borító)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Tárhely';

  @override
  String get storageSubtitle => 'Amit az app a lemezen tart, törléssel';

  @override
  String get storageDownloads => 'Letöltések';

  @override
  String get storageArtworkCache => 'Borító-gyorsítótár';

  @override
  String get storageSoundfonts => 'SoundFontok';

  @override
  String get storagePresets => 'Vizualizáló-presetek';

  @override
  String get storageOpenedFiles => 'Megnyitott fájlok';

  @override
  String get storageOpenedEmpty =>
      'A kívülről megnyitott fájlok (megosztás, „Megnyitás ezzel”, mobil fájlválasztó) ide másolódnak.';

  @override
  String get storageInUse => 'lejátszási listában vagy a könyvtárban';

  @override
  String get storageDeleteAll => 'Összes törlése';

  @override
  String get storageClear => 'Ürítés';

  @override
  String get storageDeleteSelection => 'Kijelöltek törlése';

  @override
  String get storageSelectAll => 'Összes kijelölése';

  @override
  String get storageFilterHint => 'Szűrés név szerint';

  @override
  String get storageNoMatch => 'Egy fájl sem felel meg a szűrőnek.';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kijelölve',
      one: '$count kijelölve',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Töröl $count fájlt?',
      one: 'Töröl $count fájlt?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Töröl $count fájlt? Ebből $inUse lejátszási listában vagy a könyvtárban használatos — azok a bejegyzések elvesztik a fájljukat.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Törli az összes letöltött fájlt és könyvtári sorait? A kedvencek és lejátszási listák megtartják bejegyzéseiket, de a fájlokat újra le kell tölteni.';

  @override
  String get storageSoundfontsClearBody =>
      'Törli az összes SoundFontot, az importáltakat is? A katalógusbeliek igény szerint újra letöltődnek; az importáltak elvesznek.';

  @override
  String get storagePresetsClearBody =>
      'Törli a letöltött preset-csomagokat és az importált preseteket? A beépítettek megmaradnak; a csomagok újra letöltődnek, az importáltak elvesznek.';

  @override
  String get storageOpenedDeleteAllTitle => 'Megnyitott fájlok törlése';

  @override
  String get storageInUseDeleteTitle => 'A fájl használatban van';

  @override
  String get storageInUseDeleteBody =>
      'Egy lejátszási lista vagy a könyvtár még erre a fájlra mutat. Törlésével ezek a bejegyzések fájl nélkül maradnak.';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl — $size',
      one: '$count fájl — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fájl — $size · kezelés az albumokból és számokból',
      one: '$count fájl — $size · kezelés az albumokból és számokból',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Töröl $count fájlt? A lejátszási lista vagy a könyvtár által használt fájlok megmaradnak.',
      one:
          'Töröl $count fájlt? A lejátszási lista vagy a könyvtár által használt fájlok megmaradnak.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'A statisztika visszaállítása';

  @override
  String get settingsResetStatsSubtitle =>
      'Törli a hallgatási előzményeket és a lejátszásszámlálókat';

  @override
  String get settingsClearStatsTitle => 'Visszaállítod a statisztikát?';

  @override
  String get settingsClearStatsBody =>
      'Ez véglegesen törli:\n• a teljes hallgatási előzményt\n• a lejátszásszámlálókat\n\nA kedvenceidet és a könyvtáradat ez nem érinti.';

  @override
  String get settingsStatsCleared => 'A statisztika törölve';

  @override
  String get settingsResetDatabase => 'Az adatbázis visszaállítása';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Mindent töröl: előzmények, kedvencek, lejátszási listák, gyorsítótár';

  @override
  String get settingsResetDbTitle => 'Visszaállítod az adatbázist?';

  @override
  String get settingsCleanLocalTitle =>
      'Lejátszhatatlan helyi bejegyzések törlése';

  @override
  String get cleanStageScan => 'Bejegyzések vizsgálata…';

  @override
  String get cleanStageSync => 'Szinkronizálás a fiókoddal…';

  @override
  String get cleanStagePurge => 'Eltávolítás a fiókodból…';

  @override
  String get cleanStageDelete => 'Eltávolítás helyben…';

  @override
  String get settingsCleanLocalBody =>
      'Olyan könyvtárbejegyzések, amelyek fájlja már nincs ezen az eszközön. A fiókodból is törlődnek, tehát a többi eszközödről is.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bejegyzés törölve',
      zero: 'Nincs mit törölni',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'Ez véglegesen törli:\n• a teljes hallgatási előzményt\n• minden számlálót\n• minden kedvencet\n• minden lejátszási listát\n• minden gyorsítótárazott metaadatot\n\nA hangfájljaid nem törlődnek.';

  @override
  String get settingsDbReset => 'Az adatbázis visszaállítva';

  @override
  String get settingsDeleteDownloads => 'A letöltések törlése';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Törli az online mappa összes fájlját (számok, borítók)';

  @override
  String get settingsCleanAll => 'Helyi adatbázis és gyorsítótár tisztítása';

  @override
  String get settingsCleanAllSubtitle =>
      'Eltávolítja a fájl nélküli bejegyzéseket, a más eszközön lévő fájlokra mutató könyvtárbejegyzéseket, és üríti a borító- és metaadat-gyorsítótárat';

  @override
  String get settingsCleanAllConfirmBody =>
      'A más eszközön lévő fájlokra mutató könyvtárbejegyzések a fiókjából is törlődnek, tehát a többi eszközéről is. A borítók és metaadatok a következő lejátszáskor újra letöltődnek.';

  @override
  String get settingsDataAdvanced => 'Speciális';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Minden tisztítási lépés külön, a gyorsítótár és a visszaállítások';

  @override
  String get settingsDataGroupDb => 'Adatbázis';

  @override
  String get settingsDataGroupCache => 'Gyorsítótár';

  @override
  String get settingsDataGroupReset => 'Visszaállítás';

  @override
  String get settingsDeleteDownloadsTitle => 'Törlöd a letöltéseket?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Ez véglegesen törli az online mappa összes letöltött fájlját (számok, albumok, borítók).\n\nAz adatbázis-bejegyzések megmaradnak, de már nem létező fájlokra fognak mutatni.';

  @override
  String get settingsDownloadsDeleted => 'A letöltések törölve';

  @override
  String get settingsColor => 'Szín';

  @override
  String get settingsPmPresets => 'Presetek';

  @override
  String get settingsPmRandomNext => 'Véletlenszerű következő preset';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Kikapcsolva: a presetek sorrendben követik egymást';

  @override
  String get settingsPmLockPreset => 'A preset rögzítése';

  @override
  String get settingsPmLockPresetSubtitle => 'Nincs automatikus váltás';

  @override
  String get settingsPmPresetDuration => 'A presetek közti idő';

  @override
  String get settingsPmTransitions => 'Átmenetek';

  @override
  String get settingsPmBlend => 'Áttűnéses átmenet';

  @override
  String get settingsPmBlendSubtitle => 'Kikapcsolva: a preset azonnal vált';

  @override
  String get settingsPmTransitionStyle => 'Átmenet stílusa';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Az áttűnés által használt minta';

  @override
  String get settingsPmTransitionRandom => 'Véletlenszerű';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Ütemre szinkronizált presetváltás';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minimális idő';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: érzékenység';

  @override
  String get settingsPmRendering => 'Renderelés';

  @override
  String get settingsPmQuality => 'Minőség';

  @override
  String get settingsPmQualitySubtitle =>
      'Renderelési felbontás (Max = natív felbontás)';

  @override
  String get settingsPmBeatSensitivity => 'Ütemérzékenység';

  @override
  String get settingsPmAspectRatio => 'A képarány megtartása';

  @override
  String get settingsPmAspectRatioSubtitle => 'Az ezt támogató shaderekhez';

  @override
  String get settingsPmPermissive => 'Megengedő mód';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Szkripthibás .milk fájlok betöltése';

  @override
  String get accountTitle => 'Fiók';

  @override
  String get accountSubtitle => 'Mentsd és szinkronizáld a könyvtáradat';

  @override
  String get accountAnonymous => 'Névtelen fiók';

  @override
  String get accountAnonymousExplain =>
      'A kedvenceid és az előzményeid a kiszolgálón vannak, de csak ez az eszköz fér hozzájuk. Adj meg egy e-mail-címet, hogy máshol is megtaláld őket.';

  @override
  String get accountEmailAttached =>
      'A cím megerősítve — a fiók visszaállítható';

  @override
  String get accountEmailPending => 'A cím még nincs megerősítve';

  @override
  String get accountInsecureStorage =>
      'Az eszköz biztonságos tárolója nem érhető el: a fiókazonosító titkosítatlanul van tárolva.';

  @override
  String get accountSaveCta => 'Fiókom mentése';

  @override
  String get accountStatSongs => 'Kedvenc számok';

  @override
  String get accountStatAlbums => 'Kedvenc albumok';

  @override
  String get accountStatPlays => 'Lejátszások';

  @override
  String get accountCreatedLabel => 'Létrehozva';

  @override
  String get accountSignOut => 'Kijelentkezés';

  @override
  String get accountRevoke => 'Kijelentkezés mindenhonnan';

  @override
  String get accountRevokeSubtitle => 'Kijelentkezteti az összes többi eszközt';

  @override
  String get accountRevokeBody =>
      'Minden más eszköz kijelentkezik. Ez az eszköz bejelentkezve marad.';

  @override
  String get accountRevokeDone => 'A többi eszköz kijelentkezett';

  @override
  String get accountDelete => 'Fiókom törlése';

  @override
  String get accountDeleteSubtitle =>
      'Törli a fiókot és adatait a kiszolgálón. Visszavonhatatlan.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items kedvenc és $lists lejátszási lista törlődik a kiszolgálóról. Ez nem vonható vissza.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'A letöltéseidet és az eszköz könyvtárát ez nem érinti.';

  @override
  String get accountDeleteDone => 'Fiók törölve';

  @override
  String get accountSignOutSubtitle => 'Az eszköz új, üres fiókkal indul újra';

  @override
  String get accountSignOutTitle => 'Kijelentkezel?';

  @override
  String accountSignOutBody(String email) {
    return 'A(z) $email címre küldött kóddal térhetsz vissza ehhez a fiókhoz.';
  }

  @override
  String get accountSignedOut => 'Kijelentkezve';

  @override
  String get accountNoSignOut => 'A kijelentkezés nem érhető el';

  @override
  String get accountNoSignOutSubtitle =>
      'E-mail-cím nélkül ez a fiók végleg elveszne.';

  @override
  String get accountDetach => 'Cím leválasztása';

  @override
  String get accountDetachSubtitle =>
      'A fiók újra névtelen lesz, semmilyen adat nem törlődik';

  @override
  String get accountDetachBody =>
      'Cím nélkül ez a fiók már nem érhető el másik eszközről.';

  @override
  String get accountDetachDone => 'A cím leválasztva';

  @override
  String get accountOffline => 'A fiók offline nem érhető el';

  @override
  String get accountEmailTitle => 'E-mail-cím';

  @override
  String get accountEmailExplain =>
      'Küldünk egy 6 jegyű kódot a cím megerősítéséhez. Csak a fiók visszaállítására szolgál.';

  @override
  String get accountEmailLabel => 'E-mail-cím';

  @override
  String get accountCodeTitle => 'Megerősítő kód';

  @override
  String accountCodeExplain(String email) {
    return 'A kódot elküldtük ide: $email. 10 percig érvényes.';
  }

  @override
  String get accountCodeLabel => '6 jegyű kód';

  @override
  String get accountSendCode => 'Kód küldése';

  @override
  String get accountVerify => 'Megerősítés';

  @override
  String get accountResend => 'Kód újraküldése';

  @override
  String accountResendIn(int n) {
    return 'Újraküldés $n mp múlva';
  }

  @override
  String get accountCheckSpam =>
      'A levél percekig is jöhet — nézd meg a spam mappát is.';

  @override
  String get accountErrorInvalidEmail => 'Érvénytelen cím';

  @override
  String get accountErrorTooMany => 'Túl sok kérés, próbáld meg pár perc múlva';

  @override
  String get accountErrorInvalidCode => 'Hibás vagy lejárt kód';

  @override
  String get accountErrorCodeLength => 'A kód 6 jegyű';

  @override
  String get albumOfflinePartial => 'Offline — az eszközön már meglévő elemek';

  @override
  String get accountErrorNetwork => 'A kapcsolat nem jött létre, próbáld újra';

  @override
  String get accountMergeTitle => 'Egyesíted ezt a könyvtárat?';

  @override
  String accountMergeBody(String email) {
    return 'Az eszköz kedvencei és előzményei bekerülnek a(z) $email fiókba. A művelet végleges.';
  }

  @override
  String get accountMergeConfirm => 'Egyesítés';

  @override
  String get accountCarryLocal => 'Az eszköz kedvenceinek megtartása';

  @override
  String accountCarryLocalOn(int n) {
    return 'Az eszközön lévő $n kedvenc és a lejátszási listák bekerülnek a fiókba.';
  }

  @override
  String get accountCarryLocalOff =>
      'Törlődnek erről az eszközről, és a fiókéi lépnek a helyükbe. A letöltött fájlok megmaradnak.';

  @override
  String get accountDropLocalTitle => 'Törlöd az eszköz adatait?';

  @override
  String get accountCreatedOk => 'Fiók mentve, a könyvtárad biztonságban van';

  @override
  String get accountMergedOk => 'Bejelentkezve — a helyi kedvencek hozzáadva';

  @override
  String get accountSignedInOk => 'Bejelentkezve';

  @override
  String get playlistEntryMissing => 'A fájl hiányzik erről az eszközről';

  @override
  String get playlistEntryMissingRestorable =>
      'A fájl hiányzik — újra letölthető';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hiányzik',
      one: '$n hiányzik',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Mentés a fiókomba';

  @override
  String get playlistBackupSubtitle =>
      'Újratelepítés után is megőrzi ezt a lejátszási listát';

  @override
  String get playlistBackupUpdate => 'Mentés frissítése';

  @override
  String get playlistBackupUpdateSubtitle =>
      'A fiókban lévő másolatot erre a változatra cseréli';

  @override
  String get playlistBackupStop => 'Mentés leállítása';

  @override
  String get playlistBackupStopped => 'Mentés eltávolítva';

  @override
  String get playlistBackupDone => 'Lejátszási lista mentve';

  @override
  String get playlistBackupFailed => 'A mentés nem sikerült';

  @override
  String get playlistBackupNoAccount => 'Nincs fiók ezen az eszközön';

  @override
  String get playlistSyncTooltip => 'Szinkronizálás a fiókommal';

  @override
  String get playlistSyncRunning => 'Szinkronizálás…';

  @override
  String get playlistSyncDone => 'Lejátszási listák szinkronizálva';

  @override
  String get playlistSyncPartial =>
      'Néhány lejátszási listát nem sikerült menteni';

  @override
  String get playlistFetchMissing => 'Hiányzó számok letöltése';

  @override
  String get playlistFetchDone => 'A hiányzó számok letöltve';

  @override
  String get playlistFetchPartial => 'Néhány számot nem sikerült letölteni';

  @override
  String get playlistEntryFetchFailed => 'Ezt a számot nem sikerült letölteni';

  @override
  String get accountStatPlaylists => 'Lejátszási listák';

  @override
  String get accountSyncNow => 'Szinkronizálás most';

  @override
  String get accountSyncAuto => 'Magától fut a háttérben';

  @override
  String get accountSyncAnonymous =>
      'Mentve a kiszolgálóra. Adj meg egy e-mail-címet másik eszköz szinkronizálásához.';

  @override
  String get accountSyncPending => 'Változások várnak elküldésre';

  @override
  String accountSyncLast(String when) {
    return 'Legutóbbi szinkron: $when';
  }

  @override
  String get accountSyncDone => 'A szinkronizálás kész';

  @override
  String get accountSyncFailed =>
      'A szinkronizálás nem sikerült, újrapróbáljuk';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return '$production zenéje, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'tartalmazza a(z) $compo $place helyezettjét';
  }

  @override
  String get competitionEmpty => 'Ennek a versenynek nincsenek nevezései';

  @override
  String get competitionEntryNoMusic =>
      'Ehhez a nevezéshez nincs zene a katalógusban';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n szám',
      one: '$n szám',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Kihagyás';

  @override
  String get onboardingNext => 'Tovább';

  @override
  String get onboardingStart => 'Kezdés';

  @override
  String get onboardingBetaTitle => 'Béta verzió';

  @override
  String get onboardingBetaBody =>
      'A Rewamp még épül. A helyi adatok — könyvtár, lejátszási listák, kedvencek, statisztikák — a 1.0-s verzió előtt törlődhetnek. A letöltéseidet nem fenyegeti veszély, de ami fontos, azt tartsd meg máshol is.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Verzió: $version (build: $build)';
  }

  @override
  String get onboardingExploreTitle => 'Felfedezés';

  @override
  String get onboardingExploreBody =>
      'Böngéssz és keress több tízezer chiptune és tracker modul között a nagy online archívumokból — előadó, album, platform vagy party szerint. Koppints a hallgatáshoz, tölts le a megtartáshoz.';

  @override
  String get onboardingLibraryTitle => 'A könyvtárad';

  @override
  String get onboardingLibraryBody =>
      'Mentsd, ami tetszik, állíts össze lejátszási listákat, és rendezd őket mappákba. A letöltött zene offline is szól, a könyvtárad pedig bejelentkezés után követ az eszközeid között.';

  @override
  String get onboardingPlayerTitle => 'A lejátszó';

  @override
  String get onboardingPlayerBody =>
      'Húzz a számváltáshoz, és nyisd meg a vizualizációkat: oszcilloszkóp, csatornák, gördülő hangjegyek, tracker rács. A többszámos fájlok mutatják az alszámaikat, és minden szólam külön némítható.';

  @override
  String get onboardingReplayTitle => 'Bemutató';

  @override
  String get onboardingReplaySubtitle =>
      'A béta figyelmeztetés és a bemutató újranézése';

  @override
  String get settingsPatternTitle => 'Patternek';

  @override
  String get settingsPatternSubtitle =>
      'Tracker rács: színek, oszlopok, görgetés';

  @override
  String get patternOpaqueBg => 'Átlátszatlan háttér';

  @override
  String get patternOpaqueBgSubtitle => 'Elrejti a borítót a rács mögött';

  @override
  String get commonSave => 'Mentés';

  @override
  String get commonImport => 'Importálás';

  @override
  String get accountDisplayName => 'Nyilvános név';

  @override
  String get accountDisplayNameNotSet =>
      'Nincs beállítva — lejátszási lista közzétételéhez kell';

  @override
  String get accountDisplayNameHint => 'A név, amellyel szeretnél szerepelni.';

  @override
  String get accountDisplayNameChangeWarning =>
      'A módosítás minden közzétett lejátszási listádat visszaküldi jóváhagyásra.';

  @override
  String get accountDisplayNameTaken => 'Ez a név foglalt. Válassz másikat.';

  @override
  String get accountDisplayNameLength => '2 és 40 karakter között.';

  @override
  String get accountDisplayNameSaved => 'Nyilvános név mentve';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Jóváhagyásra visszaküldött lejátszási listák: $n';
  }

  @override
  String get playlistPublish => 'Közzététel';

  @override
  String get playlistPublishSubtitle => 'Közzététel kérése (előbb jóváhagyás)';

  @override
  String get playlistPublishTitle => 'Közzéteszed ezt a lejátszási listát?';

  @override
  String get playlistPublishBody =>
      'Jóváhagyás után mindenki látja, a nyilvános neveddel jelölve. A borító a benne lévő számokból áll össze.';

  @override
  String get playlistPublishCta => 'Kérés';

  @override
  String get playlistPublishSubmitted => 'Jóváhagyásra elküldve';

  @override
  String get playlistPublishPending => 'Jóváhagyásra vár';

  @override
  String get playlistPublishApproved => 'Nyilvános';

  @override
  String playlistPublishRejected(String reason) {
    return 'Elutasítva: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Elutasítva';

  @override
  String get playlistPublishNeedName =>
      'Válaszd ki a nevet, amellyel szeretnél szerepelni';

  @override
  String get playlistPublishNeedTracks =>
      'A közzétételhez legalább 5 szám kell';

  @override
  String get playlistPublishHasLocal =>
      'Az eszközödön lévő fájlok nem tehetők közzé — mások nem tudják lejátszani őket';

  @override
  String get playlistPublishTooManyPending =>
      'Már 3 lejátszási listád vár jóváhagyásra';

  @override
  String get playlistPublishRefused =>
      'A közzététel elutasítva: nézd át a számokat és a függőben lévő kéréseket';

  @override
  String get playlistPublishFailed => 'A közzététel nem sikerült';

  @override
  String get playlistPublishWithdrawn => 'A lejátszási lista ismét privát';

  @override
  String get playlistUnpublish => 'Priváttá tétel';

  @override
  String get playlistUnpublishSubtitle =>
      'Kiveszi a nyilvános lejátszási listák közül';

  @override
  String get playlistRenamePublishedTitle =>
      'Átnevezed a közzétett lejátszási listát?';

  @override
  String get playlistRenamePublishedBody =>
      'A nevet vizsgálják felül: az átnevezés visszaküldi a listát jóváhagyásra, és addig leveszi a nyilvánosról. Számok hozzáadása vagy átrendezése nem.';

  @override
  String playlistByAuthor(String author) {
    return '$author listája';
  }

  @override
  String get settingsSpectrumMode => 'Spektrum módja';

  @override
  String get settingsSpectrumModeStandard => 'Alap';

  @override
  String get settingsSpectrumModeColored => 'Színes';

  @override
  String get settingsSpectrumModeBeam => 'Sugár';

  @override
  String get settingsSpectrumModeLine => 'Vonal';

  @override
  String get settingsSpectrumModeRing => 'Gyűrű';

  @override
  String get settingsPianoMode => 'A zongora megjelenése';

  @override
  String get settingsPianoModeRoll => 'Billentyűzetek';

  @override
  String get settingsPianoModeFalling => 'Lehulló hangjegyek';

  @override
  String get settingsPianoColor => 'Színek';

  @override
  String get settingsPianoColorVoice => 'Szólam szerint';

  @override
  String get settingsPianoColorInstrument => 'Hangszer szerint';

  @override
  String get settingsPianoGlow => 'Ragyogás a leütött billentyűkön';

  @override
  String get settingsPianoLighting => 'Fény és árnyékok a billentyűkön';

  @override
  String get settingsPianoVoiceNames => 'Szólamok nevei';

  @override
  String get featuredAdditionsHeader => 'Újdonságok a katalógusban';

  @override
  String get featuredAdditionsCard => 'Most került be';

  @override
  String get featuredAdditionsPlaylist => 'A frissen bekerült számok';

  @override
  String get releaseNotesTitle => 'Újdonságok';

  @override
  String get releaseNotesV7Cpu =>
      'Az alkalmazás már nem dolgozik a háttérben, amikor semmi sem szól: sokkal kevesebb processzor- és akkumulátorhasználat.';

  @override
  String get releaseNotesV7VizIdle =>
      'A vizualizációk megállnak, amíg a lejátszás le van állítva, és legfeljebb 60 képkocka/másodpercre korlátozódnak (állítható).';

  @override
  String get releaseNotesV7Subsongs =>
      'Javítva: PC Engine, Master System és Atari ST (.sndh) esetén egyes számok a szomszédos dalt indították el.';

  @override
  String get releaseNotesV7Piano =>
      'A Zongora vizualizáció üres maradt PC Engine-zenénél.';

  @override
  String get releaseNotesV7Database =>
      'A frissítés által megrongált adatbázis most magától helyreáll, ahelyett hogy elérhetetlenné tenné a könyvtárat.';

  @override
  String get releaseNotesDataReset =>
      'A helyi adatok törlődtek ehhez a bétához. A könyvtár és a lejátszási listák a fiókból épülnek újra; a letöltéseket meg kell ismételni.';

  @override
  String get releaseNotesDismiss => 'Tovább';

  @override
  String get pmManagePresets => 'Presetek kezelése';

  @override
  String get pmPickTooltip => 'Előbeállítás választása';

  @override
  String get pmPickFilter => 'Előbeállítások szűrése';

  @override
  String get pmSourceTooltip => 'Preset-forrás';

  @override
  String get pmAddToPlaylistTooltip => 'Preset hozzáadása lejátszási listához';

  @override
  String pmSlowPresetDropped(String name) {
    return 'A(z) „$name” túl nehéz ennek az eszköznek, ezért kimaradt.';
  }

  @override
  String get pmSlowDeviceTitle => 'Ez az eszköz túl lassú';

  @override
  String get pmSlowDeviceOff =>
      'A vizualizáció kikapcsolva: ez az eszköz nem bírja a Milkdrop-preseteket.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kihagyott preset',
      one: '$count kihagyott preset',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Túl lassúak ezen az eszközön. A lejátszás kihagyja őket.';

  @override
  String get settingsPmSlowPresetsRestore => 'Visszaállítás';

  @override
  String get pmSourceBundled => 'Beépített presetek';

  @override
  String get pmSourceImports => 'Saját importok';

  @override
  String get pmSourceAll => 'Összes preset';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preset',
      one: '$count preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Új lejátszási lista…';

  @override
  String get pmPlaylistName => 'Lejátszási lista neve';

  @override
  String get pmAddedToPlaylist => 'Hozzáadva a lejátszási listához';

  @override
  String get pmAlreadyInPlaylist => 'Már szerepel ezen a lejátszási listán';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Böngészés';

  @override
  String get pmTabPlaylists => 'Lejátszási listák';

  @override
  String get pmTabPopular => 'Népszerű';

  @override
  String get pmTabSetAside => 'Kihagyottak';

  @override
  String get pmSetAsideEmpty =>
      'Semmi sincs kihagyva. Ide kerülnek azok a presetek, amelyeknél az eszköz 6 fps alá esik.';

  @override
  String get pmSetAsideRestoreAll => 'Összes visszaállítása';

  @override
  String get pmInstall => 'Telepítés';

  @override
  String get pmInstallQueued => 'Telepítés sorba állítva';

  @override
  String get pmUninstall => 'Eltávolítás';

  @override
  String get pmUninstalled => 'Pack eltávolítva';

  @override
  String get pmUse => 'Használat';

  @override
  String get pmDefaultPackBanner => 'Ajánlott kezdő pack';

  @override
  String pmLicense(String license) {
    return 'Licenc: $license';
  }

  @override
  String get pmPacksOffline => 'A szerver nem érhető el';

  @override
  String get pmSearchPresets => 'Presetek keresése…';

  @override
  String get pmPlayNow => 'Lejátszás most';

  @override
  String get pmDownloadAction => 'Letöltés';

  @override
  String get pmDownloaded => 'Preset letöltve';

  @override
  String get pmDownloadFailed => 'A letöltés nem sikerült';

  @override
  String pmPreviewing(String name) {
    return 'Lejátszás: $name';
  }

  @override
  String get pmLocalSection => 'Saját lejátszási listák';

  @override
  String get pmCuratedSection => 'Rewamp lejátszási listák';

  @override
  String get pmImportPlaylist => 'Letöltés és használat';

  @override
  String get pmPlaylistImported => 'A lejátszási lista készen áll';

  @override
  String get pmImportFiles => 'Fájlok importálása…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preset importálva',
      one: '$count preset importálva',
      zero: 'Nem lett preset importálva',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presetek hozzáadva a projectM-könyvtárhoz';

  @override
  String get pmNoPlaylists => 'Még nincs preset-lejátszási lista';

  @override
  String get pmSourceApplied => 'Preset-forrás alkalmazva';

  @override
  String get pmPlaylistEmpty => 'Ez a lejátszási lista üres';

  @override
  String get pmDays7 => '7 nap';

  @override
  String get pmDays30 => '30 nap';

  @override
  String get pmDays365 => '1 év';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lejátszás',
      one: '$count lejátszás',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'A telepítés nem sikerült';

  @override
  String get pmSingleDownloads => 'Egyedi letöltések';

  @override
  String pmAvailableIn(String pack) {
    return 'Elérhető: $pack';
  }

  @override
  String get pmCleanUp => 'Törlés';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preset törölve',
      zero: 'Nincs mit törölni',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Preset rögzítése';

  @override
  String get pmUnlockAction => 'Preset feloldása';

  @override
  String get pmOrderRandom => 'Véletlenszerű presetek';

  @override
  String get pmOrderSequential => 'Presetek sorrendben';

  @override
  String get pmUpdateAvailable => 'Frissítés érhető el';

  @override
  String get pmUpdate => 'Frissítés';

  @override
  String get pmSelectAll => 'Összes kijelölése';

  @override
  String get pmSelectNone => 'Kijelölés törlése';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kijelölve',
      one: '$count kijelölve',
      zero: 'Nincs kijelölve',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Nem használt textúrák';

  @override
  String pmTexturesFreed(String size) {
    return '$size felszabadítva';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count textúra',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'Slágerlisták';

  @override
  String get chartsGlobal => 'Globális';

  @override
  String get chartsByCollection => 'Gyűjtemény szerint';

  @override
  String get chartsTopSongs => 'Top dalok';

  @override
  String get chartsTopAlbums => 'Top albumok';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Közzétett listák';

  @override
  String chartsUpdated(String date) {
    return 'Frissítve: $date';
  }

  @override
  String get chartsSource => 'Forrás';

  @override
  String get settingsMidiSynth => 'MIDI-szintetizátor';

  @override
  String get settingsMidiSynthAuto => 'Automatikus (MT-32, ha a fájl kéri)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (emuláció)';

  @override
  String get settingsMt32Section => 'Roland MT-32 emuláció';

  @override
  String get settingsMt32RomsTitle => 'MT-32 ROM-ok';

  @override
  String get settingsMt32RomsMissing =>
      'Nincs használható ROM-készlet — importálja egy MT-32 vagy CM-32L vezérlő- és PCM-ROM-ját';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Aktív készlet: $set';
  }

  @override
  String get settingsMt32Import => 'ROM-fájlok importálása…';

  @override
  String get settingsMt32ImportSubtitle =>
      'Vezérlő ROM + PCM ROM (.rom/.bin), a MAME-felek elfogadottak. A ROM-ok nem részei az alkalmazásnak.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name nem ismert MT-32 / CM-32L ROM';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ROM-fájl importálva',
      one: '$count ROM-fájl importálva',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Modell';

  @override
  String get settingsMt32ModelAuto => 'Automatikus (CM-32L, ha elérhető)';

  @override
  String get settingsMt32Reverb => 'Zengetés';

  @override
  String get engineDescMt32 =>
      'Roland MT-32 / CM-32L emuláció MIDI-hez (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Minilejátszó';

  @override
  String get miniWindowExit => 'Vissza a főablakhoz';

  @override
  String get miniWindowIdle => 'Nincs lejátszás';

  @override
  String get settingsAlwaysOnTopTitle => 'Mindig felül';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Az ablakot a többi fölött tartja — a főablakot és a minilejátszót is';

  @override
  String get windowAlwaysOnTopOn => 'Mindig felül: be';

  @override
  String get miniWindowCoverFill => 'Borító nagyítása kitöltésig';

  @override
  String get miniWindowCoverFit => 'Teljes borító megjelenítése';

  @override
  String get releaseNotesV7Mt32 =>
      'Új Roland MT-32 motor a játékok MIDI-zenéjéhez, a saját ROM-jaiddal. ROM-ok nélkül az MT-32-re írt MIDI a General MIDI-hez igazodik.';

  @override
  String get releaseNotesV7Xmp =>
      'Tíz ritka modulformátum is lejátszható (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'A Westwood AdLib-zenéi (.adl) minden számukat lejátsszák, a BP SoundMon V1 pedig felismerhető Amigán.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac: minilejátszó, kompakt vagy vizualizációval, és „Mindig felül” beállítás.';

  @override
  String get releaseNotesV7Instruments =>
      'Az oszcilloszkóp, a kotta és a zongora minden hangszert meg tud nevezni és színezni, nem csak minden szólamot.';

  @override
  String get releaseNotesV7Podium =>
      'Keresés: szűrés a demoscene-versenyeken 1., 2. vagy 3. helyezést elért számokra.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'A túl rövid alszámok (játékok hangeffektusai) kimaradnak az „Összes lejátszása” alól — küszöb: Beállítások → Lejátszás.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Importjaid: húzz be egy teljes mappát (az archívumok kibontva), és hozz létre, nevezz át vagy helyezz át mappákat.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI: a dob többé nem zongoraként szól, és a hangerő sem torzul.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM: az előbeállítások már nem ismétlődnek indításról indításra, és szünet után sem sorolódik ki tévesen egy előbeállítás.';

  @override
  String get libraryFileMissing => 'Hiányzó fájl';
}
