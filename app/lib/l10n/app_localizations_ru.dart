// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navHome => 'Главная';

  @override
  String get navSearch => 'Поиск';

  @override
  String get navLibrary => 'Медиатека';

  @override
  String get noFileSelected => 'Файл не выбран';

  @override
  String get openFile => 'Открыть файл';

  @override
  String get pickerLabelAudio => 'Аудио';

  @override
  String get formatNotSupported => 'Формат не поддерживается';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Неподдерживаемый формат: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Нет на этом устройстве: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Файла больше нет на сервере: $file';
  }

  @override
  String get failedToLoadFile => 'Не удалось загрузить файл';

  @override
  String get libraryEmptyHint =>
      'Ваши исполнители, альбомы и плейлисты\nпоявятся здесь.';

  @override
  String get libraryPlaylists => 'Плейлисты';

  @override
  String get libraryArtists => 'Исполнители';

  @override
  String get libraryAlbums => 'Альбомы';

  @override
  String get libraryTracks => 'Треки';

  @override
  String get libraryFavorites => 'Избранное';

  @override
  String get libraryFavoritesSubtitle =>
      'Автоматический плейлист из ваших любимых треков';

  @override
  String get libraryRecentlyAdded => 'Недавно добавленные';

  @override
  String get libraryEmpty => 'Здесь пока ничего нет';

  @override
  String get libraryRemoved => 'Удалено из библиотеки';

  @override
  String get searchHint => 'Поиск…';

  @override
  String get searchTypePlaceholder =>
      'Введите название, исполнителя или альбом…';

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get searchDownloading => 'Загрузка…';

  @override
  String searchError(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get tabAll => 'Треки';

  @override
  String get tabArtists => 'Исполнители';

  @override
  String get tabAlbums => 'Альбомы';

  @override
  String get tabProductions => 'Продукции';

  @override
  String get filterWithVideo => 'С видео';

  @override
  String get videoUnavailable => 'Это видео недоступно';

  @override
  String get noItems => 'Нет элементов';

  @override
  String get sortRelevance => 'По релевантности';

  @override
  String get sortAZ => 'А–Я';

  @override
  String get recentlyPlayed => 'Недавно прослушанные';

  @override
  String get noRecentTracks => 'Нет недавно прослушанных треков';

  @override
  String get openLocalFile => 'Открыть локальный файл';

  @override
  String get playerSourceLocal => 'локально';

  @override
  String get browseFiles => 'Обзор файлов';

  @override
  String countTotal(int loaded, int total) {
    return 'Результатов: $loaded / $total';
  }

  @override
  String countLoadingMore(int loaded) {
    return 'Загружено: $loaded…';
  }

  @override
  String countComplete(int loaded) {
    return 'Результатов: $loaded';
  }

  @override
  String countScrollMore(int loaded) {
    return 'Загружено: $loaded — прокрутите, чтобы увидеть ещё';
  }

  @override
  String countNLoaded(int n) {
    return 'Загружено: $n';
  }

  @override
  String countFilesLoaded(int n) {
    return 'Файлов: $n';
  }

  @override
  String get browseFilterByTitle => 'Фильтр по названию…';

  @override
  String get browseNoSongs => 'Нет доступных песен';

  @override
  String get browseByFormat => 'По формату';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Фильтр по формату…';

  @override
  String get browseByPlatform => 'По платформе';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Название платформы…';

  @override
  String get browseByChip => 'По звуковому чипу';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'напр. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'По исполнителю';

  @override
  String get browseByArtistSubtitle => 'Обзор композиторов';

  @override
  String get browseFilterByName => 'Фильтр по имени…';

  @override
  String get browseNoArtistFound => 'Исполнители не найдены';

  @override
  String get browseNoArtistsAvailable => 'Нет доступных исполнителей';

  @override
  String get browseNoArtist => 'Нет исполнителей';

  @override
  String get browseNoAlbum => 'Нет альбомов';

  @override
  String get browseTopPacks => 'Топ паков';

  @override
  String get browseTopPacksSubtitle => 'Паки с самым высоким рейтингом';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Топ паков — $collection';
  }

  @override
  String get browseLatestPacks => 'Новые паки';

  @override
  String get browseLatestPacksSubtitle => 'Самые свежие добавления';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Новые паки — $collection';
  }

  @override
  String get browseAllSongs => 'Все песни';

  @override
  String get browseAllSongsSubtitleAlpha => 'Обзор в алфавитном порядке';

  @override
  String get browseAlphabetical => 'В алфавитном порядке';

  @override
  String browseAllLabel(String collection) {
    return 'Все — $collection';
  }

  @override
  String get browseCollections => 'Коллекции';

  @override
  String browseFilesCount(String count) {
    return 'Файлов: $count';
  }

  @override
  String get browseIndexing => 'Идёт индексация';

  @override
  String browseFilterFacet(String name) {
    return 'Фильтр $name…';
  }

  @override
  String get browseAllYears => 'Все годы';

  @override
  String get browseAllYearsSubtitle => 'Все песни этой party';

  @override
  String get browseNoCompo =>
      'Для этой party не проиндексировано ни одного compo.';

  @override
  String get browseOthers => 'Другие';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n работы — рейтинг',
      many: '$n работ — рейтинг',
      few: '$n работы — рейтинг',
      one: '$n работа — рейтинг',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Воспроизвести плейлист';

  @override
  String get browsePlayAllRanked => 'Воспроизвести всё (в порядке рейтинга)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n трека — в порядке рейтинга',
      many: '$n треков — в порядке рейтинга',
      few: '$n трека — в порядке рейтинга',
      one: '$n трек — в порядке рейтинга',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Обзор по альбомам';

  @override
  String get browsePlayAll => 'Воспроизвести всё';

  @override
  String get browseShuffle => 'Перемешать';

  @override
  String get browseSearchInFolder => 'Поиск в этой папке…';

  @override
  String get browseFilterThisList => 'Фильтровать этот список…';

  @override
  String get browseSearchSubfolders => 'Искать во вложенных папках';

  @override
  String get browseEmptyFolder => 'Пустая папка';

  @override
  String browsePlaybackError(String message) {
    return 'Не удалось воспроизвести: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n трека',
      many: '$n треков',
      few: '$n трека',
      one: '$n трек',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Вид';

  @override
  String get browseViewList => 'Список';

  @override
  String get browseViewGrid => 'Сетка';

  @override
  String get browseViewGridCompact => 'Компактная сетка';

  @override
  String get browseSearchAlbum => 'Поиск альбома…';

  @override
  String get browseSearchArtist => 'Поиск исполнителя…';

  @override
  String get browsePlayAlbum => 'Воспроизвести альбом';

  @override
  String get searchDownloadingAlbum => 'Загрузка альбома…';

  @override
  String get searchCategoryChip => 'Чипы';

  @override
  String get searchCategoryGroup => 'Группы';

  @override
  String get artistRealName => 'Настоящее имя';

  @override
  String get artistAliases => 'Псевдонимы';

  @override
  String get artistBorn => 'Дата рождения';

  @override
  String get artistInterview => 'Интервью';

  @override
  String get audioOutput => 'Аудиовыход';

  @override
  String get audioOutputSystemDefault => 'Системный по умолчанию';

  @override
  String get vizRangeAuto => 'Авто';

  @override
  String get contextNotes => 'Заметки';

  @override
  String get notePlacedBadge => 'Заняла место в конкурсе';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Показать треки';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count модуля',
      many: '$count модулей',
      few: '$count модуля',
      one: '$count модуль',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Party';

  @override
  String get searchCategoryYear => 'Год';

  @override
  String get searchCategoryOrigin => 'Происхождение';

  @override
  String get searchCategoryProduction => 'Продукция';

  @override
  String get searchCategoryProductionType => 'Типы продукции';

  @override
  String get searchCategoryPublisher => 'Издатели';

  @override
  String get searchCategoryDeveloper => 'Разработчики';

  @override
  String get searchCategoryArcadeBoard => 'Аркадные платы';

  @override
  String get searchCategorySaga => 'Сага';

  @override
  String get searchCategoryGenre => 'Жанр';

  @override
  String get searchViaArtist => 'через исполнителя';

  @override
  String get searchViaAlbum => 'через альбом';

  @override
  String get searchViaSong => 'через песню';

  @override
  String get searchSortPopular => 'По популярности';

  @override
  String get searchSortYear => 'Год';

  @override
  String get searchSortRandom => 'Случайно';

  @override
  String get searchSortRating => 'Оценка';

  @override
  String statsTopPercent(int percent) {
    return 'Топ $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голоса',
      many: '$count голосов',
      few: '$count голоса',
      one: '$count голос',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'По возрастанию';

  @override
  String get searchSortDesc => 'По убыванию';

  @override
  String get searchFilters => 'Фильтры';

  @override
  String get searchExactSearch => 'Точный поиск';

  @override
  String get searchExactSearchSubtitle =>
      'Отключает приблизительный (fuzzy) поиск';

  @override
  String get searchTags => 'Теги';

  @override
  String searchTagSearchHint(String category) {
    return 'Поиск тега в « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Начните вводить, чтобы найти теги.';

  @override
  String get searchTagsAndLogic => 'Несколько тегов = логическое И.';

  @override
  String get searchFilterYear => 'Год';

  @override
  String get searchFilterAll => 'все';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote => 'Фильтр по году исключает песни без даты.';

  @override
  String get searchMinRating => 'Оценка ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Отмена';

  @override
  String get searchReset => 'Сбросить';

  @override
  String get searchApply => 'Применить';

  @override
  String get searchClearRecent => 'Очистить недавние запросы';

  @override
  String get searchBrowse => 'Обзор';

  @override
  String get searchBrowseHint =>
      'Выберите фасет (группа, чип, год…), чтобы изучить каталог, или запустите Радио/Сюрприз выше.';

  @override
  String get searchDidYouMean =>
      'Мало результатов — попробовать приблизительный поиск?';

  @override
  String get searchYes => 'Да';

  @override
  String get featuredCommunityTitle => 'Новое от сообщества';

  @override
  String get searchPlaylistSourceAll => 'Все';

  @override
  String get searchPlaylistSourceUser => 'Сообщество';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Формат';

  @override
  String get searchPlatform => 'Платформа';

  @override
  String get filterCollection => 'Коллекция';

  @override
  String get videoWatchDemo => 'Смотреть демо';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Коллекция: $name';
  }

  @override
  String get searchCollectionAll => 'Все';

  @override
  String get searchRadio => 'Радио';

  @override
  String get searchRadioTooltip => 'Случайная очередь по текущим фильтрам';

  @override
  String get searchSurprise => 'Сюрприз';

  @override
  String get searchSurpriseTooltip => 'Случайная песня';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Нет песен';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n песни',
      many: '$n песен',
      few: '$n песни',
      one: '$n песня',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n альбома',
      many: '$n альбомов',
      few: '$n альбома',
      one: '$n альбом',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'aka $name';
  }

  @override
  String get searchChooseCollection => 'Выбрать коллекцию';

  @override
  String get searchFilterCollections => 'Фильтр коллекций…';

  @override
  String get searchFilterPlaceholder => 'Фильтр…';

  @override
  String searchAllOf(String label) {
    return 'Все ($label)';
  }

  @override
  String get searchNoMatch => 'Нет совпадений';

  @override
  String get searchNoPlaylist => 'Нет плейлистов';

  @override
  String get engineDescOpenmpt => 'Модули tracker (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — звуковые чипы, осциллограф по каналам';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + архивы RSN';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — голоса по каналам';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (движок reSIDfp)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'Chiptune для MSX (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Многочиповые chiptune .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Форматы Amiga с custom-чипами через эмуляцию 68k (~320 расширений)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Стандартный MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — синтезатор SDAT/SSEQ (16 голосов)';

  @override
  String get engineDescV2m => 'Синтезатор V2M (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — настоящая эмуляция 68000 + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — эмуляция R4300 + RSP audio';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — эмуляция NEC V30MZ';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + чип QSound';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — настоящий синтезатор AY-3-8910/YM2149';

  @override
  String get engineDescOrganya => 'Cave Story .org — родной движок Pixel';

  @override
  String get engineDescPxtone => 'Трекер от Pixel — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — настоящий 68000 через emu68';

  @override
  String get engineDescPmd =>
      'Professional Music Driver для PC-98 — FM OPNA + SSG + сэмплы PPZ8';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ сэмплы .pdx), FM YM2151';

  @override
  String get engineDescFmp =>
      'Драйвер FMP для PC-98 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'EUPHONY для FM Towns — FM YM2612 + PCM (.eup)';

  @override
  String get engineDescMac => 'Lossless .ape';

  @override
  String get engineDescVgmstream =>
      'Потоковые игровые аудиоформаты (700+, включая .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — запасной декодер';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total песни',
      many: '$loaded / $total песен',
      few: '$loaded / $total песни',
      one: '$loaded / $total песня',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total альбома',
      many: '$loaded / $total альбомов',
      few: '$loaded / $total альбома',
      one: '$loaded / $total альбом',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total исполнителя',
      many: '$loaded / $total исполнителей',
      few: '$loaded / $total исполнителя',
      one: '$loaded / $total исполнитель',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n песни',
      many: '$n песен',
      few: '$n песни',
      one: '$n песня',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n альбома',
      many: '$n альбомов',
      few: '$n альбома',
      one: '$n альбом',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n исполнителя',
      many: '$n исполнителей',
      few: '$n исполнителя',
      one: '$n исполнитель',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n группы',
      many: '$n групп',
      few: '$n группы',
      one: '$n группа',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Страны';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n страны',
      many: '$n стран',
      few: '$n страны',
      one: '$n страна',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Папки';

  @override
  String get featuredTitle => 'Сегодня в центре внимания';

  @override
  String featuredPartyNow(String party) {
    return '$party проходит прямо сейчас — призёры прошлых выпусков';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party начинается через $days дней — призёры прошлых выпусков',
      many: '$party начинается через $days дней — призёры прошлых выпусков',
      few: '$party начинается через $days дня — призёры прошлых выпусков',
      one: '$party начинается через $days день — призёры прошлых выпусков',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return 'Сезон $series — призёры прошлых выпусков';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Вышло: $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age лет назад: игры $year года',
      many: '$age лет назад: игры $year года',
      few: '$age года назад: игры $year года',
      one: '$age год назад: игры $year года',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade-е годы';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age лет назад: игры $year года',
      many: '$age лет назад: игры $year года',
      few: '$age года назад: игры $year года',
      one: '$age год назад: игры $year года',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Премьеры: $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Годовщины';

  @override
  String get featuredBirthdayHeader => 'Дни рождения сегодня';

  @override
  String get featuredBirthdayWeekHeader => 'Дни рождения на этой неделе';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist — день рождения на этой неделе';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count плейлистов',
      many: '$count плейлистов',
      few: '$count плейлиста',
      one: '$count плейлист',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonOptions => 'Опции';

  @override
  String get commonDownload => 'Загрузить';

  @override
  String get commonDeleteDownload => 'Удалить загрузку';

  @override
  String get commonAddToPlaylist => 'Добавить в плейлист';

  @override
  String get commonPlayNext => 'Слушать далее';

  @override
  String get commonAddToQueueEnd => 'Добавить в конец очереди';

  @override
  String get commonAddToFavorites => 'Добавить в избранное';

  @override
  String get commonRemoveFromFavorites => 'Убрать из избранного';

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
  String get subsongDeleteDownloadTitle => 'Удалить эту загрузку?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Файл и его локальные записи (история, треки) будут удалены.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Не удалось прочитать треки';

  @override
  String subsongTrackNumber(int number) {
    return 'Трек $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count субтрека',
      many: '$count субтреков',
      few: '$count субтрека',
      one: '$count субтрек',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Воспроизвести всё';

  @override
  String get albumDownloading => 'Загрузка альбома…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Загрузка альбома… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Загрузите альбом, чтобы увидеть его треки';

  @override
  String get albumNotDownloadedHint =>
      'Альбом не загружен — запустите воспроизведение, чтобы загрузить его';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count трека',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Загрузка сведений…';

  @override
  String albumAka(String label) {
    return 'aka $label';
  }

  @override
  String get albumPlayAlbum => 'Воспроизвести альбом';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Сначала воспроизведите этот трек из поиска, чтобы загрузить его';

  @override
  String get libraryAddedTrack => 'Трек добавлен в медиатеку';

  @override
  String get libraryAddedAlbum => 'Альбом добавлен в медиатеку';

  @override
  String get libraryAddedArtist => 'Исполнитель добавлен в медиатеку';

  @override
  String get libraryRemovedTrack => 'Трек удалён из медиатеки';

  @override
  String get libraryRemovedAlbum => 'Альбом удалён из медиатеки';

  @override
  String get libraryRemovedArtist => 'Исполнитель удалён из медиатеки';

  @override
  String songTilePlayFailed(String message) {
    return 'Не удалось воспроизвести: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Не удалось загрузить — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Загрузка — $label';
  }

  @override
  String get downloadsTitle => 'Загрузки';

  @override
  String get downloadsEmpty => 'Нет ожидающих загрузок';

  @override
  String get downloadsPause => 'Приостановить';

  @override
  String get downloadsResume => 'Возобновить';

  @override
  String get downloadsCancel => 'Отменить загрузку';

  @override
  String get downloadsClear => 'Убрать все';

  @override
  String get downloadsPausedBanner =>
      'Загрузки приостановлены — текущий файл будет завершён';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Загрузка — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Плейлист';

  @override
  String get miniPlayerHideQueue => 'Скрыть плейлист';

  @override
  String get transportShuffle => 'Перемешать';

  @override
  String get transportShuffleOn => 'Перемешивание включено';

  @override
  String get transportLoopOff => 'Повтор выключен';

  @override
  String get transportLoopQueue => 'Повтор: очередь';

  @override
  String get transportLoopTrack => 'Повтор: текущий трек';

  @override
  String get vizStereo => 'Стерео';

  @override
  String get vizSpectrum => 'Спектр';

  @override
  String get vizVoices => 'Голоса';

  @override
  String get vizNotes => 'Ноты';

  @override
  String get vizPatterns => 'Паттерны';

  @override
  String get patternScrollMode => 'Режим прокрутки';

  @override
  String get patternSmoothScroll => 'Плавная прокрутка';

  @override
  String get patternVolumeBars => 'Полосы громкости';

  @override
  String get patternColorScheme => 'Цветовая схема';

  @override
  String get patternSize => 'Размер';

  @override
  String get patternColumns => 'Столбцы';

  @override
  String get patternColumnsAll => 'Полный';

  @override
  String get patternColumnsNoteInstr => 'Сокращённый';

  @override
  String get patternColumnsNote => 'Минимальный';

  @override
  String get vizClose => 'Закрыть визуализатор';

  @override
  String get vizFullscreen => 'Полный экран';

  @override
  String get vizExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get vizPrevPreset => 'Предыдущий preset';

  @override
  String get vizNextPreset => 'Следующий preset';

  @override
  String get vizProjectmUnavailable => 'projectM недоступен';

  @override
  String get voicesTitle => 'Голоса';

  @override
  String get voicesNone => 'Для этого трека нет голосов.';

  @override
  String get voicesLongPressSolo => 'долгое нажатие = соло';

  @override
  String get voicesMuteAll => 'Выключить все';

  @override
  String get voicesUnmuteAll => 'Включить все';

  @override
  String get voicesStereoOutput => 'Стереовыход';

  @override
  String get voicesLeft => 'Левый';

  @override
  String get voicesRight => 'Правый';

  @override
  String get enginesFormatsTitle => 'Поддерживаемые форматы';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats воспроизводимых форматов в $engines движках воспроизведения.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count формата',
      many: '$count форматов',
      few: '$count формата',
      one: '$count формат',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Кавер на «$title» ($artist)';
  }

  @override
  String stilCover(String work) {
    return 'Кавер на «$work»';
  }

  @override
  String get playerQueue => 'Очередь';

  @override
  String get queueEdit => 'Изменить';

  @override
  String get queueEditDone => 'Готово';

  @override
  String get queueClear => 'Очистить очередь';

  @override
  String get queueClearConfirmTitle => 'Очистить очередь?';

  @override
  String get queueClearConfirmBody =>
      'Очередь будет очищена, воспроизведение остановится.';

  @override
  String get queueClearConfirm => 'Очистить';

  @override
  String get queueRemoveSelected => 'Удалить выбранные';

  @override
  String get queueRemoveTrack => 'Убрать из очереди';

  @override
  String get queueReorder => 'Изменить порядок';

  @override
  String get playerArtwork => 'Обложка';

  @override
  String get playerVisualizer => 'Визуализатор';

  @override
  String get playerVoices => 'Голоса';

  @override
  String get playerTrackInfo => 'Сведения о треке';

  @override
  String get playerShowQueue => 'Плейлист';

  @override
  String get playerHideQueue => 'Скрыть плейлист';

  @override
  String get playerNoTrackInfo => 'Нет доступной информации.';

  @override
  String get playerViewSubsongs => 'Показать субтреки';

  @override
  String get playerViewAlbum => 'Перейти к альбому';

  @override
  String get playerViewArtist => 'Перейти к исполнителю';

  @override
  String get playerAddToPlaylist => 'Добавить в плейлист';

  @override
  String get queueAddToPlaylist => 'Добавить очередь в плейлист';

  @override
  String get playerMoreOptions => 'Ещё';

  @override
  String get playerClose => 'Закрыть';

  @override
  String get playerCancel => 'Отмена';

  @override
  String get playerDelete => 'Удалить';

  @override
  String get playerAddFavorite => 'Добавить в избранное';

  @override
  String get playerRemoveFavorite => 'Убрать из избранного';

  @override
  String get playerAddToLibrary => 'Добавить в медиатеку';

  @override
  String get playerRemoveFromLibrary => 'Удалить из медиатеки';

  @override
  String get playerAddedToLibrary => 'Трек добавлен в медиатеку';

  @override
  String get playerRemovedFromLibrary => 'Трек удалён из медиатеки';

  @override
  String get playerDeleteDownload => 'Удалить загрузку';

  @override
  String get playerRedownload => 'Скачать файл заново';

  @override
  String get playerRedownloadUnavailable =>
      'Повторная загрузка недоступна для этого файла';

  @override
  String get playerDeleteDownloadTitle => 'Удалить загрузку?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Файл и его локальные записи (история, треки) будут удалены.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Ваши тренды';

  @override
  String get homeYourAllTimeTop => 'Ваш топ за всё время';

  @override
  String get homeTrending => 'В тренде';

  @override
  String get homeFeaturedPlaylists => 'Рекомендуемые плейлисты';

  @override
  String get homeAllTimeTop => 'Топ за всё время';

  @override
  String get homePeriod7d => '7 д';

  @override
  String get homePeriod30d => '30 д';

  @override
  String get homePeriod90d => '90 д';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n прослушивания',
      many: '$n прослушиваний',
      few: '$n прослушивания',
      one: '$n прослушивание',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n трека',
      many: '$n треков',
      few: '$n трека',
      one: '$n трек',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Плейлист пуст или не читается';

  @override
  String get homeExtractingArchive => 'Распаковка архива…';

  @override
  String get homeArchiveEmpty => 'В архиве нет воспроизводимых файлов';

  @override
  String get homeNothingPlayable => 'В выборе нет ничего воспроизводимого';

  @override
  String get homeAlbumLoadFailed => 'Не удалось загрузить этот альбом';

  @override
  String get homeSongLoadFailed => 'Не удалось загрузить этот трек';

  @override
  String get navStats => 'Статистика';

  @override
  String get navSettings => 'Настройки';

  @override
  String get playlistMoveUp => 'В родительскую папку';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n плейлиста',
      many: '$n плейлистов',
      few: '$n плейлиста',
      one: '$n плейлист',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n подпапки',
      many: '$n подпапок',
      few: '$n подпапки',
      one: '$n подпапка',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Эта папка и всё её содержимое будут удалены навсегда:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Эта папка будет удалена.';

  @override
  String get playlistFolderRoot => 'Корень';

  @override
  String get playlistMoveToFolder => 'Переместить в папку';

  @override
  String playlistDeleteTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get playlistDeleteBody => 'Этот плейлист будет удалён навсегда.';

  @override
  String get playlistRenameFolderTitle => 'Переименовать папку';

  @override
  String get playlistClearFavorites => 'Удалить все избранные';

  @override
  String get playlistClearFavoritesTitle => 'Удалить все избранные?';

  @override
  String get playlistClearFavoritesBody =>
      'Вы потеряете все избранные треки. Это действие необратимо.';

  @override
  String get playlistRemoveFromLibrary => 'Убрать из библиотеки';

  @override
  String get playlistServerReadOnly => 'Плейлист сервера · только для чтения';

  @override
  String get navAbout => 'О приложении';

  @override
  String get navMore => 'Ещё';

  @override
  String get shellAlbumQueuedAtEnd => 'Альбом добавлен в конец очереди';

  @override
  String get shellAlbumQueuedNext => 'Альбом будет воспроизведён следующим';

  @override
  String get shellAddingToQueue => 'Добавление в очередь…';

  @override
  String get shellAddingNext => 'Добавление для воспроизведения далее…';

  @override
  String shellDownloadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count трека в очередь',
      many: 'Добавлено $count треков в очередь',
      few: 'Добавлено $count трека в очередь',
      one: 'Добавлен $count трек в очередь',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" добавлен в конец очереди';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" будет воспроизведён следующим';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Ошибка загрузки: $title — переход к следующему треку';
  }

  @override
  String get shellNetworkUnavailable =>
      'Воспроизведение остановлено: сеть недоступна.';

  @override
  String get statsTitle => 'Статистика';

  @override
  String statsPeriodDays(int n) {
    return '$n дн.';
  }

  @override
  String get statsPeriodThisYear => 'В этом году';

  @override
  String get statsPeriodAll => 'За всё время';

  @override
  String get statsByMonthOrYear => 'По месяцам / годам…';

  @override
  String get statsByYear => 'По годам';

  @override
  String get statsByMonth => 'По месяцам';

  @override
  String get statsPlaysLabel => 'Прослушивания';

  @override
  String get statsTracksLabel => 'Треки';

  @override
  String get statsArtistsLabel => 'Исполнители';

  @override
  String get statsAlbumsLabel => 'Альбомы';

  @override
  String get statsListenTime => 'Время прослушивания';

  @override
  String get statsByCollection => 'По коллекциям';

  @override
  String get statsByFormat => 'По форматам';

  @override
  String get statsByEngine => 'По движкам';

  @override
  String get statsPlaylistsLabel => 'Плейлисты';

  @override
  String get statsLocalFilesSection => 'Загруженные файлы';

  @override
  String get statsFilesLabel => 'Файлы';

  @override
  String get statsSpaceLabel => 'Место на диске';

  @override
  String get statsNoPlaysInPeriod => 'Нет прослушиваний за этот период';

  @override
  String get statsNoPlays => 'Нет прослушиваний';

  @override
  String get statsTopTracks => 'Топ треков';

  @override
  String get statsTopAlbums => 'Топ альбомов';

  @override
  String get statsTopArtists => 'Топ исполнителей';

  @override
  String statsTopTracksIn(String period) {
    return 'Топ треков — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Топ альбомов — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Топ исполнителей — $period';
  }

  @override
  String get statsSeeAll => 'Показать всё';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n прослушивания',
      many: '$n прослушиваний',
      few: '$n прослушивания',
      one: '$n прослушивание',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n трека',
      many: '$n треков',
      few: '$n трека',
      one: '$n трек',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'макс. $n';
  }

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRename => 'Переименовать';

  @override
  String get commonSort => 'Сортировать';

  @override
  String get commonPlayAll => 'Воспроизвести всё';

  @override
  String get sortName => 'Название';

  @override
  String get sortTitle => 'Название';

  @override
  String get sortArtist => 'Исполнитель';

  @override
  String get sortAlbum => 'Альбом';

  @override
  String get sortDateAdded => 'Дата добавления';

  @override
  String get commonClear => 'Очистить';

  @override
  String get sortRecentlyModified => 'Недавно изменённые';

  @override
  String get sortCreationDate => 'Дата создания';

  @override
  String get playlistNameHint => 'Название';

  @override
  String get playlistNew => 'Новый плейлист';

  @override
  String get playlistNewFolder => 'Новая папка';

  @override
  String get playlistNewTooltip => 'Новый плейлист / папка';

  @override
  String get playlistAddTo => 'Добавить в плейлист';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Добавить в $n плейлиста',
      many: 'Добавить в $n плейлистов',
      few: 'Добавить в $n плейлиста',
      one: 'Добавить в $n плейлист',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Выберите плейлист';

  @override
  String get playlistFilterHint => 'Фильтр плейлистов…';

  @override
  String get playlistSearchHint => 'Поиск плейлиста…';

  @override
  String get playlistNoMatch => 'Нет подходящих плейлистов';

  @override
  String get playlistNoneCreateHint =>
      'Нет плейлистов — создайте один с помощью +';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n трека',
      many: '$n треков',
      few: '$n трека',
      one: '$n трек',
      zero: 'Нет треков',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Уже добавлено';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n элемента уже есть в выбранных плейлистах.',
      many: '$n элементов уже есть в выбранных плейлистах.',
      few: '$n элемента уже есть в выбранных плейлистах.',
      one: '$n элемент уже есть в выбранных плейлистах.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Пропустить дубликаты';

  @override
  String get playlistAddAgain => 'Добавить снова';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Добавлено $n трека',
      many: 'Добавлено $n треков',
      few: 'Добавлено $n трека',
      one: 'Добавлен $n трек',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m плейлиста',
      many: '$m плейлистов',
      few: '$m плейлиста',
      one: '$m плейлист',
    );
    return '$_temp0 в $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Не удалось добавить: $error';
  }

  @override
  String get playlistRenameTitle => 'Переименовать плейлист';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Удалить папку «$name»?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'Её содержимое переместится на уровень выше.';

  @override
  String get playlistEmpty => 'Пустой плейлист';

  @override
  String get playlistRemoveEntry => 'Удалить из плейлиста';

  @override
  String get trackOptionsAddToLibrary => 'Добавить в медиатеку';

  @override
  String get trackOptionsRemoveFromLibrary => 'Удалить из медиатеки';

  @override
  String get trackOptionsAddedToLibrary => 'Трек добавлен в медиатеку';

  @override
  String get trackOptionsRemovedFromLibrary => 'Трек удалён из медиатеки';

  @override
  String get trackOptionsViewAlbum => 'Перейти к альбому';

  @override
  String get trackOptionsViewArtist => 'Перейти к исполнителю';

  @override
  String get trackOptionsPlayNow => 'Слушать сейчас';

  @override
  String get trackOptionsPlayNext => 'Слушать далее';

  @override
  String get trackOptionsAddToQueueEnd => 'Добавить в конец очереди';

  @override
  String get trackOptionsPlayLast => 'Слушать последним';

  @override
  String get trackOptionsDeleteDownload => 'Удалить загрузку';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Удалить эту загрузку?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Файл и его локальные записи (история, треки) будут удалены.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Загрузка удалена';

  @override
  String get trackOptionsAddToFavorites => 'Добавить в избранное';

  @override
  String get trackOptionsRemoveFromFavorites => 'Убрать из избранного';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Альбом добавлен в избранное';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Альбом убран из избранного';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Альбом не загружен — удалять нечего';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Удалить загруженный альбом?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Папка и все её локальные записи (треки, история) будут удалены.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Альбом удалён из локального хранилища';

  @override
  String get trackOptionsRedownloadAlbum => 'Загрузить альбом заново';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Перезаписывает файлы И локальные записи';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Удалить файлы альбома';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Загруженная папка + локальные записи (история)';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsGeneral => 'Основные';

  @override
  String get settingsGeneralSubtitle => 'Тема';

  @override
  String get settingsVisualisation => 'Визуализация';

  @override
  String get settingsVisualisationSubtitle => 'Осциллографы, обложка на фоне';

  @override
  String get settingsPlayback => 'Воспроизведение';

  @override
  String get settingsPlaybackSubtitle => 'Повторы, затухание, тишина';

  @override
  String get settingsEngines => 'Движки';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Данные';

  @override
  String get settingsDataSubtitle => 'Идентификатор, история, сброс';

  @override
  String get settingsBackupExport => 'Экспорт резервной копии';

  @override
  String get settingsBackupExportSubtitle =>
      'Сохранить библиотеку, плейлисты и настройки в файл';

  @override
  String get settingsBackupImport => 'Импорт резервной копии';

  @override
  String get settingsBackupImportSubtitle =>
      'Восстановить данные из файла резервной копии';

  @override
  String get settingsBackupExportFailed =>
      'Не удалось экспортировать резервную копию';

  @override
  String get settingsBackupImportConfirmTitle =>
      'Импортировать резервную копию?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Это заменит библиотеку, плейлисты и настройки на этом устройстве. Загруженные файлы сохранятся.';

  @override
  String get settingsBackupImportConfirm => 'Импортировать';

  @override
  String get settingsBackupImportedTitle => 'Резервная копия импортирована';

  @override
  String get settingsBackupImportedBody =>
      'Данные восстановлены. Перезапустите приложение, чтобы применить всё.';

  @override
  String get settingsBackupTooNew =>
      'Эта резервная копия создана более новой версией приложения';

  @override
  String get settingsBackupInvalid => 'Недействительная резервная копия Rewamp';

  @override
  String get settingsBackupImportFailed =>
      'Не удалось импортировать резервную копию';

  @override
  String get settingsAbout => 'О программе';

  @override
  String get settingsAboutSubtitle => 'Благодарности и лицензии';

  @override
  String get settingsCreditsSubtitle => 'Библиотеки, данные и компоненты';

  @override
  String get settingsSupport => 'Контакты и поддержка';

  @override
  String get settingsSupportSubtitle => 'Связаться, сайт';

  @override
  String get settingsSupportEmail => 'Отправить письмо';

  @override
  String get settingsSupportEmailSubtitle => 'Вопрос, ошибка или предложение';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — поддержка';

  @override
  String get settingsSupportEmailIntro =>
      'Опишите выше свой вопрос, ошибку или предложение. Данные ниже помогают нам помочь вам.';

  @override
  String get settingsSupportWebsite => 'Сайт';

  @override
  String get settingsDonation => 'Поддержать Rewamp';

  @override
  String get settingsDonationSubtitle => 'Чаевые, если хотите';

  @override
  String get settingsDonationBlurb =>
      'Rewamp бесплатен и без рекламы — проект, созданный с любовью ради сохранения культуры демосцены и ретро. Пожертвования помогают финансировать разработку приложения и покрывать расходы на хостинг базы данных. Без обязательств: если приложение приносит вам радость, небольшой жест всегда приятен.';

  @override
  String get settingsDonationFloppy => 'Дискета';

  @override
  String get settingsDonationCartridge => 'Картридж';

  @override
  String get settingsDonationBox => 'Игра в коробке';

  @override
  String get settingsDonationCustom => 'Выбрать сумму';

  @override
  String get settingsCancel => 'Отмена';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Удалить';

  @override
  String get settingsReset => 'Сбросить';

  @override
  String get settingsRenew => 'Обновить';

  @override
  String get settingsOff => 'Выкл.';

  @override
  String get settingsOn => 'Вкл.';

  @override
  String get settingsAuto => 'Авто';

  @override
  String get settingsInfinite => 'Бесконечно';

  @override
  String get settingsDefault => 'По умолчанию';

  @override
  String get settingsCoreNoScope => 'без осциллографа';

  @override
  String get settingsNone => 'Нет';

  @override
  String get settingsLevelLow => 'Низкое';

  @override
  String get settingsLevelHigh => 'Высокое';

  @override
  String get settingsStereo => 'Стерео';

  @override
  String get settingsSurround => 'Surround';

  @override
  String settingsValuePercent(int value) {
    return '$value %';
  }

  @override
  String settingsValueSeconds(int value) {
    return '$value с';
  }

  @override
  String settingsValueSecondsFrac(String value) {
    return '$value с';
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
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsArtworkTintTitle => 'Окрашивать плеер под обложку';

  @override
  String get settingsArtworkTintSubtitle =>
      'Плеер принимает доминирующий цвет обложки';

  @override
  String get settingsGlassEffectTitle => 'Эффект liquid glass';

  @override
  String get settingsGlassEffectSubtitle =>
      'Линза и размытие нижних панелей — отключите на медленных устройствах';

  @override
  String get settingsResetSection => 'Сбросить этот раздел';

  @override
  String get settingsResetEngine => 'Сбросить этот движок';

  @override
  String get settingsResetChoices => 'Сбросить эти настройки';

  @override
  String get settingsResetToDefault => 'Значение по умолчанию';

  @override
  String get settingsStartInVizTitle => 'Запускать в режиме визуализации';

  @override
  String get settingsStartInVizSubtitle =>
      'Плеер открывается на осциллографах, а не на обложке';

  @override
  String get settingsVoiceGridTitle => 'Сетка осциллографа голосов';

  @override
  String get settingsVoiceGridSubtitle => 'Показывать границы между голосами';

  @override
  String get settingsKeepAwakeTitle => 'Не гасить экран';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Пока показана визуализация, экран не гаснет и не блокируется';

  @override
  String get settingsVoiceNamesTitle => 'Названия голосов';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Показывать название каждого голоса в его рамке';

  @override
  String get settingsLineThickness => 'Толщина линии';

  @override
  String get settingsColors => 'Цвета';

  @override
  String get settingsScopeVoiceColor => 'Осциллограф голосов';

  @override
  String get settingsStereoColors => 'Стерео: цвета';

  @override
  String get settingsStereoMono => 'Моно';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Стерео (моно)';

  @override
  String get settingsStereoLeftColor => 'Стерео слева';

  @override
  String get settingsStereoRightColor => 'Стерео справа';

  @override
  String get settingsNotation => 'Нотация (ноты)';

  @override
  String get settingsNotePalette => 'Цветовая палитра';

  @override
  String get settingsNoteBoxStyle => 'Стиль блоков';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'Эффекты CRT';

  @override
  String get settingsCrtGlow => 'Свечение (glow)';

  @override
  String get settingsCrtSpeed => 'Интенсивность / скорость';

  @override
  String get settingsArtworkOpacity => 'Непрозрачность обложки на фоне';

  @override
  String get settingsProjectMTitle => 'Настройки projectM';

  @override
  String get settingsProjectMSubtitle => 'Presets, переходы, качество, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Уведомления при смене трека';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Системное уведомление с названием нового трека';

  @override
  String get settingsSilenceDetection => 'Определение тишины';

  @override
  String get settingsSilenceSkipTitle =>
      'Переходить к следующему треку при тишине';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Автоматически идёт дальше, когда на выходе остаётся тишина';

  @override
  String get settingsSilenceDelay => 'Задержка тишины';

  @override
  String get settingsDefaultDuration => 'Длительность по умолчанию';

  @override
  String get settingsDefaultDurationHelp =>
      'Используется, когда у трека нет известной длительности (нет тега, нет метаданных с сервера) — чтобы он не играл и не зацикливался бесконечно. Никогда не применяется к трекам Amiga (UADE), у которых есть собственная база длительностей.';

  @override
  String get settingsForcedLoopHeader => 'Принудительный повтор / затухание';

  @override
  String get settingsForcedLoopHelp =>
      'Некоторые форматы зацикливают определённый фрагмент (VGM, модули tracker…), другие — нет. «Бесконечно» игнорирует естественный конец трека.';

  @override
  String get settingsForceLoopCount => 'Задать число повторов';

  @override
  String get settingsLoopCount => 'Число повторов';

  @override
  String get settingsForceFadeout => 'Принудительное затухание';

  @override
  String get settingsFadeoutDuration => 'Длительность затухания';

  @override
  String get settingsResetEnginesTitle => 'Сбросить настройки движков?';

  @override
  String get settingsResetEnginesBody =>
      'Все настройки движков вернутся к значениям по умолчанию.';

  @override
  String get settingsResetDefaultsTitle => 'Сбросить к значениям по умолчанию';

  @override
  String get settingsResetDefaultsSubtitle => 'Все движки';

  @override
  String get settingsDefaultDecoders => 'Декодеры по умолчанию';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Форматы, которые может читать несколько движков';

  @override
  String get settingsDecodersHelp =>
      'Некоторые форматы могут воспроизводиться несколькими движками. Выберите, какой использовать по умолчанию — все остальные форматы направляются автоматически.';

  @override
  String get settingsDecoderAmigaTrackers => 'Трекеры Amiga (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Трекеры — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — эквалайзер, стерео';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — качество, фильтры, опции по чипам';

  @override
  String get settingsEngineGbsSubtitle =>
      'Game Boy / GBS — фильтр верхних частот';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — используемый SoundFont';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — интерполяция, фильтр НЧ, эхо';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — панорама, наушники, усиление, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — тактовая частота, модель, фильтры ReSIDfp';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — гармонический режим стерео/surround';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, реверберация';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — ядра YM2612, OPL3, QSound…';

  @override
  String get settingsMasterVolume => 'Общая громкость';

  @override
  String get settingsAmigaFilter => 'Фильтр Amiga';

  @override
  String get settingsInterpolation => 'Интерполяция';

  @override
  String get settingsPolyphony => 'Полифония';

  @override
  String get settingsReverb => 'Реверберация';

  @override
  String get settingsChorus => 'Хорус';

  @override
  String get settingsInterpNone => 'Нет';

  @override
  String get settingsInterpLinear => 'Линейная';

  @override
  String get settingsInterpCubic => 'Кубическая';

  @override
  String get settingsInterpSinc => 'Sinc (лучшая)';

  @override
  String get settingsStereoSeparation => 'Стереоразделение';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Завершает трек, когда движок обнаруживает долгую тишину';

  @override
  String get settingsStereoDepth => 'Глубина стерео';

  @override
  String get settingsEqualizer => 'Эквалайзер';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — не влияет на SPC';

  @override
  String get settingsBass => 'Низкие частоты';

  @override
  String get settingsTreble => 'Высокие частоты';

  @override
  String get settingsAppliedLive =>
      'Применяется сразу, даже во время воспроизведения.';

  @override
  String get settingsAppliedNextTrack =>
      'Применяется к следующему загруженному треку.';

  @override
  String get settingsSidEmulation => 'Эмуляция';

  @override
  String get settingsSidResidfp => 'ReSIDfp (точная)';

  @override
  String get settingsSidLite => 'SIDLite (быстрая)';

  @override
  String get settingsSidSampling => 'Сэмплирование';

  @override
  String get settingsSidSamplingInterp => 'Интерполяция (быстро)';

  @override
  String get settingsSidSamplingResample => 'Resample (лучше)';

  @override
  String get settingsSidClock => 'Тактовая частота';

  @override
  String get settingsSidModel => 'Модель SID';

  @override
  String get settingsSidFilter => 'Фильтр SID';

  @override
  String get settingsSidForceSecond => 'Включить 2-й SID';

  @override
  String get settingsSidSecondSubtitle => 'Стереотреки 2SID';

  @override
  String get settingsSidSecondAddr => 'Адрес 2-го SID';

  @override
  String get settingsSidForceThird => 'Включить 3-й SID';

  @override
  String get settingsSidThirdAddr => 'Адрес 3-го SID';

  @override
  String get settingsSidAutoFilter => 'Автоматический диапазон фильтра 6581';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Значение, рекомендованное для автора трека (таблицы sidplayfp)';

  @override
  String get settingsSid6581Range => 'Диапазон фильтра 6581';

  @override
  String get settingsSid6581Curve => 'Кривая фильтра 6581';

  @override
  String get settingsSid8580Curve => 'Кривая фильтра 8580';

  @override
  String get settingsSidNote =>
      'Фильтр SID и кривые применяются сразу; эмуляция/сэмплирование/тактовая частота/модель/2-й и 3-й SID — со следующего трека.';

  @override
  String get settingsAudioOutput => 'Аудиовыход';

  @override
  String get settingsAdplugNote =>
      'Surround: два слегка расстроенных чипа OPL. Применяется к следующему треку.';

  @override
  String get settingsHeSpuMain => 'Основные голоса (SPU)';

  @override
  String get settingsHeSpuReverb => 'Реверберация (SPU)';

  @override
  String get settingsNsfQuality => 'Качество (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Фильтр нижних частот';

  @override
  String get settingsHighpassFilter => 'Фильтр верхних частот';

  @override
  String get settingsRegion => 'Регион';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC принудительно';

  @override
  String get settingsNsfRegionPalForced => 'PAL принудительно';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy принудительно';

  @override
  String get settingsNsfForceIrq => 'Принудительный IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — импульсные каналы (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — треугольник / шум / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Включать звук при сбросе';

  @override
  String get settingsNsfPhaseRefresh => 'Обновлять фазу';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Сбрасывать фазу при записи периода';

  @override
  String get settingsNsfNonlinearMixer => 'Нелинейное микширование';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      'Реальное микширование 2A03 (иначе линейное)';

  @override
  String get settingsNsfDutySwap => 'Поменять местами duty cycles';

  @override
  String get settingsNsfDutySwapSubtitle => 'Порядок duty 25 % / 50 %';

  @override
  String get settingsNsfNegateSweep => 'Отрицательный sweep при инициализации';

  @override
  String get settingsNsfEnable4011 => 'Регистр \$4011 включён';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Прямой выход DAC (оригинальные щелчки)';

  @override
  String get settingsNsfPeriodicNoise => 'Периодический шум';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Короткий режим генератора шума';

  @override
  String get settingsNsfDpcmAntiClick => 'Антищелчок DPCM';

  @override
  String get settingsNsfRandomizeNoise => 'Случайный шум при инициализации';

  @override
  String get settingsNsfTriangleMute => 'Приглушать треугольник';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Заглушает треугольник на ультразвуковых периодах';

  @override
  String get settingsNsfRandomizeTri =>
      'Случайный треугольник при инициализации';

  @override
  String get settingsNsfDpcmReverse => 'Обратный DPCM';

  @override
  String get settingsNsfN163Serial => 'Последовательное мультиплексирование';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'Настоящий гул N163 на многоголосых треках';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Фаза только для чтения';

  @override
  String get settingsNsfN163LimitWavelength => 'Ограничить длину волны';

  @override
  String get settingsNsfFdsCutoff => 'Частота среза фильтра нижних частот';

  @override
  String get settingsNsfFds4085Reset => 'Сброс \$4085';

  @override
  String get settingsNsfFdsWriteProtect => 'Защита от записи';

  @override
  String get settingsNsfVrc7Patch => 'Набор патчей';

  @override
  String get settingsNsfVrc7Opll => 'Режим OPLL';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Эмулировать YM2413 вместо VRC7';

  @override
  String get settingsGbsHpFilter => 'Фильтр верхних частот (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (классический GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Эхо';

  @override
  String get settingsUadePostfx => 'Постобработка';

  @override
  String get settingsUadePostfxSubtitle =>
      'Включает цепочку эффектов (нужна для всего ниже)';

  @override
  String get settingsUadePan => 'Панорама (стереоразделение)';

  @override
  String get settingsUadePanValue => 'Величина панорамы';

  @override
  String get settingsUadeHeadphones => 'Наушники';

  @override
  String get settingsUadeLed => 'LED (фильтр Paula)';

  @override
  String get settingsUadeLedAuto => 'Авто (по треку)';

  @override
  String get settingsUadeLedOn => 'Принудительно ВКЛ';

  @override
  String get settingsUadeLedOff => 'Принудительно ВЫКЛ';

  @override
  String get settingsUadeFilterType => 'Тип фильтра';

  @override
  String get settingsUadeGain => 'Усиление';

  @override
  String get settingsUadeGainValue => 'Величина усиления';

  @override
  String get settingsSoundfontLoading => 'Загрузка каталога…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Каталог недоступен ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get settingsSoundfontImport => 'Импортировать SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Выберите файл .sf2 на этом устройстве';

  @override
  String get settingsSoundfontImported => 'Импортирована';

  @override
  String get settingsSoundfontInvalid =>
      'Этот файл не является SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Не удалось импортировать — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Удалить файл';

  @override
  String get settingsCreditsHeader => 'Благодарности и лицензии';

  @override
  String get settingsRightsNotice =>
      'Rewamp — это проигрыватель: он не размещает файлы и не распространяет музыку. Композиции происходят из онлайн-архивов сохранения наследия и остаются собственностью правообладателей. Вы сами обязаны убедиться, что их прослушивание, скачивание и хранение соответствуют применимым правам и законодательству вашей страны.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Поддерживается $count формата',
      many: 'Поддерживается $count форматов',
      few: 'Поддерживается $count формата',
      one: 'Поддерживается $count формат',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Распределены по $count движкам воспроизведения — смотреть подробности',
      many:
          'Распределены по $count движкам воспроизведения — смотреть подробности',
      few:
          'Распределены по $count движкам воспроизведения — смотреть подробности',
      one:
          'Обрабатывается $count движком воспроизведения — смотреть подробности',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Длительности и метаданные Amiga';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb, автор Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'Данные и обложки C64 / SID';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — метаданные и изображения игр C64.';

  @override
  String get settingsFt2FontTitle => 'Шрифт FastTracker 2';

  @override
  String get settingsFt2FontSubtitle =>
      'Стиль FastTracker II визуализатора паттернов использует растровый шрифт FT2 из ft2-clone от 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url скопирован';
  }

  @override
  String get settingsOpenLink => 'Открыть ссылку';

  @override
  String get settingsEnginesHeader => 'Движки воспроизведения';

  @override
  String get settingsComponentsHeader => 'Прочие компоненты';

  @override
  String get settingsResetAll => 'Сбросить все настройки';

  @override
  String get settingsResetAllSubtitle =>
      'Основные, Визуализация, Воспроизведение, Движки — кроме медиатеки';

  @override
  String get settingsResetAllTitle => 'Сбросить все настройки?';

  @override
  String get settingsResetAllBody =>
      'Основные, Визуализация, Воспроизведение и все движки вернутся к значениям по умолчанию. Ваша медиатека и история не затрагиваются.';

  @override
  String get settingsRenewUserId => 'Обновить анонимный идентификатор';

  @override
  String get settingsRenewUserIdTitle => 'Обновить анонимный идентификатор?';

  @override
  String get settingsRenewUserIdBody =>
      'Для серверной статистики будет создан новый анонимный идентификатор.\n\nСтарый больше не будет использоваться. Локальная история и избранное не затрагиваются.';

  @override
  String get settingsRenewUserIdFailed => 'Ошибка — сервер недоступен';

  @override
  String settingsNewUserId(String id) {
    return 'Новый идентификатор: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'Идентификатор не зарегистрирован';

  @override
  String get settingsCleanDb => 'Очистить локальную базу данных';

  @override
  String get settingsCleanDbSubtitle =>
      'Удаляет записи, файл которых больше не существует (удалённые загрузки, старые ошибки)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count потерянные записи',
      many: 'Удалено $count потерянных записей',
      few: 'Удалено $count потерянные записи',
      one: 'Удалена $count потерянная запись',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'Локальная база данных чиста — удалять нечего';

  @override
  String get settingsClearCache => 'Очистить кеш (обложки и метаданные)';

  @override
  String get settingsClearCacheSubtitle =>
      'Удаляет обложки из кеша и полученные метаданные (STIL, длительности) — они будут загружены заново при следующем воспроизведении';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Кеш очищен ($count обложки)',
      many: 'Кеш очищен ($count обложек)',
      few: 'Кеш очищен ($count обложки)',
      one: 'Кеш очищен ($count обложка)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Сбросить статистику';

  @override
  String get settingsResetStatsSubtitle =>
      'Удаляет историю прослушиваний и счётчики воспроизведений';

  @override
  String get settingsClearStatsTitle => 'Сбросить статистику?';

  @override
  String get settingsClearStatsBody =>
      'Будет безвозвратно удалено:\n• вся история прослушиваний\n• счётчики воспроизведений\n\nВаше избранное и медиатека не затрагиваются.';

  @override
  String get settingsStatsCleared => 'Статистика удалена';

  @override
  String get settingsResetDatabase => 'Сбросить базу данных';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Удаляет всё: историю, избранное, плейлисты, кеш';

  @override
  String get settingsResetDbTitle => 'Сбросить базу данных?';

  @override
  String get settingsResetDbBody =>
      'Будет безвозвратно удалено:\n• вся история прослушиваний\n• все счётчики\n• всё избранное\n• все плейлисты\n• все метаданные из кеша\n\nВаши аудиофайлы не удаляются.';

  @override
  String get settingsDbReset => 'База данных сброшена';

  @override
  String get settingsDeleteDownloads => 'Удалить загрузки';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Удаляет все файлы из папки online (треки, обложки)';

  @override
  String get settingsDeleteDownloadsTitle => 'Удалить загрузки?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Все загруженные файлы (треки, альбомы, обложки) будут безвозвратно удалены из папки online.\n\nЗаписи в базе данных останутся, но будут указывать на несуществующие файлы.';

  @override
  String get settingsDownloadsDeleted => 'Загрузки удалены';

  @override
  String get settingsColor => 'Цвет';

  @override
  String get settingsPmPresets => 'Presets';

  @override
  String get settingsPmRandomNext => 'Случайный следующий preset';

  @override
  String get settingsPmRandomNextSubtitle => 'Выкл.: presets идут по порядку';

  @override
  String get settingsPmLockPreset => 'Зафиксировать preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Без автоматической смены';

  @override
  String get settingsPmPresetDuration => 'Время между presets';

  @override
  String get settingsPmTransitions => 'Переходы';

  @override
  String get settingsPmBlend => 'Переход с плавным наложением';

  @override
  String get settingsPmBlendSubtitle => 'Выкл.: мгновенная смена preset';

  @override
  String get settingsPmTransitionStyle => 'Стиль перехода';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Узор, используемый плавным переходом';

  @override
  String get settingsPmTransitionRandom => 'Случайно';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'Смена preset в такт битам';

  @override
  String get settingsPmHardcutTime => 'Hardcut: минимальное время';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: чувствительность';

  @override
  String get settingsPmRendering => 'Рендеринг';

  @override
  String get settingsPmQuality => 'Качество';

  @override
  String get settingsPmQualitySubtitle =>
      'Разрешение рендеринга (Max = родное разрешение)';

  @override
  String get settingsPmBeatSensitivity => 'Чувствительность к битам';

  @override
  String get settingsPmAspectRatio => 'Соблюдать соотношение сторон';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'Для шейдеров, которые это поддерживают';

  @override
  String get settingsPmPermissive => 'Разрешающий режим';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Загружать файлы .milk с ошибками в скриптах';

  @override
  String get accountTitle => 'Аккаунт';

  @override
  String get accountSubtitle => 'Сохранение и синхронизация библиотеки';

  @override
  String get accountAnonymous => 'Анонимный аккаунт';

  @override
  String get accountAnonymousExplain =>
      'Избранное и история хранятся на сервере, но доступны только с этого устройства. Добавьте адрес электронной почты, чтобы найти их в другом месте.';

  @override
  String get accountEmailAttached =>
      'Адрес подтверждён — аккаунт можно восстановить';

  @override
  String get accountEmailPending => 'Адрес ещё не подтверждён';

  @override
  String get accountInsecureStorage =>
      'Защищённое хранилище устройства недоступно: идентификатор аккаунта сохранён в открытом виде.';

  @override
  String get accountSaveCta => 'Сохранить аккаунт';

  @override
  String get accountStatSongs => 'Избранные треки';

  @override
  String get accountStatAlbums => 'Избранные альбомы';

  @override
  String get accountStatPlays => 'Прослушивания';

  @override
  String get accountCreatedLabel => 'Создан';

  @override
  String get accountSignOut => 'Выйти';

  @override
  String get accountRevoke => 'Выйти на всех устройствах';

  @override
  String get accountRevokeSubtitle => 'Завершает сеансы на других устройствах';

  @override
  String get accountRevokeBody =>
      'На всех других устройствах сеанс завершится. Это устройство останется в системе.';

  @override
  String get accountRevokeDone => 'Сеансы на других устройствах завершены';

  @override
  String get accountDelete => 'Удалить аккаунт';

  @override
  String get accountDeleteSubtitle =>
      'Удаляет аккаунт и его данные на сервере. Необратимо.';

  @override
  String accountDeleteBody(int items, int lists) {
    return 'С сервера будет удалено: избранное — $items, плейлисты — $lists. Отменить нельзя.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Загрузки и библиотека на этом устройстве не затрагиваются.';

  @override
  String get accountDeleteDone => 'Аккаунт удалён';

  @override
  String get accountSignOutSubtitle =>
      'Устройство начнёт с нового пустого аккаунта';

  @override
  String get accountSignOutTitle => 'Выйти из аккаунта?';

  @override
  String accountSignOutBody(String email) {
    return 'Вернуться в этот аккаунт можно по коду, отправленному на $email.';
  }

  @override
  String get accountSignedOut => 'Выход выполнен';

  @override
  String get accountNoSignOut => 'Выход недоступен';

  @override
  String get accountNoSignOutSubtitle =>
      'Без адреса почты этот аккаунт будет потерян навсегда.';

  @override
  String get accountDetach => 'Отвязать адрес';

  @override
  String get accountDetachSubtitle =>
      'Аккаунт снова станет анонимным, данные не удаляются';

  @override
  String get accountDetachBody =>
      'Без адреса этот аккаунт больше не найти с другого устройства.';

  @override
  String get accountDetachDone => 'Адрес отвязан';

  @override
  String get accountOffline => 'Аккаунт недоступен без сети';

  @override
  String get accountEmailTitle => 'Адрес электронной почты';

  @override
  String get accountEmailExplain =>
      'Мы отправим код из 6 цифр для подтверждения адреса. Он нужен только для восстановления аккаунта.';

  @override
  String get accountEmailLabel => 'Адрес электронной почты';

  @override
  String get accountCodeTitle => 'Код подтверждения';

  @override
  String accountCodeExplain(String email) {
    return 'Код отправлен на $email. Он действует 10 минут.';
  }

  @override
  String get accountCodeLabel => 'Код из 6 цифр';

  @override
  String get accountSendCode => 'Отправить код';

  @override
  String get accountVerify => 'Подтвердить';

  @override
  String get accountResend => 'Отправить код ещё раз';

  @override
  String accountResendIn(int n) {
    return 'Повтор через $n с';
  }

  @override
  String get accountCheckSpam =>
      'Письмо может идти около минуты — проверьте папку «Спам».';

  @override
  String get accountErrorInvalidEmail => 'Неверный адрес';

  @override
  String get accountErrorTooMany =>
      'Слишком много запросов, попробуйте через несколько минут';

  @override
  String get accountErrorInvalidCode => 'Неверный или просроченный код';

  @override
  String get accountErrorCodeLength => 'В коде 6 цифр';

  @override
  String get accountErrorNetwork => 'Не удалось подключиться, попробуйте снова';

  @override
  String get accountMergeTitle => 'Объединить эту библиотеку?';

  @override
  String accountMergeBody(String email) {
    return 'Избранное и история этого устройства будут добавлены в аккаунт $email. Действие необратимо.';
  }

  @override
  String get accountMergeConfirm => 'Объединить';

  @override
  String get accountCarryLocal => 'Сохранить избранное этого устройства';

  @override
  String accountCarryLocalOn(int n) {
    return 'Избранное этого устройства ($n) и плейлисты будут добавлены в аккаунт.';
  }

  @override
  String get accountCarryLocalOff =>
      'Они будут удалены с этого устройства и заменены данными аккаунта. Загруженные файлы останутся.';

  @override
  String get accountDropLocalTitle => 'Удалить данные этого устройства?';

  @override
  String get accountCreatedOk => 'Аккаунт сохранён, библиотека в безопасности';

  @override
  String get accountMergedOk => 'Вход выполнен — локальное избранное добавлено';

  @override
  String get accountSignedInOk => 'Вход выполнен';

  @override
  String get playlistEntryMissing => 'Файл отсутствует на этом устройстве';

  @override
  String get playlistEntryMissingRestorable =>
      'Файл отсутствует — можно скачать заново';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n отсутствует',
      many: '$n отсутствуют',
      few: '$n отсутствуют',
      one: '$n отсутствует',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Сохранить в аккаунт';

  @override
  String get playlistBackupSubtitle =>
      'Плейлист сохранится даже после переустановки';

  @override
  String get playlistBackupUpdate => 'Обновить копию';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Заменяет копию в аккаунте этой версией';

  @override
  String get playlistBackupStop => 'Больше не сохранять';

  @override
  String get playlistBackupStopped => 'Копия удалена';

  @override
  String get playlistBackupDone => 'Плейлист сохранён';

  @override
  String get playlistBackupFailed => 'Не удалось сохранить';

  @override
  String get playlistBackupNoAccount => 'На этом устройстве нет аккаунта';

  @override
  String get playlistSyncTooltip => 'Синхронизировать с аккаунтом';

  @override
  String get playlistSyncRunning => 'Синхронизация…';

  @override
  String get playlistSyncDone => 'Плейлисты синхронизированы';

  @override
  String get playlistSyncPartial => 'Некоторые плейлисты не удалось сохранить';

  @override
  String get playlistFetchMissing => 'Скачать отсутствующие треки';

  @override
  String get playlistFetchDone => 'Отсутствующие треки скачаны';

  @override
  String get playlistFetchPartial => 'Некоторые треки не удалось скачать';

  @override
  String get playlistEntryFetchFailed => 'Не удалось скачать этот трек';

  @override
  String get accountStatPlaylists => 'Плейлисты';

  @override
  String get accountSyncNow => 'Синхронизировать сейчас';

  @override
  String get accountSyncAuto => 'Выполняется сама в фоне';

  @override
  String get accountSyncAnonymous =>
      'Сохранено на сервере. Добавьте e-mail, чтобы синхронизировать другое устройство.';

  @override
  String get accountSyncPending => 'Изменения ждут отправки';

  @override
  String accountSyncLast(String when) {
    return 'Последняя синхронизация: $when';
  }

  @override
  String get accountSyncDone => 'Синхронизация завершена';

  @override
  String get accountSyncFailed => 'Синхронизация не удалась, повторим позже';

  @override
  String get podiumFirst => '1-е';

  @override
  String get podiumSecond => '2-е';

  @override
  String get podiumThird => '3-е';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'музыка из $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'содержит $place место конкурса $compo';
  }

  @override
  String get competitionEmpty => 'В этом конкурсе нет работ';

  @override
  String get competitionEntryNoMusic => 'Для этой работы нет музыки в каталоге';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n трека',
      many: '$n треков',
      few: '$n трека',
      one: '$n трек',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStart => 'Начать';

  @override
  String get onboardingBetaTitle => 'Бета-версия';

  @override
  String get onboardingBetaBody =>
      'Rewamp ещё строится. Локальные данные — библиотека, плейлисты, избранное, статистика — могут быть обнулены до версии 1.0. Загруженным файлам ничего не грозит, но важное храните и в другом месте.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Версия $version (сборка $build)';
  }

  @override
  String get onboardingExploreTitle => 'Обзор';

  @override
  String get onboardingExploreBody =>
      'Ищите и просматривайте десятки тысяч чиптюнов и трекерных модулей из крупных онлайн-архивов — по исполнителю, альбому, платформе или пати. Коснитесь, чтобы послушать, скачайте, чтобы оставить.';

  @override
  String get onboardingLibraryTitle => 'Ваша библиотека';

  @override
  String get onboardingLibraryBody =>
      'Сохраняйте понравившееся, собирайте плейлисты и раскладывайте их по папкам. Загруженное играет офлайн, а библиотека следует за вами между устройствами после входа.';

  @override
  String get onboardingPlayerTitle => 'Плеер';

  @override
  String get onboardingPlayerBody =>
      'Смахивайте для смены трека и открывайте визуализации: осциллограф, каналы, бегущие ноты, трекерную сетку. Многотрековые файлы показывают свои подтреки, и каждый голос отключается отдельно.';

  @override
  String get onboardingReplayTitle => 'Знакомство';

  @override
  String get onboardingReplaySubtitle =>
      'Снова показать уведомление о бете и обзор функций';

  @override
  String get settingsPatternTitle => 'Паттерны';

  @override
  String get settingsPatternSubtitle =>
      'Трекерная сетка: цвета, столбцы, прокрутка';

  @override
  String get patternOpaqueBg => 'Непрозрачный фон';

  @override
  String get patternOpaqueBgSubtitle => 'Скрывает обложку за сеткой';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get accountDisplayName => 'Публичное имя';

  @override
  String get accountDisplayNameNotSet =>
      'Не задано — нужно, чтобы опубликовать плейлист';

  @override
  String get accountDisplayNameHint =>
      'Имя, под которым ты хочешь быть указан.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Смена имени вернёт все опубликованные плейлисты на проверку.';

  @override
  String get accountDisplayNameTaken => 'Это имя занято. Выбери другое.';

  @override
  String get accountDisplayNameLength => 'От 2 до 40 символов.';

  @override
  String get accountDisplayNameSaved => 'Публичное имя сохранено';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Плейлистов возвращено на проверку: $n';
  }

  @override
  String get playlistPublish => 'Опубликовать';

  @override
  String get playlistPublishSubtitle => 'Запросить публикацию (после проверки)';

  @override
  String get playlistPublishTitle => 'Опубликовать этот плейлист?';

  @override
  String get playlistPublishBody =>
      'После одобрения он станет виден всем и будет подписан твоим публичным именем. Обложка берётся из его треков.';

  @override
  String get playlistPublishCta => 'Запросить';

  @override
  String get playlistPublishSubmitted => 'Отправлен на проверку';

  @override
  String get playlistPublishPending => 'Ожидает одобрения';

  @override
  String get playlistPublishApproved => 'Публичный';

  @override
  String playlistPublishRejected(String reason) {
    return 'Отклонён: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Отклонён';

  @override
  String get playlistPublishNeedName =>
      'Выбери имя, под которым ты хочешь быть указан';

  @override
  String get playlistPublishNeedTracks =>
      'Для публикации нужно не меньше 5 треков';

  @override
  String get playlistPublishHasLocal =>
      'Файлы с твоего устройства опубликовать нельзя — другие не смогут их воспроизвести';

  @override
  String get playlistPublishTooManyPending =>
      'У тебя уже 3 плейлиста ожидают одобрения';

  @override
  String get playlistPublishRefused =>
      'Публикация отклонена: проверь треки и заявки в ожидании';

  @override
  String get playlistPublishFailed => 'Не удалось опубликовать';

  @override
  String get playlistPublishWithdrawn => 'Плейлист снова приватный';

  @override
  String get playlistUnpublish => 'Сделать приватным';

  @override
  String get playlistUnpublishSubtitle => 'Убирает его из публичных плейлистов';

  @override
  String get playlistRenamePublishedTitle =>
      'Переименовать опубликованный плейлист?';

  @override
  String get playlistRenamePublishedBody =>
      'Проверяется именно название: переименование вернёт плейлист на проверку и снимет его с публикации на это время. Добавление или перестановка треков — нет.';

  @override
  String playlistByAuthor(String author) {
    return 'автор: $author';
  }

  @override
  String get settingsSpectrumMode => 'Режим спектра';

  @override
  String get settingsSpectrumModeStandard => 'Обычный';

  @override
  String get settingsSpectrumModeColored => 'Цветной';

  @override
  String get settingsSpectrumModeBeam => 'Луч';

  @override
  String get settingsSpectrumModeLine => 'Линия';

  @override
  String get settingsSpectrumModeRing => 'Кольцо';

  @override
  String get releaseNotesTitle => 'Что нового';

  @override
  String get releaseNotesV4Downloads =>
      'Загрузки: длинную можно отменить на ходу, а архив альбома больше не скачивается по нескольку раз.';

  @override
  String get releaseNotesV4Queue =>
      'Очередь: кнопка её очистки с подтверждением — она также останавливает воспроизведение.';

  @override
  String get releaseNotesV4DropFiles =>
      'Файлы, брошенные в окно: воспроизвести сейчас, следующим или в конце; обложки и вспомогательные файлы отбрасываются, а список из архива учитывается (настоящие названия, без пустых треков).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: импорт собственного SoundFont с устройства, рядом с серверными.';

  @override
  String get releaseNotesV4Formats =>
      'Игровые потоки Wwise, FSB и OGL наконец звучат (собственный Vorbis).';

  @override
  String get releaseNotesV4Chips =>
      'Ещё шесть звуковых чипов, выбор ядра эмуляции для чипа (SameBoy для Game Boy) и верная высота тона у сэмплерных чипов.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: файлы .vt2 играют, а виды нот и паттернов охватывают всё семейство ZX.';

  @override
  String get releaseNotesV4Loop =>
      'Повтор трека действительно зацикливает вместо перезагрузки, и счётчик больше не замирает при бесконечном повторе.';

  @override
  String get releaseNotesV4Info =>
      'Панель ⓘ перечисляет файлы, которые трек действительно открыл, — вместе со спутниками и библиотеками.';

  @override
  String get releaseNotesV4Linux => 'Сборка для Linux.';

  @override
  String get releaseNotesDataReset =>
      'Локальные данные сброшены для этой беты. Медиатека и плейлисты восстановятся из аккаунта; загрузки придётся повторить.';

  @override
  String get releaseNotesDismiss => 'Продолжить';

  @override
  String get pmManagePresets => 'Управление пресетами';

  @override
  String get pmPickTooltip => 'Выбрать пресет';

  @override
  String get pmPickFilter => 'Фильтр пресетов';

  @override
  String get pmSourceTooltip => 'Источник пресетов';

  @override
  String get pmAddToPlaylistTooltip => 'Добавить пресет в плейлист';

  @override
  String pmSlowPresetDropped(String name) {
    return '«$name» слишком тяжёлый для этого устройства и был исключён.';
  }

  @override
  String get pmSlowDeviceTitle => 'Это устройство слишком медленное';

  @override
  String get pmSlowDeviceOff =>
      'Визуализатор отключён: это устройство не справляется с пресетами Milkdrop.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пресетов исключено',
      many: '$count пресетов исключено',
      few: '$count пресета исключены',
      one: '1 пресет исключён',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Слишком медленные на этом устройстве. Воспроизведение их пропускает.';

  @override
  String get settingsPmSlowPresetsRestore => 'Вернуть';

  @override
  String get pmSourceBundled => 'Встроенные пресеты';

  @override
  String get pmSourceImports => 'Мои импорты';

  @override
  String get pmSourceAll => 'Все пресеты';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пресета',
      many: '$count пресетов',
      few: '$count пресета',
      one: '$count пресет',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Новый плейлист…';

  @override
  String get pmPlaylistName => 'Название плейлиста';

  @override
  String get pmAddedToPlaylist => 'Добавлено в плейлист';

  @override
  String get pmAlreadyInPlaylist => 'Уже в этом плейлисте';

  @override
  String get pmTabPacks => 'Паки';

  @override
  String get pmTabBrowse => 'Обзор';

  @override
  String get pmTabPlaylists => 'Плейлисты';

  @override
  String get pmTabPopular => 'Популярные';

  @override
  String get pmTabSetAside => 'Исключённые';

  @override
  String get pmSetAsideEmpty =>
      'Ничего не исключено. Сюда попадают пресеты, на которых устройство падает ниже 6 к/с.';

  @override
  String get pmSetAsideRestoreAll => 'Вернуть все';

  @override
  String get pmInstall => 'Установить';

  @override
  String get pmInstallQueued => 'Установка в очереди';

  @override
  String get pmUninstall => 'Удалить';

  @override
  String get pmUninstalled => 'Пак удалён';

  @override
  String get pmUse => 'Использовать';

  @override
  String get pmDefaultPackBanner => 'Рекомендуемый стартовый пак';

  @override
  String pmLicense(String license) {
    return 'Лицензия: $license';
  }

  @override
  String get pmPacksOffline => 'Сервер недоступен';

  @override
  String get pmSearchPresets => 'Поиск пресетов…';

  @override
  String get pmPlayNow => 'Слушать сейчас';

  @override
  String get pmDownloadAction => 'Загрузить';

  @override
  String get pmDownloaded => 'Пресет загружен';

  @override
  String get pmDownloadFailed => 'Не удалось загрузить';

  @override
  String pmPreviewing(String name) {
    return 'Воспроизводится: $name';
  }

  @override
  String get pmLocalSection => 'Мои плейлисты';

  @override
  String get pmCuratedSection => 'Плейлисты Rewamp';

  @override
  String get pmImportPlaylist => 'Загрузить и использовать';

  @override
  String get pmPlaylistImported => 'Плейлист готов';

  @override
  String get pmImportFiles => 'Импортировать файлы…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Импортировано $count пресета',
      many: 'Импортировано $count пресетов',
      few: 'Импортировано $count пресета',
      one: 'Импортирован $count пресет',
      zero: 'Пресеты не импортированы',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Пресеты добавлены в библиотеку projectM';

  @override
  String get pmNoPlaylists => 'Плейлистов пресетов пока нет';

  @override
  String get pmSourceApplied => 'Источник пресетов применён';

  @override
  String get pmPlaylistEmpty => 'Этот плейлист пуст';

  @override
  String get pmDays7 => '7 дней';

  @override
  String get pmDays30 => '30 дней';

  @override
  String get pmDays365 => '1 год';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count воспроизведения',
      many: '$count воспроизведений',
      few: '$count воспроизведения',
      one: '$count воспроизведение',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Не удалось установить';

  @override
  String get pmSingleDownloads => 'Отдельные загрузки';

  @override
  String pmAvailableIn(String pack) {
    return 'Доступен в $pack';
  }

  @override
  String get pmCleanUp => 'Очистить';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count пресета',
      many: 'Удалено $count пресетов',
      few: 'Удалено $count пресета',
      one: 'Удалён $count пресет',
      zero: 'Нечего очищать',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Закрепить этот пресет';

  @override
  String get pmUnlockAction => 'Открепить пресет';

  @override
  String get pmOrderRandom => 'Пресеты вперемешку';

  @override
  String get pmOrderSequential => 'Пресеты по порядку';

  @override
  String get pmUpdateAvailable => 'Доступно обновление';

  @override
  String get pmUpdate => 'Обновить';

  @override
  String get pmSelectAll => 'Выбрать все';

  @override
  String get pmSelectNone => 'Снять выделение';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count',
      many: 'Выбрано $count',
      few: 'Выбрано $count',
      one: 'Выбран $count',
      zero: 'Ничего не выбрано',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Неиспользуемые текстуры';

  @override
  String pmTexturesFreed(String size) {
    return 'Освобождено $size';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count текстуры',
      many: '$count текстур',
      few: '$count текстуры',
      one: '$count текстура',
    );
    return '$_temp0';
  }
}
