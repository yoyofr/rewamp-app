// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get navHome => 'Início';

  @override
  String get navSearch => 'Pesquisa';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get noFileSelected => 'Nenhum ficheiro selecionado';

  @override
  String get openFile => 'Abrir ficheiro';

  @override
  String get pickerLabelAudio => 'Áudio';

  @override
  String get formatNotSupported => 'Formato não suportado';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Formato não suportado: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Não está neste dispositivo: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Ficheiro já não está no servidor: $file';
  }

  @override
  String get failedToLoadFile => 'Não foi possível carregar o ficheiro';

  @override
  String get libraryEmptyHint =>
      'Os teus artistas, álbuns e playlists\naparecerão aqui.';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryArtists => 'Artistas';

  @override
  String get libraryAlbums => 'Álbuns';

  @override
  String get libraryTracks => 'Faixas';

  @override
  String get libraryFavorites => 'Favoritos';

  @override
  String get libraryFavoritesSubtitle =>
      'Playlist automática das tuas faixas favoritas';

  @override
  String get libraryRecentlyAdded => 'Adicionados recentemente';

  @override
  String get libraryEmpty => 'Ainda não há nada aqui';

  @override
  String get libraryRemoved => 'Removido da biblioteca';

  @override
  String get searchHint => 'Pesquisar…';

  @override
  String get searchTypePlaceholder => 'Escreve um título, artista ou álbum…';

  @override
  String get searchNoResults => 'Sem resultados';

  @override
  String get searchDownloading => 'A transferir…';

  @override
  String searchError(String message) {
    return 'Erro: $message';
  }

  @override
  String get tabAll => 'Faixas';

  @override
  String get tabArtists => 'Artistas';

  @override
  String get tabAlbums => 'Álbuns';

  @override
  String get tabProductions => 'Produções';

  @override
  String get filterWithVideo => 'Com vídeo';

  @override
  String get videoUnavailable => 'Este vídeo está indisponível';

  @override
  String get noItems => 'Nenhum elemento';

  @override
  String get sortRelevance => 'Relevância';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'Reproduzidos recentemente';

  @override
  String get noRecentTracks => 'Nenhuma faixa reproduzida recentemente';

  @override
  String get openLocalFile => 'Abrir ficheiro local';

  @override
  String get playerSourceLocal => 'local';

  @override
  String get browseFiles => 'Explorar ficheiros';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total resultados';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded carregados…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded resultados';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded carregados — desliza para ver mais';
  }

  @override
  String countNLoaded(int n) {
    return '$n carregados';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n ficheiro(s)';
  }

  @override
  String get browseFilterByTitle => 'Filtrar por título…';

  @override
  String get browseNoSongs => 'Nenhuma música disponível';

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
  String get browsePlatformNameHint => 'Nome da plataforma…';

  @override
  String get browseByChip => 'Por chip de som';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'ex.: YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Por artista';

  @override
  String get browseByArtistSubtitle => 'Explorar os compositores';

  @override
  String get browseFilterByName => 'Filtrar por nome…';

  @override
  String get browseNoArtistFound => 'Nenhum artista encontrado';

  @override
  String get browseNoArtistsAvailable => 'Nenhum artista disponível';

  @override
  String get browseNoArtist => 'Nenhum artista';

  @override
  String get browseNoAlbum => 'Nenhum álbum';

  @override
  String get browseTopPacks => 'Melhores packs';

  @override
  String get browseTopPacksSubtitle => 'Os packs com melhor classificação';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Melhores packs — $collection';
  }

  @override
  String get browseLatestPacks => 'Últimos packs';

  @override
  String get browseLatestPacksSubtitle => 'As adições mais recentes';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Últimos packs — $collection';
  }

  @override
  String get browseAllSongs => 'Todas as músicas';

  @override
  String get browseAllSongsSubtitleAlpha => 'Explorar por ordem alfabética';

  @override
  String get browseAlphabetical => 'Por ordem alfabética';

  @override
  String browseAllLabel(String collection) {
    return 'Tudo — $collection';
  }

  @override
  String get browseCollections => 'Coleções';

  @override
  String browseFilesCount(String count) {
    return '$count ficheiros';
  }

  @override
  String get browseIndexing => 'Indexação em curso';

  @override
  String browseFilterFacet(String name) {
    return 'Filtrar $name…';
  }

  @override
  String get browseAllYears => 'Todos os anos';

  @override
  String get browseAllYearsSubtitle => 'Todas as músicas da demoparty';

  @override
  String get browseNoCompo => 'Nenhuma compo indexada para esta demoparty.';

  @override
  String get browseOthers => 'Outros';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n entradas — classificação',
      one: '$n entrada — classificação',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Reproduzir playlist';

  @override
  String get browsePlayAllRanked =>
      'Reproduzir tudo (por ordem de classificação)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas — ordem de classificação',
      one: '$n faixa — ordem de classificação',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Explorar por álbum';

  @override
  String get browsePlayAll => 'Reproduzir tudo';

  @override
  String get browseShuffle => 'Reprodução aleatória';

  @override
  String get browseSearchInFolder => 'Pesquisar nesta pasta…';

  @override
  String get browseFilterThisList => 'Filtrar esta lista…';

  @override
  String get browseSearchSubfolders => 'Pesquisar em subpastas';

  @override
  String get browseEmptyFolder => 'Pasta vazia';

  @override
  String browsePlaybackError(String message) {
    return 'Falha na reprodução: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas',
      one: '$n faixa',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Vista';

  @override
  String get browseViewList => 'Lista';

  @override
  String get browseViewGrid => 'Grelha';

  @override
  String get browseViewGridCompact => 'Grelha compacta';

  @override
  String get browseSearchAlbum => 'Pesquisar um álbum…';

  @override
  String get browseSearchArtist => 'Pesquisar um artista…';

  @override
  String get browsePlayAlbum => 'Reproduzir álbum';

  @override
  String get searchDownloadingAlbum => 'A transferir o álbum…';

  @override
  String get searchCategoryChip => 'Chips';

  @override
  String get searchCategoryGroup => 'Grupos';

  @override
  String get artistRealName => 'Nome verdadeiro';

  @override
  String get artistAliases => 'Pseudónimos';

  @override
  String get artistBorn => 'Nascimento';

  @override
  String get artistInterview => 'Entrevista';

  @override
  String get audioOutput => 'Saída de áudio';

  @override
  String get audioOutputSystemDefault => 'Padrão do sistema';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Notas';

  @override
  String get notePlacedBadge => 'Classificada na competição';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Ver músicas';

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
  String get searchCategoryYear => 'Ano';

  @override
  String get searchCategoryOrigin => 'Origem';

  @override
  String get searchCategoryProduction => 'Produção';

  @override
  String get searchCategoryProductionType => 'Tipos de prod';

  @override
  String get searchCategoryPublisher => 'Editoras';

  @override
  String get searchCategoryDeveloper => 'Desenvolvedores';

  @override
  String get searchCategoryArcadeBoard => 'Placas de arcade';

  @override
  String get searchCategorySaga => 'Saga';

  @override
  String get searchCategoryGenre => 'Género';

  @override
  String get searchViaArtist => 'via artista';

  @override
  String get searchViaAlbum => 'via um álbum';

  @override
  String get searchViaSong => 'via uma música';

  @override
  String get searchSortPopular => 'Popular';

  @override
  String get searchSortYear => 'Ano';

  @override
  String get searchSortRandom => 'Aleatório';

  @override
  String get searchSortRating => 'Avaliação';

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
  String get searchSortAsc => 'Crescente';

  @override
  String get searchSortDesc => 'Decrescente';

  @override
  String get searchFilters => 'Filtros';

  @override
  String get searchExactSearch => 'Pesquisa exata';

  @override
  String get searchExactSearchSubtitle =>
      'Desativa a pesquisa aproximada (fuzzy)';

  @override
  String get searchTags => 'Tags';

  @override
  String searchTagSearchHint(String category) {
    return 'Pesquisar uma tag em « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Escreve para pesquisar tags.';

  @override
  String get searchTagsAndLogic => 'Várias tags = E lógico.';

  @override
  String get searchFilterYear => 'Ano';

  @override
  String get searchFilterAll => 'todos';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Filtrar por ano exclui as músicas sem data.';

  @override
  String get searchMinRating => 'Classificação ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Cancelar';

  @override
  String get searchReset => 'Repor';

  @override
  String get searchApply => 'Aplicar';

  @override
  String get searchClearRecent => 'Limpar pesquisas recentes';

  @override
  String get searchBrowse => 'Explorar';

  @override
  String get searchBrowseHint =>
      'Escolhe uma faceta (grupo, chip, ano…) para explorar o catálogo, ou inicia Rádio/Surpresa acima.';

  @override
  String get searchDidYouMean =>
      'Poucos resultados — tentar uma pesquisa aproximada?';

  @override
  String get searchYes => 'Sim';

  @override
  String get featuredCommunityTitle => 'Novidades da comunidade';

  @override
  String get searchPlaylistSourceAll => 'Todas';

  @override
  String get searchPlaylistSourceUser => 'Comunidade';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formato';

  @override
  String get searchPlatform => 'Plataforma';

  @override
  String get filterCollection => 'Coleção';

  @override
  String get videoWatchDemo => 'Ver a demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Coleção: $name';
  }

  @override
  String get searchCollectionAll => 'Todas';

  @override
  String get searchRadio => 'Rádio';

  @override
  String get searchRadioTooltip => 'Fila aleatória com os filtros atuais';

  @override
  String get searchSurprise => 'Surpresa';

  @override
  String get searchSurpriseTooltip => 'Uma música ao acaso';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Nenhuma música';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n músicas',
      one: '$n música',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n álbuns',
      one: '$n álbum',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Escolher uma coleção';

  @override
  String get searchFilterCollections => 'Filtrar as coleções…';

  @override
  String get searchFilterPlaceholder => 'Filtrar…';

  @override
  String searchAllOf(String label) {
    return 'Todos ($label)';
  }

  @override
  String get searchNoMatch => 'Nenhuma correspondência';

  @override
  String get searchNoPlaylist => 'Nenhuma playlist';

  @override
  String get engineDescOpenmpt => 'Módulos tracker (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — chips de som, scope por canal';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + arquivos RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — vozes por canal';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (motor reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'Chiptunes MSX (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Chiptunes multi-chip .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Formatos Amiga custom-chip via emulação 68k (~320 exts)';

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
      'Nintendo DS .ncsf/.minincsf — sintetizador SDAT/SSEQ (16 vozes)';

  @override
  String get engineDescV2m => 'Sintetizador V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — emulação real do 68000 + YM2149 + DAC STE';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — emulação R4300 + áudio RSP';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — emulação NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + chip QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — sintetizador AY-3-8910/YM2149 real';

  @override
  String get engineDescOrganya => 'Cave Story .org — o motor do próprio Pixel';

  @override
  String get engineDescPxtone => 'O tracker do Pixel — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — 68000 real via emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver do PC-98 — FM OPNA + SSG + amostras PPZ8';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ amostras .pdx), FM YM2151';

  @override
  String get engineDescFmp =>
      'Driver FMP do PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY do FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Formatos de áudio de jogos em streaming (700+, incl. .rrds)';

  @override
  String get engineDescMiniaudio =>
      'PCM/MP3/FLAC/OGG — descodificador de recurso';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total músicas',
      one: '$loaded / 1 música',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total álbuns',
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
      other: '$n músicas',
      one: '$n música',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n álbuns',
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
  String get browseFoldersCard => 'Pastas';

  @override
  String get featuredTitle => 'Em destaque hoje';

  @override
  String featuredPartyNow(String party) {
    return '$party está a decorrer neste momento — os pódios das edições anteriores';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          '$party começa dentro de $days dias — os pódios das edições anteriores',
      one: '$party começa amanhã — os pódios das edições anteriores',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'Época de $series — os pódios das edições anteriores';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Lançado em $month de $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Há $age anos: os jogos de $year',
      one: 'Há um ano: os jogos de $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return 'Os anos $decade';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Há $age anos: os jogos de $year',
      one: 'Há um ano: os jogos de $year',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Lançados em $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Aniversários';

  @override
  String get featuredBirthdayHeader => 'Aniversários de hoje';

  @override
  String get featuredBirthdayWeekHeader => 'Aniversários da semana';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return 'Aniversário de $artist esta semana';
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
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonOptions => 'Opções';

  @override
  String get commonDownload => 'Transferir';

  @override
  String get commonDeleteDownload => 'Eliminar a transferência';

  @override
  String get commonAddToPlaylist => 'Adicionar à playlist';

  @override
  String get commonPlayNext => 'Reproduzir a seguir';

  @override
  String get commonAddToQueueEnd => 'Adicionar ao fim da fila';

  @override
  String get commonAddToFavorites => 'Adicionar aos favoritos';

  @override
  String get commonRemoveFromFavorites => 'Remover dos favoritos';

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
  String get subsongDeleteDownloadTitle => 'Eliminar esta transferência?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'O ficheiro e as suas entradas locais (histórico, faixas) serão eliminados.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Não foi possível ler as faixas';

  @override
  String subsongTrackNumber(int number) {
    return 'Faixa $number';
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
  String get subsongPlayAll => 'Reproduzir tudo';

  @override
  String get albumDownloading => 'A transferir o álbum…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'A transferir o álbum… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks => 'Transfere o álbum para ver as faixas';

  @override
  String get albumNotDownloadedHint =>
      'Álbum não transferido — inicia a reprodução para o transferir';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '$count faixa',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'A carregar os detalhes…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Reproduzir álbum';

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
      'Reproduz esta faixa a partir da pesquisa para a transferir primeiro';

  @override
  String get libraryAddedTrack => 'Faixa adicionada à biblioteca';

  @override
  String get libraryAddedAlbum => 'Álbum adicionado à biblioteca';

  @override
  String get libraryAddedArtist => 'Artista adicionado à biblioteca';

  @override
  String get libraryRemovedTrack => 'Faixa removida da biblioteca';

  @override
  String get libraryRemovedAlbum => 'Álbum removido da biblioteca';

  @override
  String get libraryRemovedArtist => 'Artista removido da biblioteca';

  @override
  String songTilePlayFailed(String message) {
    return 'Falha na reprodução: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Falha na transferência — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'A transferir — $label';
  }

  @override
  String get downloadsTitle => 'Transferências';

  @override
  String get downloadsEmpty => 'Nenhuma transferência pendente';

  @override
  String get downloadsPause => 'Pausar';

  @override
  String get downloadsResume => 'Retomar';

  @override
  String get downloadsCancel => 'Cancelar transferência';

  @override
  String get downloadsClear => 'Remover tudo';

  @override
  String get downloadsPausedBanner =>
      'Transferências em pausa — o ficheiro atual termina primeiro';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'A transferir — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Playlist';

  @override
  String get miniPlayerHideQueue => 'Ocultar a playlist';

  @override
  String get transportShuffle => 'Reprodução aleatória';

  @override
  String get transportShuffleOn => 'Reprodução aleatória ativada';

  @override
  String get transportLoopOff => 'Repetição desativada';

  @override
  String get transportLoopQueue => 'Repetição: fila';

  @override
  String get transportLoopTrack => 'Repetição: faixa atual';

  @override
  String get vizStereo => 'Estéreo';

  @override
  String get vizSpectrum => 'Espectro';

  @override
  String get vizVoices => 'Vozes';

  @override
  String get vizNotes => 'Notas';

  @override
  String get vizPatterns => 'Padrões';

  @override
  String get patternScrollMode => 'Modo de rolagem';

  @override
  String get patternSmoothScroll => 'Deslocamento suave';

  @override
  String get patternVolumeBars => 'Barras de volume';

  @override
  String get patternColorScheme => 'Esquema de cores';

  @override
  String get patternSize => 'Tamanho';

  @override
  String get patternColumns => 'Colunas';

  @override
  String get patternColumnsAll => 'Completo';

  @override
  String get patternColumnsNoteInstr => 'Reduzido';

  @override
  String get patternColumnsNote => 'Mínimo';

  @override
  String get vizClose => 'Fechar o visualizador';

  @override
  String get vizFullscreen => 'Ecrã inteiro';

  @override
  String get vizExitFullscreen => 'Sair do ecrã inteiro';

  @override
  String get vizPrevPreset => 'Preset anterior';

  @override
  String get vizNextPreset => 'Preset seguinte';

  @override
  String get vizProjectmUnavailable => 'projectM indisponível';

  @override
  String get voicesTitle => 'Vozes';

  @override
  String get voicesNone => 'Nenhuma voz para esta faixa.';

  @override
  String get voicesLongPressSolo => 'toque longo = solo';

  @override
  String get voicesMuteAll => 'Silenciar tudo';

  @override
  String get voicesUnmuteAll => 'Ativar tudo';

  @override
  String get voicesStereoOutput => 'Saída estéreo';

  @override
  String get voicesLeft => 'Esquerda';

  @override
  String get voicesRight => 'Direita';

  @override
  String get enginesFormatsTitle => 'Formatos reproduzíveis';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats formatos reproduzíveis, repartidos por $engines motores de reprodução.';
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
    return 'Versão de $title de $artist';
  }

  @override
  String stilCover(String work) {
    return 'Versão de $work';
  }

  @override
  String get playerQueue => 'Fila';

  @override
  String get queueEdit => 'Editar';

  @override
  String get queueEditDone => 'Concluído';

  @override
  String get queueClear => 'Limpar a fila';

  @override
  String get queueClearConfirmTitle => 'Limpar a fila?';

  @override
  String get queueClearConfirmBody =>
      'A fila será esvaziada e a reprodução será interrompida.';

  @override
  String get queueClearConfirm => 'Limpar';

  @override
  String get queueRemoveSelected => 'Remover seleção';

  @override
  String get queueRemoveTrack => 'Remover da fila';

  @override
  String get queueReorder => 'Reordenar';

  @override
  String get playerArtwork => 'Artwork';

  @override
  String get playerVisualizer => 'Visualizador';

  @override
  String get playerVoices => 'Vozes';

  @override
  String get playerTrackInfo => 'Informações da faixa';

  @override
  String get playerShowQueue => 'Playlist';

  @override
  String get playerHideQueue => 'Ocultar a playlist';

  @override
  String get playerNoTrackInfo => 'Nenhuma informação disponível.';

  @override
  String get playerViewSubsongs => 'Ver os subsongs';

  @override
  String get playerViewAlbum => 'Ver o álbum';

  @override
  String get playerViewArtist => 'Ver o artista';

  @override
  String get playerAddToPlaylist => 'Adicionar à playlist';

  @override
  String get queueAddToPlaylist => 'Adicionar a fila a uma playlist';

  @override
  String get playerMoreOptions => 'Mais opções';

  @override
  String get playerClose => 'Fechar';

  @override
  String get playerCancel => 'Cancelar';

  @override
  String get playerDelete => 'Eliminar';

  @override
  String get playerAddFavorite => 'Adicionar aos favoritos';

  @override
  String get playerRemoveFavorite => 'Remover dos favoritos';

  @override
  String get playerAddToLibrary => 'Adicionar à biblioteca';

  @override
  String get playerRemoveFromLibrary => 'Remover da biblioteca';

  @override
  String get playerAddedToLibrary => 'Faixa adicionada à biblioteca';

  @override
  String get playerRemovedFromLibrary => 'Faixa removida da biblioteca';

  @override
  String get playerDeleteDownload => 'Eliminar a transferência';

  @override
  String get playerRedownload => 'Baixar o ficheiro novamente';

  @override
  String get playerRedownloadUnavailable =>
      'Não é possível baixar novamente este ficheiro';

  @override
  String get playerDeleteDownloadTitle => 'Eliminar a transferência?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'O ficheiro e as suas entradas locais (histórico, faixas) serão eliminados.\n\n$path';
  }

  @override
  String get homeYourTrends => 'As tuas tendências';

  @override
  String get homeYourAllTimeTop => 'O teu top de sempre';

  @override
  String get homeTrending => 'Tendências';

  @override
  String get homeFeaturedPlaylists => 'Playlists em destaque';

  @override
  String get homeAllTimeTop => 'Top de sempre';

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
      other: '$n reproduções',
      one: '$n reprodução',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas',
      one: '$n faixa',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Playlist vazia ou ilegível';

  @override
  String get homeExtractingArchive => 'A extrair o arquivo…';

  @override
  String get homeArchiveEmpty => 'Nenhum ficheiro reproduzível no arquivo';

  @override
  String get homeNothingPlayable => 'Nada reproduzível na seleção';

  @override
  String get homeAlbumLoadFailed => 'Não foi possível carregar este álbum';

  @override
  String get homeSongLoadFailed => 'Não foi possível carregar esta faixa';

  @override
  String get navStats => 'Estatísticas';

  @override
  String get navSettings => 'Definições';

  @override
  String get playlistMoveUp => 'Mover para a pasta acima';

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
      other: '$n subpastas',
      one: '$n subpasta',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Esta pasta e todo o seu conteúdo serão eliminados permanentemente:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Esta pasta será eliminada.';

  @override
  String get playlistFolderRoot => 'Raiz';

  @override
  String get playlistMoveToFolder => 'Mover para pasta';

  @override
  String playlistDeleteTitle(String name) {
    return 'Eliminar «$name»?';
  }

  @override
  String get playlistDeleteBody => 'Esta lista será eliminada permanentemente.';

  @override
  String get playlistRenameFolderTitle => 'Renomear pasta';

  @override
  String get playlistClearFavorites => 'Eliminar todos os favoritos';

  @override
  String get playlistClearFavoritesTitle => 'Eliminar todos os favoritos?';

  @override
  String get playlistClearFavoritesBody =>
      'Vais perder todas as tuas faixas favoritas. Isto não pode ser desfeito.';

  @override
  String get playlistRemoveFromLibrary => 'Remover da biblioteca';

  @override
  String get playlistServerReadOnly => 'Lista do servidor · só leitura';

  @override
  String get navAbout => 'Sobre';

  @override
  String get navMore => 'Mais';

  @override
  String get shellAlbumQueuedAtEnd => 'Álbum adicionado ao fim da fila';

  @override
  String get shellAlbumQueuedNext => 'O álbum será reproduzido a seguir';

  @override
  String get shellAddingToQueue => 'A adicionar à fila…';

  @override
  String get shellAddingNext => 'A adicionar para reproduzir a seguir…';

  @override
  String shellDownloadFailed(String error) {
    return 'Falha na transferência: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas adicionadas à fila',
      one: '$count faixa adicionada à fila',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" adicionado ao fim da fila';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" será reproduzido a seguir';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Falha na transferência: $title — a passar à faixa seguinte';
  }

  @override
  String get shellNetworkUnavailable =>
      'Reprodução interrompida: a rede parece estar indisponível.';

  @override
  String get statsTitle => 'Estatísticas';

  @override
  String statsPeriodDays(int n) {
    return '$n dias';
  }

  @override
  String get statsPeriodThisYear => 'Este ano';

  @override
  String get statsPeriodAll => 'Sempre';

  @override
  String get statsByMonthOrYear => 'Por mês / ano…';

  @override
  String get statsByYear => 'Por ano';

  @override
  String get statsByMonth => 'Por mês';

  @override
  String get statsPlaysLabel => 'Reproduções';

  @override
  String get statsTracksLabel => 'Faixas';

  @override
  String get statsArtistsLabel => 'Artistas';

  @override
  String get statsAlbumsLabel => 'Álbuns';

  @override
  String get statsListenTime => 'Tempo de escuta';

  @override
  String get statsByCollection => 'Por coleção';

  @override
  String get statsByFormat => 'Por formato';

  @override
  String get statsByEngine => 'Por motor';

  @override
  String get statsPlaylistsLabel => 'Playlists';

  @override
  String get statsLocalFilesSection => 'Ficheiros transferidos';

  @override
  String get statsFilesLabel => 'Ficheiros';

  @override
  String get statsSpaceLabel => 'Espaço em disco';

  @override
  String get statsNoPlaysInPeriod => 'Nenhuma reprodução neste período';

  @override
  String get statsNoPlays => 'Nenhuma reprodução';

  @override
  String get statsTopTracks => 'Top faixas';

  @override
  String get statsTopAlbums => 'Top álbuns';

  @override
  String get statsTopArtists => 'Top artistas';

  @override
  String statsTopTracksIn(String period) {
    return 'Top faixas — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Top álbuns — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Top artistas — $period';
  }

  @override
  String get statsSeeAll => 'Ver tudo';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n reproduções',
      one: '$n reprodução',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas',
      one: '$n faixa',
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
  String get commonCreate => 'Criar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRename => 'Mudar o nome';

  @override
  String get commonSort => 'Ordenar';

  @override
  String get commonPlayAll => 'Reproduzir tudo';

  @override
  String get sortName => 'Nome';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortArtist => 'Artista';

  @override
  String get sortAlbum => 'Álbum';

  @override
  String get sortDateAdded => 'Data de adição';

  @override
  String get commonClear => 'Limpar';

  @override
  String get sortRecentlyModified => 'Modificadas recentemente';

  @override
  String get sortCreationDate => 'Data de criação';

  @override
  String get playlistNameHint => 'Nome';

  @override
  String get playlistNew => 'Nova playlist';

  @override
  String get playlistNewFolder => 'Nova pasta';

  @override
  String get playlistNewTooltip => 'Nova playlist / pasta';

  @override
  String get playlistAddTo => 'Adicionar à playlist';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Adicionar a $n playlists',
      one: 'Adicionar a $n playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Seleciona uma playlist';

  @override
  String get playlistFilterHint => 'Filtrar as playlists…';

  @override
  String get playlistSearchHint => 'Pesquisar uma playlist…';

  @override
  String get playlistNoMatch => 'Nenhuma playlist corresponde';

  @override
  String get playlistNoneCreateHint => 'Nenhuma playlist — cria uma com +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas',
      one: '$n faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Já presentes';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n elementos já estão nas playlists selecionadas.',
      one: '$n elemento já está nas playlists selecionadas.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Ignorar os duplicados';

  @override
  String get playlistAddAgain => 'Adicionar novamente';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas adicionadas',
      one: '$n faixa adicionada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m playlists',
      one: '$n playlist',
    );
    return '$_temp0 a $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Não foi possível adicionar: $error';
  }

  @override
  String get playlistRenameTitle => 'Mudar o nome da playlist';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Eliminar a pasta “$name”?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'O seu conteúdo passa para o nível superior.';

  @override
  String get playlistEmpty => 'Playlist vazia';

  @override
  String get playlistRemoveEntry => 'Remover da playlist';

  @override
  String get trackOptionsAddToLibrary => 'Adicionar à biblioteca';

  @override
  String get trackOptionsRemoveFromLibrary => 'Remover da biblioteca';

  @override
  String get trackOptionsAddedToLibrary => 'Faixa adicionada à biblioteca';

  @override
  String get trackOptionsRemovedFromLibrary => 'Faixa removida da biblioteca';

  @override
  String get trackOptionsViewAlbum => 'Ver o álbum';

  @override
  String get trackOptionsViewArtist => 'Ver o artista';

  @override
  String get trackOptionsPlayNow => 'Reproduzir agora';

  @override
  String get trackOptionsPlayNext => 'Reproduzir a seguir';

  @override
  String get trackOptionsAddToQueueEnd => 'Adicionar ao fim da fila';

  @override
  String get trackOptionsPlayLast => 'Reproduzir por último';

  @override
  String get trackOptionsDeleteDownload => 'Eliminar a transferência';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Eliminar esta transferência?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'O ficheiro e as suas entradas locais (histórico, faixas) serão eliminados.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Transferência eliminada';

  @override
  String get trackOptionsAddToFavorites => 'Adicionar aos favoritos';

  @override
  String get trackOptionsRemoveFromFavorites => 'Remover dos favoritos';

  @override
  String get trackOptionsAlbumAddedToFavorites =>
      'Álbum adicionado aos favoritos';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Álbum removido dos favoritos';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Álbum não transferido — nada para eliminar';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Eliminar o álbum transferido?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'A pasta e todas as suas entradas locais (faixas, histórico) serão eliminadas.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Álbum eliminado do armazenamento local';

  @override
  String get trackOptionsRedownloadAlbum => 'Voltar a transferir o álbum';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Reescreve os ficheiros E as entradas locais';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Eliminar os ficheiros do álbum';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Pasta transferida + entradas locais (histórico)';

  @override
  String get settingsTitle => 'Definições';

  @override
  String get settingsGeneral => 'Geral';

  @override
  String get settingsGeneralSubtitle => 'Tema';

  @override
  String get settingsVisualisation => 'Visualização';

  @override
  String get settingsVisualisationSubtitle => 'Osciloscópios, artwork de fundo';

  @override
  String get settingsPlayback => 'Reprodução';

  @override
  String get settingsPlaybackSubtitle => 'Repetições, fade-out, silêncio';

  @override
  String get settingsEngines => 'Motores';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Dados';

  @override
  String get settingsDataSubtitle => 'Identificador, histórico, reposição';

  @override
  String get settingsBackupExport => 'Exportar uma cópia de segurança';

  @override
  String get settingsBackupExportSubtitle =>
      'Guarda a tua biblioteca, playlists e definições num ficheiro';

  @override
  String get settingsBackupImport => 'Importar uma cópia de segurança';

  @override
  String get settingsBackupImportSubtitle =>
      'Restaura os teus dados a partir de um ficheiro de cópia de segurança';

  @override
  String get settingsBackupExportFailed =>
      'Falha ao exportar a cópia de segurança';

  @override
  String get settingsBackupImportConfirmTitle =>
      'Importar a cópia de segurança?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Isto substitui a tua biblioteca, playlists e definições neste dispositivo. Os ficheiros transferidos são mantidos.';

  @override
  String get settingsBackupImportConfirm => 'Importar';

  @override
  String get settingsBackupImportedTitle => 'Cópia de segurança importada';

  @override
  String get settingsBackupImportedBody =>
      'Os teus dados foram restaurados. Reinicia a app para aplicar tudo.';

  @override
  String get settingsBackupTooNew =>
      'Esta cópia foi criada por uma versão mais recente da app';

  @override
  String get settingsBackupInvalid =>
      'Não é uma cópia de segurança Rewamp válida';

  @override
  String get settingsBackupImportFailed =>
      'Falha ao importar a cópia de segurança';

  @override
  String get settingsAbout => 'Acerca';

  @override
  String get settingsAboutSubtitle => 'Créditos e licenças';

  @override
  String get settingsCreditsSubtitle => 'Bibliotecas, dados e componentes';

  @override
  String get settingsSupport => 'Contacto e suporte';

  @override
  String get settingsSupportSubtitle => 'Fale connosco, site';

  @override
  String get settingsSupportEmail => 'Enviar um e-mail';

  @override
  String get settingsSupportEmailSubtitle => 'Pergunta, erro ou sugestão';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — suporte';

  @override
  String get settingsSupportEmailIntro =>
      'Descreva acima a sua pergunta, erro ou sugestão. As informações abaixo ajudam-nos a ajudá-lo.';

  @override
  String get settingsSupportWebsite => 'Site';

  @override
  String get settingsDonation => 'Apoiar o Rewamp';

  @override
  String get settingsDonationSubtitle => 'Uma gorjeta, se quiser';

  @override
  String get settingsDonationBlurb =>
      'O Rewamp é gratuito e sem publicidade — um trabalho de paixão dedicado à preservação da cultura demoscene e retro. Os donativos ajudam a financiar o desenvolvimento da app e a cobrir os custos de alojamento da base de dados. Sem obrigação: se a app lhe agrada, um pequeno gesto é sempre bem-vindo.';

  @override
  String get settingsDonationFloppy => 'Uma disquete';

  @override
  String get settingsDonationCartridge => 'Um cartucho';

  @override
  String get settingsDonationBox => 'Um jogo em caixa';

  @override
  String get settingsDonationCustom => 'Escolher um valor';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Eliminar';

  @override
  String get settingsReset => 'Repor';

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
  String get settingsDefault => 'Predefinição';

  @override
  String get settingsCoreNoScope => 'sem osciloscópio';

  @override
  String get settingsNone => 'Nenhum';

  @override
  String get settingsLevelLow => 'Baixo';

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
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsArtworkTintTitle => 'Colorir o leitor com o artwork';

  @override
  String get settingsArtworkTintSubtitle =>
      'O leitor adota a cor dominante da capa';

  @override
  String get settingsGlassEffectTitle => 'Efeito liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Lente e desfoque nas barras inferiores — desative em aparelhos lentos';

  @override
  String get settingsResetSection => 'Repor esta secção';

  @override
  String get settingsResetEngine => 'Repor este motor';

  @override
  String get settingsResetChoices => 'Repor estas escolhas';

  @override
  String get settingsResetToDefault => 'Valor predefinido';

  @override
  String get settingsStartInVizTitle => 'Iniciar no modo visualizador';

  @override
  String get settingsStartInVizSubtitle =>
      'O leitor abre nos osciloscópios em vez do artwork';

  @override
  String get settingsVoiceGridTitle => 'Grelha do osciloscópio de vozes';

  @override
  String get settingsVoiceGridSubtitle =>
      'Mostra os limites que separam cada voz';

  @override
  String get settingsKeepAwakeTitle => 'Manter o ecrã ligado';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Enquanto um visualizador está visível, o ecrã não escurece nem bloqueia';

  @override
  String get settingsVoiceNamesTitle => 'Nomes das vozes';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Mostra o nome de cada voz dentro do seu quadro';

  @override
  String get settingsLineThickness => 'Espessura do traço';

  @override
  String get settingsColors => 'Cores';

  @override
  String get settingsScopeVoiceColor => 'Osciloscópio de vozes';

  @override
  String get settingsStereoColors => 'Estéreo: cores';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Estéreo (mono)';

  @override
  String get settingsStereoLeftColor => 'Estéreo esquerdo';

  @override
  String get settingsStereoRightColor => 'Estéreo direito';

  @override
  String get settingsNotation => 'Notação (notas)';

  @override
  String get settingsNotePalette => 'Paleta de cores';

  @override
  String get settingsNoteBoxStyle => 'Estilo dos blocos';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'Efeitos CRT';

  @override
  String get settingsCrtGlow => 'Halo (glow)';

  @override
  String get settingsCrtSpeed => 'Intensidade / velocidade';

  @override
  String get settingsArtworkOpacity => 'Opacidade do artwork de fundo';

  @override
  String get settingsProjectMTitle => 'Definições do projectM';

  @override
  String get settingsProjectMSubtitle =>
      'Presets, transições, qualidade, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Notificações ao mudar de faixa';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Notificação do sistema com o título da nova faixa';

  @override
  String get settingsSilenceDetection => 'Deteção de silêncio';

  @override
  String get settingsSilenceSkipTitle =>
      'Passar à faixa seguinte em caso de silêncio';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Avança automaticamente quando a saída permanece silenciosa';

  @override
  String get settingsSilenceDelay => 'Atraso de silêncio';

  @override
  String get settingsDefaultDuration => 'Duração predefinida';

  @override
  String get settingsDefaultDurationHelp =>
      'Usada quando uma faixa não indica nenhuma duração conhecida (sem tag, sem metadados do servidor) — evita que toque ou repita indefinidamente. Nunca se aplica às faixas Amiga (UADE), que têm a sua própria base de durações.';

  @override
  String get settingsForcedLoopHeader => 'Repetição / fade-out forçados';

  @override
  String get settingsForcedLoopHelp =>
      'Alguns formatos repetem uma secção precisa (VGM, módulos tracker…); outros não. \"Infinito\" ignora o fim natural da faixa.';

  @override
  String get settingsForceLoopCount => 'Forçar o número de repetições';

  @override
  String get settingsLoopCount => 'Número de repetições';

  @override
  String get settingsForceFadeout => 'Forçar um fade-out';

  @override
  String get settingsFadeoutDuration => 'Duração do fade';

  @override
  String get settingsResetEnginesTitle => 'Repor as definições dos motores?';

  @override
  String get settingsResetEnginesBody =>
      'Todas as definições dos motores voltarão aos valores predefinidos.';

  @override
  String get settingsResetDefaultsTitle => 'Repor os valores predefinidos';

  @override
  String get settingsResetDefaultsSubtitle => 'Todos os motores';

  @override
  String get settingsDefaultDecoders => 'Descodificadores predefinidos';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formatos que vários motores conseguem ler';

  @override
  String get settingsDecodersHelp =>
      'Alguns formatos podem ser lidos por vários motores. Escolhe qual usar por predefinição — todos os outros formatos são encaminhados automaticamente.';

  @override
  String get settingsDecoderAmigaTrackers => 'Trackers Amiga (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, estéreo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — qualidade, filtros, opções por chip';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — filtro passa-alto';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — SoundFont em uso';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolação, passa-baixo, eco';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorâmica, auscultadores, ganho, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — relógio, modelo, filtros ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — modo harmónico estéreo/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, reverb';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — cores YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Volume principal';

  @override
  String get settingsAmigaFilter => 'Filtro Amiga';

  @override
  String get settingsInterpolation => 'Interpolação';

  @override
  String get settingsPolyphony => 'Polifonia';

  @override
  String get settingsReverb => 'Reverberação';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Nenhuma';

  @override
  String get settingsInterpLinear => 'Linear';

  @override
  String get settingsInterpCubic => 'Cúbica';

  @override
  String get settingsInterpSinc => 'Sinc (melhor)';

  @override
  String get settingsStereoSeparation => 'Separação estéreo';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Termina a faixa quando o motor deteta um silêncio prolongado';

  @override
  String get settingsStereoDepth => 'Profundidade estéreo';

  @override
  String get settingsEqualizer => 'Equalizador';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — sem efeito no SPC';

  @override
  String get settingsBass => 'Graves';

  @override
  String get settingsTreble => 'Agudos';

  @override
  String get settingsAppliedLive =>
      'Aplicado imediatamente, mesmo durante a reprodução.';

  @override
  String get settingsAppliedNextTrack => 'Aplicado à próxima faixa carregada.';

  @override
  String get settingsSidEmulation => 'Emulação';

  @override
  String get settingsSidResidfp => 'ReSIDfp (preciso)';

  @override
  String get settingsSidLite => 'SIDLite (rápido)';

  @override
  String get settingsSidSampling => 'Amostragem';

  @override
  String get settingsSidSamplingInterp => 'Interpolação (rápida)';

  @override
  String get settingsSidSamplingResample => 'Resample (melhor)';

  @override
  String get settingsSidClock => 'Relógio';

  @override
  String get settingsSidModel => 'Modelo SID';

  @override
  String get settingsSidFilter => 'Filtro SID';

  @override
  String get settingsSidForceSecond => 'Forçar um 2.º SID';

  @override
  String get settingsSidSecondSubtitle => 'Faixas 2SID estéreo';

  @override
  String get settingsSidSecondAddr => 'Endereço do 2.º SID';

  @override
  String get settingsSidForceThird => 'Forçar um 3.º SID';

  @override
  String get settingsSidThirdAddr => 'Endereço do 3.º SID';

  @override
  String get settingsSidAutoFilter => 'Intervalo do filtro 6581 automático';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Valor recomendado para o autor da faixa (tabelas sidplayfp)';

  @override
  String get settingsSid6581Range => 'Intervalo do filtro 6581';

  @override
  String get settingsSid6581Curve => 'Curva do filtro 6581';

  @override
  String get settingsSid8580Curve => 'Curva do filtro 8580';

  @override
  String get settingsSidNote =>
      'O filtro SID e as curvas são aplicados em direto; emulação/amostragem/relógio/modelo/2.º-3.º SID aplicam-se na próxima faixa.';

  @override
  String get settingsAudioOutput => 'Saída de áudio';

  @override
  String get settingsAdplugNote =>
      'Surround: dois chips OPL ligeiramente desafinados. Aplicado à próxima faixa.';

  @override
  String get settingsHeSpuMain => 'Vozes principais (SPU)';

  @override
  String get settingsHeSpuReverb => 'Reverb (SPU)';

  @override
  String get settingsNsfQuality => 'Qualidade (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Filtro passa-baixo';

  @override
  String get settingsHighpassFilter => 'Filtro passa-alto';

  @override
  String get settingsRegion => 'Região';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC forçado';

  @override
  String get settingsNsfRegionPalForced => 'PAL forçado';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy forçado';

  @override
  String get settingsNsfForceIrq => 'Forçar IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulses (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — triangle / ruído / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Reativar o som ao fazer reset';

  @override
  String get settingsNsfPhaseRefresh => 'Atualizar a fase';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Repor a fase quando o período é escrito';

  @override
  String get settingsNsfNonlinearMixer => 'Mistura não linear';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'A mistura real do 2A03 (caso contrário, linear)';

  @override
  String get settingsNsfDutySwap => 'Trocar os duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Ordem dos duty 25 % / 50 %';

  @override
  String get settingsNsfNegateSweep => 'Sweep negativo na inicialização';

  @override
  String get settingsNsfEnable4011 => 'Registo \$4011 ativo';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Saída DAC direta (clicks de origem)';

  @override
  String get settingsNsfPeriodicNoise => 'Ruído periódico';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Modo curto do gerador de ruído';

  @override
  String get settingsNsfDpcmAntiClick => 'Anti-clique DPCM';

  @override
  String get settingsNsfRandomizeNoise => 'Ruído aleatório na inicialização';

  @override
  String get settingsNsfTriangleMute => 'Silenciar o triangle';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Silencia o triangle em períodos ultrassónicos';

  @override
  String get settingsNsfRandomizeTri => 'Triangle aleatório na inicialização';

  @override
  String get settingsNsfDpcmReverse => 'DPCM invertido';

  @override
  String get settingsNsfN163Serial => 'Multiplexagem série';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'O zumbido real do N163 em faixas multi-voz';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Fase só de leitura';

  @override
  String get settingsNsfN163LimitWavelength => 'Limitar o comprimento de onda';

  @override
  String get settingsNsfFdsCutoff => 'Corte passa-baixo';

  @override
  String get settingsNsfFds4085Reset => 'Reset \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Proteção contra escrita';

  @override
  String get settingsNsfVrc7Patch => 'Conjunto de patches';

  @override
  String get settingsNsfVrc7Opll => 'Modo OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Emula um YM2413 em vez do VRC7';

  @override
  String get settingsGbsHpFilter => 'Filtro passa-alto (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (GB clássico)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Eco';

  @override
  String get settingsUadePostfx => 'Pós-processamento';

  @override
  String get settingsUadePostfxSubtitle =>
      'Ativa a cadeia de efeitos (necessário para tudo o resto)';

  @override
  String get settingsUadePan => 'Panorâmica (separação estéreo)';

  @override
  String get settingsUadePanValue => 'Valor da panorâmica';

  @override
  String get settingsUadeHeadphones => 'Auscultadores';

  @override
  String get settingsUadeLed => 'LED (filtro Paula)';

  @override
  String get settingsUadeLedAuto => 'Auto (por faixa)';

  @override
  String get settingsUadeLedOn => 'Forçado ON';

  @override
  String get settingsUadeLedOff => 'Forçado OFF';

  @override
  String get settingsUadeFilterType => 'Tipo de filtro';

  @override
  String get settingsUadeGain => 'Ganho';

  @override
  String get settingsUadeGainValue => 'Valor do ganho';

  @override
  String get settingsSoundfontLoading => 'A carregar o catálogo…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Catálogo indisponível ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Falha na transferência: $error';
  }

  @override
  String get settingsSoundfontImport => 'Importar uma SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Escolher um ficheiro .sf2 neste dispositivo';

  @override
  String get settingsSoundfontImported => 'Importada';

  @override
  String get settingsSoundfontInvalid =>
      'Este ficheiro não é uma SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Falha na importação — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Eliminar o ficheiro';

  @override
  String get settingsCreditsHeader => 'Créditos e licenças';

  @override
  String get settingsRightsNotice =>
      'O Rewamp é um leitor: não aloja ficheiros nem distribui música. As faixas provêm de arquivos de preservação online e continuam a ser propriedade dos respetivos titulares de direitos. Cabe-lhe verificar se ouvi-las, transferi-las e conservá-las cumpre os direitos aplicáveis e a legislação do seu país.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formatos suportados',
      one: '$count formato suportado',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repartidos por $count motores de reprodução — ver os detalhes',
      one: 'Suportados por $count motor de reprodução — ver os detalhes',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Durações e metadados Amiga';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb por Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Dados e capas C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — metadados e imagens dos jogos C64.';

  @override
  String get settingsFt2FontTitle => 'Fonte FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'O estilo FastTracker II do visualizador de padrões usa a fonte FT2 do ft2-clone por 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url copiado';
  }

  @override
  String get settingsOpenLink => 'Abrir o link';

  @override
  String get settingsEnginesHeader => 'Motores de reprodução';

  @override
  String get settingsComponentsHeader => 'Outros componentes';

  @override
  String get settingsResetAll => 'Repor todas as definições';

  @override
  String get settingsResetAllSubtitle =>
      'Geral, Visualização, Reprodução, Motores — não a biblioteca';

  @override
  String get settingsResetAllTitle => 'Repor todas as definições?';

  @override
  String get settingsResetAllBody =>
      'Geral, Visualização, Reprodução e todos os motores voltarão aos valores predefinidos. A tua biblioteca e o teu histórico não são afetados.';

  @override
  String get settingsRenewUserId => 'Renovar o identificador anónimo';

  @override
  String get settingsRenewUserIdTitle => 'Renovar o identificador anónimo?';

  @override
  String get settingsRenewUserIdBody =>
      'Será criado um novo identificador anónimo para as estatísticas do servidor.\n\nO antigo deixará de ser usado. O teu histórico local e os teus favoritos não são afetados.';

  @override
  String get settingsRenewUserIdFailed => 'Falhou — servidor inacessível';

  @override
  String settingsNewUserId(String id) {
    return 'Novo identificador: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Nenhum identificador registado';

  @override
  String get settingsCleanDb => 'Limpar a base de dados local';

  @override
  String get settingsCleanDbSubtitle =>
      'Remove as entradas cujo ficheiro já não existe (transferências eliminadas, erros antigos)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas órfãs removidas',
      one: '$count entrada órfã removida',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'Base de dados local limpa — nada a remover';

  @override
  String get settingsClearCache => 'Limpar a cache (artwork e metadados)';

  @override
  String get settingsClearCacheSubtitle =>
      'Remove as capas em cache e os metadados obtidos (STIL, durações) — voltam a ser transferidos na próxima reprodução';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cache limpa ($count capas)',
      one: 'Cache limpa ($count capa)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Repor as estatísticas';

  @override
  String get settingsResetStatsSubtitle =>
      'Remove o histórico de reprodução e os contadores';

  @override
  String get settingsClearStatsTitle => 'Repor as estatísticas?';

  @override
  String get settingsClearStatsBody =>
      'Esta ação eliminará definitivamente:\n• todo o histórico de reprodução\n• os contadores de reproduções\n\nOs teus favoritos e a tua biblioteca não são afetados.';

  @override
  String get settingsStatsCleared => 'Estatísticas eliminadas';

  @override
  String get settingsResetDatabase => 'Repor a base de dados';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Elimina tudo: histórico, favoritos, playlists, cache';

  @override
  String get settingsResetDbTitle => 'Repor a base de dados?';

  @override
  String get settingsResetDbBody =>
      'Esta ação eliminará definitivamente:\n• todo o histórico de reprodução\n• todos os contadores\n• todos os favoritos\n• todas as playlists\n• todos os metadados em cache\n\nOs teus ficheiros de áudio não são eliminados.';

  @override
  String get settingsDbReset => 'Base de dados reposta';

  @override
  String get settingsDeleteDownloads => 'Eliminar as transferências';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Elimina todos os ficheiros da pasta online (faixas, artwork)';

  @override
  String get settingsDeleteDownloadsTitle => 'Eliminar as transferências?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Esta ação eliminará definitivamente todos os ficheiros transferidos (faixas, álbuns, artwork) da pasta online.\n\nAs entradas na base de dados permanecerão, mas apontarão para ficheiros que já não existem.';

  @override
  String get settingsDownloadsDeleted => 'Transferências eliminadas';

  @override
  String get settingsColor => 'Cor';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Preset seguinte aleatório';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Desativado: reproduz os presets por ordem';

  @override
  String get settingsPmLockPreset => 'Bloquear o preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Sem mudança automática';

  @override
  String get settingsPmPresetDuration => 'Tempo entre presets';

  @override
  String get settingsPmTransitions => 'Transições';

  @override
  String get settingsPmBlend => 'Transição em cross-fade';

  @override
  String get settingsPmBlendSubtitle =>
      'Desativado: muda de preset instantaneamente';

  @override
  String get settingsPmTransitionStyle => 'Estilo de transição';

  @override
  String get settingsPmTransitionStyleSubtitle => 'O padrão usado pela fusão';

  @override
  String get settingsPmTransitionRandom => 'Aleatório';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Mudança de preset sincronizada com os beats';

  @override
  String get settingsPmHardcutTime => 'Hardcut: tempo mínimo';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: sensibilidade';

  @override
  String get settingsPmRendering => 'Renderização';

  @override
  String get settingsPmQuality => 'Qualidade';

  @override
  String get settingsPmQualitySubtitle =>
      'Resolução de renderização (Máx = resolução nativa)';

  @override
  String get settingsPmBeatSensitivity => 'Sensibilidade ao beat';

  @override
  String get settingsPmAspectRatio => 'Respeitar o rácio de aspeto';

  @override
  String get settingsPmAspectRatioSubtitle => 'Para os shaders que o suportam';

  @override
  String get settingsPmPermissive => 'Modo permissivo';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Carrega os ficheiros .milk com erros de script';

  @override
  String get accountTitle => 'Conta';

  @override
  String get accountSubtitle => 'Guarda e sincroniza a tua biblioteca';

  @override
  String get accountAnonymous => 'Conta anónima';

  @override
  String get accountAnonymousExplain =>
      'Os teus favoritos e o teu histórico ficam guardados no servidor, mas só este dispositivo lhes acede. Adiciona um endereço de e-mail para os reencontrares noutro lado.';

  @override
  String get accountEmailAttached =>
      'Endereço confirmado — esta conta pode ser restaurada';

  @override
  String get accountEmailPending => 'Endereço ainda não confirmado';

  @override
  String get accountInsecureStorage =>
      'O armazenamento seguro deste dispositivo não está disponível: o identificador da conta fica guardado sem cifra.';

  @override
  String get accountSaveCta => 'Guardar a minha conta';

  @override
  String get accountStatSongs => 'Faixas favoritas';

  @override
  String get accountStatAlbums => 'Álbuns favoritos';

  @override
  String get accountStatPlays => 'Reproduções';

  @override
  String get accountCreatedLabel => 'Criada';

  @override
  String get accountSignOut => 'Terminar sessão';

  @override
  String get accountRevoke => 'Terminar sessão em todo o lado';

  @override
  String get accountRevokeSubtitle =>
      'Termina a sessão nos outros dispositivos';

  @override
  String get accountRevokeBody =>
      'Os outros dispositivos são desligados. Este permanece ligado.';

  @override
  String get accountRevokeDone => 'Outros dispositivos desligados';

  @override
  String get accountDelete => 'Eliminar a minha conta';

  @override
  String get accountDeleteSubtitle =>
      'Apaga a conta e os seus dados no servidor. Irreversível.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items favoritos e $lists playlists serão eliminados do servidor. Não é possível anular.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'As tuas transferências e a biblioteca deste dispositivo não são afetadas.';

  @override
  String get accountDeleteDone => 'Conta eliminada';

  @override
  String get accountSignOutSubtitle =>
      'Este dispositivo volta a uma conta nova e vazia';

  @override
  String get accountSignOutTitle => 'Terminar sessão?';

  @override
  String accountSignOutBody(String email) {
    return 'Podes voltar a esta conta com um código enviado para $email.';
  }

  @override
  String get accountSignedOut => 'Sessão terminada';

  @override
  String get accountNoSignOut => 'Terminar sessão indisponível';

  @override
  String get accountNoSignOutSubtitle =>
      'Sem endereço de e-mail, esta conta ficaria perdida para sempre.';

  @override
  String get accountDetach => 'Desassociar endereço';

  @override
  String get accountDetachSubtitle =>
      'A conta volta a ser anónima, não se apaga nenhum dado';

  @override
  String get accountDetachBody =>
      'Sem endereço, esta conta deixa de poder ser recuperada noutro dispositivo.';

  @override
  String get accountDetachDone => 'Endereço desassociado';

  @override
  String get accountOffline => 'Conta indisponível sem ligação';

  @override
  String get accountEmailTitle => 'Endereço de e-mail';

  @override
  String get accountEmailExplain =>
      'Enviamos-te um código de 6 dígitos para confirmar o endereço. Serve apenas para recuperar a tua conta.';

  @override
  String get accountEmailLabel => 'Endereço de e-mail';

  @override
  String get accountCodeTitle => 'Código de confirmação';

  @override
  String accountCodeExplain(String email) {
    return 'Código enviado para $email. É válido durante 10 minutos.';
  }

  @override
  String get accountCodeLabel => 'Código de 6 dígitos';

  @override
  String get accountSendCode => 'Enviar o código';

  @override
  String get accountVerify => 'Confirmar';

  @override
  String get accountResend => 'Reenviar o código';

  @override
  String accountResendIn(int n) {
    return 'Reenviar dentro de $n s';
  }

  @override
  String get accountCheckSpam =>
      'O e-mail pode demorar um minuto — vê também a pasta de spam.';

  @override
  String get accountErrorInvalidEmail => 'Endereço inválido';

  @override
  String get accountErrorTooMany =>
      'Demasiados pedidos, tenta daqui a alguns minutos';

  @override
  String get accountErrorInvalidCode => 'Código incorreto ou expirado';

  @override
  String get accountErrorCodeLength => 'O código tem 6 dígitos';

  @override
  String get accountErrorNetwork => 'Não foi possível ligar, tenta de novo';

  @override
  String get accountMergeTitle => 'Juntar esta biblioteca?';

  @override
  String accountMergeBody(String email) {
    return 'Os favoritos e o histórico deste dispositivo serão adicionados à conta $email. A operação é definitiva.';
  }

  @override
  String get accountMergeConfirm => 'Juntar';

  @override
  String get accountCarryLocal => 'Manter os favoritos deste dispositivo';

  @override
  String accountCarryLocalOn(int n) {
    return 'Os $n favoritos e as playlists deste dispositivo são adicionados à conta.';
  }

  @override
  String get accountCarryLocalOff =>
      'São eliminados deste dispositivo e substituídos pelos da conta. Os ficheiros transferidos são mantidos.';

  @override
  String get accountDropLocalTitle => 'Eliminar os dados deste dispositivo?';

  @override
  String get accountCreatedOk => 'Conta guardada, a tua biblioteca está segura';

  @override
  String get accountMergedOk =>
      'Sessão iniciada — os teus favoritos locais foram adicionados';

  @override
  String get accountSignedInOk => 'Sessão iniciada';

  @override
  String get playlistEntryMissing => 'Ficheiro ausente neste dispositivo';

  @override
  String get playlistEntryMissingRestorable =>
      'Ficheiro ausente — pode ser transferido de novo';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n em falta',
      one: '$n em falta',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Guardar na minha conta';

  @override
  String get playlistBackupSubtitle =>
      'Mantém esta playlist mesmo depois de reinstalar';

  @override
  String get playlistBackupUpdate => 'Atualizar a cópia';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Substitui a cópia da conta por esta versão';

  @override
  String get playlistBackupStop => 'Deixar de guardar';

  @override
  String get playlistBackupStopped => 'Cópia removida';

  @override
  String get playlistBackupDone => 'Playlist guardada';

  @override
  String get playlistBackupFailed => 'Não foi possível guardar';

  @override
  String get playlistBackupNoAccount => 'Nenhuma conta neste dispositivo';

  @override
  String get playlistSyncTooltip => 'Sincronizar com a minha conta';

  @override
  String get playlistSyncRunning => 'A sincronizar…';

  @override
  String get playlistSyncDone => 'Playlists sincronizadas';

  @override
  String get playlistSyncPartial =>
      'Algumas playlists não puderam ser guardadas';

  @override
  String get playlistFetchMissing => 'Transferir as faixas em falta';

  @override
  String get playlistFetchDone => 'Faixas em falta transferidas';

  @override
  String get playlistFetchPartial =>
      'Algumas faixas não puderam ser transferidas';

  @override
  String get playlistEntryFetchFailed =>
      'Não foi possível transferir esta faixa';

  @override
  String get accountStatPlaylists => 'Playlists';

  @override
  String get accountSyncNow => 'Sincronizar agora';

  @override
  String get accountSyncAuto => 'Faz-se sozinho em segundo plano';

  @override
  String get accountSyncAnonymous =>
      'Guardado no servidor. Adiciona um e-mail para sincronizar outro dispositivo.';

  @override
  String get accountSyncPending => 'Há alterações à espera de envio';

  @override
  String accountSyncLast(String when) {
    return 'Última sincronização: $when';
  }

  @override
  String get accountSyncDone => 'Sincronização concluída';

  @override
  String get accountSyncFailed => 'A sincronização falhou, será repetida';

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
    return 'contém o $place de $compo';
  }

  @override
  String get competitionEmpty => 'Esta competição não tem entradas';

  @override
  String get competitionEntryNoMusic =>
      'Não há música no catálogo para esta entrada';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n faixas',
      one: '$n faixa',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Ignorar';

  @override
  String get onboardingNext => 'Seguinte';

  @override
  String get onboardingStart => 'Começar';

  @override
  String get onboardingBetaTitle => 'Versão beta';

  @override
  String get onboardingBetaBody =>
      'O Rewamp ainda está em construção. Os dados locais — biblioteca, listas, favoritos, estatísticas — poderão ser apagados antes da versão 1.0. As transferências não correm risco, mas guarde noutro lado o que lhe é caro.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Versão $version (compilação $build)';
  }

  @override
  String get onboardingExploreTitle => 'Explorar';

  @override
  String get onboardingExploreBody =>
      'Percorra e pesquise dezenas de milhares de chiptunes e módulos dos grandes arquivos online, por artista, álbum, plataforma ou party. Toque para ouvir, transfira para guardar.';

  @override
  String get onboardingLibraryTitle => 'A sua biblioteca';

  @override
  String get onboardingLibraryBody =>
      'Guarde o que gosta, crie listas e organize-as em pastas. O que transferir toca offline, e a biblioteca acompanha-o entre dispositivos depois de iniciar sessão.';

  @override
  String get onboardingPlayerTitle => 'O leitor';

  @override
  String get onboardingPlayerBody =>
      'Deslize para mudar de faixa e abra os visualizadores: osciloscópio, canais, notas em movimento, grelha tracker. Os ficheiros com várias faixas mostram as subfaixas e cada voz pode ser silenciada.';

  @override
  String get onboardingReplayTitle => 'Apresentação';

  @override
  String get onboardingReplaySubtitle => 'Rever o aviso beta e a visita guiada';

  @override
  String get settingsPatternTitle => 'Padrões';

  @override
  String get settingsPatternSubtitle =>
      'Grelha tracker: cores, colunas, deslocamento';

  @override
  String get patternOpaqueBg => 'Fundo opaco';

  @override
  String get patternOpaqueBgSubtitle => 'Esconde a capa por trás da grelha';

  @override
  String get commonSave => 'Guardar';

  @override
  String get accountDisplayName => 'Nome público';

  @override
  String get accountDisplayNameNotSet =>
      'Por definir — necessário para publicar uma playlist';

  @override
  String get accountDisplayNameHint => 'O nome com que queres ser creditado.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Mudá-lo devolve à revisão todas as playlists que publicaste.';

  @override
  String get accountDisplayNameTaken =>
      'Esse nome já está ocupado. Escolhe outro.';

  @override
  String get accountDisplayNameLength => 'Entre 2 e 40 caracteres.';

  @override
  String get accountDisplayNameSaved => 'Nome público guardado';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Playlists devolvidas à revisão: $n';
  }

  @override
  String get playlistPublish => 'Tornar pública';

  @override
  String get playlistPublishSubtitle =>
      'Pedir a publicação (passa por revisão)';

  @override
  String get playlistPublishTitle => 'Publicar esta playlist?';

  @override
  String get playlistPublishBody =>
      'Fica visível para todos assim que for aprovada, creditada ao teu nome público. A capa vem das suas faixas.';

  @override
  String get playlistPublishCta => 'Pedir';

  @override
  String get playlistPublishSubmitted => 'Enviada para revisão';

  @override
  String get playlistPublishPending => 'À espera de aprovação';

  @override
  String get playlistPublishApproved => 'Pública';

  @override
  String playlistPublishRejected(String reason) {
    return 'Recusada: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Recusada';

  @override
  String get playlistPublishNeedName =>
      'Escolhe o nome com que queres ser creditado';

  @override
  String get playlistPublishNeedTracks =>
      'São precisas pelo menos 5 faixas para publicar';

  @override
  String get playlistPublishHasLocal =>
      'Os ficheiros do teu aparelho não podem ser publicados — os outros não os conseguem tocar';

  @override
  String get playlistPublishTooManyPending =>
      'Já tens 3 playlists à espera de aprovação';

  @override
  String get playlistPublishRefused =>
      'Publicação recusada: verifica as faixas e os pedidos pendentes';

  @override
  String get playlistPublishFailed => 'A publicação falhou';

  @override
  String get playlistPublishWithdrawn => 'A playlist voltou a ser privada';

  @override
  String get playlistUnpublish => 'Tornar privada';

  @override
  String get playlistUnpublishSubtitle => 'Retira-a das playlists públicas';

  @override
  String get playlistRenamePublishedTitle => 'Renomear uma playlist publicada?';

  @override
  String get playlistRenamePublishedBody =>
      'O que é revisto é o nome: renomear devolve a playlist à revisão e despublica-a entretanto. Acrescentar ou reordenar faixas, não.';

  @override
  String playlistByAuthor(String author) {
    return 'por $author';
  }

  @override
  String get settingsSpectrumMode => 'Modo do espetro';

  @override
  String get settingsSpectrumModeStandard => 'Padrão';

  @override
  String get settingsSpectrumModeColored => 'Colorido';

  @override
  String get settingsSpectrumModeBeam => 'Feixe';

  @override
  String get settingsSpectrumModeLine => 'Linha';

  @override
  String get settingsSpectrumModeRing => 'Anel';

  @override
  String get releaseNotesTitle => 'Novidades';

  @override
  String get releaseNotesV4Downloads =>
      'Transferências: uma transferência longa pode ser cancelada a meio, e o arquivo de um álbum já não é obtido várias vezes.';

  @override
  String get releaseNotesV4Queue =>
      'Fila: um botão para a esvaziar, com confirmação — também para a reprodução.';

  @override
  String get releaseNotesV4DropFiles =>
      'Ficheiros largados na janela: escolher reproduzir agora, a seguir ou no fim; capas e ficheiros acompanhantes ficam de fora, e a lista incluída num arquivo é respeitada (títulos reais, sem faixas mortas).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: importe a sua própria SoundFont a partir do dispositivo, a par das do servidor.';

  @override
  String get releaseNotesV4Formats =>
      'Os fluxos de jogo Wwise, FSB e OGL já tocam (Vorbis próprio).';

  @override
  String get releaseNotesV4Chips =>
      'Mais seis chips de som, escolha do núcleo de emulação por chip (SameBoy para Game Boy) e afinação correta nos chips com amostras.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: os .vt2 tocam, e as vistas de notas e padrões cobrem toda a família ZX.';

  @override
  String get releaseNotesV4Loop =>
      'Repetir faixa faz mesmo o ciclo em vez de recarregar, e o contador já não congela em ciclo infinito.';

  @override
  String get releaseNotesV4Info =>
      'O painel ⓘ lista os ficheiros que uma peça abriu de facto — acompanhantes e bibliotecas incluídos.';

  @override
  String get releaseNotesV4Linux => 'Versão Linux para computador.';

  @override
  String get releaseNotesDataReset =>
      'Os dados locais foram repostos para esta beta. Biblioteca e playlists reconstroem-se a partir da conta; as transferências têm de ser refeitas.';

  @override
  String get releaseNotesDismiss => 'Continuar';

  @override
  String get pmManagePresets => 'Gerir os presets';

  @override
  String get pmPickTooltip => 'Escolher um preset';

  @override
  String get pmPickFilter => 'Filtrar presets';

  @override
  String get pmSourceTooltip => 'Origem dos presets';

  @override
  String get pmAddToPlaylistTooltip => 'Adicionar o preset a uma playlist';

  @override
  String pmSlowPresetDropped(String name) {
    return '«$name» é pesado demais para este dispositivo e foi posto de lado.';
  }

  @override
  String get pmSlowDeviceTitle => 'Este dispositivo é demasiado lento';

  @override
  String get pmSlowDeviceOff =>
      'O visualizador foi desativado: este dispositivo não acompanha os presets Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets postos de lado',
      one: '1 preset posto de lado',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Demasiado lentos neste dispositivo. A reprodução salta-os.';

  @override
  String get settingsPmSlowPresetsRestore => 'Restaurar';

  @override
  String get pmSourceBundled => 'Presets integrados';

  @override
  String get pmSourceImports => 'As minhas importações';

  @override
  String get pmSourceAll => 'Todos os presets';

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
  String get pmNewPlaylist => 'Nova playlist…';

  @override
  String get pmPlaylistName => 'Nome da playlist';

  @override
  String get pmAddedToPlaylist => 'Adicionado à playlist';

  @override
  String get pmAlreadyInPlaylist => 'Já está nesta playlist';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Explorar';

  @override
  String get pmTabPlaylists => 'Playlists';

  @override
  String get pmTabPopular => 'Populares';

  @override
  String get pmTabSetAside => 'Postos de lado';

  @override
  String get pmSetAsideEmpty =>
      'Nada posto de lado. Os presets que fazem este dispositivo cair abaixo de 6 fps aparecem aqui.';

  @override
  String get pmSetAsideRestoreAll => 'Restaurar tudo';

  @override
  String get pmInstall => 'Instalar';

  @override
  String get pmInstallQueued => 'Instalação em fila';

  @override
  String get pmUninstall => 'Desinstalar';

  @override
  String get pmUninstalled => 'Pack removido';

  @override
  String get pmUse => 'Usar';

  @override
  String get pmDefaultPackBanner => 'Pack inicial recomendado';

  @override
  String pmLicense(String license) {
    return 'Licença: $license';
  }

  @override
  String get pmPacksOffline => 'Servidor inacessível';

  @override
  String get pmSearchPresets => 'Procurar presets…';

  @override
  String get pmPlayNow => 'Reproduzir agora';

  @override
  String get pmDownloadAction => 'Transferir';

  @override
  String get pmDownloaded => 'Preset transferido';

  @override
  String get pmDownloadFailed => 'Falha na transferência';

  @override
  String pmPreviewing(String name) {
    return 'A reproduzir: $name';
  }

  @override
  String get pmLocalSection => 'As minhas playlists';

  @override
  String get pmCuratedSection => 'Playlists Rewamp';

  @override
  String get pmImportPlaylist => 'Transferir e usar';

  @override
  String get pmPlaylistImported => 'Playlist pronta';

  @override
  String get pmImportFiles => 'Importar ficheiros…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets importados',
      one: '$count preset importado',
      zero: 'Nenhum preset importado',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presets adicionados à biblioteca projectM';

  @override
  String get pmNoPlaylists => 'Ainda não há playlists de presets';

  @override
  String get pmSourceApplied => 'Origem de presets aplicada';

  @override
  String get pmPlaylistEmpty => 'Esta playlist está vazia';

  @override
  String get pmDays7 => '7 dias';

  @override
  String get pmDays30 => '30 dias';

  @override
  String get pmDays365 => '1 ano';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '$count reprodução',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Falha na instalação';

  @override
  String get pmSingleDownloads => 'Transferências individuais';

  @override
  String pmAvailableIn(String pack) {
    return 'Disponível em $pack';
  }

  @override
  String get pmCleanUp => 'Limpar';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presets eliminados',
      one: '$count preset eliminado',
      zero: 'Nada para limpar',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Bloquear este preset';

  @override
  String get pmUnlockAction => 'Desbloquear o preset';

  @override
  String get pmOrderRandom => 'Presets aleatórios';

  @override
  String get pmOrderSequential => 'Presets por ordem';

  @override
  String get pmUpdateAvailable => 'Atualização disponível';

  @override
  String get pmUpdate => 'Atualizar';

  @override
  String get pmSelectAll => 'Selecionar tudo';

  @override
  String get pmSelectNone => 'Desmarcar tudo';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '$count selecionado',
      zero: 'Nada selecionado',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Texturas não utilizadas';

  @override
  String pmTexturesFreed(String size) {
    return '$size libertados';
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
