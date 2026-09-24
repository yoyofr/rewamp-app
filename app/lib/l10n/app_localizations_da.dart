// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get navHome => 'Hjem';

  @override
  String get navSearch => 'Søg';

  @override
  String get navLocal => 'Lokalt';

  @override
  String get settingsTabsOrderTitle => 'Rækkefølge af faner';

  @override
  String get settingsTabsOrderSubtitle =>
      'Træk for at ordne. De første fire vises i bundlinjen, resten under “Mere”.';

  @override
  String get settingsTabsInBar => 'I linjen';

  @override
  String get settingsTabsInMore => 'Under “Mere”';

  @override
  String get settingsLaunchTab => 'Fane ved start';

  @override
  String get settingsLaunchTabSubtitle => 'Hvilken fane appen åbner på';

  @override
  String get navLibrary => 'Bibliotek';

  @override
  String get noFileSelected => 'Ingen fil valgt';

  @override
  String get openFile => 'Åbn fil';

  @override
  String get pickerLabelAudio => 'Lyd';

  @override
  String get formatNotSupported => 'Formatet understøttes ikke';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Ikke-understøttet format: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Ikke på denne enhed: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Filen findes ikke længere på serveren: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file findes ikke i albummets arkiv — rippet nævner filen, men leverer den ikke.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host svarede ikke. Tjek forbindelsen, og prøv igen.';
  }

  @override
  String get failedToLoadFile => 'Kunne ikke indlæse filen';

  @override
  String get libraryEmptyHint =>
      'Dine kunstnere, album og spillelister\nvises her.';

  @override
  String get libraryPlaylists => 'Spillelister';

  @override
  String get libraryArtists => 'Kunstnere';

  @override
  String get libraryAlbums => 'Album';

  @override
  String get libraryTracks => 'Numre';

  @override
  String get libraryFavorites => 'Favoritter';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatisk spilleliste med dine yndlingsnumre';

  @override
  String get libraryRecentlyAdded => 'Tilføjet for nylig';

  @override
  String get libraryEmpty => 'Der er ikke noget her endnu';

  @override
  String get libraryRemoved => 'Fjernet fra biblioteket';

  @override
  String get searchHint => 'Søg…';

  @override
  String get searchTypePlaceholder =>
      'Skriv en titel, en kunstner eller et album…';

  @override
  String get searchNoResults => 'Ingen resultater';

  @override
  String get searchDownloading => 'Downloader…';

  @override
  String searchError(String message) {
    return 'Fejl: $message';
  }

  @override
  String get tabAll => 'Numre';

  @override
  String get tabArtists => 'Kunstnere';

  @override
  String get tabAlbums => 'Album';

  @override
  String get tabProductions => 'Produktioner';

  @override
  String get filterWithVideo => 'Med video';

  @override
  String get videoUnavailable => 'Denne video er ikke tilgængelig';

  @override
  String get noItems => 'Ingen emner';

  @override
  String get sortRelevance => 'Relevans';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Afspillet for nylig';

  @override
  String get noRecentTracks => 'Ingen numre afspillet for nylig';

  @override
  String get playerSourceLocal => 'lokal';

  @override
  String get homePlayFiles => 'Afspil filer';

  @override
  String get homePlayFolder => 'Afspil en mappe';

  @override
  String get homeSectionsOrderTitle => 'Rækkefølge af sektioner';

  @override
  String get homeSectionsOrderSubtitle =>
      'Træk for at ordne startskærmen, som du vil.';

  @override
  String get homeSectionsOrderReset => 'Standardrækkefølge';

  @override
  String get homeSectionsOrderSettings => 'Startskærmens sektionsrækkefølge';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total resultater';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded indlæst…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded resultater';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded indlæst — rul for at se flere';
  }

  @override
  String countNLoaded(int n) {
    return '$n indlæst';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n fil(er)';
  }

  @override
  String get browseFilterByTitle => 'Filtrér efter titel…';

  @override
  String get browseNoSongs => 'Ingen sange tilgængelige';

  @override
  String get browseByFormat => 'Efter format';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtrér efter format…';

  @override
  String get browseByPlatform => 'Efter platform';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Platformsnavn…';

  @override
  String get browseByChip => 'Efter lydchip';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'f.eks. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Efter kunstner';

  @override
  String get browseByArtistSubtitle => 'Gennemse komponisterne';

  @override
  String get browseFilterByName => 'Filtrér efter navn…';

  @override
  String get browseNoArtistFound => 'Ingen kunstner fundet';

  @override
  String get browseNoArtistsAvailable => 'Ingen kunstnere tilgængelige';

  @override
  String get browseNoArtist => 'Ingen kunstnere';

  @override
  String get browseNoAlbum => 'Ingen album';

  @override
  String get browseTopPacks => 'Bedste pakker';

  @override
  String get browseTopPacksSubtitle => 'De højest bedømte pakker';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Bedste pakker — $collection';
  }

  @override
  String get browseLatestPacks => 'Nyeste pakker';

  @override
  String get browseLatestPacksSubtitle => 'De seneste tilføjelser';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Nyeste pakker — $collection';
  }

  @override
  String get browseAllSongs => 'Alle sange';

  @override
  String get browseAllSongsSubtitleAlpha => 'Gennemse i alfabetisk rækkefølge';

  @override
  String get browseAlphabetical => 'I alfabetisk rækkefølge';

  @override
  String browseAllLabel(String collection) {
    return 'Alle — $collection';
  }

  @override
  String get browseCollections => 'Samlinger';

  @override
  String browseFilesCount(String count) {
    return '$count filer';
  }

  @override
  String get browseIndexing => 'Indeksering i gang';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrér $name…';
  }

  @override
  String get browseAllYears => 'Alle år';

  @override
  String get browseAllYearsSubtitle => 'Alle sange fra partyet';

  @override
  String get browseNoCompo => 'Ingen compo indekseret for dette party.';

  @override
  String get browseOthers => 'Andre';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bidrag — rangliste',
      one: '$n bidrag — rangliste',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Afspil spillelisten';

  @override
  String get browsePlayAllRanked => 'Afspil alle (i ranglistens rækkefølge)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre — ranglistens rækkefølge',
      one: '$n nummer — ranglistens rækkefølge',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Gennemse efter album';

  @override
  String get browsePlayAll => 'Afspil alle';

  @override
  String get browseShuffle => 'Bland';

  @override
  String get browseSearchInFolder => 'Søg i denne mappe…';

  @override
  String get browseFilterThisList => 'Filtrér denne liste…';

  @override
  String get browseSearchSubfolders => 'Søg i undermapper';

  @override
  String get browseEmptyFolder => 'Tom mappe';

  @override
  String browsePlaybackError(String message) {
    return 'Afspilning mislykkedes: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Visning';

  @override
  String get browseViewList => 'Liste';

  @override
  String get browseViewGrid => 'Gitter';

  @override
  String get browseViewGridCompact => 'Kompakt gitter';

  @override
  String get browseSearchAlbum => 'Søg efter et album…';

  @override
  String get browseSearchArtist => 'Søg efter en kunstner…';

  @override
  String get browsePlayAlbum => 'Afspil album';

  @override
  String get searchDownloadingAlbum => 'Downloader album…';

  @override
  String get searchCategoryChip => 'Chips';

  @override
  String get searchCategoryGroup => 'Grupper';

  @override
  String get artistRealName => 'Rigtigt navn';

  @override
  String get artistAliases => 'Aliasser';

  @override
  String get artistBorn => 'Født';

  @override
  String get artistInterview => 'Interview';

  @override
  String get audioOutput => 'Lydudgang';

  @override
  String get audioOutputSystemDefault => 'Systemstandard';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Noter';

  @override
  String get notePlacedBadge => 'Placeret i konkurrencen';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmer',
      one: '$count medlem',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Vis numre';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moduler',
      one: '$count modul',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Parties';

  @override
  String get searchCategoryYear => 'År';

  @override
  String get searchCategoryOrigin => 'Oprindelse';

  @override
  String get searchCategoryProduction => 'Produktion';

  @override
  String get searchCategoryProductionType => 'Prod-typer';

  @override
  String get searchCategoryPublisher => 'Udgivere';

  @override
  String get searchCategoryDeveloper => 'Udviklere';

  @override
  String get searchCategoryArcadeBoard => 'Arkadekort';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'via kunstner';

  @override
  String get searchViaAlbum => 'via et album';

  @override
  String get searchViaSong => 'via en sang';

  @override
  String get searchSortPopular => 'Populær';

  @override
  String get searchSortYear => 'År';

  @override
  String get searchSortRandom => 'Tilfældig';

  @override
  String get searchSortRating => 'Bedømmelse';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stemmer',
      one: '$count stemme',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Stigende';

  @override
  String get searchSortDesc => 'Faldende';

  @override
  String get searchFilters => 'Filtre';

  @override
  String get searchExactSearch => 'Nøjagtig søgning';

  @override
  String get searchExactSearchSubtitle => 'Slår omtrentlig (fuzzy) søgning fra';

  @override
  String get searchTags => 'Tags';

  @override
  String searchTagSearchHint(String category) {
    return 'Søg efter et tag i « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Skriv for at søge efter tags.';

  @override
  String get searchTagsAndLogic => 'Flere tags = logisk OG.';

  @override
  String get searchFilterYear => 'År';

  @override
  String get searchFilterAll => 'alle';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrering efter år udelader sange uden dato.';

  @override
  String get searchMinRating => 'Bedømmelse ≥';

  @override
  String get searchPodium => 'Podieplads';

  @override
  String get searchPodiumAny => 'Enhver podieplads';

  @override
  String get searchPodiumUnavailable =>
      'Podiefilteret er endnu ikke tilgængeligt på serveren';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Annuller';

  @override
  String get searchReset => 'Nulstil';

  @override
  String get searchApply => 'Anvend';

  @override
  String get searchClearRecent => 'Ryd de seneste søgninger';

  @override
  String get searchBrowse => 'Gennemse';

  @override
  String get searchBrowseHint =>
      'Vælg en facet (gruppe, chip, år…) for at udforske kataloget, eller start Radio/Overraskelse ovenfor.';

  @override
  String get searchDidYouMean => 'Få resultater — prøv en omtrentlig søgning?';

  @override
  String get searchYes => 'Ja';

  @override
  String get featuredCommunityTitle => 'Nyt fra fællesskabet';

  @override
  String get searchPlaylistSourceAll => 'Alle';

  @override
  String get searchPlaylistSourceUser => 'Fællesskab';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Platform';

  @override
  String get filterCollection => 'Samling';

  @override
  String get videoWatchDemo => 'Se demoen';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Samling: $name';
  }

  @override
  String get searchCollectionAll => 'Alle';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Tilfældig kø ud fra de aktuelle filtre';

  @override
  String get searchSurprise => 'Overraskelse';

  @override
  String get searchSurpriseTooltip => 'En tilfældig sang';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Ingen sange';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sange',
      one: '$n sang',
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
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Vælg samling';

  @override
  String get searchFilterCollections => 'Filtrér samlinger…';

  @override
  String get searchFilterPlaceholder => 'Filtrér…';

  @override
  String searchAllOf(String label) {
    return 'Alle ($label)';
  }

  @override
  String get searchNoMatch => 'Ingen match';

  @override
  String get searchNoPlaylist => 'Ingen spillelister';

  @override
  String get engineDescOpenmpt => 'Tracker-moduler (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Moduler, libopenmpt ikke læser (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — lydchips, scope pr. kanal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN-arkiver';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — stemmer pr. kanal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp-motor)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX-chiptunes (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Multi-chip-chiptunes .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amiga custom-chip-formater via 68k-emulering (~320 filtyper)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Standard MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ-synth (16 stemmer)';

  @override
  String get engineDescV2m => 'V2M-synth (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — ægte 68000-emulering + YM2149 + STE-DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300-emulering + RSP-lyd';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ-emulering';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound-chip';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — ægte AY-3-8910/YM2149-synth';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixels egen motor';

  @override
  String get engineDescPxtone => 'Pixels tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — ægte 68000 via emu68';

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
      'Streamede spillydformater (700+, inkl. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — reservedekoder';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total sange',
      one: '$loaded / 1 sang',
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
      other: '$loaded / $total kunstnere',
      one: '$loaded / 1 kunstner',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sange',
      one: '$n sang',
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
      other: '$n kunstnere',
      one: '$n kunstner',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n grupper',
      one: '$n gruppe',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Lande';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lande',
      one: '$n land',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Mapper';

  @override
  String get featuredTitle => 'Fremhævet i dag';

  @override
  String featuredPartyNow(String party) {
    return '$party kører lige nu — podier fra tidligere udgaver';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party starter om $days dage — podier fra tidligere udgaver',
      one: '$party starter i morgen — podier fra tidligere udgaver',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series-sæson — podier fra tidligere udgaver';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Udgivet i $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'For $age år siden: spillene fra $year',
      one: 'For et år siden: spillene fra $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade\'erne';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'For $age år siden: spillene fra $year',
      one: 'For et år siden: spillene fra $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Udgivet i $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Jubilæer';

  @override
  String get featuredBirthdayHeader => 'Dagens fødselsdage';

  @override
  String get featuredBirthdayWeekHeader => 'Ugens fødselsdage';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist har fødselsdag i denne uge';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlister',
      one: '$count playliste',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Prøv igen';

  @override
  String get commonOptions => 'Valgmuligheder';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonDeleteDownload => 'Slet download';

  @override
  String get commonAddToPlaylist => 'Føj til spilleliste';

  @override
  String get commonPlayNext => 'Afspil næste';

  @override
  String get commonAddToQueueEnd => 'Føj til slutningen af køen';

  @override
  String get commonAddToFavorites => 'Føj til favoritter';

  @override
  String get commonRemoveFromFavorites => 'Fjern fra favoritter';

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
  String get subsongDeleteDownloadTitle => 'Slet denne download?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Filen og dens lokale poster (historik, numre) bliver slettet.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Kunne ikke læse numrene';

  @override
  String subsongTrackNumber(int number) {
    return 'Spor $number';
  }

  @override
  String get subsongDefaultTrack => 'Standardnummer';

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
  String get subsongPlayAll => 'Afspil alle';

  @override
  String get albumDownloading => 'Downloader album…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Downloader album… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks => 'Download albummet for at se numrene';

  @override
  String get albumNotDownloadedHint =>
      'Albummet er ikke downloadet — start afspilningen for at downloade det';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre',
      one: '$count nummer',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Indlæser detaljer…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Afspil album';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count emner',
      one: '$count emne',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Afspil dette nummer fra søgningen først for at downloade det';

  @override
  String get libraryAddedTrack => 'Nummeret er føjet til dit bibliotek';

  @override
  String get libraryAddedAlbum => 'Albummet er føjet til dit bibliotek';

  @override
  String get libraryAddedArtist => 'Kunstneren er føjet til dit bibliotek';

  @override
  String get libraryRemovedTrack => 'Nummeret er fjernet fra dit bibliotek';

  @override
  String get libraryRemovedAlbum => 'Albummet er fjernet fra dit bibliotek';

  @override
  String get libraryRemovedArtist => 'Kunstneren er fjernet fra dit bibliotek';

  @override
  String get libraryImportBeforeAddTitle => 'Importér først?';

  @override
  String get libraryImportBeforeAddBody =>
      'Denne fil afspilles fra en midlertidig placering, som systemet kan tømme. Vil du importere den til dit lokale bibliotek, så posten overlever?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'Dette nummer kommer fra et arkiv, der er åbnet i en midlertidig cache. Hele arkivet importeres til dit lokale bibliotek, inklusive ledsagefiler.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'Nummeret kan ikke tilføjes: dets katalog-id er ukendt på denne enhed.';

  @override
  String songTilePlayFailed(String message) {
    return 'Afspilning mislykkedes: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Download mislykkedes — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Downloader — $label';
  }

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmpty => 'Ingen ventende downloads';

  @override
  String get downloadsPause => 'Sæt på pause';

  @override
  String get downloadsResume => 'Genoptag';

  @override
  String get downloadsCancel => 'Annullér download';

  @override
  String get downloadsClear => 'Fjern alle';

  @override
  String get downloadsPausedBanner =>
      'Downloads på pause — den aktuelle fil afsluttes først';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Downloader — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Spilleliste';

  @override
  String get miniPlayerHideQueue => 'Skjul spillelisten';

  @override
  String get transportShuffle => 'Bland';

  @override
  String get transportShuffleOn => 'Blanding slået til';

  @override
  String get transportLoopOff => 'Gentagelse slået fra';

  @override
  String get transportLoopQueue => 'Gentag: køen';

  @override
  String get transportLoopTrack => 'Gentag: aktuelt nummer';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spektrum';

  @override
  String get vizVoices => 'Stemmer';

  @override
  String get vizNotes => 'Noder';

  @override
  String get vizPiano => 'Klaver';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Rulletilstand';

  @override
  String get patternSmoothScroll => 'Blød rulning';

  @override
  String get patternPinnedRow => 'Fastgjort aktiv række';

  @override
  String get patternVolumeBars => 'Lydstyrkebjælker';

  @override
  String get patternColorScheme => 'Farveskema';

  @override
  String get patternSize => 'Størrelse';

  @override
  String get patternColumns => 'Kolonner';

  @override
  String get patternColumnsAll => 'Fuld';

  @override
  String get patternColumnsNoteInstr => 'Reduceret';

  @override
  String get patternColumnsNote => 'Minimal';

  @override
  String get vizClose => 'Luk visualiseringen';

  @override
  String get vizFullscreen => 'Fuld skærm';

  @override
  String get vizExitFullscreen => 'Afslut fuld skærm';

  @override
  String get vizPrevPreset => 'Forrige preset';

  @override
  String get vizNextPreset => 'Næste preset';

  @override
  String get vizProjectmUnavailable => 'projectM er ikke tilgængelig';

  @override
  String get voicesTitle => 'Stemmer';

  @override
  String get voicesNone => 'Ingen stemmer for dette nummer.';

  @override
  String get voicesLongPressSolo => 'langt tryk = solo';

  @override
  String get voicesMuteAll => 'Slå alle fra';

  @override
  String get voicesUnmuteAll => 'Slå alle til';

  @override
  String get voicesStereoOutput => 'Stereoudgang';

  @override
  String get voicesLeft => 'Venstre';

  @override
  String get voicesRight => 'Højre';

  @override
  String get enginesFormatsTitle => 'Afspilbare formater';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats afspilbare formater fordelt på $engines afspilningsmotorer.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formater',
      one: '$count format',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Cover af $title af $artist';
  }

  @override
  String stilCover(String work) {
    return 'Cover af $work';
  }

  @override
  String get playerQueue => 'Kø';

  @override
  String get queueEdit => 'Rediger';

  @override
  String get queueEditDone => 'Færdig';

  @override
  String get queueClear => 'Ryd køen';

  @override
  String get queueClearConfirmTitle => 'Ryd køen?';

  @override
  String get queueClearConfirmBody => 'Køen tømmes, og afspilningen stopper.';

  @override
  String get queueClearConfirm => 'Ryd';

  @override
  String get queueRemoveSelected => 'Fjern valgte';

  @override
  String get queueRemoveTrack => 'Fjern fra køen';

  @override
  String get queueReorder => 'Skift rækkefølge';

  @override
  String get playerArtwork => 'Cover';

  @override
  String get playerVisualizer => 'Visualisering';

  @override
  String get playerVoices => 'Stemmer';

  @override
  String get playerTrackInfo => 'Oplysninger om nummeret';

  @override
  String get playerShowQueue => 'Spilleliste';

  @override
  String get playerHideQueue => 'Skjul spillelisten';

  @override
  String get playerNoTrackInfo => 'Ingen oplysninger tilgængelige.';

  @override
  String get playerViewSubsongs => 'Vis subsongs';

  @override
  String get playerViewAlbum => 'Vis album';

  @override
  String get playerViewArtist => 'Vis kunstner';

  @override
  String get playerAddToPlaylist => 'Føj til spilleliste';

  @override
  String get playerEngineSettings => 'Motorindstillinger';

  @override
  String get queueAddToPlaylist => 'Føj køen til en playliste';

  @override
  String get playerMoreOptions => 'Flere valgmuligheder';

  @override
  String get playerClose => 'Luk';

  @override
  String get playerCancel => 'Annuller';

  @override
  String get playerDelete => 'Slet';

  @override
  String get playerAddFavorite => 'Føj til favoritter';

  @override
  String get playerRemoveFavorite => 'Fjern fra favoritter';

  @override
  String get playerAddToLibrary => 'Føj til bibliotek';

  @override
  String get playerRemoveFromLibrary => 'Fjern fra bibliotek';

  @override
  String get playerAddedToLibrary => 'Nummeret er føjet til biblioteket';

  @override
  String get playerRemovedFromLibrary => 'Nummeret er fjernet fra biblioteket';

  @override
  String get playerDeleteDownload => 'Slet download';

  @override
  String get playerRedownload => 'Download filen igen';

  @override
  String get playerRedownloadUnavailable =>
      'Gendownload er ikke tilgængelig for denne fil';

  @override
  String get playerDeleteDownloadTitle => 'Slet download?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Filen og dens lokale poster (historik, numre) bliver slettet.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Dine tendenser';

  @override
  String get homeYourAllTimeTop => 'Din top gennem tiden';

  @override
  String get homeTrending => 'Populært nu';

  @override
  String get homeFeaturedPlaylists => 'Fremhævede spillelister';

  @override
  String get homeAllTimeTop => 'Top gennem tiden';

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
      other: '$n afspilninger',
      one: '$n afspilning',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Tom eller ulæselig spilleliste';

  @override
  String get homeExtractingArchive => 'Udpakker arkivet…';

  @override
  String get homeArchiveEmpty => 'Ingen afspilbare filer i arkivet';

  @override
  String get homeNothingPlayable => 'Intet afspilleligt i markeringen';

  @override
  String get homeAlbumLoadFailed => 'Kunne ikke indlæse dette album';

  @override
  String get homeSongLoadFailed => 'Kunne ikke indlæse dette nummer';

  @override
  String get navStats => 'Statistik';

  @override
  String get navSettings => 'Indstillinger';

  @override
  String get playlistMoveUp => 'Flyt til overordnet mappe';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlister',
      one: '$n playliste',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n undermapper',
      one: '$n undermappe',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Denne mappe og hele dens indhold slettes permanent:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Denne mappe slettes.';

  @override
  String get playlistFolderRoot => 'Rod';

  @override
  String get playlistMoveToFolder => 'Flyt til mappe';

  @override
  String playlistDeleteTitle(String name) {
    return 'Slet \"$name\"?';
  }

  @override
  String get playlistDeleteBody => 'Denne playliste slettes permanent.';

  @override
  String get playlistRenameFolderTitle => 'Omdøb mappe';

  @override
  String get playlistClearFavorites => 'Slet alle favoritter';

  @override
  String get playlistClearFavoritesTitle => 'Slet alle favoritter?';

  @override
  String get playlistClearFavoritesBody =>
      'Du mister alle dine yndlingsnumre. Dette kan ikke fortrydes.';

  @override
  String get playlistRemoveFromLibrary => 'Fjern fra biblioteket';

  @override
  String get playlistServerReadOnly => 'Serverplayliste · skrivebeskyttet';

  @override
  String get navAbout => 'Om';

  @override
  String get navMore => 'Mere';

  @override
  String get shellAlbumQueuedAtEnd =>
      'Albummet er føjet til slutningen af køen';

  @override
  String get shellAlbumQueuedNext => 'Albummet afspilles som det næste';

  @override
  String get shellAddingToQueue => 'Føjer til køen…';

  @override
  String get shellAddingNext => 'Føjer til afspil næste…';

  @override
  String shellDownloadFailed(String error) {
    return 'Download mislykkedes: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre føjet til køen',
      one: '$count nummer føjet til køen',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" er føjet til slutningen af køen';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" afspilles som det næste';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Download mislykkedes: $title — springer til næste nummer';
  }

  @override
  String get shellNetworkUnavailable =>
      'Afspilningen er stoppet: netværket ser ud til at være utilgængeligt.';

  @override
  String get statsTitle => 'Statistik';

  @override
  String statsPeriodDays(int n) {
    return '$n dage';
  }

  @override
  String get statsPeriodThisYear => 'I år';

  @override
  String get statsPeriodAll => 'Alt';

  @override
  String get statsByMonthOrYear => 'Efter måned / år…';

  @override
  String get statsByYear => 'Efter år';

  @override
  String get statsByMonth => 'Efter måned';

  @override
  String get statsPlaysLabel => 'Afspilninger';

  @override
  String get statsTracksLabel => 'Numre';

  @override
  String get statsArtistsLabel => 'Kunstnere';

  @override
  String get statsAlbumsLabel => 'Album';

  @override
  String get statsListenTime => 'Lyttetid';

  @override
  String get statsByCollection => 'Efter samling';

  @override
  String get statsByFormat => 'Efter format';

  @override
  String get statsByEngine => 'Efter motor';

  @override
  String get statsPlaylistsLabel => 'Playlister';

  @override
  String get statsLocalFilesSection => 'Downloadede filer';

  @override
  String get statsFilesLabel => 'Filer';

  @override
  String get statsSpaceLabel => 'Diskplads';

  @override
  String get statsNoPlaysInPeriod => 'Ingen afspilninger i denne periode';

  @override
  String get statsNoPlays => 'Ingen afspilninger';

  @override
  String get statsTopTracks => 'Topnumre';

  @override
  String get statsTopAlbums => 'Topalbum';

  @override
  String get statsTopArtists => 'Topkunstnere';

  @override
  String statsTopTracksIn(String period) {
    return 'Topnumre — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Topalbum — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Topkunstnere — $period';
  }

  @override
  String get statsSeeAll => 'Se alle';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n afspilninger',
      one: '$n afspilning',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'maks. $n';
  }

  @override
  String get commonCancel => 'Annuller';

  @override
  String get commonCreate => 'Opret';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Slet';

  @override
  String get commonRename => 'Omdøb';

  @override
  String get commonSort => 'Sortér';

  @override
  String get commonPlayAll => 'Afspil alle';

  @override
  String get sortName => 'Navn';

  @override
  String get sortTitle => 'Titel';

  @override
  String get sortArtist => 'Kunstner';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Tilføjet';

  @override
  String get commonClear => 'Ryd';

  @override
  String get sortRecentlyModified => 'Ændret for nylig';

  @override
  String get sortCreationDate => 'Oprettelsesdato';

  @override
  String get playlistNameHint => 'Navn';

  @override
  String get playlistNew => 'Ny spilleliste';

  @override
  String get playlistNewFolder => 'Ny mappe';

  @override
  String get playlistNewTooltip => 'Ny spilleliste / mappe';

  @override
  String get playlistAddTo => 'Føj til spilleliste';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Føj til $n spillelister',
      one: 'Føj til $n spilleliste',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Vælg en spilleliste';

  @override
  String get playlistFilterHint => 'Filtrér spillelister…';

  @override
  String get playlistSearchHint => 'Søg efter en spilleliste…';

  @override
  String get playlistNoMatch => 'Ingen spilleliste matcher';

  @override
  String get playlistNoneCreateHint => 'Ingen spillelister — opret en med +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre',
      one: '$n nummer',
      zero: 'Ingen numre',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Allerede tilføjet';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n emner findes allerede i de valgte spillelister.',
      one: '$n emne findes allerede i de valgte spillelister.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Spring dubletter over';

  @override
  String get playlistAddAgain => 'Tilføj igen';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre tilføjet',
      one: '$n nummer tilføjet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m spillelister',
      one: '$n spilleliste',
    );
    return '$_temp0 til $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Kunne ikke tilføje: $error';
  }

  @override
  String get playlistRenameTitle => 'Omdøb spilleliste';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Slet mappen “$name”?';
  }

  @override
  String get playlistDeleteFolderBody => 'Indholdet flyttes et niveau op.';

  @override
  String get playlistEmpty => 'Tom spilleliste';

  @override
  String get trackOptionsAddToLibrary => 'Føj til bibliotek';

  @override
  String get trackOptionsRemoveFromLibrary => 'Fjern fra bibliotek';

  @override
  String get trackOptionsAddedToLibrary => 'Nummeret er føjet til biblioteket';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'Nummeret er fjernet fra biblioteket';

  @override
  String get trackOptionsViewAlbum => 'Vis album';

  @override
  String get trackOptionsViewArtist => 'Vis kunstner';

  @override
  String get trackOptionsPlayNow => 'Afspil nu';

  @override
  String get trackOptionsPlayNext => 'Afspil næste';

  @override
  String get trackOptionsAddToQueueEnd => 'Føj til slutningen af køen';

  @override
  String get trackOptionsPlayLast => 'Afspil sidst';

  @override
  String get trackOptionsDeleteDownload => 'Slet download';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Slet denne download?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Filen og dens lokale poster (historik, numre) bliver slettet.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Download slettet';

  @override
  String get trackOptionsAddToFavorites => 'Føj til favoritter';

  @override
  String get trackOptionsRemoveFromFavorites => 'Fjern fra favoritter';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Albummet er føjet til favoritter';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Albummet er fjernet fra favoritter';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Albummet er ikke downloadet — intet at slette';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Slet det downloadede album?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Mappen og alle dens lokale poster (numre, historik) bliver slettet.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Albummet er slettet fra den lokale lagring';

  @override
  String get trackOptionsRedownloadAlbum => 'Download albummet igen';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Overskriver filer OG lokale poster';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Slet albummets filer';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Downloadet mappe + lokale poster (historik)';

  @override
  String get settingsTitle => 'Indstillinger';

  @override
  String get settingsGeneral => 'Generelt';

  @override
  String get settingsGeneralSubtitle => 'Tema';

  @override
  String get settingsVisualisation => 'Visualisering';

  @override
  String get settingsVisualisationSubtitle =>
      'Oscilloskoper, cover i baggrunden';

  @override
  String get settingsPlayback => 'Afspilning';

  @override
  String get settingsPlaybackSubtitle => 'Loops, fade-out, stilhed';

  @override
  String get settingsEngines => 'Motorer';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDataSubtitle => 'ID, historik, nulstilling';

  @override
  String get settingsBackupExport => 'Eksportér en sikkerhedskopi';

  @override
  String get settingsBackupExportSubtitle =>
      'Gem dit bibliotek, playlister og indstillinger i en fil';

  @override
  String get settingsBackupImport => 'Importér en sikkerhedskopi';

  @override
  String get settingsBackupImportSubtitle =>
      'Gendan dine data fra en sikkerhedskopifil';

  @override
  String get settingsBackupExportFailed =>
      'Eksport af sikkerhedskopi mislykkedes';

  @override
  String get settingsBackupImportConfirmTitle => 'Importér sikkerhedskopi?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Dette erstatter dit bibliotek, dine playlister og indstillinger på denne enhed. Downloadede filer bevares.';

  @override
  String get settingsBackupImportConfirm => 'Importér';

  @override
  String get settingsBackupImportedTitle => 'Sikkerhedskopi importeret';

  @override
  String get settingsBackupImportedBody =>
      'Dine data er gendannet. Genstart appen for at anvende alt.';

  @override
  String get settingsBackupTooNew =>
      'Denne sikkerhedskopi blev lavet af en nyere version af appen';

  @override
  String get settingsBackupInvalid => 'Ikke en gyldig Rewamp-sikkerhedskopi';

  @override
  String get settingsBackupImportFailed =>
      'Import af sikkerhedskopi mislykkedes';

  @override
  String get settingsAbout => 'Om';

  @override
  String get settingsAboutSubtitle => 'Credits og licenser';

  @override
  String get settingsCreditsSubtitle => 'Biblioteker, data og komponenter';

  @override
  String get settingsSupport => 'Kontakt og support';

  @override
  String get settingsSupportSubtitle => 'Kontakt os, websted';

  @override
  String get settingsSupportEmail => 'Send en e-mail';

  @override
  String get settingsSupportEmailSubtitle => 'Spørgsmål, fejl eller forslag';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — support';

  @override
  String get settingsSupportEmailIntro =>
      'Beskriv dit spørgsmål, din fejl eller dit forslag ovenfor. Oplysningerne nedenfor hjælper os med at hjælpe dig.';

  @override
  String get settingsSupportWebsite => 'Websted';

  @override
  String get settingsDonation => 'Støt Rewamp';

  @override
  String get settingsDonationSubtitle => 'Et lille tip, hvis du vil';

  @override
  String get settingsDonationBlurb =>
      'Rewamp er gratis og uden reklamer — et hjerteprojekt dedikeret til at bevare demoscene- og retrokulturen. Donationer hjælper med at finansiere udviklingen af appen og dække omkostningerne til databasens hosting. Ingen forpligtelse: hvis appen giver dig glæde, er en lille gestus altid velkommen.';

  @override
  String get settingsDonationFloppy => 'En diskette';

  @override
  String get settingsDonationCartridge => 'En kassette';

  @override
  String get settingsDonationBox => 'Et spil i æske';

  @override
  String get settingsDonationCustom => 'Vælg et beløb';

  @override
  String get settingsCancel => 'Annuller';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Slet';

  @override
  String get settingsReset => 'Nulstil';

  @override
  String get settingsRenew => 'Forny';

  @override
  String get settingsOff => 'Fra';

  @override
  String get settingsOn => 'Til';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Uendelig';

  @override
  String get settingsDefault => 'Standard';

  @override
  String get settingsCoreNoScope => 'uden oscilloskop';

  @override
  String get settingsNone => 'Ingen';

  @override
  String get settingsLevelLow => 'Lav';

  @override
  String get settingsLevelHigh => 'Høj';

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
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeLight => 'Lyst';

  @override
  String get settingsThemeDark => 'Mørkt';

  @override
  String get settingsArtworkTintTitle => 'Farv afspilleren efter coveret';

  @override
  String get settingsArtworkTintSubtitle =>
      'Afspilleren overtager coverets dominerende farve';

  @override
  String get settingsGlassEffectTitle => 'Liquid glass-effekt';

  @override
  String get settingsGlassEffectSubtitle =>
      'Linse og sløring på de nederste bjælker — slå fra på langsomme enheder';

  @override
  String get settingsResetSection => 'Nulstil dette afsnit';

  @override
  String get settingsResetEngine => 'Nulstil denne motor';

  @override
  String get settingsResetChoices => 'Nulstil disse valg';

  @override
  String get settingsResetToDefault => 'Standardværdi';

  @override
  String get settingsStartInVizTitle => 'Start i visualiseringstilstand';

  @override
  String get settingsStartInVizSubtitle =>
      'Afspilleren åbner på oscilloskoperne i stedet for coveret';

  @override
  String get settingsVoiceGridTitle => 'Gitter i stemmeoscilloskopet';

  @override
  String get settingsVoiceGridSubtitle => 'Vis kanterne mellem hver stemme';

  @override
  String get settingsKeepAwakeTitle => 'Hold skærmen tændt';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Mens en visualisering vises, dæmpes eller låses skærmen ikke';

  @override
  String get settingsVoiceNamesTitle => 'Stemmenavne';

  @override
  String get settingsVoiceNamesSubtitle => 'Vis hver stemmes navn i dens ramme';

  @override
  String get settingsLineThickness => 'Stregtykkelse';

  @override
  String get settingsScopeVoiceColor => 'Stemmeoscilloskop';

  @override
  String get settingsStereoColors => 'Stereo: farver';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo venstre';

  @override
  String get settingsStereoRightColor => 'Stereo højre';

  @override
  String get settingsNotePalette => 'Farvepalet';

  @override
  String get settingsNoteBoxStyle => 'Blokstil';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'Alle visualiseringer';

  @override
  String get settingsVizScopes => 'Oscilloskoper (stereo og pr. stemme)';

  @override
  String get settingsVizFrameRate => 'Billedhastighed';

  @override
  String get settingsVizFrameRateScreen => 'Skærm';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => 'Intensitet / hastighed';

  @override
  String get settingsArtworkOpacity => 'Baggrundscoverets opacitet';

  @override
  String get settingsProjectMTitle => 'projectM-indstillinger';

  @override
  String get settingsProjectMSubtitle => 'Presets, overgange, kvalitet, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Notifikationer ved sporskift';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Systemnotifikation med den nye tracks titel';

  @override
  String get settingsSilenceDetection => 'Registrering af stilhed';

  @override
  String get settingsCrossfade => 'Krydsfade';

  @override
  String get localActionPlay => 'Afspil filer eller en mappe';

  @override
  String get localActionImport => 'Importér filer eller en mappe';

  @override
  String localOpsImporting(String name) {
    return 'Importerer $name…';
  }

  @override
  String get localOpsImportingSelection => 'Importerer valgte filer…';

  @override
  String localOpsDeleting(String name) {
    return 'Sletter $name…';
  }

  @override
  String get localOpsPhaseCopying => 'kopierer';

  @override
  String get localOpsPhaseExtracting => 'udpakker';

  @override
  String get localOpsPhaseRegistering => 'føjer til biblioteket';

  @override
  String get localOpsPhaseDeleting => 'fjerner filer';

  @override
  String get localImportFiles => 'Importér filer';

  @override
  String get storageLocalImports => 'Lokale importer';

  @override
  String get settingsVgmJapaneseTags => 'Japanske tags (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'Foretrækker de japanske felter (titel, spil, kunstner) i VGM-tags, når de findes.';

  @override
  String get localImportFolder => 'Importér en mappe';

  @override
  String get localLibraryTitle => 'På denne enhed';

  @override
  String get libraryOnAnotherDevice => 'På en anden enhed';

  @override
  String get localLibraryEmpty =>
      'Ingen lokale importer endnu. Brug ”Importér filer” eller ”Importér en mappe” fra startsiden.';

  @override
  String queueLimitReached(int count) {
    return 'Køen er begrænset til de første $count numre';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return 'Slet ”$name”? Filen og tilhørende filer (omslag…) fjernes.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slet mappen ”$name” og dens $count numre?',
      one: 'Slet mappen ”$name” og dens $count nummer?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count numre importeret til biblioteket';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks numre importeret — $albums album';
  }

  @override
  String localImportFailed(String error) {
    return 'Import mislykkedes: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'Toner slutningen af hvert nummer over i starten af det næste. Ved 0 er afspilningen stadig uden pauser.';

  @override
  String get settingsMinSubsongSection => 'For korte delnumre';

  @override
  String get settingsMinSubsongTitle => 'Mindste længde';

  @override
  String get settingsMinSubsongHelp =>
      'Kortere delnumre holdes uden for listen og køen – en spilfil indeholder ofte flere lydeffekter end musik. Ved 0 udelades intet; en ukendt længde regnes aldrig som kort.';

  @override
  String get localNewFolder => 'Ny mappe';

  @override
  String get localFolderName => 'Mappenavn';

  @override
  String get localRename => 'Omdøb';

  @override
  String get localMoveTo => 'Flyt til…';

  @override
  String get localMove => 'Flyt';

  @override
  String get localMoveNothing => 'Intet blev flyttet';

  @override
  String get localNameInvalid => 'Ugyldigt navn';

  @override
  String get localNameTaken => 'Navnet er allerede i brug';

  @override
  String get localMoveIntoItself => 'En mappe kan ikke flyttes ind i sig selv';

  @override
  String get localManageFailed => 'Handlingen mislykkedes';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Sættes ikke i kø: under $seconds s (Indstillinger → Afspilning)';
  }

  @override
  String get settingsQueuePrefetchSection => 'Downloads i køen';

  @override
  String get settingsQueuePrefetchTitle => 'Hent hele køen';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'Én fil ad gangen; næste manglende nummer starter, så snart det forrige er hentet. Fra: kun næste nummer.';

  @override
  String get settingsCdRipDeclickSection => 'CD-rips';

  @override
  String get settingsCdRipDeclickTitle => 'Fjern klik ved starten af sporet';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'Dårlige CD-rips (mp3, ape, ogg, flac…) begynder ofte med nogle få korrupte samples. De repareres, indtil 200 ms rigtig musik er spillet; derefter træder filteret tilbage.';

  @override
  String get settingsSilenceSkipTitle => 'Spring til næste nummer ved stilhed';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Går automatisk videre, når udgangen forbliver tavs';

  @override
  String get settingsSilenceDelay => 'Forsinkelse for stilhed';

  @override
  String get settingsDefaultDuration => 'Standardvarighed';

  @override
  String get settingsDefaultDurationHelp =>
      'Bruges, når et nummer ikke oplyser nogen kendt varighed (intet tag, ingen servermetadata) — så det ikke spiller eller looper i det uendelige. Gælder aldrig for Amiga-numre (UADE), som har deres egen database over varigheder.';

  @override
  String get settingsForcedLoopHeader => 'Tvungne loops / fade-out';

  @override
  String get settingsForcedLoopHelp =>
      'Nogle formater looper et bestemt afsnit (VGM, tracker-moduler…); andre gør ikke. \"Uendelig\" ignorerer nummerets naturlige slutning.';

  @override
  String get settingsForceLoopCount => 'Tving antallet af loops';

  @override
  String get settingsLoopCount => 'Antal loops';

  @override
  String get settingsForceFadeout => 'Tving en fade-out';

  @override
  String get settingsFadeoutDuration => 'Varighed af fade';

  @override
  String get settingsResetEnginesTitle => 'Nulstil motorindstillingerne?';

  @override
  String get settingsResetEnginesBody =>
      'Alle motorindstillinger vender tilbage til standardværdierne.';

  @override
  String get settingsResetDefaultsTitle => 'Nulstil til standardværdier';

  @override
  String get settingsResetDefaultsSubtitle => 'Alle motorer';

  @override
  String get settingsDefaultDecoders => 'Standarddekodere';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formater som flere motorer kan afspille';

  @override
  String get settingsDecodersHelp =>
      'Nogle formater kan afspilles af flere motorer. Vælg hvilken der skal bruges som standard — alle andre formater dirigeres automatisk.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga-trackere (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackere — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Moduler, libopenmpt ikke læser — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — kvalitet, filtre, indstillinger pr. chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — højpasfilter';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont i brug';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolation, lavpas, ekko';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorering, hovedtelefoner, gain, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — clock, model, ReSIDfp-filtre';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — harmonisk stereo-/surroundtilstand';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, rumklang';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612-, OPL3-, QSound-kerner…';

  @override
  String get settingsMasterVolume => 'Masterlydstyrke';

  @override
  String get settingsAmplification => 'Forstærkning';

  @override
  String get settingsAmigaFilter => 'Amiga-filter';

  @override
  String get settingsInterpolation => 'Interpolation';

  @override
  String get settingsPolyphony => 'Polyfoni';

  @override
  String get settingsReverb => 'Rumklang';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'Denne MIDI-fil er skrevet til en Roland MT-32. Uden dens ROM\'er spilles den med SoundFonten, med instrumenterne oversat til General MIDI — importér ROM\'erne i Indstillinger › Motorer › Munt.';

  @override
  String get settingsMidiMt32ToGm => 'Tilpas MT-32-filer';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'En MIDI skrevet til Roland MT-32 nummererer sine programmer efter MT-32\'erens egen liste: oversat til det nærmeste General MIDI-instrument lyder de troværdige i stedet for tilfældige.';

  @override
  String get settingsInterpNone => 'Ingen';

  @override
  String get settingsInterpLinear => 'Lineær';

  @override
  String get settingsInterpCubic => 'Kubisk';

  @override
  String get settingsInterpSinc => 'Sinc (bedst)';

  @override
  String get settingsStereoSeparation => 'Stereoseparation';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Afslutter nummeret, når motoren registrerer en lang stilhed';

  @override
  String get settingsStereoDepth => 'Stereodybde';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — ingen effekt på SPC';

  @override
  String get settingsBass => 'Bas';

  @override
  String get settingsTreble => 'Diskant';

  @override
  String get settingsAppliedLive =>
      'Anvendes med det samme, også under afspilning.';

  @override
  String get settingsAppliedNextTrack =>
      'Anvendes på det næste nummer, der indlæses.';

  @override
  String get settingsSidEmulation => 'Emulering';

  @override
  String get settingsSidResidfp => 'ReSIDfp (præcis)';

  @override
  String get settingsSidLite => 'SIDLite (hurtig)';

  @override
  String get settingsSidSampling => 'Sampling';

  @override
  String get settingsSidSamplingInterp => 'Interpolation (hurtig)';

  @override
  String get settingsSidSamplingResample => 'Resample (bedst)';

  @override
  String get settingsSidClock => 'Clock';

  @override
  String get settingsSidModel => 'SID-model';

  @override
  String get settingsSidFilter => 'SID-filter';

  @override
  String get settingsSidForceSecond => 'Tving en 2. SID';

  @override
  String get settingsSidSecondSubtitle => '2SID-numre i stereo';

  @override
  String get settingsSidSecondAddr => 'Adresse på 2. SID';

  @override
  String get settingsSidForceThird => 'Tving en 3. SID';

  @override
  String get settingsSidThirdAddr => 'Adresse på 3. SID';

  @override
  String get settingsSidAutoFilter => 'Automatisk 6581-filterområde';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Værdi anbefalet for nummerets ophavsmand (sidplayfp-tabeller)';

  @override
  String get settingsSid6581Range => '6581-filterområde';

  @override
  String get settingsSid6581Curve => '6581-filterkurve';

  @override
  String get settingsSid8580Curve => '8580-filterkurve';

  @override
  String get settingsSidNote =>
      'SID-filter og -kurver anvendes med det samme; emulering/sampling/clock/model/2.-3. SID træder i kraft ved næste nummer.';

  @override
  String get settingsAudioOutput => 'Lydudgang';

  @override
  String get settingsAdplugNote =>
      'Surround: to let fejlstemte OPL-chips. Anvendes på det næste nummer.';

  @override
  String get settingsHeSpuMain => 'Hovedstemmer (SPU)';

  @override
  String get settingsHeSpuReverb => 'Rumklang (SPU)';

  @override
  String get settingsNsfQuality => 'Kvalitet (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Lavpasfilter';

  @override
  String get settingsHighpassFilter => 'Højpasfilter';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC tvunget';

  @override
  String get settingsNsfRegionPalForced => 'PAL tvunget';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy tvunget';

  @override
  String get settingsNsfForceIrq => 'Tving IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulser (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — trekant / støj / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Slå lyden til ved reset';

  @override
  String get settingsNsfPhaseRefresh => 'Opdater fasen';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Nulstil fasen, når perioden skrives';

  @override
  String get settingsNsfNonlinearMixer => 'Ikke-lineær miksning';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      '2A03\'ens rigtige miks (ellers lineært)';

  @override
  String get settingsNsfDutySwap => 'Byt om på duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Rækkefølgen af 25 % / 50 % duty';

  @override
  String get settingsNsfNegateSweep => 'Negativt sweep ved init';

  @override
  String get settingsNsfEnable4011 => 'Register \$4011 aktiveret';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Direkte DAC-udgang (originale klik)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodisk støj';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Støjgeneratorens korte tilstand';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM-antiklik';

  @override
  String get settingsNsfRandomizeNoise => 'Tilfældig støj ved init';

  @override
  String get settingsNsfTriangleMute => 'Slå trekanten fra';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Gør trekanten tavs ved ultrasoniske perioder';

  @override
  String get settingsNsfRandomizeTri => 'Tilfældig trekant ved init';

  @override
  String get settingsNsfDpcmReverse => 'Omvendt DPCM';

  @override
  String get settingsNsfN163Serial => 'Seriel multipleksing';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Den ægte N163-summen på flerstemmige numre';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fase i skrivebeskyttet tilstand';

  @override
  String get settingsNsfN163LimitWavelength => 'Begræns bølgelængden';

  @override
  String get settingsNsfFdsCutoff => 'Lavpas-cutoff';

  @override
  String get settingsNsfFds4085Reset => '\$4085-reset';

  @override
  String get settingsNsfFdsWriteProtect => 'Skrivebeskyttelse';

  @override
  String get settingsNsfVrc7Patch => 'Patch-sæt';

  @override
  String get settingsNsfVrc7Opll => 'OPLL-tilstand';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Emulér en YM2413 i stedet for VRC7';

  @override
  String get settingsGbsHpFilter => 'Højpasfilter (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klassisk GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Ekko';

  @override
  String get settingsUadePostfx => 'Efterbehandling';

  @override
  String get settingsUadePostfxSubtitle =>
      'Aktiverer effektkæden (kræves for alt nedenfor)';

  @override
  String get settingsUadePan => 'Panorering (stereoseparation)';

  @override
  String get settingsUadePanValue => 'Panoreringsmængde';

  @override
  String get settingsUadeHeadphones => 'Hovedtelefoner';

  @override
  String get settingsUadeLed => 'LED (Paula-filter)';

  @override
  String get settingsUadeLedAuto => 'Auto (pr. nummer)';

  @override
  String get settingsUadeLedOn => 'Tvunget TIL';

  @override
  String get settingsUadeLedOff => 'Tvunget FRA';

  @override
  String get settingsUadeFilterType => 'Filtertype';

  @override
  String get settingsUadeGain => 'Gain';

  @override
  String get settingsUadeGainValue => 'Gain-mængde';

  @override
  String get settingsSoundfontLoading => 'Indlæser kataloget…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Kataloget er ikke tilgængeligt ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Download mislykkedes: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importér en SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Vælg en .sf2-fil på denne enhed';

  @override
  String get settingsSoundfontImported => 'Importeret';

  @override
  String get settingsSoundfontInvalid => 'Filen er ikke en SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Import mislykkedes — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Slet filen';

  @override
  String get settingsCreditsHeader => 'Credits & licenser';

  @override
  String get settingsRightsNotice =>
      'Rewamp er en afspiller: den hoster ingen filer og distribuerer ingen musik. Numrene kommer fra online bevaringsarkiver og forbliver rettighedshavernes ejendom. Det er dit eget ansvar at sikre, at afspilning, download og opbevaring overholder de gældende rettigheder og lovgivningen i dit land.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formater understøttet',
      one: '$count format understøttet',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fordelt på $count afspilningsmotorer — se detaljerne',
      one: 'Håndteres af $count afspilningsmotor — se detaljerne',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga-varigheder & metadata';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb af Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64-/SID-data & covers';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadata og billeder til C64-spil.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2-skrifttype';

  @override
  String get settingsFt2FontSubtitle =>
      'Patternvisualiserens FastTracker II-stil bruger FT2-bitmapskrifttypen fra ft2-clone af 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url kopieret';
  }

  @override
  String get settingsOpenLink => 'Åbn linket';

  @override
  String get settingsEnginesHeader => 'Afspilningsmotorer';

  @override
  String get settingsComponentsHeader => 'Øvrige komponenter';

  @override
  String get settingsResetAll => 'Nulstil alle indstillinger';

  @override
  String get settingsResetAllSubtitle =>
      'Generelt, Visualisering, Afspilning, Motorer — ikke biblioteket';

  @override
  String get settingsResetAllTitle => 'Nulstil alle indstillinger?';

  @override
  String get settingsResetAllBody =>
      'Generelt, Visualisering, Afspilning og alle motorer vender tilbage til standardværdierne. Dit bibliotek og din historik røres ikke.';

  @override
  String get settingsRenewUserId => 'Forny det anonyme ID';

  @override
  String get settingsRenewUserIdTitle => 'Forny det anonyme ID?';

  @override
  String get settingsRenewUserIdBody =>
      'Der oprettes et nyt anonymt ID til serverstatistikken.\n\nDet gamle bliver ikke brugt længere. Din lokale historik og dine favoritter påvirkes ikke.';

  @override
  String get settingsRenewUserIdFailed => 'Mislykkedes — serveren kan ikke nås';

  @override
  String settingsNewUserId(String id) {
    return 'Nyt ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Intet ID registreret';

  @override
  String get settingsCleanDb => 'Ryd op i den lokale database';

  @override
  String get settingsCleanDbSubtitle =>
      'Fjerner poster, hvis fil ikke længere findes (slettede downloads, gamle fejl)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count forældreløse poster fjernet',
      one: '$count forældreløs post fjernet',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'Den lokale database er ren — intet at fjerne';

  @override
  String get settingsClearCache => 'Ryd cachen (covers & metadata)';

  @override
  String get settingsClearCacheSubtitle =>
      'Fjerner cachelagrede covers og hentede metadata (STIL, varigheder) — hentes igen ved næste afspilning';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cachen er ryddet ($count covers)',
      one: 'Cachen er ryddet ($count cover)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Lagerplads';

  @override
  String get storageSubtitle => 'Hvad appen gemmer på disken, med sletning';

  @override
  String get storageDownloads => 'Downloads';

  @override
  String get storageArtworkCache => 'Cover-cache';

  @override
  String get storageSoundfonts => 'SoundFonts';

  @override
  String get storagePresets => 'Visualizer-forudindstillinger';

  @override
  String get storageOpenedFiles => 'Åbnede filer';

  @override
  String get storageOpenedEmpty =>
      'Filer åbnet udefra (deling, ”Åbn med”, vælgeren på mobil) kopieres hertil.';

  @override
  String get storageInUse => 'i en playliste eller biblioteket';

  @override
  String get storageDeleteAll => 'Slet alle';

  @override
  String get storageClear => 'Ryd';

  @override
  String get storageDeleteSelection => 'Slet det valgte';

  @override
  String get storageSelectAll => 'Vælg alle';

  @override
  String get storageFilterHint => 'Filtrér efter navn';

  @override
  String get storageNoMatch => 'Ingen fil matcher filteret.';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valgt',
      one: '$count valgt',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slet $count filer?',
      one: 'Slet $count fil?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Slet $count filer? $inUse bruges af en playliste eller biblioteket — de poster mister deres fil.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Slet alle downloadede filer og deres biblioteksrækker? Favoritter og playlister beholder deres poster, men filerne skal downloades igen.';

  @override
  String get storageSoundfontsClearBody =>
      'Slet alle SoundFonts, også importerede? Katalogets hentes igen efter behov; importerede går tabt.';

  @override
  String get storagePresetsClearBody =>
      'Slet downloadede preset-pakker og importerede presets? Medfølgende beholdes; pakker hentes igen, importerede går tabt.';

  @override
  String get storageOpenedDeleteAllTitle => 'Slet åbnede filer';

  @override
  String get storageInUseDeleteTitle => 'Filen er i brug';

  @override
  String get storageInUseDeleteBody =>
      'En playliste eller biblioteket peger stadig på denne fil. Sletning efterlader posterne uden deres fil.';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filer — $size',
      one: '$count fil — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filer — $size · håndteres via album og numre',
      one: '$count fil — $size · håndteres via album og numre',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Slet $count filer? Filer brugt af en playliste eller biblioteket beholdes.',
      one:
          'Slet $count fil? Filer brugt af en playliste eller biblioteket beholdes.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Nulstil statistikken';

  @override
  String get settingsResetStatsSubtitle =>
      'Fjerner lyttehistorikken og afspilningstællerne';

  @override
  String get settingsClearStatsTitle => 'Nulstil statistikken?';

  @override
  String get settingsClearStatsBody =>
      'Dette sletter permanent:\n• hele lyttehistorikken\n• afspilningstællerne\n\nDine favoritter og dit bibliotek påvirkes ikke.';

  @override
  String get settingsStatsCleared => 'Statistikken er slettet';

  @override
  String get settingsResetDatabase => 'Nulstil databasen';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Sletter alt: historik, favoritter, spillelister, cache';

  @override
  String get settingsResetDbTitle => 'Nulstil databasen?';

  @override
  String get settingsCleanLocalTitle =>
      'Ryd op i lokale poster der ikke kan afspilles';

  @override
  String get cleanStageScan => 'Scanner poster…';

  @override
  String get cleanStageSync => 'Synkroniserer med din konto…';

  @override
  String get cleanStagePurge => 'Fjerner fra din konto…';

  @override
  String get cleanStageDelete => 'Fjerner lokalt…';

  @override
  String get settingsCleanLocalBody =>
      'Biblioteksposter der peger på en fil, som ikke længere findes på denne enhed. De fjernes også fra din konto og dermed fra dine andre enheder.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count poster fjernet',
      one: '$count post fjernet',
      zero: 'Intet at rydde op',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'Dette sletter permanent:\n• hele lyttehistorikken\n• alle tællere\n• alle favoritter\n• alle spillelister\n• alle cachelagrede metadata\n\nDine lydfiler bliver ikke slettet.';

  @override
  String get settingsDbReset => 'Databasen er nulstillet';

  @override
  String get settingsDeleteDownloads => 'Slet downloads';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Sletter alle filer i online-mappen (numre, covers)';

  @override
  String get settingsCleanAll => 'Ryd lokal database og cache';

  @override
  String get settingsCleanAllSubtitle =>
      'Fjerner poster uden fil, biblioteksposter der peger på filer på en anden enhed, og tømmer cachen for omslag og metadata';

  @override
  String get settingsCleanAllConfirmBody =>
      'Biblioteksposter der peger på filer på en anden enhed fjernes også fra din konto, altså fra dine andre enheder. Omslag og metadata hentes igen ved næste afspilning.';

  @override
  String get settingsDataAdvanced => 'Avanceret';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Hvert oprydningstrin for sig, cachen og nulstillingerne';

  @override
  String get settingsDataGroupDb => 'Database';

  @override
  String get settingsDataGroupCache => 'Cache';

  @override
  String get settingsDataGroupReset => 'Nulstil';

  @override
  String get settingsDeleteDownloadsTitle => 'Slet downloads?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Dette sletter permanent alle downloadede filer (numre, album, covers) fra online-mappen.\n\nPosterne i databasen bliver bevaret, men peger på filer, der ikke længere findes.';

  @override
  String get settingsDownloadsDeleted => 'Downloads slettet';

  @override
  String get settingsColor => 'Farve';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Tilfældigt næste preset';

  @override
  String get settingsPmRandomNextSubtitle => 'Fra: afspil presets i rækkefølge';

  @override
  String get settingsPmLockPreset => 'Lås presettet';

  @override
  String get settingsPmLockPresetSubtitle => 'Ingen automatisk skift';

  @override
  String get settingsPmPresetDuration => 'Tid mellem presets';

  @override
  String get settingsPmTransitions => 'Overgange';

  @override
  String get settingsPmBlend => 'Overgang med cross-fade';

  @override
  String get settingsPmBlendSubtitle => 'Fra: skift preset øjeblikkeligt';

  @override
  String get settingsPmTransitionStyle => 'Overgangsstil';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Mønsteret som overtoningen bruger';

  @override
  String get settingsPmTransitionRandom => 'Tilfældig';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Beat-synkroniseret presetskift';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minimumstid';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: følsomhed';

  @override
  String get settingsPmRendering => 'Rendering';

  @override
  String get settingsPmQuality => 'Kvalitet';

  @override
  String get settingsPmQualitySubtitle =>
      'Renderopløsning (Maks = native opløsning)';

  @override
  String get settingsPmBeatSensitivity => 'Beat-følsomhed';

  @override
  String get settingsPmAspectRatio => 'Respektér billedformatet';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'For de shaders, der understøtter det';

  @override
  String get settingsPmPermissive => 'Permissiv tilstand';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Indlæs .milk-filer med scriptfejl';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountSubtitle => 'Gem og synkroniser dit bibliotek';

  @override
  String get accountAnonymous => 'Anonym konto';

  @override
  String get accountAnonymousExplain =>
      'Dine favoritter og din historik ligger på serveren, men kun denne enhed kan nå dem. Tilføj en e-mailadresse for at finde dem igen andre steder.';

  @override
  String get accountEmailAttached =>
      'Adressen er bekræftet — kontoen kan gendannes';

  @override
  String get accountEmailPending => 'Adressen er ikke bekræftet endnu';

  @override
  String get accountInsecureStorage =>
      'Enhedens sikre lager er ikke tilgængeligt: kontoens id gemmes ukrypteret.';

  @override
  String get accountSaveCta => 'Gem min konto';

  @override
  String get accountStatSongs => 'Favoritnumre';

  @override
  String get accountStatAlbums => 'Favoritalbum';

  @override
  String get accountStatPlays => 'Afspilninger';

  @override
  String get accountCreatedLabel => 'Oprettet';

  @override
  String get accountSignOut => 'Log ud';

  @override
  String get accountRevoke => 'Log ud overalt';

  @override
  String get accountRevokeSubtitle => 'Logger alle andre enheder ud';

  @override
  String get accountRevokeBody =>
      'Alle andre enheder logges ud. Denne forbliver logget ind.';

  @override
  String get accountRevokeDone => 'Andre enheder logget ud';

  @override
  String get accountDelete => 'Slet min konto';

  @override
  String get accountDeleteSubtitle =>
      'Sletter kontoen og dens data på serveren. Kan ikke fortrydes.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favoritter og $lists afspilningslister slettes fra serveren. Det kan ikke fortrydes.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Dine downloads og denne enheds bibliotek berøres ikke.';

  @override
  String get accountDeleteDone => 'Kontoen er slettet';

  @override
  String get accountSignOutSubtitle =>
      'Enheden begynder forfra med en tom konto';

  @override
  String get accountSignOutTitle => 'Log ud?';

  @override
  String accountSignOutBody(String email) {
    return 'Du kan vende tilbage til kontoen med en kode sendt til $email.';
  }

  @override
  String get accountSignedOut => 'Logget ud';

  @override
  String get accountNoSignOut => 'Log ud er ikke tilgængelig';

  @override
  String get accountNoSignOutSubtitle =>
      'Uden en e-mailadresse ville kontoen være tabt for altid.';

  @override
  String get accountDetach => 'Frakobl adressen';

  @override
  String get accountDetachSubtitle =>
      'Kontoen bliver anonym igen, ingen data slettes';

  @override
  String get accountDetachBody =>
      'Uden adresse kan kontoen ikke længere findes fra en anden enhed.';

  @override
  String get accountDetachDone => 'Adressen er frakoblet';

  @override
  String get accountOffline => 'Kontoen er ikke tilgængelig offline';

  @override
  String get accountEmailTitle => 'E-mailadresse';

  @override
  String get accountEmailExplain =>
      'Vi sender dig en 6-cifret kode for at bekræfte adressen. Den bruges kun til at gendanne din konto.';

  @override
  String get accountEmailLabel => 'E-mailadresse';

  @override
  String get accountCodeTitle => 'Bekræftelseskode';

  @override
  String accountCodeExplain(String email) {
    return 'Kode sendt til $email. Den er gyldig i 10 minutter.';
  }

  @override
  String get accountCodeLabel => '6-cifret kode';

  @override
  String get accountSendCode => 'Send koden';

  @override
  String get accountVerify => 'Bekræft';

  @override
  String get accountResend => 'Send koden igen';

  @override
  String accountResendIn(int n) {
    return 'Send igen om $n s';
  }

  @override
  String get accountCheckSpam =>
      'Mailen kan være et minut undervejs — tjek også spammappen.';

  @override
  String get accountErrorInvalidEmail => 'Ugyldig adresse';

  @override
  String get accountErrorTooMany =>
      'For mange anmodninger, prøv igen om et par minutter';

  @override
  String get accountErrorInvalidCode => 'Forkert eller udløbet kode';

  @override
  String get accountErrorCodeLength => 'Koden har 6 cifre';

  @override
  String get albumOfflinePartial =>
      'Offline – viser det, der allerede er på denne enhed';

  @override
  String get accountErrorNetwork => 'Forbindelsen mislykkedes, prøv igen';

  @override
  String get accountMergeTitle => 'Skal dette bibliotek flettes?';

  @override
  String accountMergeBody(String email) {
    return 'Enhedens favoritter og historik føjes til kontoen $email. Det kan ikke fortrydes.';
  }

  @override
  String get accountMergeConfirm => 'Flet';

  @override
  String get accountCarryLocal => 'Behold denne enheds favoritter';

  @override
  String accountCarryLocalOn(int n) {
    return 'De $n favoritter og afspilningslister på denne enhed føjes til kontoen.';
  }

  @override
  String get accountCarryLocalOff =>
      'De slettes fra enheden og erstattes af kontoens. Downloadede filer bevares.';

  @override
  String get accountDropLocalTitle => 'Slet denne enheds data?';

  @override
  String get accountCreatedOk =>
      'Kontoen er gemt, dit bibliotek er i sikkerhed';

  @override
  String get accountMergedOk =>
      'Logget ind — dine lokale favoritter blev tilføjet';

  @override
  String get accountSignedInOk => 'Logget ind';

  @override
  String get playlistEntryMissing => 'Filen mangler på denne enhed';

  @override
  String get playlistEntryMissingRestorable =>
      'Filen mangler — kan hentes igen';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n mangler',
      one: '$n mangler',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Gem på min konto';

  @override
  String get playlistBackupSubtitle =>
      'Bevarer playlisten også efter en geninstallation';

  @override
  String get playlistBackupUpdate => 'Opdatér sikkerhedskopien';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Erstatter kontoens kopi med denne version';

  @override
  String get playlistBackupStop => 'Stop med at gemme';

  @override
  String get playlistBackupStopped => 'Sikkerhedskopi fjernet';

  @override
  String get playlistBackupDone => 'Playliste gemt';

  @override
  String get playlistBackupFailed => 'Kunne ikke gemme';

  @override
  String get playlistBackupNoAccount => 'Ingen konto på denne enhed';

  @override
  String get playlistSyncTooltip => 'Synkronisér med min konto';

  @override
  String get playlistSyncRunning => 'Synkroniserer…';

  @override
  String get playlistSyncDone => 'Playlister synkroniseret';

  @override
  String get playlistSyncPartial => 'Nogle playlister kunne ikke gemmes';

  @override
  String get playlistFetchMissing => 'Hent de manglende numre';

  @override
  String get playlistFetchDone => 'Manglende numre hentet';

  @override
  String get playlistFetchPartial => 'Nogle numre kunne ikke hentes';

  @override
  String get playlistEntryFetchFailed => 'Dette nummer kunne ikke hentes';

  @override
  String get accountStatPlaylists => 'Playlister';

  @override
  String get accountSyncNow => 'Synkronisér nu';

  @override
  String get accountSyncAuto => 'Sker af sig selv i baggrunden';

  @override
  String get accountSyncAnonymous =>
      'Sikkerhedskopieret til serveren. Tilføj en e-mail for at synkronisere en anden enhed.';

  @override
  String get accountSyncPending => 'Ændringer venter på at blive sendt';

  @override
  String accountSyncLast(String when) {
    return 'Seneste synkronisering: $when';
  }

  @override
  String get accountSyncDone => 'Synkronisering færdig';

  @override
  String get accountSyncFailed => 'Synkronisering mislykkedes, prøver igen';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'musik fra $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'indeholder $place i $compo';
  }

  @override
  String get competitionEmpty => 'Denne konkurrence har ingen bidrag';

  @override
  String get competitionEntryNoMusic =>
      'Ingen musik i kataloget til dette bidrag';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n numre',
      one: '$n nummer',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Spring over';

  @override
  String get onboardingNext => 'Næste';

  @override
  String get onboardingStart => 'Kom i gang';

  @override
  String get onboardingBetaTitle => 'Betaversion';

  @override
  String get onboardingBetaBody =>
      'Rewamp er stadig under opbygning. Lokale data — bibliotek, playlister, favoritter, statistik — kan blive nulstillet før version 1.0. Dine downloads er ikke i fare, men gem det, du holder af, et andet sted.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Udforsk';

  @override
  String get onboardingExploreBody =>
      'Gennemse og søg blandt titusindvis af chiptunes og trackermoduler fra de store onlinearkiver — efter kunstner, album, platform eller party. Tryk for at lytte, hent for at beholde.';

  @override
  String get onboardingLibraryTitle => 'Dit bibliotek';

  @override
  String get onboardingLibraryBody =>
      'Gem det, du kan lide, lav playlister og ordn dem i mapper. Det hentede spiller offline, og biblioteket følger dig mellem enheder, når du er logget ind.';

  @override
  String get onboardingPlayerTitle => 'Afspilleren';

  @override
  String get onboardingPlayerBody =>
      'Stryg for at skifte nummer, og åbn visualiseringerne: oscilloskop, kanaler, rullende noder, trackergitter. Filer med flere numre viser deres undernumre, og hver stemme kan dæmpes for sig.';

  @override
  String get onboardingReplayTitle => 'Introduktion';

  @override
  String get onboardingReplaySubtitle =>
      'Se betabeskeden og rundvisningen igen';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Trackergitter: farver, kolonner, rulning';

  @override
  String get patternOpaqueBg => 'Uigennemsigtig baggrund';

  @override
  String get patternOpaqueBgSubtitle => 'Skjuler coveret bag gitteret';

  @override
  String get commonSave => 'Gem';

  @override
  String get commonImport => 'Importér';

  @override
  String get accountDisplayName => 'Offentligt navn';

  @override
  String get accountDisplayNameNotSet =>
      'Ikke angivet — kræves for at udgive en playliste';

  @override
  String get accountDisplayNameHint => 'Navnet, du vil krediteres under.';

  @override
  String get accountDisplayNameChangeWarning =>
      'At ændre det sender alle dine udgivne playlister tilbage til gennemgang.';

  @override
  String get accountDisplayNameTaken => 'Navnet er taget. Vælg et andet.';

  @override
  String get accountDisplayNameLength => 'Mellem 2 og 40 tegn.';

  @override
  String get accountDisplayNameSaved => 'Offentligt navn gemt';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlister sendt tilbage til gennemgang: $n';
  }

  @override
  String get playlistPublish => 'Gør offentlig';

  @override
  String get playlistPublishSubtitle => 'Anmod om udgivelse (gennemgås først)';

  @override
  String get playlistPublishTitle => 'Udgiv denne playliste?';

  @override
  String get playlistPublishBody =>
      'Efter godkendelse er den synlig for alle, krediteret dit offentlige navn. Omslaget kommer fra numrene.';

  @override
  String get playlistPublishCta => 'Anmod';

  @override
  String get playlistPublishSubmitted => 'Sendt til gennemgang';

  @override
  String get playlistPublishPending => 'Venter på godkendelse';

  @override
  String get playlistPublishApproved => 'Offentlig';

  @override
  String playlistPublishRejected(String reason) {
    return 'Afvist: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Afvist';

  @override
  String get playlistPublishNeedName => 'Vælg navnet, du vil krediteres under';

  @override
  String get playlistPublishNeedTracks =>
      'Der kræves mindst 5 numre for at udgive';

  @override
  String get playlistPublishHasLocal =>
      'Filer fra din enhed kan ikke udgives — andre kan ikke afspille dem';

  @override
  String get playlistPublishTooManyPending =>
      'Du har allerede 3 playlister, der venter på godkendelse';

  @override
  String get playlistPublishRefused =>
      'Udgivelse afvist: tjek numrene og de ventende anmodninger';

  @override
  String get playlistPublishFailed => 'Udgivelsen mislykkedes';

  @override
  String get playlistPublishWithdrawn => 'Playlisten er privat igen';

  @override
  String get playlistUnpublish => 'Gør privat';

  @override
  String get playlistUnpublishSubtitle =>
      'Fjerner den fra de offentlige playlister';

  @override
  String get playlistRenamePublishedTitle => 'Omdøb en udgivet playliste?';

  @override
  String get playlistRenamePublishedBody =>
      'Det er navnet, der gennemgås: omdøbning sender playlisten tilbage til gennemgang og afpublicerer den imens. At tilføje eller omarrangere numre gør ikke.';

  @override
  String playlistByAuthor(String author) {
    return 'af $author';
  }

  @override
  String get settingsSpectrumMode => 'Spektrumtilstand';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Farvet';

  @override
  String get settingsSpectrumModeBeam => 'Stråle';

  @override
  String get settingsSpectrumModeLine => 'Linje';

  @override
  String get settingsSpectrumModeRing => 'Ring';

  @override
  String get settingsPianoMode => 'Klaverets udseende';

  @override
  String get settingsPianoModeRoll => 'Klaviaturer';

  @override
  String get settingsPianoModeFalling => 'Faldende noder';

  @override
  String get settingsPianoColor => 'Farver';

  @override
  String get settingsPianoColorVoice => 'Pr. stemme';

  @override
  String get settingsPianoColorInstrument => 'Pr. instrument';

  @override
  String get settingsPianoGlow => 'Glød på anslåede tangenter';

  @override
  String get settingsPianoLighting => 'Lys og skygger på tangenterne';

  @override
  String get settingsPianoVoiceNames => 'Stemmernes navne';

  @override
  String get featuredAdditionsHeader => 'Nyt i kataloget';

  @override
  String get featuredAdditionsCard => 'Netop tilføjet';

  @override
  String get featuredAdditionsPlaylist => 'De netop tilføjede numre';

  @override
  String get releaseNotesTitle => 'Nyheder';

  @override
  String get releaseNotesV7Cpu =>
      'Appen arbejder ikke længere i baggrunden, når intet afspilles: langt mindre processor og batteri.';

  @override
  String get releaseNotesV7VizIdle =>
      'Visualiseringer står stille, mens afspilningen er stoppet, og er begrænset til 60 billeder i sekundet (kan justeres).';

  @override
  String get releaseNotesV7Subsongs =>
      'Rettet: på PC Engine, Master System og Atari ST (.sndh) startede nogle numre sangen ved siden af.';

  @override
  String get releaseNotesV7Piano =>
      'Klavervisualiseringen forblev tom med PC Engine-musik.';

  @override
  String get releaseNotesV7Database =>
      'En database, der er blevet beskadiget af en opdatering, reparerer nu sig selv i stedet for at gøre biblioteket utilgængeligt.';

  @override
  String get releaseNotesDataReset =>
      'Lokale data blev nulstillet til denne beta. Bibliotek og playlister genopbygges fra kontoen; downloads skal hentes igen.';

  @override
  String get releaseNotesDismiss => 'Fortsæt';

  @override
  String get pmManagePresets => 'Administrer presets';

  @override
  String get pmPickTooltip => 'Vælg en preset';

  @override
  String get pmPickFilter => 'Filtrér presets';

  @override
  String get pmSourceTooltip => 'Presetkilde';

  @override
  String get pmAddToPlaylistTooltip => 'Føj preset til en spilleliste';

  @override
  String pmSlowPresetDropped(String name) {
    return '“$name” er for tungt til denne enhed og blev lagt til side.';
  }

  @override
  String get pmSlowDeviceTitle => 'Denne enhed er for langsom';

  @override
  String get pmSlowDeviceOff =>
      'Visualiseringen blev slået fra: denne enhed kan ikke følge med Milkdrop-forindstillinger.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count forindstillinger lagt til side',
      one: '$count forindstilling lagt til side',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'For langsomme på denne enhed. De springes over.';

  @override
  String get settingsPmSlowPresetsRestore => 'Gendan';

  @override
  String get pmSourceBundled => 'Indbyggede presets';

  @override
  String get pmSourceImports => 'Mine importer';

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
  String get pmNewPlaylist => 'Ny spilleliste…';

  @override
  String get pmPlaylistName => 'Spillelistens navn';

  @override
  String get pmAddedToPlaylist => 'Føjet til spillelisten';

  @override
  String get pmAlreadyInPlaylist => 'Findes allerede i spillelisten';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Gennemse';

  @override
  String get pmTabPlaylists => 'Spillelister';

  @override
  String get pmTabPopular => 'Populær';

  @override
  String get pmTabSetAside => 'Lagt til side';

  @override
  String get pmSetAsideEmpty =>
      'Intet lagt til side. Her havner forindstillinger, der får enheden under 6 fps.';

  @override
  String get pmSetAsideRestoreAll => 'Gendan alle';

  @override
  String get pmInstall => 'Installér';

  @override
  String get pmInstallQueued => 'Installation sat i kø';

  @override
  String get pmUninstall => 'Afinstallér';

  @override
  String get pmUninstalled => 'Pack fjernet';

  @override
  String get pmUse => 'Brug';

  @override
  String get pmDefaultPackBanner => 'Anbefalet startpack';

  @override
  String pmLicense(String license) {
    return 'Licens: $license';
  }

  @override
  String get pmPacksOffline => 'Serveren kan ikke nås';

  @override
  String get pmSearchPresets => 'Søg efter presets…';

  @override
  String get pmPlayNow => 'Afspil nu';

  @override
  String get pmDownloadAction => 'Download';

  @override
  String get pmDownloaded => 'Preset downloadet';

  @override
  String get pmDownloadFailed => 'Download mislykkedes';

  @override
  String pmPreviewing(String name) {
    return 'Afspiller: $name';
  }

  @override
  String get pmLocalSection => 'Mine spillelister';

  @override
  String get pmCuratedSection => 'Rewamp-spillelister';

  @override
  String get pmImportPlaylist => 'Download og brug';

  @override
  String get pmPlaylistImported => 'Spillelisten er klar';

  @override
  String get pmImportFiles => 'Importér filer…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets importeret',
      one: '$count preset importeret',
      zero: 'Ingen presets importeret',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets føjet til projectM-biblioteket';

  @override
  String get pmNoPlaylists => 'Ingen preset-spillelister endnu';

  @override
  String get pmSourceApplied => 'Presetkilde anvendt';

  @override
  String get pmPlaylistEmpty => 'Denne spilleliste er tom';

  @override
  String get pmDays7 => '7 dage';

  @override
  String get pmDays30 => '30 dage';

  @override
  String get pmDays365 => '1 år';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count afspilninger',
      one: '$count afspilning',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Installationen mislykkedes';

  @override
  String get pmSingleDownloads => 'Enkeltdownloads';

  @override
  String pmAvailableIn(String pack) {
    return 'Findes i $pack';
  }

  @override
  String get pmCleanUp => 'Ryd op';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets slettet',
      one: '$count preset slettet',
      zero: 'Intet at rydde op',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Lås denne preset';

  @override
  String get pmUnlockAction => 'Lås preset op';

  @override
  String get pmOrderRandom => 'Tilfældige presets';

  @override
  String get pmOrderSequential => 'Presets i rækkefølge';

  @override
  String get pmUpdateAvailable => 'Opdatering tilgængelig';

  @override
  String get pmUpdate => 'Opdater';

  @override
  String get pmSelectAll => 'Vælg alle';

  @override
  String get pmSelectNone => 'Fravælg alle';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valgt',
      one: '$count valgt',
      zero: 'Intet valgt',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Ubrugte teksturer';

  @override
  String pmTexturesFreed(String size) {
    return '$size frigjort';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teksturer',
      one: '$count tekstur',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'Hitlister';

  @override
  String get chartsGlobal => 'Globalt';

  @override
  String get chartsByCollection => 'Efter samling';

  @override
  String get chartsTopSongs => 'Topnumre';

  @override
  String get chartsTopAlbums => 'Topalbum';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Udgivne lister';

  @override
  String chartsUpdated(String date) {
    return 'Opdateret $date';
  }

  @override
  String get chartsSource => 'Kilde';

  @override
  String get settingsMidiSynth => 'MIDI-synthesizer';

  @override
  String get settingsMidiSynthAuto =>
      'Automatisk (MT-32 når filen beder om det)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (emulering)';

  @override
  String get settingsMt32Section => 'Roland MT-32-emulering';

  @override
  String get settingsMt32RomsTitle => 'MT-32-ROM\'er';

  @override
  String get settingsMt32RomsMissing =>
      'Intet brugbart ROM-sæt — importér kontrol- og PCM-ROM fra en MT-32 eller CM-32L';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Aktivt sæt: $set';
  }

  @override
  String get settingsMt32Import => 'Importér ROM-filer…';

  @override
  String get settingsMt32ImportSubtitle =>
      'Kontrol- + PCM-ROM (.rom/.bin), MAME-halvdele accepteres. ROM\'er følger ikke med appen.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name er ikke en kendt MT-32-/CM-32L-ROM';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ROM-filer importeret',
      one: '$count ROM-fil importeret',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Model';

  @override
  String get settingsMt32ModelAuto => 'Automatisk (CM-32L hvis tilgængelig)';

  @override
  String get settingsMt32Reverb => 'Rumklang';

  @override
  String get engineDescMt32 =>
      'Roland MT-32-/CM-32L-emulering til MIDI (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Miniafspiller';

  @override
  String get miniWindowExit => 'Tilbage til hovedvinduet';

  @override
  String get miniWindowIdle => 'Intet afspilles';

  @override
  String get settingsAlwaysOnTopTitle => 'Altid øverst';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Holder vinduet over alle andre — både hovedvinduet og miniafspilleren';

  @override
  String get windowAlwaysOnTopOn => 'Altid øverst: til';

  @override
  String get miniWindowCoverFill => 'Zoom omslaget, så det fylder feltet';

  @override
  String get miniWindowCoverFit => 'Vis hele omslaget';

  @override
  String get releaseNotesV7Mt32 =>
      'Ny Roland MT-32-motor til MIDI-spilmusik, med dine egne ROM-filer. Uden ROM-filer tilpasses en MIDI skrevet til MT-32 til General MIDI.';

  @override
  String get releaseNotesV7Xmp =>
      'Ti sjældne modulformater afspilles nu (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'Westwoods AdLib-musik (.adl) afspiller alle sine numre, og BP SoundMon V1 genkendes på Amiga.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac: en miniafspiller, kompakt eller med visualiseringen, og indstillingen »Altid øverst«.';

  @override
  String get releaseNotesV7Instruments =>
      'Oscilloskop, noder og klaver kan navngive og farvelægge hvert instrument, ikke kun hver stemme.';

  @override
  String get releaseNotesV7Podium =>
      'Søgning: filtrer de numre, der blev nr. 1, 2 eller 3 i en demoscene-konkurrence.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'For korte delnumre (lydeffekter fra spil) udelades fra »Afspil alle« — tærskel under Indstillinger → Afspilning.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Dine importer: slip en hel mappe (arkiver pakkes ud), og opret, omdøb eller flyt mapper.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI: trommerne lyder ikke længere som et klaver, og lydstyrken klipper ikke længere.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM: forudindstillinger gentages ikke længere fra én opstart til den næste, og en forudindstilling sorteres ikke længere fejlagtigt fra efter en pause.';

  @override
  String get libraryFileMissing => 'Filen mangler';
}
