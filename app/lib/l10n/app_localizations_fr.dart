// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navHome => 'Accueil';

  @override
  String get navSearch => 'Recherche';

  @override
  String get navLocal => 'Local';

  @override
  String get settingsTabsOrderTitle => 'Ordre des onglets';

  @override
  String get settingsTabsOrderSubtitle =>
      'Glissez pour ranger. Les quatre premiers sont dans la barre du bas; les autres vivent sous « Plus ».';

  @override
  String get settingsTabsInBar => 'Dans la barre';

  @override
  String get settingsTabsInMore => 'Sous « Plus »';

  @override
  String get settingsLaunchTab => 'Onglet au lancement';

  @override
  String get settingsLaunchTabSubtitle => 'L’onglet sur lequel l’app s’ouvre';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get noFileSelected => 'Aucun fichier sélectionné';

  @override
  String get openFile => 'Ouvrir un fichier';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Format non supporté';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Format non supporté : $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Absent de cet appareil : $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Fichier absent du serveur : $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file n\'est pas dans l\'archive de l\'album — le rip l\'annonce sans le livrer.';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host n\'a pas répondu. Vérifiez votre connexion, puis réessayez.';
  }

  @override
  String get failedToLoadFile => 'Impossible de charger le fichier';

  @override
  String get libraryEmptyHint =>
      'Tes artistes, albums et playlists\napparaîtront ici.';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryArtists => 'Artistes';

  @override
  String get libraryAlbums => 'Albums';

  @override
  String get libraryTracks => 'Morceaux';

  @override
  String get libraryFavorites => 'Favoris';

  @override
  String get libraryFavoritesSubtitle =>
      'Playlist automatique de tes morceaux favoris';

  @override
  String get libraryRecentlyAdded => 'Ajouts récents';

  @override
  String get libraryEmpty => 'Rien ici pour l\'instant';

  @override
  String get libraryRemoved => 'Retiré de la bibliothèque';

  @override
  String get searchHint => 'Rechercher…';

  @override
  String get searchTypePlaceholder => 'Tapez un titre, artiste ou album…';

  @override
  String get searchNoResults => 'Aucun résultat';

  @override
  String get searchDownloading => 'Téléchargement…';

  @override
  String searchError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get tabAll => 'Morceaux';

  @override
  String get tabArtists => 'Artistes';

  @override
  String get tabAlbums => 'Albums';

  @override
  String get tabProductions => 'Productions';

  @override
  String get filterWithVideo => 'Avec vidéo';

  @override
  String get videoUnavailable => 'Cette vidéo est indisponible';

  @override
  String get noItems => 'Aucun élément';

  @override
  String get sortRelevance => 'Pertinence';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Écoutés récemment';

  @override
  String get noRecentTracks => 'Aucun morceau récemment écouté';

  @override
  String get playerSourceLocal => 'local';

  @override
  String get homePlayFiles => 'Lire des fichiers';

  @override
  String get homePlayFolder => 'Lire un dossier';

  @override
  String get homeSectionsOrderTitle => 'Ordre des sections';

  @override
  String get homeSectionsOrderSubtitle =>
      'Glissez pour ranger l’accueil à votre goût.';

  @override
  String get homeSectionsOrderReset => 'Ordre par défaut';

  @override
  String get homeSectionsOrderSettings => 'Ordre des sections de l’accueil';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total résultats';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded chargés…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded résultats';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded chargé(s) — faites défiler pour charger plus';
  }

  @override
  String countNLoaded(int n) {
    return '$n chargé(s)';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n fichier(s)';
  }

  @override
  String get browseFilterByTitle => 'Filtrer par titre…';

  @override
  String get browseNoSongs => 'Aucun morceau disponible';

  @override
  String get browseByFormat => 'Par format';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtrer par format…';

  @override
  String get browseByPlatform => 'Par plateforme';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Nom de plateforme…';

  @override
  String get browseByChip => 'Par puce sonore';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'ex: YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Par artiste';

  @override
  String get browseByArtistSubtitle => 'Parcourir les compositeurs';

  @override
  String get browseFilterByName => 'Filtrer par nom…';

  @override
  String get browseNoArtistFound => 'Aucun artiste trouvé';

  @override
  String get browseNoArtistsAvailable => 'Aucun artiste disponible';

  @override
  String get browseNoArtist => 'Aucun artiste';

  @override
  String get browseNoAlbum => 'Aucun album';

  @override
  String get browseTopPacks => 'Top packs';

  @override
  String get browseTopPacksSubtitle => 'Les packs les mieux notés';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Top packs — $collection';
  }

  @override
  String get browseLatestPacks => 'Derniers packs';

  @override
  String get browseLatestPacksSubtitle => 'Les ajouts les plus récents';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Derniers packs — $collection';
  }

  @override
  String get browseAllSongs => 'Tous les morceaux';

  @override
  String get browseAllSongsSubtitleAlpha => 'Parcourir par ordre alphabétique';

  @override
  String get browseAlphabetical => 'Par ordre alphabétique';

  @override
  String browseAllLabel(String collection) {
    return 'Tous — $collection';
  }

  @override
  String get browseCollections => 'Collections';

  @override
  String browseFilesCount(String count) {
    return '$count fichiers';
  }

  @override
  String get browseIndexing => 'En cours d\'indexation';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrer $name…';
  }

  @override
  String get browseAllYears => 'Toutes les années';

  @override
  String get browseAllYearsSubtitle => 'Tous les morceaux de la party';

  @override
  String get browseNoCompo => 'Aucune compo indexée pour cette party.';

  @override
  String get browseOthers => 'Autres';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n entrées — classement',
      one: '$n entrée — classement',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Lire la playlist';

  @override
  String get browsePlayAllRanked => 'Tout lire (dans l\'ordre du classement)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n titres — ordre du classement',
      one: '$n titre — ordre du classement',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Parcourir par albums';

  @override
  String get browsePlayAll => 'Tout lire';

  @override
  String get browseShuffle => 'Lecture aléatoire';

  @override
  String get browseSearchInFolder => 'Rechercher dans ce dossier…';

  @override
  String get browseFilterThisList => 'Filtrer cette liste…';

  @override
  String get browseSearchSubfolders => 'Chercher dans les sous-dossiers';

  @override
  String get browseEmptyFolder => 'Dossier vide';

  @override
  String browsePlaybackError(String message) {
    return 'Lecture impossible : $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n titres',
      one: '$n titre',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Affichage';

  @override
  String get browseViewList => 'Liste';

  @override
  String get browseViewGrid => 'Grille';

  @override
  String get browseViewGridCompact => 'Grille compacte';

  @override
  String get browseSearchAlbum => 'Rechercher un album…';

  @override
  String get browseSearchArtist => 'Rechercher un artiste…';

  @override
  String get browsePlayAlbum => 'Lire l\'album';

  @override
  String get searchDownloadingAlbum => 'Téléchargement de l\'album…';

  @override
  String get searchCategoryChip => 'Puces';

  @override
  String get searchCategoryGroup => 'Groupes';

  @override
  String get artistRealName => 'Nom réel';

  @override
  String get artistAliases => 'Alias';

  @override
  String get artistBorn => 'Né';

  @override
  String get artistInterview => 'Interview';

  @override
  String get audioOutput => 'Sortie audio';

  @override
  String get audioOutputSystemDefault => 'Défaut système';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notes';

  @override
  String get notePlacedBadge => 'Classé en compétition';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Voir les morceaux';

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
  String get searchCategoryYear => 'Année';

  @override
  String get searchCategoryOrigin => 'Origine';

  @override
  String get searchCategoryProduction => 'Production';

  @override
  String get searchCategoryProductionType => 'Types de prod';

  @override
  String get searchCategoryPublisher => 'Éditeurs';

  @override
  String get searchCategoryDeveloper => 'Développeurs';

  @override
  String get searchCategoryArcadeBoard => 'Cartes d\'arcade';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'via l\'artiste';

  @override
  String get searchViaAlbum => 'via un album';

  @override
  String get searchViaSong => 'via un morceau';

  @override
  String get searchSortPopular => 'Populaire';

  @override
  String get searchSortYear => 'Année';

  @override
  String get searchSortRandom => 'Aléatoire';

  @override
  String get searchSortRating => 'Note';

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
  String get searchSortAsc => 'Croissant';

  @override
  String get searchSortDesc => 'Décroissant';

  @override
  String get searchFilters => 'Filtres';

  @override
  String get searchExactSearch => 'Recherche exacte';

  @override
  String get searchExactSearchSubtitle =>
      'Désactive la recherche approximative (fuzzy)';

  @override
  String get searchTags => 'Tags';

  @override
  String searchTagSearchHint(String category) {
    return 'Rechercher un tag dans « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Tapez pour rechercher des tags.';

  @override
  String get searchTagsAndLogic => 'Plusieurs tags = ET logique.';

  @override
  String get searchFilterYear => 'Année';

  @override
  String get searchFilterAll => 'toutes';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrer par année exclut les morceaux non datés.';

  @override
  String get searchMinRating => 'Note ≥';

  @override
  String get searchPodium => 'Podium';

  @override
  String get searchPodiumAny => 'Tous les podiums';

  @override
  String get searchPodiumUnavailable =>
      'Le filtre podium n\'est pas encore disponible sur le serveur';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Annuler';

  @override
  String get searchReset => 'Réinitialiser';

  @override
  String get searchApply => 'Appliquer';

  @override
  String get searchClearRecent => 'Effacer les recherches récentes';

  @override
  String get searchBrowse => 'Parcourir';

  @override
  String get searchBrowseHint =>
      'Choisissez une facette (groupe, chip, année…) pour explorer le catalogue, ou lancez Radio/Surprise ci-dessus.';

  @override
  String get searchDidYouMean =>
      'Peu de résultats — essayer une recherche approximative ?';

  @override
  String get searchYes => 'Oui';

  @override
  String get featuredCommunityTitle => 'Nouveautés de la communauté';

  @override
  String get searchPlaylistSourceAll => 'Toutes';

  @override
  String get searchPlaylistSourceUser => 'Communauté';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Format';

  @override
  String get searchPlatform => 'Plateforme';

  @override
  String get filterCollection => 'Collection';

  @override
  String get videoWatchDemo => 'Regarder la démo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Collection: $name';
  }

  @override
  String get searchCollectionAll => 'Toutes';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'File aléatoire sur les filtres actuels';

  @override
  String get searchSurprise => 'Surprise';

  @override
  String get searchSurpriseTooltip => 'Un morceau au hasard';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Aucun morceau';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n morceaux',
      one: '$n morceau',
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
  String get searchChooseCollection => 'Choisir une collection';

  @override
  String get searchFilterCollections => 'Filtrer les collections…';

  @override
  String get searchFilterPlaceholder => 'Filtrer…';

  @override
  String searchAllOf(String label) {
    return 'Tous ($label)';
  }

  @override
  String get searchNoMatch => 'Aucune correspondance';

  @override
  String get searchNoPlaylist => 'Aucune playlist';

  @override
  String get engineDescOpenmpt => 'Modules tracker (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'Modules que libopenmpt ne lit pas (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — puces sonores, scope par canal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archives RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — voix par canal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (moteur reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'Chiptunes MSX (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Chiptunes multi-puces .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Formats Amiga custom-chip via émulation 68k (~320 exts)';

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
      'Nintendo DS .ncsf/.minincsf — synthé SDAT/SSEQ (16 voix)';

  @override
  String get engineDescV2m => 'Synthé V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — vraie émulation 68000 + YM2149 + DAC STE';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — émulation R4300 + RSP audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — émulation NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + puce QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — vrai synthé AY-3-8910/YM2149';

  @override
  String get engineDescOrganya => 'Cave Story .org — moteur natif de Pixel';

  @override
  String get engineDescPxtone => 'Tracker de Pixel — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — vrai 68000 emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver PC-98 — FM OPNA + SSG + échantillons PPZ8';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ échantillons .pdx), FM YM2151';

  @override
  String get engineDescFmp => 'Pilote FMP PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Formats audio de jeux streamés (700+, dont .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — décodeur de repli';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total morceaux',
      one: '$loaded / 1 morceau',
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
      other: '$loaded / $total artistes',
      one: '$loaded / 1 artiste',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n morceaux',
      one: '$n morceau',
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
      other: '$n artistes',
      one: '$n artiste',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n groupes',
      one: '$n groupe',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Pays';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pays',
      one: '$n pays',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Dossiers';

  @override
  String get featuredTitle => 'En vedette aujourd\'hui';

  @override
  String featuredPartyNow(String party) {
    return '$party a lieu en ce moment — les podiums des éditions passées';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          '$party commence dans $days jours — les podiums des éditions passées',
      one: '$party commence demain — les podiums des éditions passées',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'C\'est la saison de $series — les podiums des éditions passées';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Sorti en $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Il y a $age ans : les jeux de $year',
      one: 'Il y a un an : les jeux de $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Les années $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Il y a $age ans : les jeux de $year',
      one: 'Il y a un an : les jeux de $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Sorties en $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Anniversaires';

  @override
  String get featuredBirthdayHeader => 'Anniversaires du jour';

  @override
  String get featuredBirthdayWeekHeader => 'Anniversaires de la semaine';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return 'Anniversaire de $artist cette semaine';
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
  String get commonRetry => 'Réessayer';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonDownload => 'Télécharger';

  @override
  String get commonDeleteDownload => 'Supprimer le téléchargement';

  @override
  String get commonAddToPlaylist => 'Ajouter à la playlist';

  @override
  String get commonPlayNext => 'Lire ensuite';

  @override
  String get commonAddToQueueEnd => 'Ajouter à la fin de la file';

  @override
  String get commonAddToFavorites => 'Ajouter aux favoris';

  @override
  String get commonRemoveFromFavorites => 'Retirer des favoris';

  @override
  String unitBytes(String value) {
    return '$value o';
  }

  @override
  String unitKilobytes(String value) {
    return '$value Ko';
  }

  @override
  String unitMegabytes(String value) {
    return '$value Mo';
  }

  @override
  String get subsongDeleteDownloadTitle => 'Supprimer le téléchargement ?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Le fichier et ses entrées locales (historique, pistes) seront supprimés.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Impossible de lire les pistes';

  @override
  String subsongTrackNumber(int number) {
    return 'Piste $number';
  }

  @override
  String get subsongDefaultTrack => 'Piste par défaut';

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
  String get subsongPlayAll => 'Lire tous';

  @override
  String get albumDownloading => 'Téléchargement de l\'album…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Téléchargement de l\'album… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Téléchargez l\'album pour voir les pistes';

  @override
  String get albumNotDownloadedHint =>
      'Album non téléchargé — lancez la lecture pour télécharger';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Chargement des infos…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Lire l\'album';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '$count élément',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Jouez ce morceau depuis la recherche pour le télécharger d\'abord';

  @override
  String get libraryAddedTrack => 'Morceau ajouté à la bibliothèque';

  @override
  String get libraryAddedAlbum => 'Album ajouté à la bibliothèque';

  @override
  String get libraryAddedArtist => 'Artiste ajouté à la bibliothèque';

  @override
  String get libraryRemovedTrack => 'Morceau retiré de la bibliothèque';

  @override
  String get libraryRemovedAlbum => 'Album retiré de la bibliothèque';

  @override
  String get libraryRemovedArtist => 'Artiste retiré de la bibliothèque';

  @override
  String get libraryImportBeforeAddTitle => 'Importer d’abord ?';

  @override
  String get libraryImportBeforeAddBody =>
      'Ce fichier est lu depuis un emplacement temporaire que le système peut vider. L’importer dans votre bibliothèque locale pour que l’entrée survive ?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'Ce morceau vient d’une archive ouverte dans un cache temporaire. L’archive entière sera importée dans votre bibliothèque locale, fichiers compagnons compris.';

  @override
  String get libraryAddNeedsCatalogueId =>
      'Impossible d’ajouter ce morceau : son identifiant de catalogue est inconnu sur cet appareil.';

  @override
  String songTilePlayFailed(String message) {
    return 'Lecture impossible : $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Téléchargement impossible — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Téléchargement — $label';
  }

  @override
  String get downloadsTitle => 'Téléchargements';

  @override
  String get downloadsEmpty => 'Aucun téléchargement en attente';

  @override
  String get downloadsPause => 'Mettre en pause';

  @override
  String get downloadsResume => 'Reprendre';

  @override
  String get downloadsCancel => 'Annuler le téléchargement';

  @override
  String get downloadsClear => 'Tout retirer';

  @override
  String get downloadsPausedBanner =>
      'Téléchargements en pause — le fichier en cours se termine d\'abord';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Téléchargement — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Playlist';

  @override
  String get miniPlayerHideQueue => 'Masquer la playlist';

  @override
  String get transportShuffle => 'Lecture aléatoire';

  @override
  String get transportShuffleOn => 'Lecture aléatoire activée';

  @override
  String get transportLoopOff => 'Boucle désactivée';

  @override
  String get transportLoopQueue => 'Boucle : file d\'attente';

  @override
  String get transportLoopTrack => 'Boucle : morceau en cours';

  @override
  String get vizStereo => 'Stéréo';

  @override
  String get vizSpectrum => 'Spectre';

  @override
  String get vizVoices => 'Voix';

  @override
  String get vizNotes => 'Notes';

  @override
  String get vizPiano => 'Piano';

  @override
  String get vizPatterns => 'Patterns';

  @override
  String get patternScrollMode => 'Mode de défilement';

  @override
  String get patternSmoothScroll => 'Défilement fluide';

  @override
  String get patternPinnedRow => 'Ligne en cours épinglée';

  @override
  String get patternVolumeBars => 'Barres de volume';

  @override
  String get patternColorScheme => 'Palette de couleurs';

  @override
  String get patternSize => 'Taille';

  @override
  String get patternColumns => 'Colonnes';

  @override
  String get patternColumnsAll => 'Complet';

  @override
  String get patternColumnsNoteInstr => 'Réduit';

  @override
  String get patternColumnsNote => 'Minimum';

  @override
  String get vizClose => 'Fermer le visualiseur';

  @override
  String get vizFullscreen => 'Plein écran';

  @override
  String get vizExitFullscreen => 'Quitter le plein écran';

  @override
  String get vizPrevPreset => 'Preset précédent';

  @override
  String get vizNextPreset => 'Preset suivant';

  @override
  String get vizProjectmUnavailable => 'projectM indisponible';

  @override
  String get voicesTitle => 'Voix';

  @override
  String get voicesNone => 'Aucune voix pour ce morceau.';

  @override
  String get voicesLongPressSolo => 'appui long = solo';

  @override
  String get voicesMuteAll => 'Tout couper';

  @override
  String get voicesUnmuteAll => 'Tout activer';

  @override
  String get voicesStereoOutput => 'Sortie stéréo';

  @override
  String get voicesLeft => 'Gauche';

  @override
  String get voicesRight => 'Droite';

  @override
  String get enginesFormatsTitle => 'Formats lus';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats formats lisibles, répartis sur $engines moteurs de lecture.';
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
    return 'Reprend $title de $artist';
  }

  @override
  String stilCover(String work) {
    return 'Reprend $work';
  }

  @override
  String get playerQueue => 'File d\'attente';

  @override
  String get queueEdit => 'Modifier';

  @override
  String get queueEditDone => 'Terminé';

  @override
  String get queueClear => 'Vider la file d\'attente';

  @override
  String get queueClearConfirmTitle => 'Vider la file d\'attente ?';

  @override
  String get queueClearConfirmBody =>
      'La file sera vidée et la lecture s\'arrêtera.';

  @override
  String get queueClearConfirm => 'Vider';

  @override
  String get queueRemoveSelected => 'Retirer la sélection';

  @override
  String get queueRemoveTrack => 'Retirer de la file';

  @override
  String get queueReorder => 'Réordonner';

  @override
  String get playerArtwork => 'Artwork';

  @override
  String get playerVisualizer => 'Visualiseur';

  @override
  String get playerVoices => 'Voix';

  @override
  String get playerTrackInfo => 'Infos du morceau';

  @override
  String get playerShowQueue => 'Playlist';

  @override
  String get playerHideQueue => 'Masquer la playlist';

  @override
  String get playerNoTrackInfo => 'Aucune information disponible.';

  @override
  String get playerViewSubsongs => 'Voir les subsongs';

  @override
  String get playerViewAlbum => 'Voir l\'album';

  @override
  String get playerViewArtist => 'Voir l\'artiste';

  @override
  String get playerAddToPlaylist => 'Ajouter à la playlist';

  @override
  String get playerEngineSettings => 'Réglages du moteur';

  @override
  String get queueAddToPlaylist => 'Ajouter la file d\'attente à une playlist';

  @override
  String get playerMoreOptions => 'Plus d\'options';

  @override
  String get playerClose => 'Fermer';

  @override
  String get playerCancel => 'Annuler';

  @override
  String get playerDelete => 'Supprimer';

  @override
  String get playerAddFavorite => 'Ajouter aux favoris';

  @override
  String get playerRemoveFavorite => 'Retirer des favoris';

  @override
  String get playerAddToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get playerRemoveFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get playerAddedToLibrary => 'Morceau ajouté à la bibliothèque';

  @override
  String get playerRemovedFromLibrary => 'Morceau retiré de la bibliothèque';

  @override
  String get playerDeleteDownload => 'Supprimer le téléchargement';

  @override
  String get playerRedownload => 'Re-télécharger le fichier';

  @override
  String get playerRedownloadUnavailable =>
      'Re-téléchargement indisponible pour ce fichier';

  @override
  String get playerDeleteDownloadTitle => 'Supprimer le téléchargement ?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Le fichier et ses entrées locales (historique, pistes) seront supprimés.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Vos tendances';

  @override
  String get homeYourAllTimeTop => 'Votre top de tous les temps';

  @override
  String get homeTrending => 'Tendances';

  @override
  String get homeFeaturedPlaylists => 'Playlists en vedette';

  @override
  String get homeAllTimeTop => 'Top de tous les temps';

  @override
  String get homePeriod7d => '7 j';

  @override
  String get homePeriod30d => '30 j';

  @override
  String get homePeriod90d => '90 j';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n écoutes',
      one: '$n écoute',
      zero: '0 écoute',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistes',
      one: '$n piste',
      zero: '0 piste',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Playlist vide ou illisible';

  @override
  String get homeExtractingArchive => 'Extraction de l’archive…';

  @override
  String get homeArchiveEmpty => 'Aucun fichier lisible dans l’archive';

  @override
  String get homeNothingPlayable => 'Rien de jouable dans la sélection';

  @override
  String get homeAlbumLoadFailed => 'Impossible de charger cet album';

  @override
  String get homeSongLoadFailed => 'Impossible de charger ce morceau';

  @override
  String get navStats => 'Stats';

  @override
  String get navSettings => 'Réglages';

  @override
  String get playlistMoveUp => 'Déplacer vers le dossier parent';

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
      other: '$n sous-dossiers',
      one: '$n sous-dossier',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Ce dossier et tout son contenu seront définitivement supprimés :';

  @override
  String get playlistDeleteFolderEmptyBody => 'Ce dossier sera supprimé.';

  @override
  String get playlistFolderRoot => 'Racine';

  @override
  String get playlistMoveToFolder => 'Déplacer vers un dossier';

  @override
  String playlistDeleteTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get playlistDeleteBody =>
      'Cette playlist sera définitivement supprimée.';

  @override
  String get playlistRenameFolderTitle => 'Renommer le dossier';

  @override
  String get playlistClearFavorites => 'Supprimer tous les favoris';

  @override
  String get playlistClearFavoritesTitle => 'Supprimer tous les favoris ?';

  @override
  String get playlistClearFavoritesBody =>
      'Tu vas perdre tous tes morceaux favoris. Action irréversible.';

  @override
  String get playlistRemoveFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get playlistServerReadOnly => 'Playlist serveur · lecture seule';

  @override
  String get navAbout => 'À propos';

  @override
  String get navMore => 'Plus';

  @override
  String get shellAlbumQueuedAtEnd => 'Album ajouté à la fin de la file';

  @override
  String get shellAlbumQueuedNext => 'Album sera joué ensuite';

  @override
  String get shellAddingToQueue => 'Ajout à la file…';

  @override
  String get shellAddingNext => 'Ajout en suivant…';

  @override
  String shellDownloadFailed(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux ajoutés à la file',
      one: '$count morceau ajouté à la file',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" ajouté à la fin de la file';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" sera joué ensuite';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Téléchargement impossible : $title — piste suivante';
  }

  @override
  String get shellNetworkUnavailable =>
      'Lecture interrompue : le réseau semble indisponible.';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String statsPeriodDays(int n) {
    return '$n jours';
  }

  @override
  String get statsPeriodThisYear => 'Cette année';

  @override
  String get statsPeriodAll => 'Tout';

  @override
  String get statsByMonthOrYear => 'Par mois / année…';

  @override
  String get statsByYear => 'Par année';

  @override
  String get statsByMonth => 'Par mois';

  @override
  String get statsPlaysLabel => 'Écoutes';

  @override
  String get statsTracksLabel => 'Morceaux';

  @override
  String get statsArtistsLabel => 'Artistes';

  @override
  String get statsAlbumsLabel => 'Albums';

  @override
  String get statsListenTime => 'Durée d\'écoute';

  @override
  String get statsByCollection => 'Par collection';

  @override
  String get statsByFormat => 'Par format';

  @override
  String get statsByEngine => 'Par moteur';

  @override
  String get statsPlaylistsLabel => 'Playlists';

  @override
  String get statsLocalFilesSection => 'Fichiers téléchargés';

  @override
  String get statsFilesLabel => 'Fichiers';

  @override
  String get statsSpaceLabel => 'Espace disque';

  @override
  String get statsNoPlaysInPeriod => 'Aucune écoute sur cette période';

  @override
  String get statsNoPlays => 'Aucune écoute';

  @override
  String get statsTopTracks => 'Top morceaux';

  @override
  String get statsTopAlbums => 'Top albums';

  @override
  String get statsTopArtists => 'Top artistes';

  @override
  String statsTopTracksIn(String period) {
    return 'Top morceaux — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top albums — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top artistes — $period';
  }

  @override
  String get statsSeeAll => 'Tout voir';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n écoutes',
      one: '$n écoute',
      zero: '0 écoute',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n morceaux',
      one: '$n morceau',
      zero: '0 morceau',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'max $n';
  }

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonSort => 'Trier';

  @override
  String get commonPlayAll => 'Tout lire';

  @override
  String get sortName => 'Nom';

  @override
  String get sortTitle => 'Titre';

  @override
  String get sortArtist => 'Artiste';

  @override
  String get sortAlbum => 'Album';

  @override
  String get sortDateAdded => 'Date d\'ajout';

  @override
  String get commonClear => 'Effacer';

  @override
  String get sortRecentlyModified => 'Modifiées récemment';

  @override
  String get sortCreationDate => 'Date de création';

  @override
  String get playlistNameHint => 'Nom';

  @override
  String get playlistNew => 'Nouvelle playlist';

  @override
  String get playlistNewFolder => 'Nouveau dossier';

  @override
  String get playlistNewTooltip => 'Nouvelle playlist / dossier';

  @override
  String get playlistAddTo => 'Ajouter à la playlist';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ajouter à $n playlists',
      one: 'Ajouter à $n playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Sélectionnez une playlist';

  @override
  String get playlistFilterHint => 'Filtrer les playlists…';

  @override
  String get playlistSearchHint => 'Rechercher une playlist…';

  @override
  String get playlistNoMatch => 'Aucune playlist ne correspond';

  @override
  String get playlistNoneCreateHint => 'Aucune playlist — créez-en une avec +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n morceaux',
      one: '$n morceau',
      zero: 'Aucun morceau',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Déjà présents';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n éléments sont déjà présents dans les playlists sélectionnées.',
      one: '$n élément est déjà présent dans les playlists sélectionnées.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Ignorer les doublons';

  @override
  String get playlistAddAgain => 'Ajouter à nouveau';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n morceaux ajoutés',
      one: '$n morceau ajouté',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m playlists',
      one: '$n playlist',
    );
    return '$_temp0 à $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Ajout impossible : $error';
  }

  @override
  String get playlistRenameTitle => 'Renommer la playlist';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Supprimer le dossier « $name » ?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'Son contenu remonte au niveau supérieur.';

  @override
  String get playlistEmpty => 'Playlist vide';

  @override
  String get trackOptionsAddToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get trackOptionsRemoveFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get trackOptionsAddedToLibrary => 'Morceau ajouté à la bibliothèque';

  @override
  String get trackOptionsRemovedFromLibrary =>
      'Morceau retiré de la bibliothèque';

  @override
  String get trackOptionsViewAlbum => 'Voir l\'album';

  @override
  String get trackOptionsViewArtist => 'Voir l\'artiste';

  @override
  String get trackOptionsPlayNow => 'Lire maintenant';

  @override
  String get trackOptionsPlayNext => 'Lire ensuite';

  @override
  String get trackOptionsAddToQueueEnd => 'Ajouter à la fin de la file';

  @override
  String get trackOptionsPlayLast => 'Lire après';

  @override
  String get trackOptionsDeleteDownload => 'Supprimer le téléchargement';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Supprimer le téléchargement ?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Le fichier et ses entrées locales (historique, pistes) seront supprimés.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Téléchargement supprimé';

  @override
  String get trackOptionsAddToFavorites => 'Ajouter aux favoris';

  @override
  String get trackOptionsRemoveFromFavorites => 'Retirer des favoris';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Album ajouté aux favoris';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Album retiré des favoris';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Album non téléchargé — rien à supprimer';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Supprimer l\'album téléchargé ?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Le dossier et toutes ses entrées locales (pistes, historique) seront supprimés.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'Album supprimé du stockage local';

  @override
  String get trackOptionsRedownloadAlbum => 'Re-télécharger l\'album';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Réécrit fichiers ET entrées locales';

  @override
  String get trackOptionsDeleteAlbumFiles =>
      'Supprimer les fichiers de l\'album';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Dossier téléchargé + entrées locales (historique)';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsGeneralSubtitle => 'Thème';

  @override
  String get settingsVisualisation => 'Visualisation';

  @override
  String get settingsVisualisationSubtitle => 'Oscilloscopes, artwork en fond';

  @override
  String get settingsPlayback => 'Lecture';

  @override
  String get settingsPlaybackSubtitle => 'Boucles, fondu, silence';

  @override
  String get settingsEngines => 'Moteurs';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Données';

  @override
  String get settingsDataSubtitle =>
      'Identifiant, historique, réinitialisation';

  @override
  String get settingsBackupExport => 'Exporter une sauvegarde';

  @override
  String get settingsBackupExportSubtitle =>
      'Enregistrer votre bibliothèque, playlists et réglages dans un fichier';

  @override
  String get settingsBackupImport => 'Importer une sauvegarde';

  @override
  String get settingsBackupImportSubtitle =>
      'Restaurer vos données depuis un fichier de sauvegarde';

  @override
  String get settingsBackupExportFailed => 'Échec de l’export de la sauvegarde';

  @override
  String get settingsBackupImportConfirmTitle => 'Importer la sauvegarde ?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Ceci remplace votre bibliothèque, vos playlists et vos réglages sur cet appareil. Les fichiers téléchargés sont conservés.';

  @override
  String get settingsBackupImportConfirm => 'Importer';

  @override
  String get settingsBackupImportedTitle => 'Sauvegarde importée';

  @override
  String get settingsBackupImportedBody =>
      'Vos données ont été restaurées. Redémarrez l’app pour tout appliquer.';

  @override
  String get settingsBackupTooNew =>
      'Cette sauvegarde a été créée par une version plus récente de l’app';

  @override
  String get settingsBackupInvalid => 'Fichier de sauvegarde Rewamp invalide';

  @override
  String get settingsBackupImportFailed => 'Échec de l’import de la sauvegarde';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsAboutSubtitle => 'Crédits et licences';

  @override
  String get settingsCreditsSubtitle => 'Bibliothèques, données et composants';

  @override
  String get settingsSupport => 'Contact et support';

  @override
  String get settingsSupportSubtitle => 'Nous écrire, site web';

  @override
  String get settingsSupportEmail => 'Envoyer un email';

  @override
  String get settingsSupportEmailSubtitle => 'Question, bug ou suggestion';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — support';

  @override
  String get settingsSupportEmailIntro =>
      'Décris ta question, ton bug ou ta suggestion ci-dessus. Les informations ci-dessous nous aident à te répondre.';

  @override
  String get settingsSupportWebsite => 'Site web';

  @override
  String get settingsDonation => 'Soutenir Rewamp';

  @override
  String get settingsDonationSubtitle => 'Un pourboire, si le cœur t\'en dit';

  @override
  String get settingsDonationBlurb =>
      'Rewamp est gratuit et sans publicité — un travail de passion dédié à la préservation de la culture demoscene et rétro. Les dons soutiennent le développement de l\'app et aident à couvrir les coûts d\'hébergement de la base de données. Aucune obligation : si l\'app te plaît, un petit geste est toujours le bienvenu.';

  @override
  String get settingsDonationFloppy => 'Une disquette';

  @override
  String get settingsDonationCartridge => 'Une cartouche';

  @override
  String get settingsDonationBox => 'Un jeu en boîte';

  @override
  String get settingsDonationCustom => 'Montant libre';

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Supprimer';

  @override
  String get settingsReset => 'Réinitialiser';

  @override
  String get settingsRenew => 'Renouveler';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Infini';

  @override
  String get settingsDefault => 'Défaut';

  @override
  String get settingsCoreNoScope => 'sans oscilloscope';

  @override
  String get settingsNone => 'Aucun';

  @override
  String get settingsLevelLow => 'Faible';

  @override
  String get settingsLevelHigh => 'Élevé';

  @override
  String get settingsStereo => 'Stéréo';

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
    return '$value Mo';
  }

  @override
  String settingsSizeKb(String value) {
    return '$value Ko';
  }

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsArtworkTintTitle =>
      'Fond du lecteur teinté par l\'artwork';

  @override
  String get settingsArtworkTintSubtitle =>
      'Le lecteur prend la couleur dominante de la pochette';

  @override
  String get settingsGlassEffectTitle => 'Effet liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lentille et flou sur les barres du bas — à désactiver sur les appareils lents';

  @override
  String get settingsResetSection => 'Réinitialiser cette section';

  @override
  String get settingsResetEngine => 'Réinitialiser ce moteur';

  @override
  String get settingsResetChoices => 'Réinitialiser ces choix';

  @override
  String get settingsResetToDefault => 'Valeur par défaut';

  @override
  String get settingsStartInVizTitle => 'Démarrer en mode visualiseur';

  @override
  String get settingsStartInVizSubtitle =>
      'Le lecteur s\'ouvre sur les oscilloscopes plutôt que l\'artwork';

  @override
  String get settingsVoiceGridTitle => 'Grille de l\'oscilloscope voix';

  @override
  String get settingsVoiceGridSubtitle =>
      'Affiche les bordures séparant chaque voix';

  @override
  String get settingsKeepAwakeTitle => 'Garder l\'écran allumé';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Tant qu\'un visualiseur est affiché, l\'écran ne s\'éteint pas et ne se verrouille pas';

  @override
  String get settingsVoiceNamesTitle => 'Nom des voix';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Affiche le nom de chaque voix dans son cadre';

  @override
  String get settingsLineThickness => 'Épaisseur du trait';

  @override
  String get settingsScopeVoiceColor => 'Oscilloscope voix';

  @override
  String get settingsStereoColors => 'Stéréo : couleurs';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stéréo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stéréo gauche';

  @override
  String get settingsStereoRightColor => 'Stéréo droite';

  @override
  String get settingsNotePalette => 'Palette de couleurs';

  @override
  String get settingsNoteBoxStyle => 'Style des blocs';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsVizAll => 'Tous les visualiseurs';

  @override
  String get settingsVizScopes => 'Oscilloscopes (stéréo et par voies)';

  @override
  String get settingsVizFrameRate => 'Images par seconde';

  @override
  String get settingsVizFrameRateScreen => 'Écran';

  @override
  String settingsValueFps(int value) {
    return '$value img/s';
  }

  @override
  String get settingsCrtSpeed => 'Intensité / vitesse';

  @override
  String get settingsArtworkOpacity => 'Opacité artwork en fond';

  @override
  String get settingsProjectMTitle => 'Réglages projectM';

  @override
  String get settingsProjectMSubtitle => 'Presets, transitions, qualité, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Notifications de changement de piste';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Notification système avec le titre de la nouvelle piste';

  @override
  String get settingsSilenceDetection => 'Détection de silence';

  @override
  String get settingsCrossfade => 'Fondu croisé';

  @override
  String get localActionPlay => 'Lire des fichiers ou un dossier';

  @override
  String get localActionImport => 'Importer des fichiers ou un dossier';

  @override
  String localOpsImporting(String name) {
    return 'Import de $name…';
  }

  @override
  String get localOpsImportingSelection => 'Import des fichiers sélectionnés…';

  @override
  String localOpsDeleting(String name) {
    return 'Suppression de $name…';
  }

  @override
  String get localOpsPhaseCopying => 'copie';

  @override
  String get localOpsPhaseExtracting => 'extraction';

  @override
  String get localOpsPhaseRegistering => 'ajout à la bibliothèque';

  @override
  String get localOpsPhaseDeleting => 'effacement des fichiers';

  @override
  String get localImportFiles => 'Importer des fichiers';

  @override
  String get storageLocalImports => 'Imports locaux';

  @override
  String get settingsVgmJapaneseTags => 'Tags japonais (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'Préfère les champs japonais (titre, jeu, artiste) des tags VGM quand ils existent.';

  @override
  String get localImportFolder => 'Importer un dossier';

  @override
  String get localLibraryTitle => 'Sur cet appareil';

  @override
  String get libraryOnAnotherDevice => 'Sur un autre appareil';

  @override
  String get localLibraryEmpty =>
      'Aucun import local pour l’instant. Utilisez « Importer des fichiers » ou « Importer un dossier » depuis l’accueil.';

  @override
  String queueLimitReached(int count) {
    return 'File limitée aux $count premiers morceaux';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return 'Supprimer « $name » ? Le fichier et ses compagnons (pochette…) seront effacés.';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer le dossier « $name » et ses $count morceaux ?',
      one: 'Supprimer le dossier « $name » et son $count morceau ?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count piste(s) importée(s) en bibliothèque';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks piste(s) importée(s) — $albums album(s)';
  }

  @override
  String localImportFailed(String error) {
    return 'Import impossible : $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'Fond la fin de chaque piste dans le début de la suivante. À 0, l\'enchaînement reste sans blanc.';

  @override
  String get settingsMinSubsongSection => 'Sous-chansons trop courtes';

  @override
  String get settingsMinSubsongTitle => 'Durée minimale';

  @override
  String get settingsMinSubsongHelp =>
      'Les sous-chansons plus courtes sont écartées de la liste et de la file — un fichier de jeu tient souvent plus de bruitages que de musique. À 0, rien n\'est écarté ; une durée inconnue n\'est jamais tenue pour courte.';

  @override
  String get localNewFolder => 'Nouveau dossier';

  @override
  String get localFolderName => 'Nom du dossier';

  @override
  String get localRename => 'Renommer';

  @override
  String get localMoveTo => 'Déplacer vers…';

  @override
  String get localMove => 'Déplacer';

  @override
  String get localMoveNothing => 'Rien n\'a été déplacé';

  @override
  String get localNameInvalid => 'Nom invalide';

  @override
  String get localNameTaken => 'Ce nom est déjà pris';

  @override
  String get localMoveIntoItself =>
      'Un dossier ne peut pas être déplacé dans lui-même';

  @override
  String get localManageFailed => 'L\'opération a échoué';

  @override
  String subsongSkippedShort(int seconds) {
    return 'Non mise en file : moins de $seconds s (Réglages → Lecture)';
  }

  @override
  String get settingsQueuePrefetchSection => 'Téléchargements de la file';

  @override
  String get settingsQueuePrefetchTitle => 'Télécharger toute la file';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'Un fichier à la fois; le morceau manquant suivant démarre dès que le précédent est arrivé. Désactivé : seul le morceau suivant est récupéré.';

  @override
  String get settingsCdRipDeclickSection => 'Rips CD';

  @override
  String get settingsCdRipDeclickTitle =>
      'Supprimer les claquements en début de piste';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'Les mauvais rips CD (mp3, ape, ogg, flac…) s\'ouvrent souvent sur quelques échantillons corrompus. Ils sont réparés jusqu\'à 200 ms de vraie musique, puis le filtre s\'efface.';

  @override
  String get settingsSilenceSkipTitle => 'Passer au morceau suivant si silence';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Avance automatiquement quand la sortie reste silencieuse';

  @override
  String get settingsSilenceDelay => 'Délai de silence';

  @override
  String get settingsDefaultDuration => 'Durée par défaut';

  @override
  String get settingsDefaultDurationHelp =>
      'Appliquée quand un morceau ne fournit aucune durée connue (pas de tag, pas de métadonnée serveur) — évite qu\'il joue ou boucle indéfiniment. Ne s\'applique jamais aux morceaux Amiga (UADE), qui ont leur propre base de durées.';

  @override
  String get settingsForcedLoopHeader => 'Boucle / fondu forcés';

  @override
  String get settingsForcedLoopHelp =>
      'Certains formats bouclent une section précise (VGM, modules tracker…) ; d\'autres non. \"Infini\" ignore la fin naturelle du morceau.';

  @override
  String get settingsForceLoopCount => 'Forcer le nombre de boucles';

  @override
  String get settingsLoopCount => 'Nombre de boucles';

  @override
  String get settingsForceFadeout => 'Forcer un fondu de sortie';

  @override
  String get settingsFadeoutDuration => 'Durée du fondu';

  @override
  String get settingsResetEnginesTitle =>
      'Réinitialiser les réglages moteurs ?';

  @override
  String get settingsResetEnginesBody =>
      'Tous les réglages des moteurs reviendront à leurs valeurs par défaut.';

  @override
  String get settingsResetDefaultsTitle =>
      'Réinitialiser aux valeurs par défaut';

  @override
  String get settingsResetDefaultsSubtitle => 'Tous les moteurs';

  @override
  String get settingsDefaultDecoders => 'Décodeurs par défaut';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formats lus par plusieurs moteurs';

  @override
  String get settingsDecodersHelp =>
      'Certains formats sont lus par plusieurs moteurs. Choisissez lequel utiliser par défaut — les autres formats sont routés automatiquement.';

  @override
  String get settingsDecoderAmigaTrackers => 'Trackers Amiga (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'Modules que libopenmpt ne lit pas — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stéréo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — qualité, filtres, options par puce';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — filtre passe-haut';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont utilisée';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolation, passe-bas, écho';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panoramique, casque, gain, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — horloge, modèle, filtres ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — mode harmonique stéréo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, réverb';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — cores YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Volume maître';

  @override
  String get settingsAmplification => 'Amplification';

  @override
  String get settingsAmigaFilter => 'Filtre Amiga';

  @override
  String get settingsInterpolation => 'Interpolation';

  @override
  String get settingsPolyphony => 'Polyphonie';

  @override
  String get settingsReverb => 'Réverbération';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get playbackMt32NoRoms =>
      'Ce MIDI est écrit pour un Roland MT-32. Sans ses ROMs, il est joué sur la SoundFont, instruments adaptés au General MIDI — importez les ROMs dans Réglages › Moteurs › Munt pour l\'entendre vraiment.';

  @override
  String get settingsMidiMt32ToGm => 'Adapter les fichiers MT-32';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'Un MIDI écrit pour Roland MT-32 numérote ses programmes dans la liste du MT-32: traduits vers leur équivalent General MIDI le plus proche, ils donnent des instruments plausibles au lieu de tomber au hasard.';

  @override
  String get settingsInterpNone => 'Aucune';

  @override
  String get settingsInterpLinear => 'Linéaire';

  @override
  String get settingsInterpCubic => 'Cubique';

  @override
  String get settingsInterpSinc => 'Sinc (meilleure)';

  @override
  String get settingsStereoSeparation => 'Séparation stéréo';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Coupe la piste quand le moteur détecte un long silence';

  @override
  String get settingsStereoDepth => 'Profondeur stéréo';

  @override
  String get settingsEqualizer => 'Égaliseur';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — sans effet sur SPC';

  @override
  String get settingsBass => 'Graves';

  @override
  String get settingsTreble => 'Aigus';

  @override
  String get settingsAppliedLive =>
      'Appliqué immédiatement, y compris pendant la lecture.';

  @override
  String get settingsAppliedNextTrack => 'Appliqué au prochain morceau chargé.';

  @override
  String get settingsSidEmulation => 'Émulation';

  @override
  String get settingsSidResidfp => 'ReSIDfp (précis)';

  @override
  String get settingsSidLite => 'SIDLite (rapide)';

  @override
  String get settingsSidSampling => 'Échantillonnage';

  @override
  String get settingsSidSamplingInterp => 'Interpolation (rapide)';

  @override
  String get settingsSidSamplingResample => 'Resample (meilleure)';

  @override
  String get settingsSidClock => 'Horloge';

  @override
  String get settingsSidModel => 'Modèle SID';

  @override
  String get settingsSidFilter => 'Filtre SID';

  @override
  String get settingsSidForceSecond => 'Forcer un 2e SID';

  @override
  String get settingsSidSecondSubtitle => 'Morceaux 2SID stéréo';

  @override
  String get settingsSidSecondAddr => 'Adresse 2e SID';

  @override
  String get settingsSidForceThird => 'Forcer un 3e SID';

  @override
  String get settingsSidThirdAddr => 'Adresse 3e SID';

  @override
  String get settingsSidAutoFilter => 'Plage filtre 6581 auto';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Valeur recommandée selon l\'auteur du morceau (tables sidplayfp)';

  @override
  String get settingsSid6581Range => 'Plage filtre 6581';

  @override
  String get settingsSid6581Curve => 'Courbe filtre 6581';

  @override
  String get settingsSid8580Curve => 'Courbe filtre 8580';

  @override
  String get settingsSidNote =>
      'Filtre SID et courbes appliqués en direct; émulation/échantillonnage/horloge/modèle/2e-3e SID au prochain morceau.';

  @override
  String get settingsAudioOutput => 'Sortie audio';

  @override
  String get settingsAdplugNote =>
      'Surround : deux puces OPL légèrement désaccordées. Appliqué au prochain morceau.';

  @override
  String get settingsHeSpuMain => 'Voix principales (SPU)';

  @override
  String get settingsHeSpuReverb => 'Réverb (SPU)';

  @override
  String get settingsNsfQuality => 'Qualité (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Filtre passe-bas';

  @override
  String get settingsHighpassFilter => 'Filtre passe-haut';

  @override
  String get settingsRegion => 'Région';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC forcé';

  @override
  String get settingsNsfRegionPalForced => 'PAL forcé';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy forcé';

  @override
  String get settingsNsfForceIrq => 'Forcer IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulses (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — triangle / bruit / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Démuter au reset';

  @override
  String get settingsNsfPhaseRefresh => 'Rafraîchir la phase';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Reset de phase à l\'écriture de période';

  @override
  String get settingsNsfNonlinearMixer => 'Mixage non linéaire';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'Mélange réel du 2A03 (sinon linéaire)';

  @override
  String get settingsNsfDutySwap => 'Échanger les duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Ordre des duty 25 % / 50 %';

  @override
  String get settingsNsfNegateSweep => 'Sweep négatif à l\'init';

  @override
  String get settingsNsfEnable4011 => 'Registre \$4011 actif';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Sortie DAC directe (clicks d\'origine)';

  @override
  String get settingsNsfPeriodicNoise => 'Bruit périodique';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Mode court du générateur de bruit';

  @override
  String get settingsNsfDpcmAntiClick => 'Anti-clic DPCM';

  @override
  String get settingsNsfRandomizeNoise => 'Bruit aléatoire à l\'init';

  @override
  String get settingsNsfTriangleMute => 'Couper le triangle';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Silence le triangle aux périodes ultrasonores';

  @override
  String get settingsNsfRandomizeTri => 'Triangle aléatoire à l\'init';

  @override
  String get settingsNsfDpcmReverse => 'DPCM inversé';

  @override
  String get settingsNsfN163Serial => 'Multiplexage série';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Bourdonnement réel du N163 multi-voix';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Phase en lecture seule';

  @override
  String get settingsNsfN163LimitWavelength => 'Limiter la longueur d\'onde';

  @override
  String get settingsNsfFdsCutoff => 'Coupure passe-bas';

  @override
  String get settingsNsfFds4085Reset => 'Reset \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Protection en écriture';

  @override
  String get settingsNsfVrc7Patch => 'Jeu de patches';

  @override
  String get settingsNsfVrc7Opll => 'Mode OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle =>
      'Émule un YM2413 plutôt que le VRC7';

  @override
  String get settingsGbsHpFilter => 'Filtre passe-haut (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (GB classique)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Écho';

  @override
  String get settingsUadePostfx => 'Post-traitement';

  @override
  String get settingsUadePostfxSubtitle =>
      'Active la chaîne d\'effets (requis pour le reste)';

  @override
  String get settingsUadePan => 'Panoramique (séparation stéréo)';

  @override
  String get settingsUadePanValue => 'Valeur du panoramique';

  @override
  String get settingsUadeHeadphones => 'Casque (headphones)';

  @override
  String get settingsUadeLed => 'LED (filtre Paula)';

  @override
  String get settingsUadeLedAuto => 'Auto (morceau)';

  @override
  String get settingsUadeLedOn => 'Forcée ON';

  @override
  String get settingsUadeLedOff => 'Forcée OFF';

  @override
  String get settingsUadeFilterType => 'Type de filtre';

  @override
  String get settingsUadeGain => 'Gain';

  @override
  String get settingsUadeGainValue => 'Valeur du gain';

  @override
  String get settingsSoundfontLoading => 'Chargement du catalogue…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Catalogue indisponible ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Téléchargement échoué : $error';
  }

  @override
  String get settingsSoundfontImport => 'Importer une SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Choisir un fichier .sf2 sur cet appareil';

  @override
  String get settingsSoundfontImported => 'Importée';

  @override
  String get settingsSoundfontInvalid =>
      'Ce fichier n\'est pas une SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Import impossible — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Supprimer le fichier';

  @override
  String get settingsCreditsHeader => 'Crédits & licences';

  @override
  String get settingsRightsNotice =>
      'Rewamp est un lecteur : il n\'héberge aucun fichier et ne distribue aucune musique. Les morceaux proviennent d\'archives de préservation en ligne et restent la propriété de leurs ayants droit. Il vous appartient de vérifier que leur écoute, leur téléchargement et leur conservation sont conformes aux droits applicables et à la réglementation de votre pays.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formats lus',
      one: '$count format lu',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Répartis sur $count moteurs de lecture — voir le détail',
      one: 'Sur $count moteur de lecture — voir le détail',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Durées & métadonnées Amiga';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb par Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Données & jaquettes C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — métadonnées et visuels des jeux C64.';

  @override
  String get settingsFt2FontTitle => 'Police FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'Le style FastTracker II du visualiseur de patterns utilise la police FT2 de ft2-clone par 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url copié';
  }

  @override
  String get settingsOpenLink => 'Ouvrir le lien';

  @override
  String get settingsEnginesHeader => 'Moteurs de lecture';

  @override
  String get settingsComponentsHeader => 'Autres composants';

  @override
  String get settingsResetAll => 'Réinitialiser tous les réglages';

  @override
  String get settingsResetAllSubtitle =>
      'Général, Visualisation, Lecture, Moteurs — pas la bibliothèque';

  @override
  String get settingsResetAllTitle => 'Réinitialiser tous les réglages ?';

  @override
  String get settingsResetAllBody =>
      'Général, Visualisation, Lecture et tous les moteurs reviendront à leurs valeurs par défaut. La bibliothèque et l\'historique ne sont pas touchés.';

  @override
  String get settingsRenewUserId => 'Renouveler l\'identifiant anonyme';

  @override
  String get settingsRenewUserIdTitle => 'Renouveler l\'identifiant anonyme ?';

  @override
  String get settingsRenewUserIdBody =>
      'Un nouvel identifiant anonyme sera créé pour les statistiques serveur.\n\nL\'ancien identifiant ne sera plus utilisé. Votre historique local et vos favoris ne sont pas affectés.';

  @override
  String get settingsRenewUserIdFailed => 'Échec — serveur inaccessible';

  @override
  String settingsNewUserId(String id) {
    return 'Nouvel identifiant : $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID : $id';
  }

  @override
  String get settingsNoUserId => 'Aucun identifiant enregistré';

  @override
  String get settingsCleanDb => 'Nettoyer la base locale';

  @override
  String get settingsCleanDbSubtitle =>
      'Supprime les entrées dont le fichier n\'existe plus (téléchargements effacés, anciennes erreurs)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées orphelines supprimées',
      one: '$count entrée orpheline supprimée',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'Base locale saine — rien à nettoyer';

  @override
  String get settingsClearCache => 'Vider le cache (artwork & métadonnées)';

  @override
  String get settingsClearCacheSubtitle =>
      'Supprime les pochettes en cache et les métadonnées récupérées (STIL, durées) — re-téléchargées à la prochaine lecture';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cache vidé ($count pochettes)',
      one: 'Cache vidé ($count pochette)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'Stockage';

  @override
  String get storageSubtitle =>
      'Ce que l’app garde sur disque, avec suppression';

  @override
  String get storageDownloads => 'Téléchargements';

  @override
  String get storageArtworkCache => 'Cache des pochettes';

  @override
  String get storageSoundfonts => 'SoundFonts';

  @override
  String get storagePresets => 'Presets de visualisation';

  @override
  String get storageOpenedFiles => 'Fichiers ouverts';

  @override
  String get storageOpenedEmpty =>
      'Les fichiers ouverts depuis l’extérieur (partage, « Ouvrir avec », sélecteur sur mobile) sont copiés ici.';

  @override
  String get storageInUse => 'dans une playlist ou la bibliothèque';

  @override
  String get storageDeleteAll => 'Tout supprimer';

  @override
  String get storageClear => 'Vider';

  @override
  String get storageDeleteSelection => 'Supprimer la sélection';

  @override
  String get storageSelectAll => 'Tout sélectionner';

  @override
  String get storageFilterHint => 'Filtrer par nom';

  @override
  String get storageNoMatch => 'Aucun fichier ne correspond à ce filtre.';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '$count sélectionné',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count fichiers ?',
      one: 'Supprimer $count fichier ?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Supprimer $count fichiers ? $inUse sont utilisés par une playlist ou la bibliothèque — ces entrées perdront leur fichier.',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'Supprimer tous les fichiers téléchargés et leurs lignes de bibliothèque ? Les favoris et playlists gardent leurs entrées, mais les fichiers devront être retéléchargés.';

  @override
  String get storageSoundfontsClearBody =>
      'Supprimer toutes les SoundFonts, importées comprises ? Celles du catalogue se retéléchargent à la demande ; les importées sont perdues.';

  @override
  String get storagePresetsClearBody =>
      'Supprimer les packs de presets téléchargés et les presets importés ? Les presets embarqués sont conservés ; les packs se retéléchargent, les importés sont perdus.';

  @override
  String get storageOpenedDeleteAllTitle => 'Supprimer les fichiers ouverts';

  @override
  String get storageInUseDeleteTitle => 'Fichier utilisé';

  @override
  String get storageInUseDeleteBody =>
      'Une playlist ou la bibliothèque pointe encore sur ce fichier. Le supprimer laissera ces entrées sans leur fichier.';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers — $size',
      one: '$count fichier — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers — $size · gestion depuis les albums et morceaux',
      one: '$count fichier — $size · gestion depuis les albums et morceaux',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Supprimer $count fichiers ? Les fichiers utilisés par une playlist ou la bibliothèque sont conservés.',
      one:
          'Supprimer $count fichier ? Les fichiers utilisés par une playlist ou la bibliothèque sont conservés.',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Réinitialiser les statistiques';

  @override
  String get settingsResetStatsSubtitle =>
      'Supprime l\'historique d\'écoute et les compteurs';

  @override
  String get settingsClearStatsTitle => 'Réinitialiser les statistiques ?';

  @override
  String get settingsClearStatsBody =>
      'Cette action supprimera définitivement :\n• tout l\'historique d\'écoute\n• les compteurs de lecture\n\nVos favoris et votre bibliothèque ne seront pas affectés.';

  @override
  String get settingsStatsCleared => 'Statistiques supprimées';

  @override
  String get settingsResetDatabase => 'Réinitialiser la base de données';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Supprime tout : historique, favoris, playlists, cache';

  @override
  String get settingsResetDbTitle => 'Réinitialiser la base de données ?';

  @override
  String get settingsCleanLocalTitle =>
      'Nettoyer les entrées locales injouables';

  @override
  String get cleanStageScan => 'Analyse des entrées…';

  @override
  String get cleanStageSync => 'Synchronisation avec votre compte…';

  @override
  String get cleanStagePurge => 'Retrait du compte…';

  @override
  String get cleanStageDelete => 'Suppression locale…';

  @override
  String get settingsCleanLocalBody =>
      'Entrées de bibliothèque qui nomment un fichier absent de cet appareil. Elles sont aussi retirées de votre compte, donc de vos autres appareils.';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées retirées',
      one: '$count entrée retirée',
      zero: 'Rien à nettoyer',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'Cette action supprimera définitivement :\n• tout l\'historique d\'écoute\n• tous les compteurs\n• tous les favoris\n• toutes les playlists\n• toutes les métadonnées en cache\n\nLes fichiers audio ne seront pas supprimés.';

  @override
  String get settingsDbReset => 'Base de données réinitialisée';

  @override
  String get settingsDeleteDownloads => 'Supprimer les téléchargements';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Supprime tous les fichiers du dossier online (tracks, artwork)';

  @override
  String get settingsCleanAll => 'Nettoyer la base locale et le cache';

  @override
  String get settingsCleanAllSubtitle =>
      'Retire les entrées dont le fichier a disparu, les entrées de bibliothèque qui nomment un fichier gardé sur un autre appareil, et vide le cache des pochettes et métadonnées';

  @override
  String get settingsCleanAllConfirmBody =>
      'Les entrées de bibliothèque qui nomment un fichier gardé sur un autre appareil sont aussi retirées de votre compte, donc de vos autres appareils. Pochettes et métadonnées se retéléchargent à la prochaine lecture.';

  @override
  String get settingsDataAdvanced => 'Avancé';

  @override
  String get settingsDataAdvancedSubtitle =>
      'Chaque étape du nettoyage séparément, le cache, et les réinitialisations';

  @override
  String get settingsDataGroupDb => 'Base de données';

  @override
  String get settingsDataGroupCache => 'Cache';

  @override
  String get settingsDataGroupReset => 'Réinitialiser';

  @override
  String get settingsDeleteDownloadsTitle => 'Supprimer les téléchargements ?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Cette action supprimera définitivement tous les fichiers téléchargés (tracks, albums, artwork) du dossier online.\n\nLes entrées en base de données resteront mais pointeront vers des fichiers inexistants.';

  @override
  String get settingsDownloadsDeleted => 'Téléchargements supprimés';

  @override
  String get settingsColor => 'Couleur';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Preset suivant aléatoire';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Désactivé : enchaîne les presets dans l\'ordre';

  @override
  String get settingsPmLockPreset => 'Verrouiller le preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Pas de changement automatique';

  @override
  String get settingsPmPresetDuration => 'Temps entre presets';

  @override
  String get settingsPmTransitions => 'Transitions';

  @override
  String get settingsPmBlend => 'Transition en fondu';

  @override
  String get settingsPmBlendSubtitle =>
      'Désactivé : changement de preset immédiat';

  @override
  String get settingsPmTransitionStyle => 'Style de transition';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Le motif utilisé par le fondu';

  @override
  String get settingsPmTransitionRandom => 'Aléatoire';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Changement de preset synchronisé sur les beats';

  @override
  String get settingsPmHardcutTime => 'Hardcut : temps minimum';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut : sensibilité';

  @override
  String get settingsPmRendering => 'Rendu';

  @override
  String get settingsPmQuality => 'Qualité';

  @override
  String get settingsPmQualitySubtitle =>
      'Résolution de rendu (Max = résolution native)';

  @override
  String get settingsPmBeatSensitivity => 'Sensibilité au beat';

  @override
  String get settingsPmAspectRatio => 'Respect du ratio d\'aspect';

  @override
  String get settingsPmAspectRatioSubtitle => 'Pour les shaders compatibles';

  @override
  String get settingsPmPermissive => 'Mode permissif';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Charge les .milk avec des erreurs de script';

  @override
  String get accountTitle => 'Compte';

  @override
  String get accountSubtitle => 'Sauvegarder et synchroniser ta bibliothèque';

  @override
  String get accountAnonymous => 'Compte anonyme';

  @override
  String get accountAnonymousExplain =>
      'Tes favoris et ton historique sont enregistrés sur le serveur, mais seul cet appareil peut y accéder. Ajoute une adresse e-mail pour les retrouver ailleurs.';

  @override
  String get accountEmailAttached =>
      'Adresse confirmée — ce compte peut être restauré';

  @override
  String get accountEmailPending => 'Adresse pas encore confirmée';

  @override
  String get accountInsecureStorage =>
      'Le stockage sécurisé de cet appareil est indisponible : l\'identifiant du compte est enregistré en clair.';

  @override
  String get accountSaveCta => 'Sauvegarder mon compte';

  @override
  String get accountStatSongs => 'Morceaux favoris';

  @override
  String get accountStatAlbums => 'Albums favoris';

  @override
  String get accountStatPlays => 'Écoutes';

  @override
  String get accountCreatedLabel => 'Créé le';

  @override
  String get accountSignOut => 'Se déconnecter';

  @override
  String get accountRevoke => 'Déconnecter partout';

  @override
  String get accountRevokeSubtitle => 'Déconnecte tous les autres appareils';

  @override
  String get accountRevokeBody =>
      'Tous les autres appareils sont déconnectés. Celui-ci reste connecté.';

  @override
  String get accountRevokeDone => 'Autres appareils déconnectés';

  @override
  String get accountDelete => 'Supprimer mon compte';

  @override
  String get accountDeleteSubtitle =>
      'Efface le compte et ses données sur le serveur. Irréversible.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favoris et $lists playlists seront supprimés du serveur. C\'est irréversible.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Tes téléchargements et la bibliothèque de cet appareil ne sont pas touchés.';

  @override
  String get accountDeleteDone => 'Compte supprimé';

  @override
  String get accountSignOutSubtitle => 'Cet appareil repart sur un compte vide';

  @override
  String get accountSignOutTitle => 'Se déconnecter ?';

  @override
  String accountSignOutBody(String email) {
    return 'Tu pourras revenir sur ce compte avec un code envoyé à $email.';
  }

  @override
  String get accountSignedOut => 'Déconnecté';

  @override
  String get accountNoSignOut => 'Déconnexion indisponible';

  @override
  String get accountNoSignOutSubtitle =>
      'Sans adresse e-mail, ce compte serait définitivement perdu.';

  @override
  String get accountDetach => 'Délier l\'adresse';

  @override
  String get accountDetachSubtitle =>
      'Le compte redevient anonyme, aucune donnée n\'est supprimée';

  @override
  String get accountDetachBody =>
      'Sans adresse, ce compte ne pourra plus être retrouvé depuis un autre appareil.';

  @override
  String get accountDetachDone => 'Adresse déliée';

  @override
  String get accountOffline => 'Compte indisponible hors ligne';

  @override
  String get accountEmailTitle => 'Adresse e-mail';

  @override
  String get accountEmailExplain =>
      'On t\'envoie un code à 6 chiffres pour confirmer l\'adresse. Elle ne sert qu\'à récupérer ton compte.';

  @override
  String get accountEmailLabel => 'Adresse e-mail';

  @override
  String get accountCodeTitle => 'Code de confirmation';

  @override
  String accountCodeExplain(String email) {
    return 'Code envoyé à $email. Il est valable 10 minutes.';
  }

  @override
  String get accountCodeLabel => 'Code à 6 chiffres';

  @override
  String get accountSendCode => 'Envoyer le code';

  @override
  String get accountVerify => 'Valider';

  @override
  String get accountResend => 'Renvoyer le code';

  @override
  String accountResendIn(int n) {
    return 'Renvoyer dans $n s';
  }

  @override
  String get accountCheckSpam =>
      'Le mail peut mettre une minute à arriver — pense au dossier indésirables.';

  @override
  String get accountErrorInvalidEmail => 'Adresse invalide';

  @override
  String get accountErrorTooMany =>
      'Trop de demandes, réessaie dans quelques minutes';

  @override
  String get accountErrorInvalidCode => 'Code incorrect ou expiré';

  @override
  String get accountErrorCodeLength => 'Le code fait 6 chiffres';

  @override
  String get albumOfflinePartial =>
      'Hors ligne — voici ce qui est déjà sur cet appareil';

  @override
  String get accountErrorNetwork => 'Connexion impossible, réessaie';

  @override
  String get accountMergeTitle => 'Fusionner cette bibliothèque ?';

  @override
  String accountMergeBody(String email) {
    return 'Les favoris et l\'historique de cet appareil seront ajoutés au compte $email. L\'opération est définitive.';
  }

  @override
  String get accountMergeConfirm => 'Fusionner';

  @override
  String get accountCarryLocal => 'Conserver les favoris de cet appareil';

  @override
  String accountCarryLocalOn(int n) {
    return 'Les $n favoris et les playlists de cet appareil sont ajoutés au compte.';
  }

  @override
  String get accountCarryLocalOff =>
      'Ils sont supprimés de cet appareil et remplacés par ceux du compte. Les fichiers téléchargés sont conservés.';

  @override
  String get accountDropLocalTitle => 'Supprimer les données de cet appareil ?';

  @override
  String get accountCreatedOk =>
      'Compte sauvegardé, ta bibliothèque est à l\'abri';

  @override
  String get accountMergedOk => 'Connecté — tes favoris locaux ont été ajoutés';

  @override
  String get accountSignedInOk => 'Connecté';

  @override
  String get playlistEntryMissing => 'Fichier absent de cet appareil';

  @override
  String get playlistEntryMissingRestorable =>
      'Fichier absent — retéléchargeable';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n absents',
      one: '$n absent',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Sauvegarder dans mon compte';

  @override
  String get playlistBackupSubtitle =>
      'Conserve cette playlist même après réinstallation';

  @override
  String get playlistBackupUpdate => 'Mettre à jour la sauvegarde';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Remplace la copie du compte par cette version';

  @override
  String get playlistBackupStop => 'Ne plus sauvegarder';

  @override
  String get playlistBackupStopped => 'Sauvegarde retirée';

  @override
  String get playlistBackupDone => 'Playlist sauvegardée';

  @override
  String get playlistBackupFailed => 'Sauvegarde impossible';

  @override
  String get playlistBackupNoAccount => 'Aucun compte sur cet appareil';

  @override
  String get playlistSyncTooltip => 'Synchroniser avec mon compte';

  @override
  String get playlistSyncRunning => 'Synchronisation…';

  @override
  String get playlistSyncDone => 'Playlists synchronisées';

  @override
  String get playlistSyncPartial =>
      'Certaines playlists n\'ont pas pu être sauvegardées';

  @override
  String get playlistFetchMissing => 'Télécharger les morceaux absents';

  @override
  String get playlistFetchDone => 'Morceaux absents téléchargés';

  @override
  String get playlistFetchPartial =>
      'Certains morceaux n\'ont pas pu être téléchargés';

  @override
  String get playlistEntryFetchFailed =>
      'Ce morceau n\'a pas pu être téléchargé';

  @override
  String get accountStatPlaylists => 'Playlists';

  @override
  String get accountSyncNow => 'Synchroniser maintenant';

  @override
  String get accountSyncAuto => 'Se fait tout seul en arrière-plan';

  @override
  String get accountSyncAnonymous =>
      'Sauvegardé sur le serveur. Ajoute un e-mail pour synchroniser un autre appareil.';

  @override
  String get accountSyncPending => 'Des changements attendent d\'être envoyés';

  @override
  String accountSyncLast(String when) {
    return 'Dernière synchro : $when';
  }

  @override
  String get accountSyncDone => 'Synchronisation terminée';

  @override
  String get accountSyncFailed =>
      'Synchronisation échouée, nouvel essai plus tard';

  @override
  String get podiumFirst => '1er';

  @override
  String get podiumSecond => '2e';

  @override
  String get podiumThird => '3e';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'musique de $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'contient le $place de $compo';
  }

  @override
  String get competitionEmpty => 'Cette compétition n\'a aucune entrée';

  @override
  String get competitionEntryNoMusic =>
      'Aucune musique au catalogue pour cette entrée';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n morceaux',
      one: '$n morceau',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboardingBetaTitle => 'Version bêta';

  @override
  String get onboardingBetaBody =>
      'Rewamp est encore en construction. Les données locales — bibliothèque, playlists, favoris, statistiques d\'écoute — pourront être remises à zéro d\'ici la version 1.0. Vos téléchargements ne risquent rien, mais gardez ailleurs ce à quoi vous tenez.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get onboardingExploreTitle => 'Explorer';

  @override
  String get onboardingExploreBody =>
      'Parcourez et cherchez des dizaines de milliers de chiptunes et modules parmi les grandes archives en ligne, par artiste, album, plateforme ou party. Touchez pour écouter, téléchargez pour garder.';

  @override
  String get onboardingLibraryTitle => 'Votre bibliothèque';

  @override
  String get onboardingLibraryBody =>
      'Enregistrez ce qui vous plaît, composez des playlists, rangez-les en dossiers. Tout ce qui est téléchargé s\'écoute hors ligne, et votre bibliothèque vous suit d\'un appareil à l\'autre une fois connecté.';

  @override
  String get onboardingPlayerTitle => 'Le lecteur';

  @override
  String get onboardingPlayerBody =>
      'Balayez pour changer de morceau et ouvrez les visualiseurs : oscilloscope, scopes par voix, notes défilantes, grille tracker. Les fichiers multi-pistes exposent leurs sous-morceaux, et chaque voix se coupe séparément.';

  @override
  String get onboardingReplayTitle => 'Présentation';

  @override
  String get onboardingReplaySubtitle =>
      'Revoir l\'avis bêta et la visite des fonctions';

  @override
  String get settingsPatternTitle => 'Patterns';

  @override
  String get settingsPatternSubtitle =>
      'Grille tracker : couleurs, colonnes, défilement';

  @override
  String get patternOpaqueBg => 'Fond opaque';

  @override
  String get patternOpaqueBgSubtitle => 'Masque la pochette derrière la grille';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonImport => 'Importer';

  @override
  String get accountDisplayName => 'Nom public';

  @override
  String get accountDisplayNameNotSet =>
      'Non défini — nécessaire pour publier une playlist';

  @override
  String get accountDisplayNameHint =>
      'Le nom sous lequel tu veux être crédité.';

  @override
  String get accountDisplayNameChangeWarning =>
      'En changer remet en validation toutes les playlists que tu as publiées.';

  @override
  String get accountDisplayNameTaken =>
      'Ce nom est déjà pris. Choisis-en un autre.';

  @override
  String get accountDisplayNameLength => 'Entre 2 et 40 caractères.';

  @override
  String get accountDisplayNameSaved => 'Nom public enregistré';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlists remises en validation : $n';
  }

  @override
  String get playlistPublish => 'Rendre publique';

  @override
  String get playlistPublishSubtitle =>
      'Demander la publication (après validation)';

  @override
  String get playlistPublishTitle => 'Publier cette playlist ?';

  @override
  String get playlistPublishBody =>
      'Elle sera visible par tous une fois validée, créditée à ton nom public. La jaquette vient de ses morceaux.';

  @override
  String get playlistPublishCta => 'Demander';

  @override
  String get playlistPublishSubmitted => 'Envoyée en validation';

  @override
  String get playlistPublishPending => 'En attente de validation';

  @override
  String get playlistPublishApproved => 'Publique';

  @override
  String playlistPublishRejected(String reason) {
    return 'Refusée : $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Refusée';

  @override
  String get playlistPublishNeedName =>
      'Choisis le nom sous lequel tu veux être crédité';

  @override
  String get playlistPublishNeedTracks =>
      'Il faut au moins 5 morceaux pour publier';

  @override
  String get playlistPublishHasLocal =>
      'Les fichiers de ton appareil ne peuvent pas être publiés — les autres ne peuvent pas les lire';

  @override
  String get playlistPublishTooManyPending =>
      'Tu as déjà 3 playlists en attente de validation';

  @override
  String get playlistPublishRefused =>
      'Publication refusée : vérifie les morceaux et les demandes en attente';

  @override
  String get playlistPublishFailed => 'Échec de la publication';

  @override
  String get playlistPublishWithdrawn => 'La playlist est redevenue privée';

  @override
  String get playlistUnpublish => 'Rendre privée';

  @override
  String get playlistUnpublishSubtitle => 'La retire des playlists publiques';

  @override
  String get playlistRenamePublishedTitle => 'Renommer une playlist publiée ?';

  @override
  String get playlistRenamePublishedBody =>
      'C\'est le nom qui est relu : le renommer renvoie la playlist en validation et la dépublie en attendant. Ajouter ou réordonner des morceaux, non.';

  @override
  String playlistByAuthor(String author) {
    return 'par $author';
  }

  @override
  String get settingsSpectrumMode => 'Mode du spectre';

  @override
  String get settingsSpectrumModeStandard => 'Standard';

  @override
  String get settingsSpectrumModeColored => 'Coloré';

  @override
  String get settingsSpectrumModeBeam => 'Faisceau';

  @override
  String get settingsSpectrumModeLine => 'Ligne';

  @override
  String get settingsSpectrumModeRing => 'Anneau';

  @override
  String get settingsPianoMode => 'Aspect du piano';

  @override
  String get settingsPianoModeRoll => 'Claviers';

  @override
  String get settingsPianoModeFalling => 'Notes qui tombent';

  @override
  String get settingsPianoColor => 'Couleurs';

  @override
  String get settingsPianoColorVoice => 'Par voix';

  @override
  String get settingsPianoColorInstrument => 'Par instrument';

  @override
  String get settingsPianoGlow => 'Halo sur les touches frappées';

  @override
  String get settingsPianoLighting => 'Lumière et ombres sur les touches';

  @override
  String get settingsPianoVoiceNames => 'Noms des voix';

  @override
  String get featuredAdditionsHeader => 'Nouveautés du catalogue';

  @override
  String get featuredAdditionsCard => 'Fraîchement ajouté';

  @override
  String get featuredAdditionsPlaylist => 'Les pistes fraîchement ajoutées';

  @override
  String get releaseNotesTitle => 'Nouveautés';

  @override
  String get releaseNotesV7Cpu =>
      'L\'application ne travaille plus en arrière-plan quand rien ne joue : beaucoup moins de processeur et de batterie.';

  @override
  String get releaseNotesV7VizIdle =>
      'Les visualiseurs s\'immobilisent quand la lecture est arrêtée, et sont plafonnés à 60 images par seconde (réglable).';

  @override
  String get releaseNotesV7Subsongs =>
      'Corrigé : sur PC Engine, Master System et Atari ST (.sndh), certaines pistes lançaient la chanson d\'à côté.';

  @override
  String get releaseNotesV7Piano =>
      'Le visualiseur Piano restait vide sur les musiques PC Engine.';

  @override
  String get releaseNotesV7Database =>
      'Une base de données abîmée par une mise à jour se répare toute seule, au lieu de rendre la bibliothèque inaccessible.';

  @override
  String get releaseNotesDataReset =>
      'Les données locales ont été réinitialisées pour cette beta. Bibliothèque et playlists se reconstruisent depuis le compte ; les téléchargements sont à refaire.';

  @override
  String get releaseNotesDismiss => 'Continuer';

  @override
  String get pmManagePresets => 'Gérer les presets';

  @override
  String get pmPickTooltip => 'Choisir un preset';

  @override
  String get pmPickFilter => 'Filtrer les presets';

  @override
  String get pmSourceTooltip => 'Source des presets';

  @override
  String get pmAddToPlaylistTooltip => 'Ajouter le preset à une playlist';

  @override
  String pmSlowPresetDropped(String name) {
    return '« $name » est trop lourd pour cet appareil et a été écarté.';
  }

  @override
  String get pmSlowDeviceTitle => 'Cet appareil ne suit pas';

  @override
  String get pmSlowDeviceOff =>
      'Le visualiseur a été désactivé : cet appareil ne suit pas les presets Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets écartés',
      one: '$count preset écarté',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Trop lents sur cet appareil. La lecture les saute.';

  @override
  String get settingsPmSlowPresetsRestore => 'Rétablir';

  @override
  String get pmSourceBundled => 'Presets intégrés';

  @override
  String get pmSourceImports => 'Mes imports';

  @override
  String get pmSourceAll => 'Tous les presets';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets',
      one: '$count preset',
      zero: 'Aucun preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Nouvelle playlist…';

  @override
  String get pmPlaylistName => 'Nom de la playlist';

  @override
  String get pmAddedToPlaylist => 'Ajouté à la playlist';

  @override
  String get pmAlreadyInPlaylist => 'Déjà dans cette playlist';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Parcourir';

  @override
  String get pmTabPlaylists => 'Playlists';

  @override
  String get pmTabPopular => 'Populaires';

  @override
  String get pmTabSetAside => 'Écartés';

  @override
  String get pmSetAsideEmpty =>
      'Rien d\'écarté. Les presets qui font tomber cet appareil sous 6 images/s atterrissent ici.';

  @override
  String get pmSetAsideRestoreAll => 'Tout rétablir';

  @override
  String get pmInstall => 'Installer';

  @override
  String get pmInstallQueued => 'Installation mise en file';

  @override
  String get pmUninstall => 'Désinstaller';

  @override
  String get pmUninstalled => 'Pack supprimé';

  @override
  String get pmUse => 'Utiliser';

  @override
  String get pmDefaultPackBanner => 'Pack de base recommandé';

  @override
  String pmLicense(String license) {
    return 'Licence : $license';
  }

  @override
  String get pmPacksOffline => 'Serveur injoignable';

  @override
  String get pmSearchPresets => 'Rechercher un preset…';

  @override
  String get pmPlayNow => 'Jouer maintenant';

  @override
  String get pmDownloadAction => 'Télécharger';

  @override
  String get pmDownloaded => 'Preset téléchargé';

  @override
  String get pmDownloadFailed => 'Échec du téléchargement';

  @override
  String pmPreviewing(String name) {
    return 'Lecture : $name';
  }

  @override
  String get pmLocalSection => 'Mes playlists';

  @override
  String get pmCuratedSection => 'Playlists Rewamp';

  @override
  String get pmImportPlaylist => 'Télécharger et utiliser';

  @override
  String get pmPlaylistImported => 'Playlist prête';

  @override
  String get pmImportFiles => 'Importer des fichiers…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets importés',
      one: '$count preset importé',
      zero: 'Aucun preset importé',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets ajoutés à la bibliothèque projectM';

  @override
  String get pmNoPlaylists => 'Aucune playlist de presets';

  @override
  String get pmSourceApplied => 'Source de presets appliquée';

  @override
  String get pmPlaylistEmpty => 'Cette playlist est vide';

  @override
  String get pmDays7 => '7 jours';

  @override
  String get pmDays30 => '30 jours';

  @override
  String get pmDays365 => '1 an';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures',
      one: '$count lecture',
      zero: 'Aucune lecture',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Échec de l\'installation';

  @override
  String get pmSingleDownloads => 'Téléchargements à l\'unité';

  @override
  String pmAvailableIn(String pack) {
    return 'Disponible dans $pack';
  }

  @override
  String get pmCleanUp => 'Nettoyer';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets supprimés',
      one: '$count preset supprimé',
      zero: 'Rien à nettoyer',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Verrouiller ce preset';

  @override
  String get pmUnlockAction => 'Déverrouiller le preset';

  @override
  String get pmOrderRandom => 'Presets au hasard';

  @override
  String get pmOrderSequential => 'Presets dans l\'ordre';

  @override
  String get pmUpdateAvailable => 'Mise à jour disponible';

  @override
  String get pmUpdate => 'Mettre à jour';

  @override
  String get pmSelectAll => 'Tout sélectionner';

  @override
  String get pmSelectNone => 'Tout désélectionner';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '$count sélectionné',
      zero: 'Aucune sélection',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Textures inutilisées';

  @override
  String pmTexturesFreed(String size) {
    return '$size libérés';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count textures',
      one: '$count texture',
      zero: 'Aucune texture',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'Charts';

  @override
  String get chartsGlobal => 'Global';

  @override
  String get chartsByCollection => 'Par collection';

  @override
  String get chartsTopSongs => 'Top morceaux';

  @override
  String get chartsTopAlbums => 'Top albums';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => 'Classements publiés';

  @override
  String chartsUpdated(String date) {
    return 'Mis à jour le $date';
  }

  @override
  String get chartsSource => 'Source';

  @override
  String get settingsMidiSynth => 'Synthétiseur MIDI';

  @override
  String get settingsMidiSynthAuto =>
      'Automatique (MT-32 quand le fichier le demande)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (émulation)';

  @override
  String get settingsMt32Section => 'Émulation Roland MT-32';

  @override
  String get settingsMt32RomsTitle => 'ROMs MT-32';

  @override
  String get settingsMt32RomsMissing =>
      'Aucun jeu de ROM utilisable — importez les ROMs de contrôle et PCM d\'un MT-32 ou d\'un CM-32L';

  @override
  String settingsMt32RomsActive(String set) {
    return 'Jeu actif : $set';
  }

  @override
  String get settingsMt32Import => 'Importer des fichiers ROM…';

  @override
  String get settingsMt32ImportSubtitle =>
      'ROM de contrôle + ROM PCM (.rom/.bin), moitiés MAME acceptées. Les ROMs ne sont pas fournies avec l\'application.';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name n\'est pas une ROM MT-32 / CM-32L connue';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers ROM importés',
      one: '$count fichier ROM importé',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'Modèle';

  @override
  String get settingsMt32ModelAuto => 'Automatique (CM-32L si disponible)';

  @override
  String get settingsMt32Reverb => 'Réverbération';

  @override
  String get engineDescMt32 =>
      'Émulation Roland MT-32 / CM-32L pour le MIDI (.mid/.midi/.kar/.rmi)';

  @override
  String get miniWindowEnter => 'Mini lecteur';

  @override
  String get miniWindowExit => 'Revenir à la fenêtre principale';

  @override
  String get miniWindowIdle => 'Rien en lecture';

  @override
  String get settingsAlwaysOnTopTitle => 'Toujours au premier plan';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'Garde la fenêtre au-dessus des autres — fenêtre principale comme mini lecteur';

  @override
  String get windowAlwaysOnTopOn => 'Toujours au premier plan : activé';

  @override
  String get miniWindowCoverFill => 'Zoomer la pochette pour remplir';

  @override
  String get miniWindowCoverFit => 'Afficher la pochette entière';

  @override
  String get releaseNotesV7Mt32 =>
      'Nouveau moteur Roland MT-32 pour les musiques MIDI de jeux, avec vos propres ROMs. Sans ROMs, un MIDI écrit pour le MT-32 est adapté au General MIDI.';

  @override
  String get releaseNotesV7Xmp =>
      'Dix formats de modules rares sont lus en plus (Archimedes Tracker .musx, .liq, .fnk…).';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'Les musiques AdLib de Westwood (.adl) jouent toutes leurs pistes, et BP SoundMon V1 est reconnu sur Amiga.';

  @override
  String get releaseNotesV7MiniPlayer =>
      'Mac : un mini lecteur, compact ou avec le visualiseur, et une option « Toujours au premier plan ».';

  @override
  String get releaseNotesV7Instruments =>
      'Oscilloscope, notes et piano peuvent nommer et colorer chaque instrument, pas seulement chaque voix.';

  @override
  String get releaseNotesV7Podium =>
      'Recherche : filtrer les morceaux classés 1er, 2e ou 3e d\'une compétition de la demoscene.';

  @override
  String get releaseNotesV7ShortSubsongs =>
      'Les sous-chansons trop courtes (bruitages de jeu) sont écartées de « Tout lire » — seuil dans Réglages → Lecture.';

  @override
  String get releaseNotesV7LocalFolders =>
      'Vos imports : déposez un dossier entier (archives dépliées), et créez, renommez ou déplacez des dossiers.';

  @override
  String get releaseNotesV7Midi =>
      'MIDI : la batterie ne joue plus au piano, et le volume ne sature plus.';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM : les presets ne se répètent plus d\'un lancement à l\'autre, et un preset n\'est plus écarté à tort après une pause.';

  @override
  String get libraryFileMissing => 'Fichier manquant';
}
