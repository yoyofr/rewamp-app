// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Cerca';

  @override
  String get navLibrary => 'Libreria';

  @override
  String get noFileSelected => 'Nessun file selezionato';

  @override
  String get openFile => 'Apri file';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Formato non supportato';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Formato non supportato: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Non presente su questo dispositivo: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'File non più sul server: $file';
  }

  @override
  String get failedToLoadFile => 'Impossibile caricare il file';

  @override
  String get libraryEmptyHint =>
      'I tuoi artisti, album e playlist\nappariranno qui.';

  @override
  String get libraryPlaylists => 'Playlist';

  @override
  String get libraryArtists => 'Artisti';

  @override
  String get libraryAlbums => 'Album';

  @override
  String get libraryTracks => 'Brani';

  @override
  String get libraryFavorites => 'Preferiti';

  @override
  String get libraryFavoritesSubtitle =>
      'Playlist automatica dei tuoi brani preferiti';

  @override
  String get libraryRecentlyAdded => 'Aggiunti di recente';

  @override
  String get libraryEmpty => 'Ancora niente qui';

  @override
  String get libraryRemoved => 'Rimosso dalla libreria';

  @override
  String get searchHint => 'Cerca…';

  @override
  String get searchTypePlaceholder => 'Digita un titolo, artista o album…';

  @override
  String get searchNoResults => 'Nessun risultato';

  @override
  String get searchDownloading => 'Download in corso…';

  @override
  String searchError(String message) {
    return 'Errore: $message';
  }

  @override
  String get tabAll => 'Brani';

  @override
  String get tabArtists => 'Artisti';

  @override
  String get tabAlbums => 'Album';

  @override
  String get tabProductions => 'Produzioni';

  @override
  String get filterWithVideo => 'Con video';

  @override
  String get videoUnavailable => 'Questo video non è disponibile';

  @override
  String get noItems => 'Nessun elemento';

  @override
  String get sortRelevance => 'Pertinenza';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Ascoltati di recente';

  @override
  String get noRecentTracks => 'Nessun brano ascoltato di recente';

  @override
  String get openLocalFile => 'Apri un file locale';

  @override
  String get playerSourceLocal => 'locale';

  @override
  String get browseFiles => 'Sfoglia i file';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total risultati';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded caricati…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded risultati';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded caricati — scorri per caricarne altri';
  }

  @override
  String countNLoaded(int n) {
    return '$n caricati';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n file';
  }

  @override
  String get browseFilterByTitle => 'Filtra per titolo…';

  @override
  String get browseNoSongs => 'Nessun brano disponibile';

  @override
  String get browseByFormat => 'Per formato';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtra per formato…';

  @override
  String get browseByPlatform => 'Per piattaforma';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Nome della piattaforma…';

  @override
  String get browseByChip => 'Per chip sonoro';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'es. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Per artista';

  @override
  String get browseByArtistSubtitle => 'Sfoglia i compositori';

  @override
  String get browseFilterByName => 'Filtra per nome…';

  @override
  String get browseNoArtistFound => 'Nessun artista trovato';

  @override
  String get browseNoArtistsAvailable => 'Nessun artista disponibile';

  @override
  String get browseNoArtist => 'Nessun artista';

  @override
  String get browseNoAlbum => 'Nessun album';

  @override
  String get browseTopPacks => 'Top pack';

  @override
  String get browseTopPacksSubtitle => 'I pack con il punteggio più alto';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Top pack — $collection';
  }

  @override
  String get browseLatestPacks => 'Ultimi pack';

  @override
  String get browseLatestPacksSubtitle => 'Le aggiunte più recenti';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Ultimi pack — $collection';
  }

  @override
  String get browseAllSongs => 'Tutti i brani';

  @override
  String get browseAllSongsSubtitleAlpha => 'Sfoglia in ordine alfabetico';

  @override
  String get browseAlphabetical => 'In ordine alfabetico';

  @override
  String browseAllLabel(String collection) {
    return 'Tutti — $collection';
  }

  @override
  String get browseCollections => 'Collezioni';

  @override
  String browseFilesCount(String count) {
    return '$count file';
  }

  @override
  String get browseIndexing => 'Indicizzazione in corso';

  @override
  String browseFilterFacet(String name) {
    return 'Filtra $name…';
  }

  @override
  String get browseAllYears => 'Tutti gli anni';

  @override
  String get browseAllYearsSubtitle => 'Tutti i brani della demoparty';

  @override
  String get browseNoCompo => 'Nessuna compo indicizzata per questa demoparty.';

  @override
  String get browseOthers => 'Altri';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n partecipazioni — classifica',
      one: '$n partecipazione — classifica',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Riproduci la playlist';

  @override
  String get browsePlayAllRanked => 'Riproduci tutto (in ordine di classifica)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani — ordine di classifica',
      one: '$n brano — ordine di classifica',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Sfoglia per album';

  @override
  String get browsePlayAll => 'Riproduci tutto';

  @override
  String get browseShuffle => 'Riproduzione casuale';

  @override
  String get browseSearchInFolder => 'Cerca in questa cartella…';

  @override
  String get browseFilterThisList => 'Filtra questo elenco…';

  @override
  String get browseSearchSubfolders => 'Cerca nelle sottocartelle';

  @override
  String get browseEmptyFolder => 'Cartella vuota';

  @override
  String browsePlaybackError(String message) {
    return 'Riproduzione non riuscita: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Visualizzazione';

  @override
  String get browseViewList => 'Elenco';

  @override
  String get browseViewGrid => 'Griglia';

  @override
  String get browseViewGridCompact => 'Griglia compatta';

  @override
  String get browseSearchAlbum => 'Cerca un album…';

  @override
  String get browseSearchArtist => 'Cerca un artista…';

  @override
  String get browsePlayAlbum => 'Riproduci l\'album';

  @override
  String get searchDownloadingAlbum => 'Download dell\'album in corso…';

  @override
  String get searchCategoryChip => 'Chip';

  @override
  String get searchCategoryGroup => 'Gruppi';

  @override
  String get artistRealName => 'Nome reale';

  @override
  String get artistAliases => 'Alias';

  @override
  String get artistBorn => 'Nascita';

  @override
  String get artistInterview => 'Intervista';

  @override
  String get audioOutput => 'Uscita audio';

  @override
  String get audioOutputSystemDefault => 'Predefinita di sistema';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Note';

  @override
  String get notePlacedBadge => 'Classificata in competizione';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Vedi brani';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moduli',
      one: '$count modulo',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Demoparty';

  @override
  String get searchCategoryYear => 'Anno';

  @override
  String get searchCategoryOrigin => 'Origine';

  @override
  String get searchCategoryProduction => 'Produzione';

  @override
  String get searchCategoryProductionType => 'Tipi di prod';

  @override
  String get searchCategoryPublisher => 'Editori';

  @override
  String get searchCategoryDeveloper => 'Sviluppatori';

  @override
  String get searchCategoryArcadeBoard => 'Schede arcade';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Genere';

  @override
  String get searchViaArtist => 'tramite artista';

  @override
  String get searchViaAlbum => 'tramite un album';

  @override
  String get searchViaSong => 'tramite un brano';

  @override
  String get searchSortPopular => 'Popolari';

  @override
  String get searchSortYear => 'Anno';

  @override
  String get searchSortRandom => 'Casuale';

  @override
  String get searchSortRating => 'Valutazione';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voti',
      one: '$count voto',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Crescente';

  @override
  String get searchSortDesc => 'Decrescente';

  @override
  String get searchFilters => 'Filtri';

  @override
  String get searchExactSearch => 'Ricerca esatta';

  @override
  String get searchExactSearchSubtitle =>
      'Disattiva la ricerca approssimativa (fuzzy)';

  @override
  String get searchTags => 'Tag';

  @override
  String searchTagSearchHint(String category) {
    return 'Cerca un tag in « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Digita per cercare dei tag.';

  @override
  String get searchTagsAndLogic => 'Più tag = E logico.';

  @override
  String get searchFilterYear => 'Anno';

  @override
  String get searchFilterAll => 'tutti';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrare per anno esclude i brani senza data.';

  @override
  String get searchMinRating => 'Voto ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Annulla';

  @override
  String get searchReset => 'Reimposta';

  @override
  String get searchApply => 'Applica';

  @override
  String get searchClearRecent => 'Cancella le ricerche recenti';

  @override
  String get searchBrowse => 'Sfoglia';

  @override
  String get searchBrowseHint =>
      'Scegli una faccetta (gruppo, chip, anno…) per esplorare il catalogo, oppure avvia Radio/Sorpresa qui sopra.';

  @override
  String get searchDidYouMean =>
      'Pochi risultati — provare una ricerca approssimativa?';

  @override
  String get searchYes => 'Sì';

  @override
  String get featuredCommunityTitle => 'Novità dalla community';

  @override
  String get searchPlaylistSourceAll => 'Tutte';

  @override
  String get searchPlaylistSourceUser => 'Community';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formato';

  @override
  String get searchPlatform => 'Piattaforma';

  @override
  String get filterCollection => 'Collezione';

  @override
  String get videoWatchDemo => 'Guarda la demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Collezione: $name';
  }

  @override
  String get searchCollectionAll => 'Tutte';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Coda casuale sui filtri attuali';

  @override
  String get searchSurprise => 'Sorpresa';

  @override
  String get searchSurpriseTooltip => 'Un brano a caso';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Nessun brano';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
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
    return 'alias $name';
  }

  @override
  String get searchChooseCollection => 'Scegli una collezione';

  @override
  String get searchFilterCollections => 'Filtra le collezioni…';

  @override
  String get searchFilterPlaceholder => 'Filtra…';

  @override
  String searchAllOf(String label) {
    return 'Tutti ($label)';
  }

  @override
  String get searchNoMatch => 'Nessuna corrispondenza';

  @override
  String get searchNoPlaylist => 'Nessuna playlist';

  @override
  String get engineDescOpenmpt => 'Moduli tracker (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — chip sonori, scope per canale';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archivi RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — voci per canale';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (motore reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'Chiptune MSX (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace => 'Chiptune multi-chip .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Formati Amiga custom-chip tramite emulazione 68k (~320 est.)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'MIDI standard + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — synth SDAT/SSEQ (16 voci)';

  @override
  String get engineDescV2m => 'Synth V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — vera emulazione 68000 + YM2149 + DAC STE';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — emulazione R4300 + audio RSP';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — emulazione NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + chip QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — vero synth AY-3-8910/YM2149';

  @override
  String get engineDescOrganya =>
      'Cave Story .org — il motore originale di Pixel';

  @override
  String get engineDescPxtone => 'Il tracker di Pixel — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — vero 68000 via emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver del PC-98 — FM OPNA + SSG + campioni PPZ8';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ campioni .pdx), FM YM2151';

  @override
  String get engineDescFmp =>
      'Driver FMP del PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY dell\'FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Formati audio streaming da videogiochi (700+, inclusi .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — decoder di riserva';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total brani',
      one: '$loaded / 1 brano',
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
      other: '$loaded / $total artisti',
      one: '$loaded / 1 artista',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
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
      other: '$n artisti',
      one: '$n artista',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n gruppi',
      one: '$n gruppo',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Paesi';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n paesi',
      one: '$n paese',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Cartelle';

  @override
  String get featuredTitle => 'In evidenza oggi';

  @override
  String featuredPartyNow(String party) {
    return '$party è in corso proprio ora — i podi delle edizioni passate';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party inizia tra $days giorni — i podi delle edizioni passate',
      one: '$party inizia domani — i podi delle edizioni passate',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'È la stagione di $series — i podi delle edizioni passate';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Uscito nel $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age anni fa: i giochi del $year',
      one: 'Un anno fa: i giochi del $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Gli anni $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age anni fa: i giochi del $year',
      one: 'Un anno fa: i giochi del $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Usciti a $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Anniversari';

  @override
  String get featuredBirthdayHeader => 'Compleanni di oggi';

  @override
  String get featuredBirthdayWeekHeader => 'Compleanni della settimana';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return 'Compleanno di $artist questa settimana';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlist',
      one: '$count playlist',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonOptions => 'Opzioni';

  @override
  String get commonDownload => 'Scarica';

  @override
  String get commonDeleteDownload => 'Elimina il download';

  @override
  String get commonAddToPlaylist => 'Aggiungi alla playlist';

  @override
  String get commonPlayNext => 'Riproduci successivo';

  @override
  String get commonAddToQueueEnd => 'Aggiungi alla fine della coda';

  @override
  String get commonAddToFavorites => 'Aggiungi ai preferiti';

  @override
  String get commonRemoveFromFavorites => 'Rimuovi dai preferiti';

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
  String get subsongDeleteDownloadTitle => 'Eliminare questo download?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Il file e le sue voci locali (cronologia, tracce) verranno eliminati.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Impossibile leggere le tracce';

  @override
  String subsongTrackNumber(int number) {
    return 'Traccia $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subsong',
      one: '$count subsong',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Riproduci tutto';

  @override
  String get albumDownloading => 'Download dell\'album in corso…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Download dell\'album in corso… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Scarica l\'album per vederne le tracce';

  @override
  String get albumNotDownloadedHint =>
      'Album non scaricato — avvia la riproduzione per scaricarlo';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani',
      one: '$count brano',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Caricamento dei dettagli…';

  @override
  String albumAka(String label) {
    return 'alias $label';
  }

  @override
  String get albumPlayAlbum => 'Riproduci l\'album';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementi',
      one: '$count elemento',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Riproduci prima questo brano dalla ricerca per scaricarlo';

  @override
  String get libraryAddedTrack => 'Brano aggiunto alla libreria';

  @override
  String get libraryAddedAlbum => 'Album aggiunto alla libreria';

  @override
  String get libraryAddedArtist => 'Artista aggiunto alla libreria';

  @override
  String get libraryRemovedTrack => 'Brano rimosso dalla libreria';

  @override
  String get libraryRemovedAlbum => 'Album rimosso dalla libreria';

  @override
  String get libraryRemovedArtist => 'Artista rimosso dalla libreria';

  @override
  String songTilePlayFailed(String message) {
    return 'Riproduzione non riuscita: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Download non riuscito — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Download — $label';
  }

  @override
  String get downloadsTitle => 'Download';

  @override
  String get downloadsEmpty => 'Nessun download in attesa';

  @override
  String get downloadsPause => 'Metti in pausa';

  @override
  String get downloadsResume => 'Riprendi';

  @override
  String get downloadsCancel => 'Annulla il download';

  @override
  String get downloadsClear => 'Rimuovi tutto';

  @override
  String get downloadsPausedBanner =>
      'Download in pausa — il file corrente viene completato';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Download — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Playlist';

  @override
  String get miniPlayerHideQueue => 'Nascondi la playlist';

  @override
  String get transportShuffle => 'Riproduzione casuale';

  @override
  String get transportShuffleOn => 'Riproduzione casuale attiva';

  @override
  String get transportLoopOff => 'Ripetizione disattivata';

  @override
  String get transportLoopQueue => 'Ripeti: coda';

  @override
  String get transportLoopTrack => 'Ripeti: brano corrente';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spettro';

  @override
  String get vizVoices => 'Voci';

  @override
  String get vizNotes => 'Note';

  @override
  String get vizPatterns => 'Pattern';

  @override
  String get patternScrollMode => 'Modalità scorrimento';

  @override
  String get patternSmoothScroll => 'Scorrimento fluido';

  @override
  String get patternVolumeBars => 'Barre del volume';

  @override
  String get patternColorScheme => 'Schema colori';

  @override
  String get patternSize => 'Dimensione';

  @override
  String get patternColumns => 'Colonne';

  @override
  String get patternColumnsAll => 'Completo';

  @override
  String get patternColumnsNoteInstr => 'Ridotto';

  @override
  String get patternColumnsNote => 'Minimo';

  @override
  String get vizClose => 'Chiudi il visualizzatore';

  @override
  String get vizFullscreen => 'Schermo intero';

  @override
  String get vizExitFullscreen => 'Esci da schermo intero';

  @override
  String get vizPrevPreset => 'Preset precedente';

  @override
  String get vizNextPreset => 'Preset successivo';

  @override
  String get vizProjectmUnavailable => 'projectM non disponibile';

  @override
  String get voicesTitle => 'Voci';

  @override
  String get voicesNone => 'Nessuna voce per questo brano.';

  @override
  String get voicesLongPressSolo => 'pressione prolungata = solo';

  @override
  String get voicesMuteAll => 'Disattiva tutto';

  @override
  String get voicesUnmuteAll => 'Riattiva tutto';

  @override
  String get voicesStereoOutput => 'Uscita stereo';

  @override
  String get voicesLeft => 'Sinistra';

  @override
  String get voicesRight => 'Destra';

  @override
  String get enginesFormatsTitle => 'Formati riproducibili';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats formati riproducibili, distribuiti su $engines motori di riproduzione.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formati',
      one: '1 formato',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Riprende $title di $artist';
  }

  @override
  String stilCover(String work) {
    return 'Riprende $work';
  }

  @override
  String get playerQueue => 'Coda';

  @override
  String get queueEdit => 'Modifica';

  @override
  String get queueEditDone => 'Fine';

  @override
  String get queueClear => 'Svuota la coda';

  @override
  String get queueClearConfirmTitle => 'Svuotare la coda?';

  @override
  String get queueClearConfirmBody =>
      'La coda verrà svuotata e la riproduzione si fermerà.';

  @override
  String get queueClearConfirm => 'Svuota';

  @override
  String get queueRemoveSelected => 'Rimuovi selezione';

  @override
  String get queueRemoveTrack => 'Rimuovi dalla coda';

  @override
  String get queueReorder => 'Riordina';

  @override
  String get playerArtwork => 'Artwork';

  @override
  String get playerVisualizer => 'Visualizzatore';

  @override
  String get playerVoices => 'Voci';

  @override
  String get playerTrackInfo => 'Info del brano';

  @override
  String get playerShowQueue => 'Playlist';

  @override
  String get playerHideQueue => 'Nascondi la playlist';

  @override
  String get playerNoTrackInfo => 'Nessuna informazione disponibile.';

  @override
  String get playerViewSubsongs => 'Vedi i subsong';

  @override
  String get playerViewAlbum => 'Vedi l\'album';

  @override
  String get playerViewArtist => 'Vedi l\'artista';

  @override
  String get playerAddToPlaylist => 'Aggiungi alla playlist';

  @override
  String get queueAddToPlaylist => 'Aggiungi la coda a una playlist';

  @override
  String get playerMoreOptions => 'Altre opzioni';

  @override
  String get playerClose => 'Chiudi';

  @override
  String get playerCancel => 'Annulla';

  @override
  String get playerDelete => 'Elimina';

  @override
  String get playerAddFavorite => 'Aggiungi ai preferiti';

  @override
  String get playerRemoveFavorite => 'Rimuovi dai preferiti';

  @override
  String get playerAddToLibrary => 'Aggiungi alla libreria';

  @override
  String get playerRemoveFromLibrary => 'Rimuovi dalla libreria';

  @override
  String get playerAddedToLibrary => 'Brano aggiunto alla libreria';

  @override
  String get playerRemovedFromLibrary => 'Brano rimosso dalla libreria';

  @override
  String get playerDeleteDownload => 'Elimina il download';

  @override
  String get playerRedownload => 'Riscarica il file';

  @override
  String get playerRedownloadUnavailable =>
      'Riscaricamento non disponibile per questo file';

  @override
  String get playerDeleteDownloadTitle => 'Eliminare il download?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Il file e le sue voci locali (cronologia, tracce) verranno eliminati.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Le tue tendenze';

  @override
  String get homeYourAllTimeTop => 'La tua top di sempre';

  @override
  String get homeTrending => 'Tendenze';

  @override
  String get homeFeaturedPlaylists => 'Playlist in evidenza';

  @override
  String get homeAllTimeTop => 'Top di sempre';

  @override
  String get homePeriod7d => '7 gg';

  @override
  String get homePeriod30d => '30 gg';

  @override
  String get homePeriod90d => '90 gg';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ascolti',
      one: '$n ascolto',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Playlist vuota o illeggibile';

  @override
  String get homeExtractingArchive => 'Estrazione dell’archivio…';

  @override
  String get homeArchiveEmpty => 'Nessun file riproducibile nell’archivio';

  @override
  String get homeNothingPlayable => 'Niente di riproducibile nella selezione';

  @override
  String get homeAlbumLoadFailed => 'Impossibile caricare questo album';

  @override
  String get homeSongLoadFailed => 'Impossibile caricare questo brano';

  @override
  String get navStats => 'Statistiche';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get playlistMoveUp => 'Sposta nella cartella superiore';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n playlist',
      one: '$n playlist',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sottocartelle',
      one: '$n sottocartella',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Questa cartella e tutto il suo contenuto verranno eliminati definitivamente:';

  @override
  String get playlistDeleteFolderEmptyBody =>
      'Questa cartella verrà eliminata.';

  @override
  String get playlistFolderRoot => 'Radice';

  @override
  String get playlistMoveToFolder => 'Sposta in una cartella';

  @override
  String playlistDeleteTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get playlistDeleteBody =>
      'Questa playlist verrà eliminata definitivamente.';

  @override
  String get playlistRenameFolderTitle => 'Rinomina cartella';

  @override
  String get playlistClearFavorites => 'Elimina tutti i preferiti';

  @override
  String get playlistClearFavoritesTitle => 'Eliminare tutti i preferiti?';

  @override
  String get playlistClearFavoritesBody =>
      'Perderai tutti i tuoi brani preferiti. Operazione irreversibile.';

  @override
  String get playlistRemoveFromLibrary => 'Rimuovi dalla libreria';

  @override
  String get playlistServerReadOnly => 'Playlist del server · sola lettura';

  @override
  String get navAbout => 'Informazioni';

  @override
  String get navMore => 'Altro';

  @override
  String get shellAlbumQueuedAtEnd => 'Album aggiunto alla fine della coda';

  @override
  String get shellAlbumQueuedNext => 'L\'album verrà riprodotto subito dopo';

  @override
  String get shellAddingToQueue => 'Aggiunta alla coda…';

  @override
  String get shellAddingNext => 'Aggiunta come successivo…';

  @override
  String shellDownloadFailed(String error) {
    return 'Download non riuscito: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brani aggiunti alla coda',
      one: '$count brano aggiunto alla coda',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" aggiunto alla fine della coda';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" verrà riprodotto subito dopo';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Download non riuscito: $title — passo al brano successivo';
  }

  @override
  String get shellNetworkUnavailable =>
      'Riproduzione interrotta: la rete sembra non disponibile.';

  @override
  String get statsTitle => 'Statistiche';

  @override
  String statsPeriodDays(int n) {
    return '$n giorni';
  }

  @override
  String get statsPeriodThisYear => 'Quest\'anno';

  @override
  String get statsPeriodAll => 'Tutto';

  @override
  String get statsByMonthOrYear => 'Per mese / anno…';

  @override
  String get statsByYear => 'Per anno';

  @override
  String get statsByMonth => 'Per mese';

  @override
  String get statsPlaysLabel => 'Ascolti';

  @override
  String get statsTracksLabel => 'Brani';

  @override
  String get statsArtistsLabel => 'Artisti';

  @override
  String get statsAlbumsLabel => 'Album';

  @override
  String get statsListenTime => 'Tempo di ascolto';

  @override
  String get statsByCollection => 'Per collezione';

  @override
  String get statsByFormat => 'Per formato';

  @override
  String get statsByEngine => 'Per motore';

  @override
  String get statsPlaylistsLabel => 'Playlist';

  @override
  String get statsLocalFilesSection => 'File scaricati';

  @override
  String get statsFilesLabel => 'File';

  @override
  String get statsSpaceLabel => 'Spazio su disco';

  @override
  String get statsNoPlaysInPeriod => 'Nessun ascolto in questo periodo';

  @override
  String get statsNoPlays => 'Nessun ascolto';

  @override
  String get statsTopTracks => 'Top brani';

  @override
  String get statsTopAlbums => 'Top album';

  @override
  String get statsTopArtists => 'Top artisti';

  @override
  String statsTopTracksIn(String period) {
    return 'Top brani — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top album — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top artisti — $period';
  }

  @override
  String get statsSeeAll => 'Vedi tutto';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ascolti',
      one: '$n ascolto',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max $n';
  }

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonCreate => 'Crea';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonRename => 'Rinomina';

  @override
  String get commonSort => 'Ordina';

  @override
  String get commonPlayAll => 'Riproduci tutto';

  @override
  String get sortName => 'Nome';

  @override
  String get sortTitle => 'Titolo';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Data di aggiunta';

  @override
  String get commonClear => 'Cancella';

  @override
  String get sortRecentlyModified => 'Modificate di recente';

  @override
  String get sortCreationDate => 'Data di creazione';

  @override
  String get playlistNameHint => 'Nome';

  @override
  String get playlistNew => 'Nuova playlist';

  @override
  String get playlistNewFolder => 'Nuova cartella';

  @override
  String get playlistNewTooltip => 'Nuova playlist / cartella';

  @override
  String get playlistAddTo => 'Aggiungi alla playlist';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Aggiungi a $n playlist',
      one: 'Aggiungi a $n playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Seleziona una playlist';

  @override
  String get playlistFilterHint => 'Filtra le playlist…';

  @override
  String get playlistSearchHint => 'Cerca una playlist…';

  @override
  String get playlistNoMatch => 'Nessuna playlist corrispondente';

  @override
  String get playlistNoneCreateHint => 'Nessuna playlist — creane una con +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
      zero: 'Nessun brano',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Già presenti';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementi sono già presenti nelle playlist selezionate.',
      one: '$n elemento è già presente nelle playlist selezionate.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Ignora i duplicati';

  @override
  String get playlistAddAgain => 'Aggiungi di nuovo';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani aggiunti',
      one: '$n brano aggiunto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m playlist',
      one: '$n playlist',
    );
    return '$_temp0 a $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Impossibile aggiungere: $error';
  }

  @override
  String get playlistRenameTitle => 'Rinomina la playlist';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Eliminare la cartella “$name”?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'Il suo contenuto risale di un livello.';

  @override
  String get playlistEmpty => 'Playlist vuota';

  @override
  String get playlistRemoveEntry => 'Rimuovi dalla playlist';

  @override
  String get trackOptionsAddToLibrary => 'Aggiungi alla libreria';

  @override
  String get trackOptionsRemoveFromLibrary => 'Rimuovi dalla libreria';

  @override
  String get trackOptionsAddedToLibrary => 'Brano aggiunto alla libreria';

  @override
  String get trackOptionsRemovedFromLibrary => 'Brano rimosso dalla libreria';

  @override
  String get trackOptionsViewAlbum => 'Vedi l\'album';

  @override
  String get trackOptionsViewArtist => 'Vedi l\'artista';

  @override
  String get trackOptionsPlayNow => 'Riproduci ora';

  @override
  String get trackOptionsPlayNext => 'Riproduci successivo';

  @override
  String get trackOptionsAddToQueueEnd => 'Aggiungi alla fine della coda';

  @override
  String get trackOptionsPlayLast => 'Riproduci per ultimo';

  @override
  String get trackOptionsDeleteDownload => 'Elimina il download';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Eliminare questo download?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Il file e le sue voci locali (cronologia, tracce) verranno eliminati.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Download eliminato';

  @override
  String get trackOptionsAddToFavorites => 'Aggiungi ai preferiti';

  @override
  String get trackOptionsRemoveFromFavorites => 'Rimuovi dai preferiti';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Album aggiunto ai preferiti';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album rimosso dai preferiti';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album non scaricato — niente da eliminare';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Eliminare l\'album scaricato?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'La cartella e tutte le sue voci locali (tracce, cronologia) verranno eliminate.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Album eliminato dalla memoria locale';

  @override
  String get trackOptionsRedownloadAlbum => 'Riscarica l\'album';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Riscrive i file E le voci locali';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Elimina i file dell\'album';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Cartella scaricata + voci locali (cronologia)';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsGeneral => 'Generali';

  @override
  String get settingsGeneralSubtitle => 'Tema';

  @override
  String get settingsVisualisation => 'Visualizzazione';

  @override
  String get settingsVisualisationSubtitle => 'Oscilloscopi, artwork di sfondo';

  @override
  String get settingsPlayback => 'Riproduzione';

  @override
  String get settingsPlaybackSubtitle => 'Ripetizioni, dissolvenza, silenzio';

  @override
  String get settingsEngines => 'Motori';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Dati';

  @override
  String get settingsDataSubtitle => 'Identificativo, cronologia, ripristino';

  @override
  String get settingsBackupExport => 'Esporta un backup';

  @override
  String get settingsBackupExportSubtitle =>
      'Salva la tua libreria, le playlist e le impostazioni in un file';

  @override
  String get settingsBackupImport => 'Importa un backup';

  @override
  String get settingsBackupImportSubtitle =>
      'Ripristina i tuoi dati da un file di backup';

  @override
  String get settingsBackupExportFailed =>
      'Esportazione del backup non riuscita';

  @override
  String get settingsBackupImportConfirmTitle => 'Importare il backup?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Questo sostituisce la libreria, le playlist e le impostazioni su questo dispositivo. I file scaricati vengono mantenuti.';

  @override
  String get settingsBackupImportConfirm => 'Importa';

  @override
  String get settingsBackupImportedTitle => 'Backup importato';

  @override
  String get settingsBackupImportedBody =>
      'I tuoi dati sono stati ripristinati. Riavvia l’app per applicare tutto.';

  @override
  String get settingsBackupTooNew =>
      'Questo backup è stato creato da una versione più recente dell’app';

  @override
  String get settingsBackupInvalid => 'Backup Rewamp non valido';

  @override
  String get settingsBackupImportFailed =>
      'Importazione del backup non riuscita';

  @override
  String get settingsAbout => 'Informazioni';

  @override
  String get settingsAboutSubtitle => 'Crediti e licenze';

  @override
  String get settingsCreditsSubtitle => 'Librerie, dati e componenti';

  @override
  String get settingsSupport => 'Contatti e supporto';

  @override
  String get settingsSupportSubtitle => 'Contattaci, sito web';

  @override
  String get settingsSupportEmail => 'Invia un\'email';

  @override
  String get settingsSupportEmailSubtitle => 'Domanda, bug o suggerimento';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — supporto';

  @override
  String get settingsSupportEmailIntro =>
      'Descrivi sopra la tua domanda, il bug o il suggerimento. Le informazioni qui sotto ci aiutano ad aiutarti.';

  @override
  String get settingsSupportWebsite => 'Sito web';

  @override
  String get settingsDonation => 'Sostieni Rewamp';

  @override
  String get settingsDonationSubtitle => 'Una mancia, se ti va';

  @override
  String get settingsDonationBlurb =>
      'Rewamp è gratuito e senza pubblicità — un lavoro fatto con passione dedicato alla conservazione della cultura demoscene e retro. Le donazioni aiutano a finanziare lo sviluppo dell\'app e a coprire i costi di hosting del database. Nessun obbligo: se l\'app ti piace, un piccolo gesto è sempre gradito.';

  @override
  String get settingsDonationFloppy => 'Un floppy disk';

  @override
  String get settingsDonationCartridge => 'Una cartuccia';

  @override
  String get settingsDonationBox => 'Un gioco in scatola';

  @override
  String get settingsDonationCustom => 'Scegli un importo';

  @override
  String get settingsCancel => 'Annulla';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Elimina';

  @override
  String get settingsReset => 'Ripristina';

  @override
  String get settingsRenew => 'Rinnova';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Infinito';

  @override
  String get settingsDefault => 'Predefinito';

  @override
  String get settingsCoreNoScope => 'senza oscilloscopio';

  @override
  String get settingsNone => 'Nessuno';

  @override
  String get settingsLevelLow => 'Basso';

  @override
  String get settingsLevelHigh => 'Alto';

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
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeLight => 'Chiaro';

  @override
  String get settingsThemeDark => 'Scuro';

  @override
  String get settingsArtworkTintTitle => 'Colora il player con l\'artwork';

  @override
  String get settingsArtworkTintSubtitle =>
      'Il player riprende il colore dominante della copertina';

  @override
  String get settingsGlassEffectTitle => 'Effetto liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lente e sfocatura sulle barre inferiori — da disattivare sui dispositivi lenti';

  @override
  String get settingsResetSection => 'Ripristina questa sezione';

  @override
  String get settingsResetEngine => 'Ripristina questo motore';

  @override
  String get settingsResetChoices => 'Ripristina queste scelte';

  @override
  String get settingsResetToDefault => 'Valore predefinito';

  @override
  String get settingsStartInVizTitle => 'Avvia in modalità visualizzatore';

  @override
  String get settingsStartInVizSubtitle =>
      'Il player si apre sugli oscilloscopi anziché sull\'artwork';

  @override
  String get settingsVoiceGridTitle => 'Griglia dell\'oscilloscopio voci';

  @override
  String get settingsVoiceGridSubtitle =>
      'Mostra i bordi che separano ogni voce';

  @override
  String get settingsKeepAwakeTitle => 'Mantieni lo schermo acceso';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Mentre un visualizzatore è attivo, lo schermo non si oscura né si blocca';

  @override
  String get settingsVoiceNamesTitle => 'Nomi delle voci';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Mostra il nome di ogni voce nel suo riquadro';

  @override
  String get settingsLineThickness => 'Spessore del tratto';

  @override
  String get settingsColors => 'Colori';

  @override
  String get settingsScopeVoiceColor => 'Oscilloscopio voci';

  @override
  String get settingsStereoColors => 'Stereo: colori';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo sinistro';

  @override
  String get settingsStereoRightColor => 'Stereo destro';

  @override
  String get settingsNotation => 'Notazione (note)';

  @override
  String get settingsNotePalette => 'Palette di colori';

  @override
  String get settingsNoteBoxStyle => 'Stile dei blocchi';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'Effetti CRT';

  @override
  String get settingsCrtGlow => 'Alone (glow)';

  @override
  String get settingsCrtSpeed => 'Intensità / velocità';

  @override
  String get settingsArtworkOpacity => 'Opacità dell\'artwork di sfondo';

  @override
  String get settingsProjectMTitle => 'Impostazioni projectM';

  @override
  String get settingsProjectMSubtitle => 'Preset, transizioni, qualità, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Notifiche al cambio di traccia';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Notifica di sistema con il titolo della nuova traccia';

  @override
  String get settingsSilenceDetection => 'Rilevamento del silenzio';

  @override
  String get settingsSilenceSkipTitle =>
      'Passa al brano successivo se c\'è silenzio';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Avanza automaticamente quando l\'uscita resta silenziosa';

  @override
  String get settingsSilenceDelay => 'Ritardo di silenzio';

  @override
  String get settingsDefaultDuration => 'Durata predefinita';

  @override
  String get settingsDefaultDurationHelp =>
      'Usata quando un brano non fornisce alcuna durata nota (nessun tag, nessun metadato dal server) — evita che suoni o si ripeta all\'infinito. Non si applica mai ai brani Amiga (UADE), che hanno il proprio database di durate.';

  @override
  String get settingsForcedLoopHeader => 'Ripetizione / dissolvenza forzate';

  @override
  String get settingsForcedLoopHelp =>
      'Alcuni formati ripetono una sezione precisa (VGM, moduli tracker…); altri no. \"Infinito\" ignora la fine naturale del brano.';

  @override
  String get settingsForceLoopCount => 'Forza il numero di ripetizioni';

  @override
  String get settingsLoopCount => 'Numero di ripetizioni';

  @override
  String get settingsForceFadeout => 'Forza una dissolvenza in uscita';

  @override
  String get settingsFadeoutDuration => 'Durata della dissolvenza';

  @override
  String get settingsResetEnginesTitle =>
      'Ripristinare le impostazioni dei motori?';

  @override
  String get settingsResetEnginesBody =>
      'Tutte le impostazioni dei motori torneranno ai valori predefiniti.';

  @override
  String get settingsResetDefaultsTitle => 'Ripristina i valori predefiniti';

  @override
  String get settingsResetDefaultsSubtitle => 'Tutti i motori';

  @override
  String get settingsDefaultDecoders => 'Decoder predefiniti';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formati riproducibili da più motori';

  @override
  String get settingsDecodersHelp =>
      'Alcuni formati possono essere riprodotti da più motori. Scegli quale usare come predefinito — tutti gli altri formati vengono instradati automaticamente.';

  @override
  String get settingsDecoderAmigaTrackers => 'Tracker Amiga (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Tracker — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — qualità, filtri, opzioni per chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — filtro passa-alto';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont in uso';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolazione, passa-basso, eco';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panoramica, cuffie, guadagno, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — clock, modello, filtri ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — modalità armonica stereo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, riverbero';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — core YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Volume principale';

  @override
  String get settingsAmigaFilter => 'Filtro Amiga';

  @override
  String get settingsInterpolation => 'Interpolazione';

  @override
  String get settingsPolyphony => 'Polifonia';

  @override
  String get settingsReverb => 'Riverbero';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Nessuna';

  @override
  String get settingsInterpLinear => 'Lineare';

  @override
  String get settingsInterpCubic => 'Cubica';

  @override
  String get settingsInterpSinc => 'Sinc (migliore)';

  @override
  String get settingsStereoSeparation => 'Separazione stereo';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Termina il brano quando il motore rileva un lungo silenzio';

  @override
  String get settingsStereoDepth => 'Profondità stereo';

  @override
  String get settingsEqualizer => 'Equalizzatore';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — nessun effetto su SPC';

  @override
  String get settingsBass => 'Bassi';

  @override
  String get settingsTreble => 'Alti';

  @override
  String get settingsAppliedLive =>
      'Applicato immediatamente, anche durante la riproduzione.';

  @override
  String get settingsAppliedNextTrack =>
      'Applicato al prossimo brano caricato.';

  @override
  String get settingsSidEmulation => 'Emulazione';

  @override
  String get settingsSidResidfp => 'ReSIDfp (preciso)';

  @override
  String get settingsSidLite => 'SIDLite (veloce)';

  @override
  String get settingsSidSampling => 'Campionamento';

  @override
  String get settingsSidSamplingInterp => 'Interpolazione (veloce)';

  @override
  String get settingsSidSamplingResample => 'Resample (migliore)';

  @override
  String get settingsSidClock => 'Clock';

  @override
  String get settingsSidModel => 'Modello SID';

  @override
  String get settingsSidFilter => 'Filtro SID';

  @override
  String get settingsSidForceSecond => 'Forza un 2° SID';

  @override
  String get settingsSidSecondSubtitle => 'Brani 2SID stereo';

  @override
  String get settingsSidSecondAddr => 'Indirizzo del 2° SID';

  @override
  String get settingsSidForceThird => 'Forza un 3° SID';

  @override
  String get settingsSidThirdAddr => 'Indirizzo del 3° SID';

  @override
  String get settingsSidAutoFilter => 'Intervallo filtro 6581 automatico';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Valore consigliato in base all\'autore del brano (tabelle sidplayfp)';

  @override
  String get settingsSid6581Range => 'Intervallo filtro 6581';

  @override
  String get settingsSid6581Curve => 'Curva filtro 6581';

  @override
  String get settingsSid8580Curve => 'Curva filtro 8580';

  @override
  String get settingsSidNote =>
      'Filtro SID e curve sono applicati in tempo reale; emulazione/campionamento/clock/modello/2°-3° SID hanno effetto dal brano successivo.';

  @override
  String get settingsAudioOutput => 'Uscita audio';

  @override
  String get settingsAdplugNote =>
      'Surround: due chip OPL leggermente scordati tra loro. Applicato al brano successivo.';

  @override
  String get settingsHeSpuMain => 'Voci principali (SPU)';

  @override
  String get settingsHeSpuReverb => 'Riverbero (SPU)';

  @override
  String get settingsNsfQuality => 'Qualità (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Filtro passa-basso';

  @override
  String get settingsHighpassFilter => 'Filtro passa-alto';

  @override
  String get settingsRegion => 'Regione';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC forzato';

  @override
  String get settingsNsfRegionPalForced => 'PAL forzato';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy forzato';

  @override
  String get settingsNsfForceIrq => 'Forza IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulses (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — triangle / noise / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Riattiva l\'audio al reset';

  @override
  String get settingsNsfPhaseRefresh => 'Aggiorna la fase';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Reimposta la fase quando viene scritto il periodo';

  @override
  String get settingsNsfNonlinearMixer => 'Missaggio non lineare';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'Il vero mix del 2A03 (altrimenti lineare)';

  @override
  String get settingsNsfDutySwap => 'Scambia i duty cycle';

  @override
  String get settingsNsfDutySwapSubtitle => 'Ordine dei duty 25% / 50%';

  @override
  String get settingsNsfNegateSweep => 'Sweep negativo all\'init';

  @override
  String get settingsNsfEnable4011 => 'Registro \$4011 attivo';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Uscita DAC diretta (click originali)';

  @override
  String get settingsNsfPeriodicNoise => 'Rumore periodico';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Modalità corta del generatore di rumore';

  @override
  String get settingsNsfDpcmAntiClick => 'Anti-click DPCM';

  @override
  String get settingsNsfRandomizeNoise => 'Rumore casuale all\'init';

  @override
  String get settingsNsfTriangleMute => 'Disattiva il triangle';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Silenzia il triangle ai periodi ultrasonici';

  @override
  String get settingsNsfRandomizeTri => 'Triangle casuale all\'init';

  @override
  String get settingsNsfDpcmReverse => 'DPCM invertito';

  @override
  String get settingsNsfN163Serial => 'Multiplexing seriale';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Il vero ronzio dell\'N163 sui brani multi-voce';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fase in sola lettura';

  @override
  String get settingsNsfN163LimitWavelength => 'Limita la lunghezza d\'onda';

  @override
  String get settingsNsfFdsCutoff => 'Taglio passa-basso';

  @override
  String get settingsNsfFds4085Reset => 'Reset \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Protezione da scrittura';

  @override
  String get settingsNsfVrc7Patch => 'Set di patch';

  @override
  String get settingsNsfVrc7Opll => 'Modalità OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Emula un YM2413 anziché il VRC7';

  @override
  String get settingsGbsHpFilter => 'Filtro passa-alto (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (GB classico)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Eco';

  @override
  String get settingsUadePostfx => 'Post-elaborazione';

  @override
  String get settingsUadePostfxSubtitle =>
      'Attiva la catena di effetti (necessaria per tutto il resto)';

  @override
  String get settingsUadePan => 'Panoramica (separazione stereo)';

  @override
  String get settingsUadePanValue => 'Valore della panoramica';

  @override
  String get settingsUadeHeadphones => 'Cuffie';

  @override
  String get settingsUadeLed => 'LED (filtro Paula)';

  @override
  String get settingsUadeLedAuto => 'Auto (per brano)';

  @override
  String get settingsUadeLedOn => 'Forzato ON';

  @override
  String get settingsUadeLedOff => 'Forzato OFF';

  @override
  String get settingsUadeFilterType => 'Tipo di filtro';

  @override
  String get settingsUadeGain => 'Guadagno';

  @override
  String get settingsUadeGainValue => 'Valore del guadagno';

  @override
  String get settingsSoundfontLoading => 'Caricamento del catalogo…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Catalogo non disponibile ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Download non riuscito: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importa una SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Scegli un file .sf2 su questo dispositivo';

  @override
  String get settingsSoundfontImported => 'Importata';

  @override
  String get settingsSoundfontInvalid =>
      'Questo file non è una SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Importazione non riuscita — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Elimina il file';

  @override
  String get settingsCreditsHeader => 'Crediti e licenze';

  @override
  String get settingsRightsNotice =>
      'Rewamp è un lettore: non ospita alcun file e non distribuisce musica. I brani provengono da archivi di preservazione online e restano di proprietà dei rispettivi titolari dei diritti. Spetta a te verificare che ascoltarli, scaricarli e conservarli sia conforme ai diritti applicabili e alla legge del tuo paese.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formati supportati',
      one: '$count formato supportato',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Distribuiti su $count motori di riproduzione — vedi i dettagli',
      one: 'Gestiti da $count motore di riproduzione — vedi i dettagli',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Durate e metadati Amiga';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb di Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Dati e copertine C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadati e immagini dei giochi C64.';

  @override
  String get settingsFt2FontTitle => 'Font FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'Lo stile FastTracker II del visualizzatore di pattern usa il font FT2 di ft2-clone di 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url copiato';
  }

  @override
  String get settingsOpenLink => 'Apri il link';

  @override
  String get settingsEnginesHeader => 'Motori di riproduzione';

  @override
  String get settingsComponentsHeader => 'Altri componenti';

  @override
  String get settingsResetAll => 'Ripristina tutte le impostazioni';

  @override
  String get settingsResetAllSubtitle =>
      'Generali, Visualizzazione, Riproduzione, Motori — non la libreria';

  @override
  String get settingsResetAllTitle => 'Ripristinare tutte le impostazioni?';

  @override
  String get settingsResetAllBody =>
      'Generali, Visualizzazione, Riproduzione e tutti i motori torneranno ai valori predefiniti. La libreria e la cronologia non vengono toccate.';

  @override
  String get settingsRenewUserId => 'Rinnova l\'identificativo anonimo';

  @override
  String get settingsRenewUserIdTitle => 'Rinnovare l\'identificativo anonimo?';

  @override
  String get settingsRenewUserIdBody =>
      'Verrà creato un nuovo identificativo anonimo per le statistiche sul server.\n\nQuello precedente non verrà più usato. La cronologia locale e i preferiti non sono interessati.';

  @override
  String get settingsRenewUserIdFailed =>
      'Non riuscito — server irraggiungibile';

  @override
  String settingsNewUserId(String id) {
    return 'Nuovo identificativo: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Nessun identificativo registrato';

  @override
  String get settingsCleanDb => 'Pulisci il database locale';

  @override
  String get settingsCleanDbSubtitle =>
      'Rimuove le voci il cui file non esiste più (download eliminati, vecchi errori)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci orfane rimosse',
      one: '$count voce orfana rimossa',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'Database locale integro — niente da rimuovere';

  @override
  String get settingsClearCache => 'Svuota la cache (artwork e metadati)';

  @override
  String get settingsClearCacheSubtitle =>
      'Rimuove le copertine in cache e i metadati recuperati (STIL, durate) — riscaricati alla prossima riproduzione';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cache svuotata ($count copertine)',
      one: 'Cache svuotata ($count copertina)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Ripristina le statistiche';

  @override
  String get settingsResetStatsSubtitle =>
      'Rimuove la cronologia di ascolto e i contatori di riproduzione';

  @override
  String get settingsClearStatsTitle => 'Ripristinare le statistiche?';

  @override
  String get settingsClearStatsBody =>
      'Questa azione eliminerà definitivamente:\n• tutta la cronologia di ascolto\n• i contatori di riproduzione\n\nI preferiti e la libreria non vengono interessati.';

  @override
  String get settingsStatsCleared => 'Statistiche eliminate';

  @override
  String get settingsResetDatabase => 'Ripristina il database';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Elimina tutto: cronologia, preferiti, playlist, cache';

  @override
  String get settingsResetDbTitle => 'Ripristinare il database?';

  @override
  String get settingsResetDbBody =>
      'Questa azione eliminerà definitivamente:\n• tutta la cronologia di ascolto\n• tutti i contatori\n• tutti i preferiti\n• tutte le playlist\n• tutti i metadati in cache\n\nI file audio non vengono eliminati.';

  @override
  String get settingsDbReset => 'Database ripristinato';

  @override
  String get settingsDeleteDownloads => 'Elimina i download';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Elimina tutti i file della cartella online (brani, artwork)';

  @override
  String get settingsDeleteDownloadsTitle => 'Eliminare i download?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Questa azione eliminerà definitivamente tutti i file scaricati (brani, album, artwork) dalla cartella online.\n\nLe voci nel database rimarranno ma punteranno a file che non esistono più.';

  @override
  String get settingsDownloadsDeleted => 'Download eliminati';

  @override
  String get settingsColor => 'Colore';

  @override
  String get settingsPmPresets => 'Preset';

  @override
  String get settingsPmRandomNext => 'Preset successivo casuale';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Off: riproduce i preset in ordine';

  @override
  String get settingsPmLockPreset => 'Blocca il preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Nessun cambio automatico';

  @override
  String get settingsPmPresetDuration => 'Tempo tra i preset';

  @override
  String get settingsPmTransitions => 'Transizioni';

  @override
  String get settingsPmBlend => 'Transizione in dissolvenza';

  @override
  String get settingsPmBlendSubtitle => 'Off: cambio di preset istantaneo';

  @override
  String get settingsPmTransitionStyle => 'Stile di transizione';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Il motivo usato dalla dissolvenza';

  @override
  String get settingsPmTransitionRandom => 'Casuale';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Cambio di preset sincronizzato sui beat';

  @override
  String get settingsPmHardcutTime => 'Hardcut: tempo minimo';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: sensibilità';

  @override
  String get settingsPmRendering => 'Rendering';

  @override
  String get settingsPmQuality => 'Qualità';

  @override
  String get settingsPmQualitySubtitle =>
      'Risoluzione di rendering (Max = risoluzione nativa)';

  @override
  String get settingsPmBeatSensitivity => 'Sensibilità ai beat';

  @override
  String get settingsPmAspectRatio => 'Rispetta le proporzioni';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'Per gli shader che lo supportano';

  @override
  String get settingsPmPermissive => 'Modalità permissiva';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Carica i file .milk con errori di script';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountSubtitle => 'Salva e sincronizza la tua libreria';

  @override
  String get accountAnonymous => 'Account anonimo';

  @override
  String get accountAnonymousExplain =>
      'I tuoi preferiti e la cronologia sono salvati sul server, ma solo questo dispositivo può raggiungerli. Aggiungi un indirizzo e-mail per ritrovarli altrove.';

  @override
  String get accountEmailAttached =>
      'Indirizzo confermato — questo account può essere ripristinato';

  @override
  String get accountEmailPending => 'Indirizzo non ancora confermato';

  @override
  String get accountInsecureStorage =>
      'L\'archivio sicuro di questo dispositivo non è disponibile: l\'identificatore dell\'account è salvato in chiaro.';

  @override
  String get accountSaveCta => 'Salva il mio account';

  @override
  String get accountStatSongs => 'Brani preferiti';

  @override
  String get accountStatAlbums => 'Album preferiti';

  @override
  String get accountStatPlays => 'Ascolti';

  @override
  String get accountCreatedLabel => 'Creato';

  @override
  String get accountSignOut => 'Disconnetti';

  @override
  String get accountRevoke => 'Disconnetti ovunque';

  @override
  String get accountRevokeSubtitle => 'Disconnette tutti gli altri dispositivi';

  @override
  String get accountRevokeBody =>
      'Tutti gli altri dispositivi vengono disconnessi. Questo resta connesso.';

  @override
  String get accountRevokeDone => 'Altri dispositivi disconnessi';

  @override
  String get accountDelete => 'Elimina il mio account';

  @override
  String get accountDeleteSubtitle =>
      'Cancella l\'account e i suoi dati sul server. Irreversibile.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items preferiti e $lists playlist saranno eliminati dal server. L\'operazione è irreversibile.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'I tuoi download e la libreria di questo dispositivo non sono toccati.';

  @override
  String get accountDeleteDone => 'Account eliminato';

  @override
  String get accountSignOutSubtitle =>
      'Questo dispositivo riparte da un account nuovo e vuoto';

  @override
  String get accountSignOutTitle => 'Disconnettersi?';

  @override
  String accountSignOutBody(String email) {
    return 'Potrai tornare a questo account con un codice inviato a $email.';
  }

  @override
  String get accountSignedOut => 'Disconnesso';

  @override
  String get accountNoSignOut => 'Disconnessione non disponibile';

  @override
  String get accountNoSignOutSubtitle =>
      'Senza un indirizzo e-mail questo account andrebbe perso per sempre.';

  @override
  String get accountDetach => 'Scollega l\'indirizzo';

  @override
  String get accountDetachSubtitle =>
      'L\'account torna anonimo, nessun dato viene eliminato';

  @override
  String get accountDetachBody =>
      'Senza indirizzo, questo account non potrà più essere recuperato da un altro dispositivo.';

  @override
  String get accountDetachDone => 'Indirizzo scollegato';

  @override
  String get accountOffline => 'Account non disponibile offline';

  @override
  String get accountEmailTitle => 'Indirizzo e-mail';

  @override
  String get accountEmailExplain =>
      'Ti inviamo un codice di 6 cifre per confermare l\'indirizzo. Serve solo a recuperare il tuo account.';

  @override
  String get accountEmailLabel => 'Indirizzo e-mail';

  @override
  String get accountCodeTitle => 'Codice di conferma';

  @override
  String accountCodeExplain(String email) {
    return 'Codice inviato a $email. È valido per 10 minuti.';
  }

  @override
  String get accountCodeLabel => 'Codice di 6 cifre';

  @override
  String get accountSendCode => 'Invia il codice';

  @override
  String get accountVerify => 'Conferma';

  @override
  String get accountResend => 'Invia di nuovo il codice';

  @override
  String accountResendIn(int n) {
    return 'Nuovo invio tra $n s';
  }

  @override
  String get accountCheckSpam =>
      'L\'e-mail può metterci un minuto — controlla anche la posta indesiderata.';

  @override
  String get accountErrorInvalidEmail => 'Indirizzo non valido';

  @override
  String get accountErrorTooMany =>
      'Troppe richieste, riprova tra qualche minuto';

  @override
  String get accountErrorInvalidCode => 'Codice errato o scaduto';

  @override
  String get accountErrorCodeLength => 'Il codice ha 6 cifre';

  @override
  String get accountErrorNetwork => 'Connessione non riuscita, riprova';

  @override
  String get accountMergeTitle => 'Unire questa libreria?';

  @override
  String accountMergeBody(String email) {
    return 'I preferiti e la cronologia di questo dispositivo verranno aggiunti all\'account $email. L\'operazione è definitiva.';
  }

  @override
  String get accountMergeConfirm => 'Unisci';

  @override
  String get accountCarryLocal => 'Mantenere i preferiti di questo dispositivo';

  @override
  String accountCarryLocalOn(int n) {
    return 'I $n preferiti e le playlist di questo dispositivo vengono aggiunti all\'account.';
  }

  @override
  String get accountCarryLocalOff =>
      'Vengono eliminati da questo dispositivo e sostituiti da quelli dell\'account. I file scaricati restano.';

  @override
  String get accountDropLocalTitle => 'Eliminare i dati di questo dispositivo?';

  @override
  String get accountCreatedOk => 'Account salvato, la tua libreria è al sicuro';

  @override
  String get accountMergedOk =>
      'Connesso — i tuoi preferiti locali sono stati aggiunti';

  @override
  String get accountSignedInOk => 'Connesso';

  @override
  String get playlistEntryMissing => 'File assente da questo dispositivo';

  @override
  String get playlistEntryMissingRestorable =>
      'File assente — si può riscaricare';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n mancanti',
      one: '$n mancante',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Salva nel mio account';

  @override
  String get playlistBackupSubtitle =>
      'Conserva questa playlist anche dopo una reinstallazione';

  @override
  String get playlistBackupUpdate => 'Aggiorna la copia';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Sostituisce la copia dell\'account con questa versione';

  @override
  String get playlistBackupStop => 'Non salvare più';

  @override
  String get playlistBackupStopped => 'Copia rimossa';

  @override
  String get playlistBackupDone => 'Playlist salvata';

  @override
  String get playlistBackupFailed => 'Salvataggio non riuscito';

  @override
  String get playlistBackupNoAccount => 'Nessun account su questo dispositivo';

  @override
  String get playlistSyncTooltip => 'Sincronizza con il mio account';

  @override
  String get playlistSyncRunning => 'Sincronizzazione…';

  @override
  String get playlistSyncDone => 'Playlist sincronizzate';

  @override
  String get playlistSyncPartial => 'Alcune playlist non sono state salvate';

  @override
  String get playlistFetchMissing => 'Scarica i brani mancanti';

  @override
  String get playlistFetchDone => 'Brani mancanti scaricati';

  @override
  String get playlistFetchPartial => 'Alcuni brani non sono stati scaricati';

  @override
  String get playlistEntryFetchFailed => 'Impossibile scaricare questo brano';

  @override
  String get accountStatPlaylists => 'Playlist';

  @override
  String get accountSyncNow => 'Sincronizza ora';

  @override
  String get accountSyncAuto => 'Avviene da sola in background';

  @override
  String get accountSyncAnonymous =>
      'Salvato sul server. Aggiungi un\'email per sincronizzare un altro dispositivo.';

  @override
  String get accountSyncPending => 'Modifiche in attesa di invio';

  @override
  String accountSyncLast(String when) {
    return 'Ultima sincronizzazione: $when';
  }

  @override
  String get accountSyncDone => 'Sincronizzazione completata';

  @override
  String get accountSyncFailed =>
      'Sincronizzazione non riuscita, verrà ritentata';

  @override
  String get podiumFirst => '1º';

  @override
  String get podiumSecond => '2º';

  @override
  String get podiumThird => '3º';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'musica di $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'contiene il $place di $compo';
  }

  @override
  String get competitionEmpty => 'Questa competizione non ha voci';

  @override
  String get competitionEntryNoMusic =>
      'Nessuna musica in catalogo per questa voce';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n brani',
      one: '$n brano',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Salta';

  @override
  String get onboardingNext => 'Avanti';

  @override
  String get onboardingStart => 'Iniziamo';

  @override
  String get onboardingBetaTitle => 'Versione beta';

  @override
  String get onboardingBetaBody =>
      'Rewamp è ancora in costruzione. I dati locali — libreria, playlist, preferiti, statistiche — potrebbero essere azzerati prima della versione 1.0. I download non rischiano nulla, ma tieni altrove ciò a cui tieni.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Versione $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Esplora';

  @override
  String get onboardingExploreBody =>
      'Sfoglia e cerca decine di migliaia di chiptune e moduli dai grandi archivi online, per artista, album, piattaforma o party. Tocca per ascoltare, scarica per conservare.';

  @override
  String get onboardingLibraryTitle => 'La tua libreria';

  @override
  String get onboardingLibraryBody =>
      'Salva ciò che ti piace, crea playlist e organizzale in cartelle. Ciò che scarichi si ascolta offline e la libreria ti segue tra i dispositivi una volta effettuato l\'accesso.';

  @override
  String get onboardingPlayerTitle => 'Il player';

  @override
  String get onboardingPlayerBody =>
      'Scorri per cambiare brano e apri i visualizzatori: oscilloscopio, canali, note scorrevoli, griglia tracker. I file multi-traccia mostrano le sottotracce e ogni voce si può silenziare da sola.';

  @override
  String get onboardingReplayTitle => 'Presentazione';

  @override
  String get onboardingReplaySubtitle =>
      'Rivedi l\'avviso beta e il tour delle funzioni';

  @override
  String get settingsPatternTitle => 'Pattern';

  @override
  String get settingsPatternSubtitle =>
      'Griglia tracker: colori, colonne, scorrimento';

  @override
  String get patternOpaqueBg => 'Sfondo opaco';

  @override
  String get patternOpaqueBgSubtitle =>
      'Nasconde la copertina dietro la griglia';

  @override
  String get commonSave => 'Salva';

  @override
  String get accountDisplayName => 'Nome pubblico';

  @override
  String get accountDisplayNameNotSet =>
      'Non impostato — serve per pubblicare una playlist';

  @override
  String get accountDisplayNameHint =>
      'Il nome con cui vuoi essere accreditato.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Cambiarlo rimanda in revisione tutte le playlist che hai pubblicato.';

  @override
  String get accountDisplayNameTaken =>
      'Questo nome è già preso. Scegline un altro.';

  @override
  String get accountDisplayNameLength => 'Tra 2 e 40 caratteri.';

  @override
  String get accountDisplayNameSaved => 'Nome pubblico salvato';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlist rimandate in revisione: $n';
  }

  @override
  String get playlistPublish => 'Rendi pubblica';

  @override
  String get playlistPublishSubtitle =>
      'Chiedi la pubblicazione (previa revisione)';

  @override
  String get playlistPublishTitle => 'Pubblicare questa playlist?';

  @override
  String get playlistPublishBody =>
      'Sarà visibile a tutti una volta approvata, accreditata al tuo nome pubblico. La copertina viene dai suoi brani.';

  @override
  String get playlistPublishCta => 'Chiedi';

  @override
  String get playlistPublishSubmitted => 'Inviata in revisione';

  @override
  String get playlistPublishPending => 'In attesa di approvazione';

  @override
  String get playlistPublishApproved => 'Pubblica';

  @override
  String playlistPublishRejected(String reason) {
    return 'Rifiutata: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Rifiutata';

  @override
  String get playlistPublishNeedName =>
      'Scegli il nome con cui vuoi essere accreditato';

  @override
  String get playlistPublishNeedTracks =>
      'Servono almeno 5 brani per pubblicare';

  @override
  String get playlistPublishHasLocal =>
      'I file del tuo dispositivo non si possono pubblicare — gli altri non possono ascoltarli';

  @override
  String get playlistPublishTooManyPending =>
      'Hai già 3 playlist in attesa di approvazione';

  @override
  String get playlistPublishRefused =>
      'Pubblicazione rifiutata: controlla i brani e le richieste in sospeso';

  @override
  String get playlistPublishFailed => 'Pubblicazione non riuscita';

  @override
  String get playlistPublishWithdrawn => 'La playlist è di nuovo privata';

  @override
  String get playlistUnpublish => 'Rendi privata';

  @override
  String get playlistUnpublishSubtitle => 'La toglie dalle playlist pubbliche';

  @override
  String get playlistRenamePublishedTitle =>
      'Rinominare una playlist pubblicata?';

  @override
  String get playlistRenamePublishedBody =>
      'Ciò che viene revisionato è il nome: rinominarla la rimanda in revisione e nel frattempo la toglie dal pubblico. Aggiungere o riordinare brani, no.';

  @override
  String playlistByAuthor(String author) {
    return 'di $author';
  }

  @override
  String get settingsSpectrumMode => 'Modalità spettro';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Colorato';

  @override
  String get settingsSpectrumModeBeam => 'Fascio';

  @override
  String get settingsSpectrumModeLine => 'Linea';

  @override
  String get settingsSpectrumModeRing => 'Anello';

  @override
  String get releaseNotesTitle => 'Novità';

  @override
  String get releaseNotesV4Downloads =>
      'Download: uno lungo si può annullare mentre scorre, e l\'archivio di un album non viene più scaricato più volte.';

  @override
  String get releaseNotesV4Queue =>
      'Coda: un pulsante per svuotarla, con conferma — ferma anche la riproduzione.';

  @override
  String get releaseNotesV4DropFiles =>
      'File trascinati sulla finestra: scegliere riproduci ora, dopo o alla fine; copertine e file di corredo restano fuori, e la scaletta contenuta in un archivio viene rispettata (titoli veri, niente tracce morte).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: importa la tua SoundFont dal dispositivo, accanto a quelle del server.';

  @override
  String get releaseNotesV4Formats =>
      'I flussi di gioco Wwise, FSB e OGL finalmente suonano (Vorbis proprio).';

  @override
  String get releaseNotesV4Chips =>
      'Sei chip sonori in più, scelta del core di emulazione per chip (SameBoy per Game Boy) e intonazione corretta sui chip a campioni.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: i .vt2 suonano, e le viste note e pattern coprono tutta la famiglia ZX.';

  @override
  String get releaseNotesV4Loop =>
      'Ripeti brano ripete davvero invece di ricaricarlo, e il contatore non si blocca più in loop infinito.';

  @override
  String get releaseNotesV4Info =>
      'Il pannello ⓘ elenca i file che un brano ha davvero aperto — compagni e librerie compresi.';

  @override
  String get releaseNotesV4Linux => 'Versione Linux per desktop.';

  @override
  String get releaseNotesDataReset =>
      'I dati locali sono stati azzerati per questa beta. Libreria e playlist si ricostruiscono dall\'account; i download sono da rifare.';

  @override
  String get releaseNotesDismiss => 'Continua';

  @override
  String get pmManagePresets => 'Gestisci i preset';

  @override
  String get pmPickTooltip => 'Scegli un preset';

  @override
  String get pmPickFilter => 'Filtra i preset';

  @override
  String get pmSourceTooltip => 'Origine dei preset';

  @override
  String get pmAddToPlaylistTooltip => 'Aggiungi il preset a una playlist';

  @override
  String pmSlowPresetDropped(String name) {
    return '«$name» è troppo pesante per questo dispositivo ed è stato messo da parte.';
  }

  @override
  String get pmSlowDeviceTitle => 'Questo dispositivo è troppo lento';

  @override
  String get pmSlowDeviceOff =>
      'Il visualizzatore è stato disattivato: questo dispositivo non regge i preset Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preset messi da parte',
      one: '1 preset messo da parte',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Troppo lenti su questo dispositivo. La riproduzione li salta.';

  @override
  String get settingsPmSlowPresetsRestore => 'Ripristina';

  @override
  String get pmSourceBundled => 'Preset integrati';

  @override
  String get pmSourceImports => 'Le mie importazioni';

  @override
  String get pmSourceAll => 'Tutti i preset';

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
  String get pmNewPlaylist => 'Nuova playlist…';

  @override
  String get pmPlaylistName => 'Nome della playlist';

  @override
  String get pmAddedToPlaylist => 'Aggiunto alla playlist';

  @override
  String get pmAlreadyInPlaylist => 'Già in questa playlist';

  @override
  String get pmTabPacks => 'Pack';

  @override
  String get pmTabBrowse => 'Sfoglia';

  @override
  String get pmTabPlaylists => 'Playlist';

  @override
  String get pmTabPopular => 'Popolari';

  @override
  String get pmTabSetAside => 'Messi da parte';

  @override
  String get pmSetAsideEmpty =>
      'Niente da parte. Qui finiscono i preset che fanno scendere questo dispositivo sotto i 6 fps.';

  @override
  String get pmSetAsideRestoreAll => 'Ripristina tutto';

  @override
  String get pmInstall => 'Installa';

  @override
  String get pmInstallQueued => 'Installazione in coda';

  @override
  String get pmUninstall => 'Disinstalla';

  @override
  String get pmUninstalled => 'Pack rimosso';

  @override
  String get pmUse => 'Usa';

  @override
  String get pmDefaultPackBanner => 'Pack iniziale consigliato';

  @override
  String pmLicense(String license) {
    return 'Licenza: $license';
  }

  @override
  String get pmPacksOffline => 'Server non raggiungibile';

  @override
  String get pmSearchPresets => 'Cerca preset…';

  @override
  String get pmPlayNow => 'Riproduci ora';

  @override
  String get pmDownloadAction => 'Scarica';

  @override
  String get pmDownloaded => 'Preset scaricato';

  @override
  String get pmDownloadFailed => 'Download non riuscito';

  @override
  String pmPreviewing(String name) {
    return 'In riproduzione: $name';
  }

  @override
  String get pmLocalSection => 'Le mie playlist';

  @override
  String get pmCuratedSection => 'Playlist Rewamp';

  @override
  String get pmImportPlaylist => 'Scarica e usa';

  @override
  String get pmPlaylistImported => 'Playlist pronta';

  @override
  String get pmImportFiles => 'Importa file…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preset importati',
      one: '$count preset importato',
      zero: 'Nessun preset importato',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Preset aggiunti alla libreria projectM';

  @override
  String get pmNoPlaylists => 'Ancora nessuna playlist di preset';

  @override
  String get pmSourceApplied => 'Origine dei preset applicata';

  @override
  String get pmPlaylistEmpty => 'Questa playlist è vuota';

  @override
  String get pmDays7 => '7 giorni';

  @override
  String get pmDays30 => '30 giorni';

  @override
  String get pmDays365 => '1 anno';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count riproduzioni',
      one: '$count riproduzione',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Installazione non riuscita';

  @override
  String get pmSingleDownloads => 'Download singoli';

  @override
  String pmAvailableIn(String pack) {
    return 'Disponibile in $pack';
  }

  @override
  String get pmCleanUp => 'Pulisci';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preset eliminati',
      one: '$count preset eliminato',
      zero: 'Niente da pulire',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Blocca questo preset';

  @override
  String get pmUnlockAction => 'Sblocca il preset';

  @override
  String get pmOrderRandom => 'Preset casuali';

  @override
  String get pmOrderSequential => 'Preset in ordine';

  @override
  String get pmUpdateAvailable => 'Aggiornamento disponibile';

  @override
  String get pmUpdate => 'Aggiorna';

  @override
  String get pmSelectAll => 'Seleziona tutto';

  @override
  String get pmSelectNone => 'Deseleziona tutto';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionati',
      one: '$count selezionato',
      zero: 'Nessuna selezione',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Texture inutilizzate';

  @override
  String pmTexturesFreed(String size) {
    return '$size liberati';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texture',
      one: '$count texture',
    );
    return '$_temp0';
  }
}
