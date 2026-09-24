// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navLocal => 'Local';

  @override
  String get settingsTabsOrderTitle => 'Tab order';

  @override
  String get settingsTabsOrderSubtitle =>
      'Drag to reorder. The first four appear in the bottom bar; the rest live under “More”.';

  @override
  String get settingsTabsInBar => 'In the bar';

  @override
  String get settingsTabsInMore => 'Under “More”';

  @override
  String get settingsLaunchTab => 'Tab at launch';

  @override
  String get settingsLaunchTabSubtitle => 'Which tab the app opens on';

  @override
  String get navLibrary => 'Library';

  @override
  String get noFileSelected => 'No file selected';

  @override
  String get openFile => 'Open file';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Format not supported';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Unsupported format: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Not on this device: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'File no longer on the server: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file is not in the album\'s archive — the rip lists it but does not ship it.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host did not respond. Check your connection, then try again.';
  }

  @override
  String get failedToLoadFile => 'Failed to load file';

  @override
  String get libraryEmptyHint =>
      'Your artists, albums and playlists\nwill appear here.';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryArtists => 'Artists';

  @override
  String get libraryAlbums => 'Albums';

  @override
  String get libraryTracks => 'Tracks';

  @override
  String get libraryFavorites => 'Favorites';

  @override
  String get libraryFavoritesSubtitle =>
      'Auto-playlist of your favorite tracks';

  @override
  String get libraryRecentlyAdded => 'Recently added';

  @override
  String get libraryEmpty => 'Nothing here yet';

  @override
  String get libraryRemoved => 'Removed from library';

  @override
  String get searchHint => 'Search…';

  @override
  String get searchTypePlaceholder => 'Type a title, artist or album…';

  @override
  String get searchNoResults => 'No results';

  @override
  String get searchDownloading => 'Downloading…';

  @override
  String searchError(String message) {
    return 'Error: $message';
  }

  @override
  String get tabAll => 'Tracks';

  @override
  String get tabArtists => 'Artists';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabProductions => 'Productions';

  @override
  String get filterWithVideo => 'With video';

  @override
  String get videoUnavailable => 'This video is unavailable';

  @override
  String get noItems => 'No items';

  @override
  String get sortRelevance => 'Relevance';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get noRecentTracks => 'No recently played tracks';

  @override
  String get playerSourceLocal => 'local';

  @override
  String get homePlayFiles => 'Play files';

  @override
  String get homePlayFolder => 'Play a folder';

  @override
  String get homeSectionsOrderTitle => 'Section order';

  @override
  String get homeSectionsOrderSubtitle =>
      'Drag to arrange the Home screen the way you like.';

  @override
  String get homeSectionsOrderReset => 'Default order';

  @override
  String get homeSectionsOrderSettings => 'Home section order';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total results';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded loaded…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded results';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded loaded — scroll for more';
  }

  @override
  String countNLoaded(int n) {
    return '$n loaded';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n file(s)';
  }

  @override
  String get browseFilterByTitle => 'Filter by title…';

  @override
  String get browseNoSongs => 'No songs available';

  @override
  String get browseByFormat => 'By format';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filter by format…';

  @override
  String get browseByPlatform => 'By platform';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Platform name…';

  @override
  String get browseByChip => 'By sound chip';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'e.g. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'By artist';

  @override
  String get browseByArtistSubtitle => 'Browse the composers';

  @override
  String get browseFilterByName => 'Filter by name…';

  @override
  String get browseNoArtistFound => 'No artist found';

  @override
  String get browseNoArtistsAvailable => 'No artists available';

  @override
  String get browseNoArtist => 'No artists';

  @override
  String get browseNoAlbum => 'No albums';

  @override
  String get browseTopPacks => 'Top packs';

  @override
  String get browseTopPacksSubtitle => 'The highest-rated packs';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Top packs — $collection';
  }

  @override
  String get browseLatestPacks => 'Latest packs';

  @override
  String get browseLatestPacksSubtitle => 'The most recent additions';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Latest packs — $collection';
  }

  @override
  String get browseAllSongs => 'All songs';

  @override
  String get browseAllSongsSubtitleAlpha => 'Browse in alphabetical order';

  @override
  String get browseAlphabetical => 'In alphabetical order';

  @override
  String browseAllLabel(String collection) {
    return 'All — $collection';
  }

  @override
  String get browseCollections => 'Collections';

  @override
  String browseFilesCount(String count) {
    return '$count files';
  }

  @override
  String get browseIndexing => 'Indexing in progress';

  @override
  String browseFilterFacet(String name) {
    return 'Filter $name…';
  }

  @override
  String get browseAllYears => 'All years';

  @override
  String get browseAllYearsSubtitle => 'All the party\'s songs';

  @override
  String get browseNoCompo => 'No compo indexed for this party.';

  @override
  String get browseOthers => 'Others';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n entries — ranking',
      one: '$n entry — ranking',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Play playlist';

  @override
  String get browsePlayAllRanked => 'Play all (in ranking order)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tracks — ranking order',
      one: '$n track — ranking order',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Browse by album';

  @override
  String get browsePlayAll => 'Play all';

  @override
  String get browseShuffle => 'Shuffle';

  @override
  String get browseSearchInFolder => 'Search in this folder…';

  @override
  String get browseFilterThisList => 'Filter this list…';

  @override
  String get browseSearchSubfolders => 'Search subfolders';

  @override
  String get browseEmptyFolder => 'Empty folder';

  @override
  String browsePlaybackError(String message) {
    return 'Playback failed: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tracks',
      one: '$n track',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'View';

  @override
  String get browseViewList => 'List';

  @override
  String get browseViewGrid => 'Grid';

  @override
  String get browseViewGridCompact => 'Compact grid';

  @override
  String get browseSearchAlbum => 'Search for an album…';

  @override
  String get browseSearchArtist => 'Search for an artist…';

  @override
  String get browsePlayAlbum => 'Play album';

  @override
  String get searchDownloadingAlbum => 'Downloading album…';

  @override
  String get searchCategoryChip => 'Chips';

  @override
  String get searchCategoryGroup => 'Groups';

  @override
  String get artistRealName => 'Real name';

  @override
  String get artistAliases => 'Aliases';

  @override
  String get artistBorn => 'Born';

  @override
  String get artistInterview => 'Interview';

  @override
  String get audioOutput => 'Audio output';

  @override
  String get audioOutputSystemDefault => 'System default';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notes';

  @override
  String get notePlacedBadge => 'Placed in competition';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'View songs';

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
  String get searchCategoryYear => 'Year';

  @override
  String get searchCategoryOrigin => 'Origin';

  @override
  String get searchCategoryProduction => 'Production';

  @override
  String get searchCategoryProductionType => 'Prod types';

  @override
  String get searchCategoryPublisher => 'Publishers';

  @override
  String get searchCategoryDeveloper => 'Developers';

  @override
  String get searchCategoryArcadeBoard => 'Arcade boards';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'via artist';

  @override
  String get searchViaAlbum => 'via an album';

  @override
  String get searchViaSong => 'via a song';

  @override
  String get searchSortPopular => 'Popular';

  @override
  String get searchSortYear => 'Year';

  @override
  String get searchSortRandom => 'Random';

  @override
  String get searchSortRating => 'Rating';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Ascending';

  @override
  String get searchSortDesc => 'Descending';

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchExactSearch => 'Exact search';

  @override
  String get searchExactSearchSubtitle => 'Disables approximate (fuzzy) search';

  @override
  String get searchTags => 'Tags';

  @override
  String searchTagSearchHint(String category) {
    return 'Search for a tag in « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Type to search for tags.';

  @override
  String get searchTagsAndLogic => 'Multiple tags = logical AND.';

  @override
  String get searchFilterYear => 'Year';

  @override
  String get searchFilterAll => 'all';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtering by year excludes undated songs.';

  @override
  String get searchMinRating => 'Rating ≥';

  @override
  String get searchPodium => 'Podium';

  @override
  String get searchPodiumAny => 'Any podium';

  @override
  String get searchPodiumUnavailable =>
      'The podium filter is not available on the server yet';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Cancel';

  @override
  String get searchReset => 'Reset';

  @override
  String get searchApply => 'Apply';

  @override
  String get searchClearRecent => 'Clear recent searches';

  @override
  String get searchBrowse => 'Browse';

  @override
  String get searchBrowseHint =>
      'Pick a facet (group, chip, year…) to explore the catalogue, or start Radio/Surprise above.';

  @override
  String get searchDidYouMean => 'Few results — try an approximate search?';

  @override
  String get searchYes => 'Yes';

  @override
  String get featuredCommunityTitle => 'New from the community';

  @override
  String get searchPlaylistSourceAll => 'All';

  @override
  String get searchPlaylistSourceUser => 'Community';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Platform';

  @override
  String get filterCollection => 'Collection';

  @override
  String get videoWatchDemo => 'Watch the demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Collection: $name';
  }

  @override
  String get searchCollectionAll => 'All';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Random queue over the current filters';

  @override
  String get searchSurprise => 'Surprise';

  @override
  String get searchSurpriseTooltip => 'A random song';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'No songs';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n songs',
      one: '$n song',
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
  String get searchChooseCollection => 'Choose collection';

  @override
  String get searchFilterCollections => 'Filter collections…';

  @override
  String get searchFilterPlaceholder => 'Filter…';

  @override
  String searchAllOf(String label) {
    return 'All ($label)';
  }

  @override
  String get searchNoMatch => 'No match';

  @override
  String get searchNoPlaylist => 'No playlists';

  @override
  String get engineDescOpenmpt => 'Tracker modules (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Modules libopenmpt cannot read (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — sound chips, per-channel scope';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN archives';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — per-channel voices';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp engine)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX chiptunes (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Multi-chip chiptunes .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amiga custom-chip formats via 68k emulation (~320 exts)';

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
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ synth (16 voices)';

  @override
  String get engineDescV2m => 'V2M synth (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — real 68000 emulation + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300 emulation + RSP audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ emulation';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound chip';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — real AY-3-8910/YM2149 synth';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixel\'s own engine';

  @override
  String get engineDescPxtone => 'Pixel\'s tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — real 68000 via emu68';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA FM + SSG + PPZ8 samples';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ .pdx samples), YM2151 FM';

  @override
  String get engineDescFmp => 'PC-98 FMP driver — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612 FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Streamed game audio formats (700+, incl. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — fallback decoder';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total songs',
      one: '$loaded / 1 song',
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
      other: '$loaded / $total artists',
      one: '$loaded / 1 artist',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n songs',
      one: '$n song',
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
      other: '$n artists',
      one: '$n artist',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n groups',
      one: '$n group',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Countries';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n countries',
      one: '$n country',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Folders';

  @override
  String get featuredTitle => 'Featured today';

  @override
  String featuredPartyNow(String party) {
    return '$party is on right now — podiums from past editions';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party starts in $days days — podiums from past editions',
      one: '$party starts tomorrow — podiums from past editions',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series season — podiums from past editions';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Released in $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age years ago: the games of $year',
      one: 'One year ago: the games of $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'The ${decade}s';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age years ago: the games of $year',
      one: 'One year ago: the games of $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Released in $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Anniversaries';

  @override
  String get featuredBirthdayHeader => 'Today\'s birthdays';

  @override
  String get featuredBirthdayWeekHeader => 'This week\'s birthdays';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist\'s birthday this week';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '$count playlist',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonDownload => 'Download';

  @override
  String get commonDeleteDownload => 'Delete download';

  @override
  String get commonAddToPlaylist => 'Add to playlist';

  @override
  String get commonPlayNext => 'Play next';

  @override
  String get commonAddToQueueEnd => 'Add to end of queue';

  @override
  String get commonAddToFavorites => 'Add to favorites';

  @override
  String get commonRemoveFromFavorites => 'Remove from favorites';

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
  String get subsongDeleteDownloadTitle => 'Delete this download?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'The file and its local entries (history, tracks) will be deleted.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Unable to read the tracks';

  @override
  String subsongTrackNumber(int number) {
    return 'Track $number';
  }

  @override
  String get subsongDefaultTrack => 'Default track';

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
  String get subsongPlayAll => 'Play all';

  @override
  String get albumDownloading => 'Downloading album…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Downloading album… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks => 'Download the album to see its tracks';

  @override
  String get albumNotDownloadedHint =>
      'Album not downloaded — start playback to download it';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '$count track',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Loading details…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Play album';

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
      'Play this track from search first to download it';

  @override
  String get libraryAddedTrack => 'Track added to your library';

  @override
  String get libraryAddedAlbum => 'Album added to your library';

  @override
  String get libraryAddedArtist => 'Artist added to your library';

  @override
  String get libraryRemovedTrack => 'Track removed from your library';

  @override
  String get libraryRemovedAlbum => 'Album removed from your library';

  @override
  String get libraryRemovedArtist => 'Artist removed from your library';

  @override
  String get libraryImportBeforeAddTitle => 'Import first?';

  @override
  String get libraryImportBeforeAddBody =>
      'This file is playing from a temporary location the system can clear. Import it into your local library so the entry survives?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'This track comes from an archive opened into a temporary cache. The whole archive will be imported into your local library, companion files included.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'Cannot add this track: its catalogue id is unknown on this device.';

  @override
  String songTilePlayFailed(String message) {
    return 'Playback failed: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Download failed — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Downloading — $label';
  }

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmpty => 'No pending downloads';

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Resume';

  @override
  String get downloadsCancel => 'Cancel download';

  @override
  String get downloadsClear => 'Remove all';

  @override
  String get downloadsPausedBanner =>
      'Downloads paused — the current file finishes first';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Downloading — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Playlist';

  @override
  String get miniPlayerHideQueue => 'Hide playlist';

  @override
  String get transportShuffle => 'Shuffle';

  @override
  String get transportShuffleOn => 'Shuffle on';

  @override
  String get transportLoopOff => 'Loop off';

  @override
  String get transportLoopQueue => 'Loop: queue';

  @override
  String get transportLoopTrack => 'Loop: current track';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spectrum';

  @override
  String get vizVoices => 'Voices';

  @override
  String get vizNotes => 'Notes';

  @override
  String get vizPiano => 'Piano';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Scroll mode';

  @override
  String get patternSmoothScroll => 'Smooth scrolling';

  @override
  String get patternPinnedRow => 'Pinned playing row';

  @override
  String get patternVolumeBars => 'Volume bars';

  @override
  String get patternColorScheme => 'Color scheme';

  @override
  String get patternSize => 'Size';

  @override
  String get patternColumns => 'Columns';

  @override
  String get patternColumnsAll => 'Full';

  @override
  String get patternColumnsNoteInstr => 'Reduced';

  @override
  String get patternColumnsNote => 'Minimal';

  @override
  String get vizClose => 'Close the visualizer';

  @override
  String get vizFullscreen => 'Fullscreen';

  @override
  String get vizExitFullscreen => 'Exit fullscreen';

  @override
  String get vizPrevPreset => 'Previous preset';

  @override
  String get vizNextPreset => 'Next preset';

  @override
  String get vizProjectmUnavailable => 'projectM unavailable';

  @override
  String get voicesTitle => 'Voices';

  @override
  String get voicesNone => 'No voices for this track.';

  @override
  String get voicesLongPressSolo => 'long-press = solo';

  @override
  String get voicesMuteAll => 'Mute all';

  @override
  String get voicesUnmuteAll => 'Unmute all';

  @override
  String get voicesStereoOutput => 'Stereo output';

  @override
  String get voicesLeft => 'Left';

  @override
  String get voicesRight => 'Right';

  @override
  String get enginesFormatsTitle => 'Playable formats';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats playable formats, across $engines playback engines.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formats',
      one: '$count format',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Covers $title by $artist';
  }

  @override
  String stilCover(String work) {
    return 'Covers $work';
  }

  @override
  String get playerQueue => 'Queue';

  @override
  String get queueEdit => 'Edit';

  @override
  String get queueEditDone => 'Done';

  @override
  String get queueClear => 'Clear queue';

  @override
  String get queueClearConfirmTitle => 'Clear the queue?';

  @override
  String get queueClearConfirmBody =>
      'The queue will be emptied and playback will stop.';

  @override
  String get queueClearConfirm => 'Clear';

  @override
  String get queueRemoveSelected => 'Remove selected';

  @override
  String get queueRemoveTrack => 'Remove from queue';

  @override
  String get queueReorder => 'Reorder';

  @override
  String get playerArtwork => 'Artwork';

  @override
  String get playerVisualizer => 'Visualizer';

  @override
  String get playerVoices => 'Voices';

  @override
  String get playerTrackInfo => 'Track info';

  @override
  String get playerShowQueue => 'Playlist';

  @override
  String get playerHideQueue => 'Hide playlist';

  @override
  String get playerNoTrackInfo => 'No information available.';

  @override
  String get playerViewSubsongs => 'View subsongs';

  @override
  String get playerViewAlbum => 'View album';

  @override
  String get playerViewArtist => 'View artist';

  @override
  String get playerAddToPlaylist => 'Add to playlist';

  @override
  String get playerEngineSettings => 'Engine settings';

  @override
  String get queueAddToPlaylist => 'Add queue to a playlist';

  @override
  String get playerMoreOptions => 'More options';

  @override
  String get playerClose => 'Close';

  @override
  String get playerCancel => 'Cancel';

  @override
  String get playerDelete => 'Delete';

  @override
  String get playerAddFavorite => 'Add to favorites';

  @override
  String get playerRemoveFavorite => 'Remove from favorites';

  @override
  String get playerAddToLibrary => 'Add to library';

  @override
  String get playerRemoveFromLibrary => 'Remove from library';

  @override
  String get playerAddedToLibrary => 'Track added to library';

  @override
  String get playerRemovedFromLibrary => 'Track removed from library';

  @override
  String get playerDeleteDownload => 'Delete download';

  @override
  String get playerRedownload => 'Re-download file';

  @override
  String get playerRedownloadUnavailable =>
      'Re-download unavailable for this file';

  @override
  String get playerDeleteDownloadTitle => 'Delete download?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'The file and its local entries (history, tracks) will be deleted.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Your trends';

  @override
  String get homeYourAllTimeTop => 'Your all-time top';

  @override
  String get homeTrending => 'Trending';

  @override
  String get homeFeaturedPlaylists => 'Featured playlists';

  @override
  String get homeAllTimeTop => 'All-time top';

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
      other: '$n plays',
      one: '$n play',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tracks',
      one: '$n track',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Empty or unreadable playlist';

  @override
  String get homeExtractingArchive => 'Extracting archive…';

  @override
  String get homeArchiveEmpty => 'No playable files in the archive';

  @override
  String get homeNothingPlayable => 'Nothing playable in the selection';

  @override
  String get homeAlbumLoadFailed => 'Couldn\'t load this album';

  @override
  String get homeSongLoadFailed => 'Couldn\'t load this track';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Settings';

  @override
  String get playlistMoveUp => 'Move to parent folder';

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
      other: '$n subfolders',
      one: '$n subfolder',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'This folder and everything inside will be permanently deleted:';

  @override
  String get playlistDeleteFolderEmptyBody => 'This folder will be deleted.';

  @override
  String get playlistFolderRoot => 'Root';

  @override
  String get playlistMoveToFolder => 'Move to folder';

  @override
  String playlistDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get playlistDeleteBody => 'This playlist will be permanently deleted.';

  @override
  String get playlistRenameFolderTitle => 'Rename folder';

  @override
  String get playlistClearFavorites => 'Delete all favorites';

  @override
  String get playlistClearFavoritesTitle => 'Delete all favorites?';

  @override
  String get playlistClearFavoritesBody =>
      'You will lose all your favorite tracks. This can\'t be undone.';

  @override
  String get playlistRemoveFromLibrary => 'Remove from library';

  @override
  String get playlistServerReadOnly => 'Server playlist · read-only';

  @override
  String get navAbout => 'About';

  @override
  String get navMore => 'More';

  @override
  String get shellAlbumQueuedAtEnd => 'Album added to the end of the queue';

  @override
  String get shellAlbumQueuedNext => 'Album will play next';

  @override
  String get shellAddingToQueue => 'Adding to queue…';

  @override
  String get shellAddingNext => 'Adding to play next…';

  @override
  String shellDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to the queue',
      one: '$count track added to the queue',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" added to the end of the queue';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" will play next';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Download failed: $title — skipping to next track';
  }

  @override
  String get shellNetworkUnavailable =>
      'Playback stopped: the network appears to be unavailable.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String statsPeriodDays(int n) {
    return '$n days';
  }

  @override
  String get statsPeriodThisYear => 'This year';

  @override
  String get statsPeriodAll => 'All time';

  @override
  String get statsByMonthOrYear => 'By month / year…';

  @override
  String get statsByYear => 'By year';

  @override
  String get statsByMonth => 'By month';

  @override
  String get statsPlaysLabel => 'Plays';

  @override
  String get statsTracksLabel => 'Tracks';

  @override
  String get statsArtistsLabel => 'Artists';

  @override
  String get statsAlbumsLabel => 'Albums';

  @override
  String get statsListenTime => 'Listening time';

  @override
  String get statsByCollection => 'By collection';

  @override
  String get statsByFormat => 'By format';

  @override
  String get statsByEngine => 'By engine';

  @override
  String get statsPlaylistsLabel => 'Playlists';

  @override
  String get statsLocalFilesSection => 'Downloaded files';

  @override
  String get statsFilesLabel => 'Files';

  @override
  String get statsSpaceLabel => 'Disk space';

  @override
  String get statsNoPlaysInPeriod => 'No plays in this period';

  @override
  String get statsNoPlays => 'No plays';

  @override
  String get statsTopTracks => 'Top tracks';

  @override
  String get statsTopAlbums => 'Top albums';

  @override
  String get statsTopArtists => 'Top artists';

  @override
  String statsTopTracksIn(String period) {
    return 'Top tracks — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top albums — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top artists — $period';
  }

  @override
  String get statsSeeAll => 'See all';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n plays',
      one: '$n play',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tracks',
      one: '$n track',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max $n';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonPlayAll => 'Play all';

  @override
  String get sortName => 'Name';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Date added';

  @override
  String get commonClear => 'Clear';

  @override
  String get sortRecentlyModified => 'Recently modified';

  @override
  String get sortCreationDate => 'Creation date';

  @override
  String get playlistNameHint => 'Name';

  @override
  String get playlistNew => 'New playlist';

  @override
  String get playlistNewFolder => 'New folder';

  @override
  String get playlistNewTooltip => 'New playlist / folder';

  @override
  String get playlistAddTo => 'Add to playlist';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Add to $n playlists',
      one: 'Add to $n playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Select a playlist';

  @override
  String get playlistFilterHint => 'Filter playlists…';

  @override
  String get playlistSearchHint => 'Search a playlist…';

  @override
  String get playlistNoMatch => 'No matching playlist';

  @override
  String get playlistNoneCreateHint => 'No playlist — create one with +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tracks',
      one: '$n track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Already there';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items are already in the selected playlists.',
      one: '$n item is already in the selected playlists.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Skip duplicates';

  @override
  String get playlistAddAgain => 'Add again';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tracks added',
      one: '$n track added',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m playlists',
      one: '$n playlist',
    );
    return '$_temp0 to $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Could not add: $error';
  }

  @override
  String get playlistRenameTitle => 'Rename playlist';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Delete the folder “$name”?';
  }

  @override
  String get playlistDeleteFolderBody => 'Its contents move up one level.';

  @override
  String get playlistEmpty => 'Empty playlist';

  @override
  String get trackOptionsAddToLibrary => 'Add to library';

  @override
  String get trackOptionsRemoveFromLibrary => 'Remove from library';

  @override
  String get trackOptionsAddedToLibrary => 'Track added to the library';

  @override
  String get trackOptionsRemovedFromLibrary => 'Track removed from the library';

  @override
  String get trackOptionsViewAlbum => 'View album';

  @override
  String get trackOptionsViewArtist => 'View artist';

  @override
  String get trackOptionsPlayNow => 'Play now';

  @override
  String get trackOptionsPlayNext => 'Play next';

  @override
  String get trackOptionsAddToQueueEnd => 'Add to end of queue';

  @override
  String get trackOptionsPlayLast => 'Play last';

  @override
  String get trackOptionsDeleteDownload => 'Delete download';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Delete this download?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'The file and its local entries (history, tracks) will be deleted.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Download deleted';

  @override
  String get trackOptionsAddToFavorites => 'Add to favorites';

  @override
  String get trackOptionsRemoveFromFavorites => 'Remove from favorites';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Album added to favorites';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album removed from favorites';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album not downloaded — nothing to delete';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Delete the downloaded album?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'The folder and all its local entries (tracks, history) will be deleted.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Album deleted from local storage';

  @override
  String get trackOptionsRedownloadAlbum => 'Re-download album';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Rewrites files AND local entries';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Delete album files';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Downloaded folder + local entries (history)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralSubtitle => 'Theme';

  @override
  String get settingsVisualisation => 'Visualization';

  @override
  String get settingsVisualisationSubtitle =>
      'Oscilloscopes, artwork background';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsPlaybackSubtitle => 'Loops, fade-out, silence';

  @override
  String get settingsEngines => 'Engines';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDataSubtitle => 'ID, history, reset';

  @override
  String get settingsBackupExport => 'Export a backup';

  @override
  String get settingsBackupExportSubtitle =>
      'Save your library, playlists and settings to a file';

  @override
  String get settingsBackupImport => 'Import a backup';

  @override
  String get settingsBackupImportSubtitle =>
      'Restore your data from a backup file';

  @override
  String get settingsBackupExportFailed => 'Backup export failed';

  @override
  String get settingsBackupImportConfirmTitle => 'Import backup?';

  @override
  String get settingsBackupImportConfirmBody =>
      'This replaces your library, playlists and settings on this device. Downloaded files are kept.';

  @override
  String get settingsBackupImportConfirm => 'Import';

  @override
  String get settingsBackupImportedTitle => 'Backup imported';

  @override
  String get settingsBackupImportedBody =>
      'Your data has been restored. Restart the app to apply everything.';

  @override
  String get settingsBackupTooNew =>
      'This backup was made by a newer version of the app';

  @override
  String get settingsBackupInvalid => 'Not a valid Rewamp backup';

  @override
  String get settingsBackupImportFailed => 'Backup import failed';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'Credits and licenses';

  @override
  String get settingsCreditsSubtitle => 'Libraries, data & components';

  @override
  String get settingsSupport => 'Contact & support';

  @override
  String get settingsSupportSubtitle => 'Reach us, website';

  @override
  String get settingsSupportEmail => 'Send an email';

  @override
  String get settingsSupportEmailSubtitle => 'Question, bug or suggestion';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — support';

  @override
  String get settingsSupportEmailIntro =>
      'Describe your question, bug or suggestion above. The information below helps us help you.';

  @override
  String get settingsSupportWebsite => 'Website';

  @override
  String get settingsDonation => 'Support Rewamp';

  @override
  String get settingsDonationSubtitle => 'Leave a tip, if you\'d like';

  @override
  String get settingsDonationBlurb =>
      'Rewamp is free and ad-free — a labour of love devoted to preserving demoscene and retro culture. Tips help fund the app\'s development and cover the database hosting costs. There\'s no obligation: if the app brings you joy, a little something is always appreciated.';

  @override
  String get settingsDonationFloppy => 'A floppy disk';

  @override
  String get settingsDonationCartridge => 'A cartridge';

  @override
  String get settingsDonationBox => 'A boxed game';

  @override
  String get settingsDonationCustom => 'Choose an amount';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Delete';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsRenew => 'Renew';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Infinite';

  @override
  String get settingsDefault => 'Default';

  @override
  String get settingsCoreNoScope => 'no oscilloscope';

  @override
  String get settingsNone => 'None';

  @override
  String get settingsLevelLow => 'Low';

  @override
  String get settingsLevelHigh => 'High';

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
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsArtworkTintTitle => 'Tint the player with the artwork';

  @override
  String get settingsArtworkTintSubtitle =>
      'The player picks up the cover\'s dominant color';

  @override
  String get settingsGlassEffectTitle => 'Liquid glass effect';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lens and blur on the bottom bars — turn off on slow devices';

  @override
  String get settingsResetSection => 'Reset this section';

  @override
  String get settingsResetEngine => 'Reset this engine';

  @override
  String get settingsResetChoices => 'Reset these choices';

  @override
  String get settingsResetToDefault => 'Default value';

  @override
  String get settingsStartInVizTitle => 'Start in visualizer mode';

  @override
  String get settingsStartInVizSubtitle =>
      'The player opens on the oscilloscopes instead of the artwork';

  @override
  String get settingsVoiceGridTitle => 'Voice oscilloscope grid';

  @override
  String get settingsVoiceGridSubtitle =>
      'Show the borders separating each voice';

  @override
  String get settingsKeepAwakeTitle => 'Keep the screen on';

  @override
  String get settingsKeepAwakeSubtitle =>
      'While a visualizer is showing, the display does not dim or lock';

  @override
  String get settingsVoiceNamesTitle => 'Voice names';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Show each voice\'s name inside its frame';

  @override
  String get settingsLineThickness => 'Line thickness';

  @override
  String get settingsScopeVoiceColor => 'Voice oscilloscope';

  @override
  String get settingsStereoColors => 'Stereo: colors';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo left';

  @override
  String get settingsStereoRightColor => 'Stereo right';

  @override
  String get settingsNotePalette => 'Color palette';

  @override
  String get settingsNoteBoxStyle => 'Block style';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'All visualizers';

  @override
  String get settingsVizScopes => 'Oscilloscopes (stereo and per-voice)';

  @override
  String get settingsVizFrameRate => 'Frame rate';

  @override
  String get settingsVizFrameRateScreen => 'Screen';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => 'Intensity / speed';

  @override
  String get settingsArtworkOpacity => 'Background artwork opacity';

  @override
  String get settingsProjectMTitle => 'projectM settings';

  @override
  String get settingsProjectMSubtitle => 'Presets, transitions, quality, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Track-change notifications';

  @override
  String get settingsNotifyTrackSubtitle =>
      'System notification with the new track\'s title';

  @override
  String get settingsSilenceDetection => 'Silence detection';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get localActionPlay => 'Play files or a folder';

  @override
  String get localActionImport => 'Import files or a folder';

  @override
  String localOpsImporting(String name) {
    return 'Importing $name…';
  }

  @override
  String get localOpsImportingSelection => 'Importing the selected files…';

  @override
  String localOpsDeleting(String name) {
    return 'Deleting $name…';
  }

  @override
  String get localOpsPhaseCopying => 'copying';

  @override
  String get localOpsPhaseExtracting => 'extracting';

  @override
  String get localOpsPhaseRegistering => 'adding to library';

  @override
  String get localOpsPhaseDeleting => 'removing files';

  @override
  String get localImportFiles => 'Import files';

  @override
  String get storageLocalImports => 'Local imports';

  @override
  String get settingsVgmJapaneseTags => 'Japanese tags (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'Prefer the Japanese title/game/artist fields of VGM tags when present.';

  @override
  String get localImportFolder => 'Import a folder';

  @override
  String get localLibraryTitle => 'On this device';

  @override
  String get libraryOnAnotherDevice => 'On another device';

  @override
  String get localLibraryEmpty =>
      'No local imports yet. Use “Import files” or “Import a folder” from Home.';

  @override
  String queueLimitReached(int count) {
    return 'Queue limited to the first $count tracks';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return 'Delete “$name”? The file and its companion files (artwork…) will be removed.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete folder “$name” and its $count tracks?',
      one: 'Delete folder “$name” and its $count track?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count track(s) imported to library';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks track(s) imported — $albums album(s)';
  }

  @override
  String localImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'Blends the end of each track into the start of the next. At 0, playback is still gapless.';

  @override
  String get settingsMinSubsongSection => 'Short subsongs';

  @override
  String get settingsMinSubsongTitle => 'Minimum length';

  @override
  String get settingsMinSubsongHelp =>
      'Subsongs shorter than this stay out of the list and the queue — a game file often holds more sound effects than music. At 0 nothing is dropped; a length the decoder cannot tell is never treated as short.';

  @override
  String get localNewFolder => 'New folder';

  @override
  String get localFolderName => 'Folder name';

  @override
  String get localRename => 'Rename';

  @override
  String get localMoveTo => 'Move to…';

  @override
  String get localMove => 'Move';

  @override
  String get localMoveNothing => 'Nothing moved';

  @override
  String get localNameInvalid => 'Invalid name';

  @override
  String get localNameTaken => 'That name is already taken';

  @override
  String get localMoveIntoItself => 'A folder cannot be moved into itself';

  @override
  String get localManageFailed => 'Operation failed';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Not queued: under $seconds s (Settings → Playback)';
  }

  @override
  String get settingsQueuePrefetchSection => 'Queue downloads';

  @override
  String get settingsQueuePrefetchTitle => 'Download the whole queue';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'One file at a time; the next missing track starts as soon as the previous one lands. Off: only the next track is fetched.';

  @override
  String get settingsCdRipDeclickSection => 'CD rips';

  @override
  String get settingsCdRipDeclickTitle => 'Remove clicks at track start';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'Bad CD rips (mp3, ape, ogg, flac…) often open on a few corrupt samples. They are repaired until 200 ms of real music has played; the filter then steps aside.';

  @override
  String get settingsSilenceSkipTitle => 'Skip to the next track on silence';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Moves on automatically when the output stays silent';

  @override
  String get settingsSilenceDelay => 'Silence delay';

  @override
  String get settingsDefaultDuration => 'Default duration';

  @override
  String get settingsDefaultDurationHelp =>
      'Used when a track reports no known duration (no tag, no server metadata) — keeps it from playing or looping forever. Never applies to Amiga tracks (UADE), which have their own songlength database.';

  @override
  String get settingsForcedLoopHeader => 'Forced loop / fade-out';

  @override
  String get settingsForcedLoopHelp =>
      'Some formats loop a specific section (VGM, tracker modules…); others don\'t. \"Infinite\" ignores the track\'s natural end.';

  @override
  String get settingsForceLoopCount => 'Force the number of loops';

  @override
  String get settingsLoopCount => 'Number of loops';

  @override
  String get settingsForceFadeout => 'Force a fade-out';

  @override
  String get settingsFadeoutDuration => 'Fade duration';

  @override
  String get settingsResetEnginesTitle => 'Reset engine settings?';

  @override
  String get settingsResetEnginesBody =>
      'All engine settings will go back to their default values.';

  @override
  String get settingsResetDefaultsTitle => 'Reset to default values';

  @override
  String get settingsResetDefaultsSubtitle => 'All engines';

  @override
  String get settingsDefaultDecoders => 'Default decoders';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formats several engines can play';

  @override
  String get settingsDecodersHelp =>
      'Some formats can be played by several engines. Pick which one to use by default — every other format is routed automatically.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga trackers (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Modules libopenmpt cannot read — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — quality, filters, per-chip options';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — high-pass filter';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont in use';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolation, low-pass, echo';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panning, headphones, gain, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — clock, model, ReSIDfp filters';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — stereo/surround harmonic mode';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, reverb';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612, OPL3, QSound cores…';

  @override
  String get settingsMasterVolume => 'Master volume';

  @override
  String get settingsAmplification => 'Amplification';

  @override
  String get settingsAmigaFilter => 'Amiga filter';

  @override
  String get settingsInterpolation => 'Interpolation';

  @override
  String get settingsPolyphony => 'Polyphony';

  @override
  String get settingsReverb => 'Reverb';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'This MIDI was written for a Roland MT-32. Without its ROMs it plays on the SoundFont, with instruments mapped to General MIDI — import the ROMs in Settings › Engines › Munt for the real thing.';

  @override
  String get settingsMidiMt32ToGm => 'Adapt MT-32 files';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'A MIDI written for a Roland MT-32 numbers its programs in the MT-32\'s own list: mapped to their closest General MIDI equivalent, it plays with plausible instruments instead of random ones.';

  @override
  String get settingsInterpNone => 'None';

  @override
  String get settingsInterpLinear => 'Linear';

  @override
  String get settingsInterpCubic => 'Cubic';

  @override
  String get settingsInterpSinc => 'Sinc (best)';

  @override
  String get settingsStereoSeparation => 'Stereo separation';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Ends the track when the engine detects a long silence';

  @override
  String get settingsStereoDepth => 'Stereo depth';

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — no effect on SPC';

  @override
  String get settingsBass => 'Bass';

  @override
  String get settingsTreble => 'Treble';

  @override
  String get settingsAppliedLive =>
      'Applied immediately, even during playback.';

  @override
  String get settingsAppliedNextTrack => 'Applied to the next track loaded.';

  @override
  String get settingsSidEmulation => 'Emulation';

  @override
  String get settingsSidResidfp => 'ReSIDfp (accurate)';

  @override
  String get settingsSidLite => 'SIDLite (fast)';

  @override
  String get settingsSidSampling => 'Sampling';

  @override
  String get settingsSidSamplingInterp => 'Interpolation (fast)';

  @override
  String get settingsSidSamplingResample => 'Resample (best)';

  @override
  String get settingsSidClock => 'Clock';

  @override
  String get settingsSidModel => 'SID model';

  @override
  String get settingsSidFilter => 'SID filter';

  @override
  String get settingsSidForceSecond => 'Force a 2nd SID';

  @override
  String get settingsSidSecondSubtitle => 'Stereo 2SID tunes';

  @override
  String get settingsSidSecondAddr => '2nd SID address';

  @override
  String get settingsSidForceThird => 'Force a 3rd SID';

  @override
  String get settingsSidThirdAddr => '3rd SID address';

  @override
  String get settingsSidAutoFilter => 'Auto 6581 filter range';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Value recommended for the tune\'s author (sidplayfp tables)';

  @override
  String get settingsSid6581Range => '6581 filter range';

  @override
  String get settingsSid6581Curve => '6581 filter curve';

  @override
  String get settingsSid8580Curve => '8580 filter curve';

  @override
  String get settingsSidNote =>
      'SID filter and curves are applied live; emulation/sampling/clock/model/2nd-3rd SID take effect on the next track.';

  @override
  String get settingsAudioOutput => 'Audio output';

  @override
  String get settingsAdplugNote =>
      'Surround: two slightly detuned OPL chips. Applied to the next track.';

  @override
  String get settingsHeSpuMain => 'Main voices (SPU)';

  @override
  String get settingsHeSpuReverb => 'Reverb (SPU)';

  @override
  String get settingsNsfQuality => 'Quality (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Low-pass filter';

  @override
  String get settingsHighpassFilter => 'High-pass filter';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC forced';

  @override
  String get settingsNsfRegionPalForced => 'PAL forced';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy forced';

  @override
  String get settingsNsfForceIrq => 'Force IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulses (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — triangle / noise / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Unmute on reset';

  @override
  String get settingsNsfPhaseRefresh => 'Refresh phase';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Reset the phase when the period is written';

  @override
  String get settingsNsfNonlinearMixer => 'Non-linear mixing';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'The 2A03\'s real mix (otherwise linear)';

  @override
  String get settingsNsfDutySwap => 'Swap duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Order of the 25% / 50% duties';

  @override
  String get settingsNsfNegateSweep => 'Negative sweep on init';

  @override
  String get settingsNsfEnable4011 => 'Register \$4011 enabled';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Direct DAC output (original clicks)';

  @override
  String get settingsNsfPeriodicNoise => 'Periodic noise';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Short mode of the noise generator';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM anti-click';

  @override
  String get settingsNsfRandomizeNoise => 'Randomize noise on init';

  @override
  String get settingsNsfTriangleMute => 'Mute the triangle';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Silences the triangle at ultrasonic periods';

  @override
  String get settingsNsfRandomizeTri => 'Randomize triangle on init';

  @override
  String get settingsNsfDpcmReverse => 'Reversed DPCM';

  @override
  String get settingsNsfN163Serial => 'Serial multiplexing';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'The real N163 buzz on multi-voice tunes';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Read-only phase';

  @override
  String get settingsNsfN163LimitWavelength => 'Limit the wavelength';

  @override
  String get settingsNsfFdsCutoff => 'Low-pass cutoff';

  @override
  String get settingsNsfFds4085Reset => '\$4085 reset';

  @override
  String get settingsNsfFdsWriteProtect => 'Write protection';

  @override
  String get settingsNsfVrc7Patch => 'Patch set';

  @override
  String get settingsNsfVrc7Opll => 'OPLL mode';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Emulate a YM2413 instead of the VRC7';

  @override
  String get settingsGbsHpFilter => 'High-pass filter (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (classic GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Echo';

  @override
  String get settingsUadePostfx => 'Post-processing';

  @override
  String get settingsUadePostfxSubtitle =>
      'Enables the effect chain (required for everything below)';

  @override
  String get settingsUadePan => 'Panning (stereo separation)';

  @override
  String get settingsUadePanValue => 'Panning amount';

  @override
  String get settingsUadeHeadphones => 'Headphones';

  @override
  String get settingsUadeLed => 'LED (Paula filter)';

  @override
  String get settingsUadeLedAuto => 'Auto (per tune)';

  @override
  String get settingsUadeLedOn => 'Forced ON';

  @override
  String get settingsUadeLedOff => 'Forced OFF';

  @override
  String get settingsUadeFilterType => 'Filter type';

  @override
  String get settingsUadeGain => 'Gain';

  @override
  String get settingsUadeGainValue => 'Gain amount';

  @override
  String get settingsSoundfontLoading => 'Loading the catalogue…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Catalogue unavailable ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String get settingsSoundfontImport => 'Import a SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Choose an .sf2 file on this device';

  @override
  String get settingsSoundfontImported => 'Imported';

  @override
  String get settingsSoundfontInvalid => 'That file is not a SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Import failed — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Delete the file';

  @override
  String get settingsCreditsHeader => 'Credits & licenses';

  @override
  String get settingsRightsNotice =>
      'Rewamp is a player: it hosts no files and distributes no music. Tracks come from online preservation archives and remain the property of their rights holders. It is your responsibility to ensure that listening to them, downloading them and keeping them complies with the applicable rights and with the law of your country.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formats supported',
      one: '$count format supported',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spread across $count playback engines — see the details',
      one: 'Handled by $count playback engine — see the details',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga songlengths & metadata';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb by Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID data & cover art';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — C64 game metadata and visuals.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 font';

  @override
  String get settingsFt2FontSubtitle =>
      'The pattern visualizer\'s FastTracker II style uses the FT2 bitmap font from ft2-clone by 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url copied';
  }

  @override
  String get settingsOpenLink => 'Open link';

  @override
  String get settingsEnginesHeader => 'Playback engines';

  @override
  String get settingsComponentsHeader => 'Other components';

  @override
  String get settingsResetAll => 'Reset all settings';

  @override
  String get settingsResetAllSubtitle =>
      'General, Visualization, Playback, Engines — not the library';

  @override
  String get settingsResetAllTitle => 'Reset all settings?';

  @override
  String get settingsResetAllBody =>
      'General, Visualization, Playback and every engine will go back to their default values. Your library and history are untouched.';

  @override
  String get settingsRenewUserId => 'Renew the anonymous ID';

  @override
  String get settingsRenewUserIdTitle => 'Renew the anonymous ID?';

  @override
  String get settingsRenewUserIdBody =>
      'A new anonymous ID will be created for server statistics.\n\nThe old one will no longer be used. Your local history and favorites are unaffected.';

  @override
  String get settingsRenewUserIdFailed => 'Failed — server unreachable';

  @override
  String settingsNewUserId(String id) {
    return 'New ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'No ID registered';

  @override
  String get settingsCleanDb => 'Clean up the local database';

  @override
  String get settingsCleanDbSubtitle =>
      'Removes entries whose file no longer exists (deleted downloads, old errors)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orphan entries removed',
      one: '$count orphan entry removed',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'Local database is clean — nothing to remove';

  @override
  String get settingsClearCache => 'Clear the cache (artwork & metadata)';

  @override
  String get settingsClearCacheSubtitle =>
      'Removes cached covers and fetched metadata (STIL, songlengths) — re-downloaded on the next play';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cache cleared ($count covers)',
      one: 'Cache cleared ($count cover)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Storage';

  @override
  String get storageSubtitle => 'What the app keeps on disk, with deletion';

  @override
  String get storageDownloads => 'Downloads';

  @override
  String get storageArtworkCache => 'Artwork cache';

  @override
  String get storageSoundfonts => 'SoundFonts';

  @override
  String get storagePresets => 'Visualizer presets';

  @override
  String get storageOpenedFiles => 'Opened files';

  @override
  String get storageOpenedEmpty =>
      'Files opened from outside the app (share, “Open with”, the file picker on mobile) are copied here.';

  @override
  String get storageInUse => 'in a playlist or library';

  @override
  String get storageDeleteAll => 'Delete all';

  @override
  String get storageClear => 'Clear';

  @override
  String get storageDeleteSelection => 'Delete selection';

  @override
  String get storageSelectAll => 'Select all';

  @override
  String get storageFilterHint => 'Filter by name';

  @override
  String get storageNoMatch => 'No file matches this filter.';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count files?',
      one: 'Delete $count file?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Delete $count files? $inUse of them are used by a playlist or the library — those entries will lose their file.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Delete every downloaded file and its library rows? Favourites and playlists keep their entries, but the files will need downloading again.';

  @override
  String get storageSoundfontsClearBody =>
      'Delete every SoundFont, imported ones included? Catalogue SoundFonts re-download on demand; imported files are lost.';

  @override
  String get storagePresetsClearBody =>
      'Delete downloaded preset packs and imported presets? Bundled presets are kept; packs re-download on demand, imported files are lost.';

  @override
  String get storageOpenedDeleteAllTitle => 'Delete opened files';

  @override
  String get storageInUseDeleteTitle => 'File in use';

  @override
  String get storageInUseDeleteBody =>
      'A playlist or the library still points at this file. Deleting it will leave those entries without their file.';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files — $size',
      one: '$count file — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files — $size · managed from albums and tracks',
      one: '$count file — $size · managed from albums and tracks',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Delete $count files? Files used by a playlist or the library are kept.',
      one:
          'Delete $count file? Files used by a playlist or the library are kept.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Reset the statistics';

  @override
  String get settingsResetStatsSubtitle =>
      'Removes the listening history and the play counters';

  @override
  String get settingsClearStatsTitle => 'Reset the statistics?';

  @override
  String get settingsClearStatsBody =>
      'This will permanently delete:\n• the whole listening history\n• the play counters\n\nYour favorites and your library are unaffected.';

  @override
  String get settingsStatsCleared => 'Statistics deleted';

  @override
  String get settingsResetDatabase => 'Reset the database';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Deletes everything: history, favorites, playlists, cache';

  @override
  String get settingsResetDbTitle => 'Reset the database?';

  @override
  String get settingsCleanLocalTitle => 'Clean up unplayable local entries';

  @override
  String get cleanStageScan => 'Scanning entries…';

  @override
  String get cleanStageSync => 'Syncing with your account…';

  @override
  String get cleanStagePurge => 'Removing from your account…';

  @override
  String get cleanStageDelete => 'Removing locally…';

  @override
  String get settingsCleanLocalBody =>
      'Library entries naming a file that is no longer on this device. They are removed from your account too, so they disappear from your other devices.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries removed',
      one: '$count entry removed',
      zero: 'Nothing to clean up',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'This will permanently delete:\n• the whole listening history\n• every counter\n• every favorite\n• every playlist\n• all cached metadata\n\nYour audio files are not deleted.';

  @override
  String get settingsDbReset => 'Database reset';

  @override
  String get settingsDeleteDownloads => 'Delete the downloads';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Deletes every file in the online folder (tracks, artwork)';

  @override
  String get settingsCleanAll => 'Clean the local database and cache';

  @override
  String get settingsCleanAllSubtitle =>
      'Removes entries whose file is gone, library entries pointing at files kept on another device, and the artwork & metadata cache';

  @override
  String get settingsCleanAllConfirmBody =>
      'Library entries pointing at files kept on another device are also removed from your account, so from your other devices. Artwork and metadata are re-downloaded on next play.';

  @override
  String get settingsDataAdvanced => 'Advanced';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Each cleanup step on its own, the cache, and the resets';

  @override
  String get settingsDataGroupDb => 'Database';

  @override
  String get settingsDataGroupCache => 'Cache';

  @override
  String get settingsDataGroupReset => 'Reset';

  @override
  String get settingsDeleteDownloadsTitle => 'Delete the downloads?';

  @override
  String get settingsDeleteDownloadsBody =>
      'This will permanently delete every downloaded file (tracks, albums, artwork) from the online folder.\n\nThe database entries will stay but will point at files that no longer exist.';

  @override
  String get settingsDownloadsDeleted => 'Downloads deleted';

  @override
  String get settingsColor => 'Color';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Random next preset';

  @override
  String get settingsPmRandomNextSubtitle => 'Off: play the presets in order';

  @override
  String get settingsPmLockPreset => 'Lock the preset';

  @override
  String get settingsPmLockPresetSubtitle => 'No automatic switching';

  @override
  String get settingsPmPresetDuration => 'Time between presets';

  @override
  String get settingsPmTransitions => 'Transitions';

  @override
  String get settingsPmBlend => 'Cross-fade transition';

  @override
  String get settingsPmBlendSubtitle => 'Off: switch presets instantly';

  @override
  String get settingsPmTransitionStyle => 'Transition style';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Which pattern the blend uses';

  @override
  String get settingsPmTransitionRandom => 'Random';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Beat-synced preset switching';

  @override
  String get settingsPmHardcutTime => 'Hardcut: minimum time';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: sensitivity';

  @override
  String get settingsPmRendering => 'Rendering';

  @override
  String get settingsPmQuality => 'Quality';

  @override
  String get settingsPmQualitySubtitle =>
      'Render resolution (Max = native resolution)';

  @override
  String get settingsPmBeatSensitivity => 'Beat sensitivity';

  @override
  String get settingsPmAspectRatio => 'Respect the aspect ratio';

  @override
  String get settingsPmAspectRatioSubtitle => 'For the shaders that support it';

  @override
  String get settingsPmPermissive => 'Permissive mode';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Load .milk files that have script errors';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSubtitle => 'Save and sync your library';

  @override
  String get accountAnonymous => 'Anonymous account';

  @override
  String get accountAnonymousExplain =>
      'Your favourites and your history are stored on the server, but only this device can reach them. Add an email address to find them again elsewhere.';

  @override
  String get accountEmailAttached =>
      'Address confirmed — this account can be restored';

  @override
  String get accountEmailPending => 'Address not confirmed yet';

  @override
  String get accountInsecureStorage =>
      'This device\'s secure storage is unavailable: the account identifier is stored unencrypted.';

  @override
  String get accountSaveCta => 'Save my account';

  @override
  String get accountStatSongs => 'Favourite tracks';

  @override
  String get accountStatAlbums => 'Favourite albums';

  @override
  String get accountStatPlays => 'Plays';

  @override
  String get accountCreatedLabel => 'Created';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountRevoke => 'Log out everywhere';

  @override
  String get accountRevokeSubtitle => 'Signs out every other device';

  @override
  String get accountRevokeBody =>
      'Every other device is signed out. This one stays connected.';

  @override
  String get accountRevokeDone => 'Other devices signed out';

  @override
  String get accountDelete => 'Delete my account';

  @override
  String get accountDeleteSubtitle =>
      'Erases the account and its data on the server. Irreversible.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favourites and $lists playlists will be deleted from the server. This cannot be undone.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Your downloads and this device\'s library are not affected.';

  @override
  String get accountDeleteDone => 'Account deleted';

  @override
  String get accountSignOutSubtitle =>
      'This device goes back to a new, empty account';

  @override
  String get accountSignOutTitle => 'Sign out?';

  @override
  String accountSignOutBody(String email) {
    return 'You can come back to this account with a code sent to $email.';
  }

  @override
  String get accountSignedOut => 'Signed out';

  @override
  String get accountNoSignOut => 'Signing out is unavailable';

  @override
  String get accountNoSignOutSubtitle =>
      'Without an email address, this account could never be recovered.';

  @override
  String get accountDetach => 'Unlink address';

  @override
  String get accountDetachSubtitle =>
      'The account goes back to anonymous, no data is deleted';

  @override
  String get accountDetachBody =>
      'Without an address, this account can no longer be recovered from another device.';

  @override
  String get accountDetachDone => 'Address unlinked';

  @override
  String get accountOffline => 'Account unavailable offline';

  @override
  String get accountEmailTitle => 'Email address';

  @override
  String get accountEmailExplain =>
      'We send you a 6-digit code to confirm the address. It is only used to recover your account.';

  @override
  String get accountEmailLabel => 'Email address';

  @override
  String get accountCodeTitle => 'Confirmation code';

  @override
  String accountCodeExplain(String email) {
    return 'Code sent to $email. It is valid for 10 minutes.';
  }

  @override
  String get accountCodeLabel => '6-digit code';

  @override
  String get accountSendCode => 'Send the code';

  @override
  String get accountVerify => 'Confirm';

  @override
  String get accountResend => 'Resend the code';

  @override
  String accountResendIn(int n) {
    return 'Resend in $n s';
  }

  @override
  String get accountCheckSpam =>
      'The email can take up to a minute to arrive — check your spam folder.';

  @override
  String get accountErrorInvalidEmail => 'Invalid address';

  @override
  String get accountErrorTooMany =>
      'Too many requests, try again in a few minutes';

  @override
  String get accountErrorInvalidCode => 'Wrong or expired code';

  @override
  String get accountErrorCodeLength => 'The code has 6 digits';

  @override
  String get albumOfflinePartial =>
      'Offline — showing what is already on this device';

  @override
  String get accountErrorNetwork => 'Connection failed, try again';

  @override
  String get accountMergeTitle => 'Merge this library?';

  @override
  String accountMergeBody(String email) {
    return 'This device\'s favourites and history will be added to the $email account. This cannot be undone.';
  }

  @override
  String get accountMergeConfirm => 'Merge';

  @override
  String get accountCarryLocal => 'Keep this device\'s favourites';

  @override
  String accountCarryLocalOn(int n) {
    return 'The $n favourites and the playlists on this device are added to the account.';
  }

  @override
  String get accountCarryLocalOff =>
      'They are deleted from this device and replaced by the account\'s. Downloaded files are kept.';

  @override
  String get accountDropLocalTitle => 'Drop this device\'s data?';

  @override
  String get accountCreatedOk => 'Account saved, your library is backed up';

  @override
  String get accountMergedOk => 'Signed in — your local favourites were added';

  @override
  String get accountSignedInOk => 'Signed in';

  @override
  String get playlistEntryMissing => 'File missing on this device';

  @override
  String get playlistEntryMissingRestorable =>
      'File missing — can be downloaded again';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n missing',
      one: '$n missing',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Back up to my account';

  @override
  String get playlistBackupSubtitle =>
      'Keeps this playlist even if the app is reinstalled';

  @override
  String get playlistBackupUpdate => 'Update the backup';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Replaces the account copy with this version';

  @override
  String get playlistBackupStop => 'Stop backing up';

  @override
  String get playlistBackupStopped => 'Backup removed';

  @override
  String get playlistBackupDone => 'Playlist backed up';

  @override
  String get playlistBackupFailed => 'Backup failed';

  @override
  String get playlistBackupNoAccount => 'No account on this device';

  @override
  String get playlistSyncTooltip => 'Sync with my account';

  @override
  String get playlistSyncRunning => 'Syncing…';

  @override
  String get playlistSyncDone => 'Playlists synced';

  @override
  String get playlistSyncPartial => 'Some playlists could not be backed up';

  @override
  String get playlistFetchMissing => 'Download the missing tracks';

  @override
  String get playlistFetchDone => 'Missing tracks downloaded';

  @override
  String get playlistFetchPartial => 'Some tracks could not be downloaded';

  @override
  String get playlistEntryFetchFailed => 'This track could not be downloaded';

  @override
  String get accountStatPlaylists => 'Playlists';

  @override
  String get accountSyncNow => 'Sync now';

  @override
  String get accountSyncAuto => 'Runs on its own in the background';

  @override
  String get accountSyncAnonymous =>
      'Backed up to the server. Add an email to sync another device.';

  @override
  String get accountSyncPending => 'Changes waiting to be sent';

  @override
  String accountSyncLast(String when) {
    return 'Last sync: $when';
  }

  @override
  String get accountSyncDone => 'Sync done';

  @override
  String get accountSyncFailed => 'Sync failed, will retry';

  @override
  String get podiumFirst => '1st';

  @override
  String get podiumSecond => '2nd';

  @override
  String get podiumThird => '3rd';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'music of $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'contains the $place of $compo';
  }

  @override
  String get competitionEmpty => 'This competition has no entries';

  @override
  String get competitionEntryNoMusic =>
      'No music in the catalogue for this entry';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n tunes',
      one: '$n tune',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingBetaTitle => 'Beta version';

  @override
  String get onboardingBetaBody =>
      'Rewamp is still being built. Local data — library, playlists, favourites, listening stats — may be wiped before version 1.0. Nothing you download is at risk, but keep anything precious backed up elsewhere.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Explore';

  @override
  String get onboardingExploreBody =>
      'Browse and search tens of thousands of chiptunes and tracker modules from the great online archives, by artist, album, platform or party. Tap to listen, download to keep.';

  @override
  String get onboardingLibraryTitle => 'Your library';

  @override
  String get onboardingLibraryBody =>
      'Save what you like, build playlists, organise them in folders. Anything downloaded plays offline, and your library follows you across devices once you sign in.';

  @override
  String get onboardingPlayerTitle => 'The player';

  @override
  String get onboardingPlayerBody =>
      'Swipe to change track, and open the visualizers: oscilloscope, per-voice scopes, scrolling notes, tracker grid. Multi-track files expose their subsongs, and every voice can be muted on its own.';

  @override
  String get onboardingReplayTitle => 'Welcome tour';

  @override
  String get onboardingReplaySubtitle =>
      'Replay the beta notice and the feature tour';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Tracker grid: colours, columns, scrolling';

  @override
  String get patternOpaqueBg => 'Opaque background';

  @override
  String get patternOpaqueBgSubtitle => 'Hides the cover art behind the grid';

  @override
  String get commonSave => 'Save';

  @override
  String get commonImport => 'Import';

  @override
  String get accountDisplayName => 'Public name';

  @override
  String get accountDisplayNameNotSet =>
      'Not set — required to publish a playlist';

  @override
  String get accountDisplayNameHint =>
      'The name you want to be credited under.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Changing it sends every playlist you published back for review.';

  @override
  String get accountDisplayNameTaken =>
      'This name is taken. Choose another one.';

  @override
  String get accountDisplayNameLength => 'Between 2 and 40 characters.';

  @override
  String get accountDisplayNameSaved => 'Public name saved';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlists sent back for review: $n';
  }

  @override
  String get playlistPublish => 'Make public';

  @override
  String get playlistPublishSubtitle => 'Request publication (reviewed first)';

  @override
  String get playlistPublishTitle => 'Publish this playlist?';

  @override
  String get playlistPublishBody =>
      'It becomes visible to everyone once approved, credited to your public name. The cover comes from its tracks.';

  @override
  String get playlistPublishCta => 'Request';

  @override
  String get playlistPublishSubmitted => 'Sent for review';

  @override
  String get playlistPublishPending => 'Waiting for approval';

  @override
  String get playlistPublishApproved => 'Public';

  @override
  String playlistPublishRejected(String reason) {
    return 'Refused: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Refused';

  @override
  String get playlistPublishNeedName =>
      'Choose the name you want to be credited under';

  @override
  String get playlistPublishNeedTracks =>
      'At least 5 tracks are needed to publish';

  @override
  String get playlistPublishHasLocal =>
      'Files from your device cannot be published — others cannot play them';

  @override
  String get playlistPublishTooManyPending =>
      'You already have 3 playlists waiting for approval';

  @override
  String get playlistPublishRefused =>
      'Publication refused: check the tracks and the pending requests';

  @override
  String get playlistPublishFailed => 'Publication failed';

  @override
  String get playlistPublishWithdrawn => 'Playlist is private again';

  @override
  String get playlistUnpublish => 'Make private';

  @override
  String get playlistUnpublishSubtitle => 'Removes it from public playlists';

  @override
  String get playlistRenamePublishedTitle => 'Rename a published playlist?';

  @override
  String get playlistRenamePublishedBody =>
      'The name is what gets reviewed: renaming sends the playlist back for approval and unpublishes it meanwhile. Adding or reordering tracks does not.';

  @override
  String playlistByAuthor(String author) {
    return 'by $author';
  }

  @override
  String get settingsSpectrumMode => 'Spectrum mode';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Colored';

  @override
  String get settingsSpectrumModeBeam => 'Beam';

  @override
  String get settingsSpectrumModeLine => 'Line';

  @override
  String get settingsSpectrumModeRing => 'Ring';

  @override
  String get settingsPianoMode => 'Piano look';

  @override
  String get settingsPianoModeRoll => 'Keyboards';

  @override
  String get settingsPianoModeFalling => 'Falling notes';

  @override
  String get settingsPianoColor => 'Colors';

  @override
  String get settingsPianoColorVoice => 'By voice';

  @override
  String get settingsPianoColorInstrument => 'By instrument';

  @override
  String get settingsPianoGlow => 'Glow on struck keys';

  @override
  String get settingsPianoLighting => 'Light and shadows on the keys';

  @override
  String get settingsPianoVoiceNames => 'Voice names';

  @override
  String get featuredAdditionsHeader => 'New in the catalogue';

  @override
  String get featuredAdditionsCard => 'Just added';

  @override
  String get featuredAdditionsPlaylist => 'The freshly added tunes';

  @override
  String get releaseNotesTitle => 'What\'s new';

  @override
  String get releaseNotesV7Cpu =>
      'The app no longer works away in the background when nothing is playing: far less processor and battery.';

  @override
  String get releaseNotesV7VizIdle =>
      'Visualizers stand still while playback is stopped, and are capped at 60 frames per second (adjustable).';

  @override
  String get releaseNotesV7Subsongs =>
      'Fixed: on PC Engine, Master System and Atari ST (.sndh), some tracks started the song next to the right one.';

  @override
  String get releaseNotesV7Piano =>
      'The Piano visualizer stayed empty on PC Engine music.';

  @override
  String get releaseNotesV7Database =>
      'A database left broken by an update now repairs itself, instead of making the library unreachable.';

  @override
  String get releaseNotesDataReset =>
      'Local data was reset for this beta. Your library and playlists rebuild from your account; downloads start over.';

  @override
  String get releaseNotesDismiss => 'Continue';

  @override
  String get pmManagePresets => 'Manage presets';

  @override
  String get pmPickTooltip => 'Pick a preset';

  @override
  String get pmPickFilter => 'Filter presets';

  @override
  String get pmSourceTooltip => 'Preset source';

  @override
  String get pmAddToPlaylistTooltip => 'Add preset to a playlist';

  @override
  String pmSlowPresetDropped(String name) {
    return '“$name” is too heavy for this device and was set aside.';
  }

  @override
  String get pmSlowDeviceTitle => 'This device is too slow';

  @override
  String get pmSlowDeviceOff =>
      'The visualiser was turned off: this device cannot keep up with Milkdrop presets.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets set aside',
      one: '$count preset set aside',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Too slow on this device. Playback skips them.';

  @override
  String get settingsPmSlowPresetsRestore => 'Restore';

  @override
  String get pmSourceBundled => 'Built-in presets';

  @override
  String get pmSourceImports => 'My imports';

  @override
  String get pmSourceAll => 'All presets';

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
  String get pmNewPlaylist => 'New playlist…';

  @override
  String get pmPlaylistName => 'Playlist name';

  @override
  String get pmAddedToPlaylist => 'Added to playlist';

  @override
  String get pmAlreadyInPlaylist => 'Already in this playlist';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Browse';

  @override
  String get pmTabPlaylists => 'Playlists';

  @override
  String get pmTabPopular => 'Popular';

  @override
  String get pmTabSetAside => 'Set aside';

  @override
  String get pmSetAsideEmpty =>
      'Nothing set aside. Presets that make this device drop below 6 fps land here.';

  @override
  String get pmSetAsideRestoreAll => 'Restore all';

  @override
  String get pmInstall => 'Install';

  @override
  String get pmInstallQueued => 'Install queued';

  @override
  String get pmUninstall => 'Uninstall';

  @override
  String get pmUninstalled => 'Pack removed';

  @override
  String get pmUse => 'Use';

  @override
  String get pmDefaultPackBanner => 'Recommended starter pack';

  @override
  String pmLicense(String license) {
    return 'License: $license';
  }

  @override
  String get pmPacksOffline => 'Server unreachable';

  @override
  String get pmSearchPresets => 'Search presets…';

  @override
  String get pmPlayNow => 'Play now';

  @override
  String get pmDownloadAction => 'Download';

  @override
  String get pmDownloaded => 'Preset downloaded';

  @override
  String get pmDownloadFailed => 'Download failed';

  @override
  String pmPreviewing(String name) {
    return 'Playing: $name';
  }

  @override
  String get pmLocalSection => 'My playlists';

  @override
  String get pmCuratedSection => 'Rewamp playlists';

  @override
  String get pmImportPlaylist => 'Download and use';

  @override
  String get pmPlaylistImported => 'Playlist ready';

  @override
  String get pmImportFiles => 'Import files…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets imported',
      one: '$count preset imported',
      zero: 'No preset imported',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets added to the projectM library';

  @override
  String get pmNoPlaylists => 'No preset playlists yet';

  @override
  String get pmSourceApplied => 'Preset source applied';

  @override
  String get pmPlaylistEmpty => 'This playlist is empty';

  @override
  String get pmDays7 => '7 days';

  @override
  String get pmDays30 => '30 days';

  @override
  String get pmDays365 => '1 year';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '$count play',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Install failed';

  @override
  String get pmSingleDownloads => 'Individual downloads';

  @override
  String pmAvailableIn(String pack) {
    return 'Available in $pack';
  }

  @override
  String get pmCleanUp => 'Clean up';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets deleted',
      one: '$count preset deleted',
      zero: 'Nothing to clean up',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Lock this preset';

  @override
  String get pmUnlockAction => 'Unlock the preset';

  @override
  String get pmOrderRandom => 'Shuffle presets';

  @override
  String get pmOrderSequential => 'Play presets in order';

  @override
  String get pmUpdateAvailable => 'Update available';

  @override
  String get pmUpdate => 'Update';

  @override
  String get pmSelectAll => 'Select all';

  @override
  String get pmSelectNone => 'Deselect all';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
      zero: 'None selected',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Unused textures';

  @override
  String pmTexturesFreed(String size) {
    return '$size freed';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count textures',
      one: '$count texture',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'Charts';

  @override
  String get chartsGlobal => 'Global';

  @override
  String get chartsByCollection => 'By collection';

  @override
  String get chartsTopSongs => 'Top songs';

  @override
  String get chartsTopAlbums => 'Top albums';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Published charts';

  @override
  String chartsUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get chartsSource => 'Source';

  @override
  String get settingsMidiSynth => 'MIDI synthesizer';

  @override
  String get settingsMidiSynthAuto =>
      'Automatic (MT-32 when the file asks for it)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (emulation)';

  @override
  String get settingsMt32Section => 'Roland MT-32 emulation';

  @override
  String get settingsMt32RomsTitle => 'MT-32 ROMs';

  @override
  String get settingsMt32RomsMissing =>
      'No usable ROM set — import the control and PCM ROMs of an MT-32 or CM-32L';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Active set: $set';
  }

  @override
  String get settingsMt32Import => 'Import ROM files…';

  @override
  String get settingsMt32ImportSubtitle =>
      'Control + PCM ROM (.rom/.bin), MAME split halves accepted. ROMs are not distributed with the app.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name is not a known MT-32 / CM-32L ROM';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ROM files imported',
      one: '$count ROM file imported',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Model';

  @override
  String get settingsMt32ModelAuto => 'Automatic (CM-32L if available)';

  @override
  String get settingsMt32Reverb => 'Reverb';

  @override
  String get engineDescMt32 =>
      'Roland MT-32 / CM-32L emulation for MIDI (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Mini player';

  @override
  String get miniWindowExit => 'Back to the main window';

  @override
  String get miniWindowIdle => 'Nothing playing';

  @override
  String get settingsAlwaysOnTopTitle => 'Always on top';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Keep the window above all others — main window and mini player alike';

  @override
  String get windowAlwaysOnTopOn => 'Always on top: on';

  @override
  String get miniWindowCoverFill => 'Zoom cover to fill';

  @override
  String get miniWindowCoverFit => 'Show whole cover';

  @override
  String get releaseNotesV7Mt32 =>
      'New Roland MT-32 engine for game MIDI music, with your own ROMs. Without ROMs, a MIDI written for the MT-32 is adapted to General MIDI.';

  @override
  String get releaseNotesV7Xmp =>
      'Ten rare module formats now play (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'Westwood AdLib music (.adl) plays all of its tracks, and BP SoundMon V1 is recognised on Amiga.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac: a mini player, compact or with the visualizer, and an “Always on top” option.';

  @override
  String get releaseNotesV7Instruments =>
      'Oscilloscope, notes and piano can name and colour each instrument, not just each voice.';

  @override
  String get releaseNotesV7Podium =>
      'Search: filter the tunes that placed 1st, 2nd or 3rd in a demoscene competition.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'Subsongs that are too short (game sound effects) are left out of “Play all” — threshold in Settings → Playback.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Your imports: drop a whole folder (archives unpacked), and create, rename or move folders.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI: drums no longer play as a piano, and the volume no longer clips.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM: presets no longer repeat from one launch to the next, and a preset is no longer set aside by mistake after a pause.';

  @override
  String get libraryFileMissing => 'File missing';
}
