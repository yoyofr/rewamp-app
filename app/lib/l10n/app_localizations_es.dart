// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get noFileSelected => 'Ningún archivo seleccionado';

  @override
  String get openFile => 'Abrir archivo';

  @override
  String get pickerLabelAudio => 'Audio';

  @override
  String get formatNotSupported => 'Formato no compatible';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Formato no compatible: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'No está en este dispositivo: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'El archivo ya no está en el servidor: $file';
  }

  @override
  String get failedToLoadFile => 'No se ha podido cargar el archivo';

  @override
  String get libraryEmptyHint =>
      'Tus artistas, álbumes y listas de reproducción\naparecerán aquí.';

  @override
  String get libraryPlaylists => 'Listas de reproducción';

  @override
  String get libraryArtists => 'Artistas';

  @override
  String get libraryAlbums => 'Álbumes';

  @override
  String get libraryTracks => 'Pistas';

  @override
  String get libraryFavorites => 'Favoritos';

  @override
  String get libraryFavoritesSubtitle =>
      'Lista automática con tus pistas favoritas';

  @override
  String get libraryRecentlyAdded => 'Añadido recientemente';

  @override
  String get libraryEmpty => 'Aquí no hay nada todavía';

  @override
  String get libraryRemoved => 'Eliminado de la biblioteca';

  @override
  String get searchHint => 'Buscar…';

  @override
  String get searchTypePlaceholder => 'Escribe un título, artista o álbum…';

  @override
  String get searchNoResults => 'Sin resultados';

  @override
  String get searchDownloading => 'Descargando…';

  @override
  String searchError(String message) {
    return 'Error: $message';
  }

  @override
  String get tabAll => 'Pistas';

  @override
  String get tabArtists => 'Artistas';

  @override
  String get tabAlbums => 'Álbumes';

  @override
  String get tabProductions => 'Producciones';

  @override
  String get filterWithVideo => 'Con vídeo';

  @override
  String get videoUnavailable => 'Este vídeo no está disponible';

  @override
  String get noItems => 'Ningún elemento';

  @override
  String get sortRelevance => 'Relevancia';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Reproducido recientemente';

  @override
  String get noRecentTracks => 'Ninguna pista reproducida recientemente';

  @override
  String get openLocalFile => 'Abrir archivo local';

  @override
  String get playerSourceLocal => 'local';

  @override
  String get browseFiles => 'Explorar archivos';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total resultados';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded cargados…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded resultados';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded cargados — desplázate para ver más';
  }

  @override
  String countNLoaded(int n) {
    return '$n cargados';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n archivo(s)';
  }

  @override
  String get browseFilterByTitle => 'Filtrar por título…';

  @override
  String get browseNoSongs => 'No hay canciones disponibles';

  @override
  String get browseByFormat => 'Por formato';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Filtrar por formato…';

  @override
  String get browseByPlatform => 'Por plataforma';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Nombre de la plataforma…';

  @override
  String get browseByChip => 'Por chip de sonido';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'p. ej. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Por artista';

  @override
  String get browseByArtistSubtitle => 'Explorar los compositores';

  @override
  String get browseFilterByName => 'Filtrar por nombre…';

  @override
  String get browseNoArtistFound => 'No se ha encontrado ningún artista';

  @override
  String get browseNoArtistsAvailable => 'No hay artistas disponibles';

  @override
  String get browseNoArtist => 'Ningún artista';

  @override
  String get browseNoAlbum => 'Ningún álbum';

  @override
  String get browseTopPacks => 'Packs destacados';

  @override
  String get browseTopPacksSubtitle => 'Los packs mejor valorados';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Packs destacados — $collection';
  }

  @override
  String get browseLatestPacks => 'Últimos packs';

  @override
  String get browseLatestPacksSubtitle => 'Las incorporaciones más recientes';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Últimos packs — $collection';
  }

  @override
  String get browseAllSongs => 'Todas las canciones';

  @override
  String get browseAllSongsSubtitleAlpha => 'Explorar por orden alfabético';

  @override
  String get browseAlphabetical => 'Por orden alfabético';

  @override
  String browseAllLabel(String collection) {
    return 'Todo — $collection';
  }

  @override
  String get browseCollections => 'Colecciones';

  @override
  String browseFilesCount(String count) {
    return '$count archivos';
  }

  @override
  String get browseIndexing => 'Indexación en curso';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrar $name…';
  }

  @override
  String get browseAllYears => 'Todos los años';

  @override
  String get browseAllYearsSubtitle => 'Todas las canciones de la party';

  @override
  String get browseNoCompo => 'No hay ninguna compo indexada para esta party.';

  @override
  String get browseOthers => 'Otros';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n entradas — clasificación',
      one: '$n entrada — clasificación',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Reproducir la lista';

  @override
  String get browsePlayAllRanked =>
      'Reproducir todo (por orden de clasificación)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas — orden de clasificación',
      one: '$n pista — orden de clasificación',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Explorar por álbum';

  @override
  String get browsePlayAll => 'Reproducir todo';

  @override
  String get browseShuffle => 'Reproducción aleatoria';

  @override
  String get browseSearchInFolder => 'Buscar en esta carpeta…';

  @override
  String get browseFilterThisList => 'Filtrar esta lista…';

  @override
  String get browseSearchSubfolders => 'Buscar en subcarpetas';

  @override
  String get browseEmptyFolder => 'Carpeta vacía';

  @override
  String browsePlaybackError(String message) {
    return 'No se ha podido reproducir: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas',
      one: '$n pista',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Vista';

  @override
  String get browseViewList => 'Lista';

  @override
  String get browseViewGrid => 'Cuadrícula';

  @override
  String get browseViewGridCompact => 'Cuadrícula compacta';

  @override
  String get browseSearchAlbum => 'Buscar un álbum…';

  @override
  String get browseSearchArtist => 'Buscar un artista…';

  @override
  String get browsePlayAlbum => 'Reproducir el álbum';

  @override
  String get searchDownloadingAlbum => 'Descargando el álbum…';

  @override
  String get searchCategoryChip => 'Chips';

  @override
  String get searchCategoryGroup => 'Grupos';

  @override
  String get artistRealName => 'Nombre real';

  @override
  String get artistAliases => 'Alias';

  @override
  String get artistBorn => 'Nacimiento';

  @override
  String get artistInterview => 'Entrevista';

  @override
  String get audioOutput => 'Salida de audio';

  @override
  String get audioOutputSystemDefault => 'Predeterminada del sistema';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notas';

  @override
  String get notePlacedBadge => 'Clasificada en competición';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '$count miembro',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Ver canciones';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count módulos',
      one: '$count módulo',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Demoparties';

  @override
  String get searchCategoryYear => 'Año';

  @override
  String get searchCategoryOrigin => 'Origen';

  @override
  String get searchCategoryProduction => 'Producción';

  @override
  String get searchCategoryProductionType => 'Tipos de prod';

  @override
  String get searchCategoryPublisher => 'Editores';

  @override
  String get searchCategoryDeveloper => 'Desarrolladores';

  @override
  String get searchCategoryArcadeBoard => 'Placas arcade';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Género';

  @override
  String get searchViaArtist => 'vía artista';

  @override
  String get searchViaAlbum => 'vía un álbum';

  @override
  String get searchViaSong => 'vía una canción';

  @override
  String get searchSortPopular => 'Popular';

  @override
  String get searchSortYear => 'Año';

  @override
  String get searchSortRandom => 'Aleatorio';

  @override
  String get searchSortRating => 'Valoración';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '$count voto',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Ascendente';

  @override
  String get searchSortDesc => 'Descendente';

  @override
  String get searchFilters => 'Filtros';

  @override
  String get searchExactSearch => 'Búsqueda exacta';

  @override
  String get searchExactSearchSubtitle =>
      'Desactiva la búsqueda aproximada (fuzzy)';

  @override
  String get searchTags => 'Etiquetas';

  @override
  String searchTagSearchHint(String category) {
    return 'Buscar una etiqueta en « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Escribe para buscar etiquetas.';

  @override
  String get searchTagsAndLogic => 'Varias etiquetas = Y lógico.';

  @override
  String get searchFilterYear => 'Año';

  @override
  String get searchFilterAll => 'todos';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrar por año excluye las canciones sin fecha.';

  @override
  String get searchMinRating => 'Valoración ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Cancelar';

  @override
  String get searchReset => 'Restablecer';

  @override
  String get searchApply => 'Aplicar';

  @override
  String get searchClearRecent => 'Borrar las búsquedas recientes';

  @override
  String get searchBrowse => 'Explorar';

  @override
  String get searchBrowseHint =>
      'Elige una faceta (grupo, chip, año…) para explorar el catálogo, o inicia Radio/Sorpresa arriba.';

  @override
  String get searchDidYouMean =>
      'Pocos resultados: ¿probar una búsqueda aproximada?';

  @override
  String get searchYes => 'Sí';

  @override
  String get featuredCommunityTitle => 'Novedades de la comunidad';

  @override
  String get searchPlaylistSourceAll => 'Todas';

  @override
  String get searchPlaylistSourceUser => 'Comunidad';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formato';

  @override
  String get searchPlatform => 'Plataforma';

  @override
  String get filterCollection => 'Colección';

  @override
  String get videoWatchDemo => 'Ver la demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Colección: $name';
  }

  @override
  String get searchCollectionAll => 'Todas';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Cola aleatoria con los filtros actuales';

  @override
  String get searchSurprise => 'Sorpresa';

  @override
  String get searchSurpriseTooltip => 'Una canción al azar';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Ninguna canción';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones',
      one: '$n canción',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n álbumes',
      one: '$n álbum',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Elegir una colección';

  @override
  String get searchFilterCollections => 'Filtrar las colecciones…';

  @override
  String get searchFilterPlaceholder => 'Filtrar…';

  @override
  String searchAllOf(String label) {
    return 'Todos ($label)';
  }

  @override
  String get searchNoMatch => 'Ninguna coincidencia';

  @override
  String get searchNoPlaylist => 'Ninguna lista de reproducción';

  @override
  String get engineDescOpenmpt => 'Módulos tracker (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — chips de sonido, osciloscopio por canal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + archivos RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — voces por canal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (motor reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'Chiptunes de MSX (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace => 'Chiptunes multichip .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Formatos Amiga de chips propios mediante emulación 68k (~320 ext.)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'MIDI estándar + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — sintetizador SDAT/SSEQ (16 voces)';

  @override
  String get engineDescV2m => 'Sintetizador V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — emulación real del 68000 + YM2149 + DAC STE';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — emulación R4300 + audio RSP';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — emulación NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + chip QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — sintetizador real AY-3-8910/YM2149';

  @override
  String get engineDescOrganya => 'Cave Story .org — motor propio de Pixel';

  @override
  String get engineDescPxtone => 'El tracker de Pixel — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — 68000 real vía emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver de PC-98 — FM OPNA + SSG + muestras PPZ8';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ muestras .pdx), FM YM2151';

  @override
  String get engineDescFmp =>
      'Controlador FMP de PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY de FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Formatos de audio de videojuegos en streaming (más de 700, incl. .rrds)';

  @override
  String get engineDescMiniaudio =>
      'PCM/MP3/FLAC/OGG — decodificador de reserva';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total canciones',
      one: '$loaded / 1 canción',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total álbumes',
      one: '$loaded / 1 álbum',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total artistas',
      one: '$loaded / 1 artista',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones',
      one: '$n canción',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n álbumes',
      one: '$n álbum',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artistas',
      one: '$n artista',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n grupos',
      one: '$n grupo',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Países';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n países',
      one: '$n país',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Carpetas';

  @override
  String get featuredTitle => 'Destacado hoy';

  @override
  String featuredPartyNow(String party) {
    return '$party se está celebrando ahora mismo — podios de ediciones anteriores';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          '$party empieza dentro de $days días — podios de ediciones anteriores',
      one: '$party empieza mañana — podios de ediciones anteriores',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'Temporada de $series — podios de ediciones anteriores';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Publicado en $month de $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Hace $age años: los juegos de $year',
      one: 'Hace un año: los juegos de $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Los años $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Hace $age años: los juegos de $year',
      one: 'Hace un año: los juegos de $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Lanzados en $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Aniversarios';

  @override
  String get featuredBirthdayHeader => 'Cumpleaños de hoy';

  @override
  String get featuredBirthdayWeekHeader => 'Cumpleaños de la semana';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return 'Cumpleaños de $artist esta semana';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '$count lista',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonOptions => 'Opciones';

  @override
  String get commonDownload => 'Descargar';

  @override
  String get commonDeleteDownload => 'Eliminar la descarga';

  @override
  String get commonAddToPlaylist => 'Añadir a la lista de reproducción';

  @override
  String get commonPlayNext => 'Reproducir a continuación';

  @override
  String get commonAddToQueueEnd => 'Añadir al final de la cola';

  @override
  String get commonAddToFavorites => 'Añadir a favoritos';

  @override
  String get commonRemoveFromFavorites => 'Quitar de favoritos';

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
  String get subsongDeleteDownloadTitle => '¿Eliminar esta descarga?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Se eliminarán el archivo y sus entradas locales (historial, pistas).\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'No se han podido leer las pistas';

  @override
  String subsongTrackNumber(int number) {
    return 'Pista $number';
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
  String get subsongPlayAll => 'Reproducir todo';

  @override
  String get albumDownloading => 'Descargando el álbum…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Descargando el álbum… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Descarga el álbum para ver sus pistas';

  @override
  String get albumNotDownloadedHint =>
      'Álbum no descargado — inicia la reproducción para descargarlo';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '$count pista',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Cargando los detalles…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Reproducir el álbum';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '$count elemento',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Reproduce esta pista desde la búsqueda para descargarla primero';

  @override
  String get libraryAddedTrack => 'Pista añadida a tu biblioteca';

  @override
  String get libraryAddedAlbum => 'Álbum añadido a tu biblioteca';

  @override
  String get libraryAddedArtist => 'Artista añadido a tu biblioteca';

  @override
  String get libraryRemovedTrack => 'Pista quitada de tu biblioteca';

  @override
  String get libraryRemovedAlbum => 'Álbum quitado de tu biblioteca';

  @override
  String get libraryRemovedArtist => 'Artista quitado de tu biblioteca';

  @override
  String songTilePlayFailed(String message) {
    return 'No se ha podido reproducir: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Descarga fallida — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Descargando — $label';
  }

  @override
  String get downloadsTitle => 'Descargas';

  @override
  String get downloadsEmpty => 'No hay descargas pendientes';

  @override
  String get downloadsPause => 'Pausar';

  @override
  String get downloadsResume => 'Reanudar';

  @override
  String get downloadsCancel => 'Cancelar la descarga';

  @override
  String get downloadsClear => 'Quitar todo';

  @override
  String get downloadsPausedBanner =>
      'Descargas en pausa — el archivo actual termina primero';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Descargando — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Lista de reproducción';

  @override
  String get miniPlayerHideQueue => 'Ocultar la lista de reproducción';

  @override
  String get transportShuffle => 'Reproducción aleatoria';

  @override
  String get transportShuffleOn => 'Reproducción aleatoria activada';

  @override
  String get transportLoopOff => 'Repetición desactivada';

  @override
  String get transportLoopQueue => 'Repetición: cola';

  @override
  String get transportLoopTrack => 'Repetición: pista actual';

  @override
  String get vizStereo => 'Estéreo';

  @override
  String get vizSpectrum => 'Espectro';

  @override
  String get vizVoices => 'Voces';

  @override
  String get vizNotes => 'Notas';

  @override
  String get vizPatterns => 'Patrones';

  @override
  String get patternScrollMode => 'Modo de desplazamiento';

  @override
  String get patternSmoothScroll => 'Desplazamiento suave';

  @override
  String get patternVolumeBars => 'Barras de volumen';

  @override
  String get patternColorScheme => 'Esquema de color';

  @override
  String get patternSize => 'Tamaño';

  @override
  String get patternColumns => 'Columnas';

  @override
  String get patternColumnsAll => 'Completo';

  @override
  String get patternColumnsNoteInstr => 'Reducido';

  @override
  String get patternColumnsNote => 'Mínimo';

  @override
  String get vizClose => 'Cerrar el visualizador';

  @override
  String get vizFullscreen => 'Pantalla completa';

  @override
  String get vizExitFullscreen => 'Salir de la pantalla completa';

  @override
  String get vizPrevPreset => 'Preset anterior';

  @override
  String get vizNextPreset => 'Preset siguiente';

  @override
  String get vizProjectmUnavailable => 'projectM no disponible';

  @override
  String get voicesTitle => 'Voces';

  @override
  String get voicesNone => 'No hay voces para esta pista.';

  @override
  String get voicesLongPressSolo => 'pulsación larga = solo';

  @override
  String get voicesMuteAll => 'Silenciar todo';

  @override
  String get voicesUnmuteAll => 'Activar todo';

  @override
  String get voicesStereoOutput => 'Salida estéreo';

  @override
  String get voicesLeft => 'Izquierda';

  @override
  String get voicesRight => 'Derecha';

  @override
  String get enginesFormatsTitle => 'Formatos reproducibles';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats formatos reproducibles, repartidos en $engines motores de reproducción.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formatos',
      one: '1 formato',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Versión de $title de $artist';
  }

  @override
  String stilCover(String work) {
    return 'Versión de $work';
  }

  @override
  String get playerQueue => 'Cola';

  @override
  String get queueEdit => 'Editar';

  @override
  String get queueEditDone => 'Listo';

  @override
  String get queueClear => 'Vaciar la cola';

  @override
  String get queueClearConfirmTitle => '¿Vaciar la cola?';

  @override
  String get queueClearConfirmBody =>
      'Se vaciará la cola y se detendrá la reproducción.';

  @override
  String get queueClearConfirm => 'Vaciar';

  @override
  String get queueRemoveSelected => 'Quitar selección';

  @override
  String get queueRemoveTrack => 'Quitar de la cola';

  @override
  String get queueReorder => 'Reordenar';

  @override
  String get playerArtwork => 'Portada';

  @override
  String get playerVisualizer => 'Visualizador';

  @override
  String get playerVoices => 'Voces';

  @override
  String get playerTrackInfo => 'Info de la pista';

  @override
  String get playerShowQueue => 'Lista de reproducción';

  @override
  String get playerHideQueue => 'Ocultar la lista de reproducción';

  @override
  String get playerNoTrackInfo => 'No hay información disponible.';

  @override
  String get playerViewSubsongs => 'Ver los subsongs';

  @override
  String get playerViewAlbum => 'Ver el álbum';

  @override
  String get playerViewArtist => 'Ver el artista';

  @override
  String get playerAddToPlaylist => 'Añadir a la lista de reproducción';

  @override
  String get queueAddToPlaylist => 'Añadir la cola a una lista';

  @override
  String get playerMoreOptions => 'Más opciones';

  @override
  String get playerClose => 'Cerrar';

  @override
  String get playerCancel => 'Cancelar';

  @override
  String get playerDelete => 'Eliminar';

  @override
  String get playerAddFavorite => 'Añadir a favoritos';

  @override
  String get playerRemoveFavorite => 'Quitar de favoritos';

  @override
  String get playerAddToLibrary => 'Añadir a la biblioteca';

  @override
  String get playerRemoveFromLibrary => 'Quitar de la biblioteca';

  @override
  String get playerAddedToLibrary => 'Pista añadida a la biblioteca';

  @override
  String get playerRemovedFromLibrary => 'Pista quitada de la biblioteca';

  @override
  String get playerDeleteDownload => 'Eliminar la descarga';

  @override
  String get playerRedownload => 'Volver a descargar el archivo';

  @override
  String get playerRedownloadUnavailable =>
      'Volver a descargar no disponible para este archivo';

  @override
  String get playerDeleteDownloadTitle => '¿Eliminar la descarga?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Se eliminarán el archivo y sus entradas locales (historial, pistas).\n\n$path';
  }

  @override
  String get homeYourTrends => 'Tus tendencias';

  @override
  String get homeYourAllTimeTop => 'Tu top de todos los tiempos';

  @override
  String get homeTrending => 'Tendencias';

  @override
  String get homeFeaturedPlaylists => 'Listas destacadas';

  @override
  String get homeAllTimeTop => 'Top de todos los tiempos';

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
      other: '$n reproducciones',
      one: '$n reproducción',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas',
      one: '$n pista',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Lista vacía o ilegible';

  @override
  String get homeExtractingArchive => 'Extrayendo el archivo…';

  @override
  String get homeArchiveEmpty => 'No hay archivos reproducibles en el archivo';

  @override
  String get homeNothingPlayable => 'Nada reproducible en la selección';

  @override
  String get homeAlbumLoadFailed => 'No se ha podido cargar este álbum';

  @override
  String get homeSongLoadFailed => 'No se ha podido cargar esta pista';

  @override
  String get navStats => 'Estadísticas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get playlistMoveUp => 'Mover a la carpeta superior';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n listas',
      one: '$n lista',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n subcarpetas',
      one: '$n subcarpeta',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Esta carpeta y todo su contenido se eliminarán permanentemente:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Esta carpeta se eliminará.';

  @override
  String get playlistFolderRoot => 'Raíz';

  @override
  String get playlistMoveToFolder => 'Mover a una carpeta';

  @override
  String playlistDeleteTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get playlistDeleteBody => 'Esta lista se eliminará permanentemente.';

  @override
  String get playlistRenameFolderTitle => 'Renombrar carpeta';

  @override
  String get playlistClearFavorites => 'Eliminar todos los favoritos';

  @override
  String get playlistClearFavoritesTitle => '¿Eliminar todos los favoritos?';

  @override
  String get playlistClearFavoritesBody =>
      'Perderás todos tus temas favoritos. No se puede deshacer.';

  @override
  String get playlistRemoveFromLibrary => 'Quitar de la biblioteca';

  @override
  String get playlistServerReadOnly => 'Lista del servidor · solo lectura';

  @override
  String get navAbout => 'Acerca de';

  @override
  String get navMore => 'Más';

  @override
  String get shellAlbumQueuedAtEnd => 'Álbum añadido al final de la cola';

  @override
  String get shellAlbumQueuedNext => 'El álbum se reproducirá a continuación';

  @override
  String get shellAddingToQueue => 'Añadiendo a la cola…';

  @override
  String get shellAddingNext => 'Añadiendo para reproducir a continuación…';

  @override
  String shellDownloadFailed(String error) {
    return 'Error en la descarga: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas añadidas a la cola',
      one: '$count pista añadida a la cola',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" añadido al final de la cola';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" se reproducirá a continuación';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Descarga fallida: $title — pasando a la pista siguiente';
  }

  @override
  String get shellNetworkUnavailable =>
      'Reproducción detenida: la red parece no estar disponible.';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String statsPeriodDays(int n) {
    return '$n días';
  }

  @override
  String get statsPeriodThisYear => 'Este año';

  @override
  String get statsPeriodAll => 'Todo';

  @override
  String get statsByMonthOrYear => 'Por mes / año…';

  @override
  String get statsByYear => 'Por año';

  @override
  String get statsByMonth => 'Por mes';

  @override
  String get statsPlaysLabel => 'Reproducciones';

  @override
  String get statsTracksLabel => 'Pistas';

  @override
  String get statsArtistsLabel => 'Artistas';

  @override
  String get statsAlbumsLabel => 'Álbumes';

  @override
  String get statsListenTime => 'Tiempo de escucha';

  @override
  String get statsByCollection => 'Por colección';

  @override
  String get statsByFormat => 'Por formato';

  @override
  String get statsByEngine => 'Por motor';

  @override
  String get statsPlaylistsLabel => 'Listas';

  @override
  String get statsLocalFilesSection => 'Archivos descargados';

  @override
  String get statsFilesLabel => 'Archivos';

  @override
  String get statsSpaceLabel => 'Espacio en disco';

  @override
  String get statsNoPlaysInPeriod => 'Ninguna reproducción en este periodo';

  @override
  String get statsNoPlays => 'Ninguna reproducción';

  @override
  String get statsTopTracks => 'Top de pistas';

  @override
  String get statsTopAlbums => 'Top de álbumes';

  @override
  String get statsTopArtists => 'Top de artistas';

  @override
  String statsTopTracksIn(String period) {
    return 'Top de pistas — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top de álbumes — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top de artistas — $period';
  }

  @override
  String get statsSeeAll => 'Ver todo';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n reproducciones',
      one: '$n reproducción',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas',
      one: '$n pista',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'máx. $n';
  }

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRename => 'Renombrar';

  @override
  String get commonSort => 'Ordenar';

  @override
  String get commonPlayAll => 'Reproducir todo';

  @override
  String get sortName => 'Nombre';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortAlbum => 'Álbum';

  @override
  String get sortDateAdded => 'Fecha de adición';

  @override
  String get commonClear => 'Borrar';

  @override
  String get sortRecentlyModified => 'Modificadas recientemente';

  @override
  String get sortCreationDate => 'Fecha de creación';

  @override
  String get playlistNameHint => 'Nombre';

  @override
  String get playlistNew => 'Nueva lista de reproducción';

  @override
  String get playlistNewFolder => 'Nueva carpeta';

  @override
  String get playlistNewTooltip => 'Nueva lista / carpeta';

  @override
  String get playlistAddTo => 'Añadir a la lista de reproducción';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Añadir a $n listas',
      one: 'Añadir a $n lista',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Selecciona una lista de reproducción';

  @override
  String get playlistFilterHint => 'Filtrar las listas…';

  @override
  String get playlistSearchHint => 'Buscar una lista…';

  @override
  String get playlistNoMatch => 'Ninguna lista coincide';

  @override
  String get playlistNoneCreateHint => 'Ninguna lista — crea una con +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas',
      one: '$n pista',
      zero: 'Ninguna pista',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Ya están';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementos ya están en las listas seleccionadas.',
      one: '$n elemento ya está en las listas seleccionadas.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Ignorar los duplicados';

  @override
  String get playlistAddAgain => 'Añadir de nuevo';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas añadidas',
      one: '$n pista añadida',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m listas',
      one: '$n lista',
    );
    return '$_temp0 a $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'No se ha podido añadir: $error';
  }

  @override
  String get playlistRenameTitle => 'Renombrar la lista de reproducción';

  @override
  String playlistDeleteFolderTitle(String name) {
    return '¿Eliminar la carpeta “$name”?';
  }

  @override
  String get playlistDeleteFolderBody => 'Su contenido pasa al nivel superior.';

  @override
  String get playlistEmpty => 'Lista vacía';

  @override
  String get playlistRemoveEntry => 'Quitar de la lista de reproducción';

  @override
  String get trackOptionsAddToLibrary => 'Añadir a la biblioteca';

  @override
  String get trackOptionsRemoveFromLibrary => 'Quitar de la biblioteca';

  @override
  String get trackOptionsAddedToLibrary => 'Pista añadida a la biblioteca';

  @override
  String get trackOptionsRemovedFromLibrary => 'Pista quitada de la biblioteca';

  @override
  String get trackOptionsViewAlbum => 'Ver el álbum';

  @override
  String get trackOptionsViewArtist => 'Ver el artista';

  @override
  String get trackOptionsPlayNow => 'Reproducir ahora';

  @override
  String get trackOptionsPlayNext => 'Reproducir a continuación';

  @override
  String get trackOptionsAddToQueueEnd => 'Añadir al final de la cola';

  @override
  String get trackOptionsPlayLast => 'Reproducir al final';

  @override
  String get trackOptionsDeleteDownload => 'Eliminar la descarga';

  @override
  String get trackOptionsDeleteDownloadTitle => '¿Eliminar esta descarga?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Se eliminarán el archivo y sus entradas locales (historial, pistas).\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Descarga eliminada';

  @override
  String get trackOptionsAddToFavorites => 'Añadir a favoritos';

  @override
  String get trackOptionsRemoveFromFavorites => 'Quitar de favoritos';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Álbum añadido a favoritos';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Álbum quitado de favoritos';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Álbum no descargado — no hay nada que eliminar';

  @override
  String get trackOptionsDeleteAlbumTitle => '¿Eliminar el álbum descargado?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Se eliminarán la carpeta y todas sus entradas locales (pistas, historial).\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Álbum eliminado del almacenamiento local';

  @override
  String get trackOptionsRedownloadAlbum => 'Volver a descargar el álbum';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Reescribe los archivos Y las entradas locales';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Eliminar los archivos del álbum';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Carpeta descargada + entradas locales (historial)';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralSubtitle => 'Tema';

  @override
  String get settingsVisualisation => 'Visualización';

  @override
  String get settingsVisualisationSubtitle => 'Osciloscopios, portada de fondo';

  @override
  String get settingsPlayback => 'Reproducción';

  @override
  String get settingsPlaybackSubtitle => 'Bucles, fundido, silencio';

  @override
  String get settingsEngines => 'Motores';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Datos';

  @override
  String get settingsDataSubtitle => 'Identificador, historial, restablecer';

  @override
  String get settingsBackupExport => 'Exportar una copia de seguridad';

  @override
  String get settingsBackupExportSubtitle =>
      'Guarda tu biblioteca, listas y ajustes en un archivo';

  @override
  String get settingsBackupImport => 'Importar una copia de seguridad';

  @override
  String get settingsBackupImportSubtitle =>
      'Restaura tus datos desde un archivo de copia de seguridad';

  @override
  String get settingsBackupExportFailed =>
      'Error al exportar la copia de seguridad';

  @override
  String get settingsBackupImportConfirmTitle =>
      '¿Importar la copia de seguridad?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Esto reemplaza tu biblioteca, listas y ajustes en este dispositivo. Los archivos descargados se conservan.';

  @override
  String get settingsBackupImportConfirm => 'Importar';

  @override
  String get settingsBackupImportedTitle => 'Copia de seguridad importada';

  @override
  String get settingsBackupImportedBody =>
      'Tus datos se han restaurado. Reinicia la app para aplicarlo todo.';

  @override
  String get settingsBackupTooNew =>
      'Esta copia se creó con una versión más reciente de la app';

  @override
  String get settingsBackupInvalid =>
      'No es una copia de seguridad de Rewamp válida';

  @override
  String get settingsBackupImportFailed =>
      'Error al importar la copia de seguridad';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsAboutSubtitle => 'Créditos y licencias';

  @override
  String get settingsCreditsSubtitle => 'Bibliotecas, datos y componentes';

  @override
  String get settingsSupport => 'Contacto y soporte';

  @override
  String get settingsSupportSubtitle => 'Contáctanos, sitio web';

  @override
  String get settingsSupportEmail => 'Enviar un correo';

  @override
  String get settingsSupportEmailSubtitle => 'Pregunta, error o sugerencia';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — soporte';

  @override
  String get settingsSupportEmailIntro =>
      'Describe arriba tu pregunta, error o sugerencia. La información de abajo nos ayuda a ayudarte.';

  @override
  String get settingsSupportWebsite => 'Sitio web';

  @override
  String get settingsDonation => 'Apoyar Rewamp';

  @override
  String get settingsDonationSubtitle => 'Una propina, si te apetece';

  @override
  String get settingsDonationBlurb =>
      'Rewamp es gratis y sin anuncios — un trabajo hecho con pasión dedicado a preservar la cultura demoscene y retro. Las propinas ayudan a financiar el desarrollo de la app y a cubrir los costes de alojamiento de la base de datos. Sin obligación: si la app te gusta, un pequeño gesto siempre se agradece.';

  @override
  String get settingsDonationFloppy => 'Un disquete';

  @override
  String get settingsDonationCartridge => 'Un cartucho';

  @override
  String get settingsDonationBox => 'Un juego en caja';

  @override
  String get settingsDonationCustom => 'Elegir un importe';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Eliminar';

  @override
  String get settingsReset => 'Restablecer';

  @override
  String get settingsRenew => 'Renovar';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Infinito';

  @override
  String get settingsDefault => 'Por defecto';

  @override
  String get settingsCoreNoScope => 'sin osciloscopio';

  @override
  String get settingsNone => 'Ninguno';

  @override
  String get settingsLevelLow => 'Bajo';

  @override
  String get settingsLevelHigh => 'Alto';

  @override
  String get settingsStereo => 'Estéreo';

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
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsArtworkTintTitle => 'Teñir el reproductor con la portada';

  @override
  String get settingsArtworkTintSubtitle =>
      'El reproductor adopta el color dominante de la portada';

  @override
  String get settingsGlassEffectTitle => 'Efecto liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lente y desenfoque en las barras inferiores — desactívalo en dispositivos lentos';

  @override
  String get settingsResetSection => 'Restablecer esta sección';

  @override
  String get settingsResetEngine => 'Restablecer este motor';

  @override
  String get settingsResetChoices => 'Restablecer estas opciones';

  @override
  String get settingsResetToDefault => 'Valor por defecto';

  @override
  String get settingsStartInVizTitle => 'Iniciar en modo visualizador';

  @override
  String get settingsStartInVizSubtitle =>
      'El reproductor se abre en los osciloscopios en lugar de la portada';

  @override
  String get settingsVoiceGridTitle => 'Cuadrícula del osciloscopio de voces';

  @override
  String get settingsVoiceGridSubtitle =>
      'Muestra los bordes que separan cada voz';

  @override
  String get settingsKeepAwakeTitle => 'Mantener la pantalla encendida';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Mientras se muestra un visualizador, la pantalla no se atenúa ni se bloquea';

  @override
  String get settingsVoiceNamesTitle => 'Nombre de las voces';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Muestra el nombre de cada voz dentro de su marco';

  @override
  String get settingsLineThickness => 'Grosor del trazo';

  @override
  String get settingsColors => 'Colores';

  @override
  String get settingsScopeVoiceColor => 'Osciloscopio de voces';

  @override
  String get settingsStereoColors => 'Estéreo: colores';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Estéreo (mono)';

  @override
  String get settingsStereoLeftColor => 'Estéreo izquierda';

  @override
  String get settingsStereoRightColor => 'Estéreo derecha';

  @override
  String get settingsNotation => 'Notación (notas)';

  @override
  String get settingsNotePalette => 'Paleta de colores';

  @override
  String get settingsNoteBoxStyle => 'Estilo de los bloques';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'Efectos CRT';

  @override
  String get settingsCrtGlow => 'Halo (glow)';

  @override
  String get settingsCrtSpeed => 'Intensidad / velocidad';

  @override
  String get settingsArtworkOpacity => 'Opacidad de la portada de fondo';

  @override
  String get settingsProjectMTitle => 'Ajustes de projectM';

  @override
  String get settingsProjectMSubtitle =>
      'Presets, transiciones, calidad, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Notificaciones al cambiar de pista';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Notificación del sistema con el título de la nueva pista';

  @override
  String get settingsSilenceDetection => 'Detección de silencio';

  @override
  String get settingsSilenceSkipTitle =>
      'Pasar a la pista siguiente si hay silencio';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Avanza automáticamente cuando la salida permanece en silencio';

  @override
  String get settingsSilenceDelay => 'Retardo de silencio';

  @override
  String get settingsDefaultDuration => 'Duración por defecto';

  @override
  String get settingsDefaultDurationHelp =>
      'Se aplica cuando una pista no indica ninguna duración conocida (sin etiqueta, sin metadatos del servidor) — evita que suene o se repita indefinidamente. Nunca se aplica a las pistas de Amiga (UADE), que tienen su propia base de datos de duraciones.';

  @override
  String get settingsForcedLoopHeader => 'Bucle / fundido forzados';

  @override
  String get settingsForcedLoopHelp =>
      'Algunos formatos repiten una sección concreta (VGM, módulos tracker…); otros no. \"Infinito\" ignora el final natural de la pista.';

  @override
  String get settingsForceLoopCount => 'Forzar el número de bucles';

  @override
  String get settingsLoopCount => 'Número de bucles';

  @override
  String get settingsForceFadeout => 'Forzar un fundido de salida';

  @override
  String get settingsFadeoutDuration => 'Duración del fundido';

  @override
  String get settingsResetEnginesTitle =>
      '¿Restablecer los ajustes de los motores?';

  @override
  String get settingsResetEnginesBody =>
      'Todos los ajustes de los motores volverán a sus valores por defecto.';

  @override
  String get settingsResetDefaultsTitle =>
      'Restablecer los valores por defecto';

  @override
  String get settingsResetDefaultsSubtitle => 'Todos los motores';

  @override
  String get settingsDefaultDecoders => 'Decodificadores por defecto';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formatos que pueden reproducir varios motores';

  @override
  String get settingsDecodersHelp =>
      'Algunos formatos pueden reproducirse con varios motores. Elige cuál usar por defecto — los demás formatos se enrutan automáticamente.';

  @override
  String get settingsDecoderAmigaTrackers =>
      'Trackers de Amiga (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, estéreo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — calidad, filtros, opciones por chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — filtro paso alto';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont en uso';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolación, paso bajo, eco';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorámica, auriculares, ganancia, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — reloj, modelo, filtros ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — modo armónico estéreo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, reverb';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — cores YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Volumen maestro';

  @override
  String get settingsAmigaFilter => 'Filtro Amiga';

  @override
  String get settingsInterpolation => 'Interpolación';

  @override
  String get settingsPolyphony => 'Polifonía';

  @override
  String get settingsReverb => 'Reverberación';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Ninguna';

  @override
  String get settingsInterpLinear => 'Lineal';

  @override
  String get settingsInterpCubic => 'Cúbica';

  @override
  String get settingsInterpSinc => 'Sinc (la mejor)';

  @override
  String get settingsStereoSeparation => 'Separación estéreo';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Termina la pista cuando el motor detecta un silencio largo';

  @override
  String get settingsStereoDepth => 'Profundidad estéreo';

  @override
  String get settingsEqualizer => 'Ecualizador';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — sin efecto en SPC';

  @override
  String get settingsBass => 'Graves';

  @override
  String get settingsTreble => 'Agudos';

  @override
  String get settingsAppliedLive =>
      'Se aplica de inmediato, incluso durante la reproducción.';

  @override
  String get settingsAppliedNextTrack =>
      'Se aplica a la siguiente pista cargada.';

  @override
  String get settingsSidEmulation => 'Emulación';

  @override
  String get settingsSidResidfp => 'ReSIDfp (preciso)';

  @override
  String get settingsSidLite => 'SIDLite (rápido)';

  @override
  String get settingsSidSampling => 'Muestreo';

  @override
  String get settingsSidSamplingInterp => 'Interpolación (rápida)';

  @override
  String get settingsSidSamplingResample => 'Resample (la mejor)';

  @override
  String get settingsSidClock => 'Reloj';

  @override
  String get settingsSidModel => 'Modelo de SID';

  @override
  String get settingsSidFilter => 'Filtro SID';

  @override
  String get settingsSidForceSecond => 'Forzar un 2.º SID';

  @override
  String get settingsSidSecondSubtitle => 'Temas 2SID en estéreo';

  @override
  String get settingsSidSecondAddr => 'Dirección del 2.º SID';

  @override
  String get settingsSidForceThird => 'Forzar un 3.er SID';

  @override
  String get settingsSidThirdAddr => 'Dirección del 3.er SID';

  @override
  String get settingsSidAutoFilter => 'Rango del filtro 6581 automático';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Valor recomendado según el autor del tema (tablas de sidplayfp)';

  @override
  String get settingsSid6581Range => 'Rango del filtro 6581';

  @override
  String get settingsSid6581Curve => 'Curva del filtro 6581';

  @override
  String get settingsSid8580Curve => 'Curva del filtro 8580';

  @override
  String get settingsSidNote =>
      'El filtro SID y las curvas se aplican en directo; emulación/muestreo/reloj/modelo/2.º-3.er SID en la siguiente pista.';

  @override
  String get settingsAudioOutput => 'Salida de audio';

  @override
  String get settingsAdplugNote =>
      'Surround: dos chips OPL ligeramente desafinados. Se aplica a la siguiente pista.';

  @override
  String get settingsHeSpuMain => 'Voces principales (SPU)';

  @override
  String get settingsHeSpuReverb => 'Reverb (SPU)';

  @override
  String get settingsNsfQuality => 'Calidad (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Filtro paso bajo';

  @override
  String get settingsHighpassFilter => 'Filtro paso alto';

  @override
  String get settingsRegion => 'Región';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC forzado';

  @override
  String get settingsNsfRegionPalForced => 'PAL forzado';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy forzado';

  @override
  String get settingsNsfForceIrq => 'Forzar IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulses (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — triangle / ruido / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Reactivar el sonido al reiniciar';

  @override
  String get settingsNsfPhaseRefresh => 'Refrescar la fase';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Reinicia la fase al escribir el periodo';

  @override
  String get settingsNsfNonlinearMixer => 'Mezcla no lineal';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'La mezcla real del 2A03 (si no, lineal)';

  @override
  String get settingsNsfDutySwap => 'Intercambiar los duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Orden de los duty 25 % / 50 %';

  @override
  String get settingsNsfNegateSweep => 'Sweep negativo al iniciar';

  @override
  String get settingsNsfEnable4011 => 'Registro \$4011 activo';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Salida DAC directa (clics originales)';

  @override
  String get settingsNsfPeriodicNoise => 'Ruido periódico';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Modo corto del generador de ruido';

  @override
  String get settingsNsfDpcmAntiClick => 'Anticlic DPCM';

  @override
  String get settingsNsfRandomizeNoise => 'Ruido aleatorio al iniciar';

  @override
  String get settingsNsfTriangleMute => 'Silenciar el triangle';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Silencia el triangle en los periodos ultrasónicos';

  @override
  String get settingsNsfRandomizeTri => 'Triangle aleatorio al iniciar';

  @override
  String get settingsNsfDpcmReverse => 'DPCM invertido';

  @override
  String get settingsNsfN163Serial => 'Multiplexado serie';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'El zumbido real del N163 en temas multivoz';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fase de solo lectura';

  @override
  String get settingsNsfN163LimitWavelength => 'Limitar la longitud de onda';

  @override
  String get settingsNsfFdsCutoff => 'Corte del paso bajo';

  @override
  String get settingsNsfFds4085Reset => 'Reset de \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Protección contra escritura';

  @override
  String get settingsNsfVrc7Patch => 'Juego de patches';

  @override
  String get settingsNsfVrc7Opll => 'Modo OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Emula un YM2413 en lugar del VRC7';

  @override
  String get settingsGbsHpFilter => 'Filtro paso alto (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (GB clásica)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Eco';

  @override
  String get settingsUadePostfx => 'Posprocesado';

  @override
  String get settingsUadePostfxSubtitle =>
      'Activa la cadena de efectos (necesario para todo lo demás)';

  @override
  String get settingsUadePan => 'Panorámica (separación estéreo)';

  @override
  String get settingsUadePanValue => 'Valor de la panorámica';

  @override
  String get settingsUadeHeadphones => 'Auriculares';

  @override
  String get settingsUadeLed => 'LED (filtro Paula)';

  @override
  String get settingsUadeLedAuto => 'Auto (según el tema)';

  @override
  String get settingsUadeLedOn => 'Forzado ON';

  @override
  String get settingsUadeLedOff => 'Forzado OFF';

  @override
  String get settingsUadeFilterType => 'Tipo de filtro';

  @override
  String get settingsUadeGain => 'Ganancia';

  @override
  String get settingsUadeGainValue => 'Valor de la ganancia';

  @override
  String get settingsSoundfontLoading => 'Cargando el catálogo…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Catálogo no disponible ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Error en la descarga: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importar una SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Elegir un archivo .sf2 en este dispositivo';

  @override
  String get settingsSoundfontImported => 'Importada';

  @override
  String get settingsSoundfontInvalid =>
      'Ese archivo no es una SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Error al importar — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Eliminar el archivo';

  @override
  String get settingsCreditsHeader => 'Créditos y licencias';

  @override
  String get settingsRightsNotice =>
      'Rewamp es un reproductor: no aloja ningún archivo ni distribuye música. Las pistas provienen de archivos de preservación en línea y siguen siendo propiedad de sus titulares de derechos. Es responsabilidad suya comprobar que escucharlas, descargarlas y conservarlas cumple con los derechos aplicables y con la legislación de su país.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formatos compatibles',
      one: '$count formato compatible',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repartidos en $count motores de reproducción — ver el detalle',
      one: 'Gestionados por $count motor de reproducción — ver el detalle',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Duraciones y metadatos de Amiga';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb de Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Datos y carátulas de C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadatos y material visual de los juegos de C64.';

  @override
  String get settingsFt2FontTitle => 'Fuente FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'El estilo FastTracker II del visualizador de patrones usa la fuente FT2 de ft2-clone por 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url copiado';
  }

  @override
  String get settingsOpenLink => 'Abrir el enlace';

  @override
  String get settingsEnginesHeader => 'Motores de reproducción';

  @override
  String get settingsComponentsHeader => 'Otros componentes';

  @override
  String get settingsResetAll => 'Restablecer todos los ajustes';

  @override
  String get settingsResetAllSubtitle =>
      'General, Visualización, Reproducción, Motores — no la biblioteca';

  @override
  String get settingsResetAllTitle => '¿Restablecer todos los ajustes?';

  @override
  String get settingsResetAllBody =>
      'General, Visualización, Reproducción y todos los motores volverán a sus valores por defecto. Tu biblioteca y tu historial no se ven afectados.';

  @override
  String get settingsRenewUserId => 'Renovar el identificador anónimo';

  @override
  String get settingsRenewUserIdTitle => '¿Renovar el identificador anónimo?';

  @override
  String get settingsRenewUserIdBody =>
      'Se creará un nuevo identificador anónimo para las estadísticas del servidor.\n\nEl anterior dejará de usarse. Tu historial local y tus favoritos no se ven afectados.';

  @override
  String get settingsRenewUserIdFailed => 'Error — servidor inaccesible';

  @override
  String settingsNewUserId(String id) {
    return 'Nuevo identificador: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Ningún identificador registrado';

  @override
  String get settingsCleanDb => 'Limpiar la base de datos local';

  @override
  String get settingsCleanDbSubtitle =>
      'Elimina las entradas cuyo archivo ya no existe (descargas borradas, errores antiguos)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas huérfanas eliminadas',
      one: '$count entrada huérfana eliminada',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'La base de datos local está limpia — no hay nada que eliminar';

  @override
  String get settingsClearCache => 'Vaciar la caché (portadas y metadatos)';

  @override
  String get settingsClearCacheSubtitle =>
      'Elimina las portadas en caché y los metadatos recuperados (STIL, duraciones) — se vuelven a descargar en la siguiente reproducción';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Caché vaciada ($count portadas)',
      one: 'Caché vaciada ($count portada)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Restablecer las estadísticas';

  @override
  String get settingsResetStatsSubtitle =>
      'Elimina el historial de escucha y los contadores de reproducción';

  @override
  String get settingsClearStatsTitle => '¿Restablecer las estadísticas?';

  @override
  String get settingsClearStatsBody =>
      'Esta acción eliminará definitivamente:\n• todo el historial de escucha\n• los contadores de reproducción\n\nTus favoritos y tu biblioteca no se verán afectados.';

  @override
  String get settingsStatsCleared => 'Estadísticas eliminadas';

  @override
  String get settingsResetDatabase => 'Restablecer la base de datos';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Lo elimina todo: historial, favoritos, listas de reproducción, caché';

  @override
  String get settingsResetDbTitle => '¿Restablecer la base de datos?';

  @override
  String get settingsResetDbBody =>
      'Esta acción eliminará definitivamente:\n• todo el historial de escucha\n• todos los contadores\n• todos los favoritos\n• todas las listas de reproducción\n• todos los metadatos en caché\n\nTus archivos de audio no se eliminan.';

  @override
  String get settingsDbReset => 'Base de datos restablecida';

  @override
  String get settingsDeleteDownloads => 'Eliminar las descargas';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Elimina todos los archivos de la carpeta online (pistas, portadas)';

  @override
  String get settingsDeleteDownloadsTitle => '¿Eliminar las descargas?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Esta acción eliminará definitivamente todos los archivos descargados (pistas, álbumes, portadas) de la carpeta online.\n\nLas entradas de la base de datos permanecerán, pero apuntarán a archivos que ya no existen.';

  @override
  String get settingsDownloadsDeleted => 'Descargas eliminadas';

  @override
  String get settingsColor => 'Color';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Preset siguiente aleatorio';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Desactivado: reproduce los presets en orden';

  @override
  String get settingsPmLockPreset => 'Bloquear el preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Sin cambio automático';

  @override
  String get settingsPmPresetDuration => 'Tiempo entre presets';

  @override
  String get settingsPmTransitions => 'Transiciones';

  @override
  String get settingsPmBlend => 'Transición con fundido';

  @override
  String get settingsPmBlendSubtitle =>
      'Desactivado: cambio de preset instantáneo';

  @override
  String get settingsPmTransitionStyle => 'Estilo de transición';

  @override
  String get settingsPmTransitionStyleSubtitle => 'El patrón que usa la fusión';

  @override
  String get settingsPmTransitionRandom => 'Aleatorio';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Cambio de preset sincronizado con los beats';

  @override
  String get settingsPmHardcutTime => 'Hardcut: tiempo mínimo';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: sensibilidad';

  @override
  String get settingsPmRendering => 'Renderizado';

  @override
  String get settingsPmQuality => 'Calidad';

  @override
  String get settingsPmQualitySubtitle =>
      'Resolución de renderizado (Máx. = resolución nativa)';

  @override
  String get settingsPmBeatSensitivity => 'Sensibilidad al beat';

  @override
  String get settingsPmAspectRatio => 'Respetar la relación de aspecto';

  @override
  String get settingsPmAspectRatioSubtitle => 'Para los shaders compatibles';

  @override
  String get settingsPmPermissive => 'Modo permisivo';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Carga los archivos .milk con errores de script';

  @override
  String get accountTitle => 'Cuenta';

  @override
  String get accountSubtitle => 'Guarda y sincroniza tu biblioteca';

  @override
  String get accountAnonymous => 'Cuenta anónima';

  @override
  String get accountAnonymousExplain =>
      'Tus favoritos y tu historial se guardan en el servidor, pero solo este dispositivo puede acceder a ellos. Añade un correo electrónico para recuperarlos en otro sitio.';

  @override
  String get accountEmailAttached =>
      'Dirección confirmada — esta cuenta se puede restaurar';

  @override
  String get accountEmailPending => 'Dirección aún sin confirmar';

  @override
  String get accountInsecureStorage =>
      'El almacenamiento seguro de este dispositivo no está disponible: el identificador de la cuenta se guarda sin cifrar.';

  @override
  String get accountSaveCta => 'Guardar mi cuenta';

  @override
  String get accountStatSongs => 'Pistas favoritas';

  @override
  String get accountStatAlbums => 'Álbumes favoritos';

  @override
  String get accountStatPlays => 'Reproducciones';

  @override
  String get accountCreatedLabel => 'Creada';

  @override
  String get accountSignOut => 'Cerrar sesión';

  @override
  String get accountRevoke => 'Cerrar sesión en todas partes';

  @override
  String get accountRevokeSubtitle =>
      'Cierra la sesión en los demás dispositivos';

  @override
  String get accountRevokeBody =>
      'Los demás dispositivos se desconectan. Este sigue conectado.';

  @override
  String get accountRevokeDone => 'Otros dispositivos desconectados';

  @override
  String get accountDelete => 'Eliminar mi cuenta';

  @override
  String get accountDeleteSubtitle =>
      'Borra la cuenta y sus datos en el servidor. Irreversible.';

  @override
  String accountDeleteBody(int items, int lists) {
    return 'Se eliminarán del servidor $items favoritos y $lists listas. No se puede deshacer.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Tus descargas y la biblioteca de este dispositivo no se ven afectadas.';

  @override
  String get accountDeleteDone => 'Cuenta eliminada';

  @override
  String get accountSignOutSubtitle =>
      'Este dispositivo vuelve a una cuenta nueva y vacía';

  @override
  String get accountSignOutTitle => '¿Cerrar sesión?';

  @override
  String accountSignOutBody(String email) {
    return 'Podrás volver a esta cuenta con un código enviado a $email.';
  }

  @override
  String get accountSignedOut => 'Sesión cerrada';

  @override
  String get accountNoSignOut => 'No se puede cerrar sesión';

  @override
  String get accountNoSignOutSubtitle =>
      'Sin dirección de correo, esta cuenta se perdería para siempre.';

  @override
  String get accountDetach => 'Desvincular dirección';

  @override
  String get accountDetachSubtitle =>
      'La cuenta vuelve a ser anónima, no se borra ningún dato';

  @override
  String get accountDetachBody =>
      'Sin dirección, esta cuenta ya no se podrá recuperar desde otro dispositivo.';

  @override
  String get accountDetachDone => 'Dirección desvinculada';

  @override
  String get accountOffline => 'Cuenta no disponible sin conexión';

  @override
  String get accountEmailTitle => 'Correo electrónico';

  @override
  String get accountEmailExplain =>
      'Te enviamos un código de 6 dígitos para confirmar la dirección. Solo sirve para recuperar tu cuenta.';

  @override
  String get accountEmailLabel => 'Correo electrónico';

  @override
  String get accountCodeTitle => 'Código de confirmación';

  @override
  String accountCodeExplain(String email) {
    return 'Código enviado a $email. Es válido durante 10 minutos.';
  }

  @override
  String get accountCodeLabel => 'Código de 6 dígitos';

  @override
  String get accountSendCode => 'Enviar el código';

  @override
  String get accountVerify => 'Confirmar';

  @override
  String get accountResend => 'Reenviar el código';

  @override
  String accountResendIn(int n) {
    return 'Reenviar en $n s';
  }

  @override
  String get accountCheckSpam =>
      'El correo puede tardar un minuto — revisa la carpeta de spam.';

  @override
  String get accountErrorInvalidEmail => 'Dirección no válida';

  @override
  String get accountErrorTooMany =>
      'Demasiadas solicitudes, inténtalo dentro de unos minutos';

  @override
  String get accountErrorInvalidCode => 'Código incorrecto o caducado';

  @override
  String get accountErrorCodeLength => 'El código tiene 6 dígitos';

  @override
  String get accountErrorNetwork => 'No se pudo conectar, inténtalo de nuevo';

  @override
  String get accountMergeTitle => '¿Fusionar esta biblioteca?';

  @override
  String accountMergeBody(String email) {
    return 'Los favoritos y el historial de este dispositivo se añadirán a la cuenta $email. La operación es definitiva.';
  }

  @override
  String get accountMergeConfirm => 'Fusionar';

  @override
  String get accountCarryLocal => 'Conservar los favoritos de este dispositivo';

  @override
  String accountCarryLocalOn(int n) {
    return 'Los $n favoritos y las listas de este dispositivo se añaden a la cuenta.';
  }

  @override
  String get accountCarryLocalOff =>
      'Se eliminan de este dispositivo y se sustituyen por los de la cuenta. Las descargas se conservan.';

  @override
  String get accountDropLocalTitle =>
      '¿Eliminar los datos de este dispositivo?';

  @override
  String get accountCreatedOk => 'Cuenta guardada, tu biblioteca está a salvo';

  @override
  String get accountMergedOk =>
      'Sesión iniciada — se añadieron tus favoritos locales';

  @override
  String get accountSignedInOk => 'Sesión iniciada';

  @override
  String get playlistEntryMissing => 'Archivo ausente de este dispositivo';

  @override
  String get playlistEntryMissingRestorable =>
      'Archivo ausente — se puede volver a descargar';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ausentes',
      one: '$n ausente',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Guardar en mi cuenta';

  @override
  String get playlistBackupSubtitle =>
      'Conserva esta lista aunque reinstales la app';

  @override
  String get playlistBackupUpdate => 'Actualizar la copia';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Sustituye la copia de la cuenta por esta versión';

  @override
  String get playlistBackupStop => 'Dejar de guardar';

  @override
  String get playlistBackupStopped => 'Copia eliminada';

  @override
  String get playlistBackupDone => 'Lista guardada';

  @override
  String get playlistBackupFailed => 'No se pudo guardar';

  @override
  String get playlistBackupNoAccount => 'No hay cuenta en este dispositivo';

  @override
  String get playlistSyncTooltip => 'Sincronizar con mi cuenta';

  @override
  String get playlistSyncRunning => 'Sincronizando…';

  @override
  String get playlistSyncDone => 'Listas sincronizadas';

  @override
  String get playlistSyncPartial => 'Algunas listas no se pudieron guardar';

  @override
  String get playlistFetchMissing => 'Descargar las pistas ausentes';

  @override
  String get playlistFetchDone => 'Pistas ausentes descargadas';

  @override
  String get playlistFetchPartial => 'Algunas pistas no se pudieron descargar';

  @override
  String get playlistEntryFetchFailed => 'No se pudo descargar esta pista';

  @override
  String get accountStatPlaylists => 'Listas';

  @override
  String get accountSyncNow => 'Sincronizar ahora';

  @override
  String get accountSyncAuto => 'Se hace solo en segundo plano';

  @override
  String get accountSyncAnonymous =>
      'Copia guardada en el servidor. Añade un correo para sincronizar otro dispositivo.';

  @override
  String get accountSyncPending => 'Hay cambios pendientes de enviar';

  @override
  String accountSyncLast(String when) {
    return 'Última sincronización: $when';
  }

  @override
  String get accountSyncDone => 'Sincronización terminada';

  @override
  String get accountSyncFailed => 'Error de sincronización, se reintentará';

  @override
  String get podiumFirst => '1.º';

  @override
  String get podiumSecond => '2.º';

  @override
  String get podiumThird => '3.º';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'música de $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'contiene el $place de $compo';
  }

  @override
  String get competitionEmpty => 'Esta competición no tiene entradas';

  @override
  String get competitionEntryNoMusic =>
      'No hay música en el catálogo para esta entrada';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pistas',
      one: '$n pista',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStart => 'Empezar';

  @override
  String get onboardingBetaTitle => 'Versión beta';

  @override
  String get onboardingBetaBody =>
      'Rewamp aún está en construcción. Los datos locales — biblioteca, listas, favoritos, estadísticas — podrían borrarse antes de la versión 1.0. Tus descargas no corren peligro, pero guarda en otro sitio lo que te importe.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Versión $version (compilación $build)';
  }

  @override
  String get onboardingExploreTitle => 'Explorar';

  @override
  String get onboardingExploreBody =>
      'Recorre y busca decenas de miles de chiptunes y módulos de los grandes archivos en línea, por artista, álbum, plataforma o party. Toca para escuchar, descarga para conservar.';

  @override
  String get onboardingLibraryTitle => 'Tu biblioteca';

  @override
  String get onboardingLibraryBody =>
      'Guarda lo que te gusta, crea listas y organízalas en carpetas. Lo descargado suena sin conexión, y tu biblioteca te sigue entre dispositivos al iniciar sesión.';

  @override
  String get onboardingPlayerTitle => 'El reproductor';

  @override
  String get onboardingPlayerBody =>
      'Desliza para cambiar de pista y abre los visualizadores: osciloscopio, canales, notas en desplazamiento, rejilla tracker. Los archivos multipista muestran sus subcanciones y cada voz se silencia por separado.';

  @override
  String get onboardingReplayTitle => 'Presentación';

  @override
  String get onboardingReplaySubtitle =>
      'Ver de nuevo el aviso beta y el recorrido';

  @override
  String get settingsPatternTitle => 'Patrones';

  @override
  String get settingsPatternSubtitle =>
      'Rejilla tracker: colores, columnas, desplazamiento';

  @override
  String get patternOpaqueBg => 'Fondo opaco';

  @override
  String get patternOpaqueBgSubtitle => 'Oculta la carátula tras la rejilla';

  @override
  String get commonSave => 'Guardar';

  @override
  String get accountDisplayName => 'Nombre público';

  @override
  String get accountDisplayNameNotSet =>
      'Sin definir — necesario para publicar una lista';

  @override
  String get accountDisplayNameHint =>
      'El nombre con el que quieres aparecer acreditado.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Cambiarlo devuelve a revisión todas las listas que hayas publicado.';

  @override
  String get accountDisplayNameTaken =>
      'Ese nombre ya está cogido. Elige otro.';

  @override
  String get accountDisplayNameLength => 'Entre 2 y 40 caracteres.';

  @override
  String get accountDisplayNameSaved => 'Nombre público guardado';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Listas devueltas a revisión: $n';
  }

  @override
  String get playlistPublish => 'Hacer pública';

  @override
  String get playlistPublishSubtitle =>
      'Solicitar la publicación (con revisión previa)';

  @override
  String get playlistPublishTitle => '¿Publicar esta lista?';

  @override
  String get playlistPublishBody =>
      'Será visible para todos una vez aprobada, acreditada a tu nombre público. La portada sale de sus pistas.';

  @override
  String get playlistPublishCta => 'Solicitar';

  @override
  String get playlistPublishSubmitted => 'Enviada a revisión';

  @override
  String get playlistPublishPending => 'Esperando aprobación';

  @override
  String get playlistPublishApproved => 'Pública';

  @override
  String playlistPublishRejected(String reason) {
    return 'Rechazada: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Rechazada';

  @override
  String get playlistPublishNeedName =>
      'Elige el nombre con el que quieres aparecer acreditado';

  @override
  String get playlistPublishNeedTracks =>
      'Hacen falta al menos 5 pistas para publicar';

  @override
  String get playlistPublishHasLocal =>
      'Los archivos de tu dispositivo no se pueden publicar — los demás no pueden reproducirlos';

  @override
  String get playlistPublishTooManyPending =>
      'Ya tienes 3 listas esperando aprobación';

  @override
  String get playlistPublishRefused =>
      'Publicación rechazada: revisa las pistas y las solicitudes pendientes';

  @override
  String get playlistPublishFailed => 'No se pudo publicar';

  @override
  String get playlistPublishWithdrawn => 'La lista vuelve a ser privada';

  @override
  String get playlistUnpublish => 'Hacer privada';

  @override
  String get playlistUnpublishSubtitle => 'La retira de las listas públicas';

  @override
  String get playlistRenamePublishedTitle => '¿Renombrar una lista publicada?';

  @override
  String get playlistRenamePublishedBody =>
      'Lo que se revisa es el nombre: renombrarla la devuelve a revisión y la despublica mientras tanto. Añadir o reordenar pistas, no.';

  @override
  String playlistByAuthor(String author) {
    return 'por $author';
  }

  @override
  String get settingsSpectrumMode => 'Modo del espectro';

  @override
  String get settingsSpectrumModeStandard => 'Estándar';

  @override
  String get settingsSpectrumModeColored => 'Coloreado';

  @override
  String get settingsSpectrumModeBeam => 'Haz';

  @override
  String get settingsSpectrumModeLine => 'Línea';

  @override
  String get settingsSpectrumModeRing => 'Anillo';

  @override
  String get releaseNotesTitle => 'Novedades';

  @override
  String get releaseNotesV4Downloads =>
      'Descargas: una descarga larga se puede cancelar mientras corre, y el archivo de un álbum ya no se baja varias veces.';

  @override
  String get releaseNotesV4Queue =>
      'Cola: un botón para vaciarla, con confirmación — también detiene la reproducción.';

  @override
  String get releaseNotesV4DropFiles =>
      'Archivos soltados en la ventana: elegir reproducir ahora, a continuación o al final; carátulas y archivos acompañantes quedan fuera, y se respeta la lista incluida en un archivo comprimido (títulos reales, sin pistas muertas).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: importa tu propia SoundFont desde el dispositivo, junto a las del servidor.';

  @override
  String get releaseNotesV4Formats =>
      'Los flujos de juego Wwise, FSB y OGL ya suenan (Vorbis propio).';

  @override
  String get releaseNotesV4Chips =>
      'Seis chips de sonido más, elección de núcleo de emulación por chip (SameBoy para Game Boy) y afinación correcta en los chips con muestras.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: los .vt2 suenan, y las vistas de notas y patrones cubren toda la familia ZX.';

  @override
  String get releaseNotesV4Loop =>
      'Repetir pista repite de verdad en lugar de recargarla, y el contador ya no se congela en bucle infinito.';

  @override
  String get releaseNotesV4Info =>
      'El panel ⓘ enumera los archivos que una pieza abrió realmente — acompañantes y bibliotecas incluidos.';

  @override
  String get releaseNotesV4Linux => 'Versión Linux para escritorio.';

  @override
  String get releaseNotesDataReset =>
      'Los datos locales se han restablecido para esta beta. La biblioteca y las listas se reconstruyen desde la cuenta; las descargas hay que rehacerlas.';

  @override
  String get releaseNotesDismiss => 'Continuar';

  @override
  String get pmManagePresets => 'Gestionar los presets';

  @override
  String get pmPickTooltip => 'Elegir un preset';

  @override
  String get pmPickFilter => 'Filtrar presets';

  @override
  String get pmSourceTooltip => 'Fuente de presets';

  @override
  String get pmAddToPlaylistTooltip =>
      'Añadir el preset a una lista de reproducción';

  @override
  String pmSlowPresetDropped(String name) {
    return '«$name» es demasiado pesado para este dispositivo y se ha descartado.';
  }

  @override
  String get pmSlowDeviceTitle => 'Este dispositivo es demasiado lento';

  @override
  String get pmSlowDeviceOff =>
      'Se ha desactivado el visualizador: este dispositivo no puede con los presets de Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets descartados',
      one: '1 preset descartado',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Demasiado lentos en este dispositivo. La reproducción los omite.';

  @override
  String get settingsPmSlowPresetsRestore => 'Restaurar';

  @override
  String get pmSourceBundled => 'Presets integrados';

  @override
  String get pmSourceImports => 'Mis importaciones';

  @override
  String get pmSourceAll => 'Todos los presets';

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
  String get pmNewPlaylist => 'Nueva lista de reproducción…';

  @override
  String get pmPlaylistName => 'Nombre de la lista de reproducción';

  @override
  String get pmAddedToPlaylist => 'Añadido a la lista de reproducción';

  @override
  String get pmAlreadyInPlaylist => 'Ya está en esta lista de reproducción';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Explorar';

  @override
  String get pmTabPlaylists => 'Listas de reproducción';

  @override
  String get pmTabPopular => 'Populares';

  @override
  String get pmTabSetAside => 'Descartados';

  @override
  String get pmSetAsideEmpty =>
      'Nada descartado. Aquí van los presets que hacen bajar este dispositivo de 6 fps.';

  @override
  String get pmSetAsideRestoreAll => 'Restaurar todo';

  @override
  String get pmInstall => 'Instalar';

  @override
  String get pmInstallQueued => 'Instalación en cola';

  @override
  String get pmUninstall => 'Desinstalar';

  @override
  String get pmUninstalled => 'Pack eliminado';

  @override
  String get pmUse => 'Usar';

  @override
  String get pmDefaultPackBanner => 'Pack inicial recomendado';

  @override
  String pmLicense(String license) {
    return 'Licencia: $license';
  }

  @override
  String get pmPacksOffline => 'Servidor inaccesible';

  @override
  String get pmSearchPresets => 'Buscar presets…';

  @override
  String get pmPlayNow => 'Reproducir ahora';

  @override
  String get pmDownloadAction => 'Descargar';

  @override
  String get pmDownloaded => 'Preset descargado';

  @override
  String get pmDownloadFailed => 'Error al descargar';

  @override
  String pmPreviewing(String name) {
    return 'Reproduciendo: $name';
  }

  @override
  String get pmLocalSection => 'Mis listas de reproducción';

  @override
  String get pmCuratedSection => 'Listas de reproducción de Rewamp';

  @override
  String get pmImportPlaylist => 'Descargar y usar';

  @override
  String get pmPlaylistImported => 'Lista de reproducción preparada';

  @override
  String get pmImportFiles => 'Importar archivos…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets importados',
      one: '$count preset importado',
      zero: 'Ningún preset importado',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported =>
      'Presets añadidos a la biblioteca de projectM';

  @override
  String get pmNoPlaylists => 'Aún no hay listas de reproducción de presets';

  @override
  String get pmSourceApplied => 'Fuente de presets aplicada';

  @override
  String get pmPlaylistEmpty => 'Esta lista de reproducción está vacía';

  @override
  String get pmDays7 => '7 días';

  @override
  String get pmDays30 => '30 días';

  @override
  String get pmDays365 => '1 año';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproducciones',
      one: '$count reproducción',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Error de instalación';

  @override
  String get pmSingleDownloads => 'Descargas individuales';

  @override
  String pmAvailableIn(String pack) {
    return 'Disponible en $pack';
  }

  @override
  String get pmCleanUp => 'Limpiar';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets eliminados',
      one: '$count preset eliminado',
      zero: 'Nada que limpiar',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Bloquear este preset';

  @override
  String get pmUnlockAction => 'Desbloquear el preset';

  @override
  String get pmOrderRandom => 'Presets al azar';

  @override
  String get pmOrderSequential => 'Presets en orden';

  @override
  String get pmUpdateAvailable => 'Actualización disponible';

  @override
  String get pmUpdate => 'Actualizar';

  @override
  String get pmSelectAll => 'Seleccionar todo';

  @override
  String get pmSelectNone => 'Deseleccionar todo';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '$count seleccionado',
      zero: 'Nada seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Texturas sin usar';

  @override
  String pmTexturesFreed(String size) {
    return '$size liberados';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count texturas',
      one: '$count textura',
    );
    return '$_temp0';
  }
}
