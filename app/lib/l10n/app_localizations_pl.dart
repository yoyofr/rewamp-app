// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get navHome => 'Główna';

  @override
  String get navSearch => 'Szukaj';

  @override
  String get navLocal => 'Lokalne';

  @override
  String get settingsTabsOrderTitle => 'Kolejność kart';

  @override
  String get settingsTabsOrderSubtitle =>
      'Przeciągaj, aby uporządkować. Pierwsze cztery trafiają na dolny pasek, reszta do „Więcej”.';

  @override
  String get settingsTabsInBar => 'Na pasku';

  @override
  String get settingsTabsInMore => 'W „Więcej”';

  @override
  String get settingsLaunchTab => 'Karta przy starcie';

  @override
  String get settingsLaunchTabSubtitle =>
      'Od której karty otwiera się aplikacja';

  @override
  String get navLibrary => 'Biblioteka';

  @override
  String get noFileSelected => 'Nie wybrano pliku';

  @override
  String get openFile => 'Otwórz plik';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Format nieobsługiwany';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Nieobsługiwany format: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Nie ma go na tym urządzeniu: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Pliku już nie ma na serwerze: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return 'Pliku $file nie ma w archiwum albumu — rip go wymienia, ale nie dostarcza.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host nie odpowiedział. Sprawdź połączenie i spróbuj ponownie.';
  }

  @override
  String get failedToLoadFile => 'Nie udało się wczytać pliku';

  @override
  String get libraryEmptyHint =>
      'Twoi wykonawcy, albumy i playlisty\npojawią się tutaj.';

  @override
  String get libraryPlaylists => 'Playlisty';

  @override
  String get libraryArtists => 'Wykonawcy';

  @override
  String get libraryAlbums => 'Albumy';

  @override
  String get libraryTracks => 'Utwory';

  @override
  String get libraryFavorites => 'Ulubione';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatyczna playlista z Twoich ulubionych utworów';

  @override
  String get libraryRecentlyAdded => 'Ostatnio dodane';

  @override
  String get libraryEmpty => 'Jeszcze nic tu nie ma';

  @override
  String get libraryRemoved => 'Usunięto z biblioteki';

  @override
  String get searchHint => 'Szukaj…';

  @override
  String get searchTypePlaceholder => 'Wpisz tytuł, wykonawcę lub album…';

  @override
  String get searchNoResults => 'Brak wyników';

  @override
  String get searchDownloading => 'Pobieranie…';

  @override
  String searchError(String message) {
    return 'Błąd: $message';
  }

  @override
  String get tabAll => 'Utwory';

  @override
  String get tabArtists => 'Wykonawcy';

  @override
  String get tabAlbums => 'Albumy';

  @override
  String get tabProductions => 'Produkcje';

  @override
  String get filterWithVideo => 'Z wideo';

  @override
  String get videoUnavailable => 'To wideo jest niedostępne';

  @override
  String get noItems => 'Brak elementów';

  @override
  String get sortRelevance => 'Trafność';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Ostatnio odtwarzane';

  @override
  String get noRecentTracks => 'Brak ostatnio odtwarzanych utworów';

  @override
  String get playerSourceLocal => 'lokalny';

  @override
  String get homePlayFiles => 'Odtwórz pliki';

  @override
  String get homePlayFolder => 'Odtwórz folder';

  @override
  String get homeSectionsOrderTitle => 'Kolejność sekcji';

  @override
  String get homeSectionsOrderSubtitle =>
      'Przeciągaj, aby ułożyć ekran główny po swojemu.';

  @override
  String get homeSectionsOrderReset => 'Kolejność domyślna';

  @override
  String get homeSectionsOrderSettings => 'Kolejność sekcji ekranu głównego';

  @override
  String countTotal(int loaded, String total) {
    return 'Wyniki: $loaded / $total';
  }

  @override
  String countLoadingMore(int loaded) {
    return 'Wczytano: $loaded…';
  }

  @override
  String countComplete(int loaded) {
    return 'Wyniki: $loaded';
  }

  @override
  String countScrollMore(int loaded) {
    return 'Wczytano: $loaded — przewiń, aby zobaczyć więcej';
  }

  @override
  String countNLoaded(int n) {
    return 'Wczytano: $n';
  }

  @override
  String countFilesLoaded(int n) {
    return 'Pliki: $n';
  }

  @override
  String get browseFilterByTitle => 'Filtruj po tytule…';

  @override
  String get browseNoSongs => 'Brak dostępnych utworów';

  @override
  String get browseByFormat => 'Wg formatu';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtruj po formacie…';

  @override
  String get browseByPlatform => 'Wg platformy';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Nazwa platformy…';

  @override
  String get browseByChip => 'Wg układu dźwiękowego';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'np. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Wg wykonawcy';

  @override
  String get browseByArtistSubtitle => 'Przeglądaj kompozytorów';

  @override
  String get browseFilterByName => 'Filtruj po nazwie…';

  @override
  String get browseNoArtistFound => 'Nie znaleziono wykonawcy';

  @override
  String get browseNoArtistsAvailable => 'Brak dostępnych wykonawców';

  @override
  String get browseNoArtist => 'Brak wykonawców';

  @override
  String get browseNoAlbum => 'Brak albumów';

  @override
  String get browseTopPacks => 'Najlepsze packi';

  @override
  String get browseTopPacksSubtitle => 'Najwyżej oceniane packi';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Najlepsze packi — $collection';
  }

  @override
  String get browseLatestPacks => 'Najnowsze packi';

  @override
  String get browseLatestPacksSubtitle => 'Ostatnio dodane pozycje';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Najnowsze packi — $collection';
  }

  @override
  String get browseAllSongs => 'Wszystkie utwory';

  @override
  String get browseAllSongsSubtitleAlpha =>
      'Przeglądaj w kolejności alfabetycznej';

  @override
  String get browseAlphabetical => 'W kolejności alfabetycznej';

  @override
  String browseAllLabel(String collection) {
    return 'Wszystko — $collection';
  }

  @override
  String get browseCollections => 'Kolekcje';

  @override
  String browseFilesCount(String count) {
    return 'Pliki: $count';
  }

  @override
  String get browseIndexing => 'Trwa indeksowanie';

  @override
  String browseFilterFacet(String name) {
    return 'Filtruj $name…';
  }

  @override
  String get browseAllYears => 'Wszystkie lata';

  @override
  String get browseAllYearsSubtitle => 'Wszystkie utwory z tej party';

  @override
  String get browseNoCompo => 'Dla tej party nie zaindeksowano żadnego compo.';

  @override
  String get browseOthers => 'Inne';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n wpisu — ranking',
      many: '$n wpisów — ranking',
      few: '$n wpisy — ranking',
      one: '$n wpis — ranking',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Odtwórz playlistę';

  @override
  String get browsePlayAllRanked => 'Odtwórz wszystko (w kolejności rankingu)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu — kolejność rankingu',
      many: '$n utworów — kolejność rankingu',
      few: '$n utwory — kolejność rankingu',
      one: '$n utwór — kolejność rankingu',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Przeglądaj wg albumów';

  @override
  String get browsePlayAll => 'Odtwórz wszystko';

  @override
  String get browseShuffle => 'Odtwarzanie losowe';

  @override
  String get browseSearchInFolder => 'Szukaj w tym folderze…';

  @override
  String get browseFilterThisList => 'Filtruj tę listę…';

  @override
  String get browseSearchSubfolders => 'Szukaj w podfolderach';

  @override
  String get browseEmptyFolder => 'Pusty folder';

  @override
  String browsePlaybackError(String message) {
    return 'Odtwarzanie nie powiodło się: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Widok';

  @override
  String get browseViewList => 'Lista';

  @override
  String get browseViewGrid => 'Siatka';

  @override
  String get browseViewGridCompact => 'Siatka kompaktowa';

  @override
  String get browseSearchAlbum => 'Szukaj albumu…';

  @override
  String get browseSearchArtist => 'Szukaj wykonawcy…';

  @override
  String get browsePlayAlbum => 'Odtwórz album';

  @override
  String get searchDownloadingAlbum => 'Pobieranie albumu…';

  @override
  String get searchCategoryChip => 'Układy';

  @override
  String get searchCategoryGroup => 'Grupy';

  @override
  String get artistRealName => 'Prawdziwe imię';

  @override
  String get artistAliases => 'Aliasy';

  @override
  String get artistBorn => 'Urodzony';

  @override
  String get artistInterview => 'Wywiad';

  @override
  String get audioOutput => 'Wyjście audio';

  @override
  String get audioOutputSystemDefault => 'Domyślne systemowe';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notatki';

  @override
  String get notePlacedBadge => 'Sklasyfikowana w konkursie';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count członka',
      many: '$count członków',
      few: '$count członków',
      one: '$count członek',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Zobacz utwory';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modułu',
      many: '$count modułów',
      few: '$count moduły',
      one: '$count moduł',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Party';

  @override
  String get searchCategoryYear => 'Rok';

  @override
  String get searchCategoryOrigin => 'Pochodzenie';

  @override
  String get searchCategoryProduction => 'Produkcje';

  @override
  String get searchCategoryProductionType => 'Typy produkcji';

  @override
  String get searchCategoryPublisher => 'Wydawcy';

  @override
  String get searchCategoryDeveloper => 'Deweloperzy';

  @override
  String get searchCategoryArcadeBoard => 'Płyty arcade';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Gatunek';

  @override
  String get searchViaArtist => 'przez wykonawcę';

  @override
  String get searchViaAlbum => 'przez album';

  @override
  String get searchViaSong => 'przez utwór';

  @override
  String get searchSortPopular => 'Popularne';

  @override
  String get searchSortYear => 'Rok';

  @override
  String get searchSortRandom => 'Losowo';

  @override
  String get searchSortRating => 'Ocena';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count głosu',
      many: '$count głosów',
      few: '$count głosy',
      one: '$count głos',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Rosnąco';

  @override
  String get searchSortDesc => 'Malejąco';

  @override
  String get searchFilters => 'Filtry';

  @override
  String get searchExactSearch => 'Wyszukiwanie dokładne';

  @override
  String get searchExactSearchSubtitle =>
      'Wyłącza wyszukiwanie przybliżone (fuzzy)';

  @override
  String get searchTags => 'Tagi';

  @override
  String searchTagSearchHint(String category) {
    return 'Szukaj tagu w « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Zacznij pisać, aby wyszukać tagi.';

  @override
  String get searchTagsAndLogic => 'Kilka tagów = logiczne ORAZ.';

  @override
  String get searchFilterYear => 'Rok';

  @override
  String get searchFilterAll => 'wszystkie';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrowanie wg roku pomija utwory bez daty.';

  @override
  String get searchMinRating => 'Ocena ≥';

  @override
  String get searchPodium => 'Podium';

  @override
  String get searchPodiumAny => 'Dowolne podium';

  @override
  String get searchPodiumUnavailable =>
      'Filtr podium nie jest jeszcze dostępny na serwerze';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Anuluj';

  @override
  String get searchReset => 'Zresetuj';

  @override
  String get searchApply => 'Zastosuj';

  @override
  String get searchClearRecent => 'Wyczyść ostatnie wyszukiwania';

  @override
  String get searchBrowse => 'Przeglądaj';

  @override
  String get searchBrowseHint =>
      'Wybierz aspekt (grupa, układ, rok…), aby poznać katalog, albo uruchom Radio/Niespodziankę powyżej.';

  @override
  String get searchDidYouMean =>
      'Mało wyników — spróbować wyszukiwania przybliżonego?';

  @override
  String get searchYes => 'Tak';

  @override
  String get featuredCommunityTitle => 'Nowości od społeczności';

  @override
  String get searchPlaylistSourceAll => 'Wszystkie';

  @override
  String get searchPlaylistSourceUser => 'Społeczność';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Platforma';

  @override
  String get filterCollection => 'Kolekcja';

  @override
  String get videoWatchDemo => 'Obejrzyj demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Kolekcja: $name';
  }

  @override
  String get searchCollectionAll => 'Wszystkie';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Losowa kolejka według bieżących filtrów';

  @override
  String get searchSurprise => 'Niespodzianka';

  @override
  String get searchSurpriseTooltip => 'Losowy utwór';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Brak utworów';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albumu',
      many: '$n albumów',
      few: '$n albumy',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Wybierz kolekcję';

  @override
  String get searchFilterCollections => 'Filtruj kolekcje…';

  @override
  String get searchFilterPlaceholder => 'Filtruj…';

  @override
  String searchAllOf(String label) {
    return 'Wszystko ($label)';
  }

  @override
  String get searchNoMatch => 'Brak dopasowań';

  @override
  String get searchNoPlaylist => 'Brak playlist';

  @override
  String get engineDescOpenmpt => 'Moduły tracker (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Moduły, których libopenmpt nie odczytuje (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — układy dźwiękowe, oscyloskop na kanał';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archiwa RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — głosy na kanał';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (silnik reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'Chiptune MSX (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Chiptune wieloukładowe .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Formaty Amiga z układami custom przez emulację 68k (~320 rozszerzeń)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Standardowe MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — syntezator SDAT/SSEQ (16 głosów)';

  @override
  String get engineDescV2m => 'Syntezator V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — prawdziwa emulacja 68000 + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — emulacja R4300 + RSP audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — emulacja NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + układ QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — prawdziwy syntezator AY-3-8910/YM2149';

  @override
  String get engineDescOrganya => 'Cave Story .org — własny silnik Pixela';

  @override
  String get engineDescPxtone => 'Tracker Pixela — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — prawdziwy 68000 przez emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver dla PC-98 — FM OPNA + SSG + próbki PPZ8';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ próbki .pdx), FM YM2151';

  @override
  String get engineDescFmp =>
      'Sterownik FMP dla PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY dla FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Bezstratny .ape';

  @override
  String get engineDescVgmstream =>
      'Strumieniowe formaty audio z gier (700+, w tym .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — dekoder zapasowy';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total utworu',
      many: '$loaded / $total utworów',
      few: '$loaded / $total utwory',
      one: '$loaded / 1 utwór',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total albumu',
      many: '$loaded / $total albumów',
      few: '$loaded / $total albumy',
      one: '$loaded / 1 album',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total wykonawcy',
      many: '$loaded / $total wykonawców',
      few: '$loaded / $total wykonawcy',
      one: '$loaded / 1 wykonawca',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albumu',
      many: '$n albumów',
      few: '$n albumy',
      one: '$n album',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n wykonawcy',
      many: '$n wykonawców',
      few: '$n wykonawcy',
      one: '$n wykonawca',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n grupy',
      many: '$n grup',
      few: '$n grupy',
      one: '$n grupa',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Kraje';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kraju',
      many: '$n krajów',
      few: '$n kraje',
      one: '$n kraj',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Foldery';

  @override
  String get featuredTitle => 'Dziś polecamy';

  @override
  String featuredPartyNow(String party) {
    return '$party trwa właśnie teraz — podia z poprzednich edycji';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party zaczyna się za $days dnia — podia z poprzednich edycji',
      many: '$party zaczyna się za $days dni — podia z poprzednich edycji',
      few: '$party zaczyna się za $days dni — podia z poprzednich edycji',
      one: '$party zaczyna się jutro — podia z poprzednich edycji',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'Sezon $series — podia z poprzednich edycji';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Wydano: $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age roku temu: gry z $year roku',
      many: '$age lat temu: gry z $year roku',
      few: '$age lata temu: gry z $year roku',
      one: 'Rok temu: gry z $year roku',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Lata $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age roku temu: gry z $year roku',
      many: '$age lat temu: gry z $year roku',
      few: '$age lata temu: gry z $year roku',
      one: 'Rok temu: gry z $year roku',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Premiery: $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Rocznice';

  @override
  String get featuredBirthdayHeader => 'Dzisiejsze urodziny';

  @override
  String get featuredBirthdayWeekHeader => 'Urodziny w tym tygodniu';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist ma w tym tygodniu urodziny';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlisty',
      many: '$count playlist',
      few: '$count playlisty',
      one: '$count playlista',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Ponów';

  @override
  String get commonOptions => 'Opcje';

  @override
  String get commonDownload => 'Pobierz';

  @override
  String get commonDeleteDownload => 'Usuń pobrany plik';

  @override
  String get commonAddToPlaylist => 'Dodaj do playlisty';

  @override
  String get commonPlayNext => 'Odtwórz jako następny';

  @override
  String get commonAddToQueueEnd => 'Dodaj na koniec kolejki';

  @override
  String get commonAddToFavorites => 'Dodaj do ulubionych';

  @override
  String get commonRemoveFromFavorites => 'Usuń z ulubionych';

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
  String get subsongDeleteDownloadTitle => 'Usunąć ten pobrany plik?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Plik i jego lokalne wpisy (historia, utwory) zostaną usunięte.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Nie udało się odczytać utworów';

  @override
  String subsongTrackNumber(int number) {
    return 'Utwór $number';
  }

  @override
  String get subsongDefaultTrack => 'Utwór domyślny';

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subsongu',
      many: '$count subsongów',
      few: '$count subsongi',
      one: '$count subsong',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Odtwórz wszystko';

  @override
  String get albumDownloading => 'Pobieranie albumu…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Pobieranie albumu… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Pobierz album, aby zobaczyć jego utwory';

  @override
  String get albumNotDownloadedHint =>
      'Album niepobrany — włącz odtwarzanie, aby go pobrać';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworu',
      many: '$count utworów',
      few: '$count utwory',
      one: '$count utwór',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Wczytywanie szczegółów…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Odtwórz album';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementu',
      many: '$count elementów',
      few: '$count elementy',
      one: '$count element',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Najpierw odtwórz ten utwór z wyszukiwarki, aby go pobrać';

  @override
  String get libraryAddedTrack => 'Utwór dodany do biblioteki';

  @override
  String get libraryAddedAlbum => 'Album dodany do biblioteki';

  @override
  String get libraryAddedArtist => 'Wykonawca dodany do biblioteki';

  @override
  String get libraryRemovedTrack => 'Utwór usunięty z biblioteki';

  @override
  String get libraryRemovedAlbum => 'Album usunięty z biblioteki';

  @override
  String get libraryRemovedArtist => 'Wykonawca usunięty z biblioteki';

  @override
  String get libraryImportBeforeAddTitle => 'Najpierw zaimportować?';

  @override
  String get libraryImportBeforeAddBody =>
      'Ten plik jest odtwarzany z tymczasowej lokalizacji, którą system może wyczyścić. Zaimportować go do biblioteki lokalnej, aby wpis przetrwał?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'Ten utwór pochodzi z archiwum otwartego w tymczasowej pamięci podręcznej. Całe archiwum zostanie zaimportowane do biblioteki lokalnej, wraz z plikami towarzyszącymi.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'Nie można dodać tego utworu: jego identyfikator katalogowy jest nieznany na tym urządzeniu.';

  @override
  String songTilePlayFailed(String message) {
    return 'Odtwarzanie nie powiodło się: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Pobieranie nie powiodło się — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Pobieranie — $label';
  }

  @override
  String get downloadsTitle => 'Pobrania';

  @override
  String get downloadsEmpty => 'Brak oczekujących pobrań';

  @override
  String get downloadsPause => 'Wstrzymaj';

  @override
  String get downloadsResume => 'Wznów';

  @override
  String get downloadsCancel => 'Anuluj pobieranie';

  @override
  String get downloadsClear => 'Usuń wszystko';

  @override
  String get downloadsPausedBanner =>
      'Pobieranie wstrzymane — bieżący plik zostanie dokończony';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Pobieranie — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Playlista';

  @override
  String get miniPlayerHideQueue => 'Ukryj playlistę';

  @override
  String get transportShuffle => 'Odtwarzanie losowe';

  @override
  String get transportShuffleOn => 'Odtwarzanie losowe włączone';

  @override
  String get transportLoopOff => 'Powtarzanie wyłączone';

  @override
  String get transportLoopQueue => 'Powtarzanie: kolejka';

  @override
  String get transportLoopTrack => 'Powtarzanie: bieżący utwór';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Widmo';

  @override
  String get vizVoices => 'Głosy';

  @override
  String get vizNotes => 'Nuty';

  @override
  String get vizPiano => 'Pianino';

  @override
  String get vizPatterns => 'Patterny';

  @override
  String get patternScrollMode => 'Tryb przewijania';

  @override
  String get patternSmoothScroll => 'Płynne przewijanie';

  @override
  String get patternPinnedRow => 'Przypięty aktywny wiersz';

  @override
  String get patternVolumeBars => 'Paski głośności';

  @override
  String get patternColorScheme => 'Schemat kolorów';

  @override
  String get patternSize => 'Rozmiar';

  @override
  String get patternColumns => 'Kolumny';

  @override
  String get patternColumnsAll => 'Pełny';

  @override
  String get patternColumnsNoteInstr => 'Ograniczony';

  @override
  String get patternColumnsNote => 'Minimalny';

  @override
  String get vizClose => 'Zamknij wizualizator';

  @override
  String get vizFullscreen => 'Pełny ekran';

  @override
  String get vizExitFullscreen => 'Wyjdź z pełnego ekranu';

  @override
  String get vizPrevPreset => 'Poprzedni preset';

  @override
  String get vizNextPreset => 'Następny preset';

  @override
  String get vizProjectmUnavailable => 'projectM niedostępny';

  @override
  String get voicesTitle => 'Głosy';

  @override
  String get voicesNone => 'Brak głosów dla tego utworu.';

  @override
  String get voicesLongPressSolo => 'długie przytrzymanie = solo';

  @override
  String get voicesMuteAll => 'Wycisz wszystkie';

  @override
  String get voicesUnmuteAll => 'Włącz wszystkie';

  @override
  String get voicesStereoOutput => 'Wyjście stereo';

  @override
  String get voicesLeft => 'Lewy';

  @override
  String get voicesRight => 'Prawy';

  @override
  String get enginesFormatsTitle => 'Obsługiwane formaty';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats obsługiwanych formatów w $engines silnikach odtwarzania.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formatu',
      many: '$count formatów',
      few: '$count formaty',
      one: '1 format',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Cover utworu $title — $artist';
  }

  @override
  String stilCover(String work) {
    return 'Cover: $work';
  }

  @override
  String get playerQueue => 'Kolejka';

  @override
  String get queueEdit => 'Edytuj';

  @override
  String get queueEditDone => 'Gotowe';

  @override
  String get queueClear => 'Wyczyść kolejkę';

  @override
  String get queueClearConfirmTitle => 'Wyczyścić kolejkę?';

  @override
  String get queueClearConfirmBody =>
      'Kolejka zostanie opróżniona, a odtwarzanie zatrzymane.';

  @override
  String get queueClearConfirm => 'Wyczyść';

  @override
  String get queueRemoveSelected => 'Usuń zaznaczone';

  @override
  String get queueRemoveTrack => 'Usuń z kolejki';

  @override
  String get queueReorder => 'Zmień kolejność';

  @override
  String get playerArtwork => 'Okładka';

  @override
  String get playerVisualizer => 'Wizualizator';

  @override
  String get playerVoices => 'Głosy';

  @override
  String get playerTrackInfo => 'Informacje o utworze';

  @override
  String get playerShowQueue => 'Playlista';

  @override
  String get playerHideQueue => 'Ukryj playlistę';

  @override
  String get playerNoTrackInfo => 'Brak dostępnych informacji.';

  @override
  String get playerViewSubsongs => 'Pokaż subsongi';

  @override
  String get playerViewAlbum => 'Zobacz album';

  @override
  String get playerViewArtist => 'Zobacz wykonawcę';

  @override
  String get playerAddToPlaylist => 'Dodaj do playlisty';

  @override
  String get playerEngineSettings => 'Ustawienia silnika';

  @override
  String get queueAddToPlaylist => 'Dodaj kolejkę do playlisty';

  @override
  String get playerMoreOptions => 'Więcej opcji';

  @override
  String get playerClose => 'Zamknij';

  @override
  String get playerCancel => 'Anuluj';

  @override
  String get playerDelete => 'Usuń';

  @override
  String get playerAddFavorite => 'Dodaj do ulubionych';

  @override
  String get playerRemoveFavorite => 'Usuń z ulubionych';

  @override
  String get playerAddToLibrary => 'Dodaj do biblioteki';

  @override
  String get playerRemoveFromLibrary => 'Usuń z biblioteki';

  @override
  String get playerAddedToLibrary => 'Utwór dodany do biblioteki';

  @override
  String get playerRemovedFromLibrary => 'Utwór usunięty z biblioteki';

  @override
  String get playerDeleteDownload => 'Usuń pobrany plik';

  @override
  String get playerRedownload => 'Pobierz plik ponownie';

  @override
  String get playerRedownloadUnavailable =>
      'Ponowne pobranie niedostępne dla tego pliku';

  @override
  String get playerDeleteDownloadTitle => 'Usunąć pobrany plik?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Plik i jego lokalne wpisy (historia, utwory) zostaną usunięte.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Twoje trendy';

  @override
  String get homeYourAllTimeTop => 'Twój top wszech czasów';

  @override
  String get homeTrending => 'Na czasie';

  @override
  String get homeFeaturedPlaylists => 'Polecane playlisty';

  @override
  String get homeAllTimeTop => 'Top wszech czasów';

  @override
  String get homePeriod7d => '7 dni';

  @override
  String get homePeriod30d => '30 dni';

  @override
  String get homePeriod90d => '90 dni';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n odtworzenia',
      many: '$n odtworzeń',
      few: '$n odtworzenia',
      one: '$n odtworzenie',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Playlista pusta lub nieczytelna';

  @override
  String get homeExtractingArchive => 'Wypakowywanie archiwum…';

  @override
  String get homeArchiveEmpty => 'Brak odtwarzalnych plików w archiwum';

  @override
  String get homeNothingPlayable => 'Brak plików do odtworzenia w wyborze';

  @override
  String get homeAlbumLoadFailed => 'Nie udało się wczytać tego albumu';

  @override
  String get homeSongLoadFailed => 'Nie udało się wczytać tego utworu';

  @override
  String get navStats => 'Statystyki';

  @override
  String get navSettings => 'Ustawienia';

  @override
  String get playlistMoveUp => 'Przenieś do folderu nadrzędnego';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlisty',
      many: '$n playlist',
      few: '$n playlisty',
      one: '$n playlista',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n podfolderu',
      many: '$n podfolderów',
      few: '$n podfoldery',
      one: '$n podfolder',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Ten folder i cała jego zawartość zostaną trwale usunięte:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Ten folder zostanie usunięty.';

  @override
  String get playlistFolderRoot => 'Katalog główny';

  @override
  String get playlistMoveToFolder => 'Przenieś do folderu';

  @override
  String playlistDeleteTitle(String name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get playlistDeleteBody => 'Ta playlista zostanie trwale usunięta.';

  @override
  String get playlistRenameFolderTitle => 'Zmień nazwę folderu';

  @override
  String get playlistClearFavorites => 'Usuń wszystkie ulubione';

  @override
  String get playlistClearFavoritesTitle => 'Usunąć wszystkie ulubione?';

  @override
  String get playlistClearFavoritesBody =>
      'Stracisz wszystkie ulubione utwory. Tej operacji nie można cofnąć.';

  @override
  String get playlistRemoveFromLibrary => 'Usuń z biblioteki';

  @override
  String get playlistServerReadOnly => 'Playlista z serwera · tylko do odczytu';

  @override
  String get navAbout => 'O aplikacji';

  @override
  String get navMore => 'Więcej';

  @override
  String get shellAlbumQueuedAtEnd => 'Album dodany na koniec kolejki';

  @override
  String get shellAlbumQueuedNext => 'Album zostanie odtworzony jako następny';

  @override
  String get shellAddingToQueue => 'Dodawanie do kolejki…';

  @override
  String get shellAddingNext => 'Dodawanie jako następny…';

  @override
  String shellDownloadFailed(String error) {
    return 'Pobieranie nie powiodło się: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dodano $count utworu do kolejki',
      many: 'Dodano $count utworów do kolejki',
      few: 'Dodano $count utwory do kolejki',
      one: 'Dodano $count utwór do kolejki',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" dodano na koniec kolejki';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" zostanie odtworzony jako następny';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Pobieranie nie powiodło się: $title — przechodzę do następnego utworu';
  }

  @override
  String get shellNetworkUnavailable =>
      'Odtwarzanie zatrzymane: sieć wygląda na niedostępną.';

  @override
  String get statsTitle => 'Statystyki';

  @override
  String statsPeriodDays(int n) {
    return '$n dni';
  }

  @override
  String get statsPeriodThisYear => 'W tym roku';

  @override
  String get statsPeriodAll => 'Cały okres';

  @override
  String get statsByMonthOrYear => 'Wg miesiąca / roku…';

  @override
  String get statsByYear => 'Wg roku';

  @override
  String get statsByMonth => 'Wg miesiąca';

  @override
  String get statsPlaysLabel => 'Odtworzenia';

  @override
  String get statsTracksLabel => 'Utwory';

  @override
  String get statsArtistsLabel => 'Wykonawcy';

  @override
  String get statsAlbumsLabel => 'Albumy';

  @override
  String get statsListenTime => 'Czas słuchania';

  @override
  String get statsByCollection => 'Według kolekcji';

  @override
  String get statsByFormat => 'Według formatu';

  @override
  String get statsByEngine => 'Według silnika';

  @override
  String get statsPlaylistsLabel => 'Playlisty';

  @override
  String get statsLocalFilesSection => 'Pobrane pliki';

  @override
  String get statsFilesLabel => 'Pliki';

  @override
  String get statsSpaceLabel => 'Miejsce na dysku';

  @override
  String get statsNoPlaysInPeriod => 'Brak odtworzeń w tym okresie';

  @override
  String get statsNoPlays => 'Brak odtworzeń';

  @override
  String get statsTopTracks => 'Top utwory';

  @override
  String get statsTopAlbums => 'Top albumy';

  @override
  String get statsTopArtists => 'Top wykonawcy';

  @override
  String statsTopTracksIn(String period) {
    return 'Top utwory — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top albumy — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top wykonawcy — $period';
  }

  @override
  String get statsSeeAll => 'Zobacz wszystko';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n odtworzenia',
      many: '$n odtworzeń',
      few: '$n odtworzenia',
      one: '$n odtworzenie',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'maks. $n';
  }

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get commonCreate => 'Utwórz';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Usuń';

  @override
  String get commonRename => 'Zmień nazwę';

  @override
  String get commonSort => 'Sortuj';

  @override
  String get commonPlayAll => 'Odtwórz wszystko';

  @override
  String get sortName => 'Nazwa';

  @override
  String get sortTitle => 'Tytuł';

  @override
  String get sortArtist => 'Wykonawca';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Data dodania';

  @override
  String get commonClear => 'Wyczyść';

  @override
  String get sortRecentlyModified => 'Ostatnio zmodyfikowane';

  @override
  String get sortCreationDate => 'Data utworzenia';

  @override
  String get playlistNameHint => 'Nazwa';

  @override
  String get playlistNew => 'Nowa playlista';

  @override
  String get playlistNewFolder => 'Nowy folder';

  @override
  String get playlistNewTooltip => 'Nowa playlista / folder';

  @override
  String get playlistAddTo => 'Dodaj do playlisty';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Dodaj do $n playlisty',
      many: 'Dodaj do $n playlist',
      few: 'Dodaj do $n playlist',
      one: 'Dodaj do $n playlisty',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Wybierz playlistę';

  @override
  String get playlistFilterHint => 'Filtruj playlisty…';

  @override
  String get playlistSearchHint => 'Szukaj playlisty…';

  @override
  String get playlistNoMatch => 'Brak pasujących playlist';

  @override
  String get playlistNoneCreateHint =>
      'Brak playlist — utwórz jedną przyciskiem +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
      zero: 'Brak utworów',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Już dodane';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementu jest już w wybranych playlistach.',
      many: '$n elementów jest już w wybranych playlistach.',
      few: '$n elementy są już w wybranych playlistach.',
      one: '$n element jest już w wybranych playlistach.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Pomiń duplikaty';

  @override
  String get playlistAddAgain => 'Dodaj ponownie';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Dodano $n utworu',
      many: 'Dodano $n utworów',
      few: 'Dodano $n utwory',
      one: 'Dodano $n utwór',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m playlisty',
      many: '$m playlist',
      few: '$m playlist',
      one: '$n playlisty',
    );
    return '$_temp0 do $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Nie udało się dodać: $error';
  }

  @override
  String get playlistRenameTitle => 'Zmień nazwę playlisty';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Usunąć folder „$name”?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'Jego zawartość przejdzie o poziom wyżej.';

  @override
  String get playlistEmpty => 'Pusta playlista';

  @override
  String get trackOptionsAddToLibrary => 'Dodaj do biblioteki';

  @override
  String get trackOptionsRemoveFromLibrary => 'Usuń z biblioteki';

  @override
  String get trackOptionsAddedToLibrary => 'Utwór dodany do biblioteki';

  @override
  String get trackOptionsRemovedFromLibrary => 'Utwór usunięty z biblioteki';

  @override
  String get trackOptionsViewAlbum => 'Zobacz album';

  @override
  String get trackOptionsViewArtist => 'Zobacz wykonawcę';

  @override
  String get trackOptionsPlayNow => 'Odtwórz teraz';

  @override
  String get trackOptionsPlayNext => 'Odtwórz jako następny';

  @override
  String get trackOptionsAddToQueueEnd => 'Dodaj na koniec kolejki';

  @override
  String get trackOptionsPlayLast => 'Odtwórz na końcu';

  @override
  String get trackOptionsDeleteDownload => 'Usuń pobrany plik';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Usunąć ten pobrany plik?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Plik i jego lokalne wpisy (historia, utwory) zostaną usunięte.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Pobrany plik usunięty';

  @override
  String get trackOptionsAddToFavorites => 'Dodaj do ulubionych';

  @override
  String get trackOptionsRemoveFromFavorites => 'Usuń z ulubionych';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Album dodany do ulubionych';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album usunięty z ulubionych';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album niepobrany — nie ma czego usuwać';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Usunąć pobrany album?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Folder i wszystkie jego lokalne wpisy (utwory, historia) zostaną usunięte.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Album usunięty z pamięci lokalnej';

  @override
  String get trackOptionsRedownloadAlbum => 'Pobierz album ponownie';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Nadpisuje pliki ORAZ wpisy lokalne';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Usuń pliki albumu';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Pobrany folder + wpisy lokalne (historia)';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsGeneral => 'Ogólne';

  @override
  String get settingsGeneralSubtitle => 'Motyw';

  @override
  String get settingsVisualisation => 'Wizualizacja';

  @override
  String get settingsVisualisationSubtitle => 'Oscyloskopy, okładka w tle';

  @override
  String get settingsPlayback => 'Odtwarzanie';

  @override
  String get settingsPlaybackSubtitle => 'Pętle, wyciszanie, cisza';

  @override
  String get settingsEngines => 'Silniki';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Dane';

  @override
  String get settingsDataSubtitle => 'Identyfikator, historia, reset';

  @override
  String get settingsBackupExport => 'Eksportuj kopię zapasową';

  @override
  String get settingsBackupExportSubtitle =>
      'Zapisz bibliotekę, playlisty i ustawienia do pliku';

  @override
  String get settingsBackupImport => 'Importuj kopię zapasową';

  @override
  String get settingsBackupImportSubtitle =>
      'Przywróć dane z pliku kopii zapasowej';

  @override
  String get settingsBackupExportFailed =>
      'Eksport kopii zapasowej nie powiódł się';

  @override
  String get settingsBackupImportConfirmTitle => 'Zaimportować kopię zapasową?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Zastąpi to bibliotekę, playlisty i ustawienia na tym urządzeniu. Pobrane pliki zostaną zachowane.';

  @override
  String get settingsBackupImportConfirm => 'Importuj';

  @override
  String get settingsBackupImportedTitle => 'Zaimportowano kopię zapasową';

  @override
  String get settingsBackupImportedBody =>
      'Twoje dane zostały przywrócone. Uruchom aplikację ponownie, aby zastosować wszystko.';

  @override
  String get settingsBackupTooNew =>
      'Ta kopia zapasowa została utworzona przez nowszą wersję aplikacji';

  @override
  String get settingsBackupInvalid =>
      'To nie jest prawidłowa kopia zapasowa Rewamp';

  @override
  String get settingsBackupImportFailed =>
      'Import kopii zapasowej nie powiódł się';

  @override
  String get settingsAbout => 'O aplikacji';

  @override
  String get settingsAboutSubtitle => 'Podziękowania i licencje';

  @override
  String get settingsCreditsSubtitle => 'Biblioteki, dane i komponenty';

  @override
  String get settingsSupport => 'Kontakt i pomoc';

  @override
  String get settingsSupportSubtitle => 'Napisz do nas, strona';

  @override
  String get settingsSupportEmail => 'Wyślij e-mail';

  @override
  String get settingsSupportEmailSubtitle => 'Pytanie, błąd lub sugestia';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — pomoc';

  @override
  String get settingsSupportEmailIntro =>
      'Opisz powyżej swoje pytanie, błąd lub sugestię. Informacje poniżej pomagają nam Ci pomóc.';

  @override
  String get settingsSupportWebsite => 'Strona internetowa';

  @override
  String get settingsDonation => 'Wesprzyj Rewamp';

  @override
  String get settingsDonationSubtitle => 'Napiwek, jeśli masz ochotę';

  @override
  String get settingsDonationBlurb =>
      'Rewamp jest darmowy i bez reklam — to projekt z pasji poświęcony zachowaniu kultury demosceny i retro. Darowizny pomagają finansować rozwój aplikacji i pokrywać koszty hostingu bazy danych. Bez zobowiązań: jeśli aplikacja sprawia Ci radość, drobny gest zawsze mile widziany.';

  @override
  String get settingsDonationFloppy => 'Dyskietka';

  @override
  String get settingsDonationCartridge => 'Kartridż';

  @override
  String get settingsDonationBox => 'Gra w pudełku';

  @override
  String get settingsDonationCustom => 'Wybierz kwotę';

  @override
  String get settingsCancel => 'Anuluj';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Usuń';

  @override
  String get settingsReset => 'Zresetuj';

  @override
  String get settingsRenew => 'Odnów';

  @override
  String get settingsOff => 'Wył.';

  @override
  String get settingsOn => 'Wł.';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Nieskończona';

  @override
  String get settingsDefault => 'Domyślne';

  @override
  String get settingsCoreNoScope => 'bez oscyloskopu';

  @override
  String get settingsNone => 'Brak';

  @override
  String get settingsLevelLow => 'Niska';

  @override
  String get settingsLevelHigh => 'Wysoka';

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
  String get settingsTheme => 'Motyw';

  @override
  String get settingsThemeLight => 'Jasny';

  @override
  String get settingsThemeDark => 'Ciemny';

  @override
  String get settingsArtworkTintTitle => 'Zabarw odtwarzacz kolorem okładki';

  @override
  String get settingsArtworkTintSubtitle =>
      'Odtwarzacz przejmuje dominujący kolor okładki';

  @override
  String get settingsGlassEffectTitle => 'Efekt liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Soczewka i rozmycie dolnych pasków — wyłącz na wolnych urządzeniach';

  @override
  String get settingsResetSection => 'Zresetuj tę sekcję';

  @override
  String get settingsResetEngine => 'Zresetuj ten silnik';

  @override
  String get settingsResetChoices => 'Zresetuj te ustawienia';

  @override
  String get settingsResetToDefault => 'Wartość domyślna';

  @override
  String get settingsStartInVizTitle => 'Uruchamiaj w trybie wizualizacji';

  @override
  String get settingsStartInVizSubtitle =>
      'Odtwarzacz otwiera się na oscyloskopach zamiast na okładce';

  @override
  String get settingsVoiceGridTitle => 'Siatka oscyloskopu głosów';

  @override
  String get settingsVoiceGridSubtitle =>
      'Pokazuj krawędzie oddzielające poszczególne głosy';

  @override
  String get settingsKeepAwakeTitle => 'Nie wygaszaj ekranu';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Gdy wizualizacja jest widoczna, ekran nie przygasa ani się nie blokuje';

  @override
  String get settingsVoiceNamesTitle => 'Nazwy głosów';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Pokazuj nazwę każdego głosu w jego ramce';

  @override
  String get settingsLineThickness => 'Grubość linii';

  @override
  String get settingsScopeVoiceColor => 'Oscyloskop głosów';

  @override
  String get settingsStereoColors => 'Stereo: kolory';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo lewy';

  @override
  String get settingsStereoRightColor => 'Stereo prawy';

  @override
  String get settingsNotePalette => 'Paleta kolorów';

  @override
  String get settingsNoteBoxStyle => 'Styl bloków';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'Wszystkie wizualizacje';

  @override
  String get settingsVizScopes => 'Oscyloskopy (stereo i na głos)';

  @override
  String get settingsVizFrameRate => 'Liczba klatek';

  @override
  String get settingsVizFrameRateScreen => 'Ekran';

  @override
  String settingsValueFps(int value) {
    return '$value kl./s';
  }

  @override
  String get settingsCrtSpeed => 'Intensywność / szybkość';

  @override
  String get settingsArtworkOpacity => 'Krycie okładki w tle';

  @override
  String get settingsProjectMTitle => 'Ustawienia projectM';

  @override
  String get settingsProjectMSubtitle => 'Presets, przejścia, jakość, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Powiadomienia o zmianie utworu';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Powiadomienie systemowe z tytułem nowego utworu';

  @override
  String get settingsSilenceDetection => 'Wykrywanie ciszy';

  @override
  String get settingsCrossfade => 'Płynne przejście';

  @override
  String get localActionPlay => 'Odtwórz pliki lub folder';

  @override
  String get localActionImport => 'Importuj pliki lub folder';

  @override
  String localOpsImporting(String name) {
    return 'Importowanie $name…';
  }

  @override
  String get localOpsImportingSelection => 'Importowanie wybranych plików…';

  @override
  String localOpsDeleting(String name) {
    return 'Usuwanie $name…';
  }

  @override
  String get localOpsPhaseCopying => 'kopiowanie';

  @override
  String get localOpsPhaseExtracting => 'rozpakowywanie';

  @override
  String get localOpsPhaseRegistering => 'dodawanie do biblioteki';

  @override
  String get localOpsPhaseDeleting => 'usuwanie plików';

  @override
  String get localImportFiles => 'Importuj pliki';

  @override
  String get storageLocalImports => 'Importy lokalne';

  @override
  String get settingsVgmJapaneseTags => 'Japońskie tagi (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'Preferuje japońskie pola (tytuł, gra, artysta) tagów VGM, gdy istnieją.';

  @override
  String get localImportFolder => 'Importuj folder';

  @override
  String get localLibraryTitle => 'Na tym urządzeniu';

  @override
  String get libraryOnAnotherDevice => 'Na innym urządzeniu';

  @override
  String get localLibraryEmpty =>
      'Brak lokalnych importów. Użyj „Importuj pliki” lub „Importuj folder” na ekranie głównym.';

  @override
  String queueLimitReached(int count) {
    return 'Kolejka ograniczona do pierwszych $count utworów';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return 'Usunąć „$name”? Plik i pliki towarzyszące (okładka…) zostaną skasowane.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunąć folder „$name” i $count utworu?',
      many: 'Usunąć folder „$name” i $count utworów?',
      few: 'Usunąć folder „$name” i $count utwory?',
      one: 'Usunąć folder „$name” i $count utwór?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return 'Zaimportowano do biblioteki: $count';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return 'Zaimportowano utwory: $tracks — albumy: $albums';
  }

  @override
  String localImportFailed(String error) {
    return 'Import nie powiódł się: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'Miesza koniec każdego utworu z początkiem następnego. Przy 0 odtwarzanie pozostaje bez przerw.';

  @override
  String get settingsMinSubsongSection => 'Zbyt krótkie podutwory';

  @override
  String get settingsMinSubsongTitle => 'Minimalny czas trwania';

  @override
  String get settingsMinSubsongHelp =>
      'Krótsze podutwory nie trafiają na listę ani do kolejki — plik z gry często zawiera więcej efektów dźwiękowych niż muzyki. Przy 0 nic nie jest pomijane; nieznany czas trwania nigdy nie uchodzi za krótki.';

  @override
  String get localNewFolder => 'Nowy folder';

  @override
  String get localFolderName => 'Nazwa folderu';

  @override
  String get localRename => 'Zmień nazwę';

  @override
  String get localMoveTo => 'Przenieś do…';

  @override
  String get localMove => 'Przenieś';

  @override
  String get localMoveNothing => 'Nic nie przeniesiono';

  @override
  String get localNameInvalid => 'Nieprawidłowa nazwa';

  @override
  String get localNameTaken => 'Ta nazwa jest już zajęta';

  @override
  String get localMoveIntoItself =>
      'Nie można przenieść folderu do niego samego';

  @override
  String get localManageFailed => 'Operacja nie powiodła się';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Nie trafia do kolejki: poniżej $seconds s (Ustawienia → Odtwarzanie)';
  }

  @override
  String get settingsQueuePrefetchSection => 'Pobieranie kolejki';

  @override
  String get settingsQueuePrefetchTitle => 'Pobierz całą kolejkę';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'Po jednym pliku; następny brakujący utwór startuje, gdy poprzedni się pobierze. Wyłączone: tylko następny utwór.';

  @override
  String get settingsCdRipDeclickSection => 'Ripy CD';

  @override
  String get settingsCdRipDeclickTitle => 'Usuwaj trzaski na początku utworu';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'Wadliwe ripy CD (mp3, ape, ogg, flac…) często zaczynają się kilkoma uszkodzonymi próbkami. Są naprawiane, aż zagra 200 ms prawdziwej muzyki; potem filtr się wyłącza.';

  @override
  String get settingsSilenceSkipTitle =>
      'Przejdź do następnego utworu przy ciszy';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Automatycznie przechodzi dalej, gdy na wyjściu panuje cisza';

  @override
  String get settingsSilenceDelay => 'Opóźnienie ciszy';

  @override
  String get settingsDefaultDuration => 'Domyślny czas trwania';

  @override
  String get settingsDefaultDurationHelp =>
      'Używany, gdy utwór nie podaje znanego czasu trwania (brak tagu, brak metadanych z serwera) — zapobiega odtwarzaniu lub zapętlaniu w nieskończoność. Nigdy nie dotyczy utworów Amiga (UADE), które mają własną bazę czasów trwania.';

  @override
  String get settingsForcedLoopHeader => 'Wymuszona pętla / wyciszenie';

  @override
  String get settingsForcedLoopHelp =>
      'Niektóre formaty zapętlają konkretny fragment (VGM, moduły tracker…), inne nie. „Nieskończona” ignoruje naturalny koniec utworu.';

  @override
  String get settingsForceLoopCount => 'Wymuś liczbę pętli';

  @override
  String get settingsLoopCount => 'Liczba pętli';

  @override
  String get settingsForceFadeout => 'Wymuś wyciszenie';

  @override
  String get settingsFadeoutDuration => 'Czas wyciszenia';

  @override
  String get settingsResetEnginesTitle => 'Zresetować ustawienia silników?';

  @override
  String get settingsResetEnginesBody =>
      'Wszystkie ustawienia silników wrócą do wartości domyślnych.';

  @override
  String get settingsResetDefaultsTitle => 'Przywróć wartości domyślne';

  @override
  String get settingsResetDefaultsSubtitle => 'Wszystkie silniki';

  @override
  String get settingsDefaultDecoders => 'Domyślne dekodery';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formaty, które potrafi odtworzyć kilka silników';

  @override
  String get settingsDecodersHelp =>
      'Niektóre formaty może odtwarzać kilka silników. Wybierz, którego użyć domyślnie — wszystkie pozostałe formaty są kierowane automatycznie.';

  @override
  String get settingsDecoderAmigaTrackers => 'Trackery Amiga (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackery — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Moduły, których libopenmpt nie odczytuje — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — korektor, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — jakość, filtry, opcje poszczególnych układów';

  @override
  String get settingsEngineGbsSubtitle =>
      'Game Boy / GBS — filtr górnoprzepustowy';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — używany SoundFont';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolacja, filtr dolnoprzepustowy, echo';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorama, słuchawki, wzmocnienie, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — zegar, model, filtry ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — tryb harmoniczny stereo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, pogłos';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — rdzenie YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Głośność główna';

  @override
  String get settingsAmplification => 'Wzmocnienie';

  @override
  String get settingsAmigaFilter => 'Filtr Amiga';

  @override
  String get settingsInterpolation => 'Interpolacja';

  @override
  String get settingsPolyphony => 'Polifonia';

  @override
  String get settingsReverb => 'Pogłos';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'Ten plik MIDI napisano dla Rolanda MT-32. Bez jego ROM-ów gra na SoundFoncie, z instrumentami przełożonymi na General MIDI — zaimportuj ROM-y w Ustawienia › Silniki › Munt.';

  @override
  String get settingsMidiMt32ToGm => 'Dostosuj pliki MT-32';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'MIDI napisane dla Rolanda MT-32 numeruje programy według listy MT-32: po przełożeniu na najbliższy odpowiednik General MIDI brzmi wiarygodnie zamiast przypadkowo.';

  @override
  String get settingsInterpNone => 'Brak';

  @override
  String get settingsInterpLinear => 'Liniowa';

  @override
  String get settingsInterpCubic => 'Sześcienna';

  @override
  String get settingsInterpSinc => 'Sinc (najlepsza)';

  @override
  String get settingsStereoSeparation => 'Separacja stereo';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Kończy utwór, gdy silnik wykryje długą ciszę';

  @override
  String get settingsStereoDepth => 'Głębia stereo';

  @override
  String get settingsEqualizer => 'Korektor';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — bez wpływu na SPC';

  @override
  String get settingsBass => 'Niskie tony';

  @override
  String get settingsTreble => 'Wysokie tony';

  @override
  String get settingsAppliedLive =>
      'Stosowane natychmiast, nawet podczas odtwarzania.';

  @override
  String get settingsAppliedNextTrack =>
      'Stosowane przy następnym wczytanym utworze.';

  @override
  String get settingsSidEmulation => 'Emulacja';

  @override
  String get settingsSidResidfp => 'ReSIDfp (dokładna)';

  @override
  String get settingsSidLite => 'SIDLite (szybka)';

  @override
  String get settingsSidSampling => 'Próbkowanie';

  @override
  String get settingsSidSamplingInterp => 'Interpolacja (szybka)';

  @override
  String get settingsSidSamplingResample => 'Resample (najlepsze)';

  @override
  String get settingsSidClock => 'Zegar';

  @override
  String get settingsSidModel => 'Model SID';

  @override
  String get settingsSidFilter => 'Filtr SID';

  @override
  String get settingsSidForceSecond => 'Wymuś 2. SID';

  @override
  String get settingsSidSecondSubtitle => 'Utwory stereo 2SID';

  @override
  String get settingsSidSecondAddr => 'Adres 2. SID';

  @override
  String get settingsSidForceThird => 'Wymuś 3. SID';

  @override
  String get settingsSidThirdAddr => 'Adres 3. SID';

  @override
  String get settingsSidAutoFilter => 'Automatyczny zakres filtra 6581';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Wartość zalecana dla autora utworu (tabele sidplayfp)';

  @override
  String get settingsSid6581Range => 'Zakres filtra 6581';

  @override
  String get settingsSid6581Curve => 'Krzywa filtra 6581';

  @override
  String get settingsSid8580Curve => 'Krzywa filtra 8580';

  @override
  String get settingsSidNote =>
      'Filtr SID i krzywe działają na żywo; emulacja/próbkowanie/zegar/model/2. i 3. SID zadziałają przy następnym utworze.';

  @override
  String get settingsAudioOutput => 'Wyjście audio';

  @override
  String get settingsAdplugNote =>
      'Surround: dwa lekko rozstrojone układy OPL. Stosowane przy następnym utworze.';

  @override
  String get settingsHeSpuMain => 'Głosy główne (SPU)';

  @override
  String get settingsHeSpuReverb => 'Pogłos (SPU)';

  @override
  String get settingsNsfQuality => 'Jakość (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Filtr dolnoprzepustowy';

  @override
  String get settingsHighpassFilter => 'Filtr górnoprzepustowy';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsNsfRegionNtscForced => 'Wymuszony NTSC';

  @override
  String get settingsNsfRegionPalForced => 'Wymuszony PAL';

  @override
  String get settingsNsfRegionDendyForced => 'Wymuszony Dendy';

  @override
  String get settingsNsfForceIrq => 'Wymuś IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — kanały impulsowe (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — trójkąt / szum / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Wyłącz wyciszenie przy resecie';

  @override
  String get settingsNsfPhaseRefresh => 'Odświeżaj fazę';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Resetuj fazę przy zapisie okresu';

  @override
  String get settingsNsfNonlinearMixer => 'Mieszanie nieliniowe';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'Prawdziwe mieszanie 2A03 (w przeciwnym razie liniowe)';

  @override
  String get settingsNsfDutySwap => 'Zamień duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Kolejność duty 25 % / 50 %';

  @override
  String get settingsNsfNegateSweep => 'Ujemny sweep przy inicjalizacji';

  @override
  String get settingsNsfEnable4011 => 'Rejestr \$4011 włączony';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Bezpośrednie wyjście DAC (oryginalne kliknięcia)';

  @override
  String get settingsNsfPeriodicNoise => 'Szum okresowy';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => 'Tryb krótki generatora szumu';

  @override
  String get settingsNsfDpcmAntiClick => 'Anti-click DPCM';

  @override
  String get settingsNsfRandomizeNoise => 'Losowy szum przy inicjalizacji';

  @override
  String get settingsNsfTriangleMute => 'Wycisz trójkąt';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Wycisza trójkąt przy okresach ultradźwiękowych';

  @override
  String get settingsNsfRandomizeTri => 'Losowy trójkąt przy inicjalizacji';

  @override
  String get settingsNsfDpcmReverse => 'Odwrócony DPCM';

  @override
  String get settingsNsfN163Serial => 'Multipleksowanie szeregowe';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Prawdziwy buczek N163 w utworach wielogłosowych';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Faza tylko do odczytu';

  @override
  String get settingsNsfN163LimitWavelength => 'Ogranicz długość fali';

  @override
  String get settingsNsfFdsCutoff =>
      'Częstotliwość odcięcia filtra dolnoprzepustowego';

  @override
  String get settingsNsfFds4085Reset => 'Reset \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Ochrona przed zapisem';

  @override
  String get settingsNsfVrc7Patch => 'Zestaw patchy';

  @override
  String get settingsNsfVrc7Opll => 'Tryb OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Emuluj YM2413 zamiast VRC7';

  @override
  String get settingsGbsHpFilter => 'Filtr górnoprzepustowy (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klasyczny GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Echo';

  @override
  String get settingsUadePostfx => 'Przetwarzanie końcowe';

  @override
  String get settingsUadePostfxSubtitle =>
      'Włącza łańcuch efektów (wymagany dla wszystkiego poniżej)';

  @override
  String get settingsUadePan => 'Panorama (separacja stereo)';

  @override
  String get settingsUadePanValue => 'Wartość panoramy';

  @override
  String get settingsUadeHeadphones => 'Słuchawki';

  @override
  String get settingsUadeLed => 'LED (filtr Paula)';

  @override
  String get settingsUadeLedAuto => 'Auto (wg utworu)';

  @override
  String get settingsUadeLedOn => 'Wymuszony ON';

  @override
  String get settingsUadeLedOff => 'Wymuszony OFF';

  @override
  String get settingsUadeFilterType => 'Typ filtra';

  @override
  String get settingsUadeGain => 'Wzmocnienie';

  @override
  String get settingsUadeGainValue => 'Wartość wzmocnienia';

  @override
  String get settingsSoundfontLoading => 'Wczytywanie katalogu…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Katalog niedostępny ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Pobieranie nie powiodło się: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importuj SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Wybierz plik .sf2 na tym urządzeniu';

  @override
  String get settingsSoundfontImported => 'Zaimportowana';

  @override
  String get settingsSoundfontInvalid => 'Ten plik nie jest SoundFontem (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Import nie powiódł się — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Usuń plik';

  @override
  String get settingsCreditsHeader => 'Podziękowania i licencje';

  @override
  String get settingsRightsNotice =>
      'Rewamp jest odtwarzaczem: nie hostuje żadnych plików ani nie rozpowszechnia muzyki. Utwory pochodzą z internetowych archiwów zachowania dziedzictwa i pozostają własnością podmiotów praw autorskich. To Ty odpowiadasz za sprawdzenie, czy ich odsłuchiwanie, pobieranie i przechowywanie jest zgodne z obowiązującymi prawami i przepisami Twojego kraju.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count obsługiwanego formatu',
      many: '$count obsługiwanych formatów',
      few: '$count obsługiwane formaty',
      one: '$count obsługiwany format',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rozłożone na $count silnika odtwarzania — zobacz szczegóły',
      many: 'Rozłożone na $count silników odtwarzania — zobacz szczegóły',
      few: 'Rozłożone na $count silniki odtwarzania — zobacz szczegóły',
      one: 'Obsługiwane przez $count silnik odtwarzania — zobacz szczegóły',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Czasy trwania i metadane Amiga';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb autorstwa Mattiego Tiainena (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Dane i okładki C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadane i grafiki gier C64.';

  @override
  String get settingsFt2FontTitle => 'Czcionka FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'Styl FastTracker II wizualizera patternów używa bitmapowej czcionki FT2 z ft2-clone autorstwa 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return 'Skopiowano $url';
  }

  @override
  String get settingsOpenLink => 'Otwórz link';

  @override
  String get settingsEnginesHeader => 'Silniki odtwarzania';

  @override
  String get settingsComponentsHeader => 'Pozostałe komponenty';

  @override
  String get settingsResetAll => 'Zresetuj wszystkie ustawienia';

  @override
  String get settingsResetAllSubtitle =>
      'Ogólne, Wizualizacja, Odtwarzanie, Silniki — bez biblioteki';

  @override
  String get settingsResetAllTitle => 'Zresetować wszystkie ustawienia?';

  @override
  String get settingsResetAllBody =>
      'Ogólne, Wizualizacja, Odtwarzanie i wszystkie silniki wrócą do wartości domyślnych. Twoja biblioteka i historia pozostaną nietknięte.';

  @override
  String get settingsRenewUserId => 'Odnów anonimowy identyfikator';

  @override
  String get settingsRenewUserIdTitle => 'Odnowić anonimowy identyfikator?';

  @override
  String get settingsRenewUserIdBody =>
      'Zostanie utworzony nowy anonimowy identyfikator do statystyk serwera.\n\nStary nie będzie już używany. Twoja lokalna historia i ulubione pozostaną bez zmian.';

  @override
  String get settingsRenewUserIdFailed => 'Niepowodzenie — serwer nieosiągalny';

  @override
  String settingsNewUserId(String id) {
    return 'Nowy identyfikator: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Brak zarejestrowanego identyfikatora';

  @override
  String get settingsCleanDb => 'Wyczyść lokalną bazę danych';

  @override
  String get settingsCleanDbSubtitle =>
      'Usuwa wpisy, których plik już nie istnieje (usunięte pobrania, stare błędy)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto $count osieroconego wpisu',
      many: 'Usunięto $count osieroconych wpisów',
      few: 'Usunięto $count osierocone wpisy',
      one: 'Usunięto $count osierocony wpis',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'Lokalna baza danych jest czysta — nie ma czego usuwać';

  @override
  String get settingsClearCache =>
      'Wyczyść pamięć podręczną (okładki i metadane)';

  @override
  String get settingsClearCacheSubtitle =>
      'Usuwa okładki z pamięci podręcznej i pobrane metadane (STIL, czasy trwania) — zostaną pobrane ponownie przy następnym odtwarzaniu';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pamięć podręczna wyczyszczona ($count okładki)',
      many: 'Pamięć podręczna wyczyszczona ($count okładek)',
      few: 'Pamięć podręczna wyczyszczona ($count okładki)',
      one: 'Pamięć podręczna wyczyszczona ($count okładka)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Pamięć';

  @override
  String get storageSubtitle => 'Co aplikacja trzyma na dysku, z usuwaniem';

  @override
  String get storageDownloads => 'Pobrane';

  @override
  String get storageArtworkCache => 'Pamięć okładek';

  @override
  String get storageSoundfonts => 'SoundFonty';

  @override
  String get storagePresets => 'Presety wizualizera';

  @override
  String get storageOpenedFiles => 'Otwarte pliki';

  @override
  String get storageOpenedEmpty =>
      'Pliki otwarte z zewnątrz (udostępnianie, „Otwórz w”, wybieranie na telefonie) są tu kopiowane.';

  @override
  String get storageInUse => 'na playliście lub w bibliotece';

  @override
  String get storageDeleteAll => 'Usuń wszystko';

  @override
  String get storageClear => 'Wyczyść';

  @override
  String get storageDeleteSelection => 'Usuń zaznaczone';

  @override
  String get storageSelectAll => 'Zaznacz wszystko';

  @override
  String get storageFilterHint => 'Filtruj po nazwie';

  @override
  String get storageNoMatch => 'Żaden plik nie pasuje do tego filtra.';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaznaczonego',
      many: '$count zaznaczonych',
      few: '$count zaznaczone',
      one: '$count zaznaczony',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunąć $count pliku?',
      many: 'Usunąć $count plików?',
      few: 'Usunąć $count pliki?',
      one: 'Usunąć $count plik?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Usunąć $count plików? $inUse są używane przez playlistę lub bibliotekę — te wpisy stracą swój plik.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Usunąć wszystkie pobrane pliki i ich wpisy w bibliotece? Ulubione i playlisty zachowają wpisy, ale pliki trzeba będzie pobrać ponownie.';

  @override
  String get storageSoundfontsClearBody =>
      'Usunąć wszystkie SoundFonty, także zaimportowane? Katalogowe pobiorą się ponownie; zaimportowane przepadną.';

  @override
  String get storagePresetsClearBody =>
      'Usunąć pobrane paczki presetów i zaimportowane presety? Wbudowane presety zostają; paczki pobiorą się ponownie, zaimportowane przepadną.';

  @override
  String get storageOpenedDeleteAllTitle => 'Usuń otwarte pliki';

  @override
  String get storageInUseDeleteTitle => 'Plik w użyciu';

  @override
  String get storageInUseDeleteBody =>
      'Playlista lub biblioteka nadal wskazuje na ten plik. Po usunięciu te wpisy zostaną bez pliku.';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pliku — $size',
      many: '$count plików — $size',
      few: '$count pliki — $size',
      one: '$count plik — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pliku — $size · zarządzanie z albumów i utworów',
      many: '$count plików — $size · zarządzanie z albumów i utworów',
      few: '$count pliki — $size · zarządzanie z albumów i utworów',
      one: '$count plik — $size · zarządzanie z albumów i utworów',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Usunąć $count pliku? Pliki używane przez playlistę lub bibliotekę zostaną zachowane.',
      many:
          'Usunąć $count plików? Pliki używane przez playlistę lub bibliotekę zostaną zachowane.',
      few:
          'Usunąć $count pliki? Pliki używane przez playlistę lub bibliotekę zostaną zachowane.',
      one:
          'Usunąć $count plik? Pliki używane przez playlistę lub bibliotekę zostaną zachowane.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Zresetuj statystyki';

  @override
  String get settingsResetStatsSubtitle =>
      'Usuwa historię słuchania i liczniki odtworzeń';

  @override
  String get settingsClearStatsTitle => 'Zresetować statystyki?';

  @override
  String get settingsClearStatsBody =>
      'Trwale usunięte zostaną:\n• cała historia słuchania\n• liczniki odtworzeń\n\nTwoje ulubione i biblioteka pozostaną bez zmian.';

  @override
  String get settingsStatsCleared => 'Statystyki usunięte';

  @override
  String get settingsResetDatabase => 'Zresetuj bazę danych';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Usuwa wszystko: historię, ulubione, playlisty, pamięć podręczną';

  @override
  String get settingsResetDbTitle => 'Zresetować bazę danych?';

  @override
  String get settingsCleanLocalTitle => 'Wyczyść niedziałające wpisy lokalne';

  @override
  String get cleanStageScan => 'Analizowanie wpisów…';

  @override
  String get cleanStageSync => 'Synchronizacja z kontem…';

  @override
  String get cleanStagePurge => 'Usuwanie z konta…';

  @override
  String get cleanStageDelete => 'Usuwanie lokalne…';

  @override
  String get settingsCleanLocalBody =>
      'Wpisy biblioteki wskazujące plik, którego nie ma już na tym urządzeniu. Zostaną też usunięte z konta, a więc z innych urządzeń.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto $count wpisu',
      many: 'Usunięto $count wpisów',
      few: 'Usunięto $count wpisy',
      one: 'Usunięto $count wpis',
      zero: 'Nie ma czego czyścić',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'Trwale usunięte zostaną:\n• cała historia słuchania\n• wszystkie liczniki\n• wszystkie ulubione\n• wszystkie playlisty\n• wszystkie metadane z pamięci podręcznej\n\nTwoje pliki audio nie zostaną usunięte.';

  @override
  String get settingsDbReset => 'Baza danych zresetowana';

  @override
  String get settingsDeleteDownloads => 'Usuń pobrane pliki';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Usuwa wszystkie pliki z folderu online (utwory, okładki)';

  @override
  String get settingsCleanAll => 'Wyczyść lokalną bazę i pamięć podręczną';

  @override
  String get settingsCleanAllSubtitle =>
      'Usuwa wpisy bez pliku, wpisy biblioteki wskazujące pliki na innym urządzeniu oraz opróżnia pamięć podręczną okładek i metadanych';

  @override
  String get settingsCleanAllConfirmBody =>
      'Wpisy biblioteki wskazujące pliki na innym urządzeniu zostaną usunięte także z konta, a więc z pozostałych urządzeń. Okładki i metadane zostaną pobrane ponownie przy następnym odtworzeniu.';

  @override
  String get settingsDataAdvanced => 'Zaawansowane';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Każdy krok czyszczenia osobno, pamięć podręczna i resetowanie';

  @override
  String get settingsDataGroupDb => 'Baza danych';

  @override
  String get settingsDataGroupCache => 'Pamięć podręczna';

  @override
  String get settingsDataGroupReset => 'Resetowanie';

  @override
  String get settingsDeleteDownloadsTitle => 'Usunąć pobrane pliki?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Wszystkie pobrane pliki (utwory, albumy, okładki) zostaną trwale usunięte z folderu online.\n\nWpisy w bazie danych pozostaną, ale będą wskazywać na nieistniejące pliki.';

  @override
  String get settingsDownloadsDeleted => 'Pobrane pliki usunięte';

  @override
  String get settingsColor => 'Kolor';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Losowy następny preset';

  @override
  String get settingsPmRandomNextSubtitle => 'Wył.: presets w kolejności';

  @override
  String get settingsPmLockPreset => 'Zablokuj preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Bez automatycznej zmiany';

  @override
  String get settingsPmPresetDuration => 'Czas między presetami';

  @override
  String get settingsPmTransitions => 'Przejścia';

  @override
  String get settingsPmBlend => 'Przejście z płynnym mieszaniem';

  @override
  String get settingsPmBlendSubtitle => 'Wył.: natychmiastowa zmiana presetu';

  @override
  String get settingsPmTransitionStyle => 'Styl przejścia';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Wzór używany przez przenikanie';

  @override
  String get settingsPmTransitionRandom => 'Losowo';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Zmiana presetu zsynchronizowana z bitem';

  @override
  String get settingsPmHardcutTime => 'Hardcut: czas minimalny';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: czułość';

  @override
  String get settingsPmRendering => 'Renderowanie';

  @override
  String get settingsPmQuality => 'Jakość';

  @override
  String get settingsPmQualitySubtitle =>
      'Rozdzielczość renderowania (Max = rozdzielczość natywna)';

  @override
  String get settingsPmBeatSensitivity => 'Czułość na bit';

  @override
  String get settingsPmAspectRatio => 'Zachowaj proporcje obrazu';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'Dla shaderów, które to obsługują';

  @override
  String get settingsPmPermissive => 'Tryb permisywny';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Wczytuj pliki .milk z błędami w skryptach';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountSubtitle => 'Zapisz i synchronizuj bibliotekę';

  @override
  String get accountAnonymous => 'Konto anonimowe';

  @override
  String get accountAnonymousExplain =>
      'Ulubione i historia są zapisane na serwerze, ale dostęp do nich ma tylko to urządzenie. Dodaj adres e-mail, aby odzyskać je gdzie indziej.';

  @override
  String get accountEmailAttached =>
      'Adres potwierdzony — to konto można przywrócić';

  @override
  String get accountEmailPending => 'Adres jeszcze niepotwierdzony';

  @override
  String get accountInsecureStorage =>
      'Bezpieczny magazyn tego urządzenia jest niedostępny: identyfikator konta zapisano bez szyfrowania.';

  @override
  String get accountSaveCta => 'Zapisz moje konto';

  @override
  String get accountStatSongs => 'Ulubione utwory';

  @override
  String get accountStatAlbums => 'Ulubione albumy';

  @override
  String get accountStatPlays => 'Odtworzenia';

  @override
  String get accountCreatedLabel => 'Utworzono';

  @override
  String get accountSignOut => 'Wyloguj się';

  @override
  String get accountRevoke => 'Wyloguj wszędzie';

  @override
  String get accountRevokeSubtitle => 'Wylogowuje wszystkie inne urządzenia';

  @override
  String get accountRevokeBody =>
      'Wszystkie inne urządzenia zostaną wylogowane. To pozostanie zalogowane.';

  @override
  String get accountRevokeDone => 'Inne urządzenia wylogowane';

  @override
  String get accountDelete => 'Usuń moje konto';

  @override
  String get accountDeleteSubtitle =>
      'Kasuje konto i jego dane na serwerze. Nieodwracalne.';

  @override
  String accountDeleteBody(int items, int lists) {
    return 'Z serwera zostanie usuniętych $items ulubionych i $lists playlist. Tego nie można cofnąć.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Twoje pobrania i biblioteka na tym urządzeniu pozostają nienaruszone.';

  @override
  String get accountDeleteDone => 'Konto usunięte';

  @override
  String get accountSignOutSubtitle =>
      'To urządzenie zaczyna od nowego, pustego konta';

  @override
  String get accountSignOutTitle => 'Wylogować się?';

  @override
  String accountSignOutBody(String email) {
    return 'Możesz wrócić na to konto za pomocą kodu wysłanego na $email.';
  }

  @override
  String get accountSignedOut => 'Wylogowano';

  @override
  String get accountNoSignOut => 'Wylogowanie niedostępne';

  @override
  String get accountNoSignOutSubtitle =>
      'Bez adresu e-mail to konto zostałoby utracone na zawsze.';

  @override
  String get accountDetach => 'Odłącz adres';

  @override
  String get accountDetachSubtitle =>
      'Konto znów staje się anonimowe, żadne dane nie są usuwane';

  @override
  String get accountDetachBody =>
      'Bez adresu tego konta nie da się już odzyskać z innego urządzenia.';

  @override
  String get accountDetachDone => 'Adres odłączony';

  @override
  String get accountOffline => 'Konto niedostępne offline';

  @override
  String get accountEmailTitle => 'Adres e-mail';

  @override
  String get accountEmailExplain =>
      'Wyślemy 6-cyfrowy kod, aby potwierdzić adres. Służy on wyłącznie do odzyskania konta.';

  @override
  String get accountEmailLabel => 'Adres e-mail';

  @override
  String get accountCodeTitle => 'Kod potwierdzający';

  @override
  String accountCodeExplain(String email) {
    return 'Kod wysłany na $email. Jest ważny 10 minut.';
  }

  @override
  String get accountCodeLabel => 'Kod 6-cyfrowy';

  @override
  String get accountSendCode => 'Wyślij kod';

  @override
  String get accountVerify => 'Potwierdź';

  @override
  String get accountResend => 'Wyślij kod ponownie';

  @override
  String accountResendIn(int n) {
    return 'Ponowne wysłanie za $n s';
  }

  @override
  String get accountCheckSpam =>
      'E-mail może iść minutę — sprawdź też folder ze spamem.';

  @override
  String get accountErrorInvalidEmail => 'Nieprawidłowy adres';

  @override
  String get accountErrorTooMany => 'Zbyt wiele żądań, spróbuj za kilka minut';

  @override
  String get accountErrorInvalidCode => 'Kod błędny lub wygasł';

  @override
  String get accountErrorCodeLength => 'Kod ma 6 cyfr';

  @override
  String get albumOfflinePartial =>
      'Offline — pokazujemy to, co już jest na tym urządzeniu';

  @override
  String get accountErrorNetwork => 'Brak połączenia, spróbuj ponownie';

  @override
  String get accountMergeTitle => 'Połączyć tę bibliotekę?';

  @override
  String accountMergeBody(String email) {
    return 'Ulubione i historia z tego urządzenia zostaną dodane do konta $email. Operacji nie można cofnąć.';
  }

  @override
  String get accountMergeConfirm => 'Połącz';

  @override
  String get accountCarryLocal => 'Zachowaj ulubione z tego urządzenia';

  @override
  String accountCarryLocalOn(int n) {
    return 'Ulubione ($n) i playlisty z tego urządzenia zostaną dodane do konta.';
  }

  @override
  String get accountCarryLocalOff =>
      'Zostaną usunięte z tego urządzenia i zastąpione tymi z konta. Pobrane pliki pozostaną.';

  @override
  String get accountDropLocalTitle => 'Usunąć dane z tego urządzenia?';

  @override
  String get accountCreatedOk => 'Konto zapisane, biblioteka jest bezpieczna';

  @override
  String get accountMergedOk => 'Zalogowano — lokalne ulubione zostały dodane';

  @override
  String get accountSignedInOk => 'Zalogowano';

  @override
  String get playlistEntryMissing => 'Brak pliku na tym urządzeniu';

  @override
  String get playlistEntryMissingRestorable =>
      'Brak pliku — można pobrać ponownie';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brakującego',
      many: '$n brakujących',
      few: '$n brakujące',
      one: '$n brakujący',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Zapisz na moim koncie';

  @override
  String get playlistBackupSubtitle =>
      'Zachowuje tę playlistę nawet po ponownej instalacji';

  @override
  String get playlistBackupUpdate => 'Zaktualizuj kopię';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Zastępuje kopię na koncie tą wersją';

  @override
  String get playlistBackupStop => 'Przestań zapisywać';

  @override
  String get playlistBackupStopped => 'Kopia usunięta';

  @override
  String get playlistBackupDone => 'Playlista zapisana';

  @override
  String get playlistBackupFailed => 'Nie udało się zapisać';

  @override
  String get playlistBackupNoAccount => 'Brak konta na tym urządzeniu';

  @override
  String get playlistSyncTooltip => 'Synchronizuj z moim kontem';

  @override
  String get playlistSyncRunning => 'Synchronizowanie…';

  @override
  String get playlistSyncDone => 'Playlisty zsynchronizowane';

  @override
  String get playlistSyncPartial => 'Niektórych playlist nie udało się zapisać';

  @override
  String get playlistFetchMissing => 'Pobierz brakujące utwory';

  @override
  String get playlistFetchDone => 'Pobrano brakujące utwory';

  @override
  String get playlistFetchPartial => 'Niektórych utworów nie udało się pobrać';

  @override
  String get playlistEntryFetchFailed => 'Nie udało się pobrać tego utworu';

  @override
  String get accountStatPlaylists => 'Playlisty';

  @override
  String get accountSyncNow => 'Synchronizuj teraz';

  @override
  String get accountSyncAuto => 'Dzieje się samo w tle';

  @override
  String get accountSyncAnonymous =>
      'Kopia na serwerze. Dodaj e-mail, aby zsynchronizować inne urządzenie.';

  @override
  String get accountSyncPending => 'Zmiany czekają na wysłanie';

  @override
  String accountSyncLast(String when) {
    return 'Ostatnia synchronizacja: $when';
  }

  @override
  String get accountSyncDone => 'Synchronizacja zakończona';

  @override
  String get accountSyncFailed => 'Synchronizacja nieudana, ponowimy próbę';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'muzyka z $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'zawiera $place z $compo';
  }

  @override
  String get competitionEmpty => 'Ta kompilacja nie ma zgłoszeń';

  @override
  String get competitionEntryNoMusic =>
      'Brak muzyki w katalogu dla tego zgłoszenia';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n utworu',
      many: '$n utworów',
      few: '$n utwory',
      one: '$n utwór',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Pomiń';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingStart => 'Zaczynamy';

  @override
  String get onboardingBetaTitle => 'Wersja beta';

  @override
  String get onboardingBetaBody =>
      'Rewamp wciąż powstaje. Dane lokalne — biblioteka, playlisty, ulubione, statystyki — mogą zostać wyczyszczone przed wersją 1.0. Pobranym plikom nic nie grozi, ale to, na czym Ci zależy, przechowuj też gdzie indziej.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Wersja $version (kompilacja $build)';
  }

  @override
  String get onboardingExploreTitle => 'Odkrywaj';

  @override
  String get onboardingExploreBody =>
      'Przeglądaj i szukaj dziesiątek tysięcy chiptune\'ów i modułów z wielkich archiwów online — według wykonawcy, albumu, platformy lub party. Dotknij, by posłuchać, pobierz, by zachować.';

  @override
  String get onboardingLibraryTitle => 'Twoja biblioteka';

  @override
  String get onboardingLibraryBody =>
      'Zapisuj to, co lubisz, twórz playlisty i porządkuj je w folderach. Pobrane utwory grają offline, a biblioteka podąża za Tobą między urządzeniami po zalogowaniu.';

  @override
  String get onboardingPlayerTitle => 'Odtwarzacz';

  @override
  String get onboardingPlayerBody =>
      'Przesuwaj, by zmienić utwór, i otwieraj wizualizacje: oscyloskop, kanały, przewijane nuty, siatkę trackera. Pliki wieloutworowe pokazują podutwory, a każdy głos można wyciszyć osobno.';

  @override
  String get onboardingReplayTitle => 'Wprowadzenie';

  @override
  String get onboardingReplaySubtitle =>
      'Ponownie zobacz informację o wersji beta i przewodnik';

  @override
  String get settingsPatternTitle => 'Patterny';

  @override
  String get settingsPatternSubtitle =>
      'Siatka trackera: kolory, kolumny, przewijanie';

  @override
  String get patternOpaqueBg => 'Nieprzezroczyste tło';

  @override
  String get patternOpaqueBgSubtitle => 'Ukrywa okładkę za siatką';

  @override
  String get commonSave => 'Zapisz';

  @override
  String get commonImport => 'Importuj';

  @override
  String get accountDisplayName => 'Nazwa publiczna';

  @override
  String get accountDisplayNameNotSet =>
      'Nie ustawiona — wymagana, by opublikować playlistę';

  @override
  String get accountDisplayNameHint => 'Nazwa, pod którą chcesz być podpisany.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Zmiana odsyła wszystkie opublikowane playlisty z powrotem do weryfikacji.';

  @override
  String get accountDisplayNameTaken =>
      'Ta nazwa jest już zajęta. Wybierz inną.';

  @override
  String get accountDisplayNameLength => 'Od 2 do 40 znaków.';

  @override
  String get accountDisplayNameSaved => 'Nazwa publiczna zapisana';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlisty odesłane do weryfikacji: $n';
  }

  @override
  String get playlistPublish => 'Upublicznij';

  @override
  String get playlistPublishSubtitle => 'Poproś o publikację (po weryfikacji)';

  @override
  String get playlistPublishTitle => 'Opublikować tę playlistę?';

  @override
  String get playlistPublishBody =>
      'Po zatwierdzeniu będzie widoczna dla wszystkich, podpisana twoją nazwą publiczną. Okładka pochodzi z utworów.';

  @override
  String get playlistPublishCta => 'Poproś';

  @override
  String get playlistPublishSubmitted => 'Wysłana do weryfikacji';

  @override
  String get playlistPublishPending => 'Czeka na zatwierdzenie';

  @override
  String get playlistPublishApproved => 'Publiczna';

  @override
  String playlistPublishRejected(String reason) {
    return 'Odrzucona: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Odrzucona';

  @override
  String get playlistPublishNeedName =>
      'Wybierz nazwę, pod którą chcesz być podpisany';

  @override
  String get playlistPublishNeedTracks =>
      'Do publikacji potrzeba co najmniej 5 utworów';

  @override
  String get playlistPublishHasLocal =>
      'Plików z twojego urządzenia nie można opublikować — inni ich nie odtworzą';

  @override
  String get playlistPublishTooManyPending =>
      'Masz już 3 playlisty czekające na zatwierdzenie';

  @override
  String get playlistPublishRefused =>
      'Publikacja odrzucona: sprawdź utwory i oczekujące zgłoszenia';

  @override
  String get playlistPublishFailed => 'Publikacja nie powiodła się';

  @override
  String get playlistPublishWithdrawn => 'Playlista znów jest prywatna';

  @override
  String get playlistUnpublish => 'Ustaw jako prywatną';

  @override
  String get playlistUnpublishSubtitle => 'Usuwa ją z playlist publicznych';

  @override
  String get playlistRenamePublishedTitle =>
      'Zmienić nazwę opublikowanej playlisty?';

  @override
  String get playlistRenamePublishedBody =>
      'Weryfikowana jest nazwa: zmiana odsyła playlistę do weryfikacji i na ten czas ją ukrywa. Dodanie lub przestawienie utworów — nie.';

  @override
  String playlistByAuthor(String author) {
    return 'od $author';
  }

  @override
  String get settingsSpectrumMode => 'Tryb widma';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Kolorowy';

  @override
  String get settingsSpectrumModeBeam => 'Wiązka';

  @override
  String get settingsSpectrumModeLine => 'Linia';

  @override
  String get settingsSpectrumModeRing => 'Pierścień';

  @override
  String get settingsPianoMode => 'Wygląd pianina';

  @override
  String get settingsPianoModeRoll => 'Klawiatury';

  @override
  String get settingsPianoModeFalling => 'Spadające nuty';

  @override
  String get settingsPianoColor => 'Kolory';

  @override
  String get settingsPianoColorVoice => 'Według głosu';

  @override
  String get settingsPianoColorInstrument => 'Według instrumentu';

  @override
  String get settingsPianoGlow => 'Poświata na uderzonych klawiszach';

  @override
  String get settingsPianoLighting => 'Światło i cienie na klawiszach';

  @override
  String get settingsPianoVoiceNames => 'Nazwy głosów';

  @override
  String get featuredAdditionsHeader => 'Nowości w katalogu';

  @override
  String get featuredAdditionsCard => 'Świeżo dodane';

  @override
  String get featuredAdditionsPlaylist => 'Świeżo dodane utwory';

  @override
  String get releaseNotesTitle => 'Nowości';

  @override
  String get releaseNotesV7Cpu =>
      'Aplikacja nie pracuje już w tle, gdy nic nie gra: znacznie mniejsze zużycie procesora i baterii.';

  @override
  String get releaseNotesV7VizIdle =>
      'Wizualizacje zatrzymują się, gdy odtwarzanie jest wstrzymane, i są ograniczone do 60 klatek na sekundę (regulowane).';

  @override
  String get releaseNotesV7Subsongs =>
      'Naprawiono: na PC Engine, Master System i Atari ST (.sndh) niektóre utwory uruchamiały sąsiednią piosenkę.';

  @override
  String get releaseNotesV7Piano =>
      'Wizualizacja pianina pozostawała pusta przy muzyce z PC Engine.';

  @override
  String get releaseNotesV7Database =>
      'Baza danych uszkodzona przez aktualizację naprawia się teraz sama, zamiast blokować dostęp do biblioteki.';

  @override
  String get releaseNotesDataReset =>
      'Dane lokalne zostały wyczyszczone na potrzeby tej bety. Biblioteka i playlisty odtworzą się z konta; pobrania trzeba powtórzyć.';

  @override
  String get releaseNotesDismiss => 'Dalej';

  @override
  String get pmManagePresets => 'Zarządzaj presetami';

  @override
  String get pmPickTooltip => 'Wybierz preset';

  @override
  String get pmPickFilter => 'Filtruj presety';

  @override
  String get pmSourceTooltip => 'Źródło presetów';

  @override
  String get pmAddToPlaylistTooltip => 'Dodaj preset do playlisty';

  @override
  String pmSlowPresetDropped(String name) {
    return '„$name” jest zbyt ciężki dla tego urządzenia i został pominięty.';
  }

  @override
  String get pmSlowDeviceTitle => 'To urządzenie jest zbyt wolne';

  @override
  String get pmSlowDeviceOff =>
      'Wizualizacja została wyłączona: to urządzenie nie nadąża za presetami Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pominiętych presetów',
      many: '$count pominiętych presetów',
      few: '$count pominięte presety',
      one: '$count pominięty preset',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Zbyt wolne na tym urządzeniu. Odtwarzanie je pomija.';

  @override
  String get settingsPmSlowPresetsRestore => 'Przywróć';

  @override
  String get pmSourceBundled => 'Wbudowane presety';

  @override
  String get pmSourceImports => 'Moje importy';

  @override
  String get pmSourceAll => 'Wszystkie presety';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presetu',
      many: '$count presetów',
      few: '$count presety',
      one: '$count preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Nowa playlista…';

  @override
  String get pmPlaylistName => 'Nazwa playlisty';

  @override
  String get pmAddedToPlaylist => 'Dodano do playlisty';

  @override
  String get pmAlreadyInPlaylist => 'Już jest na tej playliście';

  @override
  String get pmTabPacks => 'Packi';

  @override
  String get pmTabBrowse => 'Przeglądaj';

  @override
  String get pmTabPlaylists => 'Playlisty';

  @override
  String get pmTabPopular => 'Popularne';

  @override
  String get pmTabSetAside => 'Pominięte';

  @override
  String get pmSetAsideEmpty =>
      'Nic nie pominięto. Trafiają tu presety, przy których to urządzenie spada poniżej 6 kl./s.';

  @override
  String get pmSetAsideRestoreAll => 'Przywróć wszystko';

  @override
  String get pmInstall => 'Zainstaluj';

  @override
  String get pmInstallQueued => 'Instalacja w kolejce';

  @override
  String get pmUninstall => 'Odinstaluj';

  @override
  String get pmUninstalled => 'Pack usunięty';

  @override
  String get pmUse => 'Użyj';

  @override
  String get pmDefaultPackBanner => 'Polecany pack startowy';

  @override
  String pmLicense(String license) {
    return 'Licencja: $license';
  }

  @override
  String get pmPacksOffline => 'Serwer niedostępny';

  @override
  String get pmSearchPresets => 'Szukaj presetów…';

  @override
  String get pmPlayNow => 'Odtwórz teraz';

  @override
  String get pmDownloadAction => 'Pobierz';

  @override
  String get pmDownloaded => 'Preset pobrany';

  @override
  String get pmDownloadFailed => 'Pobieranie nie powiodło się';

  @override
  String pmPreviewing(String name) {
    return 'Odtwarzanie: $name';
  }

  @override
  String get pmLocalSection => 'Moje playlisty';

  @override
  String get pmCuratedSection => 'Playlisty Rewamp';

  @override
  String get pmImportPlaylist => 'Pobierz i użyj';

  @override
  String get pmPlaylistImported => 'Playlista gotowa';

  @override
  String get pmImportFiles => 'Importuj pliki…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaimportowano $count presetu',
      many: 'Zaimportowano $count presetów',
      few: 'Zaimportowano $count presety',
      one: 'Zaimportowano $count preset',
      zero: 'Nie zaimportowano żadnego presetu',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presety dodano do biblioteki projectM';

  @override
  String get pmNoPlaylists => 'Brak playlist z presetami';

  @override
  String get pmSourceApplied => 'Zastosowano źródło presetów';

  @override
  String get pmPlaylistEmpty => 'Ta playlista jest pusta';

  @override
  String get pmDays7 => '7 dni';

  @override
  String get pmDays30 => '30 dni';

  @override
  String get pmDays365 => '1 rok';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odtworzenia',
      many: '$count odtworzeń',
      few: '$count odtworzenia',
      one: '$count odtworzenie',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Instalacja nie powiodła się';

  @override
  String get pmSingleDownloads => 'Pojedyncze pobrania';

  @override
  String pmAvailableIn(String pack) {
    return 'Dostępny w $pack';
  }

  @override
  String get pmCleanUp => 'Wyczyść';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto $count presetu',
      many: 'Usunięto $count presetów',
      few: 'Usunięto $count presety',
      one: 'Usunięto $count preset',
      zero: 'Nie ma czego czyścić',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Zablokuj ten preset';

  @override
  String get pmUnlockAction => 'Odblokuj preset';

  @override
  String get pmOrderRandom => 'Presety losowo';

  @override
  String get pmOrderSequential => 'Presety po kolei';

  @override
  String get pmUpdateAvailable => 'Dostępna aktualizacja';

  @override
  String get pmUpdate => 'Aktualizuj';

  @override
  String get pmSelectAll => 'Zaznacz wszystko';

  @override
  String get pmSelectNone => 'Odznacz wszystko';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaznaczonych',
      many: '$count zaznaczonych',
      few: '$count zaznaczone',
      one: '$count zaznaczony',
      zero: 'Nic nie zaznaczono',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Nieużywane tekstury';

  @override
  String pmTexturesFreed(String size) {
    return 'Zwolniono $size';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tekstury',
      many: '$count tekstur',
      few: '$count tekstury',
      one: '$count tekstura',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'Listy przebojów';

  @override
  String get chartsGlobal => 'Globalne';

  @override
  String get chartsByCollection => 'Wg kolekcji';

  @override
  String get chartsTopSongs => 'Top utwory';

  @override
  String get chartsTopAlbums => 'Top albumy';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Opublikowane listy';

  @override
  String chartsUpdated(String date) {
    return 'Zaktualizowano $date';
  }

  @override
  String get chartsSource => 'Źródło';

  @override
  String get settingsMidiSynth => 'Syntezator MIDI';

  @override
  String get settingsMidiSynthAuto =>
      'Automatycznie (MT-32, gdy plik tego wymaga)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (emulacja)';

  @override
  String get settingsMt32Section => 'Emulacja Roland MT-32';

  @override
  String get settingsMt32RomsTitle => 'ROM-y MT-32';

  @override
  String get settingsMt32RomsMissing =>
      'Brak użytecznego zestawu ROM — zaimportuj ROM sterujący i PCM z MT-32 lub CM-32L';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Aktywny zestaw: $set';
  }

  @override
  String get settingsMt32Import => 'Importuj pliki ROM…';

  @override
  String get settingsMt32ImportSubtitle =>
      'ROM sterujący + ROM PCM (.rom/.bin), połówki MAME są akceptowane. ROM-y nie są dostarczane z aplikacją.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name nie jest znanym ROM-em MT-32 / CM-32L';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaimportowano $count pliku ROM',
      many: 'Zaimportowano $count plików ROM',
      few: 'Zaimportowano $count pliki ROM',
      one: 'Zaimportowano $count plik ROM',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Model';

  @override
  String get settingsMt32ModelAuto => 'Automatycznie (CM-32L, jeśli dostępny)';

  @override
  String get settingsMt32Reverb => 'Pogłos';

  @override
  String get engineDescMt32 =>
      'Emulacja Roland MT-32 / CM-32L dla MIDI (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Miniodtwarzacz';

  @override
  String get miniWindowExit => 'Wróć do głównego okna';

  @override
  String get miniWindowIdle => 'Nic nie jest odtwarzane';

  @override
  String get settingsAlwaysOnTopTitle => 'Zawsze na wierzchu';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Utrzymuje okno nad pozostałymi — zarówno główne, jak i miniodtwarzacz';

  @override
  String get windowAlwaysOnTopOn => 'Zawsze na wierzchu: włączone';

  @override
  String get miniWindowCoverFill => 'Powiększ okładkę, by wypełniła pole';

  @override
  String get miniWindowCoverFit => 'Pokaż całą okładkę';

  @override
  String get releaseNotesV7Mt32 =>
      'Nowy silnik Roland MT-32 do muzyki MIDI z gier, z własnymi ROM-ami. Bez ROM-ów plik MIDI napisany dla MT-32 jest dostosowywany do General MIDI.';

  @override
  String get releaseNotesV7Xmp =>
      'Odtwarzanych jest teraz dziesięć rzadkich formatów modułów (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'Muzyka AdLib Westwood (.adl) odtwarza wszystkie swoje utwory, a BP SoundMon V1 jest rozpoznawany na Amidze.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac: miniodtwarzacz, kompaktowy lub z wizualizacją, oraz opcja „Zawsze na wierzchu”.';

  @override
  String get releaseNotesV7Instruments =>
      'Oscyloskop, nuty i pianino mogą nazywać i kolorować każdy instrument, nie tylko każdy głos.';

  @override
  String get releaseNotesV7Podium =>
      'Wyszukiwanie: filtruj utwory, które zajęły 1., 2. lub 3. miejsce w konkursie demosceny.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'Zbyt krótkie podutwory (efekty dźwiękowe z gier) są pomijane w „Odtwórz wszystko” — próg w Ustawienia → Odtwarzanie.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Twoje importy: upuść cały folder (archiwa zostaną rozpakowane) oraz twórz, zmieniaj nazwy lub przenoś foldery.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI: perkusja nie brzmi już jak pianino, a głośność nie przesterowuje.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM: presety nie powtarzają się już między kolejnymi uruchomieniami, a preset nie jest już błędnie odrzucany po pauzie.';

  @override
  String get libraryFileMissing => 'Brak pliku';
}
