// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian (`no`).
class AppLocalizationsNo extends AppLocalizations {
  AppLocalizationsNo([String locale = 'no']) : super(locale);

  @override
  String get navHome => 'Hjem';

  @override
  String get navSearch => 'Søk';

  @override
  String get navLocal => 'Lokalt';

  @override
  String get settingsTabsOrderTitle => 'Rekkefølge på faner';

  @override
  String get settingsTabsOrderSubtitle =>
      'Dra for å ordne. De fire første vises i bunnlinjen, resten under «Mer».';

  @override
  String get settingsTabsInBar => 'I linjen';

  @override
  String get settingsTabsInMore => 'Under «Mer»';

  @override
  String get settingsLaunchTab => 'Fane ved oppstart';

  @override
  String get settingsLaunchTabSubtitle => 'Hvilken fane appen åpner på';

  @override
  String get navLibrary => 'Bibliotek';

  @override
  String get noFileSelected => 'Ingen fil valgt';

  @override
  String get openFile => 'Åpne fil';

  @override
  String get pickerLabelAudio => 'Lyd';

  @override
  String get formatNotSupported => 'Formatet støttes ikke';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Ikke-støttet format: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Ikke på denne enheten: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Filen finnes ikke lenger på serveren: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file finnes ikke i albumets arkiv — rippen lister filen, men leverer den ikke.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host svarte ikke. Sjekk tilkoblingen og prøv igjen.';
  }

  @override
  String get failedToLoadFile => 'Kunne ikke laste filen';

  @override
  String get libraryEmptyHint =>
      'Artistene, albumene og spillelistene dine\nvises her.';

  @override
  String get libraryPlaylists => 'Spillelister';

  @override
  String get libraryArtists => 'Artister';

  @override
  String get libraryAlbums => 'Album';

  @override
  String get libraryTracks => 'Spor';

  @override
  String get libraryFavorites => 'Favoritter';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatisk spilleliste med favorittsporene dine';

  @override
  String get libraryRecentlyAdded => 'Nylig lagt til';

  @override
  String get libraryEmpty => 'Ingenting her ennå';

  @override
  String get libraryRemoved => 'Fjernet fra biblioteket';

  @override
  String get searchHint => 'Søk…';

  @override
  String get searchTypePlaceholder => 'Skriv en tittel, artist eller album…';

  @override
  String get searchNoResults => 'Ingen resultater';

  @override
  String get searchDownloading => 'Laster ned…';

  @override
  String searchError(String message) {
    return 'Feil: $message';
  }

  @override
  String get tabAll => 'Spor';

  @override
  String get tabArtists => 'Artister';

  @override
  String get tabAlbums => 'Album';

  @override
  String get tabProductions => 'Produksjoner';

  @override
  String get filterWithVideo => 'Med video';

  @override
  String get videoUnavailable => 'Denne videoen er utilgjengelig';

  @override
  String get noItems => 'Ingen elementer';

  @override
  String get sortRelevance => 'Relevans';

  @override
  String get sortAZ => 'A–Å';

  @override
  String get recentlyPlayed => 'Nylig spilt';

  @override
  String get noRecentTracks => 'Ingen nylig spilte spor';

  @override
  String get playerSourceLocal => 'lokal';

  @override
  String get homePlayFiles => 'Spill av filer';

  @override
  String get homePlayFolder => 'Spill av en mappe';

  @override
  String get homeSectionsOrderTitle => 'Rekkefølge på seksjoner';

  @override
  String get homeSectionsOrderSubtitle =>
      'Dra for å ordne startskjermen slik du vil.';

  @override
  String get homeSectionsOrderReset => 'Standardrekkefølge';

  @override
  String get homeSectionsOrderSettings => 'Rekkefølge på startseksjoner';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total resultater';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded lastet…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded resultater';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded lastet — rull for å laste mer';
  }

  @override
  String countNLoaded(int n) {
    return '$n lastet';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n fil(er)';
  }

  @override
  String get browseFilterByTitle => 'Filtrer etter tittel…';

  @override
  String get browseNoSongs => 'Ingen sanger tilgjengelig';

  @override
  String get browseByFormat => 'Etter format';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtrer etter format…';

  @override
  String get browseByPlatform => 'Etter plattform';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Plattformnavn…';

  @override
  String get browseByChip => 'Etter lydbrikke';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'f.eks. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Etter artist';

  @override
  String get browseByArtistSubtitle => 'Bla gjennom komponistene';

  @override
  String get browseFilterByName => 'Filtrer etter navn…';

  @override
  String get browseNoArtistFound => 'Ingen artist funnet';

  @override
  String get browseNoArtistsAvailable => 'Ingen artister tilgjengelig';

  @override
  String get browseNoArtist => 'Ingen artister';

  @override
  String get browseNoAlbum => 'Ingen album';

  @override
  String get browseTopPacks => 'Topp-pakker';

  @override
  String get browseTopPacksSubtitle => 'De best vurderte pakkene';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Topp-pakker — $collection';
  }

  @override
  String get browseLatestPacks => 'Siste pakker';

  @override
  String get browseLatestPacksSubtitle => 'De nyeste tilleggene';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Siste pakker — $collection';
  }

  @override
  String get browseAllSongs => 'Alle sanger';

  @override
  String get browseAllSongsSubtitleAlpha =>
      'Bla gjennom i alfabetisk rekkefølge';

  @override
  String get browseAlphabetical => 'I alfabetisk rekkefølge';

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
  String get browseIndexing => 'Indeksering pågår';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrer $name…';
  }

  @override
  String get browseAllYears => 'Alle år';

  @override
  String get browseAllYearsSubtitle => 'Alle sangene fra partyet';

  @override
  String get browseNoCompo => 'Ingen compo indeksert for dette partyet.';

  @override
  String get browseOthers => 'Andre';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bidrag — rangering',
      one: '$n bidrag — rangering',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Spill spillelisten';

  @override
  String get browsePlayAllRanked => 'Spill alle (i rangert rekkefølge)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor — rangert rekkefølge',
      one: '$n spor — rangert rekkefølge',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Bla gjennom etter album';

  @override
  String get browsePlayAll => 'Spill alle';

  @override
  String get browseShuffle => 'Tilfeldig rekkefølge';

  @override
  String get browseSearchInFolder => 'Søk i denne mappen…';

  @override
  String get browseFilterThisList => 'Filtrer denne listen…';

  @override
  String get browseSearchSubfolders => 'Søk i undermapper';

  @override
  String get browseEmptyFolder => 'Tom mappe';

  @override
  String browsePlaybackError(String message) {
    return 'Avspilling mislyktes: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor',
      one: '$n spor',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Visning';

  @override
  String get browseViewList => 'Liste';

  @override
  String get browseViewGrid => 'Rutenett';

  @override
  String get browseViewGridCompact => 'Kompakt rutenett';

  @override
  String get browseSearchAlbum => 'Søk etter et album…';

  @override
  String get browseSearchArtist => 'Søk etter en artist…';

  @override
  String get browsePlayAlbum => 'Spill albumet';

  @override
  String get searchDownloadingAlbum => 'Laster ned album…';

  @override
  String get searchCategoryChip => 'Brikker';

  @override
  String get searchCategoryGroup => 'Grupper';

  @override
  String get artistRealName => 'Virkelig navn';

  @override
  String get artistAliases => 'Aliaser';

  @override
  String get artistBorn => 'Født';

  @override
  String get artistInterview => 'Intervju';

  @override
  String get audioOutput => 'Lydutgang';

  @override
  String get audioOutputSystemDefault => 'Systemstandard';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notater';

  @override
  String get notePlacedBadge => 'Plassert i konkurransen';

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
  String get groupViewSongs => 'Vis låter';

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
  String get searchCategoryParty => 'Partyer';

  @override
  String get searchCategoryYear => 'År';

  @override
  String get searchCategoryOrigin => 'Opphav';

  @override
  String get searchCategoryProduction => 'Produksjon';

  @override
  String get searchCategoryProductionType => 'Prod-typer';

  @override
  String get searchCategoryPublisher => 'Utgivere';

  @override
  String get searchCategoryDeveloper => 'Utviklere';

  @override
  String get searchCategoryArcadeBoard => 'Arkadekort';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Sjanger';

  @override
  String get searchViaArtist => 'via artisten';

  @override
  String get searchViaAlbum => 'via et album';

  @override
  String get searchViaSong => 'via en sang';

  @override
  String get searchSortPopular => 'Populær';

  @override
  String get searchSortYear => 'År';

  @override
  String get searchSortRandom => 'Tilfeldig';

  @override
  String get searchSortRating => 'Vurdering';

  @override
  String statsTopPercent(int percent) {
    return 'Topp $percent %';
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
  String get searchSortDesc => 'Synkende';

  @override
  String get searchFilters => 'Filtre';

  @override
  String get searchExactSearch => 'Eksakt søk';

  @override
  String get searchExactSearchSubtitle => 'Slår av omtrentlig (fuzzy) søk';

  @override
  String get searchTags => 'Tagger';

  @override
  String searchTagSearchHint(String category) {
    return 'Søk etter en tagg i « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Skriv for å søke etter tagger.';

  @override
  String get searchTagsAndLogic => 'Flere tagger = logisk OG.';

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
      'Filtrering på år utelater sanger uten årstall.';

  @override
  String get searchMinRating => 'Vurdering ≥';

  @override
  String get searchPodium => 'Pallplass';

  @override
  String get searchPodiumAny => 'Hvilken som helst pallplass';

  @override
  String get searchPodiumUnavailable =>
      'Pallfilteret er ikke tilgjengelig på serveren ennå';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Avbryt';

  @override
  String get searchReset => 'Nullstill';

  @override
  String get searchApply => 'Bruk';

  @override
  String get searchClearRecent => 'Tøm nylige søk';

  @override
  String get searchBrowse => 'Bla gjennom';

  @override
  String get searchBrowseHint =>
      'Velg en fasett (gruppe, brikke, år…) for å utforske katalogen, eller start Radio/Overraskelse ovenfor.';

  @override
  String get searchDidYouMean => 'Få resultater — prøve et omtrentlig søk?';

  @override
  String get searchYes => 'Ja';

  @override
  String get featuredCommunityTitle => 'Nytt fra fellesskapet';

  @override
  String get searchPlaylistSourceAll => 'Alle';

  @override
  String get searchPlaylistSourceUser => 'Fellesskap';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Plattform';

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
  String get searchRadioTooltip => 'Tilfeldig kø basert på gjeldende filtre';

  @override
  String get searchSurprise => 'Overraskelse';

  @override
  String get searchSurpriseTooltip => 'En tilfeldig sang';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Ingen sanger';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sanger',
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
  String get searchChooseCollection => 'Velg samling';

  @override
  String get searchFilterCollections => 'Filtrer samlinger…';

  @override
  String get searchFilterPlaceholder => 'Filtrer…';

  @override
  String searchAllOf(String label) {
    return 'Alle ($label)';
  }

  @override
  String get searchNoMatch => 'Ingen treff';

  @override
  String get searchNoPlaylist => 'Ingen spillelister';

  @override
  String get engineDescOpenmpt => 'Tracker-moduler (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Moduler libopenmpt ikke leser (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — lydbrikker, scope per kanal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN-arkiver';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — stemmer per kanal';

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
      'Fler-brikke chiptunes .fur / FamiTracker .ftm';

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
      'Atari ST .sndh — ekte 68000-emulering + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300-emulering + RSP-lyd';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ-emulering';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound-brikke';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — ekte AY-3-8910/YM2149-synth';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixels egen motor';

  @override
  String get engineDescPxtone => 'Pixels tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — ekte 68000 via emu68';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA-FM + SSG + PPZ8-samplinger';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ .pdx-samplinger), YM2151-FM';

  @override
  String get engineDescFmp => 'PC-98 FMP-driver — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612-FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Tapsfri .ape';

  @override
  String get engineDescVgmstream =>
      'Strømmede lydformater fra spill (700+, inkl. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — reservedekoder';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total sanger',
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
      other: '$loaded / $total artister',
      one: '$loaded / 1 artist',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sanger',
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
      other: '$n artister',
      one: '$n artist',
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
  String get browseCountries => 'Land';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n land',
      one: '$n land',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Mapper';

  @override
  String get featuredTitle => 'Dagens utvalgte';

  @override
  String featuredPartyNow(String party) {
    return '$party pågår akkurat nå — pallplassene fra tidligere utgaver';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          '$party starter om $days dager — pallplassene fra tidligere utgaver',
      one: '$party starter i morgen — pallplassene fra tidligere utgaver',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series-sesong — pallplassene fra tidligere utgaver';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Utgitt i $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'For $age år siden: spillene fra $year',
      one: 'For ett år siden: spillene fra $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade-tallet';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'For $age år siden: spillene fra $year',
      one: 'For ett år siden: spillene fra $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Utgitt i $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Jubileer';

  @override
  String get featuredBirthdayHeader => 'Dagens bursdager';

  @override
  String get featuredBirthdayWeekHeader => 'Ukens fødselsdager';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist har fødselsdag denne uken';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spillelister',
      one: '$count spilleliste',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Prøv igjen';

  @override
  String get commonOptions => 'Alternativer';

  @override
  String get commonDownload => 'Last ned';

  @override
  String get commonDeleteDownload => 'Slett nedlastingen';

  @override
  String get commonAddToPlaylist => 'Legg til i spilleliste';

  @override
  String get commonPlayNext => 'Spill neste';

  @override
  String get commonAddToQueueEnd => 'Legg til sist i køen';

  @override
  String get commonAddToFavorites => 'Legg til i favoritter';

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
  String get subsongDeleteDownloadTitle => 'Slette denne nedlastingen?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Filen og de lokale oppføringene (historikk, spor) blir slettet.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Kunne ikke lese sporene';

  @override
  String subsongTrackNumber(int number) {
    return 'Spor $number';
  }

  @override
  String get subsongDefaultTrack => 'Standardspor';

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
  String get subsongPlayAll => 'Spill alle';

  @override
  String get albumDownloading => 'Laster ned album…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Laster ned album… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks => 'Last ned albumet for å se sporene';

  @override
  String get albumNotDownloadedHint =>
      'Albumet er ikke lastet ned — start avspilling for å laste det ned';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spor',
      one: '$count spor',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Laster detaljer…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Spill albumet';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementer',
      one: '$count element',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Spill dette sporet fra søket først for å laste det ned';

  @override
  String get libraryAddedTrack => 'Sporet er lagt til i biblioteket';

  @override
  String get libraryAddedAlbum => 'Albumet er lagt til i biblioteket';

  @override
  String get libraryAddedArtist => 'Artisten er lagt til i biblioteket';

  @override
  String get libraryRemovedTrack => 'Sporet er fjernet fra biblioteket';

  @override
  String get libraryRemovedAlbum => 'Albumet er fjernet fra biblioteket';

  @override
  String get libraryRemovedArtist => 'Artisten er fjernet fra biblioteket';

  @override
  String get libraryImportBeforeAddTitle => 'Importere først?';

  @override
  String get libraryImportBeforeAddBody =>
      'Denne filen spilles fra et midlertidig sted som systemet kan tømme. Importere den til det lokale biblioteket så oppføringen overlever?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'Dette sporet kommer fra et arkiv som er åpnet i en midlertidig hurtigbuffer. Hele arkivet importeres til det lokale biblioteket, følgefiler inkludert.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'Kan ikke legge til sporet: katalog-ID-en er ukjent på denne enheten.';

  @override
  String songTilePlayFailed(String message) {
    return 'Avspilling mislyktes: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Nedlasting mislyktes — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Laster ned — $label';
  }

  @override
  String get downloadsTitle => 'Nedlastinger';

  @override
  String get downloadsEmpty => 'Ingen ventende nedlastinger';

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Fortsett';

  @override
  String get downloadsCancel => 'Avbryt nedlastingen';

  @override
  String get downloadsClear => 'Fjern alle';

  @override
  String get downloadsPausedBanner =>
      'Nedlastinger på pause — gjeldende fil fullføres først';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Laster ned — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Spilleliste';

  @override
  String get miniPlayerHideQueue => 'Skjul spillelisten';

  @override
  String get transportShuffle => 'Tilfeldig rekkefølge';

  @override
  String get transportShuffleOn => 'Tilfeldig rekkefølge på';

  @override
  String get transportLoopOff => 'Gjenta: av';

  @override
  String get transportLoopQueue => 'Gjenta: køen';

  @override
  String get transportLoopTrack => 'Gjenta: gjeldende spor';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spektrum';

  @override
  String get vizVoices => 'Stemmer';

  @override
  String get vizNotes => 'Noter';

  @override
  String get vizPiano => 'Piano';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Rullemodus';

  @override
  String get patternSmoothScroll => 'Jevn rulling';

  @override
  String get patternPinnedRow => 'Festet aktiv rad';

  @override
  String get patternVolumeBars => 'Volumsøyler';

  @override
  String get patternColorScheme => 'Fargeskjema';

  @override
  String get patternSize => 'Størrelse';

  @override
  String get patternColumns => 'Kolonner';

  @override
  String get patternColumnsAll => 'Fullstendig';

  @override
  String get patternColumnsNoteInstr => 'Redusert';

  @override
  String get patternColumnsNote => 'Minimal';

  @override
  String get vizClose => 'Lukk visualiseringen';

  @override
  String get vizFullscreen => 'Fullskjerm';

  @override
  String get vizExitFullscreen => 'Avslutt fullskjerm';

  @override
  String get vizPrevPreset => 'Forrige preset';

  @override
  String get vizNextPreset => 'Neste preset';

  @override
  String get vizProjectmUnavailable => 'projectM er utilgjengelig';

  @override
  String get voicesTitle => 'Stemmer';

  @override
  String get voicesNone => 'Ingen stemmer for dette sporet.';

  @override
  String get voicesLongPressSolo => 'langt trykk = solo';

  @override
  String get voicesMuteAll => 'Demp alle';

  @override
  String get voicesUnmuteAll => 'Opphev demping av alle';

  @override
  String get voicesStereoOutput => 'Stereoutgang';

  @override
  String get voicesLeft => 'Venstre';

  @override
  String get voicesRight => 'Høyre';

  @override
  String get enginesFormatsTitle => 'Spillbare formater';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats spillbare formater, fordelt på $engines avspillingsmotorer.';
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
    return 'Cover av $title av $artist';
  }

  @override
  String stilCover(String work) {
    return 'Cover av $work';
  }

  @override
  String get playerQueue => 'Kø';

  @override
  String get queueEdit => 'Rediger';

  @override
  String get queueEditDone => 'Ferdig';

  @override
  String get queueClear => 'Tøm køen';

  @override
  String get queueClearConfirmTitle => 'Tømme køen?';

  @override
  String get queueClearConfirmBody => 'Køen tømmes og avspillingen stopper.';

  @override
  String get queueClearConfirm => 'Tøm';

  @override
  String get queueRemoveSelected => 'Fjern valgte';

  @override
  String get queueRemoveTrack => 'Fjern fra køen';

  @override
  String get queueReorder => 'Endre rekkefølge';

  @override
  String get playerArtwork => 'Omslag';

  @override
  String get playerVisualizer => 'Visualisering';

  @override
  String get playerVoices => 'Stemmer';

  @override
  String get playerTrackInfo => 'Sporinfo';

  @override
  String get playerShowQueue => 'Spilleliste';

  @override
  String get playerHideQueue => 'Skjul spillelisten';

  @override
  String get playerNoTrackInfo => 'Ingen informasjon tilgjengelig.';

  @override
  String get playerViewSubsongs => 'Vis subsongs';

  @override
  String get playerViewAlbum => 'Vis albumet';

  @override
  String get playerViewArtist => 'Vis artisten';

  @override
  String get playerAddToPlaylist => 'Legg til i spilleliste';

  @override
  String get playerEngineSettings => 'Motorinnstillinger';

  @override
  String get queueAddToPlaylist => 'Legg køen til i en spilleliste';

  @override
  String get playerMoreOptions => 'Flere alternativer';

  @override
  String get playerClose => 'Lukk';

  @override
  String get playerCancel => 'Avbryt';

  @override
  String get playerDelete => 'Slett';

  @override
  String get playerAddFavorite => 'Legg til i favoritter';

  @override
  String get playerRemoveFavorite => 'Fjern fra favoritter';

  @override
  String get playerAddToLibrary => 'Legg til i biblioteket';

  @override
  String get playerRemoveFromLibrary => 'Fjern fra biblioteket';

  @override
  String get playerAddedToLibrary => 'Sporet er lagt til i biblioteket';

  @override
  String get playerRemovedFromLibrary => 'Sporet er fjernet fra biblioteket';

  @override
  String get playerDeleteDownload => 'Slett nedlastingen';

  @override
  String get playerRedownload => 'Last ned filen på nytt';

  @override
  String get playerRedownloadUnavailable =>
      'Nedlasting på nytt er ikke tilgjengelig for denne filen';

  @override
  String get playerDeleteDownloadTitle => 'Slette nedlastingen?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Filen og de lokale oppføringene (historikk, spor) blir slettet.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Dine trender';

  @override
  String get homeYourAllTimeTop => 'Din topp gjennom tidene';

  @override
  String get homeTrending => 'Trender';

  @override
  String get homeFeaturedPlaylists => 'Utvalgte spillelister';

  @override
  String get homeAllTimeTop => 'Topp gjennom tidene';

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
      other: '$n avspillinger',
      one: '$n avspilling',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor',
      one: '$n spor',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Tom eller uleselig spilleliste';

  @override
  String get homeExtractingArchive => 'Pakker ut arkivet…';

  @override
  String get homeArchiveEmpty => 'Ingen spillbare filer i arkivet';

  @override
  String get homeNothingPlayable => 'Ingenting spillbart i utvalget';

  @override
  String get homeAlbumLoadFailed => 'Kunne ikke laste dette albumet';

  @override
  String get homeSongLoadFailed => 'Kunne ikke laste dette sporet';

  @override
  String get navStats => 'Statistikk';

  @override
  String get navSettings => 'Innstillinger';

  @override
  String get playlistMoveUp => 'Flytt til overordnet mappe';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spillelister',
      one: '$n spilleliste',
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
      'Denne mappen og alt innhold slettes permanent:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Denne mappen slettes.';

  @override
  String get playlistFolderRoot => 'Rot';

  @override
  String get playlistMoveToFolder => 'Flytt til mappe';

  @override
  String playlistDeleteTitle(String name) {
    return 'Slette \"$name\"?';
  }

  @override
  String get playlistDeleteBody => 'Denne spillelisten slettes permanent.';

  @override
  String get playlistRenameFolderTitle => 'Gi mappe nytt navn';

  @override
  String get playlistClearFavorites => 'Slett alle favoritter';

  @override
  String get playlistClearFavoritesTitle => 'Slette alle favoritter?';

  @override
  String get playlistClearFavoritesBody =>
      'Du mister alle favorittsporene dine. Dette kan ikke angres.';

  @override
  String get playlistRemoveFromLibrary => 'Fjern fra biblioteket';

  @override
  String get playlistServerReadOnly => 'Serverspilleliste · skrivebeskyttet';

  @override
  String get navAbout => 'Om';

  @override
  String get navMore => 'Mer';

  @override
  String get shellAlbumQueuedAtEnd => 'Albumet er lagt til sist i køen';

  @override
  String get shellAlbumQueuedNext => 'Albumet spilles som neste';

  @override
  String get shellAddingToQueue => 'Legger til i køen…';

  @override
  String get shellAddingNext => 'Legger til som neste…';

  @override
  String shellDownloadFailed(String error) {
    return 'Nedlasting mislyktes: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spor lagt til i køen',
      one: '$count spor lagt til i køen',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" er lagt til sist i køen';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" spilles som neste';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Nedlasting mislyktes: $title — hopper til neste spor';
  }

  @override
  String get shellNetworkUnavailable =>
      'Avspillingen stoppet: nettverket ser ut til å være utilgjengelig.';

  @override
  String get statsTitle => 'Statistikk';

  @override
  String statsPeriodDays(int n) {
    return '$n dager';
  }

  @override
  String get statsPeriodThisYear => 'I år';

  @override
  String get statsPeriodAll => 'Alt';

  @override
  String get statsByMonthOrYear => 'Etter måned / år…';

  @override
  String get statsByYear => 'Etter år';

  @override
  String get statsByMonth => 'Etter måned';

  @override
  String get statsPlaysLabel => 'Avspillinger';

  @override
  String get statsTracksLabel => 'Spor';

  @override
  String get statsArtistsLabel => 'Artister';

  @override
  String get statsAlbumsLabel => 'Album';

  @override
  String get statsListenTime => 'Lyttetid';

  @override
  String get statsByCollection => 'Per samling';

  @override
  String get statsByFormat => 'Per format';

  @override
  String get statsByEngine => 'Per motor';

  @override
  String get statsPlaylistsLabel => 'Spillelister';

  @override
  String get statsLocalFilesSection => 'Nedlastede filer';

  @override
  String get statsFilesLabel => 'Filer';

  @override
  String get statsSpaceLabel => 'Diskplass';

  @override
  String get statsNoPlaysInPeriod => 'Ingen avspillinger i denne perioden';

  @override
  String get statsNoPlays => 'Ingen avspillinger';

  @override
  String get statsTopTracks => 'Topp spor';

  @override
  String get statsTopAlbums => 'Topp album';

  @override
  String get statsTopArtists => 'Topp artister';

  @override
  String statsTopTracksIn(String period) {
    return 'Topp spor — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Topp album — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Topp artister — $period';
  }

  @override
  String get statsSeeAll => 'Se alle';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n avspillinger',
      one: '$n avspilling',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor',
      one: '$n spor',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'maks $n';
  }

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get commonCreate => 'Opprett';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Slett';

  @override
  String get commonRename => 'Gi nytt navn';

  @override
  String get commonSort => 'Sorter';

  @override
  String get commonPlayAll => 'Spill alle';

  @override
  String get sortName => 'Navn';

  @override
  String get sortTitle => 'Tittel';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Lagt til';

  @override
  String get commonClear => 'Tøm';

  @override
  String get sortRecentlyModified => 'Nylig endret';

  @override
  String get sortCreationDate => 'Opprettelsesdato';

  @override
  String get playlistNameHint => 'Navn';

  @override
  String get playlistNew => 'Ny spilleliste';

  @override
  String get playlistNewFolder => 'Ny mappe';

  @override
  String get playlistNewTooltip => 'Ny spilleliste / mappe';

  @override
  String get playlistAddTo => 'Legg til i spilleliste';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Legg til i $n spillelister',
      one: 'Legg til i $n spilleliste',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Velg en spilleliste';

  @override
  String get playlistFilterHint => 'Filtrer spillelister…';

  @override
  String get playlistSearchHint => 'Søk etter en spilleliste…';

  @override
  String get playlistNoMatch => 'Ingen spilleliste samsvarer';

  @override
  String get playlistNoneCreateHint => 'Ingen spillelister — opprett en med +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor',
      one: '$n spor',
      zero: 'Ingen spor',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Allerede lagt til';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementer ligger allerede i de valgte spillelistene.',
      one: '$n element ligger allerede i de valgte spillelistene.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Hopp over duplikater';

  @override
  String get playlistAddAgain => 'Legg til likevel';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor lagt til',
      one: '$n spor lagt til',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m spillelister',
      one: '$n spilleliste',
    );
    return '$_temp0 i $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Kunne ikke legge til: $error';
  }

  @override
  String get playlistRenameTitle => 'Gi spillelisten nytt navn';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Slette mappen “$name”?';
  }

  @override
  String get playlistDeleteFolderBody => 'Innholdet flyttes opp ett nivå.';

  @override
  String get playlistEmpty => 'Tom spilleliste';

  @override
  String get trackOptionsAddToLibrary => 'Legg til i biblioteket';

  @override
  String get trackOptionsRemoveFromLibrary => 'Fjern fra biblioteket';

  @override
  String get trackOptionsAddedToLibrary => 'Sporet er lagt til i biblioteket';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'Sporet er fjernet fra biblioteket';

  @override
  String get trackOptionsViewAlbum => 'Vis albumet';

  @override
  String get trackOptionsViewArtist => 'Vis artisten';

  @override
  String get trackOptionsPlayNow => 'Spill nå';

  @override
  String get trackOptionsPlayNext => 'Spill neste';

  @override
  String get trackOptionsAddToQueueEnd => 'Legg til sist i køen';

  @override
  String get trackOptionsPlayLast => 'Spill sist';

  @override
  String get trackOptionsDeleteDownload => 'Slett nedlastingen';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Slette denne nedlastingen?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Filen og de lokale oppføringene (historikk, spor) blir slettet.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Nedlastingen er slettet';

  @override
  String get trackOptionsAddToFavorites => 'Legg til i favoritter';

  @override
  String get trackOptionsRemoveFromFavorites => 'Fjern fra favoritter';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Albumet er lagt til i favoritter';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Albumet er fjernet fra favoritter';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Albumet er ikke lastet ned — ingenting å slette';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Slette det nedlastede albumet?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Mappen og alle de lokale oppføringene (spor, historikk) blir slettet.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Albumet er slettet fra lokal lagring';

  @override
  String get trackOptionsRedownloadAlbum => 'Last ned albumet på nytt';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Skriver over både filer OG lokale oppføringer';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Slett albumets filer';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Nedlastet mappe + lokale oppføringer (historikk)';

  @override
  String get settingsTitle => 'Innstillinger';

  @override
  String get settingsGeneral => 'Generelt';

  @override
  String get settingsGeneralSubtitle => 'Tema';

  @override
  String get settingsVisualisation => 'Visualisering';

  @override
  String get settingsVisualisationSubtitle =>
      'Oscilloskop, omslag i bakgrunnen';

  @override
  String get settingsPlayback => 'Avspilling';

  @override
  String get settingsPlaybackSubtitle => 'Looper, uttoning, stillhet';

  @override
  String get settingsEngines => 'Motorer';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDataSubtitle => 'ID, historikk, nullstilling';

  @override
  String get settingsBackupExport => 'Eksporter en sikkerhetskopi';

  @override
  String get settingsBackupExportSubtitle =>
      'Lagre biblioteket, spillelister og innstillinger til en fil';

  @override
  String get settingsBackupImport => 'Importer en sikkerhetskopi';

  @override
  String get settingsBackupImportSubtitle =>
      'Gjenopprett dataene fra en sikkerhetskopifil';

  @override
  String get settingsBackupExportFailed =>
      'Eksport av sikkerhetskopi mislyktes';

  @override
  String get settingsBackupImportConfirmTitle => 'Importere sikkerhetskopi?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Dette erstatter biblioteket, spillelistene og innstillingene på denne enheten. Nedlastede filer beholdes.';

  @override
  String get settingsBackupImportConfirm => 'Importer';

  @override
  String get settingsBackupImportedTitle => 'Sikkerhetskopi importert';

  @override
  String get settingsBackupImportedBody =>
      'Dataene dine er gjenopprettet. Start appen på nytt for å ta i bruk alt.';

  @override
  String get settingsBackupTooNew =>
      'Denne sikkerhetskopien ble laget av en nyere versjon av appen';

  @override
  String get settingsBackupInvalid => 'Ikke en gyldig Rewamp-sikkerhetskopi';

  @override
  String get settingsBackupImportFailed => 'Import av sikkerhetskopi mislyktes';

  @override
  String get settingsAbout => 'Om';

  @override
  String get settingsAboutSubtitle => 'Krediteringer og lisenser';

  @override
  String get settingsCreditsSubtitle => 'Biblioteker, data og komponenter';

  @override
  String get settingsSupport => 'Kontakt og støtte';

  @override
  String get settingsSupportSubtitle => 'Kontakt oss, nettsted';

  @override
  String get settingsSupportEmail => 'Send e-post';

  @override
  String get settingsSupportEmailSubtitle => 'Spørsmål, feil eller forslag';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — støtte';

  @override
  String get settingsSupportEmailIntro =>
      'Beskriv spørsmålet, feilen eller forslaget ditt ovenfor. Informasjonen nedenfor hjelper oss å hjelpe deg.';

  @override
  String get settingsSupportWebsite => 'Nettsted';

  @override
  String get settingsDonation => 'Støtt Rewamp';

  @override
  String get settingsDonationSubtitle => 'En liten tips, hvis du vil';

  @override
  String get settingsDonationBlurb =>
      'Rewamp er gratis og reklamefritt — et hjertearbeid viet til å bevare demoscene- og retrokulturen. Donasjoner bidrar til å finansiere utviklingen av appen og dekke kostnadene for databasens hosting. Ingen forpliktelse: hvis appen gir deg glede, er en liten gest alltid velkommen.';

  @override
  String get settingsDonationFloppy => 'En diskett';

  @override
  String get settingsDonationCartridge => 'En kassett';

  @override
  String get settingsDonationBox => 'Et spill i eske';

  @override
  String get settingsDonationCustom => 'Velg et beløp';

  @override
  String get settingsCancel => 'Avbryt';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Slett';

  @override
  String get settingsReset => 'Nullstill';

  @override
  String get settingsRenew => 'Forny';

  @override
  String get settingsOff => 'Av';

  @override
  String get settingsOn => 'På';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Uendelig';

  @override
  String get settingsDefault => 'Standard';

  @override
  String get settingsCoreNoScope => 'uten oscilloskop';

  @override
  String get settingsNone => 'Ingen';

  @override
  String get settingsLevelLow => 'Lav';

  @override
  String get settingsLevelHigh => 'Høy';

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
  String get settingsArtworkTintTitle => 'Fargelegg spilleren etter omslaget';

  @override
  String get settingsArtworkTintSubtitle =>
      'Spilleren tar opp den dominerende fargen i omslaget';

  @override
  String get settingsGlassEffectTitle => 'Liquid glass-effekt';

  @override
  String get settingsGlassEffectSubtitle =>
      'Linse og uskarphet på de nedre feltene — slå av på trege enheter';

  @override
  String get settingsResetSection => 'Nullstill denne seksjonen';

  @override
  String get settingsResetEngine => 'Nullstill denne motoren';

  @override
  String get settingsResetChoices => 'Nullstill disse valgene';

  @override
  String get settingsResetToDefault => 'Standardverdi';

  @override
  String get settingsStartInVizTitle => 'Start i visualiseringsmodus';

  @override
  String get settingsStartInVizSubtitle =>
      'Spilleren åpnes på oscilloskopene i stedet for omslaget';

  @override
  String get settingsVoiceGridTitle => 'Rutenett for stemmeoscilloskopet';

  @override
  String get settingsVoiceGridSubtitle =>
      'Viser kantene som skiller hver stemme';

  @override
  String get settingsKeepAwakeTitle => 'Hold skjermen på';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Mens en visualisering vises, dempes eller låses ikke skjermen';

  @override
  String get settingsVoiceNamesTitle => 'Stemmenavn';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Viser navnet på hver stemme inne i rammen';

  @override
  String get settingsLineThickness => 'Linjetykkelse';

  @override
  String get settingsScopeVoiceColor => 'Stemmeoscilloskop';

  @override
  String get settingsStereoColors => 'Stereo: farger';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo venstre';

  @override
  String get settingsStereoRightColor => 'Stereo høyre';

  @override
  String get settingsNotePalette => 'Fargepalett';

  @override
  String get settingsNoteBoxStyle => 'Blokkstil';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'Alle visualiseringer';

  @override
  String get settingsVizScopes => 'Oscilloskop (stereo og per stemme)';

  @override
  String get settingsVizFrameRate => 'Bildefrekvens';

  @override
  String get settingsVizFrameRateScreen => 'Skjerm';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => 'Intensitet / hastighet';

  @override
  String get settingsArtworkOpacity => 'Dekkevne for omslag i bakgrunnen';

  @override
  String get settingsProjectMTitle => 'projectM-innstillinger';

  @override
  String get settingsProjectMSubtitle => 'Presets, overganger, kvalitet, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Varsler ved sporbytte';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Systemvarsel med tittelen på det nye sporet';

  @override
  String get settingsSilenceDetection => 'Stillhetsdeteksjon';

  @override
  String get settingsCrossfade => 'Kryssfading';

  @override
  String get localActionPlay => 'Spill av filer eller en mappe';

  @override
  String get localActionImport => 'Importer filer eller en mappe';

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
  String get localOpsPhaseExtracting => 'pakker ut';

  @override
  String get localOpsPhaseRegistering => 'legger til i biblioteket';

  @override
  String get localOpsPhaseDeleting => 'fjerner filer';

  @override
  String get localImportFiles => 'Importer filer';

  @override
  String get storageLocalImports => 'Lokale importer';

  @override
  String get settingsVgmJapaneseTags => 'Japanske tagger (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'Foretrekker de japanske feltene (tittel, spill, artist) i VGM-tagger når de finnes.';

  @override
  String get localImportFolder => 'Importer en mappe';

  @override
  String get localLibraryTitle => 'På denne enheten';

  @override
  String get libraryOnAnotherDevice => 'På en annen enhet';

  @override
  String get localLibraryEmpty =>
      'Ingen lokale importer ennå. Bruk «Importer filer» eller «Importer en mappe» fra startsiden.';

  @override
  String queueLimitReached(int count) {
    return 'Køen er begrenset til de første $count sporene';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return 'Slette «$name»? Filen og tilhørende filer (omslag…) fjernes.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slette mappen «$name» og dens $count spor?',
      one: 'Slette mappen «$name» og dens $count spor?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count spor importert til biblioteket';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks spor importert — $albums album';
  }

  @override
  String localImportFailed(String error) {
    return 'Import mislyktes: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'Toner slutten av hvert spor over i starten av neste. Ved 0 er avspillingen fortsatt sømløs.';

  @override
  String get settingsMinSubsongSection => 'For korte delspor';

  @override
  String get settingsMinSubsongTitle => 'Minste lengde';

  @override
  String get settingsMinSubsongHelp =>
      'Kortere delspor holdes utenfor listen og køen – en spillfil inneholder ofte flere lydeffekter enn musikk. Ved 0 utelates ingenting; en ukjent lengde regnes aldri som kort.';

  @override
  String get localNewFolder => 'Ny mappe';

  @override
  String get localFolderName => 'Mappenavn';

  @override
  String get localRename => 'Gi nytt navn';

  @override
  String get localMoveTo => 'Flytt til…';

  @override
  String get localMove => 'Flytt';

  @override
  String get localMoveNothing => 'Ingenting ble flyttet';

  @override
  String get localNameInvalid => 'Ugyldig navn';

  @override
  String get localNameTaken => 'Navnet er allerede i bruk';

  @override
  String get localMoveIntoItself => 'En mappe kan ikke flyttes inn i seg selv';

  @override
  String get localManageFailed => 'Handlingen mislyktes';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Legges ikke i kø: under $seconds s (Innstillinger → Avspilling)';
  }

  @override
  String get settingsQueuePrefetchSection => 'Nedlastinger i køen';

  @override
  String get settingsQueuePrefetchTitle => 'Last ned hele køen';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'Én fil om gangen; neste manglende spor starter så snart det forrige er ferdig. Av: bare neste spor.';

  @override
  String get settingsCdRipDeclickSection => 'CD-ripper';

  @override
  String get settingsCdRipDeclickTitle => 'Fjern klikk ved starten av sporet';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'Dårlige CD-ripper (mp3, ape, ogg, flac…) begynner ofte med noen korrupte sampler. De repareres til 200 ms ekte musikk er spilt; deretter trekker filteret seg tilbake.';

  @override
  String get settingsSilenceSkipTitle => 'Gå til neste spor ved stillhet';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Går videre automatisk når utgangen forblir stille';

  @override
  String get settingsSilenceDelay => 'Stillhetsforsinkelse';

  @override
  String get settingsDefaultDuration => 'Standardvarighet';

  @override
  String get settingsDefaultDurationHelp =>
      'Brukes når et spor ikke oppgir noen kjent varighet (ingen tagg, ingen servermetadata) — hindrer at det spiller eller looper i det uendelige. Gjelder aldri Amiga-spor (UADE), som har sin egen database over sporlengder.';

  @override
  String get settingsForcedLoopHeader => 'Tvungen loop / uttoning';

  @override
  String get settingsForcedLoopHelp =>
      'Enkelte formater looper en bestemt del (VGM, tracker-moduler…); andre gjør det ikke. \"Uendelig\" ignorerer sporets naturlige slutt.';

  @override
  String get settingsForceLoopCount => 'Tving antall looper';

  @override
  String get settingsLoopCount => 'Antall looper';

  @override
  String get settingsForceFadeout => 'Tving en uttoning';

  @override
  String get settingsFadeoutDuration => 'Varighet på uttoningen';

  @override
  String get settingsResetEnginesTitle => 'Nullstille motorinnstillingene?';

  @override
  String get settingsResetEnginesBody =>
      'Alle motorinnstillinger settes tilbake til standardverdiene.';

  @override
  String get settingsResetDefaultsTitle => 'Nullstill til standardverdier';

  @override
  String get settingsResetDefaultsSubtitle => 'Alle motorer';

  @override
  String get settingsDefaultDecoders => 'Standarddekodere';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formater som flere motorer kan spille';

  @override
  String get settingsDecodersHelp =>
      'Enkelte formater kan spilles av flere motorer. Velg hvilken som skal brukes som standard — alle andre formater rutes automatisk.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga-trackere (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackere — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Moduler libopenmpt ikke leser — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — kvalitet, filtre, valg per brikke';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — høypassfilter';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont i bruk';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolasjon, lavpass, ekko';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorering, hodetelefoner, gain, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — klokke, modell, ReSIDfp-filtre';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — harmonisk modus stereo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, romklang';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612-, OPL3-, QSound-kjerner…';

  @override
  String get settingsMasterVolume => 'Hovedvolum';

  @override
  String get settingsAmplification => 'Forsterkning';

  @override
  String get settingsAmigaFilter => 'Amiga-filter';

  @override
  String get settingsInterpolation => 'Interpolasjon';

  @override
  String get settingsPolyphony => 'Polyfoni';

  @override
  String get settingsReverb => 'Romklang';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'Denne MIDI-filen er skrevet for en Roland MT-32. Uten ROM-ene spilles den med SoundFonten, med instrumentene oversatt til General MIDI — importer ROM-ene i Innstillinger › Motorer › Munt.';

  @override
  String get settingsMidiMt32ToGm => 'Tilpass MT-32-filer';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'En MIDI skrevet for Roland MT-32 nummererer programmene etter MT-32-ens egen liste: oversatt til nærmeste General MIDI-instrument høres de troverdige ut i stedet for tilfeldige.';

  @override
  String get settingsInterpNone => 'Ingen';

  @override
  String get settingsInterpLinear => 'Lineær';

  @override
  String get settingsInterpCubic => 'Kubisk';

  @override
  String get settingsInterpSinc => 'Sinc (best)';

  @override
  String get settingsStereoSeparation => 'Stereoseparasjon';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Avslutter sporet når motoren oppdager en lang stillhet';

  @override
  String get settingsStereoDepth => 'Stereodybde';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — ingen effekt på SPC';

  @override
  String get settingsBass => 'Bass';

  @override
  String get settingsTreble => 'Diskant';

  @override
  String get settingsAppliedLive =>
      'Tas i bruk umiddelbart, også under avspilling.';

  @override
  String get settingsAppliedNextTrack => 'Tas i bruk på neste spor som lastes.';

  @override
  String get settingsSidEmulation => 'Emulering';

  @override
  String get settingsSidResidfp => 'ReSIDfp (nøyaktig)';

  @override
  String get settingsSidLite => 'SIDLite (rask)';

  @override
  String get settingsSidSampling => 'Sampling';

  @override
  String get settingsSidSamplingInterp => 'Interpolasjon (rask)';

  @override
  String get settingsSidSamplingResample => 'Resample (best)';

  @override
  String get settingsSidClock => 'Klokke';

  @override
  String get settingsSidModel => 'SID-modell';

  @override
  String get settingsSidFilter => 'SID-filter';

  @override
  String get settingsSidForceSecond => 'Tving en 2. SID';

  @override
  String get settingsSidSecondSubtitle => '2SID-låter i stereo';

  @override
  String get settingsSidSecondAddr => 'Adresse for 2. SID';

  @override
  String get settingsSidForceThird => 'Tving en 3. SID';

  @override
  String get settingsSidThirdAddr => 'Adresse for 3. SID';

  @override
  String get settingsSidAutoFilter => 'Automatisk 6581-filterområde';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Verdien som anbefales for låtens komponist (sidplayfp-tabeller)';

  @override
  String get settingsSid6581Range => '6581-filterområde';

  @override
  String get settingsSid6581Curve => '6581-filterkurve';

  @override
  String get settingsSid8580Curve => '8580-filterkurve';

  @override
  String get settingsSidNote =>
      'SID-filter og -kurver tas i bruk direkte; emulering/sampling/klokke/modell/2.-3. SID trer i kraft på neste spor.';

  @override
  String get settingsAudioOutput => 'Lydutgang';

  @override
  String get settingsAdplugNote =>
      'Surround: to lett feilstemte OPL-brikker. Tas i bruk på neste spor.';

  @override
  String get settingsHeSpuMain => 'Hovedstemmer (SPU)';

  @override
  String get settingsHeSpuReverb => 'Romklang (SPU)';

  @override
  String get settingsNsfQuality => 'Kvalitet (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Lavpassfilter';

  @override
  String get settingsHighpassFilter => 'Høypassfilter';

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
  String get settingsNsfApu2Title => '2A03 — triangel / støy / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Opphev demping ved reset';

  @override
  String get settingsNsfPhaseRefresh => 'Oppdater fasen';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Nullstiller fasen når perioden skrives';

  @override
  String get settingsNsfNonlinearMixer => 'Ikke-lineær miksing';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      '2A03-ens ekte miks (ellers lineær)';

  @override
  String get settingsNsfDutySwap => 'Bytt om duty-sykluser';

  @override
  String get settingsNsfDutySwapSubtitle => 'Rekkefølgen på 25 % / 50 % duty';

  @override
  String get settingsNsfNegateSweep => 'Negativ sweep ved init';

  @override
  String get settingsNsfEnable4011 => 'Register \$4011 aktivt';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Direkte DAC-utgang (originale klikk)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodisk støy';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Kort modus på støygeneratoren';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM anti-klikk';

  @override
  String get settingsNsfRandomizeNoise => 'Tilfeldig støy ved init';

  @override
  String get settingsNsfTriangleMute => 'Demp triangelen';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Gjør triangelen stille ved ultrasoniske perioder';

  @override
  String get settingsNsfRandomizeTri => 'Tilfeldig triangel ved init';

  @override
  String get settingsNsfDpcmReverse => 'Reversert DPCM';

  @override
  String get settingsNsfN163Serial => 'Seriell multipleksing';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Den ekte N163-summingen på låter med mange stemmer';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fase kun for lesing';

  @override
  String get settingsNsfN163LimitWavelength => 'Begrens bølgelengden';

  @override
  String get settingsNsfFdsCutoff => 'Lavpass-kutt';

  @override
  String get settingsNsfFds4085Reset => '\$4085-reset';

  @override
  String get settingsNsfFdsWriteProtect => 'Skrivebeskyttelse';

  @override
  String get settingsNsfVrc7Patch => 'Patch-sett';

  @override
  String get settingsNsfVrc7Opll => 'OPLL-modus';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Emulerer en YM2413 i stedet for VRC7';

  @override
  String get settingsGbsHpFilter => 'Høypassfilter (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klassisk GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Ekko';

  @override
  String get settingsUadePostfx => 'Etterbehandling';

  @override
  String get settingsUadePostfxSubtitle =>
      'Slår på effektkjeden (kreves for alt nedenfor)';

  @override
  String get settingsUadePan => 'Panorering (stereoseparasjon)';

  @override
  String get settingsUadePanValue => 'Panoreringsgrad';

  @override
  String get settingsUadeHeadphones => 'Hodetelefoner';

  @override
  String get settingsUadeLed => 'LED (Paula-filter)';

  @override
  String get settingsUadeLedAuto => 'Auto (per låt)';

  @override
  String get settingsUadeLedOn => 'Tvunget PÅ';

  @override
  String get settingsUadeLedOff => 'Tvunget AV';

  @override
  String get settingsUadeFilterType => 'Filtertype';

  @override
  String get settingsUadeGain => 'Gain';

  @override
  String get settingsUadeGainValue => 'Gain-verdi';

  @override
  String get settingsSoundfontLoading => 'Laster katalogen…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Katalogen er utilgjengelig ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Nedlasting mislyktes: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importer en SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Velg en .sf2-fil på denne enheten';

  @override
  String get settingsSoundfontImported => 'Importert';

  @override
  String get settingsSoundfontInvalid =>
      'Denne filen er ikke en SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Importen mislyktes — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Slett filen';

  @override
  String get settingsCreditsHeader => 'Krediteringer og lisenser';

  @override
  String get settingsRightsNotice =>
      'Rewamp er en spiller: den lagrer ingen filer og distribuerer ingen musikk. Sporene kommer fra bevaringsarkiver på nett og forblir rettighetshavernes eiendom. Det er ditt ansvar å sikre at avspilling, nedlasting og oppbevaring er i samsvar med gjeldende rettigheter og lovene i landet ditt.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formater støttes',
      one: '$count format støttes',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fordelt på $count avspillingsmotorer — se detaljene',
      one: 'Håndteres av $count avspillingsmotor — se detaljene',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga-sporlengder og metadata';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb av Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64/SID-data og omslagsbilder';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadata og bilder for C64-spill.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2-skrift';

  @override
  String get settingsFt2FontSubtitle =>
      'Patternvisualiserens FastTracker II-stil bruker FT2-bitmapskriften fra ft2-clone av 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url kopiert';
  }

  @override
  String get settingsOpenLink => 'Åpne lenken';

  @override
  String get settingsEnginesHeader => 'Avspillingsmotorer';

  @override
  String get settingsComponentsHeader => 'Andre komponenter';

  @override
  String get settingsResetAll => 'Nullstill alle innstillinger';

  @override
  String get settingsResetAllSubtitle =>
      'Generelt, Visualisering, Avspilling, Motorer — ikke biblioteket';

  @override
  String get settingsResetAllTitle => 'Nullstille alle innstillinger?';

  @override
  String get settingsResetAllBody =>
      'Generelt, Visualisering, Avspilling og alle motorer settes tilbake til standardverdiene. Biblioteket og historikken din berøres ikke.';

  @override
  String get settingsRenewUserId => 'Forny den anonyme ID-en';

  @override
  String get settingsRenewUserIdTitle => 'Fornye den anonyme ID-en?';

  @override
  String get settingsRenewUserIdBody =>
      'En ny anonym ID opprettes for serverstatistikken.\n\nDen gamle vil ikke lenger bli brukt. Den lokale historikken og favorittene dine berøres ikke.';

  @override
  String get settingsRenewUserIdFailed =>
      'Mislyktes — serveren er ikke tilgjengelig';

  @override
  String settingsNewUserId(String id) {
    return 'Ny ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Ingen ID registrert';

  @override
  String get settingsCleanDb => 'Rydd opp i den lokale databasen';

  @override
  String get settingsCleanDbSubtitle =>
      'Fjerner oppføringer der filen ikke lenger finnes (slettede nedlastinger, gamle feil)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foreldreløse oppføringer fjernet',
      one: '$count foreldreløs oppføring fjernet',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'Den lokale databasen er ryddig — ingenting å fjerne';

  @override
  String get settingsClearCache => 'Tøm hurtiglageret (omslag og metadata)';

  @override
  String get settingsClearCacheSubtitle =>
      'Fjerner omslag i hurtiglageret og hentede metadata (STIL, sporlengder) — lastes ned på nytt ved neste avspilling';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hurtiglageret er tømt ($count omslag)',
      one: 'Hurtiglageret er tømt ($count omslag)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Lagring';

  @override
  String get storageSubtitle => 'Hva appen beholder på disk, med sletting';

  @override
  String get storageDownloads => 'Nedlastinger';

  @override
  String get storageArtworkCache => 'Omslagsbuffer';

  @override
  String get storageSoundfonts => 'SoundFonts';

  @override
  String get storagePresets => 'Visualiseringsforvalg';

  @override
  String get storageOpenedFiles => 'Åpnede filer';

  @override
  String get storageOpenedEmpty =>
      'Filer åpnet utenfra (deling, «Åpne med», velgeren på mobil) kopieres hit.';

  @override
  String get storageInUse => 'i en spilleliste eller biblioteket';

  @override
  String get storageDeleteAll => 'Slett alle';

  @override
  String get storageClear => 'Tøm';

  @override
  String get storageDeleteSelection => 'Slett utvalget';

  @override
  String get storageSelectAll => 'Velg alle';

  @override
  String get storageFilterHint => 'Filtrer på navn';

  @override
  String get storageNoMatch => 'Ingen fil samsvarer med filteret.';

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
      other: 'Slette $count filer?',
      one: 'Slette $count fil?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Slette $count filer? $inUse brukes av en spilleliste eller biblioteket — de oppføringene mister filen sin.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Slette alle nedlastede filer og bibliotekradene deres? Favoritter og spillelister beholder oppføringene, men filene må lastes ned på nytt.';

  @override
  String get storageSoundfontsClearBody =>
      'Slette alle SoundFonts, også importerte? Katalogens lastes ned igjen ved behov; importerte går tapt.';

  @override
  String get storagePresetsClearBody =>
      'Slette nedlastede preset-pakker og importerte presets? Medfølgende beholdes; pakker lastes ned igjen, importerte går tapt.';

  @override
  String get storageOpenedDeleteAllTitle => 'Slett åpnede filer';

  @override
  String get storageInUseDeleteTitle => 'Filen er i bruk';

  @override
  String get storageInUseDeleteBody =>
      'En spilleliste eller biblioteket peker fortsatt på denne filen. Sletting etterlater oppføringene uten fil.';

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
      other: '$count filer — $size · håndteres via album og spor',
      one: '$count fil — $size · håndteres via album og spor',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Slette $count filer? Filer brukt av en spilleliste eller biblioteket beholdes.',
      one:
          'Slette $count fil? Filer brukt av en spilleliste eller biblioteket beholdes.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Nullstill statistikken';

  @override
  String get settingsResetStatsSubtitle =>
      'Fjerner lyttehistorikken og avspillingstellerne';

  @override
  String get settingsClearStatsTitle => 'Nullstille statistikken?';

  @override
  String get settingsClearStatsBody =>
      'Dette sletter permanent:\n• hele lyttehistorikken\n• avspillingstellerne\n\nFavorittene og biblioteket ditt berøres ikke.';

  @override
  String get settingsStatsCleared => 'Statistikken er slettet';

  @override
  String get settingsResetDatabase => 'Nullstill databasen';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Sletter alt: historikk, favoritter, spillelister, hurtiglager';

  @override
  String get settingsResetDbTitle => 'Nullstille databasen?';

  @override
  String get settingsCleanLocalTitle =>
      'Rydd opp i uspillbare lokale oppføringer';

  @override
  String get cleanStageScan => 'Skanner oppføringer…';

  @override
  String get cleanStageSync => 'Synkroniserer med kontoen din…';

  @override
  String get cleanStagePurge => 'Fjerner fra kontoen din…';

  @override
  String get cleanStageDelete => 'Fjerner lokalt…';

  @override
  String get settingsCleanLocalBody =>
      'Biblioteksoppføringer som peker på en fil som ikke lenger finnes på denne enheten. De fjernes også fra kontoen din, altså fra de andre enhetene dine.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oppføringer fjernet',
      one: '$count oppføring fjernet',
      zero: 'Ingenting å rydde',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'Dette sletter permanent:\n• hele lyttehistorikken\n• alle tellere\n• alle favoritter\n• alle spillelister\n• alle metadata i hurtiglageret\n\nLydfilene dine slettes ikke.';

  @override
  String get settingsDbReset => 'Databasen er nullstilt';

  @override
  String get settingsDeleteDownloads => 'Slett nedlastingene';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Sletter alle filene i online-mappen (spor, omslag)';

  @override
  String get settingsCleanAll => 'Rydd lokal database og hurtigbuffer';

  @override
  String get settingsCleanAllSubtitle =>
      'Fjerner oppføringer uten fil, bibliotekoppføringer som peker på filer på en annen enhet, og tømmer hurtigbufferen for omslag og metadata';

  @override
  String get settingsCleanAllConfirmBody =>
      'Bibliotekoppføringer som peker på filer på en annen enhet fjernes også fra kontoen din, altså fra de andre enhetene dine. Omslag og metadata lastes ned igjen ved neste avspilling.';

  @override
  String get settingsDataAdvanced => 'Avansert';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Hvert ryddetrinn for seg, hurtigbufferen og tilbakestillingene';

  @override
  String get settingsDataGroupDb => 'Database';

  @override
  String get settingsDataGroupCache => 'Hurtigbuffer';

  @override
  String get settingsDataGroupReset => 'Tilbakestill';

  @override
  String get settingsDeleteDownloadsTitle => 'Slette nedlastingene?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Dette sletter permanent alle nedlastede filer (spor, album, omslag) fra online-mappen.\n\nOppføringene i databasen blir værende, men vil peke på filer som ikke lenger finnes.';

  @override
  String get settingsDownloadsDeleted => 'Nedlastingene er slettet';

  @override
  String get settingsColor => 'Farge';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Tilfeldig neste preset';

  @override
  String get settingsPmRandomNextSubtitle => 'Av: spill presetene i rekkefølge';

  @override
  String get settingsPmLockPreset => 'Lås presetet';

  @override
  String get settingsPmLockPresetSubtitle => 'Ingen automatisk bytting';

  @override
  String get settingsPmPresetDuration => 'Tid mellom presets';

  @override
  String get settingsPmTransitions => 'Overganger';

  @override
  String get settingsPmBlend => 'Overgang med kryssfade';

  @override
  String get settingsPmBlendSubtitle => 'Av: bytt preset umiddelbart';

  @override
  String get settingsPmTransitionStyle => 'Overgangsstil';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Mønsteret overtoningen bruker';

  @override
  String get settingsPmTransitionRandom => 'Tilfeldig';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Presetbytte synkronisert med beatet';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minimumstid';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: følsomhet';

  @override
  String get settingsPmRendering => 'Gjengivelse';

  @override
  String get settingsPmQuality => 'Kvalitet';

  @override
  String get settingsPmQualitySubtitle =>
      'Gjengivelsesoppløsning (Maks = naturlig oppløsning)';

  @override
  String get settingsPmBeatSensitivity => 'Beat-følsomhet';

  @override
  String get settingsPmAspectRatio => 'Respekter høyde-breddeforholdet';

  @override
  String get settingsPmAspectRatioSubtitle => 'For shaderne som støtter det';

  @override
  String get settingsPmPermissive => 'Tillatende modus';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Laster .milk-filer som har skriptfeil';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountSubtitle => 'Lagre og synkroniser biblioteket ditt';

  @override
  String get accountAnonymous => 'Anonym konto';

  @override
  String get accountAnonymousExplain =>
      'Favorittene og historikken din ligger på serveren, men bare denne enheten når dem. Legg til en e-postadresse for å finne dem igjen andre steder.';

  @override
  String get accountEmailAttached =>
      'Adressen er bekreftet — kontoen kan gjenopprettes';

  @override
  String get accountEmailPending => 'Adressen er ikke bekreftet ennå';

  @override
  String get accountInsecureStorage =>
      'Enhetens sikre lagring er utilgjengelig: kontoens identifikator lagres ukryptert.';

  @override
  String get accountSaveCta => 'Lagre kontoen min';

  @override
  String get accountStatSongs => 'Favorittspor';

  @override
  String get accountStatAlbums => 'Favorittalbum';

  @override
  String get accountStatPlays => 'Avspillinger';

  @override
  String get accountCreatedLabel => 'Opprettet';

  @override
  String get accountSignOut => 'Logg ut';

  @override
  String get accountRevoke => 'Logg ut overalt';

  @override
  String get accountRevokeSubtitle => 'Logger ut alle andre enheter';

  @override
  String get accountRevokeBody =>
      'Alle andre enheter logges ut. Denne forblir pålogget.';

  @override
  String get accountRevokeDone => 'Andre enheter logget ut';

  @override
  String get accountDelete => 'Slett kontoen min';

  @override
  String get accountDeleteSubtitle =>
      'Sletter kontoen og dataene på serveren. Kan ikke angres.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favoritter og $lists spillelister slettes fra serveren. Dette kan ikke angres.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Nedlastingene dine og bibliotektet på denne enheten berøres ikke.';

  @override
  String get accountDeleteDone => 'Kontoen er slettet';

  @override
  String get accountSignOutSubtitle =>
      'Enheten starter på nytt med en tom konto';

  @override
  String get accountSignOutTitle => 'Logge ut?';

  @override
  String accountSignOutBody(String email) {
    return 'Du kan komme tilbake til kontoen med en kode sendt til $email.';
  }

  @override
  String get accountSignedOut => 'Logget ut';

  @override
  String get accountNoSignOut => 'Utlogging er utilgjengelig';

  @override
  String get accountNoSignOutSubtitle =>
      'Uten e-postadresse ville denne kontoen vært tapt for alltid.';

  @override
  String get accountDetach => 'Koble fra adressen';

  @override
  String get accountDetachSubtitle =>
      'Kontoen blir anonym igjen, ingen data slettes';

  @override
  String get accountDetachBody =>
      'Uten adresse kan ikke denne kontoen lenger hentes fram fra en annen enhet.';

  @override
  String get accountDetachDone => 'Adressen er koblet fra';

  @override
  String get accountOffline => 'Kontoen er utilgjengelig uten nett';

  @override
  String get accountEmailTitle => 'E-postadresse';

  @override
  String get accountEmailExplain =>
      'Vi sender deg en 6-sifret kode for å bekrefte adressen. Den brukes bare til å gjenopprette kontoen.';

  @override
  String get accountEmailLabel => 'E-postadresse';

  @override
  String get accountCodeTitle => 'Bekreftelseskode';

  @override
  String accountCodeExplain(String email) {
    return 'Kode sendt til $email. Den er gyldig i 10 minutter.';
  }

  @override
  String get accountCodeLabel => '6-sifret kode';

  @override
  String get accountSendCode => 'Send koden';

  @override
  String get accountVerify => 'Bekreft';

  @override
  String get accountResend => 'Send koden på nytt';

  @override
  String accountResendIn(int n) {
    return 'Send på nytt om $n s';
  }

  @override
  String get accountCheckSpam =>
      'E-posten kan bruke et minutt — sjekk også søppelposten.';

  @override
  String get accountErrorInvalidEmail => 'Ugyldig adresse';

  @override
  String get accountErrorTooMany =>
      'For mange forespørsler, prøv igjen om noen minutter';

  @override
  String get accountErrorInvalidCode => 'Feil eller utløpt kode';

  @override
  String get accountErrorCodeLength => 'Koden har 6 sifre';

  @override
  String get albumOfflinePartial =>
      'Frakoblet – viser det som allerede finnes på denne enheten';

  @override
  String get accountErrorNetwork => 'Tilkoblingen mislyktes, prøv igjen';

  @override
  String get accountMergeTitle => 'Slå sammen dette biblioteket?';

  @override
  String accountMergeBody(String email) {
    return 'Favorittene og historikken på denne enheten legges til kontoen $email. Dette kan ikke angres.';
  }

  @override
  String get accountMergeConfirm => 'Slå sammen';

  @override
  String get accountCarryLocal => 'Behold favorittene på denne enheten';

  @override
  String accountCarryLocalOn(int n) {
    return 'De $n favorittene og spillelistene på denne enheten legges til i kontoen.';
  }

  @override
  String get accountCarryLocalOff =>
      'De slettes fra enheten og erstattes av kontoens. Nedlastede filer beholdes.';

  @override
  String get accountDropLocalTitle => 'Slette dataene på denne enheten?';

  @override
  String get accountCreatedOk => 'Kontoen er lagret, biblioteket ditt er trygt';

  @override
  String get accountMergedOk =>
      'Logget inn — de lokale favorittene dine ble lagt til';

  @override
  String get accountSignedInOk => 'Logget inn';

  @override
  String get playlistEntryMissing => 'Filen mangler på denne enheten';

  @override
  String get playlistEntryMissingRestorable =>
      'Filen mangler — kan lastes ned igjen';

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
  String get playlistBackupToAccount => 'Lagre på kontoen min';

  @override
  String get playlistBackupSubtitle =>
      'Beholder spillelisten også etter en ominstallasjon';

  @override
  String get playlistBackupUpdate => 'Oppdater sikkerhetskopien';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Erstatter kontoens kopi med denne versjonen';

  @override
  String get playlistBackupStop => 'Slutt å lagre';

  @override
  String get playlistBackupStopped => 'Sikkerhetskopi fjernet';

  @override
  String get playlistBackupDone => 'Spillelisten lagret';

  @override
  String get playlistBackupFailed => 'Kunne ikke lagre';

  @override
  String get playlistBackupNoAccount => 'Ingen konto på denne enheten';

  @override
  String get playlistSyncTooltip => 'Synkroniser med kontoen min';

  @override
  String get playlistSyncRunning => 'Synkroniserer…';

  @override
  String get playlistSyncDone => 'Spillelister synkronisert';

  @override
  String get playlistSyncPartial => 'Noen spillelister kunne ikke lagres';

  @override
  String get playlistFetchMissing => 'Last ned sporene som mangler';

  @override
  String get playlistFetchDone => 'Manglende spor lastet ned';

  @override
  String get playlistFetchPartial => 'Noen spor kunne ikke lastes ned';

  @override
  String get playlistEntryFetchFailed => 'Dette sporet kunne ikke lastes ned';

  @override
  String get accountStatPlaylists => 'Spillelister';

  @override
  String get accountSyncNow => 'Synkroniser nå';

  @override
  String get accountSyncAuto => 'Skjer av seg selv i bakgrunnen';

  @override
  String get accountSyncAnonymous =>
      'Sikkerhetskopiert til serveren. Legg til en e-postadresse for å synkronisere en annen enhet.';

  @override
  String get accountSyncPending => 'Endringer venter på å bli sendt';

  @override
  String accountSyncLast(String when) {
    return 'Siste synkronisering: $when';
  }

  @override
  String get accountSyncDone => 'Synkronisering fullført';

  @override
  String get accountSyncFailed => 'Synkronisering mislyktes, prøver igjen';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'musikk fra $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'inneholder $place i $compo';
  }

  @override
  String get competitionEmpty => 'Denne konkurransen har ingen bidrag';

  @override
  String get competitionEntryNoMusic =>
      'Ingen musikk i katalogen for dette bidraget';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spor',
      one: '$n spor',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Hopp over';

  @override
  String get onboardingNext => 'Neste';

  @override
  String get onboardingStart => 'Kom i gang';

  @override
  String get onboardingBetaTitle => 'Betaversjon';

  @override
  String get onboardingBetaBody =>
      'Rewamp er fortsatt under bygging. Lokale data — bibliotek, spillelister, favoritter, statistikk — kan bli nullstilt før versjon 1.0. Nedlastingene dine står trygt, men ta vare på det du bryr deg om et annet sted.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Versjon $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Utforsk';

  @override
  String get onboardingExploreBody =>
      'Bla og søk blant titusenvis av chiptunes og trackermoduler fra de store nettarkivene — etter artist, album, plattform eller party. Trykk for å lytte, last ned for å beholde.';

  @override
  String get onboardingLibraryTitle => 'Biblioteket ditt';

  @override
  String get onboardingLibraryBody =>
      'Lagre det du liker, lag spillelister og ordne dem i mapper. Nedlastet musikk spilles av offline, og biblioteket følger deg mellom enheter når du er logget inn.';

  @override
  String get onboardingPlayerTitle => 'Spilleren';

  @override
  String get onboardingPlayerBody =>
      'Sveip for å bytte spor og åpne visualiseringene: oscilloskop, kanaler, rullende noter, trackerrutenett. Filer med flere låter viser delsporene, og hver stemme kan dempes for seg.';

  @override
  String get onboardingReplayTitle => 'Introduksjon';

  @override
  String get onboardingReplaySubtitle =>
      'Se betavarselet og omvisningen på nytt';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Trackerrutenett: farger, kolonner, rulling';

  @override
  String get patternOpaqueBg => 'Ugjennomsiktig bakgrunn';

  @override
  String get patternOpaqueBgSubtitle => 'Skjuler coveret bak rutenettet';

  @override
  String get commonSave => 'Lagre';

  @override
  String get commonImport => 'Importer';

  @override
  String get accountDisplayName => 'Offentlig navn';

  @override
  String get accountDisplayNameNotSet =>
      'Ikke satt — kreves for å publisere en spilleliste';

  @override
  String get accountDisplayNameHint => 'Navnet du vil krediteres under.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Å endre det sender alle spillelistene du har publisert tilbake til gjennomgang.';

  @override
  String get accountDisplayNameTaken => 'Navnet er opptatt. Velg et annet.';

  @override
  String get accountDisplayNameLength => 'Mellom 2 og 40 tegn.';

  @override
  String get accountDisplayNameSaved => 'Offentlig navn lagret';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Spillelister sendt tilbake til gjennomgang: $n';
  }

  @override
  String get playlistPublish => 'Gjør offentlig';

  @override
  String get playlistPublishSubtitle => 'Be om publisering (gjennomgås først)';

  @override
  String get playlistPublishTitle => 'Publisere denne spillelisten?';

  @override
  String get playlistPublishBody =>
      'Etter godkjenning er den synlig for alle, kreditert ditt offentlige navn. Omslaget kommer fra sporene.';

  @override
  String get playlistPublishCta => 'Be om';

  @override
  String get playlistPublishSubmitted => 'Sendt til gjennomgang';

  @override
  String get playlistPublishPending => 'Venter på godkjenning';

  @override
  String get playlistPublishApproved => 'Offentlig';

  @override
  String playlistPublishRejected(String reason) {
    return 'Avvist: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Avvist';

  @override
  String get playlistPublishNeedName => 'Velg navnet du vil krediteres under';

  @override
  String get playlistPublishNeedTracks =>
      'Det trengs minst 5 spor for å publisere';

  @override
  String get playlistPublishHasLocal =>
      'Filer fra enheten din kan ikke publiseres — andre kan ikke spille dem';

  @override
  String get playlistPublishTooManyPending =>
      'Du har allerede 3 spillelister som venter på godkjenning';

  @override
  String get playlistPublishRefused =>
      'Publisering avvist: sjekk sporene og de ventende forespørslene';

  @override
  String get playlistPublishFailed => 'Publiseringen mislyktes';

  @override
  String get playlistPublishWithdrawn => 'Spillelisten er privat igjen';

  @override
  String get playlistUnpublish => 'Gjør privat';

  @override
  String get playlistUnpublishSubtitle =>
      'Fjerner den fra de offentlige spillelistene';

  @override
  String get playlistRenamePublishedTitle =>
      'Gi en publisert spilleliste nytt navn?';

  @override
  String get playlistRenamePublishedBody =>
      'Det er navnet som gjennomgås: nytt navn sender spillelisten tilbake til gjennomgang og avpubliserer den i mellomtiden. Å legge til eller omorganisere spor gjør det ikke.';

  @override
  String playlistByAuthor(String author) {
    return 'av $author';
  }

  @override
  String get settingsSpectrumMode => 'Spektermodus';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Farget';

  @override
  String get settingsSpectrumModeBeam => 'Stråle';

  @override
  String get settingsSpectrumModeLine => 'Linje';

  @override
  String get settingsSpectrumModeRing => 'Ring';

  @override
  String get settingsPianoMode => 'Pianoets utseende';

  @override
  String get settingsPianoModeRoll => 'Klaviaturer';

  @override
  String get settingsPianoModeFalling => 'Fallende noter';

  @override
  String get settingsPianoColor => 'Farger';

  @override
  String get settingsPianoColorVoice => 'Per stemme';

  @override
  String get settingsPianoColorInstrument => 'Per instrument';

  @override
  String get settingsPianoGlow => 'Glød på anslåtte tangenter';

  @override
  String get settingsPianoLighting => 'Lys og skygger på tangentene';

  @override
  String get settingsPianoVoiceNames => 'Stemmenes navn';

  @override
  String get featuredAdditionsHeader => 'Nytt i katalogen';

  @override
  String get featuredAdditionsCard => 'Nettopp lagt til';

  @override
  String get featuredAdditionsPlaylist => 'De nylig tillagte låtene';

  @override
  String get releaseNotesTitle => 'Nyheter';

  @override
  String get releaseNotesV7Cpu =>
      'Appen jobber ikke lenger i bakgrunnen når ingenting spilles: mye mindre prosessor og batteri.';

  @override
  String get releaseNotesV7VizIdle =>
      'Visualiseringer står stille når avspillingen er stoppet, og er begrenset til 60 bilder per sekund (justerbart).';

  @override
  String get releaseNotesV7Subsongs =>
      'Rettet: på PC Engine, Master System og Atari ST (.sndh) startet noen spor sangen ved siden av.';

  @override
  String get releaseNotesV7Piano =>
      'Pianovisualiseringen forble tom med PC Engine-musikk.';

  @override
  String get releaseNotesV7Database =>
      'En database som ble skadet av en oppdatering, reparerer seg nå selv i stedet for å gjøre biblioteket utilgjengelig.';

  @override
  String get releaseNotesDataReset =>
      'Lokale data ble nullstilt for denne betaen. Bibliotek og spillelister bygges opp fra kontoen; nedlastinger må gjøres på nytt.';

  @override
  String get releaseNotesDismiss => 'Fortsett';

  @override
  String get pmManagePresets => 'Administrer presets';

  @override
  String get pmPickTooltip => 'Velg en preset';

  @override
  String get pmPickFilter => 'Filtrer presets';

  @override
  String get pmSourceTooltip => 'Presetkilde';

  @override
  String get pmAddToPlaylistTooltip => 'Legg til preset i en spilleliste';

  @override
  String pmSlowPresetDropped(String name) {
    return '«$name» er for tungt for denne enheten og ble lagt til side.';
  }

  @override
  String get pmSlowDeviceTitle => 'Denne enheten er for treg';

  @override
  String get pmSlowDeviceOff =>
      'Visualiseringen ble slått av: denne enheten klarer ikke Milkdrop-forhåndsinnstillinger.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count forhåndsinnstillinger lagt til side',
      one: '$count forhåndsinnstilling lagt til side',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'For trege på denne enheten. De hoppes over.';

  @override
  String get settingsPmSlowPresetsRestore => 'Gjenopprett';

  @override
  String get pmSourceBundled => 'Innebygde presets';

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
  String get pmPlaylistName => 'Navn på spillelisten';

  @override
  String get pmAddedToPlaylist => 'Lagt til i spillelisten';

  @override
  String get pmAlreadyInPlaylist => 'Finnes allerede i spillelisten';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Bla gjennom';

  @override
  String get pmTabPlaylists => 'Spillelister';

  @override
  String get pmTabPopular => 'Populær';

  @override
  String get pmTabSetAside => 'Lagt til side';

  @override
  String get pmSetAsideEmpty =>
      'Ingenting lagt til side. Her havner forhåndsinnstillinger som får enheten under 6 fps.';

  @override
  String get pmSetAsideRestoreAll => 'Gjenopprett alle';

  @override
  String get pmInstall => 'Installer';

  @override
  String get pmInstallQueued => 'Installasjon lagt i kø';

  @override
  String get pmUninstall => 'Avinstaller';

  @override
  String get pmUninstalled => 'Pack fjernet';

  @override
  String get pmUse => 'Bruk';

  @override
  String get pmDefaultPackBanner => 'Anbefalt startpack';

  @override
  String pmLicense(String license) {
    return 'Lisens: $license';
  }

  @override
  String get pmPacksOffline => 'Får ikke kontakt med serveren';

  @override
  String get pmSearchPresets => 'Søk etter presets…';

  @override
  String get pmPlayNow => 'Spill nå';

  @override
  String get pmDownloadAction => 'Last ned';

  @override
  String get pmDownloaded => 'Preset lastet ned';

  @override
  String get pmDownloadFailed => 'Nedlastingen mislyktes';

  @override
  String pmPreviewing(String name) {
    return 'Spiller: $name';
  }

  @override
  String get pmLocalSection => 'Mine spillelister';

  @override
  String get pmCuratedSection => 'Rewamp-spillelister';

  @override
  String get pmImportPlaylist => 'Last ned og bruk';

  @override
  String get pmPlaylistImported => 'Spillelisten er klar';

  @override
  String get pmImportFiles => 'Importer filer…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets importert',
      one: '$count preset importert',
      zero: 'Ingen presets importert',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets lagt til i projectM-biblioteket';

  @override
  String get pmNoPlaylists => 'Ingen preset-spillelister ennå';

  @override
  String get pmSourceApplied => 'Presetkilde tatt i bruk';

  @override
  String get pmPlaylistEmpty => 'Denne spillelisten er tom';

  @override
  String get pmDays7 => '7 dager';

  @override
  String get pmDays30 => '30 dager';

  @override
  String get pmDays365 => '1 år';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avspillinger',
      one: '$count avspilling',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Installasjonen mislyktes';

  @override
  String get pmSingleDownloads => 'Enkeltnedlastinger';

  @override
  String pmAvailableIn(String pack) {
    return 'Finnes i $pack';
  }

  @override
  String get pmCleanUp => 'Rydd opp';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets slettet',
      one: '$count preset slettet',
      zero: 'Ingenting å rydde',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Lås denne preseten';

  @override
  String get pmUnlockAction => 'Lås opp preseten';

  @override
  String get pmOrderRandom => 'Tilfeldige presets';

  @override
  String get pmOrderSequential => 'Presets i rekkefølge';

  @override
  String get pmUpdateAvailable => 'Oppdatering tilgjengelig';

  @override
  String get pmUpdate => 'Oppdater';

  @override
  String get pmSelectAll => 'Merk alle';

  @override
  String get pmSelectNone => 'Fjern merking';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merket',
      one: '$count merket',
      zero: 'Ingen merket',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Ubrukte teksturer';

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
  String get browseCharts => 'Topplister';

  @override
  String get chartsGlobal => 'Globalt';

  @override
  String get chartsByCollection => 'Etter samling';

  @override
  String get chartsTopSongs => 'Topplåter';

  @override
  String get chartsTopAlbums => 'Toppalbum';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Publiserte lister';

  @override
  String chartsUpdated(String date) {
    return 'Oppdatert $date';
  }

  @override
  String get chartsSource => 'Kilde';

  @override
  String get settingsMidiSynth => 'MIDI-synth';

  @override
  String get settingsMidiSynthAuto => 'Automatisk (MT-32 når filen ber om det)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (emulering)';

  @override
  String get settingsMt32Section => 'Roland MT-32-emulering';

  @override
  String get settingsMt32RomsTitle => 'MT-32-ROM-er';

  @override
  String get settingsMt32RomsMissing =>
      'Ingen brukbar ROM-samling — importer kontroll- og PCM-ROM fra en MT-32 eller CM-32L';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Aktiv samling: $set';
  }

  @override
  String get settingsMt32Import => 'Importer ROM-filer…';

  @override
  String get settingsMt32ImportSubtitle =>
      'Kontroll- + PCM-ROM (.rom/.bin), MAME-halvdeler godtas. ROM-er følger ikke med appen.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name er ikke en kjent MT-32-/CM-32L-ROM';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ROM-filer importert',
      one: '$count ROM-fil importert',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Modell';

  @override
  String get settingsMt32ModelAuto => 'Automatisk (CM-32L hvis tilgjengelig)';

  @override
  String get settingsMt32Reverb => 'Klang';

  @override
  String get engineDescMt32 =>
      'Roland MT-32-/CM-32L-emulering for MIDI (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Minispiller';

  @override
  String get miniWindowExit => 'Tilbake til hovedvinduet';

  @override
  String get miniWindowIdle => 'Ingenting spilles';

  @override
  String get settingsAlwaysOnTopTitle => 'Alltid øverst';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Holder vinduet over alle andre — både hovedvinduet og minispilleren';

  @override
  String get windowAlwaysOnTopOn => 'Alltid øverst: på';

  @override
  String get miniWindowCoverFill => 'Zoom omslaget så det fyller flaten';

  @override
  String get miniWindowCoverFit => 'Vis hele omslaget';

  @override
  String get releaseNotesV7Mt32 =>
      'Ny Roland MT-32-motor for MIDI-spillmusikk, med dine egne ROM-filer. Uten ROM-filer tilpasses en MIDI skrevet for MT-32 til General MIDI.';

  @override
  String get releaseNotesV7Xmp =>
      'Ti sjeldne modulformater spilles nå (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'Westwoods AdLib-musikk (.adl) spiller alle sporene sine, og BP SoundMon V1 gjenkjennes på Amiga.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac: en minispiller, kompakt eller med visualiseringen, og valget «Alltid øverst».';

  @override
  String get releaseNotesV7Instruments =>
      'Oscilloskop, noter og piano kan navngi og fargelegge hvert instrument, ikke bare hver stemme.';

  @override
  String get releaseNotesV7Podium =>
      'Søk: filtrer låtene som ble nummer 1, 2 eller 3 i en demoscenekonkurranse.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'For korte dellåter (lydeffekter fra spill) utelates fra «Spill alle» — terskel under Innstillinger → Avspilling.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Importene dine: slipp en hel mappe (arkiver pakkes ut), og opprett, gi nytt navn til eller flytt mapper.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI: trommene høres ikke lenger ut som et piano, og volumet klipper ikke lenger.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM: forhåndsinnstillinger gjentas ikke lenger fra én oppstart til den neste, og en forhåndsinnstilling blir ikke lenger feilaktig satt til side etter en pause.';

  @override
  String get libraryFileMissing => 'Filen mangler';
}
