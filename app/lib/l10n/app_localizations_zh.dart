// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navHome => '主页';

  @override
  String get navSearch => '搜索';

  @override
  String get navLocal => '本地';

  @override
  String get settingsTabsOrderTitle => '标签顺序';

  @override
  String get settingsTabsOrderSubtitle => '拖动排序。前四个显示在底部栏，其余放在“更多”中。';

  @override
  String get settingsTabsInBar => '在栏中';

  @override
  String get settingsTabsInMore => '在“更多”中';

  @override
  String get settingsLaunchTab => '启动标签';

  @override
  String get settingsLaunchTabSubtitle => '应用启动时打开的标签';

  @override
  String get navLibrary => '资料库';

  @override
  String get noFileSelected => '未选择文件';

  @override
  String get openFile => '打开文件';

  @override
  String get pickerLabelAudio => '音频';

  @override
  String get formatNotSupported => '不支持的格式';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return '不支持的格式：$file（.$ext）';
  }

  @override
  String playbackFileMissing(String file) {
    return '此设备上没有：$file';
  }

  @override
  String playbackFileGone(String file) {
    return '服务器上已无此文件：$file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file 不在专辑的压缩包里——该 rip 列出了它，却没有收录。';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host 没有响应。请检查网络连接后重试。';
  }

  @override
  String get failedToLoadFile => '无法加载文件';

  @override
  String get libraryEmptyHint => '你的艺人、专辑和播放列表\n将显示在这里。';

  @override
  String get libraryPlaylists => '播放列表';

  @override
  String get libraryArtists => '艺人';

  @override
  String get libraryAlbums => '专辑';

  @override
  String get libraryTracks => '歌曲';

  @override
  String get libraryFavorites => '收藏';

  @override
  String get libraryFavoritesSubtitle => '你收藏歌曲的自动播放列表';

  @override
  String get libraryRecentlyAdded => '最近添加';

  @override
  String get libraryEmpty => '这里还没有内容';

  @override
  String get libraryRemoved => '已从资料库中移除';

  @override
  String get searchHint => '搜索…';

  @override
  String get searchTypePlaceholder => '输入标题、艺人或专辑…';

  @override
  String get searchNoResults => '无结果';

  @override
  String get searchDownloading => '下载中…';

  @override
  String searchError(String message) {
    return '错误：$message';
  }

  @override
  String get tabAll => '歌曲';

  @override
  String get tabArtists => '艺人';

  @override
  String get tabAlbums => '专辑';

  @override
  String get tabProductions => '作品';

  @override
  String get filterWithVideo => '有视频';

  @override
  String get videoUnavailable => '此视频无法播放';

  @override
  String get noItems => '无项目';

  @override
  String get sortRelevance => '相关度';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get noRecentTracks => '暂无最近播放的歌曲';

  @override
  String get playerSourceLocal => '本地';

  @override
  String get homePlayFiles => '播放文件';

  @override
  String get homePlayFolder => '播放文件夹';

  @override
  String get homeSectionsOrderTitle => '板块顺序';

  @override
  String get homeSectionsOrderSubtitle => '拖动以按你的喜好排列首页。';

  @override
  String get homeSectionsOrderReset => '默认顺序';

  @override
  String get homeSectionsOrderSettings => '首页板块顺序';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total 条结果';
  }

  @override
  String countLoadingMore(int loaded) {
    return '已加载 $loaded…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded 条结果';
  }

  @override
  String countScrollMore(int loaded) {
    return '已加载 $loaded — 滚动查看更多';
  }

  @override
  String countNLoaded(int n) {
    return '已加载 $n';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n 个文件';
  }

  @override
  String get browseFilterByTitle => '按标题筛选…';

  @override
  String get browseNoSongs => '暂无歌曲';

  @override
  String get browseByFormat => '按格式';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => '按格式筛选…';

  @override
  String get browseByPlatform => '按平台';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => '平台名称…';

  @override
  String get browseByChip => '按声音芯片';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => '例如 YM2612、SPC700…';

  @override
  String get browseOk => '确定';

  @override
  String get browseByArtist => '按艺人';

  @override
  String get browseByArtistSubtitle => '浏览作曲者';

  @override
  String get browseFilterByName => '按名称筛选…';

  @override
  String get browseNoArtistFound => '未找到艺人';

  @override
  String get browseNoArtistsAvailable => '暂无艺人';

  @override
  String get browseNoArtist => '无艺人';

  @override
  String get browseNoAlbum => '无专辑';

  @override
  String get browseTopPacks => '热门合辑包';

  @override
  String get browseTopPacksSubtitle => '评分最高的合辑包';

  @override
  String browseTopPacksLabel(String collection) {
    return '热门合辑包 — $collection';
  }

  @override
  String get browseLatestPacks => '最新合辑包';

  @override
  String get browseLatestPacksSubtitle => '最近新增的内容';

  @override
  String browseLatestPacksLabel(String collection) {
    return '最新合辑包 — $collection';
  }

  @override
  String get browseAllSongs => '全部歌曲';

  @override
  String get browseAllSongsSubtitleAlpha => '按字母顺序浏览';

  @override
  String get browseAlphabetical => '按字母顺序';

  @override
  String browseAllLabel(String collection) {
    return '全部 — $collection';
  }

  @override
  String get browseCollections => '合集';

  @override
  String browseFilesCount(String count) {
    return '$count 个文件';
  }

  @override
  String get browseIndexing => '正在建立索引';

  @override
  String browseFilterFacet(String name) {
    return '筛选 $name…';
  }

  @override
  String get browseAllYears => '所有年份';

  @override
  String get browseAllYearsSubtitle => '该 party 的全部歌曲';

  @override
  String get browseNoCompo => '该 party 暂无已收录的 compo。';

  @override
  String get browseOthers => '其他';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 个参赛作品 — 排名',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => '播放此列表';

  @override
  String get browsePlayAllRanked => '全部播放（按排名顺序）';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首 — 排名顺序',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => '按专辑浏览';

  @override
  String get browsePlayAll => '全部播放';

  @override
  String get browseShuffle => '随机播放';

  @override
  String get browseSearchInFolder => '在此文件夹中搜索…';

  @override
  String get browseFilterThisList => '筛选此列表…';

  @override
  String get browseSearchSubfolders => '搜索子文件夹';

  @override
  String get browseEmptyFolder => '空文件夹';

  @override
  String browsePlaybackError(String message) {
    return '播放失败：$message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => '显示';

  @override
  String get browseViewList => '列表';

  @override
  String get browseViewGrid => '网格';

  @override
  String get browseViewGridCompact => '紧凑网格';

  @override
  String get browseSearchAlbum => '搜索专辑…';

  @override
  String get browseSearchArtist => '搜索艺人…';

  @override
  String get browsePlayAlbum => '播放专辑';

  @override
  String get searchDownloadingAlbum => '正在下载专辑…';

  @override
  String get searchCategoryChip => '芯片';

  @override
  String get searchCategoryGroup => '团队';

  @override
  String get artistRealName => '真实姓名';

  @override
  String get artistAliases => '别名';

  @override
  String get artistBorn => '出生';

  @override
  String get artistInterview => '采访';

  @override
  String get audioOutput => '音频输出';

  @override
  String get audioOutputSystemDefault => '系统默认';

  @override
  String get vizRangeAuto => '自动';

  @override
  String get contextNotes => '备注';

  @override
  String get notePlacedBadge => '在比赛中获得名次';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 名成员',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => '查看歌曲';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个模块',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Party';

  @override
  String get searchCategoryYear => '年份';

  @override
  String get searchCategoryOrigin => '来源';

  @override
  String get searchCategoryProduction => '作品';

  @override
  String get searchCategoryProductionType => '作品类型';

  @override
  String get searchCategoryPublisher => '发行商';

  @override
  String get searchCategoryDeveloper => '开发商';

  @override
  String get searchCategoryArcadeBoard => '街机基板';

  @override
  String get searchCategorySaga => '系列';

  @override
  String get searchCategoryGenre => '风格';

  @override
  String get searchViaArtist => '来自艺人';

  @override
  String get searchViaAlbum => '来自专辑';

  @override
  String get searchViaSong => '来自歌曲';

  @override
  String get searchSortPopular => '热门';

  @override
  String get searchSortYear => '年份';

  @override
  String get searchSortRandom => '随机';

  @override
  String get searchSortRating => '评分';

  @override
  String statsTopPercent(int percent) {
    return '前 $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => '升序';

  @override
  String get searchSortDesc => '降序';

  @override
  String get searchFilters => '筛选';

  @override
  String get searchExactSearch => '精确搜索';

  @override
  String get searchExactSearchSubtitle => '关闭模糊（fuzzy）搜索';

  @override
  String get searchTags => '标签';

  @override
  String searchTagSearchHint(String category) {
    return '在「$category」中搜索标签…';
  }

  @override
  String get searchTagTypeToSearch => '输入以搜索标签。';

  @override
  String get searchTagsAndLogic => '多个标签 = 逻辑与（AND）。';

  @override
  String get searchFilterYear => '年份';

  @override
  String get searchFilterAll => '全部';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote => '按年份筛选会排除没有日期的歌曲。';

  @override
  String get searchMinRating => '评分 ≥';

  @override
  String get searchPodium => '获奖';

  @override
  String get searchPodiumAny => '所有获奖';

  @override
  String get searchPodiumUnavailable => '服务器尚不支持获奖筛选';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => '取消';

  @override
  String get searchReset => '重置';

  @override
  String get searchApply => '应用';

  @override
  String get searchClearRecent => '清除最近搜索';

  @override
  String get searchBrowse => '浏览';

  @override
  String get searchBrowseHint => '选择一个维度（团队、芯片、年份…）来探索曲库，或使用上方的电台 / 惊喜。';

  @override
  String get searchDidYouMean => '结果很少 — 试试模糊搜索？';

  @override
  String get searchYes => '是';

  @override
  String get featuredCommunityTitle => '社区新作';

  @override
  String get searchPlaylistSourceAll => '全部';

  @override
  String get searchPlaylistSourceUser => '社区';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => '格式';

  @override
  String get searchPlatform => '平台';

  @override
  String get filterCollection => '合集';

  @override
  String get videoWatchDemo => '观看演示';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return '合集：$name';
  }

  @override
  String get searchCollectionAll => '全部';

  @override
  String get searchRadio => '电台';

  @override
  String get searchRadioTooltip => '基于当前筛选的随机队列';

  @override
  String get searchSurprise => '惊喜';

  @override
  String get searchSurpriseTooltip => '随机一首歌曲';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => '无歌曲';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 张专辑',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return '又名 $name';
  }

  @override
  String get searchChooseCollection => '选择合集';

  @override
  String get searchFilterCollections => '筛选合集…';

  @override
  String get searchFilterPlaceholder => '筛选…';

  @override
  String searchAllOf(String label) {
    return '全部（$label）';
  }

  @override
  String get searchNoMatch => '无匹配项';

  @override
  String get searchNoPlaylist => '无播放列表';

  @override
  String get engineDescOpenmpt => 'Tracker 模块（MOD/XM/S3M/IT/…）';

  @override
  String get engineDescXmp => 'libopenmpt 无法读取的模块（.musx、.liq、.fnk…）';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — 声音芯片，分声道示波器';

  @override
  String get engineDescGme => 'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN 压缩包';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — 分声道声部';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID（reSIDfp 引擎）';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC（SN76489/YM2413）';

  @override
  String get engineDescKss => 'MSX 芯片音乐（KSS/MGS/BGM/MPK/MBM/OPX）';

  @override
  String get engineDescFurnace => '多芯片芯片音乐 .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade => '通过 68k 模拟播放 Amiga 自定义芯片格式（约 320 种扩展名）';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi => '标准 MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ 合成器（16 声部）';

  @override
  String get engineDescV2m => 'V2M 合成器 (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — 真实 68000 模拟 + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf => 'Nintendo 64 .usf — R4300 模拟 + RSP 音频';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ 模拟';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound 芯片';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — 真实 AY-3-8910/YM2149 合成器';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixel 的原生引擎';

  @override
  String get engineDescPxtone => 'Pixel 的 tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — 通过 emu68 的真实 68000';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA FM + SSG + PPZ8 采样';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx（+ .pdx 采样），YM2151 FM';

  @override
  String get engineDescFmp => 'PC-98 FMP 驱动 — OPNA + PPZ8（.opi/.ovi/.ozi）';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612 FM + PCM（.eup）';

  @override
  String get engineDescMac => '无损 .ape';

  @override
  String get engineDescVgmstream => '游戏流式音频格式（700+，含 .rrds）';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — 备用解码器';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total 张专辑',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total 位艺人',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 张专辑',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 位艺人',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 个团队',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => '国家/地区';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 个国家/地区',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => '文件夹';

  @override
  String get featuredTitle => '今日精选';

  @override
  String featuredPartyNow(String party) {
    return '$party 正在举行 — 往届的获奖作品';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party 将在 $days 天后开始 — 往届的获奖作品',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series 季来了 — 往届的获奖作品';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return '发行于 $year 年 $month';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age 年前：$year 年的游戏',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade年代';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age 年前：$year 年的游戏',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return '$month发行';
  }

  @override
  String get featuredAnniversaryHeader => '周年纪念';

  @override
  String get featuredBirthdayHeader => '今日生日';

  @override
  String get featuredBirthdayWeekHeader => '本周生日';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '本周是$artist的生日';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个播放列表',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => '重试';

  @override
  String get commonOptions => '选项';

  @override
  String get commonDownload => '下载';

  @override
  String get commonDeleteDownload => '删除下载';

  @override
  String get commonAddToPlaylist => '添加到播放列表';

  @override
  String get commonPlayNext => '下一首播放';

  @override
  String get commonAddToQueueEnd => '添加到队列末尾';

  @override
  String get commonAddToFavorites => '添加到收藏';

  @override
  String get commonRemoveFromFavorites => '从收藏中移除';

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
  String get subsongDeleteDownloadTitle => '删除此下载？';

  @override
  String subsongDeleteDownloadBody(String path) {
    return '文件及其本地记录（历史、曲目）将被删除。\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => '无法读取曲目';

  @override
  String subsongTrackNumber(int number) {
    return '曲目 $number';
  }

  @override
  String get subsongDefaultTrack => '默认曲目';

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个子曲目',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => '全部播放';

  @override
  String get albumDownloading => '正在下载专辑…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return '正在下载专辑…（$done/$total）';
  }

  @override
  String get albumDownloadToSeeTracks => '下载专辑以查看曲目';

  @override
  String get albumNotDownloadedHint => '专辑未下载 — 开始播放即可下载';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => '正在加载详情…';

  @override
  String albumAka(String label) {
    return '又名 $label';
  }

  @override
  String get albumPlayAlbum => '播放专辑';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst => '请先从搜索中播放这首歌曲以完成下载';

  @override
  String get libraryAddedTrack => '歌曲已添加到资料库';

  @override
  String get libraryAddedAlbum => '专辑已添加到资料库';

  @override
  String get libraryAddedArtist => '艺人已添加到资料库';

  @override
  String get libraryRemovedTrack => '歌曲已从资料库移除';

  @override
  String get libraryRemovedAlbum => '专辑已从资料库移除';

  @override
  String get libraryRemovedArtist => '艺人已从资料库移除';

  @override
  String get libraryImportBeforeAddTitle => '先导入？';

  @override
  String get libraryImportBeforeAddBody =>
      '此文件正从系统可能清空的临时位置播放。要将其导入本地音乐库，让该条目得以保留吗？';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      '此曲目来自解压到临时缓存的压缩包。整个压缩包连同配套文件将一起导入本地音乐库。';

  @override
  String get libraryAddNeedsCatalogueId => '无法添加此曲目：本设备上未知其目录标识。';

  @override
  String songTilePlayFailed(String message) {
    return '播放失败：$message';
  }

  @override
  String downloadFailed(String label) {
    return '下载失败 — $label';
  }

  @override
  String downloadInProgress(String label) {
    return '正在下载 — $label';
  }

  @override
  String get downloadsTitle => '下载';

  @override
  String get downloadsEmpty => '没有等待中的下载';

  @override
  String get downloadsPause => '暂停';

  @override
  String get downloadsResume => '继续';

  @override
  String get downloadsCancel => '取消下载';

  @override
  String get downloadsClear => '全部移除';

  @override
  String get downloadsPausedBanner => '下载已暂停 — 当前文件将先完成';

  @override
  String downloadInProgressPct(String label, int percent) {
    return '正在下载 — $label $percent %';
  }

  @override
  String get miniPlayerQueue => '播放列表';

  @override
  String get miniPlayerHideQueue => '隐藏播放列表';

  @override
  String get transportShuffle => '随机播放';

  @override
  String get transportShuffleOn => '随机播放已开启';

  @override
  String get transportLoopOff => '循环关闭';

  @override
  String get transportLoopQueue => '循环：播放队列';

  @override
  String get transportLoopTrack => '循环：当前歌曲';

  @override
  String get vizStereo => '立体声';

  @override
  String get vizSpectrum => '频谱';

  @override
  String get vizVoices => '声部';

  @override
  String get vizNotes => '音符';

  @override
  String get vizPiano => '钢琴';

  @override
  String get vizPatterns => 'Pattern';

  @override
  String get patternScrollMode => '滚动模式';

  @override
  String get patternSmoothScroll => '平滑滚动';

  @override
  String get patternPinnedRow => '固定当前播放行';

  @override
  String get patternVolumeBars => '音量条';

  @override
  String get patternColorScheme => '配色方案';

  @override
  String get patternSize => '大小';

  @override
  String get patternColumns => '列';

  @override
  String get patternColumnsAll => '完整';

  @override
  String get patternColumnsNoteInstr => '精简';

  @override
  String get patternColumnsNote => '最小';

  @override
  String get vizClose => '关闭可视化';

  @override
  String get vizFullscreen => '全屏';

  @override
  String get vizExitFullscreen => '退出全屏';

  @override
  String get vizPrevPreset => '上一个预设';

  @override
  String get vizNextPreset => '下一个预设';

  @override
  String get vizProjectmUnavailable => 'projectM 不可用';

  @override
  String get voicesTitle => '声部';

  @override
  String get voicesNone => '这首歌曲没有声部。';

  @override
  String get voicesLongPressSolo => '长按 = 独奏';

  @override
  String get voicesMuteAll => '全部静音';

  @override
  String get voicesUnmuteAll => '全部取消静音';

  @override
  String get voicesStereoOutput => '立体声输出';

  @override
  String get voicesLeft => '左';

  @override
  String get voicesRight => '右';

  @override
  String get enginesFormatsTitle => '可播放格式';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats 种可播放格式，分布在 $engines 个播放引擎中。';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 种格式',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return '翻自 $artist 的《$title》';
  }

  @override
  String stilCover(String work) {
    return '翻自《$work》';
  }

  @override
  String get playerQueue => '播放队列';

  @override
  String get queueEdit => '编辑';

  @override
  String get queueEditDone => '完成';

  @override
  String get queueClear => '清空队列';

  @override
  String get queueClearConfirmTitle => '清空队列？';

  @override
  String get queueClearConfirmBody => '队列将被清空，播放将停止。';

  @override
  String get queueClearConfirm => '清空';

  @override
  String get queueRemoveSelected => '删除所选';

  @override
  String get queueRemoveTrack => '从队列中移除';

  @override
  String get queueReorder => '重新排序';

  @override
  String get playerArtwork => '封面';

  @override
  String get playerVisualizer => '可视化';

  @override
  String get playerVoices => '声部';

  @override
  String get playerTrackInfo => '歌曲信息';

  @override
  String get playerShowQueue => '播放列表';

  @override
  String get playerHideQueue => '隐藏播放列表';

  @override
  String get playerNoTrackInfo => '暂无可用信息。';

  @override
  String get playerViewSubsongs => '查看子曲目';

  @override
  String get playerViewAlbum => '查看专辑';

  @override
  String get playerViewArtist => '查看艺人';

  @override
  String get playerAddToPlaylist => '添加到播放列表';

  @override
  String get playerEngineSettings => '引擎设置';

  @override
  String get queueAddToPlaylist => '将队列添加到播放列表';

  @override
  String get playerMoreOptions => '更多选项';

  @override
  String get playerClose => '关闭';

  @override
  String get playerCancel => '取消';

  @override
  String get playerDelete => '删除';

  @override
  String get playerAddFavorite => '添加到收藏';

  @override
  String get playerRemoveFavorite => '从收藏中移除';

  @override
  String get playerAddToLibrary => '添加到资料库';

  @override
  String get playerRemoveFromLibrary => '从资料库移除';

  @override
  String get playerAddedToLibrary => '歌曲已添加到资料库';

  @override
  String get playerRemovedFromLibrary => '歌曲已从资料库移除';

  @override
  String get playerDeleteDownload => '删除下载';

  @override
  String get playerRedownload => '重新下载文件';

  @override
  String get playerRedownloadUnavailable => '此文件无法重新下载';

  @override
  String get playerDeleteDownloadTitle => '删除下载？';

  @override
  String playerDeleteDownloadBody(String path) {
    return '文件及其本地记录（历史、曲目）将被删除。\n\n$path';
  }

  @override
  String get homeYourTrends => '你的趋势';

  @override
  String get homeYourAllTimeTop => '你的历史最爱';

  @override
  String get homeTrending => '热门趋势';

  @override
  String get homeFeaturedPlaylists => '精选播放列表';

  @override
  String get homeAllTimeTop => '历史热门';

  @override
  String get homePeriod7d => '7 天';

  @override
  String get homePeriod30d => '30 天';

  @override
  String get homePeriod90d => '90 天';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 次播放',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => '播放列表为空或无法读取';

  @override
  String get homeExtractingArchive => '正在解压归档…';

  @override
  String get homeArchiveEmpty => '归档中没有可播放的文件';

  @override
  String get homeNothingPlayable => '所选内容中没有可播放的文件';

  @override
  String get homeAlbumLoadFailed => '无法加载这张专辑';

  @override
  String get homeSongLoadFailed => '无法加载这首歌曲';

  @override
  String get navStats => '统计';

  @override
  String get navSettings => '设置';

  @override
  String get playlistMoveUp => '移动到上级文件夹';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 个播放列表',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 个子文件夹',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader => '该文件夹及其全部内容将被永久删除：';

  @override
  String get playlistDeleteFolderEmptyBody => '该文件夹将被删除。';

  @override
  String get playlistFolderRoot => '根目录';

  @override
  String get playlistMoveToFolder => '移动到文件夹';

  @override
  String playlistDeleteTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get playlistDeleteBody => '该播放列表将被永久删除。';

  @override
  String get playlistRenameFolderTitle => '重命名文件夹';

  @override
  String get playlistClearFavorites => '删除所有收藏';

  @override
  String get playlistClearFavoritesTitle => '删除所有收藏？';

  @override
  String get playlistClearFavoritesBody => '你将失去所有收藏的曲目。此操作无法撤销。';

  @override
  String get playlistRemoveFromLibrary => '从库中移除';

  @override
  String get playlistServerReadOnly => '服务器播放列表 · 只读';

  @override
  String get navAbout => '关于';

  @override
  String get navMore => '更多';

  @override
  String get shellAlbumQueuedAtEnd => '专辑已添加到队列末尾';

  @override
  String get shellAlbumQueuedNext => '专辑将下一首播放';

  @override
  String get shellAddingToQueue => '正在添加到队列…';

  @override
  String get shellAddingNext => '正在设为下一首播放…';

  @override
  String shellDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 首曲目加入队列',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '已将“$title”添加到队列末尾';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '“$title”将下一首播放';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return '下载失败：$title — 跳到下一首';
  }

  @override
  String get shellNetworkUnavailable => '播放已停止：网络似乎不可用。';

  @override
  String get statsTitle => '统计';

  @override
  String statsPeriodDays(int n) {
    return '$n 天';
  }

  @override
  String get statsPeriodThisYear => '今年';

  @override
  String get statsPeriodAll => '全部时间';

  @override
  String get statsByMonthOrYear => '按月 / 年…';

  @override
  String get statsByYear => '按年';

  @override
  String get statsByMonth => '按月';

  @override
  String get statsPlaysLabel => '播放';

  @override
  String get statsTracksLabel => '歌曲';

  @override
  String get statsArtistsLabel => '艺人';

  @override
  String get statsAlbumsLabel => '专辑';

  @override
  String get statsListenTime => '收听时长';

  @override
  String get statsByCollection => '按合集';

  @override
  String get statsByFormat => '按格式';

  @override
  String get statsByEngine => '按引擎';

  @override
  String get statsPlaylistsLabel => '播放列表';

  @override
  String get statsLocalFilesSection => '已下载文件';

  @override
  String get statsFilesLabel => '文件';

  @override
  String get statsSpaceLabel => '磁盘空间';

  @override
  String get statsNoPlaysInPeriod => '此期间没有播放记录';

  @override
  String get statsNoPlays => '没有播放记录';

  @override
  String get statsTopTracks => '热门歌曲';

  @override
  String get statsTopAlbums => '热门专辑';

  @override
  String get statsTopArtists => '热门艺人';

  @override
  String statsTopTracksIn(String period) {
    return '热门歌曲 — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return '热门专辑 — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return '热门艺人 — $period';
  }

  @override
  String get statsSeeAll => '查看全部';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 次播放',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return '最大 $n';
  }

  @override
  String get commonCancel => '取消';

  @override
  String get commonCreate => '创建';

  @override
  String get commonOk => '确定';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRename => '重命名';

  @override
  String get commonSort => '排序';

  @override
  String get commonPlayAll => '全部播放';

  @override
  String get sortName => '名称';

  @override
  String get sortTitle => '标题';

  @override
  String get sortArtist => '艺术家';

  @override
  String get sortAlbum => '专辑';

  @override
  String get sortDateAdded => '添加日期';

  @override
  String get commonClear => '清除';

  @override
  String get sortRecentlyModified => '最近修改';

  @override
  String get sortCreationDate => '创建日期';

  @override
  String get playlistNameHint => '名称';

  @override
  String get playlistNew => '新建播放列表';

  @override
  String get playlistNewFolder => '新建文件夹';

  @override
  String get playlistNewTooltip => '新建播放列表 / 文件夹';

  @override
  String get playlistAddTo => '添加到播放列表';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '添加到 $n 个播放列表',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => '选择一个播放列表';

  @override
  String get playlistFilterHint => '筛选播放列表…';

  @override
  String get playlistSearchHint => '搜索播放列表…';

  @override
  String get playlistNoMatch => '没有匹配的播放列表';

  @override
  String get playlistNoneCreateHint => '暂无播放列表 — 点击 + 新建';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => '已存在';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '所选播放列表中已有 $n 个项目。',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => '跳过重复项';

  @override
  String get playlistAddAgain => '再次添加';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m 个播放列表',
    );
    return '已将 $_temp0 添加到 $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return '无法添加：$error';
  }

  @override
  String get playlistRenameTitle => '重命名播放列表';

  @override
  String playlistDeleteFolderTitle(String name) {
    return '删除文件夹“$name”？';
  }

  @override
  String get playlistDeleteFolderBody => '其内容将上移一层。';

  @override
  String get playlistEmpty => '播放列表为空';

  @override
  String get trackOptionsAddToLibrary => '添加到资料库';

  @override
  String get trackOptionsRemoveFromLibrary => '从资料库移除';

  @override
  String get trackOptionsAddedToLibrary => '歌曲已添加到资料库';

  @override
  String get trackOptionsRemovedFromLibrary => '歌曲已从资料库移除';

  @override
  String get trackOptionsViewAlbum => '查看专辑';

  @override
  String get trackOptionsViewArtist => '查看艺人';

  @override
  String get trackOptionsPlayNow => '立即播放';

  @override
  String get trackOptionsPlayNext => '下一首播放';

  @override
  String get trackOptionsAddToQueueEnd => '添加到队列末尾';

  @override
  String get trackOptionsPlayLast => '最后播放';

  @override
  String get trackOptionsDeleteDownload => '删除下载';

  @override
  String get trackOptionsDeleteDownloadTitle => '删除此下载？';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return '文件及其本地记录（历史、曲目）将被删除。\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => '下载已删除';

  @override
  String get trackOptionsAddToFavorites => '添加到收藏';

  @override
  String get trackOptionsRemoveFromFavorites => '从收藏中移除';

  @override
  String get trackOptionsAlbumAddedToFavorites => '专辑已添加到收藏';

  @override
  String get trackOptionsAlbumRemovedFromFavorites => '专辑已从收藏中移除';

  @override
  String get trackOptionsAlbumNotDownloaded => '专辑未下载 — 无内容可删除';

  @override
  String get trackOptionsDeleteAlbumTitle => '删除已下载的专辑？';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return '该文件夹及其所有本地记录（曲目、历史）将被删除。\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => '专辑已从本地存储删除';

  @override
  String get trackOptionsRedownloadAlbum => '重新下载专辑';

  @override
  String get trackOptionsRedownloadAlbumSubtitle => '覆盖文件和本地记录';

  @override
  String get trackOptionsDeleteAlbumFiles => '删除专辑文件';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle => '已下载的文件夹 + 本地记录（历史）';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsGeneralSubtitle => '主题';

  @override
  String get settingsVisualisation => '可视化';

  @override
  String get settingsVisualisationSubtitle => '示波器、封面背景';

  @override
  String get settingsPlayback => '播放';

  @override
  String get settingsPlaybackSubtitle => '循环、淡出、静音检测';

  @override
  String get settingsEngines => '引擎';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => '数据';

  @override
  String get settingsDataSubtitle => '标识、历史、重置';

  @override
  String get settingsBackupExport => '导出备份';

  @override
  String get settingsBackupExportSubtitle => '将音乐库、播放列表和设置保存到文件';

  @override
  String get settingsBackupImport => '导入备份';

  @override
  String get settingsBackupImportSubtitle => '从备份文件恢复数据';

  @override
  String get settingsBackupExportFailed => '备份导出失败';

  @override
  String get settingsBackupImportConfirmTitle => '导入备份？';

  @override
  String get settingsBackupImportConfirmBody =>
      '这将替换此设备上的音乐库、播放列表和设置。已下载的文件会保留。';

  @override
  String get settingsBackupImportConfirm => '导入';

  @override
  String get settingsBackupImportedTitle => '备份已导入';

  @override
  String get settingsBackupImportedBody => '数据已恢复。请重启应用以应用全部更改。';

  @override
  String get settingsBackupTooNew => '此备份由更新版本的应用创建';

  @override
  String get settingsBackupInvalid => '不是有效的 Rewamp 备份';

  @override
  String get settingsBackupImportFailed => '备份导入失败';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAboutSubtitle => '致谢与许可';

  @override
  String get settingsCreditsSubtitle => '库、数据与组件';

  @override
  String get settingsSupport => '联系与支持';

  @override
  String get settingsSupportSubtitle => '联系我们、网站';

  @override
  String get settingsSupportEmail => '发送邮件';

  @override
  String get settingsSupportEmailSubtitle => '问题、缺陷或建议';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — 支持';

  @override
  String get settingsSupportEmailIntro => '请在上方描述您的问题、缺陷或建议。下面的信息有助于我们为您提供帮助。';

  @override
  String get settingsSupportWebsite => '网站';

  @override
  String get settingsDonation => '支持 Rewamp';

  @override
  String get settingsDonationSubtitle => '随意打赏';

  @override
  String get settingsDonationBlurb =>
      'Rewamp 免费且无广告——这是一份致力于保存 demoscene 与复古文化的热情之作。捐赠有助于资助应用开发并支付数据库的托管费用。没有任何义务：如果这款应用带给您快乐，一点心意我们都倍加珍惜。';

  @override
  String get settingsDonationFloppy => '一张软盘';

  @override
  String get settingsDonationCartridge => '一张卡带';

  @override
  String get settingsDonationBox => '一盒盒装游戏';

  @override
  String get settingsDonationCustom => '选择金额';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsOk => '确定';

  @override
  String get settingsDelete => '删除';

  @override
  String get settingsReset => '重置';

  @override
  String get settingsRenew => '更换';

  @override
  String get settingsOff => '关';

  @override
  String get settingsOn => '开';

  @override
  String get settingsAuto => '自动';

  @override
  String get settingsInfinite => '无限';

  @override
  String get settingsDefault => '默认';

  @override
  String get settingsCoreNoScope => '无示波器';

  @override
  String get settingsNone => '无';

  @override
  String get settingsLevelLow => '低';

  @override
  String get settingsLevelHigh => '高';

  @override
  String get settingsStereo => '立体声';

  @override
  String get settingsSurround => '环绕声';

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
  String get settingsTheme => '主题';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsArtworkTintTitle => '用封面为播放器着色';

  @override
  String get settingsArtworkTintSubtitle => '播放器采用封面的主色调';

  @override
  String get settingsGlassEffectTitle => '液态玻璃效果';

  @override
  String get settingsGlassEffectSubtitle => '底部栏的透镜与模糊——设备较慢时请关闭';

  @override
  String get settingsResetSection => '重置此部分';

  @override
  String get settingsResetEngine => '重置此引擎';

  @override
  String get settingsResetChoices => '重置这些选择';

  @override
  String get settingsResetToDefault => '默认值';

  @override
  String get settingsStartInVizTitle => '启动时进入可视化模式';

  @override
  String get settingsStartInVizSubtitle => '播放器打开时显示示波器而非封面';

  @override
  String get settingsVoiceGridTitle => '声部示波器网格';

  @override
  String get settingsVoiceGridSubtitle => '显示分隔各声部的边框';

  @override
  String get settingsKeepAwakeTitle => '保持屏幕常亮';

  @override
  String get settingsKeepAwakeSubtitle => '显示可视化效果时，屏幕不会变暗或锁定';

  @override
  String get settingsVoiceNamesTitle => '声部名称';

  @override
  String get settingsVoiceNamesSubtitle => '在每个声部框内显示其名称';

  @override
  String get settingsLineThickness => '线条粗细';

  @override
  String get settingsScopeVoiceColor => '声部示波器';

  @override
  String get settingsStereoColors => '立体声：颜色';

  @override
  String get settingsStereoMono => '单色';

  @override
  String get settingsStereoBi => '双色';

  @override
  String get settingsStereoMonoColor => '立体声（单色）';

  @override
  String get settingsStereoLeftColor => '立体声左声道';

  @override
  String get settingsStereoRightColor => '立体声右声道';

  @override
  String get settingsNotePalette => '调色板';

  @override
  String get settingsNoteBoxStyle => '音块样式';

  @override
  String get settingsNoteStyleFlat => '扁平';

  @override
  String get settingsNoteStyleBox => '方块';

  @override
  String get settingsVizAll => '所有可视化';

  @override
  String get settingsVizScopes => '示波器（立体声与分声部）';

  @override
  String get settingsVizFrameRate => '帧率';

  @override
  String get settingsVizFrameRateScreen => '屏幕';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => '强度 / 速度';

  @override
  String get settingsArtworkOpacity => '背景封面不透明度';

  @override
  String get settingsProjectMTitle => 'projectM 设置';

  @override
  String get settingsProjectMSubtitle => '预设、过渡、质量、mesh…';

  @override
  String get settingsNotifyTrackTitle => '切换曲目时通知';

  @override
  String get settingsNotifyTrackSubtitle => '以系统通知显示新曲目的标题';

  @override
  String get settingsSilenceDetection => '静音检测';

  @override
  String get settingsCrossfade => '交叉淡化';

  @override
  String get localActionPlay => '播放文件或文件夹';

  @override
  String get localActionImport => '导入文件或文件夹';

  @override
  String localOpsImporting(String name) {
    return '正在导入 $name…';
  }

  @override
  String get localOpsImportingSelection => '正在导入所选文件…';

  @override
  String localOpsDeleting(String name) {
    return '正在删除 $name…';
  }

  @override
  String get localOpsPhaseCopying => '复制';

  @override
  String get localOpsPhaseExtracting => '解压';

  @override
  String get localOpsPhaseRegistering => '加入曲库';

  @override
  String get localOpsPhaseDeleting => '删除文件';

  @override
  String get localImportFiles => '导入文件';

  @override
  String get storageLocalImports => '本地导入';

  @override
  String get settingsVgmJapaneseTags => '日文标签 (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp => '当 VGM 标签包含日文标题/游戏/作者字段时优先使用。';

  @override
  String get localImportFolder => '导入文件夹';

  @override
  String get localLibraryTitle => '此设备上';

  @override
  String get libraryOnAnotherDevice => '在另一台设备上';

  @override
  String get localLibraryEmpty => '还没有本地导入。请在主页使用“导入文件”或“导入文件夹”。';

  @override
  String queueLimitReached(int count) {
    return '队列已限制为前 $count 首';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return '删除“$name”？文件及其关联文件（封面等）将被移除。';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除文件夹“$name”及其中的 $count 首曲目？',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '已将 $count 首曲目导入资料库';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '已导入 $tracks 首 — $albums 张专辑';
  }

  @override
  String localImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get settingsCrossfadeHelp => '将每首曲目的结尾与下一首的开头交叠。设为 0 时仍为无缝播放。';

  @override
  String get settingsMinSubsongSection => '过短的子曲目';

  @override
  String get settingsMinSubsongTitle => '最短时长';

  @override
  String get settingsMinSubsongHelp =>
      '短于此长度的子曲目不会进入列表和播放队列——游戏文件中的音效往往比音乐还多。设为 0 则不排除任何子曲目；时长未知的不会被视为过短。';

  @override
  String get localNewFolder => '新建文件夹';

  @override
  String get localFolderName => '文件夹名称';

  @override
  String get localRename => '重命名';

  @override
  String get localMoveTo => '移动到…';

  @override
  String get localMove => '移动';

  @override
  String get localMoveNothing => '没有移动任何内容';

  @override
  String get localNameInvalid => '名称无效';

  @override
  String get localNameTaken => '该名称已被使用';

  @override
  String get localMoveIntoItself => '无法将文件夹移动到其自身中';

  @override
  String get localManageFailed => '操作失败';

  @override
  String subsongSkippedShort(int seconds) {
    return '不会加入队列：不足 $seconds 秒（设置 → 播放）';
  }

  @override
  String get settingsQueuePrefetchSection => '队列下载';

  @override
  String get settingsQueuePrefetchTitle => '下载整个队列';

  @override
  String get settingsQueuePrefetchSubtitle =>
      '一次一个文件；上一个下载完成后立即开始下一个缺失曲目。关闭：仅获取下一曲。';

  @override
  String get settingsCdRipDeclickSection => 'CD 抓轨';

  @override
  String get settingsCdRipDeclickTitle => '去除曲目开头的咔哒声';

  @override
  String get settingsCdRipDeclickSubtitle =>
      '劣质 CD 抓轨（mp3、ape、ogg、flac…）常以几个损坏的采样开头。在播放 200 毫秒真正的音乐之前会将其修复，之后滤波器不再介入。';

  @override
  String get settingsSilenceSkipTitle => '静音时跳到下一首';

  @override
  String get settingsSilenceSkipSubtitle => '输出持续无声时自动前进';

  @override
  String get settingsSilenceDelay => '静音延迟';

  @override
  String get settingsDefaultDuration => '默认时长';

  @override
  String get settingsDefaultDurationHelp =>
      '当歌曲没有已知时长（无标签、无服务器元数据）时使用 — 避免它一直播放或无限循环。不适用于 Amiga 歌曲（UADE），它们有自己的时长数据库。';

  @override
  String get settingsForcedLoopHeader => '强制循环 / 淡出';

  @override
  String get settingsForcedLoopHelp =>
      '某些格式会循环特定段落（VGM、tracker 模块…），另一些则不会。“无限”会忽略歌曲的自然结束。';

  @override
  String get settingsForceLoopCount => '强制循环次数';

  @override
  String get settingsLoopCount => '循环次数';

  @override
  String get settingsForceFadeout => '强制淡出';

  @override
  String get settingsFadeoutDuration => '淡出时长';

  @override
  String get settingsResetEnginesTitle => '重置引擎设置？';

  @override
  String get settingsResetEnginesBody => '所有引擎设置将恢复为默认值。';

  @override
  String get settingsResetDefaultsTitle => '恢复默认值';

  @override
  String get settingsResetDefaultsSubtitle => '所有引擎';

  @override
  String get settingsDefaultDecoders => '默认解码器';

  @override
  String get settingsDefaultDecodersSubtitle => '多个引擎都能播放的格式';

  @override
  String get settingsDecodersHelp => '有些格式可由多个引擎播放。选择默认使用哪一个 — 其他格式会自动路由。';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga trackers（mod、med、okt…）';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackers — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'libopenmpt 无法读取的模块 — .musx、.liq、.fnk…';

  @override
  String get settingsEngineGmeSubtitle => 'SPC, VGM(gme), KSS, AY… — EQ、立体声';

  @override
  String get settingsEngineNsfSubtitle => 'NES / NSF — 质量、滤波器、各芯片选项';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — 高通滤波器';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — 使用中的 SoundFont';

  @override
  String get settingsEngineGsfSubtitle => 'GBA / GSF — 插值、低通、回声';

  @override
  String get settingsEngineUadeSubtitle => 'Amiga — 声像、耳机、增益、LED';

  @override
  String get settingsEngineSidSubtitle => 'C64 / SID — 时钟、型号、ReSIDfp 滤波器';

  @override
  String get settingsEngineAdplugSubtitle => 'AdLib OPL — 立体声/环绕谐波模式';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU、混响';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612、OPL3、QSound 内核…';

  @override
  String get settingsMasterVolume => '主音量';

  @override
  String get settingsAmplification => '放大';

  @override
  String get settingsAmigaFilter => 'Amiga 滤波器';

  @override
  String get settingsInterpolation => '插值';

  @override
  String get settingsPolyphony => '复音';

  @override
  String get settingsReverb => '混响';

  @override
  String get settingsChorus => '合唱';

  @override
  String get playbackMt32NoRoms =>
      '此 MIDI 为 Roland MT-32 编写。缺少其 ROM，因此使用 SoundFont 播放，音色已映射到 General MIDI — 可在「设置 › 引擎 › Munt」导入 ROM。';

  @override
  String get settingsMidiMt32ToGm => '转换 MT-32 文件';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      '为 Roland MT-32 编写的 MIDI 按 MT-32 自己的音色表编号：映射到最接近的 General MIDI 音色后，听到的是合理的乐器而不是随机音色。';

  @override
  String get settingsInterpNone => '无';

  @override
  String get settingsInterpLinear => '线性';

  @override
  String get settingsInterpCubic => '三次';

  @override
  String get settingsInterpSinc => 'Sinc（最佳）';

  @override
  String get settingsStereoSeparation => '立体声分离度';

  @override
  String get settingsGmeSilenceSubtitle => '引擎检测到长时间静音时结束曲目';

  @override
  String get settingsStereoDepth => '立体声深度';

  @override
  String get settingsEqualizer => '均衡器';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — 对 SPC 无效';

  @override
  String get settingsBass => '低音';

  @override
  String get settingsTreble => '高音';

  @override
  String get settingsAppliedLive => '立即生效，播放中也适用。';

  @override
  String get settingsAppliedNextTrack => '在下次加载的歌曲上生效。';

  @override
  String get settingsSidEmulation => '模拟';

  @override
  String get settingsSidResidfp => 'ReSIDfp（精确）';

  @override
  String get settingsSidLite => 'SIDLite（快速）';

  @override
  String get settingsSidSampling => '采样';

  @override
  String get settingsSidSamplingInterp => '插值（快速）';

  @override
  String get settingsSidSamplingResample => 'Resample（最佳）';

  @override
  String get settingsSidClock => '时钟';

  @override
  String get settingsSidModel => 'SID 型号';

  @override
  String get settingsSidFilter => 'SID 滤波器';

  @override
  String get settingsSidForceSecond => '强制第 2 个 SID';

  @override
  String get settingsSidSecondSubtitle => '立体声 2SID 曲目';

  @override
  String get settingsSidSecondAddr => '第 2 个 SID 地址';

  @override
  String get settingsSidForceThird => '强制第 3 个 SID';

  @override
  String get settingsSidThirdAddr => '第 3 个 SID 地址';

  @override
  String get settingsSidAutoFilter => '自动 6581 滤波范围';

  @override
  String get settingsSidAutoFilterSubtitle => '按曲目作者推荐的值（sidplayfp 数据表）';

  @override
  String get settingsSid6581Range => '6581 滤波范围';

  @override
  String get settingsSid6581Curve => '6581 滤波曲线';

  @override
  String get settingsSid8580Curve => '8580 滤波曲线';

  @override
  String get settingsSidNote =>
      'SID 滤波器与曲线实时生效；模拟 / 采样 / 时钟 / 型号 / 第 2-3 个 SID 在下一首生效。';

  @override
  String get settingsAudioOutput => '音频输出';

  @override
  String get settingsAdplugNote => 'Surround：两颗略微失谐的 OPL 芯片。在下一首生效。';

  @override
  String get settingsHeSpuMain => '主声部（SPU）';

  @override
  String get settingsHeSpuReverb => '混响（SPU）';

  @override
  String get settingsNsfQuality => '质量 (nsfplay)';

  @override
  String get settingsLowpassFilter => '低通滤波器';

  @override
  String get settingsHighpassFilter => '高通滤波器';

  @override
  String get settingsRegion => '区域';

  @override
  String get settingsNsfRegionNtscForced => '强制 NTSC';

  @override
  String get settingsNsfRegionPalForced => '强制 PAL';

  @override
  String get settingsNsfRegionDendyForced => '强制 Dendy';

  @override
  String get settingsNsfForceIrq => '强制 IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — 脉冲波（APU1）';

  @override
  String get settingsNsfApu2Title => '2A03 — 三角波 / 噪声 / DPCM（APU2）';

  @override
  String get settingsNsfUnmuteOnReset => '重置时取消静音';

  @override
  String get settingsNsfPhaseRefresh => '刷新相位';

  @override
  String get settingsNsfPhaseRefreshSubtitle => '写入周期值时重置相位';

  @override
  String get settingsNsfNonlinearMixer => '非线性混音';

  @override
  String get settingsNsfApu1NonlinearSubtitle => '2A03 的真实混音（否则为线性）';

  @override
  String get settingsNsfDutySwap => '交换 duty cycle';

  @override
  String get settingsNsfDutySwapSubtitle => '25% / 50% duty 的顺序';

  @override
  String get settingsNsfNegateSweep => '初始化时负向 sweep';

  @override
  String get settingsNsfEnable4011 => '启用 \$4011 寄存器';

  @override
  String get settingsNsfEnable4011Subtitle => 'DAC 直接输出（原始的咔哒声）';

  @override
  String get settingsNsfPeriodicNoise => '周期性噪声';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => '噪声发生器的短模式';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM 防咔哒';

  @override
  String get settingsNsfRandomizeNoise => '初始化时随机化噪声';

  @override
  String get settingsNsfTriangleMute => '静音三角波';

  @override
  String get settingsNsfTriangleMuteSubtitle => '在超声波周期时静音三角波';

  @override
  String get settingsNsfRandomizeTri => '初始化时随机化三角波';

  @override
  String get settingsNsfDpcmReverse => 'DPCM 反向';

  @override
  String get settingsNsfN163Serial => '串行复用';

  @override
  String get settingsNsfN163SerialSubtitle => '多声部曲目上 N163 的真实嗡鸣';

  @override
  String get settingsNsfN163PhaseReadOnly => '相位只读';

  @override
  String get settingsNsfN163LimitWavelength => '限制波长';

  @override
  String get settingsNsfFdsCutoff => '低通截止频率';

  @override
  String get settingsNsfFds4085Reset => '\$4085 重置';

  @override
  String get settingsNsfFdsWriteProtect => '写保护';

  @override
  String get settingsNsfVrc7Patch => '音色组';

  @override
  String get settingsNsfVrc7Opll => 'OPLL 模式';

  @override
  String get settingsNsfVrc7OpllSubtitle => '模拟 YM2413 而非 VRC7';

  @override
  String get settingsGbsHpFilter => '高通滤波器 (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG（经典 GB）';

  @override
  String get settingsGbsFilterCgb => 'CGB（GB Color）';

  @override
  String get settingsEcho => '回声';

  @override
  String get settingsUadePostfx => '后期处理';

  @override
  String get settingsUadePostfxSubtitle => '启用效果链（以下各项都需要它）';

  @override
  String get settingsUadePan => '声像（立体声分离度）';

  @override
  String get settingsUadePanValue => '声像量';

  @override
  String get settingsUadeHeadphones => '耳机';

  @override
  String get settingsUadeLed => 'LED（Paula 滤波器）';

  @override
  String get settingsUadeLedAuto => '自动（按曲目）';

  @override
  String get settingsUadeLedOn => '强制开启';

  @override
  String get settingsUadeLedOff => '强制关闭';

  @override
  String get settingsUadeFilterType => '滤波器类型';

  @override
  String get settingsUadeGain => '增益';

  @override
  String get settingsUadeGainValue => '增益量';

  @override
  String get settingsSoundfontLoading => '正在加载目录…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return '目录不可用（$error）';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get settingsSoundfontImport => '导入 SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle => '选择本机上的 .sf2 文件';

  @override
  String get settingsSoundfontImported => '已导入';

  @override
  String get settingsSoundfontInvalid => '该文件不是 SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return '导入失败 — $error';
  }

  @override
  String get settingsSoundfontDelete => '删除文件';

  @override
  String get settingsCreditsHeader => '致谢与许可';

  @override
  String get settingsRightsNotice =>
      'Rewamp 只是播放器：它不托管任何文件，也不分发音乐。曲目来自在线保存档案，其权利仍归各权利人所有。收听、下载和保存这些曲目是否符合适用权利及您所在国家的法规，由您自行负责。';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '支持 $count 种格式',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '分布在 $count 个播放引擎中 — 查看详情',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga 时长与元数据';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb by Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID 数据与封面';

  @override
  String get settingsGb64Subtitle => 'GameBase64 (gb64.com) — C64 游戏元数据与图像。';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 字体';

  @override
  String get settingsFt2FontSubtitle =>
      'Pattern 可视化器的 FastTracker II 风格使用 8bitbubsy 的 ft2-clone (16-bits.org) 中的 FT2 位图字体。';

  @override
  String settingsLinkCopied(String url) {
    return '已复制 $url';
  }

  @override
  String get settingsOpenLink => '打开链接';

  @override
  String get settingsEnginesHeader => '播放引擎';

  @override
  String get settingsComponentsHeader => '其他组件';

  @override
  String get settingsResetAll => '重置所有设置';

  @override
  String get settingsResetAllSubtitle => '通用、可视化、播放、引擎 — 不含资料库';

  @override
  String get settingsResetAllTitle => '重置所有设置？';

  @override
  String get settingsResetAllBody => '通用、可视化、播放和所有引擎都将恢复为默认值。你的资料库和历史记录不受影响。';

  @override
  String get settingsRenewUserId => '更换匿名标识';

  @override
  String get settingsRenewUserIdTitle => '更换匿名标识？';

  @override
  String get settingsRenewUserIdBody =>
      '将为服务器统计创建一个新的匿名标识。\n\n旧标识将不再使用。你的本地历史记录和收藏不受影响。';

  @override
  String get settingsRenewUserIdFailed => '失败 — 无法连接服务器';

  @override
  String settingsNewUserId(String id) {
    return '新标识：$id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID：$id';
  }

  @override
  String get settingsNoUserId => '未注册任何标识';

  @override
  String get settingsCleanDb => '清理本地数据库';

  @override
  String get settingsCleanDbSubtitle => '移除文件已不存在的条目（已删除的下载、旧错误）';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已移除 $count 条孤立条目',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => '本地数据库正常 — 无需清理';

  @override
  String get settingsClearCache => '清除缓存（封面与元数据）';

  @override
  String get settingsClearCacheSubtitle =>
      '移除缓存的封面和已获取的元数据（STIL、时长）— 下次播放时会重新下载';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '缓存已清除（$count 张封面）',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => '存储';

  @override
  String get storageSubtitle => '应用在磁盘上保留的内容及删除';

  @override
  String get storageDownloads => '下载';

  @override
  String get storageArtworkCache => '封面缓存';

  @override
  String get storageSoundfonts => '音色库';

  @override
  String get storagePresets => '可视化预设';

  @override
  String get storageOpenedFiles => '打开过的文件';

  @override
  String get storageOpenedEmpty => '从外部打开的文件（分享、“用其他应用打开”、手机上的文件选择器）会复制到这里。';

  @override
  String get storageInUse => '在播放列表或资料库中';

  @override
  String get storageDeleteAll => '全部删除';

  @override
  String get storageClear => '清空';

  @override
  String get storageDeleteSelection => '删除所选';

  @override
  String get storageSelectAll => '全选';

  @override
  String get storageFilterHint => '按名称筛选';

  @override
  String get storageNoMatch => '没有文件匹配此筛选条件。';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 项',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 个文件？',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 个文件？其中 $inUse 个正被播放列表或资料库使用，这些条目将失去对应文件。',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      '删除所有已下载文件及其资料库记录？收藏和播放列表保留条目，但文件需要重新下载。';

  @override
  String get storageSoundfontsClearBody => '删除所有音色库（包括导入的）？目录中的会按需重新下载；导入的将丢失。';

  @override
  String get storagePresetsClearBody =>
      '删除已下载的预设包和导入的预设？内置预设保留；预设包会重新下载，导入的将丢失。';

  @override
  String get storageOpenedDeleteAllTitle => '删除打开过的文件';

  @override
  String get storageInUseDeleteTitle => '文件正在使用';

  @override
  String get storageInUseDeleteBody => '播放列表或资料库仍指向此文件。删除后这些条目将失去对应文件。';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件 — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件 — $size · 通过专辑和曲目管理',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 个文件？播放列表或资料库使用中的文件将保留。',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => '重置统计';

  @override
  String get settingsResetStatsSubtitle => '移除收听历史和播放计数';

  @override
  String get settingsClearStatsTitle => '重置统计？';

  @override
  String get settingsClearStatsBody =>
      '此操作将永久删除：\n• 全部收听历史\n• 播放计数\n\n你的收藏和资料库不受影响。';

  @override
  String get settingsStatsCleared => '统计已删除';

  @override
  String get settingsResetDatabase => '重置数据库';

  @override
  String get settingsResetDatabaseSubtitle => '删除所有内容：历史、收藏、播放列表、缓存';

  @override
  String get settingsResetDbTitle => '重置数据库？';

  @override
  String get settingsCleanLocalTitle => '清理无法播放的本地条目';

  @override
  String get cleanStageScan => '正在扫描条目…';

  @override
  String get cleanStageSync => '正在与你的账户同步…';

  @override
  String get cleanStagePurge => '正在从账户中移除…';

  @override
  String get cleanStageDelete => '正在本地移除…';

  @override
  String get settingsCleanLocalBody =>
      '指向本设备上已不存在文件的资料库条目。它们也会从你的账户中移除，因此会从其他设备上消失。';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已移除 $count 个条目',
      zero: '没有需要清理的内容',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      '此操作将永久删除：\n• 全部收听历史\n• 所有计数\n• 所有收藏\n• 所有播放列表\n• 所有缓存的元数据\n\n你的音频文件不会被删除。';

  @override
  String get settingsDbReset => '数据库已重置';

  @override
  String get settingsDeleteDownloads => '删除下载内容';

  @override
  String get settingsDeleteDownloadsSubtitle => '删除 online 文件夹中的所有文件（歌曲、封面）';

  @override
  String get settingsCleanAll => '清理本地数据库和缓存';

  @override
  String get settingsCleanAllSubtitle =>
      '移除文件已丢失的条目、指向其他设备上文件的资料库条目，并清空封面和元数据缓存';

  @override
  String get settingsCleanAllConfirmBody =>
      '指向其他设备上文件的资料库条目也会从您的账户中移除，因此也会从您的其他设备移除。封面和元数据将在下次播放时重新下载。';

  @override
  String get settingsDataAdvanced => '高级';

  @override
  String get settingsDataAdvancedSubtitle => '逐项清理、缓存和重置';

  @override
  String get settingsDataGroupDb => '数据库';

  @override
  String get settingsDataGroupCache => '缓存';

  @override
  String get settingsDataGroupReset => '重置';

  @override
  String get settingsDeleteDownloadsTitle => '删除下载内容？';

  @override
  String get settingsDeleteDownloadsBody =>
      '此操作将永久删除 online 文件夹中所有已下载的文件（歌曲、专辑、封面）。\n\n数据库条目会保留，但会指向不存在的文件。';

  @override
  String get settingsDownloadsDeleted => '下载内容已删除';

  @override
  String get settingsColor => '颜色';

  @override
  String get settingsPmPresets => '预设';

  @override
  String get settingsPmRandomNext => '随机下一个预设';

  @override
  String get settingsPmRandomNextSubtitle => '关闭：按顺序播放预设';

  @override
  String get settingsPmLockPreset => '锁定预设';

  @override
  String get settingsPmLockPresetSubtitle => '不自动切换';

  @override
  String get settingsPmPresetDuration => '预设间隔时间';

  @override
  String get settingsPmTransitions => '过渡';

  @override
  String get settingsPmBlend => '交叉淡化过渡';

  @override
  String get settingsPmBlendSubtitle => '关闭：立即切换预设';

  @override
  String get settingsPmTransitionStyle => '过渡样式';

  @override
  String get settingsPmTransitionStyleSubtitle => '混合过渡使用的图案';

  @override
  String get settingsPmTransitionRandom => '随机';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => '跟随节拍切换预设';

  @override
  String get settingsPmHardcutTime => 'Hardcut：最短时间';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut：灵敏度';

  @override
  String get settingsPmRendering => '渲染';

  @override
  String get settingsPmQuality => '质量';

  @override
  String get settingsPmQualitySubtitle => '渲染分辨率（Max = 原生分辨率）';

  @override
  String get settingsPmBeatSensitivity => '节拍灵敏度';

  @override
  String get settingsPmAspectRatio => '保持宽高比';

  @override
  String get settingsPmAspectRatioSubtitle => '适用于支持的着色器';

  @override
  String get settingsPmPermissive => '宽容模式';

  @override
  String get settingsPmPermissiveSubtitle => '加载有脚本错误的 .milk 文件';

  @override
  String get accountTitle => '账户';

  @override
  String get accountSubtitle => '保存并同步你的音乐库';

  @override
  String get accountAnonymous => '匿名账户';

  @override
  String get accountAnonymousExplain =>
      '你的收藏和播放记录已保存在服务器上，但只有本设备能访问。添加电子邮箱后即可在其他设备找回。';

  @override
  String get accountEmailAttached => '邮箱已确认 — 此账户可以恢复';

  @override
  String get accountEmailPending => '邮箱尚未确认';

  @override
  String get accountInsecureStorage => '本设备的安全存储不可用：账户标识以明文保存。';

  @override
  String get accountSaveCta => '保存我的账户';

  @override
  String get accountStatSongs => '收藏的曲目';

  @override
  String get accountStatAlbums => '收藏的专辑';

  @override
  String get accountStatPlays => '播放次数';

  @override
  String get accountCreatedLabel => '创建于';

  @override
  String get accountSignOut => '退出登录';

  @override
  String get accountRevoke => '在所有设备退出';

  @override
  String get accountRevokeSubtitle => '退出其他所有设备的登录';

  @override
  String get accountRevokeBody => '其他所有设备都会退出登录，本设备保持登录。';

  @override
  String get accountRevokeDone => '其他设备已退出登录';

  @override
  String get accountDelete => '删除我的账户';

  @override
  String get accountDeleteSubtitle => '删除服务器上的账户及其数据，不可撤销。';

  @override
  String accountDeleteBody(int items, int lists) {
    return '将从服务器删除 $items 个收藏和 $lists 个播放列表，此操作无法撤销。';
  }

  @override
  String get accountDeleteKeepsLocal => '你的下载和本设备的音乐库不受影响。';

  @override
  String get accountDeleteDone => '账户已删除';

  @override
  String get accountSignOutSubtitle => '本设备将从新的空账户重新开始';

  @override
  String get accountSignOutTitle => '退出登录？';

  @override
  String accountSignOutBody(String email) {
    return '你可以用发送到 $email 的验证码回到此账户。';
  }

  @override
  String get accountSignedOut => '已退出登录';

  @override
  String get accountNoSignOut => '无法退出登录';

  @override
  String get accountNoSignOutSubtitle => '没有邮箱，此账户将永久丢失。';

  @override
  String get accountDetach => '解绑邮箱';

  @override
  String get accountDetachSubtitle => '账户恢复为匿名，不会删除任何数据';

  @override
  String get accountDetachBody => '没有邮箱，此账户将无法再从其他设备找回。';

  @override
  String get accountDetachDone => '邮箱已解绑';

  @override
  String get accountOffline => '离线时无法使用账户';

  @override
  String get accountEmailTitle => '电子邮箱';

  @override
  String get accountEmailExplain => '我们会发送 6 位验证码以确认邮箱。它仅用于找回账户。';

  @override
  String get accountEmailLabel => '电子邮箱';

  @override
  String get accountCodeTitle => '验证码';

  @override
  String accountCodeExplain(String email) {
    return '验证码已发送至 $email，有效期 10 分钟。';
  }

  @override
  String get accountCodeLabel => '6 位验证码';

  @override
  String get accountSendCode => '发送验证码';

  @override
  String get accountVerify => '确认';

  @override
  String get accountResend => '重新发送验证码';

  @override
  String accountResendIn(int n) {
    return '$n 秒后可重发';
  }

  @override
  String get accountCheckSpam => '邮件可能需要一分钟才到达 — 也请查看垃圾邮件文件夹。';

  @override
  String get accountErrorInvalidEmail => '邮箱地址无效';

  @override
  String get accountErrorTooMany => '请求过于频繁，请几分钟后再试';

  @override
  String get accountErrorInvalidCode => '验证码错误或已过期';

  @override
  String get accountErrorCodeLength => '验证码为 6 位数字';

  @override
  String get albumOfflinePartial => '离线 — 显示本设备上已有的内容';

  @override
  String get accountErrorNetwork => '连接失败，请重试';

  @override
  String get accountMergeTitle => '合并此音乐库？';

  @override
  String accountMergeBody(String email) {
    return '本设备的收藏和播放记录将并入账户 $email。此操作不可撤销。';
  }

  @override
  String get accountMergeConfirm => '合并';

  @override
  String get accountCarryLocal => '保留本设备的收藏';

  @override
  String accountCarryLocalOn(int n) {
    return '本设备的 $n 个收藏和播放列表将添加到该账户。';
  }

  @override
  String get accountCarryLocalOff => '将从本设备删除，并用该账户的内容替换。已下载的文件会保留。';

  @override
  String get accountDropLocalTitle => '删除本设备的数据？';

  @override
  String get accountCreatedOk => '账户已保存，你的音乐库已备份';

  @override
  String get accountMergedOk => '已登录 — 本地收藏已添加';

  @override
  String get accountSignedInOk => '已登录';

  @override
  String get playlistEntryMissing => '本设备上没有该文件';

  @override
  String get playlistEntryMissingRestorable => '文件缺失 — 可重新下载';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '缺少 $n 个',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => '保存到我的账户';

  @override
  String get playlistBackupSubtitle => '即使重装应用也能保留此播放列表';

  @override
  String get playlistBackupUpdate => '更新备份';

  @override
  String get playlistBackupUpdateSubtitle => '用当前版本替换账户中的副本';

  @override
  String get playlistBackupStop => '停止保存';

  @override
  String get playlistBackupStopped => '已移除备份';

  @override
  String get playlistBackupDone => '播放列表已保存';

  @override
  String get playlistBackupFailed => '保存失败';

  @override
  String get playlistBackupNoAccount => '本设备没有账户';

  @override
  String get playlistSyncTooltip => '与我的账户同步';

  @override
  String get playlistSyncRunning => '同步中…';

  @override
  String get playlistSyncDone => '播放列表已同步';

  @override
  String get playlistSyncPartial => '部分播放列表未能保存';

  @override
  String get playlistFetchMissing => '下载缺失的曲目';

  @override
  String get playlistFetchDone => '已下载缺失的曲目';

  @override
  String get playlistFetchPartial => '部分曲目下载失败';

  @override
  String get playlistEntryFetchFailed => '无法下载此曲目';

  @override
  String get accountStatPlaylists => '播放列表';

  @override
  String get accountSyncNow => '立即同步';

  @override
  String get accountSyncAuto => '在后台自动进行';

  @override
  String get accountSyncAnonymous => '已备份到服务器。添加邮箱即可与其他设备同步。';

  @override
  String get accountSyncPending => '有更改等待发送';

  @override
  String accountSyncLast(String when) {
    return '上次同步：$when';
  }

  @override
  String get accountSyncDone => '同步完成';

  @override
  String get accountSyncFailed => '同步失败，稍后重试';

  @override
  String get podiumFirst => '第 1 名';

  @override
  String get podiumSecond => '第 2 名';

  @override
  String get podiumThird => '第 3 名';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return '$production 的音乐，$compo $place';
  }

  @override
  String podiumContains(String place, String compo) {
    return '收录 $compo 的$place';
  }

  @override
  String get competitionEmpty => '本次比赛没有参赛作品';

  @override
  String get competitionEntryNoMusic => '目录中没有该作品的音乐';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 首',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get onboardingBetaTitle => '测试版';

  @override
  String get onboardingBetaBody =>
      'Rewamp 仍在开发中。本地数据——音乐库、播放列表、收藏、收听统计——可能在 1.0 版本前被清空。已下载的文件不会受影响，但重要内容请另行备份。';

  @override
  String onboardingVersion(String version, String build) {
    return '版本 $version（构建 $build）';
  }

  @override
  String get onboardingExploreTitle => '探索';

  @override
  String get onboardingExploreBody =>
      '从各大在线档案库中浏览和搜索数万首芯片音乐与音轨模块，可按艺术家、专辑、平台或聚会查找。点按试听，下载收藏。';

  @override
  String get onboardingLibraryTitle => '你的音乐库';

  @override
  String get onboardingLibraryBody =>
      '保存喜欢的曲目，创建播放列表并用文件夹整理。已下载的音乐可离线播放，登录后音乐库会在各设备间同步。';

  @override
  String get onboardingPlayerTitle => '播放器';

  @override
  String get onboardingPlayerBody =>
      '滑动切换曲目，并可打开可视化效果：示波器、分声部示波、滚动音符、音轨网格。多曲目文件会列出子曲目，每个声部都能单独静音。';

  @override
  String get onboardingReplayTitle => '功能介绍';

  @override
  String get onboardingReplaySubtitle => '重新查看测试版提示与功能导览';

  @override
  String get settingsPatternTitle => 'Pattern';

  @override
  String get settingsPatternSubtitle => '音轨网格：颜色、列、滚动';

  @override
  String get patternOpaqueBg => '不透明背景';

  @override
  String get patternOpaqueBgSubtitle => '隐藏网格后方的封面';

  @override
  String get commonSave => '保存';

  @override
  String get commonImport => '导入';

  @override
  String get accountDisplayName => '公开名称';

  @override
  String get accountDisplayNameNotSet => '未设置 — 发布播放列表需要';

  @override
  String get accountDisplayNameHint => '你希望署名的名字。';

  @override
  String get accountDisplayNameChangeWarning => '更改后，所有已发布的播放列表都会退回审核。';

  @override
  String get accountDisplayNameTaken => '该名称已被占用，请另选一个。';

  @override
  String get accountDisplayNameLength => '2 到 40 个字符。';

  @override
  String get accountDisplayNameSaved => '公开名称已保存';

  @override
  String accountDisplayNameBackInReview(int n) {
    return '退回审核的播放列表：$n';
  }

  @override
  String get playlistPublish => '设为公开';

  @override
  String get playlistPublishSubtitle => '申请发布（需先审核）';

  @override
  String get playlistPublishTitle => '发布这个播放列表？';

  @override
  String get playlistPublishBody => '通过审核后所有人可见，并署上你的公开名称。封面取自其中的曲目。';

  @override
  String get playlistPublishCta => '申请';

  @override
  String get playlistPublishSubmitted => '已提交审核';

  @override
  String get playlistPublishPending => '等待审核';

  @override
  String get playlistPublishApproved => '已公开';

  @override
  String playlistPublishRejected(String reason) {
    return '被拒：$reason';
  }

  @override
  String get playlistPublishRejectedShort => '被拒';

  @override
  String get playlistPublishNeedName => '请选择你希望署名的名字';

  @override
  String get playlistPublishNeedTracks => '至少需要 5 首曲目才能发布';

  @override
  String get playlistPublishHasLocal => '设备上的文件无法发布 — 别人无法播放';

  @override
  String get playlistPublishTooManyPending => '你已有 3 个播放列表在等待审核';

  @override
  String get playlistPublishRefused => '发布被拒：请检查曲目和待审核的申请';

  @override
  String get playlistPublishFailed => '发布失败';

  @override
  String get playlistPublishWithdrawn => '播放列表已恢复为私有';

  @override
  String get playlistUnpublish => '设为私有';

  @override
  String get playlistUnpublishSubtitle => '将其从公开播放列表中移除';

  @override
  String get playlistRenamePublishedTitle => '重命名已发布的播放列表？';

  @override
  String get playlistRenamePublishedBody =>
      '接受审核的正是名称：重命名会让播放列表退回审核，期间取消公开。添加或重新排序曲目则不会。';

  @override
  String playlistByAuthor(String author) {
    return '作者：$author';
  }

  @override
  String get settingsSpectrumMode => '频谱模式';

  @override
  String get settingsSpectrumModeStandard => '标准';

  @override
  String get settingsSpectrumModeColored => '彩色';

  @override
  String get settingsSpectrumModeBeam => '光束';

  @override
  String get settingsSpectrumModeLine => '线条';

  @override
  String get settingsSpectrumModeRing => '环形';

  @override
  String get settingsPianoMode => '钢琴外观';

  @override
  String get settingsPianoModeRoll => '键盘';

  @override
  String get settingsPianoModeFalling => '下落音符';

  @override
  String get settingsPianoColor => '颜色';

  @override
  String get settingsPianoColorVoice => '按声部';

  @override
  String get settingsPianoColorInstrument => '按乐器';

  @override
  String get settingsPianoGlow => '按键发光';

  @override
  String get settingsPianoLighting => '琴键光影';

  @override
  String get settingsPianoVoiceNames => '声部名称';

  @override
  String get featuredAdditionsHeader => '目录新增';

  @override
  String get featuredAdditionsCard => '新近添加';

  @override
  String get featuredAdditionsPlaylist => '新近添加的曲目';

  @override
  String get releaseNotesTitle => '新功能';

  @override
  String get releaseNotesV7Cpu => '没有播放时，应用不再在后台运行：大幅减少处理器和电池消耗。';

  @override
  String get releaseNotesV7VizIdle => '播放停止时可视化会静止，帧率上限为每秒 60 帧（可调）。';

  @override
  String get releaseNotesV7Subsongs =>
      '已修复：在 PC Engine、Master System 和 Atari ST（.sndh）上，部分曲目会播放相邻的歌曲。';

  @override
  String get releaseNotesV7Piano => '播放 PC Engine 音乐时，钢琴可视化曾保持空白。';

  @override
  String get releaseNotesV7Database => '被更新损坏的数据库现在会自动修复，不再导致资料库无法访问。';

  @override
  String get releaseNotesDataReset => '本次测试版已重置本地数据。媒体库和播放列表将从账号重建；下载需要重新进行。';

  @override
  String get releaseNotesDismiss => '继续';

  @override
  String get pmManagePresets => '管理预设';

  @override
  String get pmPickTooltip => '选择预设';

  @override
  String get pmPickFilter => '筛选预设';

  @override
  String get pmSourceTooltip => '预设来源';

  @override
  String get pmAddToPlaylistTooltip => '将预设添加到播放列表';

  @override
  String pmSlowPresetDropped(String name) {
    return '「$name」对此设备来说太重，已被排除。';
  }

  @override
  String get pmSlowDeviceTitle => '此设备性能不足';

  @override
  String get pmSlowDeviceOff => '已关闭可视化：此设备无法流畅运行 Milkdrop 预设。';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已排除 $count 个预设',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle => '在此设备上太慢，播放时会跳过。';

  @override
  String get settingsPmSlowPresetsRestore => '恢复';

  @override
  String get pmSourceBundled => '内置预设';

  @override
  String get pmSourceImports => '我的导入';

  @override
  String get pmSourceAll => '全部预设';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个预设',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => '新建播放列表…';

  @override
  String get pmPlaylistName => '播放列表名称';

  @override
  String get pmAddedToPlaylist => '已添加到播放列表';

  @override
  String get pmAlreadyInPlaylist => '已在此播放列表中';

  @override
  String get pmTabPacks => '预设包';

  @override
  String get pmTabBrowse => '浏览';

  @override
  String get pmTabPlaylists => '播放列表';

  @override
  String get pmTabPopular => '热门';

  @override
  String get pmTabSetAside => '已排除';

  @override
  String get pmSetAsideEmpty => '暂无排除项。会让此设备低于 6 fps 的预设将出现在这里。';

  @override
  String get pmSetAsideRestoreAll => '全部恢复';

  @override
  String get pmInstall => '安装';

  @override
  String get pmInstallQueued => '已加入安装队列';

  @override
  String get pmUninstall => '卸载';

  @override
  String get pmUninstalled => '预设包已移除';

  @override
  String get pmUse => '使用';

  @override
  String get pmDefaultPackBanner => '推荐入门包';

  @override
  String pmLicense(String license) {
    return '许可证：$license';
  }

  @override
  String get pmPacksOffline => '无法连接服务器';

  @override
  String get pmSearchPresets => '搜索预设…';

  @override
  String get pmPlayNow => '立即播放';

  @override
  String get pmDownloadAction => '下载';

  @override
  String get pmDownloaded => '预设已下载';

  @override
  String get pmDownloadFailed => '下载失败';

  @override
  String pmPreviewing(String name) {
    return '正在播放：$name';
  }

  @override
  String get pmLocalSection => '我的播放列表';

  @override
  String get pmCuratedSection => 'Rewamp 播放列表';

  @override
  String get pmImportPlaylist => '下载并使用';

  @override
  String get pmPlaylistImported => '播放列表已就绪';

  @override
  String get pmImportFiles => '导入文件…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个预设',
      zero: '未导入任何预设',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => '预设已添加到 projectM 库';

  @override
  String get pmNoPlaylists => '还没有预设播放列表';

  @override
  String get pmSourceApplied => '已应用预设来源';

  @override
  String get pmPlaylistEmpty => '此播放列表为空';

  @override
  String get pmDays7 => '7 天';

  @override
  String get pmDays30 => '30 天';

  @override
  String get pmDays365 => '1 年';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次播放',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => '安装失败';

  @override
  String get pmSingleDownloads => '单独下载';

  @override
  String pmAvailableIn(String pack) {
    return '收录于 $pack';
  }

  @override
  String get pmCleanUp => '清理';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已删除 $count 个预设',
      zero: '无需清理',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => '锁定当前预设';

  @override
  String get pmUnlockAction => '解锁预设';

  @override
  String get pmOrderRandom => '随机播放预设';

  @override
  String get pmOrderSequential => '按顺序播放预设';

  @override
  String get pmUpdateAvailable => '有可用更新';

  @override
  String get pmUpdate => '更新';

  @override
  String get pmSelectAll => '全选';

  @override
  String get pmSelectNone => '取消全选';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 个',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => '未使用的纹理';

  @override
  String pmTexturesFreed(String size) {
    return '已释放 $size';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个纹理',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => '排行榜';

  @override
  String get chartsGlobal => '全局';

  @override
  String get chartsByCollection => '按合集';

  @override
  String get chartsTopSongs => '热门歌曲';

  @override
  String get chartsTopAlbums => '热门专辑';

  @override
  String get chartsRewampSection => 'Top rewamp';

  @override
  String get chartsPublishedSection => '公开排行榜';

  @override
  String chartsUpdated(String date) {
    return '更新于 $date';
  }

  @override
  String get chartsSource => '来源';

  @override
  String get settingsMidiSynth => 'MIDI 合成器';

  @override
  String get settingsMidiSynthAuto => '自动（文件要求时使用 MT-32）';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32（模拟）';

  @override
  String get settingsMt32Section => 'Roland MT-32 模拟';

  @override
  String get settingsMt32RomsTitle => 'MT-32 ROM';

  @override
  String get settingsMt32RomsMissing =>
      '没有可用的 ROM 组合 — 请导入 MT-32 或 CM-32L 的控制 ROM 和 PCM ROM';

  @override
  String settingsMt32RomsActive(String set) {
    return '当前组合：$set';
  }

  @override
  String get settingsMt32Import => '导入 ROM 文件…';

  @override
  String get settingsMt32ImportSubtitle =>
      '控制 ROM + PCM ROM（.rom/.bin），支持 MAME 分半文件。应用不附带 ROM。';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name 不是已知的 MT-32 / CM-32L ROM';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个 ROM 文件',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => '型号';

  @override
  String get settingsMt32ModelAuto => '自动（有 CM-32L 则优先）';

  @override
  String get settingsMt32Reverb => '混响';

  @override
  String get engineDescMt32 =>
      '用于 MIDI 的 Roland MT-32 / CM-32L 模拟（.mid/.midi/.kar/.rmi）';

  @override
  String get miniWindowEnter => '迷你播放器';

  @override
  String get miniWindowExit => '返回主窗口';

  @override
  String get miniWindowIdle => '当前没有播放';

  @override
  String get settingsAlwaysOnTopTitle => '窗口置顶';

  @override
  String get settingsAlwaysOnTopSubtitle => '让窗口始终位于其他窗口之上——主窗口和迷你播放器均适用';

  @override
  String get windowAlwaysOnTopOn => '窗口置顶：已开启';

  @override
  String get miniWindowCoverFill => '放大封面以填满';

  @override
  String get miniWindowCoverFit => '显示完整封面';

  @override
  String get releaseNotesV7Mt32 =>
      '新增 Roland MT-32 引擎，用于游戏 MIDI 音乐（需自备 ROM）。没有 ROM 时，为 MT-32 编写的 MIDI 会适配为 General MIDI 播放。';

  @override
  String get releaseNotesV7Xmp =>
      '新增支持十种少见的模块格式（Archimedes Tracker .musx、.liq、.fnk 等）。';

  @override
  String get releaseNotesV7AmigaAdlib =>
      'Westwood 的 AdLib 音乐（.adl）可播放全部曲目，Amiga 上的 BP SoundMon V1 也能识别了。';

  @override
  String get releaseNotesV7MiniPlayer => 'Mac：新增迷你播放器（紧凑模式或可视化模式），以及“窗口置顶”选项。';

  @override
  String get releaseNotesV7Instruments => '示波器、乐谱和钢琴视图可为每件乐器（而不仅是每个声部）标注名称和颜色。';

  @override
  String get releaseNotesV7Podium => '搜索：可筛选在演示场景比赛中获得第 1、2、3 名的曲目。';

  @override
  String get releaseNotesV7ShortSubsongs =>
      '过短的子曲目（游戏音效）不再加入“全部播放”——阈值可在 设置 → 播放 中调整。';

  @override
  String get releaseNotesV7LocalFolders =>
      '导入：可直接拖入整个文件夹（压缩包会自动解压），也可新建、重命名或移动文件夹。';

  @override
  String get releaseNotesV7Midi => 'MIDI：鼓声不再以钢琴音色播放，音量也不再失真。';

  @override
  String get releaseNotesV7ProjectM =>
      'projectM：预设不再在每次启动时按相同顺序重复，暂停后也不会再误将预设排除。';

  @override
  String get libraryFileMissing => '文件缺失';
}
