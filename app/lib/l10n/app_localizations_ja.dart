// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get navHome => 'ホーム';

  @override
  String get navSearch => '検索';

  @override
  String get navLibrary => 'ライブラリ';

  @override
  String get noFileSelected => 'ファイルが選択されていません';

  @override
  String get openFile => 'ファイルを開く';

  @override
  String get pickerLabelAudio => 'オーディオ';

  @override
  String get formatNotSupported => '非対応のフォーマットです';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'サポートされていない形式: $file（.$ext）';
  }

  @override
  String playbackFileMissing(String file) {
    return 'この端末にありません: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'ファイルはサーバーにありません: $file';
  }

  @override
  String get failedToLoadFile => 'ファイルを読み込めませんでした';

  @override
  String get libraryEmptyHint => 'アーティスト、アルバム、プレイリストが\nここに表示されます。';

  @override
  String get libraryPlaylists => 'プレイリスト';

  @override
  String get libraryArtists => 'アーティスト';

  @override
  String get libraryAlbums => 'アルバム';

  @override
  String get libraryTracks => '曲';

  @override
  String get libraryFavorites => 'お気に入り';

  @override
  String get libraryFavoritesSubtitle => 'お気に入りの曲の自動プレイリスト';

  @override
  String get libraryRecentlyAdded => '最近追加した項目';

  @override
  String get libraryEmpty => 'まだ何もありません';

  @override
  String get libraryRemoved => 'ライブラリから削除しました';

  @override
  String get searchHint => '検索…';

  @override
  String get searchTypePlaceholder => 'タイトル、アーティスト、アルバムを入力…';

  @override
  String get searchNoResults => '結果がありません';

  @override
  String get searchDownloading => 'ダウンロード中…';

  @override
  String searchError(String message) {
    return 'エラー: $message';
  }

  @override
  String get tabAll => '曲';

  @override
  String get tabArtists => 'アーティスト';

  @override
  String get tabAlbums => 'アルバム';

  @override
  String get tabProductions => 'プロダクション';

  @override
  String get filterWithVideo => '動画あり';

  @override
  String get videoUnavailable => 'この動画は再生できません';

  @override
  String get noItems => '項目がありません';

  @override
  String get sortRelevance => '関連度';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => '最近再生した項目';

  @override
  String get noRecentTracks => '最近再生した曲はありません';

  @override
  String get openLocalFile => 'ローカルファイルを開く';

  @override
  String get playerSourceLocal => 'ローカル';

  @override
  String get browseFiles => 'ファイルを参照';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total 件';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded 件読み込み済み…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded 件';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded 件読み込み済み — スクロールしてさらに表示';
  }

  @override
  String countNLoaded(int n) {
    return '$n 件読み込み済み';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n 件のファイル';
  }

  @override
  String get browseFilterByTitle => 'タイトルで絞り込み…';

  @override
  String get browseNoSongs => '曲がありません';

  @override
  String get browseByFormat => 'フォーマット別';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'フォーマットで絞り込み…';

  @override
  String get browseByPlatform => 'プラットフォーム別';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'プラットフォーム名…';

  @override
  String get browseByChip => 'サウンドチップ別';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => '例: YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'アーティスト別';

  @override
  String get browseByArtistSubtitle => '作曲者を見る';

  @override
  String get browseFilterByName => '名前で絞り込み…';

  @override
  String get browseNoArtistFound => 'アーティストが見つかりません';

  @override
  String get browseNoArtistsAvailable => 'アーティストがいません';

  @override
  String get browseNoArtist => 'アーティストなし';

  @override
  String get browseNoAlbum => 'アルバムなし';

  @override
  String get browseTopPacks => 'トップパック';

  @override
  String get browseTopPacksSubtitle => '評価の高いパック';

  @override
  String browseTopPacksLabel(String collection) {
    return 'トップパック — $collection';
  }

  @override
  String get browseLatestPacks => '最新パック';

  @override
  String get browseLatestPacksSubtitle => '最近追加されたもの';

  @override
  String browseLatestPacksLabel(String collection) {
    return '最新パック — $collection';
  }

  @override
  String get browseAllSongs => 'すべての曲';

  @override
  String get browseAllSongsSubtitleAlpha => 'アルファベット順に見る';

  @override
  String get browseAlphabetical => 'アルファベット順';

  @override
  String browseAllLabel(String collection) {
    return 'すべて — $collection';
  }

  @override
  String get browseCollections => 'コレクション';

  @override
  String browseFilesCount(String count) {
    return '$count 件のファイル';
  }

  @override
  String get browseIndexing => 'インデックス作成中';

  @override
  String browseFilterFacet(String name) {
    return '$name を絞り込み…';
  }

  @override
  String get browseAllYears => 'すべての年';

  @override
  String get browseAllYearsSubtitle => 'パーティーのすべての曲';

  @override
  String get browseNoCompo => 'このパーティーのコンポは登録されていません。';

  @override
  String get browseOthers => 'その他';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n エントリー — ランキング',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'プレイリストを再生';

  @override
  String get browsePlayAllRanked => 'すべて再生（ランキング順）';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲 — ランキング順',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'アルバム別に見る';

  @override
  String get browsePlayAll => 'すべて再生';

  @override
  String get browseShuffle => 'シャッフル';

  @override
  String get browseSearchInFolder => 'このフォルダ内を検索…';

  @override
  String get browseFilterThisList => 'このリストを絞り込み…';

  @override
  String get browseSearchSubfolders => 'サブフォルダーを検索';

  @override
  String get browseEmptyFolder => '空のフォルダ';

  @override
  String browsePlaybackError(String message) {
    return '再生できません: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => '表示';

  @override
  String get browseViewList => 'リスト';

  @override
  String get browseViewGrid => 'グリッド';

  @override
  String get browseViewGridCompact => 'コンパクトグリッド';

  @override
  String get browseSearchAlbum => 'アルバムを検索…';

  @override
  String get browseSearchArtist => 'アーティストを検索…';

  @override
  String get browsePlayAlbum => 'アルバムを再生';

  @override
  String get searchDownloadingAlbum => 'アルバムをダウンロード中…';

  @override
  String get searchCategoryChip => 'チップ';

  @override
  String get searchCategoryGroup => 'グループ';

  @override
  String get artistRealName => '本名';

  @override
  String get artistAliases => '別名';

  @override
  String get artistBorn => '生年';

  @override
  String get artistInterview => 'インタビュー';

  @override
  String get audioOutput => 'オーディオ出力';

  @override
  String get audioOutputSystemDefault => 'システムのデフォルト';

  @override
  String get vizRangeAuto => '自動';

  @override
  String get contextNotes => 'ノート';

  @override
  String get notePlacedBadge => 'コンペ入賞';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人のメンバー',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => '曲を表示';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count モジュール',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'パーティー';

  @override
  String get searchCategoryYear => '年';

  @override
  String get searchCategoryOrigin => '出典';

  @override
  String get searchCategoryProduction => 'プロダクション';

  @override
  String get searchCategoryProductionType => 'プロダクション種別';

  @override
  String get searchCategoryPublisher => 'パブリッシャー';

  @override
  String get searchCategoryDeveloper => '開発元';

  @override
  String get searchCategoryArcadeBoard => 'アーケード基板';

  @override
  String get searchCategorySaga => 'サーガ';

  @override
  String get searchCategoryGenre => 'ジャンル';

  @override
  String get searchViaArtist => 'アーティスト経由';

  @override
  String get searchViaAlbum => 'アルバム経由';

  @override
  String get searchViaSong => '曲経由';

  @override
  String get searchSortPopular => '人気';

  @override
  String get searchSortYear => '年';

  @override
  String get searchSortRandom => 'ランダム';

  @override
  String get searchSortRating => '評価';

  @override
  String statsTopPercent(int percent) {
    return '上位 $percent %';
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
  String get searchSortAsc => '昇順';

  @override
  String get searchSortDesc => '降順';

  @override
  String get searchFilters => 'フィルタ';

  @override
  String get searchExactSearch => '完全一致検索';

  @override
  String get searchExactSearchSubtitle => 'あいまい検索（fuzzy）を無効にします';

  @override
  String get searchTags => 'タグ';

  @override
  String searchTagSearchHint(String category) {
    return '「$category」内のタグを検索…';
  }

  @override
  String get searchTagTypeToSearch => '入力してタグを検索します。';

  @override
  String get searchTagsAndLogic => '複数のタグ = AND 条件。';

  @override
  String get searchFilterYear => '年';

  @override
  String get searchFilterAll => 'すべて';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote => '年で絞り込むと、年不明の曲は除外されます。';

  @override
  String get searchMinRating => '評価 ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'キャンセル';

  @override
  String get searchReset => 'リセット';

  @override
  String get searchApply => '適用';

  @override
  String get searchClearRecent => '最近の検索を消去';

  @override
  String get searchBrowse => 'ブラウズ';

  @override
  String get searchBrowseHint =>
      'ファセット（グループ、チップ、年…）を選んでカタログを探すか、上のラジオ／サプライズを開始してください。';

  @override
  String get searchDidYouMean => '結果が少なめです — あいまい検索を試しますか？';

  @override
  String get searchYes => 'はい';

  @override
  String get featuredCommunityTitle => 'コミュニティの新着';

  @override
  String get searchPlaylistSourceAll => 'すべて';

  @override
  String get searchPlaylistSourceUser => 'コミュニティ';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'フォーマット';

  @override
  String get searchPlatform => 'プラットフォーム';

  @override
  String get filterCollection => 'コレクション';

  @override
  String get videoWatchDemo => 'デモを見る';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'コレクション: $name';
  }

  @override
  String get searchCollectionAll => 'すべて';

  @override
  String get searchRadio => 'ラジオ';

  @override
  String get searchRadioTooltip => '現在のフィルタでランダムな再生キューを作成';

  @override
  String get searchSurprise => 'サプライズ';

  @override
  String get searchSurpriseTooltip => 'ランダムな 1 曲';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => '曲がありません';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 枚のアルバム',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return '別名 $name';
  }

  @override
  String get searchChooseCollection => 'コレクションを選択';

  @override
  String get searchFilterCollections => 'コレクションを絞り込み…';

  @override
  String get searchFilterPlaceholder => '絞り込み…';

  @override
  String searchAllOf(String label) {
    return 'すべて（$label）';
  }

  @override
  String get searchNoMatch => '一致なし';

  @override
  String get searchNoPlaylist => 'プレイリストがありません';

  @override
  String get engineDescOpenmpt => 'トラッカーモジュール（MOD/XM/S3M/IT/…）';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — サウンドチップ、チャンネル別スコープ';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN アーカイブ';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — チャンネル別ボイス';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID（reSIDfp エンジン）';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX チップチューン（KSS/MGS/BGM/MPK/MBM/OPX）';

  @override
  String get engineDescFurnace => 'マルチチップのチップチューン .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade => '68k エミュレーションによる Amiga カスタムチップ形式（約 320 拡張子）';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi => '標準 MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ シンセ（16 ボイス）';

  @override
  String get engineDescV2m => 'V2M シンセ (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — 実機同等の 68000 エミュレーション + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300 エミュレーション + RSP オーディオ';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ エミュレーション';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound チップ';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — 実機同等の AY-3-8910/YM2149 シンセ';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixel 純正エンジン';

  @override
  String get engineDescPxtone => 'Pixel のトラッカー — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — emu68 による実機同等の 68000';

  @override
  String get engineDescPmd =>
      'PC-98 の Professional Music Driver — OPNA FM + SSG + PPZ8 サンプル';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx（+ .pdx サンプル）、YM2151 FM';

  @override
  String get engineDescFmp => 'PC-98 の FMP ドライバ — OPNA + PPZ8（.opi/.ovi/.ozi）';

  @override
  String get engineDescEup => 'FM Towns の EUPHONY — YM2612 FM + PCM（.eup）';

  @override
  String get engineDescMac => 'ロスレス .ape';

  @override
  String get engineDescVgmstream => 'ゲームのストリーム音声フォーマット（700 以上、.rrds を含む）';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — フォールバックデコーダー';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total 曲',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total 枚のアルバム',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total アーティスト',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 枚のアルバム',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n アーティスト',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n グループ',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => '国';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n か国',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'フォルダー';

  @override
  String get featuredTitle => '今日の注目';

  @override
  String featuredPartyNow(String party) {
    return '$party が開催中 — 過去の大会の入賞作品';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party まであと $days 日 — 過去の大会の入賞作品',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series のシーズン — 過去の大会の入賞作品';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return '$year年$monthリリース';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age 年前: $year 年のゲーム',
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
      other: '$age 年前: $year 年のゲーム',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return '$monthにリリース';
  }

  @override
  String get featuredAnniversaryHeader => '記念日';

  @override
  String get featuredBirthdayHeader => '今日の誕生日';

  @override
  String get featuredBirthdayWeekHeader => '今週の誕生日';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '今週は$artistの誕生日';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'プレイリスト $count 件',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => '再試行';

  @override
  String get commonOptions => 'オプション';

  @override
  String get commonDownload => 'ダウンロード';

  @override
  String get commonDeleteDownload => 'ダウンロードを削除';

  @override
  String get commonAddToPlaylist => 'プレイリストに追加';

  @override
  String get commonPlayNext => '次に再生';

  @override
  String get commonAddToQueueEnd => 'キューの最後に追加';

  @override
  String get commonAddToFavorites => 'お気に入りに追加';

  @override
  String get commonRemoveFromFavorites => 'お気に入りから削除';

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
  String get subsongDeleteDownloadTitle => 'このダウンロードを削除しますか？';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'ファイルとローカルの記録（履歴、曲）が削除されます。\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => '曲を読み込めません';

  @override
  String subsongTrackNumber(int number) {
    return 'トラック $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count サブソング',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'すべて再生';

  @override
  String get albumDownloading => 'アルバムをダウンロード中…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'アルバムをダウンロード中…（$done/$total）';
  }

  @override
  String get albumDownloadToSeeTracks => 'アルバムをダウンロードすると曲が表示されます';

  @override
  String get albumNotDownloadedHint => 'アルバム未ダウンロード — 再生するとダウンロードされます';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => '詳細を読み込み中…';

  @override
  String albumAka(String label) {
    return '別名 $label';
  }

  @override
  String get albumPlayAlbum => 'アルバムを再生';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 項目',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst => '先に検索からこの曲を再生してダウンロードしてください';

  @override
  String get libraryAddedTrack => '曲をライブラリに追加しました';

  @override
  String get libraryAddedAlbum => 'アルバムをライブラリに追加しました';

  @override
  String get libraryAddedArtist => 'アーティストをライブラリに追加しました';

  @override
  String get libraryRemovedTrack => '曲をライブラリから削除しました';

  @override
  String get libraryRemovedAlbum => 'アルバムをライブラリから削除しました';

  @override
  String get libraryRemovedArtist => 'アーティストをライブラリから削除しました';

  @override
  String songTilePlayFailed(String message) {
    return '再生できません: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'ダウンロードできません — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'ダウンロード中 — $label';
  }

  @override
  String get downloadsTitle => 'ダウンロード';

  @override
  String get downloadsEmpty => '待機中のダウンロードはありません';

  @override
  String get downloadsPause => '一時停止';

  @override
  String get downloadsResume => '再開';

  @override
  String get downloadsCancel => 'ダウンロードを中止';

  @override
  String get downloadsClear => 'すべて削除';

  @override
  String get downloadsPausedBanner => 'ダウンロード一時停止中 — 現在のファイルは完了します';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'ダウンロード中 — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'プレイリスト';

  @override
  String get miniPlayerHideQueue => 'プレイリストを閉じる';

  @override
  String get transportShuffle => 'シャッフル';

  @override
  String get transportShuffleOn => 'シャッフル オン';

  @override
  String get transportLoopOff => 'リピート オフ';

  @override
  String get transportLoopQueue => 'リピート: キュー';

  @override
  String get transportLoopTrack => 'リピート: 現在の曲';

  @override
  String get vizStereo => 'ステレオ';

  @override
  String get vizSpectrum => 'スペクトラム';

  @override
  String get vizVoices => 'ボイス';

  @override
  String get vizNotes => 'ノート';

  @override
  String get vizPatterns => 'パターン';

  @override
  String get patternScrollMode => 'スクロールモード';

  @override
  String get patternSmoothScroll => 'スムーズスクロール';

  @override
  String get patternVolumeBars => '音量バー';

  @override
  String get patternColorScheme => 'カラースキーム';

  @override
  String get patternSize => 'サイズ';

  @override
  String get patternColumns => '列';

  @override
  String get patternColumnsAll => '完全';

  @override
  String get patternColumnsNoteInstr => '簡易';

  @override
  String get patternColumnsNote => '最小';

  @override
  String get vizClose => 'ビジュアライザを閉じる';

  @override
  String get vizFullscreen => 'フルスクリーン';

  @override
  String get vizExitFullscreen => 'フルスクリーンを終了';

  @override
  String get vizPrevPreset => '前のプリセット';

  @override
  String get vizNextPreset => '次のプリセット';

  @override
  String get vizProjectmUnavailable => 'projectM は利用できません';

  @override
  String get voicesTitle => 'ボイス';

  @override
  String get voicesNone => 'この曲にはボイスがありません。';

  @override
  String get voicesLongPressSolo => '長押し = ソロ';

  @override
  String get voicesMuteAll => 'すべてミュート';

  @override
  String get voicesUnmuteAll => 'すべて解除';

  @override
  String get voicesStereoOutput => 'ステレオ出力';

  @override
  String get voicesLeft => '左';

  @override
  String get voicesRight => '右';

  @override
  String get enginesFormatsTitle => '再生可能なフォーマット';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$engines 個の再生エンジンで $formats フォーマットに対応。';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count フォーマット',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return '$artist「$title」のカバー';
  }

  @override
  String stilCover(String work) {
    return '「$work」のカバー';
  }

  @override
  String get playerQueue => '再生キュー';

  @override
  String get queueEdit => '編集';

  @override
  String get queueEditDone => '完了';

  @override
  String get queueClear => 'キューを空にする';

  @override
  String get queueClearConfirmTitle => 'キューを空にしますか？';

  @override
  String get queueClearConfirmBody => 'キューが空になり、再生が停止します。';

  @override
  String get queueClearConfirm => '空にする';

  @override
  String get queueRemoveSelected => '選択項目を削除';

  @override
  String get queueRemoveTrack => 'キューから削除';

  @override
  String get queueReorder => '並べ替え';

  @override
  String get playerArtwork => 'アートワーク';

  @override
  String get playerVisualizer => 'ビジュアライザ';

  @override
  String get playerVoices => 'ボイス';

  @override
  String get playerTrackInfo => '曲の情報';

  @override
  String get playerShowQueue => 'プレイリスト';

  @override
  String get playerHideQueue => 'プレイリストを閉じる';

  @override
  String get playerNoTrackInfo => '情報がありません。';

  @override
  String get playerViewSubsongs => 'サブソングを表示';

  @override
  String get playerViewAlbum => 'アルバムを表示';

  @override
  String get playerViewArtist => 'アーティストを表示';

  @override
  String get playerAddToPlaylist => 'プレイリストに追加';

  @override
  String get queueAddToPlaylist => 'キューをプレイリストに追加';

  @override
  String get playerMoreOptions => 'その他のオプション';

  @override
  String get playerClose => '閉じる';

  @override
  String get playerCancel => 'キャンセル';

  @override
  String get playerDelete => '削除';

  @override
  String get playerAddFavorite => 'お気に入りに追加';

  @override
  String get playerRemoveFavorite => 'お気に入りから削除';

  @override
  String get playerAddToLibrary => 'ライブラリに追加';

  @override
  String get playerRemoveFromLibrary => 'ライブラリから削除';

  @override
  String get playerAddedToLibrary => '曲をライブラリに追加しました';

  @override
  String get playerRemovedFromLibrary => '曲をライブラリから削除しました';

  @override
  String get playerDeleteDownload => 'ダウンロードを削除';

  @override
  String get playerRedownload => 'ファイルを再ダウンロード';

  @override
  String get playerRedownloadUnavailable => 'このファイルは再ダウンロードできません';

  @override
  String get playerDeleteDownloadTitle => 'ダウンロードを削除しますか？';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'ファイルとローカルの記録（履歴、曲）が削除されます。\n\n$path';
  }

  @override
  String get homeYourTrends => 'あなたのトレンド';

  @override
  String get homeYourAllTimeTop => 'あなたの歴代トップ';

  @override
  String get homeTrending => 'トレンド';

  @override
  String get homeFeaturedPlaylists => '注目のプレイリスト';

  @override
  String get homeAllTimeTop => '歴代トップ';

  @override
  String get homePeriod7d => '7 日';

  @override
  String get homePeriod30d => '30 日';

  @override
  String get homePeriod90d => '90 日';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 回再生',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => '空、または読み込めないプレイリスト';

  @override
  String get homeExtractingArchive => 'アーカイブを展開中…';

  @override
  String get homeArchiveEmpty => 'アーカイブに再生可能なファイルがありません';

  @override
  String get homeNothingPlayable => '選択に再生できるものがありません';

  @override
  String get homeAlbumLoadFailed => 'このアルバムを読み込めません';

  @override
  String get homeSongLoadFailed => 'この曲を読み込めません';

  @override
  String get navStats => '統計';

  @override
  String get navSettings => '設定';

  @override
  String get playlistMoveUp => '親フォルダへ移動';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'プレイリスト$n件',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'サブフォルダ$n件',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader => 'このフォルダとその中身がすべて完全に削除されます:';

  @override
  String get playlistDeleteFolderEmptyBody => 'このフォルダが削除されます。';

  @override
  String get playlistFolderRoot => 'ルート';

  @override
  String get playlistMoveToFolder => 'フォルダへ移動';

  @override
  String playlistDeleteTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get playlistDeleteBody => 'このプレイリストは完全に削除されます。';

  @override
  String get playlistRenameFolderTitle => 'フォルダ名を変更';

  @override
  String get playlistClearFavorites => 'お気に入りをすべて削除';

  @override
  String get playlistClearFavoritesTitle => 'お気に入りをすべて削除しますか？';

  @override
  String get playlistClearFavoritesBody => 'お気に入りの曲がすべて失われます。この操作は取り消せません。';

  @override
  String get playlistRemoveFromLibrary => 'ライブラリから削除';

  @override
  String get playlistServerReadOnly => 'サーバーのプレイリスト · 読み取り専用';

  @override
  String get navAbout => 'このアプリについて';

  @override
  String get navMore => 'その他';

  @override
  String get shellAlbumQueuedAtEnd => 'アルバムをキューの最後に追加しました';

  @override
  String get shellAlbumQueuedNext => 'アルバムを次に再生します';

  @override
  String get shellAddingToQueue => 'キューに追加中…';

  @override
  String get shellAddingNext => '次に再生に追加中…';

  @override
  String shellDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 曲をキューに追加しました',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '「$title」をキューの最後に追加しました';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '「$title」を次に再生します';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'ダウンロードできません: $title — 次の曲へスキップします';
  }

  @override
  String get shellNetworkUnavailable => '再生を停止しました: ネットワークに接続できないようです。';

  @override
  String get statsTitle => '統計';

  @override
  String statsPeriodDays(int n) {
    return '$n 日間';
  }

  @override
  String get statsPeriodThisYear => '今年';

  @override
  String get statsPeriodAll => '全期間';

  @override
  String get statsByMonthOrYear => '月／年で見る…';

  @override
  String get statsByYear => '年別';

  @override
  String get statsByMonth => '月別';

  @override
  String get statsPlaysLabel => '再生';

  @override
  String get statsTracksLabel => '曲';

  @override
  String get statsArtistsLabel => 'アーティスト';

  @override
  String get statsAlbumsLabel => 'アルバム';

  @override
  String get statsListenTime => '再生時間';

  @override
  String get statsByCollection => 'コレクション別';

  @override
  String get statsByFormat => 'フォーマット別';

  @override
  String get statsByEngine => 'エンジン別';

  @override
  String get statsPlaylistsLabel => 'プレイリスト';

  @override
  String get statsLocalFilesSection => 'ダウンロード済みファイル';

  @override
  String get statsFilesLabel => 'ファイル';

  @override
  String get statsSpaceLabel => 'ディスク使用量';

  @override
  String get statsNoPlaysInPeriod => 'この期間の再生はありません';

  @override
  String get statsNoPlays => '再生履歴なし';

  @override
  String get statsTopTracks => 'トップ曲';

  @override
  String get statsTopAlbums => 'トップアルバム';

  @override
  String get statsTopArtists => 'トップアーティスト';

  @override
  String statsTopTracksIn(String period) {
    return 'トップ曲 — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'トップアルバム — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'トップアーティスト — $period';
  }

  @override
  String get statsSeeAll => 'すべて表示';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 回再生',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return '最大 $n';
  }

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonCreate => '作成';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => '削除';

  @override
  String get commonRename => '名前を変更';

  @override
  String get commonSort => '並べ替え';

  @override
  String get commonPlayAll => 'すべて再生';

  @override
  String get sortName => '名前';

  @override
  String get sortTitle => 'タイトル';

  @override
  String get sortArtist => 'アーティスト';

  @override
  String get sortAlbum => 'アルバム';

  @override
  String get sortDateAdded => '追加日';

  @override
  String get commonClear => 'クリア';

  @override
  String get sortRecentlyModified => '最近更新した順';

  @override
  String get sortCreationDate => '作成日';

  @override
  String get playlistNameHint => '名前';

  @override
  String get playlistNew => '新規プレイリスト';

  @override
  String get playlistNewFolder => '新規フォルダ';

  @override
  String get playlistNewTooltip => '新規プレイリスト／フォルダ';

  @override
  String get playlistAddTo => 'プレイリストに追加';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 件のプレイリストに追加',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'プレイリストを選択してください';

  @override
  String get playlistFilterHint => 'プレイリストを絞り込み…';

  @override
  String get playlistSearchHint => 'プレイリストを検索…';

  @override
  String get playlistNoMatch => '一致するプレイリストがありません';

  @override
  String get playlistNoneCreateHint => 'プレイリストがありません — ＋ で作成できます';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'すでに追加済み';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 件は選択したプレイリストにすでに含まれています。',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => '重複をスキップ';

  @override
  String get playlistAddAgain => 'もう一度追加';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m 件のプレイリスト',
    );
    return '$_temp0を$_temp1に追加しました';
  }

  @override
  String playlistAddFailed(String error) {
    return '追加できません: $error';
  }

  @override
  String get playlistRenameTitle => 'プレイリストの名前を変更';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'フォルダ「$name」を削除しますか？';
  }

  @override
  String get playlistDeleteFolderBody => '中身は 1 つ上の階層に移動します。';

  @override
  String get playlistEmpty => '空のプレイリスト';

  @override
  String get playlistRemoveEntry => 'プレイリストから削除';

  @override
  String get trackOptionsAddToLibrary => 'ライブラリに追加';

  @override
  String get trackOptionsRemoveFromLibrary => 'ライブラリから削除';

  @override
  String get trackOptionsAddedToLibrary => '曲をライブラリに追加しました';

  @override
  String get trackOptionsRemovedFromLibrary => '曲をライブラリから削除しました';

  @override
  String get trackOptionsViewAlbum => 'アルバムを表示';

  @override
  String get trackOptionsViewArtist => 'アーティストを表示';

  @override
  String get trackOptionsPlayNow => '今すぐ再生';

  @override
  String get trackOptionsPlayNext => '次に再生';

  @override
  String get trackOptionsAddToQueueEnd => 'キューの最後に追加';

  @override
  String get trackOptionsPlayLast => '最後に再生';

  @override
  String get trackOptionsDeleteDownload => 'ダウンロードを削除';

  @override
  String get trackOptionsDeleteDownloadTitle => 'このダウンロードを削除しますか？';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'ファイルとローカルの記録（履歴、曲）が削除されます。\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'ダウンロードを削除しました';

  @override
  String get trackOptionsAddToFavorites => 'お気に入りに追加';

  @override
  String get trackOptionsRemoveFromFavorites => 'お気に入りから削除';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'アルバムをお気に入りに追加しました';

  @override
  String get trackOptionsAlbumRemovedFromFavorites => 'アルバムをお気に入りから削除しました';

  @override
  String get trackOptionsAlbumNotDownloaded => 'アルバム未ダウンロード — 削除するものがありません';

  @override
  String get trackOptionsDeleteAlbumTitle => 'ダウンロードしたアルバムを削除しますか？';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'フォルダとローカルの記録（曲、履歴）がすべて削除されます。\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'アルバムをローカルから削除しました';

  @override
  String get trackOptionsRedownloadAlbum => 'アルバムを再ダウンロード';

  @override
  String get trackOptionsRedownloadAlbumSubtitle => 'ファイルとローカルの記録を上書きします';

  @override
  String get trackOptionsDeleteAlbumFiles => 'アルバムのファイルを削除';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'ダウンロードしたフォルダ + ローカルの記録（履歴）';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsGeneralSubtitle => 'テーマ';

  @override
  String get settingsVisualisation => 'ビジュアライザ';

  @override
  String get settingsVisualisationSubtitle => 'オシロスコープ、アートワーク背景';

  @override
  String get settingsPlayback => '再生';

  @override
  String get settingsPlaybackSubtitle => 'ループ、フェードアウト、無音';

  @override
  String get settingsEngines => 'エンジン';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsDataSubtitle => 'ID、履歴、リセット';

  @override
  String get settingsBackupExport => 'バックアップを書き出す';

  @override
  String get settingsBackupExportSubtitle => 'ライブラリ・プレイリスト・設定をファイルに保存';

  @override
  String get settingsBackupImport => 'バックアップを読み込む';

  @override
  String get settingsBackupImportSubtitle => 'バックアップファイルからデータを復元';

  @override
  String get settingsBackupExportFailed => 'バックアップの書き出しに失敗しました';

  @override
  String get settingsBackupImportConfirmTitle => 'バックアップを読み込みますか？';

  @override
  String get settingsBackupImportConfirmBody =>
      'この端末のライブラリ・プレイリスト・設定を置き換えます。ダウンロード済みファイルは保持されます。';

  @override
  String get settingsBackupImportConfirm => '読み込む';

  @override
  String get settingsBackupImportedTitle => 'バックアップを読み込みました';

  @override
  String get settingsBackupImportedBody => 'データを復元しました。すべて反映するにはアプリを再起動してください。';

  @override
  String get settingsBackupTooNew => 'このバックアップは新しいバージョンのアプリで作成されています';

  @override
  String get settingsBackupInvalid => '有効な Rewamp バックアップではありません';

  @override
  String get settingsBackupImportFailed => 'バックアップの読み込みに失敗しました';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get settingsAboutSubtitle => 'クレジットとライセンス';

  @override
  String get settingsCreditsSubtitle => 'ライブラリ・データ・コンポーネント';

  @override
  String get settingsSupport => 'お問い合わせとサポート';

  @override
  String get settingsSupportSubtitle => 'お問い合わせ、ウェブサイト';

  @override
  String get settingsSupportEmail => 'メールを送る';

  @override
  String get settingsSupportEmailSubtitle => '質問・不具合・提案';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — サポート';

  @override
  String get settingsSupportEmailIntro =>
      '上に質問・不具合・ご提案をご記入ください。以下の情報はサポートに役立ちます。';

  @override
  String get settingsSupportWebsite => 'ウェブサイト';

  @override
  String get settingsDonation => 'Rewamp を応援';

  @override
  String get settingsDonationSubtitle => 'よろしければ、チップを';

  @override
  String get settingsDonationBlurb =>
      'Rewamp は無料・広告なし——デモシーンとレトロ文化の保存に捧げる情熱のプロジェクトです。寄付はアプリの開発資金とデータベースのホスティング費用に充てられます。義務ではありません。アプリを気に入っていただけたら、ささやかなご支援はいつでも歓迎です。';

  @override
  String get settingsDonationFloppy => 'フロッピーディスク';

  @override
  String get settingsDonationCartridge => 'カートリッジ';

  @override
  String get settingsDonationBox => '箱入りゲーム';

  @override
  String get settingsDonationCustom => '金額を選ぶ';

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => '削除';

  @override
  String get settingsReset => 'リセット';

  @override
  String get settingsRenew => '再発行';

  @override
  String get settingsOff => 'オフ';

  @override
  String get settingsOn => 'オン';

  @override
  String get settingsAuto => '自動';

  @override
  String get settingsInfinite => '無限';

  @override
  String get settingsDefault => 'デフォルト';

  @override
  String get settingsCoreNoScope => 'オシロスコープなし';

  @override
  String get settingsNone => 'なし';

  @override
  String get settingsLevelLow => '低';

  @override
  String get settingsLevelHigh => '高';

  @override
  String get settingsStereo => 'ステレオ';

  @override
  String get settingsSurround => 'サラウンド';

  @override
  String settingsValuePercent(int value) {
    return '$value%';
  }

  @override
  String settingsValueSeconds(int value) {
    return '$value 秒';
  }

  @override
  String settingsValueSecondsFrac(String value) {
    return '$value 秒';
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
  String get settingsTheme => 'テーマ';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsArtworkTintTitle => 'アートワークでプレイヤーを色付け';

  @override
  String get settingsArtworkTintSubtitle => 'カバーアートの主要な色をプレイヤーに反映します';

  @override
  String get settingsGlassEffectTitle => 'リキッドグラス効果';

  @override
  String get settingsGlassEffectSubtitle => '下部バーのレンズとぼかし — 動作が遅い端末ではオフに';

  @override
  String get settingsResetSection => 'このセクションをリセット';

  @override
  String get settingsResetEngine => 'このエンジンをリセット';

  @override
  String get settingsResetChoices => 'これらの選択をリセット';

  @override
  String get settingsResetToDefault => 'デフォルト値';

  @override
  String get settingsStartInVizTitle => 'ビジュアライザモードで開始';

  @override
  String get settingsStartInVizSubtitle => 'プレイヤーがアートワークではなくオシロスコープで開きます';

  @override
  String get settingsVoiceGridTitle => 'ボイス オシロスコープのグリッド';

  @override
  String get settingsVoiceGridSubtitle => '各ボイスを区切る枠線を表示します';

  @override
  String get settingsKeepAwakeTitle => '画面をオンのままにする';

  @override
  String get settingsKeepAwakeSubtitle => 'ビジュアライザーの表示中は画面が暗くならず、ロックもされません';

  @override
  String get settingsVoiceNamesTitle => 'ボイス名';

  @override
  String get settingsVoiceNamesSubtitle => '各ボイスの名前を枠内に表示します';

  @override
  String get settingsLineThickness => '線の太さ';

  @override
  String get settingsColors => 'カラー';

  @override
  String get settingsScopeVoiceColor => 'ボイス オシロスコープ';

  @override
  String get settingsStereoColors => 'ステレオ: カラー';

  @override
  String get settingsStereoMono => 'モノ';

  @override
  String get settingsStereoBi => 'バイ';

  @override
  String get settingsStereoMonoColor => 'ステレオ（モノ）';

  @override
  String get settingsStereoLeftColor => 'ステレオ 左';

  @override
  String get settingsStereoRightColor => 'ステレオ 右';

  @override
  String get settingsNotation => 'ノート表示';

  @override
  String get settingsNotePalette => 'カラーパレット';

  @override
  String get settingsNoteBoxStyle => 'ブロックのスタイル';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'CRT エフェクト';

  @override
  String get settingsCrtGlow => 'グロー';

  @override
  String get settingsCrtSpeed => '強さ / 速さ';

  @override
  String get settingsArtworkOpacity => '背景アートワークの不透明度';

  @override
  String get settingsProjectMTitle => 'projectM の設定';

  @override
  String get settingsProjectMSubtitle => 'プリセット、トランジション、画質、Mesh…';

  @override
  String get settingsNotifyTrackTitle => '曲変更時の通知';

  @override
  String get settingsNotifyTrackSubtitle => '新しい曲のタイトルを通知します';

  @override
  String get settingsSilenceDetection => '無音検出';

  @override
  String get settingsSilenceSkipTitle => '無音になったら次の曲へスキップ';

  @override
  String get settingsSilenceSkipSubtitle => '出力が無音のままなら自動的に次へ進みます';

  @override
  String get settingsSilenceDelay => '無音の待ち時間';

  @override
  String get settingsDefaultDuration => 'デフォルトの長さ';

  @override
  String get settingsDefaultDurationHelp =>
      '曲の長さが不明な場合（タグもサーバーのメタデータもない場合）に適用され、無限に再生・ループするのを防ぎます。独自の songlength データベースを持つ Amiga（UADE）の曲には適用されません。';

  @override
  String get settingsForcedLoopHeader => '強制ループ / フェードアウト';

  @override
  String get settingsForcedLoopHelp =>
      '特定の区間をループするフォーマット（VGM、トラッカーモジュールなど）もあれば、そうでないものもあります。「無限」は曲本来の終わりを無視します。';

  @override
  String get settingsForceLoopCount => 'ループ回数を強制する';

  @override
  String get settingsLoopCount => 'ループ回数';

  @override
  String get settingsForceFadeout => 'フェードアウトを強制する';

  @override
  String get settingsFadeoutDuration => 'フェードの長さ';

  @override
  String get settingsResetEnginesTitle => 'エンジン設定をリセットしますか？';

  @override
  String get settingsResetEnginesBody => 'すべてのエンジン設定がデフォルト値に戻ります。';

  @override
  String get settingsResetDefaultsTitle => 'デフォルト値にリセット';

  @override
  String get settingsResetDefaultsSubtitle => 'すべてのエンジン';

  @override
  String get settingsDefaultDecoders => 'デフォルトのデコーダー';

  @override
  String get settingsDefaultDecodersSubtitle => '複数のエンジンで再生できるフォーマット';

  @override
  String get settingsDecodersHelp =>
      '一部のフォーマットは複数のエンジンで再生できます。デフォルトで使うエンジンを選んでください。他のフォーマットは自動で振り分けられます。';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga トラッカー（mod, med, okt…）';

  @override
  String get settingsEngineOpenmptSubtitle => 'トラッカー — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle => 'SPC, VGM(gme), KSS, AY… — EQ、ステレオ';

  @override
  String get settingsEngineNsfSubtitle => 'NES / NSF — 品質、フィルタ、チップ別オプション';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — ハイパスフィルタ';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — 使用中の SoundFont';

  @override
  String get settingsEngineGsfSubtitle => 'GBA / GSF — 補間、ローパス、エコー';

  @override
  String get settingsEngineUadeSubtitle => 'Amiga — パンニング、ヘッドフォン、ゲイン、LED';

  @override
  String get settingsEngineSidSubtitle => 'C64 / SID — クロック、モデル、ReSIDfp フィルタ';

  @override
  String get settingsEngineAdplugSubtitle => 'AdLib OPL — ステレオ/サラウンドの倍音モード';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU、リバーブ';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612、OPL3、QSound コア…';

  @override
  String get settingsMasterVolume => 'マスター音量';

  @override
  String get settingsAmigaFilter => 'Amiga フィルタ';

  @override
  String get settingsInterpolation => '補間';

  @override
  String get settingsPolyphony => 'ポリフォニー';

  @override
  String get settingsReverb => 'リバーブ';

  @override
  String get settingsChorus => 'コーラス';

  @override
  String get settingsInterpNone => 'なし';

  @override
  String get settingsInterpLinear => 'リニア';

  @override
  String get settingsInterpCubic => 'キュービック';

  @override
  String get settingsInterpSinc => 'Sinc（最高品質）';

  @override
  String get settingsStereoSeparation => 'ステレオ分離';

  @override
  String get settingsGmeSilenceSubtitle => 'エンジンが長い無音を検出したら曲を終了します';

  @override
  String get settingsStereoDepth => 'ステレオの深さ';

  @override
  String get settingsEqualizer => 'イコライザ';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — SPC には影響しません';

  @override
  String get settingsBass => '低音';

  @override
  String get settingsTreble => '高音';

  @override
  String get settingsAppliedLive => '再生中でもすぐに適用されます。';

  @override
  String get settingsAppliedNextTrack => '次に読み込む曲から適用されます。';

  @override
  String get settingsSidEmulation => 'エミュレーション';

  @override
  String get settingsSidResidfp => 'ReSIDfp（高精度）';

  @override
  String get settingsSidLite => 'SIDLite（高速）';

  @override
  String get settingsSidSampling => 'サンプリング';

  @override
  String get settingsSidSamplingInterp => '補間（高速）';

  @override
  String get settingsSidSamplingResample => 'Resample（最高品質）';

  @override
  String get settingsSidClock => 'クロック';

  @override
  String get settingsSidModel => 'SID モデル';

  @override
  String get settingsSidFilter => 'SID フィルタ';

  @override
  String get settingsSidForceSecond => '2 個目の SID を強制';

  @override
  String get settingsSidSecondSubtitle => 'ステレオ 2SID の曲';

  @override
  String get settingsSidSecondAddr => '2 個目の SID のアドレス';

  @override
  String get settingsSidForceThird => '3 個目の SID を強制';

  @override
  String get settingsSidThirdAddr => '3 個目の SID のアドレス';

  @override
  String get settingsSidAutoFilter => '6581 フィルタ範囲を自動';

  @override
  String get settingsSidAutoFilterSubtitle => '曲の作者に応じた推奨値（sidplayfp のテーブル）';

  @override
  String get settingsSid6581Range => '6581 フィルタ範囲';

  @override
  String get settingsSid6581Curve => '6581 フィルタカーブ';

  @override
  String get settingsSid8580Curve => '8580 フィルタカーブ';

  @override
  String get settingsSidNote =>
      'SID フィルタとカーブは即時に適用されます。エミュレーション／サンプリング／クロック／モデル／2・3 個目の SID は次の曲から有効になります。';

  @override
  String get settingsAudioOutput => 'オーディオ出力';

  @override
  String get settingsAdplugNote =>
      'サラウンド: わずかにデチューンした 2 つの OPL チップ。次の曲から適用されます。';

  @override
  String get settingsHeSpuMain => 'メインボイス (SPU)';

  @override
  String get settingsHeSpuReverb => 'リバーブ (SPU)';

  @override
  String get settingsNsfQuality => '品質 (nsfplay)';

  @override
  String get settingsLowpassFilter => 'ローパスフィルタ';

  @override
  String get settingsHighpassFilter => 'ハイパスフィルタ';

  @override
  String get settingsRegion => 'リージョン';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC 強制';

  @override
  String get settingsNsfRegionPalForced => 'PAL 強制';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy 強制';

  @override
  String get settingsNsfForceIrq => 'IRQ を強制';

  @override
  String get settingsNsfApu1Title => '2A03 — パルス (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — 三角波 / ノイズ / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'リセット時にミュート解除';

  @override
  String get settingsNsfPhaseRefresh => '位相をリフレッシュ';

  @override
  String get settingsNsfPhaseRefreshSubtitle => '周期の書き込み時に位相をリセットします';

  @override
  String get settingsNsfNonlinearMixer => '非線形ミキシング';

  @override
  String get settingsNsfApu1NonlinearSubtitle => '2A03 実機のミックス（オフなら線形）';

  @override
  String get settingsNsfDutySwap => 'デューティ比を入れ替え';

  @override
  String get settingsNsfDutySwapSubtitle => '25% / 50% デューティの順序';

  @override
  String get settingsNsfNegateSweep => '初期化時にネガティブスイープ';

  @override
  String get settingsNsfEnable4011 => 'レジスタ \$4011 を有効化';

  @override
  String get settingsNsfEnable4011Subtitle => 'DAC 直接出力（実機のクリックノイズ）';

  @override
  String get settingsNsfPeriodicNoise => '周期ノイズ';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => 'ノイズジェネレーターのショートモード';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM アンチクリック';

  @override
  String get settingsNsfRandomizeNoise => '初期化時にノイズをランダム化';

  @override
  String get settingsNsfTriangleMute => '三角波をミュート';

  @override
  String get settingsNsfTriangleMuteSubtitle => '超音波域の周期で三角波を無音にします';

  @override
  String get settingsNsfRandomizeTri => '初期化時に三角波をランダム化';

  @override
  String get settingsNsfDpcmReverse => 'DPCM を反転';

  @override
  String get settingsNsfN163Serial => 'シリアル多重化';

  @override
  String get settingsNsfN163SerialSubtitle => '多ボイス曲で鳴る N163 実機のノイズ';

  @override
  String get settingsNsfN163PhaseReadOnly => '位相を読み取り専用に';

  @override
  String get settingsNsfN163LimitWavelength => '波長を制限';

  @override
  String get settingsNsfFdsCutoff => 'ローパスのカットオフ';

  @override
  String get settingsNsfFds4085Reset => '\$4085 リセット';

  @override
  String get settingsNsfFdsWriteProtect => '書き込み保護';

  @override
  String get settingsNsfVrc7Patch => 'パッチセット';

  @override
  String get settingsNsfVrc7Opll => 'OPLL モード';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'VRC7 の代わりに YM2413 をエミュレートします';

  @override
  String get settingsGbsHpFilter => 'ハイパスフィルタ (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG（クラシック GB）';

  @override
  String get settingsGbsFilterCgb => 'CGB（GB Color）';

  @override
  String get settingsEcho => 'エコー';

  @override
  String get settingsUadePostfx => 'ポストプロセッシング';

  @override
  String get settingsUadePostfxSubtitle => 'エフェクトチェーンを有効にします（以下のすべてに必要）';

  @override
  String get settingsUadePan => 'パンニング（ステレオ分離）';

  @override
  String get settingsUadePanValue => 'パンニング量';

  @override
  String get settingsUadeHeadphones => 'ヘッドフォン';

  @override
  String get settingsUadeLed => 'LED（Paula フィルタ）';

  @override
  String get settingsUadeLedAuto => '自動（曲ごと）';

  @override
  String get settingsUadeLedOn => '強制 ON';

  @override
  String get settingsUadeLedOff => '強制 OFF';

  @override
  String get settingsUadeFilterType => 'フィルタの種類';

  @override
  String get settingsUadeGain => 'ゲイン';

  @override
  String get settingsUadeGainValue => 'ゲイン量';

  @override
  String get settingsSoundfontLoading => 'カタログを読み込み中…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'カタログを取得できません（$error）';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String get settingsSoundfontImport => 'SoundFont を読み込む…';

  @override
  String get settingsSoundfontImportSubtitle => 'この端末の .sf2 ファイルを選ぶ';

  @override
  String get settingsSoundfontImported => '読み込み済み';

  @override
  String get settingsSoundfontInvalid => 'このファイルは SoundFont (.sf2) ではありません';

  @override
  String settingsSoundfontImportFailed(String error) {
    return '読み込みに失敗しました — $error';
  }

  @override
  String get settingsSoundfontDelete => 'ファイルを削除';

  @override
  String get settingsCreditsHeader => 'クレジット & ライセンス';

  @override
  String get settingsRightsNotice =>
      'Rewamp は再生ソフトです。ファイルを保管することも、音楽を配布することもありません。楽曲はオンラインの保存アーカイブに由来し、権利は各権利者に帰属します。再生・ダウンロード・保存が適用される権利および居住国の法令に適合しているかを確認する責任は利用者にあります。';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count フォーマットに対応',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の再生エンジンに分散 — 詳細を見る',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga の songlength & メタデータ';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb by Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID のデータ & カバーアート';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — C64 ゲームのメタデータとビジュアル。';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 フォント';

  @override
  String get settingsFt2FontSubtitle =>
      'パターンビジュアライザーの FastTracker II スタイルは、8bitbubsy の ft2-clone (16-bits.org) の FT2 ビットマップフォントを使用しています。';

  @override
  String settingsLinkCopied(String url) {
    return '$url をコピーしました';
  }

  @override
  String get settingsOpenLink => 'リンクを開く';

  @override
  String get settingsEnginesHeader => '再生エンジン';

  @override
  String get settingsComponentsHeader => 'その他のコンポーネント';

  @override
  String get settingsResetAll => 'すべての設定をリセット';

  @override
  String get settingsResetAllSubtitle => '一般、ビジュアライザ、再生、エンジン — ライブラリは対象外';

  @override
  String get settingsResetAllTitle => 'すべての設定をリセットしますか？';

  @override
  String get settingsResetAllBody =>
      '一般、ビジュアライザ、再生、すべてのエンジンがデフォルト値に戻ります。ライブラリと履歴はそのままです。';

  @override
  String get settingsRenewUserId => '匿名 ID を再発行';

  @override
  String get settingsRenewUserIdTitle => '匿名 ID を再発行しますか？';

  @override
  String get settingsRenewUserIdBody =>
      'サーバー統計用に新しい匿名 ID が作成されます。\n\n古い ID は使用されなくなります。ローカルの履歴とお気に入りには影響しません。';

  @override
  String get settingsRenewUserIdFailed => '失敗 — サーバーに接続できません';

  @override
  String settingsNewUserId(String id) {
    return '新しい ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'ID が登録されていません';

  @override
  String get settingsCleanDb => 'ローカルデータベースを整理';

  @override
  String get settingsCleanDbSubtitle =>
      'ファイルが存在しないエントリーを削除します（削除済みのダウンロード、古いエラー）';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の孤立エントリーを削除しました',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'ローカルデータベースは正常です — 整理は不要です';

  @override
  String get settingsClearCache => 'キャッシュを消去（アートワーク & メタデータ）';

  @override
  String get settingsClearCacheSubtitle =>
      'キャッシュしたカバーアートと取得済みメタデータ（STIL、songlength）を削除します — 次回の再生時に再ダウンロードされます';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'キャッシュを消去しました（カバーアート $count 件）',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => '統計をリセット';

  @override
  String get settingsResetStatsSubtitle => '再生履歴と再生回数を削除します';

  @override
  String get settingsClearStatsTitle => '統計をリセットしますか？';

  @override
  String get settingsClearStatsBody =>
      '次の項目が完全に削除されます:\n• すべての再生履歴\n• 再生回数\n\nお気に入りとライブラリには影響しません。';

  @override
  String get settingsStatsCleared => '統計を削除しました';

  @override
  String get settingsResetDatabase => 'データベースをリセット';

  @override
  String get settingsResetDatabaseSubtitle => 'すべて削除します: 履歴、お気に入り、プレイリスト、キャッシュ';

  @override
  String get settingsResetDbTitle => 'データベースをリセットしますか？';

  @override
  String get settingsResetDbBody =>
      '次の項目が完全に削除されます:\n• すべての再生履歴\n• すべてのカウンター\n• すべてのお気に入り\n• すべてのプレイリスト\n• キャッシュしたすべてのメタデータ\n\nオーディオファイルは削除されません。';

  @override
  String get settingsDbReset => 'データベースをリセットしました';

  @override
  String get settingsDeleteDownloads => 'ダウンロードを削除';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'online フォルダのすべてのファイル（曲、アートワーク）を削除します';

  @override
  String get settingsDeleteDownloadsTitle => 'ダウンロードを削除しますか？';

  @override
  String get settingsDeleteDownloadsBody =>
      'online フォルダにダウンロードしたすべてのファイル（曲、アルバム、アートワーク）が完全に削除されます。\n\nデータベースのエントリーは残りますが、存在しないファイルを指すことになります。';

  @override
  String get settingsDownloadsDeleted => 'ダウンロードを削除しました';

  @override
  String get settingsColor => 'カラー';

  @override
  String get settingsPmPresets => 'プリセット';

  @override
  String get settingsPmRandomNext => '次のプリセットをランダムに';

  @override
  String get settingsPmRandomNextSubtitle => 'オフ: プリセットを順番に再生します';

  @override
  String get settingsPmLockPreset => 'プリセットを固定';

  @override
  String get settingsPmLockPresetSubtitle => '自動で切り替えません';

  @override
  String get settingsPmPresetDuration => 'プリセットの切り替え間隔';

  @override
  String get settingsPmTransitions => 'トランジション';

  @override
  String get settingsPmBlend => 'クロスフェード トランジション';

  @override
  String get settingsPmBlendSubtitle => 'オフ: プリセットを即座に切り替えます';

  @override
  String get settingsPmTransitionStyle => 'トランジションのスタイル';

  @override
  String get settingsPmTransitionStyleSubtitle => 'ブレンドで使用するパターン';

  @override
  String get settingsPmTransitionRandom => 'ランダム';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => 'ビートに同期してプリセットを切り替えます';

  @override
  String get settingsPmHardcutTime => 'Hardcut: 最小間隔';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: 感度';

  @override
  String get settingsPmRendering => 'レンダリング';

  @override
  String get settingsPmQuality => '画質';

  @override
  String get settingsPmQualitySubtitle => '描画解像度（Max = ネイティブ解像度）';

  @override
  String get settingsPmBeatSensitivity => 'ビート感度';

  @override
  String get settingsPmAspectRatio => 'アスペクト比を維持';

  @override
  String get settingsPmAspectRatioSubtitle => '対応するシェーダーのみ';

  @override
  String get settingsPmPermissive => '寛容モード';

  @override
  String get settingsPmPermissiveSubtitle => 'スクリプトエラーのある .milk ファイルも読み込みます';

  @override
  String get accountTitle => 'アカウント';

  @override
  String get accountSubtitle => 'ライブラリの保存と同期';

  @override
  String get accountAnonymous => '匿名アカウント';

  @override
  String get accountAnonymousExplain =>
      'お気に入りと再生履歴はサーバーに保存されていますが、このデバイスからしか利用できません。メールアドレスを登録すると、他の端末でも取り戻せます。';

  @override
  String get accountEmailAttached => 'アドレスを確認済み — このアカウントは復元できます';

  @override
  String get accountEmailPending => 'アドレスは未確認です';

  @override
  String get accountInsecureStorage =>
      'このデバイスの安全な保管領域が使えません。アカウント識別子は暗号化されずに保存されています。';

  @override
  String get accountSaveCta => 'アカウントを保存';

  @override
  String get accountStatSongs => 'お気に入りの曲';

  @override
  String get accountStatAlbums => 'お気に入りのアルバム';

  @override
  String get accountStatPlays => '再生回数';

  @override
  String get accountCreatedLabel => '作成日';

  @override
  String get accountSignOut => 'ログアウト';

  @override
  String get accountRevoke => 'すべての端末からログアウト';

  @override
  String get accountRevokeSubtitle => 'ほかの端末をすべてログアウトします';

  @override
  String get accountRevokeBody => 'ほかの端末はすべてログアウトされます。この端末は接続されたままです。';

  @override
  String get accountRevokeDone => 'ほかの端末をログアウトしました';

  @override
  String get accountDelete => 'アカウントを削除';

  @override
  String get accountDeleteSubtitle => 'サーバー上のアカウントとデータを消去します。取り消せません。';

  @override
  String accountDeleteBody(int items, int lists) {
    return 'サーバーからお気に入り $items 件とプレイリスト $lists 件を削除します。取り消せません。';
  }

  @override
  String get accountDeleteKeepsLocal => 'ダウンロード済みのファイルとこの端末のライブラリは影響を受けません。';

  @override
  String get accountDeleteDone => 'アカウントを削除しました';

  @override
  String get accountSignOutSubtitle => 'このデバイスは新しい空のアカウントで始まります';

  @override
  String get accountSignOutTitle => 'ログアウトしますか？';

  @override
  String accountSignOutBody(String email) {
    return '$email に送られるコードでこのアカウントに戻れます。';
  }

  @override
  String get accountSignedOut => 'ログアウトしました';

  @override
  String get accountNoSignOut => 'ログアウトは利用できません';

  @override
  String get accountNoSignOutSubtitle => 'メールアドレスがないと、このアカウントは二度と復元できません。';

  @override
  String get accountDetach => 'アドレスの連携を解除';

  @override
  String get accountDetachSubtitle => 'アカウントは匿名に戻ります。データは削除されません';

  @override
  String get accountDetachBody => 'アドレスがないと、このアカウントは他の端末から復元できなくなります。';

  @override
  String get accountDetachDone => 'アドレスの連携を解除しました';

  @override
  String get accountOffline => 'オフラインではアカウントを利用できません';

  @override
  String get accountEmailTitle => 'メールアドレス';

  @override
  String get accountEmailExplain => 'アドレス確認のため6桁のコードを送信します。アカウントの復元にのみ使用します。';

  @override
  String get accountEmailLabel => 'メールアドレス';

  @override
  String get accountCodeTitle => '確認コード';

  @override
  String accountCodeExplain(String email) {
    return '$email にコードを送信しました。有効期限は10分です。';
  }

  @override
  String get accountCodeLabel => '6桁のコード';

  @override
  String get accountSendCode => 'コードを送信';

  @override
  String get accountVerify => '確認';

  @override
  String get accountResend => 'コードを再送信';

  @override
  String accountResendIn(int n) {
    return '再送信まで $n 秒';
  }

  @override
  String get accountCheckSpam => 'メールの到着に1分ほどかかることがあります。迷惑メールフォルダーもご確認ください。';

  @override
  String get accountErrorInvalidEmail => 'アドレスが正しくありません';

  @override
  String get accountErrorTooMany => 'リクエストが多すぎます。数分後にお試しください';

  @override
  String get accountErrorInvalidCode => 'コードが違うか期限切れです';

  @override
  String get accountErrorCodeLength => 'コードは6桁です';

  @override
  String get accountErrorNetwork => '接続できませんでした。もう一度お試しください';

  @override
  String get accountMergeTitle => 'このライブラリを統合しますか？';

  @override
  String accountMergeBody(String email) {
    return 'このデバイスのお気に入りと履歴が $email のアカウントに追加されます。取り消せません。';
  }

  @override
  String get accountMergeConfirm => '統合';

  @override
  String get accountCarryLocal => 'この端末のお気に入りを残す';

  @override
  String accountCarryLocalOn(int n) {
    return 'この端末のお気に入り $n 件とプレイリストをアカウントに追加します。';
  }

  @override
  String get accountCarryLocalOff =>
      'この端末から削除し、アカウントのものに置き換えます。ダウンロード済みのファイルは残ります。';

  @override
  String get accountDropLocalTitle => 'この端末のデータを削除しますか？';

  @override
  String get accountCreatedOk => 'アカウントを保存しました。ライブラリは安全です';

  @override
  String get accountMergedOk => 'ログインしました — ローカルのお気に入りを追加しました';

  @override
  String get accountSignedInOk => 'ログインしました';

  @override
  String get playlistEntryMissing => 'このデバイスにファイルがありません';

  @override
  String get playlistEntryMissingRestorable => 'ファイルがありません — 再ダウンロードできます';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 件が不明',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'アカウントに保存';

  @override
  String get playlistBackupSubtitle => '再インストール後もこのプレイリストを保持します';

  @override
  String get playlistBackupUpdate => '保存内容を更新';

  @override
  String get playlistBackupUpdateSubtitle => 'アカウント上の内容をこの版に置き換えます';

  @override
  String get playlistBackupStop => '保存をやめる';

  @override
  String get playlistBackupStopped => '保存を解除しました';

  @override
  String get playlistBackupDone => 'プレイリストを保存しました';

  @override
  String get playlistBackupFailed => '保存できませんでした';

  @override
  String get playlistBackupNoAccount => 'このデバイスにアカウントがありません';

  @override
  String get playlistSyncTooltip => 'アカウントと同期';

  @override
  String get playlistSyncRunning => '同期中…';

  @override
  String get playlistSyncDone => 'プレイリストを同期しました';

  @override
  String get playlistSyncPartial => '一部のプレイリストを保存できませんでした';

  @override
  String get playlistFetchMissing => '見つからない曲をダウンロード';

  @override
  String get playlistFetchDone => '見つからない曲をダウンロードしました';

  @override
  String get playlistFetchPartial => '一部の曲をダウンロードできませんでした';

  @override
  String get playlistEntryFetchFailed => 'この曲をダウンロードできませんでした';

  @override
  String get accountStatPlaylists => 'プレイリスト';

  @override
  String get accountSyncNow => '今すぐ同期';

  @override
  String get accountSyncAuto => 'バックグラウンドで自動的に実行されます';

  @override
  String get accountSyncAnonymous =>
      'サーバーにバックアップ済み。別の端末と同期するにはメールアドレスを追加してください。';

  @override
  String get accountSyncPending => '送信待ちの変更があります';

  @override
  String accountSyncLast(String when) {
    return '最後の同期: $when';
  }

  @override
  String get accountSyncDone => '同期しました';

  @override
  String get accountSyncFailed => '同期に失敗しました。あとで再試行します';

  @override
  String get podiumFirst => '1位';

  @override
  String get podiumSecond => '2位';

  @override
  String get podiumThird => '3位';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return '$production の音楽、$compo $place';
  }

  @override
  String podiumContains(String place, String compo) {
    return '$compo の$placeを収録';
  }

  @override
  String get competitionEmpty => 'このコンペにはエントリーがありません';

  @override
  String get competitionEntryNoMusic => 'このエントリーのカタログ音源はありません';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n 曲',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => 'はじめる';

  @override
  String get onboardingBetaTitle => 'ベータ版';

  @override
  String get onboardingBetaBody =>
      'Rewamp はまだ開発中です。ライブラリ、プレイリスト、お気に入り、再生統計といったローカルデータは、バージョン 1.0 までに初期化される可能性があります。ダウンロードしたファイル自体は影響を受けませんが、大切なものは別途保管してください。';

  @override
  String onboardingVersion(String version, String build) {
    return 'バージョン $version（ビルド $build）';
  }

  @override
  String get onboardingExploreTitle => 'さがす';

  @override
  String get onboardingExploreBody =>
      '主要なオンラインアーカイブから、数万曲のチップチューンやトラッカーモジュールを、アーティスト・アルバム・プラットフォーム・パーティー別に探せます。タップで再生、ダウンロードで手元に保存。';

  @override
  String get onboardingLibraryTitle => 'ライブラリ';

  @override
  String get onboardingLibraryBody =>
      '気に入った曲を保存し、プレイリストを作り、フォルダーで整理できます。ダウンロードした曲はオフラインでも再生でき、ログインすればライブラリは端末間で同期します。';

  @override
  String get onboardingPlayerTitle => 'プレイヤー';

  @override
  String get onboardingPlayerBody =>
      'スワイプで曲を切り替え、ビジュアライザーを開けます。オシロスコープ、音声ごとのスコープ、流れる音符、トラッカーグリッド。複数曲を含むファイルはサブソングを表示し、各ボイスは個別にミュートできます。';

  @override
  String get onboardingReplayTitle => 'はじめに';

  @override
  String get onboardingReplaySubtitle => 'ベータ版の注意と機能紹介をもう一度見る';

  @override
  String get settingsPatternTitle => 'パターン';

  @override
  String get settingsPatternSubtitle => 'トラッカーグリッド：色・列・スクロール';

  @override
  String get patternOpaqueBg => '不透明な背景';

  @override
  String get patternOpaqueBgSubtitle => 'グリッドの背後のジャケットを隠します';

  @override
  String get commonSave => '保存';

  @override
  String get accountDisplayName => '公開名';

  @override
  String get accountDisplayNameNotSet => '未設定 — プレイリストの公開に必要です';

  @override
  String get accountDisplayNameHint => 'クレジットに使う名前です。';

  @override
  String get accountDisplayNameChangeWarning =>
      '変更すると、公開済みのプレイリストはすべて再審査に戻ります。';

  @override
  String get accountDisplayNameTaken => 'この名前は使われています。別の名前を選んでください。';

  @override
  String get accountDisplayNameLength => '2〜40文字。';

  @override
  String get accountDisplayNameSaved => '公開名を保存しました';

  @override
  String accountDisplayNameBackInReview(int n) {
    return '再審査に戻ったプレイリスト: $n';
  }

  @override
  String get playlistPublish => '公開する';

  @override
  String get playlistPublishSubtitle => '公開を申請（審査あり）';

  @override
  String get playlistPublishTitle => 'このプレイリストを公開しますか？';

  @override
  String get playlistPublishBody =>
      '承認されると全員に表示され、公開名でクレジットされます。ジャケットは収録曲から作られます。';

  @override
  String get playlistPublishCta => '申請';

  @override
  String get playlistPublishSubmitted => '審査に送りました';

  @override
  String get playlistPublishPending => '承認待ち';

  @override
  String get playlistPublishApproved => '公開中';

  @override
  String playlistPublishRejected(String reason) {
    return '却下: $reason';
  }

  @override
  String get playlistPublishRejectedShort => '却下';

  @override
  String get playlistPublishNeedName => 'クレジットに使う名前を選んでください';

  @override
  String get playlistPublishNeedTracks => '公開するには5曲以上必要です';

  @override
  String get playlistPublishHasLocal => '端末内のファイルは公開できません — 他の人は再生できません';

  @override
  String get playlistPublishTooManyPending => '承認待ちのプレイリストがすでに3つあります';

  @override
  String get playlistPublishRefused => '公開が却下されました: 曲と申請中のプレイリストを確認してください';

  @override
  String get playlistPublishFailed => '公開に失敗しました';

  @override
  String get playlistPublishWithdrawn => 'プレイリストは非公開に戻りました';

  @override
  String get playlistUnpublish => '非公開にする';

  @override
  String get playlistUnpublishSubtitle => '公開プレイリストから外します';

  @override
  String get playlistRenamePublishedTitle => '公開中のプレイリストの名前を変更しますか？';

  @override
  String get playlistRenamePublishedBody =>
      '審査対象は名前です。変更するとプレイリストは再審査に戻り、その間は非公開になります。曲の追加や並べ替えでは戻りません。';

  @override
  String playlistByAuthor(String author) {
    return '$author';
  }

  @override
  String get settingsSpectrumMode => 'スペクトラムのモード';

  @override
  String get settingsSpectrumModeStandard => '標準';

  @override
  String get settingsSpectrumModeColored => 'カラー';

  @override
  String get settingsSpectrumModeBeam => 'ビーム';

  @override
  String get settingsSpectrumModeLine => 'ライン';

  @override
  String get settingsSpectrumModeRing => 'リング';

  @override
  String get releaseNotesTitle => '新着情報';

  @override
  String get releaseNotesV4Downloads =>
      'ダウンロード: 長いダウンロードを途中で中止でき、アルバムの書庫を何度も取り直さなくなりました。';

  @override
  String get releaseNotesV4Queue => 'キュー: 確認付きで空にするボタン。再生も停止します。';

  @override
  String get releaseNotesV4DropFiles =>
      'ウィンドウにドロップしたファイル: 今すぐ／次に／最後に再生を選べます。ジャケットや付随ファイルは除外し、書庫に入ったプレイリストに従います（本当の曲名、空きトラックなし）。';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: サーバーのものに加えて、端末から自分の SoundFont を読み込めます。';

  @override
  String get releaseNotesV4Formats =>
      'Wwise・FSB・OGL のゲーム音源がついに再生できます（独自 Vorbis）。';

  @override
  String get releaseNotesV4Chips =>
      '音源チップを 6 種類追加、チップごとにエミュレーションコアを選択（ゲームボーイは SameBoy）、サンプル系チップの音程も正しくなりました。';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: .vt2 が再生でき、音符表示とパターン表示が ZX 系全体に対応しました。';

  @override
  String get releaseNotesV4Loop =>
      '1 曲リピートが読み込み直しではなく本当にループするようになり、無限ループでも時間表示が止まらなくなりました。';

  @override
  String get releaseNotesV4Info => 'ⓘ パネルに、その曲が実際に開いたファイルを一覧表示（付随ファイルやライブラリも）。';

  @override
  String get releaseNotesV4Linux => 'Linux デスクトップ版。';

  @override
  String get releaseNotesDataReset =>
      'このベータのためにローカルデータを初期化しました。ライブラリとプレイリストはアカウントから再構築されます。ダウンロードはやり直しです。';

  @override
  String get releaseNotesDismiss => '続ける';

  @override
  String get pmManagePresets => 'プリセットを管理';

  @override
  String get pmPickTooltip => 'プリセットを選択';

  @override
  String get pmPickFilter => 'プリセットを絞り込む';

  @override
  String get pmSourceTooltip => 'プリセットのソース';

  @override
  String get pmAddToPlaylistTooltip => 'プリセットをプレイリストに追加';

  @override
  String pmSlowPresetDropped(String name) {
    return '「$name」はこの端末には重すぎるため除外しました。';
  }

  @override
  String get pmSlowDeviceTitle => 'この端末では処理が追いつきません';

  @override
  String get pmSlowDeviceOff =>
      'ビジュアライザーを停止しました。この端末では Milkdrop プリセットに追いつけません。';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個のプリセットを除外中',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle => 'この端末では重すぎます。再生時に飛ばします。';

  @override
  String get settingsPmSlowPresetsRestore => '元に戻す';

  @override
  String get pmSourceBundled => '内蔵プリセット';

  @override
  String get pmSourceImports => 'インポートしたプリセット';

  @override
  String get pmSourceAll => 'すべてのプリセット';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のプリセット',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => '新しいプレイリスト…';

  @override
  String get pmPlaylistName => 'プレイリスト名';

  @override
  String get pmAddedToPlaylist => 'プレイリストに追加しました';

  @override
  String get pmAlreadyInPlaylist => 'すでにこのプレイリストにあります';

  @override
  String get pmTabPacks => 'パック';

  @override
  String get pmTabBrowse => 'ブラウズ';

  @override
  String get pmTabPlaylists => 'プレイリスト';

  @override
  String get pmTabPopular => '人気';

  @override
  String get pmTabSetAside => '除外';

  @override
  String get pmSetAsideEmpty => '除外はありません。この端末が 6 fps を下回るプリセットがここに入ります。';

  @override
  String get pmSetAsideRestoreAll => 'すべて元に戻す';

  @override
  String get pmInstall => 'インストール';

  @override
  String get pmInstallQueued => 'インストール待ち';

  @override
  String get pmUninstall => 'アンインストール';

  @override
  String get pmUninstalled => 'パックを削除しました';

  @override
  String get pmUse => '使用';

  @override
  String get pmDefaultPackBanner => 'おすすめのスターターパック';

  @override
  String pmLicense(String license) {
    return 'ライセンス: $license';
  }

  @override
  String get pmPacksOffline => 'サーバーに接続できません';

  @override
  String get pmSearchPresets => 'プリセットを検索…';

  @override
  String get pmPlayNow => '今すぐ再生';

  @override
  String get pmDownloadAction => 'ダウンロード';

  @override
  String get pmDownloaded => 'プリセットをダウンロードしました';

  @override
  String get pmDownloadFailed => 'ダウンロードに失敗しました';

  @override
  String pmPreviewing(String name) {
    return '再生中: $name';
  }

  @override
  String get pmLocalSection => 'マイプレイリスト';

  @override
  String get pmCuratedSection => 'Rewamp プレイリスト';

  @override
  String get pmImportPlaylist => 'ダウンロードして使用';

  @override
  String get pmPlaylistImported => 'プレイリストの準備ができました';

  @override
  String get pmImportFiles => 'ファイルをインポート…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のプリセットをインポートしました',
      zero: 'プリセットはインポートされませんでした',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'プリセットを projectM ライブラリに追加しました';

  @override
  String get pmNoPlaylists => 'プリセットのプレイリストはまだありません';

  @override
  String get pmSourceApplied => 'プリセットのソースを適用しました';

  @override
  String get pmPlaylistEmpty => 'このプレイリストは空です';

  @override
  String get pmDays7 => '7日間';

  @override
  String get pmDays30 => '30日間';

  @override
  String get pmDays365 => '1年';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 回再生',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'インストールに失敗しました';

  @override
  String get pmSingleDownloads => '個別ダウンロード';

  @override
  String pmAvailableIn(String pack) {
    return '$pack に収録';
  }

  @override
  String get pmCleanUp => '整理';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のプリセットを削除しました',
      zero: '整理するものはありません',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'このプリセットを固定';

  @override
  String get pmUnlockAction => 'プリセットの固定を解除';

  @override
  String get pmOrderRandom => 'プリセットをシャッフル';

  @override
  String get pmOrderSequential => 'プリセットを順番に';

  @override
  String get pmUpdateAvailable => '更新があります';

  @override
  String get pmUpdate => '更新';

  @override
  String get pmSelectAll => 'すべて選択';

  @override
  String get pmSelectNone => '選択を解除';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件選択中',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => '未使用のテクスチャ';

  @override
  String pmTexturesFreed(String size) {
    return '$size を解放しました';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'テクスチャ $count 件',
    );
    return '$_temp0';
  }
}
