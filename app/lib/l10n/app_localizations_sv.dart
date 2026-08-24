// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get navHome => 'Hem';

  @override
  String get navSearch => 'Sök';

  @override
  String get navLibrary => 'Bibliotek';

  @override
  String get noFileSelected => 'Ingen fil vald';

  @override
  String get openFile => 'Öppna fil';

  @override
  String get pickerLabelAudio => 'Ljud';

  @override
  String get formatNotSupported => 'Formatet stöds inte';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Formatet stöds inte: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Finns inte på den här enheten: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Filen finns inte längre på servern: $file';
  }

  @override
  String get failedToLoadFile => 'Det gick inte att läsa in filen';

  @override
  String get libraryEmptyHint =>
      'Dina artister, album och spellistor\nvisas här.';

  @override
  String get libraryPlaylists => 'Spellistor';

  @override
  String get libraryArtists => 'Artister';

  @override
  String get libraryAlbums => 'Album';

  @override
  String get libraryTracks => 'Låtar';

  @override
  String get libraryFavorites => 'Favoriter';

  @override
  String get libraryFavoritesSubtitle =>
      'Automatisk spellista med dina favoritlåtar';

  @override
  String get libraryRecentlyAdded => 'Nyligen tillagt';

  @override
  String get libraryEmpty => 'Inget här ännu';

  @override
  String get libraryRemoved => 'Borttagen från biblioteket';

  @override
  String get searchHint => 'Sök…';

  @override
  String get searchTypePlaceholder => 'Skriv en titel, artist eller album…';

  @override
  String get searchNoResults => 'Inga resultat';

  @override
  String get searchDownloading => 'Laddar ner…';

  @override
  String searchError(String message) {
    return 'Fel: $message';
  }

  @override
  String get tabAll => 'Låtar';

  @override
  String get tabArtists => 'Artister';

  @override
  String get tabAlbums => 'Album';

  @override
  String get tabProductions => 'Produktioner';

  @override
  String get filterWithVideo => 'Med video';

  @override
  String get videoUnavailable => 'Videon är inte tillgänglig';

  @override
  String get noItems => 'Inga objekt';

  @override
  String get sortRelevance => 'Relevans';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Nyligen spelat';

  @override
  String get noRecentTracks => 'Inga nyligen spelade låtar';

  @override
  String get openLocalFile => 'Öppna lokal fil';

  @override
  String get playerSourceLocal => 'lokal';

  @override
  String get browseFiles => 'Bläddra bland filer';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total resultat';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded inlästa…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded resultat';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded inlästa — skrolla för fler';
  }

  @override
  String countNLoaded(int n) {
    return '$n inlästa';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n fil(er)';
  }

  @override
  String get browseFilterByTitle => 'Filtrera efter titel…';

  @override
  String get browseNoSongs => 'Inga låtar tillgängliga';

  @override
  String get browseByFormat => 'Efter format';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtrera efter format…';

  @override
  String get browseByPlatform => 'Efter plattform';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Plattformsnamn…';

  @override
  String get browseByChip => 'Efter ljudchip';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 't.ex. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Efter artist';

  @override
  String get browseByArtistSubtitle => 'Bläddra bland kompositörerna';

  @override
  String get browseFilterByName => 'Filtrera efter namn…';

  @override
  String get browseNoArtistFound => 'Ingen artist hittades';

  @override
  String get browseNoArtistsAvailable => 'Inga artister tillgängliga';

  @override
  String get browseNoArtist => 'Inga artister';

  @override
  String get browseNoAlbum => 'Inga album';

  @override
  String get browseTopPacks => 'Top packs';

  @override
  String get browseTopPacksSubtitle => 'De högst rankade packen';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Top packs — $collection';
  }

  @override
  String get browseLatestPacks => 'Senaste packen';

  @override
  String get browseLatestPacksSubtitle => 'De senaste tilläggen';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Senaste packen — $collection';
  }

  @override
  String get browseAllSongs => 'Alla låtar';

  @override
  String get browseAllSongsSubtitleAlpha => 'Bläddra i bokstavsordning';

  @override
  String get browseAlphabetical => 'I bokstavsordning';

  @override
  String browseAllLabel(String collection) {
    return 'Alla — $collection';
  }

  @override
  String get browseCollections => 'Samlingar';

  @override
  String browseFilesCount(String count) {
    return '$count filer';
  }

  @override
  String get browseIndexing => 'Indexering pågår';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrera $name…';
  }

  @override
  String get browseAllYears => 'Alla år';

  @override
  String get browseAllYearsSubtitle => 'Alla låtar från partyt';

  @override
  String get browseNoCompo => 'Ingen compo indexerad för det här partyt.';

  @override
  String get browseOthers => 'Övriga';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n bidrag — placering',
      one: '$n bidrag — placering',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Spela spellistan';

  @override
  String get browsePlayAllRanked => 'Spela alla (i placeringsordning)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar — placeringsordning',
      one: '$n låt — placeringsordning',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Bläddra efter album';

  @override
  String get browsePlayAll => 'Spela alla';

  @override
  String get browseShuffle => 'Blanda';

  @override
  String get browseSearchInFolder => 'Sök i den här mappen…';

  @override
  String get browseFilterThisList => 'Filtrera listan…';

  @override
  String get browseSearchSubfolders => 'Sök i undermappar';

  @override
  String get browseEmptyFolder => 'Tom mapp';

  @override
  String browsePlaybackError(String message) {
    return 'Uppspelningen misslyckades: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar',
      one: '$n låt',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Visning';

  @override
  String get browseViewList => 'Lista';

  @override
  String get browseViewGrid => 'Rutnät';

  @override
  String get browseViewGridCompact => 'Kompakt rutnät';

  @override
  String get browseSearchAlbum => 'Sök efter ett album…';

  @override
  String get browseSearchArtist => 'Sök efter en artist…';

  @override
  String get browsePlayAlbum => 'Spela albumet';

  @override
  String get searchDownloadingAlbum => 'Laddar ner albumet…';

  @override
  String get searchCategoryChip => 'Chip';

  @override
  String get searchCategoryGroup => 'Grupper';

  @override
  String get artistRealName => 'Riktigt namn';

  @override
  String get artistAliases => 'Alias';

  @override
  String get artistBorn => 'Född';

  @override
  String get artistInterview => 'Intervju';

  @override
  String get audioOutput => 'Ljudutgång';

  @override
  String get audioOutputSystemDefault => 'Systemstandard';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Anteckningar';

  @override
  String get notePlacedBadge => 'Placerad i tävlingen';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '$count medlem',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Visa låtar';

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
  String get searchCategoryParty => 'Partyn';

  @override
  String get searchCategoryYear => 'År';

  @override
  String get searchCategoryOrigin => 'Ursprung';

  @override
  String get searchCategoryProduction => 'Produktion';

  @override
  String get searchCategoryProductionType => 'Prodtyper';

  @override
  String get searchCategoryPublisher => 'Utgivare';

  @override
  String get searchCategoryDeveloper => 'Utvecklare';

  @override
  String get searchCategoryArcadeBoard => 'Arkadkort';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'via artist';

  @override
  String get searchViaAlbum => 'via ett album';

  @override
  String get searchViaSong => 'via en låt';

  @override
  String get searchSortPopular => 'Populärt';

  @override
  String get searchSortYear => 'År';

  @override
  String get searchSortRandom => 'Slumpmässigt';

  @override
  String get searchSortRating => 'Betyg';

  @override
  String statsTopPercent(int percent) {
    return 'Topp $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count röster',
      one: '$count röst',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Stigande';

  @override
  String get searchSortDesc => 'Fallande';

  @override
  String get searchFilters => 'Filter';

  @override
  String get searchExactSearch => 'Exakt sökning';

  @override
  String get searchExactSearchSubtitle =>
      'Inaktiverar ungefärlig sökning (fuzzy)';

  @override
  String get searchTags => 'Taggar';

  @override
  String searchTagSearchHint(String category) {
    return 'Sök efter en tagg i « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Skriv för att söka efter taggar.';

  @override
  String get searchTagsAndLogic => 'Flera taggar = logiskt OCH.';

  @override
  String get searchFilterYear => 'År';

  @override
  String get searchFilterAll => 'alla';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Att filtrera på år utesluter odaterade låtar.';

  @override
  String get searchMinRating => 'Betyg ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Avbryt';

  @override
  String get searchReset => 'Återställ';

  @override
  String get searchApply => 'Tillämpa';

  @override
  String get searchClearRecent => 'Rensa senaste sökningarna';

  @override
  String get searchBrowse => 'Bläddra';

  @override
  String get searchBrowseHint =>
      'Välj en facett (grupp, chip, år…) för att utforska katalogen, eller starta Radio/Överraskning ovan.';

  @override
  String get searchDidYouMean =>
      'Få resultat — vill du prova en ungefärlig sökning?';

  @override
  String get searchYes => 'Ja';

  @override
  String get featuredCommunityTitle => 'Nytt från communityn';

  @override
  String get searchPlaylistSourceAll => 'Alla';

  @override
  String get searchPlaylistSourceUser => 'Community';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Plattform';

  @override
  String get filterCollection => 'Samling';

  @override
  String get videoWatchDemo => 'Se demon';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Samling: $name';
  }

  @override
  String get searchCollectionAll => 'Alla';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Slumpmässig kö utifrån de aktuella filtren';

  @override
  String get searchSurprise => 'Överraskning';

  @override
  String get searchSurpriseTooltip => 'En slumpmässig låt';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Inga låtar';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar',
      one: '$n låt',
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
  String get searchChooseCollection => 'Välj samling';

  @override
  String get searchFilterCollections => 'Filtrera samlingar…';

  @override
  String get searchFilterPlaceholder => 'Filtrera…';

  @override
  String searchAllOf(String label) {
    return 'Alla ($label)';
  }

  @override
  String get searchNoMatch => 'Ingen träff';

  @override
  String get searchNoPlaylist => 'Inga spellistor';

  @override
  String get engineDescOpenmpt => 'Trackermoduler (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — ljudchip, oscilloskop per kanal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN-arkiv';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — röster per kanal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp-motor)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX-chiptunes (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace => 'Multichip-chiptunes .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amiga custom-chip-format via 68k-emulering (~320 filändelser)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bitars POKEY (.sap/.rmt/.cmc/.tmc/…)';

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
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ-synt (16 röster)';

  @override
  String get engineDescV2m => 'V2M-synt (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — äkta 68000-emulering + YM2149 + STE-DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300-emulering + RSP-ljud';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ-emulering';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound-chip';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — äkta AY-3-8910/YM2149-synt';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixels egen motor';

  @override
  String get engineDescPxtone => 'Pixels tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — äkta 68000 via emu68';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA-FM + SSG + PPZ8-samplingar';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ .pdx-samplingar), YM2151-FM';

  @override
  String get engineDescFmp =>
      'PC-98 FMP-drivrutin — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612-FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Strömmade spelljudformat (700+, inkl. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — reservavkodare';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total låtar',
      one: '$loaded / 1 låt',
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
      other: '$n låtar',
      one: '$n låt',
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
      one: '$n grupp',
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
      other: '$n länder',
      one: '$n land',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Mappar';

  @override
  String get featuredTitle => 'Utvalt i dag';

  @override
  String featuredPartyNow(String party) {
    return '$party pågår just nu — pallplatserna från tidigare upplagor';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          '$party börjar om $days dagar — pallplatserna från tidigare upplagor',
      one: '$party börjar i morgon — pallplatserna från tidigare upplagor',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series-säsong — pallplatserna från tidigare upplagor';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Släppt i $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'För $age år sedan: spelen från $year',
      one: 'För ett år sedan: spelen från $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade-talet';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'För $age år sedan: spelen från $year',
      one: 'För ett år sedan: spelen från $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Släppta i $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Årsdagar';

  @override
  String get featuredBirthdayHeader => 'Dagens födelsedagar';

  @override
  String get featuredBirthdayWeekHeader => 'Veckans födelsedagar';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist fyller år den här veckan';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spellistor',
      one: '$count spellista',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Försök igen';

  @override
  String get commonOptions => 'Alternativ';

  @override
  String get commonDownload => 'Ladda ner';

  @override
  String get commonDeleteDownload => 'Radera nedladdning';

  @override
  String get commonAddToPlaylist => 'Lägg till i spellista';

  @override
  String get commonPlayNext => 'Spela härnäst';

  @override
  String get commonAddToQueueEnd => 'Lägg till sist i kön';

  @override
  String get commonAddToFavorites => 'Lägg till i favoriter';

  @override
  String get commonRemoveFromFavorites => 'Ta bort från favoriter';

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
  String get subsongDeleteDownloadTitle => 'Radera den här nedladdningen?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Filen och dess lokala poster (historik, spår) raderas.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Det gick inte att läsa spåren';

  @override
  String subsongTrackNumber(int number) {
    return 'Spår $number';
  }

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
  String get subsongPlayAll => 'Spela alla';

  @override
  String get albumDownloading => 'Laddar ner albumet…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Laddar ner albumet… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Ladda ner albumet för att se dess spår';

  @override
  String get albumNotDownloadedHint =>
      'Albumet är inte nedladdat — starta uppspelningen för att ladda ner det';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count låtar',
      one: '$count låt',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Läser in detaljer…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Spela albumet';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objekt',
      one: '$count objekt',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Spela låten från sökningen först för att ladda ner den';

  @override
  String get libraryAddedTrack => 'Låten lades till i biblioteket';

  @override
  String get libraryAddedAlbum => 'Albumet lades till i biblioteket';

  @override
  String get libraryAddedArtist => 'Artisten lades till i biblioteket';

  @override
  String get libraryRemovedTrack => 'Låten togs bort från biblioteket';

  @override
  String get libraryRemovedAlbum => 'Albumet togs bort från biblioteket';

  @override
  String get libraryRemovedArtist => 'Artisten togs bort från biblioteket';

  @override
  String songTilePlayFailed(String message) {
    return 'Uppspelningen misslyckades: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Nedladdningen misslyckades — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Laddar ner — $label';
  }

  @override
  String get downloadsTitle => 'Hämtningar';

  @override
  String get downloadsEmpty => 'Inga väntande hämtningar';

  @override
  String get downloadsPause => 'Pausa';

  @override
  String get downloadsResume => 'Återuppta';

  @override
  String get downloadsCancel => 'Avbryt nedladdningen';

  @override
  String get downloadsClear => 'Ta bort alla';

  @override
  String get downloadsPausedBanner =>
      'Hämtningar pausade — den pågående filen slutförs först';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Laddar ner — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Spellista';

  @override
  String get miniPlayerHideQueue => 'Dölj spellistan';

  @override
  String get transportShuffle => 'Blanda';

  @override
  String get transportShuffleOn => 'Blandning på';

  @override
  String get transportLoopOff => 'Upprepning av';

  @override
  String get transportLoopQueue => 'Upprepa: kön';

  @override
  String get transportLoopTrack => 'Upprepa: aktuell låt';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spektrum';

  @override
  String get vizVoices => 'Röster';

  @override
  String get vizNotes => 'Noter';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Rullningsläge';

  @override
  String get patternSmoothScroll => 'Mjuk rullning';

  @override
  String get patternVolumeBars => 'Volymstaplar';

  @override
  String get patternColorScheme => 'Färgschema';

  @override
  String get patternSize => 'Storlek';

  @override
  String get patternColumns => 'Kolumner';

  @override
  String get patternColumnsAll => 'Fullständig';

  @override
  String get patternColumnsNoteInstr => 'Reducerad';

  @override
  String get patternColumnsNote => 'Minimal';

  @override
  String get vizClose => 'Stäng visualiseraren';

  @override
  String get vizFullscreen => 'Helskärm';

  @override
  String get vizExitFullscreen => 'Avsluta helskärm';

  @override
  String get vizPrevPreset => 'Föregående preset';

  @override
  String get vizNextPreset => 'Nästa preset';

  @override
  String get vizProjectmUnavailable => 'projectM är inte tillgängligt';

  @override
  String get voicesTitle => 'Röster';

  @override
  String get voicesNone => 'Inga röster för den här låten.';

  @override
  String get voicesLongPressSolo => 'långtryck = solo';

  @override
  String get voicesMuteAll => 'Tysta alla';

  @override
  String get voicesUnmuteAll => 'Slå på alla';

  @override
  String get voicesStereoOutput => 'Stereoutgång';

  @override
  String get voicesLeft => 'Vänster';

  @override
  String get voicesRight => 'Höger';

  @override
  String get enginesFormatsTitle => 'Spelbara format';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats spelbara format, fördelade på $engines uppspelningsmotorer.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count format',
      one: '1 format',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Cover på $title av $artist';
  }

  @override
  String stilCover(String work) {
    return 'Cover på $work';
  }

  @override
  String get playerQueue => 'Kö';

  @override
  String get queueEdit => 'Redigera';

  @override
  String get queueEditDone => 'Klar';

  @override
  String get queueClear => 'Töm kön';

  @override
  String get queueClearConfirmTitle => 'Töm kön?';

  @override
  String get queueClearConfirmBody => 'Kön töms och uppspelningen stoppas.';

  @override
  String get queueClearConfirm => 'Töm';

  @override
  String get queueRemoveSelected => 'Ta bort markerade';

  @override
  String get queueRemoveTrack => 'Ta bort från kön';

  @override
  String get queueReorder => 'Ändra ordning';

  @override
  String get playerArtwork => 'Omslag';

  @override
  String get playerVisualizer => 'Visualiserare';

  @override
  String get playerVoices => 'Röster';

  @override
  String get playerTrackInfo => 'Låtinfo';

  @override
  String get playerShowQueue => 'Spellista';

  @override
  String get playerHideQueue => 'Dölj spellistan';

  @override
  String get playerNoTrackInfo => 'Ingen information tillgänglig.';

  @override
  String get playerViewSubsongs => 'Visa subsongs';

  @override
  String get playerViewAlbum => 'Visa album';

  @override
  String get playerViewArtist => 'Visa artist';

  @override
  String get playerAddToPlaylist => 'Lägg till i spellista';

  @override
  String get queueAddToPlaylist => 'Lägg till kön i en spellista';

  @override
  String get playerMoreOptions => 'Fler alternativ';

  @override
  String get playerClose => 'Stäng';

  @override
  String get playerCancel => 'Avbryt';

  @override
  String get playerDelete => 'Radera';

  @override
  String get playerAddFavorite => 'Lägg till i favoriter';

  @override
  String get playerRemoveFavorite => 'Ta bort från favoriter';

  @override
  String get playerAddToLibrary => 'Lägg till i biblioteket';

  @override
  String get playerRemoveFromLibrary => 'Ta bort från biblioteket';

  @override
  String get playerAddedToLibrary => 'Låten lades till i biblioteket';

  @override
  String get playerRemovedFromLibrary => 'Låten togs bort från biblioteket';

  @override
  String get playerDeleteDownload => 'Radera nedladdning';

  @override
  String get playerRedownload => 'Ladda ner filen igen';

  @override
  String get playerRedownloadUnavailable =>
      'Kan inte ladda ner den här filen igen';

  @override
  String get playerDeleteDownloadTitle => 'Radera nedladdningen?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Filen och dess lokala poster (historik, spår) raderas.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Dina trender';

  @override
  String get homeYourAllTimeTop => 'Din topplista genom tiderna';

  @override
  String get homeTrending => 'Trendar nu';

  @override
  String get homeFeaturedPlaylists => 'Utvalda spellistor';

  @override
  String get homeAllTimeTop => 'Topplista genom tiderna';

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
      other: '$n uppspelningar',
      one: '$n uppspelning',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar',
      one: '$n låt',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Tom eller oläslig spellista';

  @override
  String get homeExtractingArchive => 'Packar upp arkivet…';

  @override
  String get homeArchiveEmpty => 'Inga spelbara filer i arkivet';

  @override
  String get homeNothingPlayable => 'Inget spelbart i urvalet';

  @override
  String get homeAlbumLoadFailed => 'Det gick inte att läsa in albumet';

  @override
  String get homeSongLoadFailed => 'Det gick inte att läsa in låten';

  @override
  String get navStats => 'Statistik';

  @override
  String get navSettings => 'Inställningar';

  @override
  String get playlistMoveUp => 'Flytta till överordnad mapp';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spellistor',
      one: '$n spellista',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n undermappar',
      one: '$n undermapp',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Den här mappen och allt innehåll tas bort permanent:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Den här mappen tas bort.';

  @override
  String get playlistFolderRoot => 'Rot';

  @override
  String get playlistMoveToFolder => 'Flytta till mapp';

  @override
  String playlistDeleteTitle(String name) {
    return 'Ta bort \"$name\"?';
  }

  @override
  String get playlistDeleteBody => 'Den här spellistan tas bort permanent.';

  @override
  String get playlistRenameFolderTitle => 'Byt namn på mapp';

  @override
  String get playlistClearFavorites => 'Ta bort alla favoriter';

  @override
  String get playlistClearFavoritesTitle => 'Ta bort alla favoriter?';

  @override
  String get playlistClearFavoritesBody =>
      'Du förlorar alla dina favoritlåtar. Detta kan inte ångras.';

  @override
  String get playlistRemoveFromLibrary => 'Ta bort från biblioteket';

  @override
  String get playlistServerReadOnly => 'Serverspellista · skrivskyddad';

  @override
  String get navAbout => 'Om';

  @override
  String get navMore => 'Mer';

  @override
  String get shellAlbumQueuedAtEnd => 'Albumet lades till sist i kön';

  @override
  String get shellAlbumQueuedNext => 'Albumet spelas härnäst';

  @override
  String get shellAddingToQueue => 'Lägger till i kön…';

  @override
  String get shellAddingNext => 'Lägger till som nästa…';

  @override
  String shellDownloadFailed(String error) {
    return 'Nedladdningen misslyckades: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spår lades till i kön',
      one: '$count spår lades till i kön',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" lades till sist i kön';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" spelas härnäst';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Nedladdningen misslyckades: $title — hoppar till nästa låt';
  }

  @override
  String get shellNetworkUnavailable =>
      'Uppspelningen stoppades: nätverket verkar vara otillgängligt.';

  @override
  String get statsTitle => 'Statistik';

  @override
  String statsPeriodDays(int n) {
    return '$n dagar';
  }

  @override
  String get statsPeriodThisYear => 'I år';

  @override
  String get statsPeriodAll => 'Alla tider';

  @override
  String get statsByMonthOrYear => 'Efter månad / år…';

  @override
  String get statsByYear => 'Efter år';

  @override
  String get statsByMonth => 'Efter månad';

  @override
  String get statsPlaysLabel => 'Uppspelningar';

  @override
  String get statsTracksLabel => 'Låtar';

  @override
  String get statsArtistsLabel => 'Artister';

  @override
  String get statsAlbumsLabel => 'Album';

  @override
  String get statsListenTime => 'Lyssningstid';

  @override
  String get statsByCollection => 'Per samling';

  @override
  String get statsByFormat => 'Per format';

  @override
  String get statsByEngine => 'Per motor';

  @override
  String get statsPlaylistsLabel => 'Spellistor';

  @override
  String get statsLocalFilesSection => 'Nedladdade filer';

  @override
  String get statsFilesLabel => 'Filer';

  @override
  String get statsSpaceLabel => 'Diskutrymme';

  @override
  String get statsNoPlaysInPeriod =>
      'Inga uppspelningar under den här perioden';

  @override
  String get statsNoPlays => 'Inga uppspelningar';

  @override
  String get statsTopTracks => 'Topplåtar';

  @override
  String get statsTopAlbums => 'Toppalbum';

  @override
  String get statsTopArtists => 'Toppartister';

  @override
  String statsTopTracksIn(String period) {
    return 'Topplåtar — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Toppalbum — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Toppartister — $period';
  }

  @override
  String get statsSeeAll => 'Visa alla';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n uppspelningar',
      one: '$n uppspelning',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar',
      one: '$n låt',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max $n';
  }

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get commonCreate => 'Skapa';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Radera';

  @override
  String get commonRename => 'Byt namn';

  @override
  String get commonSort => 'Sortera';

  @override
  String get commonPlayAll => 'Spela alla';

  @override
  String get sortName => 'Namn';

  @override
  String get sortTitle => 'Titel';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Tillagd';

  @override
  String get commonClear => 'Rensa';

  @override
  String get sortRecentlyModified => 'Nyligen ändrade';

  @override
  String get sortCreationDate => 'Skapandedatum';

  @override
  String get playlistNameHint => 'Namn';

  @override
  String get playlistNew => 'Ny spellista';

  @override
  String get playlistNewFolder => 'Ny mapp';

  @override
  String get playlistNewTooltip => 'Ny spellista / mapp';

  @override
  String get playlistAddTo => 'Lägg till i spellista';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Lägg till i $n spellistor',
      one: 'Lägg till i $n spellista',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Välj en spellista';

  @override
  String get playlistFilterHint => 'Filtrera spellistor…';

  @override
  String get playlistSearchHint => 'Sök efter en spellista…';

  @override
  String get playlistNoMatch => 'Ingen spellista matchar';

  @override
  String get playlistNoneCreateHint => 'Ingen spellista — skapa en med +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar',
      one: '$n låt',
      zero: 'Inga låtar',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Finns redan';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n objekt finns redan i de valda spellistorna.',
      one: '$n objekt finns redan i de valda spellistorna.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Hoppa över dubbletter';

  @override
  String get playlistAddAgain => 'Lägg till igen';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar tillagda',
      one: '$n låt tillagd',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m spellistor',
      one: '$n spellista',
    );
    return '$_temp0 i $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Det gick inte att lägga till: $error';
  }

  @override
  String get playlistRenameTitle => 'Byt namn på spellistan';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Radera mappen ”$name”?';
  }

  @override
  String get playlistDeleteFolderBody => 'Innehållet flyttas upp en nivå.';

  @override
  String get playlistEmpty => 'Tom spellista';

  @override
  String get playlistRemoveEntry => 'Ta bort från spellistan';

  @override
  String get trackOptionsAddToLibrary => 'Lägg till i biblioteket';

  @override
  String get trackOptionsRemoveFromLibrary => 'Ta bort från biblioteket';

  @override
  String get trackOptionsAddedToLibrary => 'Låten lades till i biblioteket';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'Låten togs bort från biblioteket';

  @override
  String get trackOptionsViewAlbum => 'Visa album';

  @override
  String get trackOptionsViewArtist => 'Visa artist';

  @override
  String get trackOptionsPlayNow => 'Spela nu';

  @override
  String get trackOptionsPlayNext => 'Spela härnäst';

  @override
  String get trackOptionsAddToQueueEnd => 'Lägg till sist i kön';

  @override
  String get trackOptionsPlayLast => 'Spela sist';

  @override
  String get trackOptionsDeleteDownload => 'Radera nedladdning';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Radera den här nedladdningen?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Filen och dess lokala poster (historik, spår) raderas.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Nedladdningen raderades';

  @override
  String get trackOptionsAddToFavorites => 'Lägg till i favoriter';

  @override
  String get trackOptionsRemoveFromFavorites => 'Ta bort från favoriter';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Albumet lades till i favoriter';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Albumet togs bort från favoriter';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Albumet är inte nedladdat — inget att radera';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Radera det nedladdade albumet?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Mappen och alla dess lokala poster (spår, historik) raderas.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Albumet raderades från den lokala lagringen';

  @override
  String get trackOptionsRedownloadAlbum => 'Ladda ner albumet igen';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Skriver om filer OCH lokala poster';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Radera albumets filer';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Nedladdad mapp + lokala poster (historik)';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String get settingsGeneral => 'Allmänt';

  @override
  String get settingsGeneralSubtitle => 'Tema';

  @override
  String get settingsVisualisation => 'Visualisering';

  @override
  String get settingsVisualisationSubtitle =>
      'Oscilloskop, omslag i bakgrunden';

  @override
  String get settingsPlayback => 'Uppspelning';

  @override
  String get settingsPlaybackSubtitle => 'Loopar, uttoning, tystnad';

  @override
  String get settingsEngines => 'Motorer';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDataSubtitle => 'ID, historik, återställning';

  @override
  String get settingsBackupExport => 'Exportera en säkerhetskopia';

  @override
  String get settingsBackupExportSubtitle =>
      'Spara ditt bibliotek, spellistor och inställningar till en fil';

  @override
  String get settingsBackupImport => 'Importera en säkerhetskopia';

  @override
  String get settingsBackupImportSubtitle =>
      'Återställ dina data från en säkerhetskopia';

  @override
  String get settingsBackupExportFailed =>
      'Export av säkerhetskopia misslyckades';

  @override
  String get settingsBackupImportConfirmTitle => 'Importera säkerhetskopia?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Detta ersätter ditt bibliotek, dina spellistor och inställningar på den här enheten. Nedladdade filer behålls.';

  @override
  String get settingsBackupImportConfirm => 'Importera';

  @override
  String get settingsBackupImportedTitle => 'Säkerhetskopia importerad';

  @override
  String get settingsBackupImportedBody =>
      'Dina data har återställts. Starta om appen för att tillämpa allt.';

  @override
  String get settingsBackupTooNew =>
      'Den här säkerhetskopian skapades av en nyare version av appen';

  @override
  String get settingsBackupInvalid => 'Ingen giltig Rewamp-säkerhetskopia';

  @override
  String get settingsBackupImportFailed =>
      'Import av säkerhetskopia misslyckades';

  @override
  String get settingsAbout => 'Om';

  @override
  String get settingsAboutSubtitle => 'Medverkande och licenser';

  @override
  String get settingsCreditsSubtitle => 'Bibliotek, data och komponenter';

  @override
  String get settingsSupport => 'Kontakt och support';

  @override
  String get settingsSupportSubtitle => 'Kontakta oss, webbplats';

  @override
  String get settingsSupportEmail => 'Skicka e-post';

  @override
  String get settingsSupportEmailSubtitle => 'Fråga, bugg eller förslag';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — support';

  @override
  String get settingsSupportEmailIntro =>
      'Beskriv din fråga, bugg eller ditt förslag ovan. Informationen nedan hjälper oss att hjälpa dig.';

  @override
  String get settingsSupportWebsite => 'Webbplats';

  @override
  String get settingsDonation => 'Stöd Rewamp';

  @override
  String get settingsDonationSubtitle => 'En dricks, om du vill';

  @override
  String get settingsDonationBlurb =>
      'Rewamp är gratis och reklamfritt — ett passionsprojekt tillägnat att bevara demoscene- och retrokulturen. Donationer hjälper till att finansiera appens utveckling och täcka kostnaderna för databasens hosting. Inget krav: om appen ger dig glädje är en liten gest alltid uppskattad.';

  @override
  String get settingsDonationFloppy => 'En diskett';

  @override
  String get settingsDonationCartridge => 'En kassett';

  @override
  String get settingsDonationBox => 'Ett spel i box';

  @override
  String get settingsDonationCustom => 'Välj ett belopp';

  @override
  String get settingsCancel => 'Avbryt';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Radera';

  @override
  String get settingsReset => 'Återställ';

  @override
  String get settingsRenew => 'Förnya';

  @override
  String get settingsOff => 'Av';

  @override
  String get settingsOn => 'På';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Oändlig';

  @override
  String get settingsDefault => 'Standard';

  @override
  String get settingsCoreNoScope => 'inget oscilloskop';

  @override
  String get settingsNone => 'Ingen';

  @override
  String get settingsLevelLow => 'Låg';

  @override
  String get settingsLevelHigh => 'Hög';

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
  String get settingsThemeLight => 'Ljust';

  @override
  String get settingsThemeDark => 'Mörkt';

  @override
  String get settingsArtworkTintTitle => 'Tona spelaren efter omslaget';

  @override
  String get settingsArtworkTintSubtitle =>
      'Spelaren tar omslagets dominerande färg';

  @override
  String get settingsGlassEffectTitle => 'Liquid glass-effekt';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lins och oskärpa på de nedre fälten — stäng av på långsamma enheter';

  @override
  String get settingsResetSection => 'Återställ det här avsnittet';

  @override
  String get settingsResetEngine => 'Återställ den här motorn';

  @override
  String get settingsResetChoices => 'Återställ de här valen';

  @override
  String get settingsResetToDefault => 'Standardvärde';

  @override
  String get settingsStartInVizTitle => 'Starta i visualiseringsläge';

  @override
  String get settingsStartInVizSubtitle =>
      'Spelaren öppnas med oscilloskopen i stället för omslaget';

  @override
  String get settingsVoiceGridTitle => 'Rutnät för röstoscilloskopet';

  @override
  String get settingsVoiceGridSubtitle =>
      'Visa kanterna som skiljer rösterna åt';

  @override
  String get settingsKeepAwakeTitle => 'Håll skärmen tänd';

  @override
  String get settingsKeepAwakeSubtitle =>
      'När en visualisering visas släcks eller låses inte skärmen';

  @override
  String get settingsVoiceNamesTitle => 'Röstnamn';

  @override
  String get settingsVoiceNamesSubtitle => 'Visa varje rösts namn i dess ram';

  @override
  String get settingsLineThickness => 'Linjetjocklek';

  @override
  String get settingsColors => 'Färger';

  @override
  String get settingsScopeVoiceColor => 'Röstoscilloskop';

  @override
  String get settingsStereoColors => 'Stereo: färger';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo vänster';

  @override
  String get settingsStereoRightColor => 'Stereo höger';

  @override
  String get settingsNotation => 'Notation (noter)';

  @override
  String get settingsNotePalette => 'Färgpalett';

  @override
  String get settingsNoteBoxStyle => 'Blockstil';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'CRT-effekter';

  @override
  String get settingsCrtGlow => 'Glöd (glow)';

  @override
  String get settingsCrtSpeed => 'Intensitet / hastighet';

  @override
  String get settingsArtworkOpacity => 'Opacitet för omslaget i bakgrunden';

  @override
  String get settingsProjectMTitle => 'projectM-inställningar';

  @override
  String get settingsProjectMSubtitle => 'Presets, övergångar, kvalitet, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Aviseringar vid spårbyte';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Systemavisering med det nya spårets titel';

  @override
  String get settingsSilenceDetection => 'Tystnadsdetektering';

  @override
  String get settingsSilenceSkipTitle => 'Hoppa till nästa låt vid tystnad';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Går vidare automatiskt när utsignalen förblir tyst';

  @override
  String get settingsSilenceDelay => 'Fördröjning vid tystnad';

  @override
  String get settingsDefaultDuration => 'Standardlängd';

  @override
  String get settingsDefaultDurationHelp =>
      'Används när en låt inte anger någon känd längd (ingen tagg, inga metadata från servern) — hindrar den från att spela eller loopa i all evighet. Gäller aldrig Amiga-låtar (UADE), som har sin egen databas med låtlängder.';

  @override
  String get settingsForcedLoopHeader => 'Framtvingad loop / uttoning';

  @override
  String get settingsForcedLoopHelp =>
      'Vissa format loopar ett bestämt avsnitt (VGM, trackermoduler…); andra gör det inte. \"Oändlig\" ignorerar låtens naturliga slut.';

  @override
  String get settingsForceLoopCount => 'Tvinga fram antalet loopar';

  @override
  String get settingsLoopCount => 'Antal loopar';

  @override
  String get settingsForceFadeout => 'Tvinga fram en uttoning';

  @override
  String get settingsFadeoutDuration => 'Uttoningens längd';

  @override
  String get settingsResetEnginesTitle => 'Återställa motorinställningarna?';

  @override
  String get settingsResetEnginesBody =>
      'Alla motorinställningar återgår till sina standardvärden.';

  @override
  String get settingsResetDefaultsTitle => 'Återställ till standardvärdena';

  @override
  String get settingsResetDefaultsSubtitle => 'Alla motorer';

  @override
  String get settingsDefaultDecoders => 'Standardavkodare';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Format som flera motorer kan spela';

  @override
  String get settingsDecodersHelp =>
      'Vissa format kan spelas av flera motorer. Välj vilken som ska användas som standard — alla andra format dirigeras automatiskt.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga-trackers (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — kvalitet, filter, alternativ per chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — högpassfilter';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont som används';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolation, lågpass, eko';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorering, hörlurar, förstärkning, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — klocka, modell, ReSIDfp-filter';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — harmoniskt läge i stereo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, reverb';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612-, OPL3-, QSound-kärnor…';

  @override
  String get settingsMasterVolume => 'Huvudvolym';

  @override
  String get settingsAmigaFilter => 'Amiga-filter';

  @override
  String get settingsInterpolation => 'Interpolation';

  @override
  String get settingsPolyphony => 'Polyfoni';

  @override
  String get settingsReverb => 'Reverb';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Ingen';

  @override
  String get settingsInterpLinear => 'Linjär';

  @override
  String get settingsInterpCubic => 'Kubisk';

  @override
  String get settingsInterpSinc => 'Sinc (bäst)';

  @override
  String get settingsStereoSeparation => 'Stereoseparation';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Avslutar spåret när motorn upptäcker en lång tystnad';

  @override
  String get settingsStereoDepth => 'Stereodjup';

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
      'Tillämpas omedelbart, även under uppspelning.';

  @override
  String get settingsAppliedNextTrack => 'Tillämpas på nästa låt som läses in.';

  @override
  String get settingsSidEmulation => 'Emulering';

  @override
  String get settingsSidResidfp => 'ReSIDfp (exakt)';

  @override
  String get settingsSidLite => 'SIDLite (snabb)';

  @override
  String get settingsSidSampling => 'Sampling';

  @override
  String get settingsSidSamplingInterp => 'Interpolation (snabb)';

  @override
  String get settingsSidSamplingResample => 'Resample (bäst)';

  @override
  String get settingsSidClock => 'Klocka';

  @override
  String get settingsSidModel => 'SID-modell';

  @override
  String get settingsSidFilter => 'SID-filter';

  @override
  String get settingsSidForceSecond => 'Tvinga fram en andra SID';

  @override
  String get settingsSidSecondSubtitle => '2SID-låtar i stereo';

  @override
  String get settingsSidSecondAddr => 'Adress för andra SID';

  @override
  String get settingsSidForceThird => 'Tvinga fram en tredje SID';

  @override
  String get settingsSidThirdAddr => 'Adress för tredje SID';

  @override
  String get settingsSidAutoFilter => 'Automatiskt filterområde för 6581';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Värdet som rekommenderas för låtens upphovsperson (sidplayfp-tabeller)';

  @override
  String get settingsSid6581Range => 'Filterområde 6581';

  @override
  String get settingsSid6581Curve => 'Filterkurva 6581';

  @override
  String get settingsSid8580Curve => 'Filterkurva 8580';

  @override
  String get settingsSidNote =>
      'SID-filter och kurvor tillämpas direkt; emulering/sampling/klocka/modell/andra-tredje SID träder i kraft vid nästa låt.';

  @override
  String get settingsAudioOutput => 'Ljudutgång';

  @override
  String get settingsAdplugNote =>
      'Surround: två lätt ostämda OPL-chip. Tillämpas på nästa låt.';

  @override
  String get settingsHeSpuMain => 'Huvudröster (SPU)';

  @override
  String get settingsHeSpuReverb => 'Reverb (SPU)';

  @override
  String get settingsNsfQuality => 'Kvalitet (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Lågpassfilter';

  @override
  String get settingsHighpassFilter => 'Högpassfilter';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC tvingad';

  @override
  String get settingsNsfRegionPalForced => 'PAL tvingad';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy tvingad';

  @override
  String get settingsNsfForceIrq => 'Tvinga fram IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulser (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — triangel / brus / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Slå på ljudet vid reset';

  @override
  String get settingsNsfPhaseRefresh => 'Uppdatera fasen';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Nollställ fasen när perioden skrivs';

  @override
  String get settingsNsfNonlinearMixer => 'Icke-linjär mixning';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      '2A03:ans verkliga mixning (annars linjär)';

  @override
  String get settingsNsfDutySwap => 'Byt plats på duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Ordningen på 25 % / 50 % duty';

  @override
  String get settingsNsfNegateSweep => 'Negativ sweep vid init';

  @override
  String get settingsNsfEnable4011 => 'Register \$4011 aktiverat';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Direkt DAC-utgång (originalets klick)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodiskt brus';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => 'Brusgeneratorns korta läge';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM-antiklick';

  @override
  String get settingsNsfRandomizeNoise => 'Slumpa bruset vid init';

  @override
  String get settingsNsfTriangleMute => 'Tysta triangeln';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Tystar triangeln vid ultraljudsperioder';

  @override
  String get settingsNsfRandomizeTri => 'Slumpa triangeln vid init';

  @override
  String get settingsNsfDpcmReverse => 'Omvänd DPCM';

  @override
  String get settingsNsfN163Serial => 'Seriell multiplexering';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'N163:ans verkliga surr i låtar med flera röster';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Skrivskyddad fas';

  @override
  String get settingsNsfN163LimitWavelength => 'Begränsa våglängden';

  @override
  String get settingsNsfFdsCutoff => 'Lågpassbrytpunkt';

  @override
  String get settingsNsfFds4085Reset => 'Reset av \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Skrivskydd';

  @override
  String get settingsNsfVrc7Patch => 'Patchuppsättning';

  @override
  String get settingsNsfVrc7Opll => 'OPLL-läge';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Emulera en YM2413 i stället för VRC7';

  @override
  String get settingsGbsHpFilter => 'Högpassfilter (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klassisk GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Eko';

  @override
  String get settingsUadePostfx => 'Efterbehandling';

  @override
  String get settingsUadePostfxSubtitle =>
      'Aktiverar effektkedjan (krävs för allt nedan)';

  @override
  String get settingsUadePan => 'Panorering (stereoseparation)';

  @override
  String get settingsUadePanValue => 'Panoreringsmängd';

  @override
  String get settingsUadeHeadphones => 'Hörlurar';

  @override
  String get settingsUadeLed => 'LED (Paula-filter)';

  @override
  String get settingsUadeLedAuto => 'Auto (per låt)';

  @override
  String get settingsUadeLedOn => 'Tvingad PÅ';

  @override
  String get settingsUadeLedOff => 'Tvingad AV';

  @override
  String get settingsUadeFilterType => 'Filtertyp';

  @override
  String get settingsUadeGain => 'Förstärkning';

  @override
  String get settingsUadeGainValue => 'Förstärkningsmängd';

  @override
  String get settingsSoundfontLoading => 'Läser in katalogen…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Katalogen är inte tillgänglig ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Nedladdningen misslyckades: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importera en SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Välj en .sf2-fil på den här enheten';

  @override
  String get settingsSoundfontImported => 'Importerad';

  @override
  String get settingsSoundfontInvalid => 'Filen är inte en SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Importen misslyckades — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Radera filen';

  @override
  String get settingsCreditsHeader => 'Medverkande & licenser';

  @override
  String get settingsRightsNotice =>
      'Rewamp är en spelare: den lagrar inga filer och distribuerar ingen musik. Låtarna kommer från bevarandearkiv på nätet och förblir rättighetsinnehavarnas egendom. Det är ditt ansvar att se till att lyssnandet, nedladdningen och lagringen följer gällande rättigheter och lagen i ditt land.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count format stöds',
      one: '$count format stöds',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fördelade på $count uppspelningsmotorer — se detaljerna',
      one: 'Hanteras av $count uppspelningsmotor — se detaljerna',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga-låtlängder & metadata';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb av Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64/SID-data & omslagsbilder';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadata och bilder för C64-spel.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2-typsnitt';

  @override
  String get settingsFt2FontSubtitle =>
      'Patternvisualiserarens FastTracker II-stil använder FT2-bitmapptypsnittet från ft2-clone av 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url kopierad';
  }

  @override
  String get settingsOpenLink => 'Öppna länken';

  @override
  String get settingsEnginesHeader => 'Uppspelningsmotorer';

  @override
  String get settingsComponentsHeader => 'Övriga komponenter';

  @override
  String get settingsResetAll => 'Återställ alla inställningar';

  @override
  String get settingsResetAllSubtitle =>
      'Allmänt, Visualisering, Uppspelning, Motorer — inte biblioteket';

  @override
  String get settingsResetAllTitle => 'Återställa alla inställningar?';

  @override
  String get settingsResetAllBody =>
      'Allmänt, Visualisering, Uppspelning och alla motorer återgår till sina standardvärden. Ditt bibliotek och din historik rörs inte.';

  @override
  String get settingsRenewUserId => 'Förnya det anonyma ID:t';

  @override
  String get settingsRenewUserIdTitle => 'Förnya det anonyma ID:t?';

  @override
  String get settingsRenewUserIdBody =>
      'Ett nytt anonymt ID skapas för serverstatistiken.\n\nDet gamla används inte längre. Din lokala historik och dina favoriter påverkas inte.';

  @override
  String get settingsRenewUserIdFailed =>
      'Misslyckades — servern kunde inte nås';

  @override
  String settingsNewUserId(String id) {
    return 'Nytt ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Inget ID registrerat';

  @override
  String get settingsCleanDb => 'Rensa den lokala databasen';

  @override
  String get settingsCleanDbSubtitle =>
      'Tar bort poster vars fil inte längre finns (raderade nedladdningar, gamla fel)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count föräldralösa poster togs bort',
      one: '$count föräldralös post togs bort',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'Den lokala databasen är ren — inget att ta bort';

  @override
  String get settingsClearCache => 'Töm cachen (omslag & metadata)';

  @override
  String get settingsClearCacheSubtitle =>
      'Tar bort cachade omslag och hämtade metadata (STIL, låtlängder) — laddas ner igen vid nästa uppspelning';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cachen tömdes ($count omslag)',
      one: 'Cachen tömdes ($count omslag)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Återställ statistiken';

  @override
  String get settingsResetStatsSubtitle =>
      'Tar bort lyssningshistoriken och uppspelningsräknarna';

  @override
  String get settingsClearStatsTitle => 'Återställa statistiken?';

  @override
  String get settingsClearStatsBody =>
      'Detta raderar permanent:\n• hela lyssningshistoriken\n• uppspelningsräknarna\n\nDina favoriter och ditt bibliotek påverkas inte.';

  @override
  String get settingsStatsCleared => 'Statistiken raderades';

  @override
  String get settingsResetDatabase => 'Återställ databasen';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Raderar allt: historik, favoriter, spellistor, cache';

  @override
  String get settingsResetDbTitle => 'Återställa databasen?';

  @override
  String get settingsResetDbBody =>
      'Detta raderar permanent:\n• hela lyssningshistoriken\n• alla räknare\n• alla favoriter\n• alla spellistor\n• alla cachade metadata\n\nDina ljudfiler raderas inte.';

  @override
  String get settingsDbReset => 'Databasen återställdes';

  @override
  String get settingsDeleteDownloads => 'Radera nedladdningarna';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Raderar alla filer i online-mappen (låtar, omslag)';

  @override
  String get settingsDeleteDownloadsTitle => 'Radera nedladdningarna?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Detta raderar permanent alla nedladdade filer (låtar, album, omslag) från online-mappen.\n\nPosterna i databasen finns kvar men pekar på filer som inte längre finns.';

  @override
  String get settingsDownloadsDeleted => 'Nedladdningarna raderades';

  @override
  String get settingsColor => 'Färg';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Slumpmässigt nästa preset';

  @override
  String get settingsPmRandomNextSubtitle => 'Av: spela presets i ordning';

  @override
  String get settingsPmLockPreset => 'Lås preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Ingen automatisk växling';

  @override
  String get settingsPmPresetDuration => 'Tid mellan presets';

  @override
  String get settingsPmTransitions => 'Övergångar';

  @override
  String get settingsPmBlend => 'Övergång med övertoning';

  @override
  String get settingsPmBlendSubtitle => 'Av: byt preset direkt';

  @override
  String get settingsPmTransitionStyle => 'Övergångsstil';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Mönstret som övertoningen använder';

  @override
  String get settingsPmTransitionRandom => 'Slumpmässig';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Beat-synkat presetbyte';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minsta tid';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: känslighet';

  @override
  String get settingsPmRendering => 'Rendering';

  @override
  String get settingsPmQuality => 'Kvalitet';

  @override
  String get settingsPmQualitySubtitle =>
      'Renderingsupplösning (Max = ursprunglig upplösning)';

  @override
  String get settingsPmBeatSensitivity => 'Beat-känslighet';

  @override
  String get settingsPmAspectRatio => 'Respektera bildförhållandet';

  @override
  String get settingsPmAspectRatioSubtitle => 'För de shaders som stöder det';

  @override
  String get settingsPmPermissive => 'Tillåtande läge';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Läs in .milk-filer som har skriptfel';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountSubtitle => 'Spara och synka ditt bibliotek';

  @override
  String get accountAnonymous => 'Anonymt konto';

  @override
  String get accountAnonymousExplain =>
      'Dina favoriter och din historik sparas på servern, men bara den här enheten når dem. Lägg till en e-postadress för att hitta dem igen någon annanstans.';

  @override
  String get accountEmailAttached =>
      'Adressen bekräftad — kontot kan återställas';

  @override
  String get accountEmailPending => 'Adressen är inte bekräftad än';

  @override
  String get accountInsecureStorage =>
      'Enhetens säkra lagring är inte tillgänglig: kontots identifierare sparas okrypterad.';

  @override
  String get accountSaveCta => 'Spara mitt konto';

  @override
  String get accountStatSongs => 'Favoritlåtar';

  @override
  String get accountStatAlbums => 'Favoritalbum';

  @override
  String get accountStatPlays => 'Uppspelningar';

  @override
  String get accountCreatedLabel => 'Skapat';

  @override
  String get accountSignOut => 'Logga ut';

  @override
  String get accountRevoke => 'Logga ut överallt';

  @override
  String get accountRevokeSubtitle => 'Loggar ut alla andra enheter';

  @override
  String get accountRevokeBody =>
      'Alla andra enheter loggas ut. Den här förblir inloggad.';

  @override
  String get accountRevokeDone => 'Andra enheter utloggade';

  @override
  String get accountDelete => 'Radera mitt konto';

  @override
  String get accountDeleteSubtitle =>
      'Raderar kontot och dess data på servern. Går inte att ångra.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favoriter och $lists spellistor raderas från servern. Detta går inte att ångra.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Dina nedladdningar och den här enhetens bibliotek påverkas inte.';

  @override
  String get accountDeleteDone => 'Kontot raderat';

  @override
  String get accountSignOutSubtitle =>
      'Enheten börjar om med ett nytt, tomt konto';

  @override
  String get accountSignOutTitle => 'Logga ut?';

  @override
  String accountSignOutBody(String email) {
    return 'Du kan komma tillbaka till kontot med en kod som skickas till $email.';
  }

  @override
  String get accountSignedOut => 'Utloggad';

  @override
  String get accountNoSignOut => 'Utloggning är inte tillgänglig';

  @override
  String get accountNoSignOutSubtitle =>
      'Utan e-postadress skulle kontot gå förlorat för alltid.';

  @override
  String get accountDetach => 'Koppla bort adressen';

  @override
  String get accountDetachSubtitle =>
      'Kontot blir anonymt igen, inga data raderas';

  @override
  String get accountDetachBody =>
      'Utan adress går kontot inte längre att hitta från en annan enhet.';

  @override
  String get accountDetachDone => 'Adressen bortkopplad';

  @override
  String get accountOffline => 'Kontot är inte tillgängligt offline';

  @override
  String get accountEmailTitle => 'E-postadress';

  @override
  String get accountEmailExplain =>
      'Vi skickar en 6-siffrig kod för att bekräfta adressen. Den används bara för att återställa ditt konto.';

  @override
  String get accountEmailLabel => 'E-postadress';

  @override
  String get accountCodeTitle => 'Bekräftelsekod';

  @override
  String accountCodeExplain(String email) {
    return 'Kod skickad till $email. Den gäller i 10 minuter.';
  }

  @override
  String get accountCodeLabel => '6-siffrig kod';

  @override
  String get accountSendCode => 'Skicka koden';

  @override
  String get accountVerify => 'Bekräfta';

  @override
  String get accountResend => 'Skicka koden igen';

  @override
  String accountResendIn(int n) {
    return 'Skicka igen om $n s';
  }

  @override
  String get accountCheckSpam =>
      'Mejlet kan ta en minut — kolla även skräpposten.';

  @override
  String get accountErrorInvalidEmail => 'Ogiltig adress';

  @override
  String get accountErrorTooMany =>
      'För många förfrågningar, försök igen om några minuter';

  @override
  String get accountErrorInvalidCode => 'Fel eller utgången kod';

  @override
  String get accountErrorCodeLength => 'Koden har 6 siffror';

  @override
  String get accountErrorNetwork => 'Anslutningen misslyckades, försök igen';

  @override
  String get accountMergeTitle => 'Slå ihop det här biblioteket?';

  @override
  String accountMergeBody(String email) {
    return 'Enhetens favoriter och historik läggs till i kontot $email. Det går inte att ångra.';
  }

  @override
  String get accountMergeConfirm => 'Slå ihop';

  @override
  String get accountCarryLocal => 'Behåll den här enhetens favoriter';

  @override
  String accountCarryLocalOn(int n) {
    return 'De $n favoriterna och spellistorna på den här enheten läggs till i kontot.';
  }

  @override
  String get accountCarryLocalOff =>
      'De raderas från enheten och ersätts av kontots. Nedladdade filer behålls.';

  @override
  String get accountDropLocalTitle => 'Radera den här enhetens data?';

  @override
  String get accountCreatedOk => 'Kontot sparat, ditt bibliotek är tryggt';

  @override
  String get accountMergedOk => 'Inloggad — dina lokala favoriter lades till';

  @override
  String get accountSignedInOk => 'Inloggad';

  @override
  String get playlistEntryMissing => 'Filen saknas på den här enheten';

  @override
  String get playlistEntryMissingRestorable => 'Filen saknas — kan hämtas igen';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n saknas',
      one: '$n saknas',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Spara till mitt konto';

  @override
  String get playlistBackupSubtitle =>
      'Behåller spellistan även efter en ominstallation';

  @override
  String get playlistBackupUpdate => 'Uppdatera säkerhetskopian';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Ersätter kontots kopia med den här versionen';

  @override
  String get playlistBackupStop => 'Sluta spara';

  @override
  String get playlistBackupStopped => 'Säkerhetskopian borttagen';

  @override
  String get playlistBackupDone => 'Spellistan sparad';

  @override
  String get playlistBackupFailed => 'Kunde inte spara';

  @override
  String get playlistBackupNoAccount => 'Inget konto på den här enheten';

  @override
  String get playlistSyncTooltip => 'Synka med mitt konto';

  @override
  String get playlistSyncRunning => 'Synkar…';

  @override
  String get playlistSyncDone => 'Spellistor synkade';

  @override
  String get playlistSyncPartial => 'Vissa spellistor kunde inte sparas';

  @override
  String get playlistFetchMissing => 'Hämta låtarna som saknas';

  @override
  String get playlistFetchDone => 'Saknade låtar hämtade';

  @override
  String get playlistFetchPartial => 'Vissa låtar kunde inte hämtas';

  @override
  String get playlistEntryFetchFailed => 'Den här låten kunde inte hämtas';

  @override
  String get accountStatPlaylists => 'Spellistor';

  @override
  String get accountSyncNow => 'Synka nu';

  @override
  String get accountSyncAuto => 'Sker av sig själv i bakgrunden';

  @override
  String get accountSyncAnonymous =>
      'Säkerhetskopierat till servern. Lägg till en e-postadress för att synka en annan enhet.';

  @override
  String get accountSyncPending => 'Ändringar väntar på att skickas';

  @override
  String accountSyncLast(String when) {
    return 'Senaste synkning: $when';
  }

  @override
  String get accountSyncDone => 'Synkningen klar';

  @override
  String get accountSyncFailed => 'Synkningen misslyckades, försöker igen';

  @override
  String get podiumFirst => '1:a';

  @override
  String get podiumSecond => '2:a';

  @override
  String get podiumThird => '3:e';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'musik från $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'innehåller $place i $compo';
  }

  @override
  String get competitionEmpty => 'Den här tävlingen har inga bidrag';

  @override
  String get competitionEntryNoMusic =>
      'Ingen musik i katalogen för det här bidraget';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n låtar',
      one: '$n låt',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Hoppa över';

  @override
  String get onboardingNext => 'Nästa';

  @override
  String get onboardingStart => 'Kom igång';

  @override
  String get onboardingBetaTitle => 'Betaversion';

  @override
  String get onboardingBetaBody =>
      'Rewamp byggs fortfarande. Lokala data — bibliotek, spellistor, favoriter, statistik — kan komma att nollställas före version 1.0. Dina nedladdningar riskerar inget, men spara det du värdesätter på annat håll.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Utforska';

  @override
  String get onboardingExploreBody =>
      'Bläddra och sök bland tiotusentals chiptunes och trackermoduler från de stora nätarkiven — efter artist, album, plattform eller party. Tryck för att lyssna, ladda ner för att behålla.';

  @override
  String get onboardingLibraryTitle => 'Ditt bibliotek';

  @override
  String get onboardingLibraryBody =>
      'Spara det du gillar, bygg spellistor och ordna dem i mappar. Nedladdat spelas offline, och biblioteket följer med mellan enheter när du loggat in.';

  @override
  String get onboardingPlayerTitle => 'Spelaren';

  @override
  String get onboardingPlayerBody =>
      'Svep för att byta spår och öppna visualiseringarna: oscilloskop, kanaler, rullande noter, trackerrutnät. Filer med flera låtar visar sina delspår och varje stämma kan tystas för sig.';

  @override
  String get onboardingReplayTitle => 'Introduktion';

  @override
  String get onboardingReplaySubtitle =>
      'Se betameddelandet och rundturen igen';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Trackerrutnät: färger, kolumner, rullning';

  @override
  String get patternOpaqueBg => 'Ogenomskinlig bakgrund';

  @override
  String get patternOpaqueBgSubtitle => 'Döljer omslaget bakom rutnätet';

  @override
  String get commonSave => 'Spara';

  @override
  String get accountDisplayName => 'Offentligt namn';

  @override
  String get accountDisplayNameNotSet =>
      'Inte angivet — krävs för att publicera en spellista';

  @override
  String get accountDisplayNameHint => 'Namnet du vill krediteras under.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Att ändra det skickar alla dina publicerade spellistor tillbaka till granskning.';

  @override
  String get accountDisplayNameTaken => 'Namnet är upptaget. Välj ett annat.';

  @override
  String get accountDisplayNameLength => 'Mellan 2 och 40 tecken.';

  @override
  String get accountDisplayNameSaved => 'Offentligt namn sparat';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Spellistor som skickats tillbaka till granskning: $n';
  }

  @override
  String get playlistPublish => 'Gör offentlig';

  @override
  String get playlistPublishSubtitle => 'Begär publicering (granskas först)';

  @override
  String get playlistPublishTitle => 'Publicera den här spellistan?';

  @override
  String get playlistPublishBody =>
      'Efter godkännande syns den för alla, krediterad till ditt offentliga namn. Omslaget kommer från låtarna.';

  @override
  String get playlistPublishCta => 'Begär';

  @override
  String get playlistPublishSubmitted => 'Skickad till granskning';

  @override
  String get playlistPublishPending => 'Väntar på godkännande';

  @override
  String get playlistPublishApproved => 'Offentlig';

  @override
  String playlistPublishRejected(String reason) {
    return 'Nekad: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Nekad';

  @override
  String get playlistPublishNeedName => 'Välj namnet du vill krediteras under';

  @override
  String get playlistPublishNeedTracks =>
      'Det krävs minst 5 låtar för att publicera';

  @override
  String get playlistPublishHasLocal =>
      'Filer från din enhet kan inte publiceras — andra kan inte spela dem';

  @override
  String get playlistPublishTooManyPending =>
      'Du har redan 3 spellistor som väntar på godkännande';

  @override
  String get playlistPublishRefused =>
      'Publiceringen nekades: kontrollera låtarna och de väntande begärandena';

  @override
  String get playlistPublishFailed => 'Publiceringen misslyckades';

  @override
  String get playlistPublishWithdrawn => 'Spellistan är privat igen';

  @override
  String get playlistUnpublish => 'Gör privat';

  @override
  String get playlistUnpublishSubtitle =>
      'Tar bort den från de offentliga spellistorna';

  @override
  String get playlistRenamePublishedTitle =>
      'Byta namn på en publicerad spellista?';

  @override
  String get playlistRenamePublishedBody =>
      'Det är namnet som granskas: byter du det skickas spellistan tillbaka till granskning och avpubliceras under tiden. Att lägga till eller ordna om låtar gör det inte.';

  @override
  String playlistByAuthor(String author) {
    return 'av $author';
  }

  @override
  String get settingsSpectrumMode => 'Spektrumläge';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Färgad';

  @override
  String get settingsSpectrumModeBeam => 'Stråle';

  @override
  String get settingsSpectrumModeLine => 'Linje';

  @override
  String get settingsSpectrumModeRing => 'Ring';

  @override
  String get releaseNotesTitle => 'Nyheter';

  @override
  String get releaseNotesV4Downloads =>
      'Nedladdningar: en lång kan avbrytas medan den pågår, och ett albumarkiv hämtas inte längre flera gånger.';

  @override
  String get releaseNotesV4Queue =>
      'Kön: en knapp för att tömma den, med bekräftelse — den stoppar även uppspelningen.';

  @override
  String get releaseNotesV4DropFiles =>
      'Filer som släpps på fönstret: spela nu, härnäst eller sist; omslag och följefiler lämnas utanför, och en spellista som följer med ett arkiv respekteras (riktiga titlar, inga döda spår).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: importera din egen SoundFont från enheten, vid sidan av serverns.';

  @override
  String get releaseNotesV4Formats =>
      'Wwise-, FSB- och OGL-spelströmmar spelas äntligen (eget Vorbis).';

  @override
  String get releaseNotesV4Chips =>
      'Sex ljudkretsar till, val av emuleringskärna per krets (SameBoy för Game Boy) och rätt tonhöjd på sampelkretsar.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: .vt2 spelas, och not- och mönstervyerna täcker hela ZX-familjen.';

  @override
  String get releaseNotesV4Loop =>
      'Upprepa låt loopar på riktigt i stället för att ladda om, och räknaren fryser inte längre vid oändlig loop.';

  @override
  String get releaseNotesV4Info =>
      'ⓘ-panelen listar filerna som en låt faktiskt öppnade — följefiler och bibliotek inkluderade.';

  @override
  String get releaseNotesV4Linux => 'Linux-skrivbordsversion.';

  @override
  String get releaseNotesDataReset =>
      'Lokala data nollställdes för den här betan. Bibliotek och spellistor byggs upp från kontot; nedladdningar får göras om.';

  @override
  String get releaseNotesDismiss => 'Fortsätt';

  @override
  String get pmManagePresets => 'Hantera presets';

  @override
  String get pmPickTooltip => 'Välj en preset';

  @override
  String get pmPickFilter => 'Filtrera presets';

  @override
  String get pmSourceTooltip => 'Presetkälla';

  @override
  String get pmAddToPlaylistTooltip => 'Lägg till preset i en spellista';

  @override
  String pmSlowPresetDropped(String name) {
    return '”$name” är för tungt för den här enheten och har lagts åt sidan.';
  }

  @override
  String get pmSlowDeviceTitle => 'Den här enheten är för långsam';

  @override
  String get pmSlowDeviceOff =>
      'Visualiseringen stängdes av: enheten klarar inte Milkdrop-förinställningar.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förinställningar åsidosatta',
      one: '1 förinställning åsidosatt',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'För långsamma på den här enheten. De hoppas över.';

  @override
  String get settingsPmSlowPresetsRestore => 'Återställ';

  @override
  String get pmSourceBundled => 'Inbyggda presets';

  @override
  String get pmSourceImports => 'Mina importer';

  @override
  String get pmSourceAll => 'Alla presets';

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
  String get pmNewPlaylist => 'Ny spellista…';

  @override
  String get pmPlaylistName => 'Spellistans namn';

  @override
  String get pmAddedToPlaylist => 'Tillagd i spellistan';

  @override
  String get pmAlreadyInPlaylist => 'Finns redan i spellistan';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Bläddra';

  @override
  String get pmTabPlaylists => 'Spellistor';

  @override
  String get pmTabPopular => 'Populärt';

  @override
  String get pmTabSetAside => 'Åsidosatta';

  @override
  String get pmSetAsideEmpty =>
      'Inget åsidosatt. Här hamnar förinställningar som får enheten under 6 fps.';

  @override
  String get pmSetAsideRestoreAll => 'Återställ alla';

  @override
  String get pmInstall => 'Installera';

  @override
  String get pmInstallQueued => 'Installation köad';

  @override
  String get pmUninstall => 'Avinstallera';

  @override
  String get pmUninstalled => 'Pack borttaget';

  @override
  String get pmUse => 'Använd';

  @override
  String get pmDefaultPackBanner => 'Rekommenderat startpack';

  @override
  String pmLicense(String license) {
    return 'Licens: $license';
  }

  @override
  String get pmPacksOffline => 'Servern kan inte nås';

  @override
  String get pmSearchPresets => 'Sök presets…';

  @override
  String get pmPlayNow => 'Spela nu';

  @override
  String get pmDownloadAction => 'Ladda ner';

  @override
  String get pmDownloaded => 'Preset nedladdad';

  @override
  String get pmDownloadFailed => 'Nedladdningen misslyckades';

  @override
  String pmPreviewing(String name) {
    return 'Spelar: $name';
  }

  @override
  String get pmLocalSection => 'Mina spellistor';

  @override
  String get pmCuratedSection => 'Rewamp-spellistor';

  @override
  String get pmImportPlaylist => 'Ladda ner och använd';

  @override
  String get pmPlaylistImported => 'Spellistan är klar';

  @override
  String get pmImportFiles => 'Importera filer…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets importerade',
      one: '$count preset importerad',
      zero: 'Ingen preset importerad',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets tillagda i projectM-biblioteket';

  @override
  String get pmNoPlaylists => 'Inga preset-spellistor ännu';

  @override
  String get pmSourceApplied => 'Presetkälla tillämpad';

  @override
  String get pmPlaylistEmpty => 'Den här spellistan är tom';

  @override
  String get pmDays7 => '7 dagar';

  @override
  String get pmDays30 => '30 dagar';

  @override
  String get pmDays365 => '1 år';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spelningar',
      one: '$count spelning',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Installationen misslyckades';

  @override
  String get pmSingleDownloads => 'Enskilda nedladdningar';

  @override
  String pmAvailableIn(String pack) {
    return 'Finns i $pack';
  }

  @override
  String get pmCleanUp => 'Rensa';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets borttagna',
      one: '$count preset borttagen',
      zero: 'Inget att rensa',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Lås denna preset';

  @override
  String get pmUnlockAction => 'Lås upp preset';

  @override
  String get pmOrderRandom => 'Blanda presets';

  @override
  String get pmOrderSequential => 'Presets i ordning';

  @override
  String get pmUpdateAvailable => 'Uppdatering tillgänglig';

  @override
  String get pmUpdate => 'Uppdatera';

  @override
  String get pmSelectAll => 'Markera alla';

  @override
  String get pmSelectNone => 'Avmarkera alla';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count markerade',
      one: '$count markerad',
      zero: 'Inget markerat',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Oanvända texturer';

  @override
  String pmTexturesFreed(String size) {
    return '$size frigjort';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texturer',
      one: '$count textur',
    );
    return '$_temp0';
  }
}
