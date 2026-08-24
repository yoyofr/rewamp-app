// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get navHome => '홈';

  @override
  String get navSearch => '검색';

  @override
  String get navLibrary => '보관함';

  @override
  String get noFileSelected => '선택된 파일 없음';

  @override
  String get openFile => '파일 열기';

  @override
  String get pickerLabelAudio => '오디오';

  @override
  String get formatNotSupported => '지원하지 않는 포맷';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return '지원하지 않는 형식: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return '이 기기에 없습니다: $file';
  }

  @override
  String playbackFileGone(String file) {
    return '서버에 파일이 없습니다: $file';
  }

  @override
  String get failedToLoadFile => '파일을 불러올 수 없습니다';

  @override
  String get libraryEmptyHint => '아티스트, 앨범, 재생목록이\n여기에 표시됩니다.';

  @override
  String get libraryPlaylists => '재생목록';

  @override
  String get libraryArtists => '아티스트';

  @override
  String get libraryAlbums => '앨범';

  @override
  String get libraryTracks => '트랙';

  @override
  String get libraryFavorites => '즐겨찾기';

  @override
  String get libraryFavoritesSubtitle => '즐겨찾는 곡 자동 재생목록';

  @override
  String get libraryRecentlyAdded => '최근 추가됨';

  @override
  String get libraryEmpty => '아직 항목이 없습니다';

  @override
  String get libraryRemoved => '라이브러리에서 제거함';

  @override
  String get searchHint => '검색…';

  @override
  String get searchTypePlaceholder => '제목, 아티스트, 앨범 입력…';

  @override
  String get searchNoResults => '결과 없음';

  @override
  String get searchDownloading => '다운로드 중…';

  @override
  String searchError(String message) {
    return '오류: $message';
  }

  @override
  String get tabAll => '트랙';

  @override
  String get tabArtists => '아티스트';

  @override
  String get tabAlbums => '앨범';

  @override
  String get tabProductions => '프로덕션';

  @override
  String get filterWithVideo => '영상 있음';

  @override
  String get videoUnavailable => '이 영상을 재생할 수 없습니다';

  @override
  String get noItems => '항목 없음';

  @override
  String get sortRelevance => '관련도순';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => '최근 재생';

  @override
  String get noRecentTracks => '최근 재생한 곡이 없습니다';

  @override
  String get openLocalFile => '로컬 파일 열기';

  @override
  String get playerSourceLocal => '로컬';

  @override
  String get browseFiles => '파일 탐색';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total개 결과';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded개 불러옴…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded개 결과';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded개 불러옴 — 스크롤하면 더 보기';
  }

  @override
  String countNLoaded(int n) {
    return '$n개 불러옴';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n개 파일';
  }

  @override
  String get browseFilterByTitle => '제목으로 필터…';

  @override
  String get browseNoSongs => '재생할 수 있는 곡이 없습니다';

  @override
  String get browseByFormat => '포맷별';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => '포맷으로 필터…';

  @override
  String get browseByPlatform => '플랫폼별';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => '플랫폼 이름…';

  @override
  String get browseByChip => '사운드 칩별';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => '예: YM2612, SPC700…';

  @override
  String get browseOk => '확인';

  @override
  String get browseByArtist => '아티스트별';

  @override
  String get browseByArtistSubtitle => '작곡가 둘러보기';

  @override
  String get browseFilterByName => '이름으로 필터…';

  @override
  String get browseNoArtistFound => '아티스트를 찾을 수 없습니다';

  @override
  String get browseNoArtistsAvailable => '표시할 아티스트가 없습니다';

  @override
  String get browseNoArtist => '아티스트 없음';

  @override
  String get browseNoAlbum => '앨범 없음';

  @override
  String get browseTopPacks => '인기 팩';

  @override
  String get browseTopPacksSubtitle => '평점이 가장 높은 팩';

  @override
  String browseTopPacksLabel(String collection) {
    return '인기 팩 — $collection';
  }

  @override
  String get browseLatestPacks => '최신 팩';

  @override
  String get browseLatestPacksSubtitle => '가장 최근에 추가된 항목';

  @override
  String browseLatestPacksLabel(String collection) {
    return '최신 팩 — $collection';
  }

  @override
  String get browseAllSongs => '모든 곡';

  @override
  String get browseAllSongsSubtitleAlpha => '알파벳순으로 둘러보기';

  @override
  String get browseAlphabetical => '알파벳순';

  @override
  String browseAllLabel(String collection) {
    return '전체 — $collection';
  }

  @override
  String get browseCollections => '컬렉션';

  @override
  String browseFilesCount(String count) {
    return '$count개 파일';
  }

  @override
  String get browseIndexing => '색인 생성 중';

  @override
  String browseFilterFacet(String name) {
    return '$name 필터…';
  }

  @override
  String get browseAllYears => '모든 연도';

  @override
  String get browseAllYearsSubtitle => '이 파티의 모든 곡';

  @override
  String get browseNoCompo => '이 파티에 색인된 컴포가 없습니다.';

  @override
  String get browseOthers => '기타';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '출품작 $n개 — 순위',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => '재생목록 재생';

  @override
  String get browsePlayAllRanked => '모두 재생 (순위순)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡 — 순위순',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => '앨범별 보기';

  @override
  String get browsePlayAll => '모두 재생';

  @override
  String get browseShuffle => '셔플';

  @override
  String get browseSearchInFolder => '이 폴더에서 검색…';

  @override
  String get browseFilterThisList => '이 목록 필터링…';

  @override
  String get browseSearchSubfolders => '하위 폴더 검색';

  @override
  String get browseEmptyFolder => '빈 폴더';

  @override
  String browsePlaybackError(String message) {
    return '재생 실패: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => '보기';

  @override
  String get browseViewList => '목록';

  @override
  String get browseViewGrid => '격자';

  @override
  String get browseViewGridCompact => '좁은 격자';

  @override
  String get browseSearchAlbum => '앨범 검색…';

  @override
  String get browseSearchArtist => '아티스트 검색…';

  @override
  String get browsePlayAlbum => '앨범 재생';

  @override
  String get searchDownloadingAlbum => '앨범 다운로드 중…';

  @override
  String get searchCategoryChip => '칩';

  @override
  String get searchCategoryGroup => '그룹';

  @override
  String get artistRealName => '본명';

  @override
  String get artistAliases => '다른 이름';

  @override
  String get artistBorn => '출생';

  @override
  String get artistInterview => '인터뷰';

  @override
  String get audioOutput => '오디오 출력';

  @override
  String get audioOutputSystemDefault => '시스템 기본값';

  @override
  String get vizRangeAuto => '자동';

  @override
  String get contextNotes => '메모';

  @override
  String get notePlacedBadge => '컴포 입상';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '멤버 $count명',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => '곡 보기';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '모듈 $count개',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => '파티';

  @override
  String get searchCategoryYear => '연도';

  @override
  String get searchCategoryOrigin => '출처';

  @override
  String get searchCategoryProduction => '프로덕션';

  @override
  String get searchCategoryProductionType => '프로덕션 유형';

  @override
  String get searchCategoryPublisher => '퍼블리셔';

  @override
  String get searchCategoryDeveloper => '개발사';

  @override
  String get searchCategoryArcadeBoard => '아케이드 기판';

  @override
  String get searchCategorySaga => '사가';

  @override
  String get searchCategoryGenre => '장르';

  @override
  String get searchViaArtist => '아티스트로';

  @override
  String get searchViaAlbum => '앨범으로';

  @override
  String get searchViaSong => '곡으로';

  @override
  String get searchSortPopular => '인기순';

  @override
  String get searchSortYear => '연도';

  @override
  String get searchSortRandom => '무작위';

  @override
  String get searchSortRating => '평점';

  @override
  String statsTopPercent(int percent) {
    return '상위 $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count표',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => '오름차순';

  @override
  String get searchSortDesc => '내림차순';

  @override
  String get searchFilters => '필터';

  @override
  String get searchExactSearch => '정확히 일치';

  @override
  String get searchExactSearchSubtitle => '유사(퍼지) 검색을 끕니다';

  @override
  String get searchTags => '태그';

  @override
  String searchTagSearchHint(String category) {
    return '« $category »에서 태그 검색…';
  }

  @override
  String get searchTagTypeToSearch => '태그를 검색하려면 입력하세요.';

  @override
  String get searchTagsAndLogic => '태그 여러 개 = AND 조건.';

  @override
  String get searchFilterYear => '연도';

  @override
  String get searchFilterAll => '전체';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote => '연도로 필터링하면 연도 없는 곡은 제외됩니다.';

  @override
  String get searchMinRating => '평점 ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => '취소';

  @override
  String get searchReset => '재설정';

  @override
  String get searchApply => '적용';

  @override
  String get searchClearRecent => '최근 검색 지우기';

  @override
  String get searchBrowse => '둘러보기';

  @override
  String get searchBrowseHint =>
      '패싯(그룹, 칩, 연도…)을 골라 카탈로그를 둘러보거나, 위에서 라디오/서프라이즈를 시작하세요.';

  @override
  String get searchDidYouMean => '결과가 적습니다 — 유사 검색을 해볼까요?';

  @override
  String get searchYes => '예';

  @override
  String get featuredCommunityTitle => '커뮤니티 신규';

  @override
  String get searchPlaylistSourceAll => '전체';

  @override
  String get searchPlaylistSourceUser => '커뮤니티';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => '포맷';

  @override
  String get searchPlatform => '플랫폼';

  @override
  String get filterCollection => '컬렉션';

  @override
  String get videoWatchDemo => '데모 보기';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return '컬렉션: $name';
  }

  @override
  String get searchCollectionAll => '전체';

  @override
  String get searchRadio => '라디오';

  @override
  String get searchRadioTooltip => '현재 필터로 만든 무작위 대기열';

  @override
  String get searchSurprise => '서프라이즈';

  @override
  String get searchSurpriseTooltip => '무작위 곡 하나';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => '곡 없음';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '앨범 $n개',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return '일명 $name';
  }

  @override
  String get searchChooseCollection => '컬렉션 선택';

  @override
  String get searchFilterCollections => '컬렉션 필터…';

  @override
  String get searchFilterPlaceholder => '필터…';

  @override
  String searchAllOf(String label) {
    return '전체 ($label)';
  }

  @override
  String get searchNoMatch => '일치하는 항목 없음';

  @override
  String get searchNoPlaylist => '재생목록 없음';

  @override
  String get engineDescOpenmpt => '트래커 모듈 (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — 사운드 칩, 채널별 스코프';

  @override
  String get engineDescGme => 'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN 아카이브';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — 채널별 보이스';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp 엔진)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX 칩튠 (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace => '멀티 칩 칩튠 .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade => '68k 에뮬레이션 기반 Amiga 커스텀 칩 포맷 (약 320종)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi => '표준 MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ 신스 (16 보이스)';

  @override
  String get engineDescV2m => 'V2M 신스 (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — 실제 68000 에뮬레이션 + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf => 'Nintendo 64 .usf — R4300 에뮬레이션 + RSP 오디오';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ 에뮬레이션';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound 칩';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — 실제 AY-3-8910/YM2149 신스';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixel의 자체 엔진';

  @override
  String get engineDescPxtone => 'Pixel의 트래커 — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — emu68 기반 실제 68000';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA FM + SSG + PPZ8 샘플';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ .pdx 샘플), YM2151 FM';

  @override
  String get engineDescFmp => 'PC-98 FMP 드라이버 — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612 FM + PCM (.eup)';

  @override
  String get engineDescMac => '무손실 .ape';

  @override
  String get engineDescVgmstream => '게임 스트림 오디오 포맷 (700종 이상, .rrds 포함)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — 대체 디코더';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total곡',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / 앨범 $total개',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / 아티스트 $total명',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '앨범 $n개',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '아티스트 $n명',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '그룹 $n개',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => '국가';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '국가 $n곳',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => '폴더';

  @override
  String get featuredTitle => '오늘의 추천';

  @override
  String featuredPartyNow(String party) {
    return '$party 진행 중 — 지난 대회의 입상작';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party 개막 $days일 전 — 지난 대회의 입상작',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series 시즌 — 지난 대회의 입상작';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return '$year년 $month 발매';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age년 전: $year년의 게임',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade년대';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age년 전: $year년의 게임',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return '$month에 발매';
  }

  @override
  String get featuredAnniversaryHeader => '기념일';

  @override
  String get featuredBirthdayHeader => '오늘의 생일';

  @override
  String get featuredBirthdayWeekHeader => '이번 주 생일';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '이번 주 $artist의 생일';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '재생목록 $count개',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonOptions => '옵션';

  @override
  String get commonDownload => '다운로드';

  @override
  String get commonDeleteDownload => '다운로드 삭제';

  @override
  String get commonAddToPlaylist => '재생목록에 추가';

  @override
  String get commonPlayNext => '다음 재생';

  @override
  String get commonAddToQueueEnd => '대기열 끝에 추가';

  @override
  String get commonAddToFavorites => '즐겨찾기에 추가';

  @override
  String get commonRemoveFromFavorites => '즐겨찾기에서 삭제';

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
  String get subsongDeleteDownloadTitle => '이 다운로드를 삭제할까요?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return '파일과 로컬 항목(재생 기록, 트랙)이 삭제됩니다.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => '트랙을 읽을 수 없습니다';

  @override
  String subsongTrackNumber(int number) {
    return '트랙 $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '서브송 $count개',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => '모두 재생';

  @override
  String get albumDownloading => '앨범 다운로드 중…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return '앨범 다운로드 중… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks => '트랙을 보려면 앨범을 다운로드하세요';

  @override
  String get albumNotDownloadedHint => '다운로드되지 않은 앨범 — 재생하면 다운로드됩니다';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count곡',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => '정보 불러오는 중…';

  @override
  String albumAka(String label) {
    return '일명 $label';
  }

  @override
  String get albumPlayAlbum => '앨범 재생';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 항목',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst => '먼저 검색에서 이 곡을 재생해 다운로드하세요';

  @override
  String get libraryAddedTrack => '곡을 보관함에 추가했습니다';

  @override
  String get libraryAddedAlbum => '앨범을 보관함에 추가했습니다';

  @override
  String get libraryAddedArtist => '아티스트를 보관함에 추가했습니다';

  @override
  String get libraryRemovedTrack => '곡을 보관함에서 삭제했습니다';

  @override
  String get libraryRemovedAlbum => '앨범을 보관함에서 삭제했습니다';

  @override
  String get libraryRemovedArtist => '아티스트를 보관함에서 삭제했습니다';

  @override
  String songTilePlayFailed(String message) {
    return '재생 실패: $message';
  }

  @override
  String downloadFailed(String label) {
    return '다운로드 실패 — $label';
  }

  @override
  String downloadInProgress(String label) {
    return '다운로드 중 — $label';
  }

  @override
  String get downloadsTitle => '다운로드';

  @override
  String get downloadsEmpty => '대기 중인 다운로드 없음';

  @override
  String get downloadsPause => '일시정지';

  @override
  String get downloadsResume => '재개';

  @override
  String get downloadsCancel => '다운로드 취소';

  @override
  String get downloadsClear => '모두 제거';

  @override
  String get downloadsPausedBanner => '다운로드 일시정지됨 — 현재 파일은 먼저 완료됩니다';

  @override
  String downloadInProgressPct(String label, int percent) {
    return '다운로드 중 — $label $percent %';
  }

  @override
  String get miniPlayerQueue => '재생목록';

  @override
  String get miniPlayerHideQueue => '재생목록 숨기기';

  @override
  String get transportShuffle => '셔플';

  @override
  String get transportShuffleOn => '셔플 켜짐';

  @override
  String get transportLoopOff => '반복 꺼짐';

  @override
  String get transportLoopQueue => '반복: 대기열';

  @override
  String get transportLoopTrack => '반복: 현재 곡';

  @override
  String get vizStereo => '스테레오';

  @override
  String get vizSpectrum => '스펙트럼';

  @override
  String get vizVoices => '보이스';

  @override
  String get vizNotes => '노트';

  @override
  String get vizPatterns => '패턴';

  @override
  String get patternScrollMode => '스크롤 모드';

  @override
  String get patternSmoothScroll => '부드러운 스크롤';

  @override
  String get patternVolumeBars => '볼륨 막대';

  @override
  String get patternColorScheme => '색 구성표';

  @override
  String get patternSize => '크기';

  @override
  String get patternColumns => '열';

  @override
  String get patternColumnsAll => '전체';

  @override
  String get patternColumnsNoteInstr => '간략';

  @override
  String get patternColumnsNote => '최소';

  @override
  String get vizClose => '비주얼라이저 닫기';

  @override
  String get vizFullscreen => '전체 화면';

  @override
  String get vizExitFullscreen => '전체 화면 종료';

  @override
  String get vizPrevPreset => '이전 프리셋';

  @override
  String get vizNextPreset => '다음 프리셋';

  @override
  String get vizProjectmUnavailable => 'projectM 사용 불가';

  @override
  String get voicesTitle => '보이스';

  @override
  String get voicesNone => '이 곡에는 보이스가 없습니다.';

  @override
  String get voicesLongPressSolo => '길게 누르면 솔로';

  @override
  String get voicesMuteAll => '모두 음소거';

  @override
  String get voicesUnmuteAll => '음소거 모두 해제';

  @override
  String get voicesStereoOutput => '스테레오 출력';

  @override
  String get voicesLeft => '왼쪽';

  @override
  String get voicesRight => '오른쪽';

  @override
  String get enginesFormatsTitle => '재생 가능한 포맷';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '재생 엔진 $engines개에서 포맷 $formats개를 지원합니다.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '포맷 $count개',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return '$artist의 「$title」 커버';
  }

  @override
  String stilCover(String work) {
    return '「$work」 커버';
  }

  @override
  String get playerQueue => '재생 대기열';

  @override
  String get queueEdit => '편집';

  @override
  String get queueEditDone => '완료';

  @override
  String get queueClear => '대기열 비우기';

  @override
  String get queueClearConfirmTitle => '대기열을 비울까요?';

  @override
  String get queueClearConfirmBody => '대기열이 비워지고 재생이 중지됩니다.';

  @override
  String get queueClearConfirm => '비우기';

  @override
  String get queueRemoveSelected => '선택 항목 삭제';

  @override
  String get queueRemoveTrack => '대기열에서 제거';

  @override
  String get queueReorder => '순서 변경';

  @override
  String get playerArtwork => '아트워크';

  @override
  String get playerVisualizer => '비주얼라이저';

  @override
  String get playerVoices => '보이스';

  @override
  String get playerTrackInfo => '곡 정보';

  @override
  String get playerShowQueue => '재생목록';

  @override
  String get playerHideQueue => '재생목록 숨기기';

  @override
  String get playerNoTrackInfo => '표시할 정보가 없습니다.';

  @override
  String get playerViewSubsongs => '서브송 보기';

  @override
  String get playerViewAlbum => '앨범 보기';

  @override
  String get playerViewArtist => '아티스트 보기';

  @override
  String get playerAddToPlaylist => '재생목록에 추가';

  @override
  String get queueAddToPlaylist => '대기열을 재생목록에 추가';

  @override
  String get playerMoreOptions => '옵션 더 보기';

  @override
  String get playerClose => '닫기';

  @override
  String get playerCancel => '취소';

  @override
  String get playerDelete => '삭제';

  @override
  String get playerAddFavorite => '즐겨찾기에 추가';

  @override
  String get playerRemoveFavorite => '즐겨찾기에서 삭제';

  @override
  String get playerAddToLibrary => '보관함에 추가';

  @override
  String get playerRemoveFromLibrary => '보관함에서 삭제';

  @override
  String get playerAddedToLibrary => '곡을 보관함에 추가했습니다';

  @override
  String get playerRemovedFromLibrary => '곡을 보관함에서 삭제했습니다';

  @override
  String get playerDeleteDownload => '다운로드 삭제';

  @override
  String get playerRedownload => '파일 다시 다운로드';

  @override
  String get playerRedownloadUnavailable => '이 파일은 다시 다운로드할 수 없습니다';

  @override
  String get playerDeleteDownloadTitle => '다운로드를 삭제할까요?';

  @override
  String playerDeleteDownloadBody(String path) {
    return '파일과 로컬 항목(재생 기록, 트랙)이 삭제됩니다.\n\n$path';
  }

  @override
  String get homeYourTrends => '나의 트렌드';

  @override
  String get homeYourAllTimeTop => '나의 역대 인기';

  @override
  String get homeTrending => '인기 급상승';

  @override
  String get homeFeaturedPlaylists => '추천 재생목록';

  @override
  String get homeAllTimeTop => '역대 인기';

  @override
  String get homePeriod7d => '7일';

  @override
  String get homePeriod30d => '30일';

  @override
  String get homePeriod90d => '90일';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n회 재생',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => '비어 있거나 읽을 수 없는 재생목록';

  @override
  String get homeExtractingArchive => '아카이브 압축 해제 중…';

  @override
  String get homeArchiveEmpty => '아카이브에 재생 가능한 파일이 없습니다';

  @override
  String get homeNothingPlayable => '선택 항목에 재생 가능한 파일이 없습니다';

  @override
  String get homeAlbumLoadFailed => '이 앨범을 불러올 수 없습니다';

  @override
  String get homeSongLoadFailed => '이 곡을 불러올 수 없습니다';

  @override
  String get navStats => '통계';

  @override
  String get navSettings => '설정';

  @override
  String get playlistMoveUp => '상위 폴더로 이동';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '재생목록 $n개',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '하위 폴더 $n개',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      '이 폴더와 그 안의 모든 항목이 영구히 삭제됩니다:';

  @override
  String get playlistDeleteFolderEmptyBody => '이 폴더가 삭제됩니다.';

  @override
  String get playlistFolderRoot => '루트';

  @override
  String get playlistMoveToFolder => '폴더로 이동';

  @override
  String playlistDeleteTitle(String name) {
    return '\'$name\'을(를) 삭제할까요?';
  }

  @override
  String get playlistDeleteBody => '이 재생목록이 영구히 삭제됩니다.';

  @override
  String get playlistRenameFolderTitle => '폴더 이름 변경';

  @override
  String get playlistClearFavorites => '모든 즐겨찾기 삭제';

  @override
  String get playlistClearFavoritesTitle => '모든 즐겨찾기를 삭제할까요?';

  @override
  String get playlistClearFavoritesBody => '즐겨찾기한 모든 트랙을 잃게 됩니다. 되돌릴 수 없습니다.';

  @override
  String get playlistRemoveFromLibrary => '라이브러리에서 제거';

  @override
  String get playlistServerReadOnly => '서버 재생목록 · 읽기 전용';

  @override
  String get navAbout => '정보';

  @override
  String get navMore => '더 보기';

  @override
  String get shellAlbumQueuedAtEnd => '앨범을 대기열 끝에 추가했습니다';

  @override
  String get shellAlbumQueuedNext => '앨범을 다음에 재생합니다';

  @override
  String get shellAddingToQueue => '대기열에 추가하는 중…';

  @override
  String get shellAddingNext => '다음 재생에 추가하는 중…';

  @override
  String shellDownloadFailed(String error) {
    return '다운로드 실패: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count곡을 대기열에 추가했습니다',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\"을(를) 대기열 끝에 추가했습니다';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\"을(를) 다음에 재생합니다';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return '다운로드 실패: $title — 다음 곡으로 넘어갑니다';
  }

  @override
  String get shellNetworkUnavailable => '재생이 중단되었습니다: 네트워크를 사용할 수 없습니다.';

  @override
  String get statsTitle => '통계';

  @override
  String statsPeriodDays(int n) {
    return '$n일';
  }

  @override
  String get statsPeriodThisYear => '올해';

  @override
  String get statsPeriodAll => '전체 기간';

  @override
  String get statsByMonthOrYear => '월 / 연도별…';

  @override
  String get statsByYear => '연도별';

  @override
  String get statsByMonth => '월별';

  @override
  String get statsPlaysLabel => '재생';

  @override
  String get statsTracksLabel => '트랙';

  @override
  String get statsArtistsLabel => '아티스트';

  @override
  String get statsAlbumsLabel => '앨범';

  @override
  String get statsListenTime => '청취 시간';

  @override
  String get statsByCollection => '컬렉션별';

  @override
  String get statsByFormat => '형식별';

  @override
  String get statsByEngine => '엔진별';

  @override
  String get statsPlaylistsLabel => '재생목록';

  @override
  String get statsLocalFilesSection => '다운로드한 파일';

  @override
  String get statsFilesLabel => '파일';

  @override
  String get statsSpaceLabel => '디스크 공간';

  @override
  String get statsNoPlaysInPeriod => '이 기간에 재생 기록이 없습니다';

  @override
  String get statsNoPlays => '재생 기록 없음';

  @override
  String get statsTopTracks => '인기 트랙';

  @override
  String get statsTopAlbums => '인기 앨범';

  @override
  String get statsTopArtists => '인기 아티스트';

  @override
  String statsTopTracksIn(String period) {
    return '인기 트랙 — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return '인기 앨범 — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return '인기 아티스트 — $period';
  }

  @override
  String get statsSeeAll => '모두 보기';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n회 재생',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return '최대 $n';
  }

  @override
  String get commonCancel => '취소';

  @override
  String get commonCreate => '만들기';

  @override
  String get commonOk => '확인';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonRename => '이름 변경';

  @override
  String get commonSort => '정렬';

  @override
  String get commonPlayAll => '모두 재생';

  @override
  String get sortName => '이름';

  @override
  String get sortTitle => '제목';

  @override
  String get sortArtist => '아티스트';

  @override
  String get sortAlbum => '앨범';

  @override
  String get sortDateAdded => '추가한 날짜';

  @override
  String get commonClear => '지우기';

  @override
  String get sortRecentlyModified => '최근 수정순';

  @override
  String get sortCreationDate => '만든 날짜순';

  @override
  String get playlistNameHint => '이름';

  @override
  String get playlistNew => '새 재생목록';

  @override
  String get playlistNewFolder => '새 폴더';

  @override
  String get playlistNewTooltip => '새 재생목록 / 폴더';

  @override
  String get playlistAddTo => '재생목록에 추가';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '재생목록 $n개에 추가',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => '재생목록을 선택하세요';

  @override
  String get playlistFilterHint => '재생목록 필터…';

  @override
  String get playlistSearchHint => '재생목록 검색…';

  @override
  String get playlistNoMatch => '일치하는 재생목록 없음';

  @override
  String get playlistNoneCreateHint => '재생목록 없음 — +로 만드세요';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
      zero: '곡 없음',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => '이미 있음';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '선택한 재생목록에 이미 $n개 항목이 있습니다.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => '중복 건너뛰기';

  @override
  String get playlistAddAgain => '다시 추가';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '재생목록 $m개',
    );
    return '$_temp0을(를) $_temp1에 추가했습니다';
  }

  @override
  String playlistAddFailed(String error) {
    return '추가할 수 없습니다: $error';
  }

  @override
  String get playlistRenameTitle => '재생목록 이름 변경';

  @override
  String playlistDeleteFolderTitle(String name) {
    return '폴더 “$name”을(를) 삭제할까요?';
  }

  @override
  String get playlistDeleteFolderBody => '내용은 상위 단계로 이동합니다.';

  @override
  String get playlistEmpty => '빈 재생목록';

  @override
  String get playlistRemoveEntry => '재생목록에서 삭제';

  @override
  String get trackOptionsAddToLibrary => '보관함에 추가';

  @override
  String get trackOptionsRemoveFromLibrary => '보관함에서 삭제';

  @override
  String get trackOptionsAddedToLibrary => '곡을 보관함에 추가했습니다';

  @override
  String get trackOptionsRemovedFromLibrary => '곡을 보관함에서 삭제했습니다';

  @override
  String get trackOptionsViewAlbum => '앨범 보기';

  @override
  String get trackOptionsViewArtist => '아티스트 보기';

  @override
  String get trackOptionsPlayNow => '지금 재생';

  @override
  String get trackOptionsPlayNext => '다음 재생';

  @override
  String get trackOptionsAddToQueueEnd => '대기열 끝에 추가';

  @override
  String get trackOptionsPlayLast => '마지막에 재생';

  @override
  String get trackOptionsDeleteDownload => '다운로드 삭제';

  @override
  String get trackOptionsDeleteDownloadTitle => '이 다운로드를 삭제할까요?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return '파일과 로컬 항목(재생 기록, 트랙)이 삭제됩니다.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => '다운로드를 삭제했습니다';

  @override
  String get trackOptionsAddToFavorites => '즐겨찾기에 추가';

  @override
  String get trackOptionsRemoveFromFavorites => '즐겨찾기에서 삭제';

  @override
  String get trackOptionsAlbumAddedToFavorites => '앨범을 즐겨찾기에 추가했습니다';

  @override
  String get trackOptionsAlbumRemovedFromFavorites => '앨범을 즐겨찾기에서 삭제했습니다';

  @override
  String get trackOptionsAlbumNotDownloaded => '다운로드되지 않은 앨범 — 삭제할 항목이 없습니다';

  @override
  String get trackOptionsDeleteAlbumTitle => '다운로드한 앨범을 삭제할까요?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return '폴더와 모든 로컬 항목(트랙, 재생 기록)이 삭제됩니다.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => '앨범을 로컬 저장소에서 삭제했습니다';

  @override
  String get trackOptionsRedownloadAlbum => '앨범 다시 다운로드';

  @override
  String get trackOptionsRedownloadAlbumSubtitle => '파일과 로컬 항목을 다시 씁니다';

  @override
  String get trackOptionsDeleteAlbumFiles => '앨범 파일 삭제';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle => '다운로드 폴더 + 로컬 항목(재생 기록)';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsGeneral => '일반';

  @override
  String get settingsGeneralSubtitle => '테마';

  @override
  String get settingsVisualisation => '비주얼라이제이션';

  @override
  String get settingsVisualisationSubtitle => '오실로스코프, 아트워크 배경';

  @override
  String get settingsPlayback => '재생';

  @override
  String get settingsPlaybackSubtitle => '반복, 페이드아웃, 무음';

  @override
  String get settingsEngines => '엔진';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => '데이터';

  @override
  String get settingsDataSubtitle => 'ID, 기록, 재설정';

  @override
  String get settingsBackupExport => '백업 내보내기';

  @override
  String get settingsBackupExportSubtitle => '라이브러리, 재생목록, 설정을 파일로 저장';

  @override
  String get settingsBackupImport => '백업 가져오기';

  @override
  String get settingsBackupImportSubtitle => '백업 파일에서 데이터 복원';

  @override
  String get settingsBackupExportFailed => '백업 내보내기에 실패했습니다';

  @override
  String get settingsBackupImportConfirmTitle => '백업을 가져올까요?';

  @override
  String get settingsBackupImportConfirmBody =>
      '이 기기의 라이브러리, 재생목록, 설정을 대체합니다. 다운로드한 파일은 유지됩니다.';

  @override
  String get settingsBackupImportConfirm => '가져오기';

  @override
  String get settingsBackupImportedTitle => '백업을 가져왔습니다';

  @override
  String get settingsBackupImportedBody =>
      '데이터가 복원되었습니다. 모두 적용하려면 앱을 다시 시작하세요.';

  @override
  String get settingsBackupTooNew => '이 백업은 더 새로운 버전의 앱에서 만들어졌습니다';

  @override
  String get settingsBackupInvalid => '유효한 Rewamp 백업이 아닙니다';

  @override
  String get settingsBackupImportFailed => '백업 가져오기에 실패했습니다';

  @override
  String get settingsAbout => '정보';

  @override
  String get settingsAboutSubtitle => '크레딧 및 라이선스';

  @override
  String get settingsCreditsSubtitle => '라이브러리, 데이터 및 구성 요소';

  @override
  String get settingsSupport => '문의 및 지원';

  @override
  String get settingsSupportSubtitle => '문의하기, 웹사이트';

  @override
  String get settingsSupportEmail => '이메일 보내기';

  @override
  String get settingsSupportEmailSubtitle => '질문, 버그 또는 제안';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — 지원';

  @override
  String get settingsSupportEmailIntro =>
      '위에 질문, 버그 또는 제안을 적어 주세요. 아래 정보는 지원에 도움이 됩니다.';

  @override
  String get settingsSupportWebsite => '웹사이트';

  @override
  String get settingsDonation => 'Rewamp 후원하기';

  @override
  String get settingsDonationSubtitle => '원하시면 팁을 남겨 주세요';

  @override
  String get settingsDonationBlurb =>
      'Rewamp는 무료이며 광고가 없습니다 — 데모신과 레트로 문화를 보존하기 위한 열정의 결과물입니다. 후원은 앱 개발 자금과 데이터베이스 호스팅 비용에 사용됩니다. 의무는 없습니다. 앱이 즐거움을 준다면 작은 정성도 언제나 감사합니다.';

  @override
  String get settingsDonationFloppy => '플로피 디스크';

  @override
  String get settingsDonationCartridge => '카트리지';

  @override
  String get settingsDonationBox => '박스 게임';

  @override
  String get settingsDonationCustom => '금액 선택';

  @override
  String get settingsCancel => '취소';

  @override
  String get settingsOk => '확인';

  @override
  String get settingsDelete => '삭제';

  @override
  String get settingsReset => '재설정';

  @override
  String get settingsRenew => '갱신';

  @override
  String get settingsOff => '끔';

  @override
  String get settingsOn => '켬';

  @override
  String get settingsAuto => '자동';

  @override
  String get settingsInfinite => '무한';

  @override
  String get settingsDefault => '기본값';

  @override
  String get settingsCoreNoScope => '오실로스코프 없음';

  @override
  String get settingsNone => '없음';

  @override
  String get settingsLevelLow => 'Low';

  @override
  String get settingsLevelHigh => 'High';

  @override
  String get settingsStereo => '스테레오';

  @override
  String get settingsSurround => '서라운드';

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
  String get settingsTheme => '테마';

  @override
  String get settingsThemeLight => '라이트';

  @override
  String get settingsThemeDark => '다크';

  @override
  String get settingsArtworkTintTitle => '아트워크 색으로 플레이어 물들이기';

  @override
  String get settingsArtworkTintSubtitle => '플레이어가 커버의 주요 색을 따릅니다';

  @override
  String get settingsGlassEffectTitle => '리퀴드 글래스 효과';

  @override
  String get settingsGlassEffectSubtitle => '하단 바의 렌즈와 블러 — 느린 기기에서는 끄세요';

  @override
  String get settingsResetSection => '이 섹션 재설정';

  @override
  String get settingsResetEngine => '이 엔진 재설정';

  @override
  String get settingsResetChoices => '이 선택 재설정';

  @override
  String get settingsResetToDefault => '기본값';

  @override
  String get settingsStartInVizTitle => '비주얼라이저 모드로 시작';

  @override
  String get settingsStartInVizSubtitle => '플레이어가 아트워크 대신 오실로스코프로 열립니다';

  @override
  String get settingsVoiceGridTitle => '보이스 오실로스코프 격자';

  @override
  String get settingsVoiceGridSubtitle => '보이스를 나누는 경계선을 표시합니다';

  @override
  String get settingsKeepAwakeTitle => '화면 켜짐 유지';

  @override
  String get settingsKeepAwakeSubtitle => '비주얼라이저가 표시되는 동안 화면이 어두워지거나 잠기지 않습니다';

  @override
  String get settingsVoiceNamesTitle => '보이스 이름';

  @override
  String get settingsVoiceNamesSubtitle => '각 보이스의 이름을 프레임 안에 표시합니다';

  @override
  String get settingsLineThickness => '선 굵기';

  @override
  String get settingsColors => '색상';

  @override
  String get settingsScopeVoiceColor => '보이스 오실로스코프';

  @override
  String get settingsStereoColors => '스테레오: 색상';

  @override
  String get settingsStereoMono => '모노';

  @override
  String get settingsStereoBi => '바이';

  @override
  String get settingsStereoMonoColor => '스테레오 (모노)';

  @override
  String get settingsStereoLeftColor => '스테레오 왼쪽';

  @override
  String get settingsStereoRightColor => '스테레오 오른쪽';

  @override
  String get settingsNotation => '노테이션 (노트)';

  @override
  String get settingsNotePalette => '색상 팔레트';

  @override
  String get settingsNoteBoxStyle => '블록 스타일';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'CRT 효과';

  @override
  String get settingsCrtGlow => '글로우';

  @override
  String get settingsCrtSpeed => '강도 / 속도';

  @override
  String get settingsArtworkOpacity => '배경 아트워크 불투명도';

  @override
  String get settingsProjectMTitle => 'projectM 설정';

  @override
  String get settingsProjectMSubtitle => '프리셋, 전환, 품질, Mesh…';

  @override
  String get settingsNotifyTrackTitle => '곡 변경 알림';

  @override
  String get settingsNotifyTrackSubtitle => '새 곡 제목을 시스템 알림으로 표시';

  @override
  String get settingsSilenceDetection => '무음 감지';

  @override
  String get settingsSilenceSkipTitle => '무음이면 다음 곡으로 넘어가기';

  @override
  String get settingsSilenceSkipSubtitle => '출력이 계속 무음이면 자동으로 넘어갑니다';

  @override
  String get settingsSilenceDelay => '무음 대기 시간';

  @override
  String get settingsDefaultDuration => '기본 재생 시간';

  @override
  String get settingsDefaultDurationHelp =>
      '곡의 재생 시간을 알 수 없을 때(태그 없음, 서버 메타데이터 없음) 사용되어 무한 재생이나 무한 반복을 막습니다. 자체 songlength 데이터베이스가 있는 Amiga 곡(UADE)에는 적용되지 않습니다.';

  @override
  String get settingsForcedLoopHeader => '강제 반복 / 페이드아웃';

  @override
  String get settingsForcedLoopHelp =>
      '일부 포맷은 특정 구간을 반복합니다(VGM, 트래커 모듈…). 그렇지 않은 포맷도 있습니다. \"무한\"은 곡의 자연스러운 끝을 무시합니다.';

  @override
  String get settingsForceLoopCount => '반복 횟수 강제';

  @override
  String get settingsLoopCount => '반복 횟수';

  @override
  String get settingsForceFadeout => '페이드아웃 강제';

  @override
  String get settingsFadeoutDuration => '페이드 길이';

  @override
  String get settingsResetEnginesTitle => '엔진 설정을 재설정할까요?';

  @override
  String get settingsResetEnginesBody => '모든 엔진 설정이 기본값으로 돌아갑니다.';

  @override
  String get settingsResetDefaultsTitle => '기본값으로 재설정';

  @override
  String get settingsResetDefaultsSubtitle => '모든 엔진';

  @override
  String get settingsDefaultDecoders => '기본 디코더';

  @override
  String get settingsDefaultDecodersSubtitle => '여러 엔진이 재생할 수 있는 포맷';

  @override
  String get settingsDecodersHelp =>
      '일부 포맷은 여러 엔진이 재생할 수 있습니다. 기본으로 사용할 엔진을 선택하세요 — 나머지 포맷은 자동으로 배정됩니다.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga 트래커 (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => '트래커 — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle => 'SPC, VGM(gme), KSS, AY… — EQ, 스테레오';

  @override
  String get settingsEngineNsfSubtitle => 'NES / NSF — 품질, 필터, 칩별 옵션';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — 하이패스 필터';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — 사용 중인 SoundFont';

  @override
  String get settingsEngineGsfSubtitle => 'GBA / GSF — 보간, 로우패스, 에코';

  @override
  String get settingsEngineUadeSubtitle => 'Amiga — 패닝, 헤드폰, 게인, LED';

  @override
  String get settingsEngineSidSubtitle => 'C64 / SID — 클럭, 모델, ReSIDfp 필터';

  @override
  String get settingsEngineAdplugSubtitle => 'AdLib OPL — 스테레오/서라운드 하모닉 모드';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, 리버브';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612, OPL3, QSound 코어…';

  @override
  String get settingsMasterVolume => '마스터 볼륨';

  @override
  String get settingsAmigaFilter => 'Amiga 필터';

  @override
  String get settingsInterpolation => '보간';

  @override
  String get settingsPolyphony => '폴리포니';

  @override
  String get settingsReverb => '리버브';

  @override
  String get settingsChorus => '코러스';

  @override
  String get settingsInterpNone => '없음';

  @override
  String get settingsInterpLinear => '선형';

  @override
  String get settingsInterpCubic => '큐빅';

  @override
  String get settingsInterpSinc => 'Sinc (최상)';

  @override
  String get settingsStereoSeparation => '스테레오 분리도';

  @override
  String get settingsGmeSilenceSubtitle => '엔진이 긴 무음을 감지하면 곡을 끝냅니다';

  @override
  String get settingsStereoDepth => '스테레오 깊이';

  @override
  String get settingsEqualizer => '이퀄라이저';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — SPC에는 적용되지 않음';

  @override
  String get settingsBass => '저음';

  @override
  String get settingsTreble => '고음';

  @override
  String get settingsAppliedLive => '재생 중에도 즉시 적용됩니다.';

  @override
  String get settingsAppliedNextTrack => '다음에 불러오는 곡부터 적용됩니다.';

  @override
  String get settingsSidEmulation => '에뮬레이션';

  @override
  String get settingsSidResidfp => 'ReSIDfp (정확)';

  @override
  String get settingsSidLite => 'SIDLite (빠름)';

  @override
  String get settingsSidSampling => '샘플링';

  @override
  String get settingsSidSamplingInterp => '보간 (빠름)';

  @override
  String get settingsSidSamplingResample => '리샘플 (최상)';

  @override
  String get settingsSidClock => '클럭';

  @override
  String get settingsSidModel => 'SID 모델';

  @override
  String get settingsSidFilter => 'SID 필터';

  @override
  String get settingsSidForceSecond => '2번째 SID 강제';

  @override
  String get settingsSidSecondSubtitle => '스테레오 2SID 곡';

  @override
  String get settingsSidSecondAddr => '2번째 SID 주소';

  @override
  String get settingsSidForceThird => '3번째 SID 강제';

  @override
  String get settingsSidThirdAddr => '3번째 SID 주소';

  @override
  String get settingsSidAutoFilter => '6581 필터 범위 자동';

  @override
  String get settingsSidAutoFilterSubtitle => '곡 작곡가에게 권장되는 값 (sidplayfp 표)';

  @override
  String get settingsSid6581Range => '6581 필터 범위';

  @override
  String get settingsSid6581Curve => '6581 필터 커브';

  @override
  String get settingsSid8580Curve => '8580 필터 커브';

  @override
  String get settingsSidNote =>
      'SID 필터와 커브는 즉시 적용됩니다. 에뮬레이션/샘플링/클럭/모델/2·3번째 SID는 다음 곡부터 적용됩니다.';

  @override
  String get settingsAudioOutput => '오디오 출력';

  @override
  String get settingsAdplugNote => '서라운드: 살짝 디튠된 OPL 칩 두 개. 다음 곡부터 적용됩니다.';

  @override
  String get settingsHeSpuMain => '메인 보이스 (SPU)';

  @override
  String get settingsHeSpuReverb => '리버브 (SPU)';

  @override
  String get settingsNsfQuality => '품질 (nsfplay)';

  @override
  String get settingsLowpassFilter => '로우패스 필터';

  @override
  String get settingsHighpassFilter => '하이패스 필터';

  @override
  String get settingsRegion => '지역';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC 강제';

  @override
  String get settingsNsfRegionPalForced => 'PAL 강제';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy 강제';

  @override
  String get settingsNsfForceIrq => 'IRQ 강제';

  @override
  String get settingsNsfApu1Title => '2A03 — 펄스 (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — 삼각파 / 노이즈 / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => '리셋 시 음소거 해제';

  @override
  String get settingsNsfPhaseRefresh => '위상 갱신';

  @override
  String get settingsNsfPhaseRefreshSubtitle => '주기를 쓸 때 위상을 리셋합니다';

  @override
  String get settingsNsfNonlinearMixer => '비선형 믹싱';

  @override
  String get settingsNsfApu1NonlinearSubtitle => '2A03의 실제 믹스 (끄면 선형)';

  @override
  String get settingsNsfDutySwap => '듀티 사이클 교체';

  @override
  String get settingsNsfDutySwapSubtitle => '25% / 50% 듀티의 순서';

  @override
  String get settingsNsfNegateSweep => '초기화 시 네거티브 스윕';

  @override
  String get settingsNsfEnable4011 => '\$4011 레지스터 활성화';

  @override
  String get settingsNsfEnable4011Subtitle => 'DAC 직접 출력 (원본의 클릭음)';

  @override
  String get settingsNsfPeriodicNoise => '주기적 노이즈';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => '노이즈 제너레이터의 숏 모드';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM 클릭 방지';

  @override
  String get settingsNsfRandomizeNoise => '초기화 시 노이즈 랜덤화';

  @override
  String get settingsNsfTriangleMute => '삼각파 음소거';

  @override
  String get settingsNsfTriangleMuteSubtitle => '초음파 주기에서 삼각파를 무음 처리합니다';

  @override
  String get settingsNsfRandomizeTri => '초기화 시 삼각파 랜덤화';

  @override
  String get settingsNsfDpcmReverse => 'DPCM 역재생';

  @override
  String get settingsNsfN163Serial => '직렬 멀티플렉싱';

  @override
  String get settingsNsfN163SerialSubtitle => '다중 보이스 곡에서 나는 실제 N163 버즈';

  @override
  String get settingsNsfN163PhaseReadOnly => '위상 읽기 전용';

  @override
  String get settingsNsfN163LimitWavelength => '파장 제한';

  @override
  String get settingsNsfFdsCutoff => '로우패스 컷오프';

  @override
  String get settingsNsfFds4085Reset => '\$4085 리셋';

  @override
  String get settingsNsfFdsWriteProtect => '쓰기 방지';

  @override
  String get settingsNsfVrc7Patch => '패치 세트';

  @override
  String get settingsNsfVrc7Opll => 'OPLL 모드';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'VRC7 대신 YM2413을 에뮬레이션합니다';

  @override
  String get settingsGbsHpFilter => '하이패스 필터 (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (클래식 GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => '에코';

  @override
  String get settingsUadePostfx => '후처리';

  @override
  String get settingsUadePostfxSubtitle => '이펙트 체인을 켭니다 (아래 항목에 모두 필요)';

  @override
  String get settingsUadePan => '패닝 (스테레오 분리)';

  @override
  String get settingsUadePanValue => '패닝 값';

  @override
  String get settingsUadeHeadphones => '헤드폰';

  @override
  String get settingsUadeLed => 'LED (Paula 필터)';

  @override
  String get settingsUadeLedAuto => '자동 (곡별)';

  @override
  String get settingsUadeLedOn => '항상 켬';

  @override
  String get settingsUadeLedOff => '항상 끔';

  @override
  String get settingsUadeFilterType => '필터 종류';

  @override
  String get settingsUadeGain => '게인';

  @override
  String get settingsUadeGainValue => '게인 값';

  @override
  String get settingsSoundfontLoading => '카탈로그 불러오는 중…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return '카탈로그를 사용할 수 없습니다 ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return '다운로드 실패: $error';
  }

  @override
  String get settingsSoundfontImport => 'SoundFont 가져오기…';

  @override
  String get settingsSoundfontImportSubtitle => '이 기기의 .sf2 파일 선택';

  @override
  String get settingsSoundfontImported => '가져옴';

  @override
  String get settingsSoundfontInvalid => '이 파일은 SoundFont(.sf2)가 아닙니다';

  @override
  String settingsSoundfontImportFailed(String error) {
    return '가져오기 실패 — $error';
  }

  @override
  String get settingsSoundfontDelete => '파일 삭제';

  @override
  String get settingsCreditsHeader => '크레딧 & 라이선스';

  @override
  String get settingsRightsNotice =>
      'Rewamp는 재생기입니다. 파일을 호스팅하지 않으며 음악을 배포하지도 않습니다. 곡은 온라인 보존 아카이브에서 제공되며 권리는 각 권리자에게 있습니다. 감상, 내려받기, 보관이 적용되는 권리와 거주 국가의 법규에 부합하는지 확인할 책임은 이용자에게 있습니다.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '포맷 $count개 지원',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '재생 엔진 $count개에 분산 — 자세히 보기',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga 재생 시간 & 메타데이터';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb — Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID 데이터 & 커버 아트';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — C64 게임 메타데이터와 이미지.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 글꼴';

  @override
  String get settingsFt2FontSubtitle =>
      '패턴 시각화 도구의 FastTracker II 스타일은 8bitbubsy의 ft2-clone(16-bits.org)에 있는 FT2 비트맵 글꼴을 사용합니다.';

  @override
  String settingsLinkCopied(String url) {
    return '$url 복사됨';
  }

  @override
  String get settingsOpenLink => '링크 열기';

  @override
  String get settingsEnginesHeader => '재생 엔진';

  @override
  String get settingsComponentsHeader => '기타 구성 요소';

  @override
  String get settingsResetAll => '모든 설정 재설정';

  @override
  String get settingsResetAllSubtitle => '일반, 비주얼라이제이션, 재생, 엔진 — 보관함은 제외';

  @override
  String get settingsResetAllTitle => '모든 설정을 재설정할까요?';

  @override
  String get settingsResetAllBody =>
      '일반, 비주얼라이제이션, 재생, 모든 엔진이 기본값으로 돌아갑니다. 보관함과 재생 기록은 그대로 유지됩니다.';

  @override
  String get settingsRenewUserId => '익명 ID 갱신';

  @override
  String get settingsRenewUserIdTitle => '익명 ID를 갱신할까요?';

  @override
  String get settingsRenewUserIdBody =>
      '서버 통계용 익명 ID가 새로 만들어집니다.\n\n기존 ID는 더 이상 사용되지 않습니다. 로컬 재생 기록과 즐겨찾기는 영향을 받지 않습니다.';

  @override
  String get settingsRenewUserIdFailed => '실패 — 서버에 연결할 수 없습니다';

  @override
  String settingsNewUserId(String id) {
    return '새 ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => '등록된 ID 없음';

  @override
  String get settingsCleanDb => '로컬 데이터베이스 정리';

  @override
  String get settingsCleanDbSubtitle =>
      '파일이 더 이상 없는 항목을 삭제합니다 (삭제된 다운로드, 예전 오류)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '고아 항목 $count개 삭제됨',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => '로컬 데이터베이스가 깨끗합니다 — 정리할 항목 없음';

  @override
  String get settingsClearCache => '캐시 비우기 (아트워크 & 메타데이터)';

  @override
  String get settingsClearCacheSubtitle =>
      '캐시된 커버와 받아온 메타데이터(STIL, 재생 시간)를 삭제합니다 — 다음 재생 때 다시 다운로드됩니다';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '캐시 비움 (커버 $count개)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => '통계 재설정';

  @override
  String get settingsResetStatsSubtitle => '재생 기록과 재생 횟수를 삭제합니다';

  @override
  String get settingsClearStatsTitle => '통계를 재설정할까요?';

  @override
  String get settingsClearStatsBody =>
      '다음 항목이 영구히 삭제됩니다:\n• 전체 재생 기록\n• 재생 횟수\n\n즐겨찾기와 보관함은 영향을 받지 않습니다.';

  @override
  String get settingsStatsCleared => '통계를 삭제했습니다';

  @override
  String get settingsResetDatabase => '데이터베이스 재설정';

  @override
  String get settingsResetDatabaseSubtitle => '전부 삭제: 재생 기록, 즐겨찾기, 재생목록, 캐시';

  @override
  String get settingsResetDbTitle => '데이터베이스를 재설정할까요?';

  @override
  String get settingsResetDbBody =>
      '다음 항목이 영구히 삭제됩니다:\n• 전체 재생 기록\n• 모든 카운터\n• 모든 즐겨찾기\n• 모든 재생목록\n• 캐시된 모든 메타데이터\n\n오디오 파일은 삭제되지 않습니다.';

  @override
  String get settingsDbReset => '데이터베이스를 재설정했습니다';

  @override
  String get settingsDeleteDownloads => '다운로드 삭제';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      '온라인 폴더의 모든 파일을 삭제합니다 (트랙, 아트워크)';

  @override
  String get settingsDeleteDownloadsTitle => '다운로드를 삭제할까요?';

  @override
  String get settingsDeleteDownloadsBody =>
      '온라인 폴더에서 다운로드한 모든 파일(트랙, 앨범, 아트워크)이 영구히 삭제됩니다.\n\n데이터베이스 항목은 남지만 존재하지 않는 파일을 가리키게 됩니다.';

  @override
  String get settingsDownloadsDeleted => '다운로드를 삭제했습니다';

  @override
  String get settingsColor => '색상';

  @override
  String get settingsPmPresets => '프리셋';

  @override
  String get settingsPmRandomNext => '다음 프리셋 무작위';

  @override
  String get settingsPmRandomNextSubtitle => '끄면 프리셋을 순서대로 재생합니다';

  @override
  String get settingsPmLockPreset => '프리셋 고정';

  @override
  String get settingsPmLockPresetSubtitle => '자동으로 바뀌지 않습니다';

  @override
  String get settingsPmPresetDuration => '프리셋 전환 간격';

  @override
  String get settingsPmTransitions => '전환';

  @override
  String get settingsPmBlend => '크로스페이드 전환';

  @override
  String get settingsPmBlendSubtitle => '끄면 프리셋이 즉시 바뀝니다';

  @override
  String get settingsPmTransitionStyle => '전환 스타일';

  @override
  String get settingsPmTransitionStyleSubtitle => '블렌드가 사용하는 패턴';

  @override
  String get settingsPmTransitionRandom => '무작위';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle => '비트에 맞춰 프리셋 전환';

  @override
  String get settingsPmHardcutTime => 'Hardcut: 최소 시간';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: 민감도';

  @override
  String get settingsPmRendering => '렌더링';

  @override
  String get settingsPmQuality => '품질';

  @override
  String get settingsPmQualitySubtitle => '렌더 해상도 (Max = 네이티브 해상도)';

  @override
  String get settingsPmBeatSensitivity => '비트 민감도';

  @override
  String get settingsPmAspectRatio => '화면 비율 유지';

  @override
  String get settingsPmAspectRatioSubtitle => '지원하는 셰이더에만 적용';

  @override
  String get settingsPmPermissive => '관대 모드';

  @override
  String get settingsPmPermissiveSubtitle => '스크립트 오류가 있는 .milk 파일도 불러옵니다';

  @override
  String get accountTitle => '계정';

  @override
  String get accountSubtitle => '라이브러리 저장 및 동기화';

  @override
  String get accountAnonymous => '익명 계정';

  @override
  String get accountAnonymousExplain =>
      '즐겨찾기와 재생 기록은 서버에 저장되지만 이 기기에서만 접근할 수 있습니다. 이메일 주소를 추가하면 다른 곳에서도 되찾을 수 있습니다.';

  @override
  String get accountEmailAttached => '주소 확인됨 — 이 계정은 복구할 수 있습니다';

  @override
  String get accountEmailPending => '주소가 아직 확인되지 않았습니다';

  @override
  String get accountInsecureStorage =>
      '이 기기의 보안 저장소를 사용할 수 없습니다. 계정 식별자가 암호화되지 않은 상태로 저장됩니다.';

  @override
  String get accountSaveCta => '내 계정 저장';

  @override
  String get accountStatSongs => '즐겨찾는 곡';

  @override
  String get accountStatAlbums => '즐겨찾는 앨범';

  @override
  String get accountStatPlays => '재생 횟수';

  @override
  String get accountCreatedLabel => '생성일';

  @override
  String get accountSignOut => '로그아웃';

  @override
  String get accountRevoke => '모든 기기에서 로그아웃';

  @override
  String get accountRevokeSubtitle => '다른 모든 기기를 로그아웃합니다';

  @override
  String get accountRevokeBody => '다른 모든 기기가 로그아웃됩니다. 이 기기는 로그인 상태를 유지합니다.';

  @override
  String get accountRevokeDone => '다른 기기에서 로그아웃했습니다';

  @override
  String get accountDelete => '계정 삭제';

  @override
  String get accountDeleteSubtitle => '서버의 계정과 데이터를 지웁니다. 되돌릴 수 없습니다.';

  @override
  String accountDeleteBody(int items, int lists) {
    return '서버에서 즐겨찾기 $items개와 재생목록 $lists개를 삭제합니다. 되돌릴 수 없습니다.';
  }

  @override
  String get accountDeleteKeepsLocal => '다운로드한 파일과 이 기기의 라이브러리는 영향을 받지 않습니다.';

  @override
  String get accountDeleteDone => '계정을 삭제했습니다';

  @override
  String get accountSignOutSubtitle => '이 기기는 비어 있는 새 계정으로 다시 시작합니다';

  @override
  String get accountSignOutTitle => '로그아웃할까요?';

  @override
  String accountSignOutBody(String email) {
    return '$email(으)로 보낸 코드로 이 계정에 다시 접속할 수 있습니다.';
  }

  @override
  String get accountSignedOut => '로그아웃됨';

  @override
  String get accountNoSignOut => '로그아웃을 사용할 수 없습니다';

  @override
  String get accountNoSignOutSubtitle => '이메일 주소가 없으면 이 계정은 영원히 사라집니다.';

  @override
  String get accountDetach => '주소 연결 해제';

  @override
  String get accountDetachSubtitle => '계정이 다시 익명이 되며 데이터는 삭제되지 않습니다';

  @override
  String get accountDetachBody => '주소가 없으면 다른 기기에서 이 계정을 되찾을 수 없습니다.';

  @override
  String get accountDetachDone => '주소 연결이 해제되었습니다';

  @override
  String get accountOffline => '오프라인에서는 계정을 사용할 수 없습니다';

  @override
  String get accountEmailTitle => '이메일 주소';

  @override
  String get accountEmailExplain => '주소 확인을 위해 6자리 코드를 보냅니다. 계정 복구에만 사용됩니다.';

  @override
  String get accountEmailLabel => '이메일 주소';

  @override
  String get accountCodeTitle => '확인 코드';

  @override
  String accountCodeExplain(String email) {
    return '$email(으)로 코드를 보냈습니다. 10분 동안 유효합니다.';
  }

  @override
  String get accountCodeLabel => '6자리 코드';

  @override
  String get accountSendCode => '코드 보내기';

  @override
  String get accountVerify => '확인';

  @override
  String get accountResend => '코드 다시 보내기';

  @override
  String accountResendIn(int n) {
    return '$n초 후 재전송';
  }

  @override
  String get accountCheckSpam => '메일이 도착하는 데 1분 정도 걸릴 수 있습니다 — 스팸함도 확인해 주세요.';

  @override
  String get accountErrorInvalidEmail => '올바르지 않은 주소입니다';

  @override
  String get accountErrorTooMany => '요청이 너무 많습니다. 몇 분 후에 다시 시도하세요';

  @override
  String get accountErrorInvalidCode => '코드가 틀렸거나 만료되었습니다';

  @override
  String get accountErrorCodeLength => '코드는 6자리입니다';

  @override
  String get accountErrorNetwork => '연결에 실패했습니다. 다시 시도하세요';

  @override
  String get accountMergeTitle => '이 라이브러리를 병합할까요?';

  @override
  String accountMergeBody(String email) {
    return '이 기기의 즐겨찾기와 재생 기록이 $email 계정에 추가됩니다. 되돌릴 수 없습니다.';
  }

  @override
  String get accountMergeConfirm => '병합';

  @override
  String get accountCarryLocal => '이 기기의 즐겨찾기 유지';

  @override
  String accountCarryLocalOn(int n) {
    return '이 기기의 즐겨찾기 $n개와 재생목록을 계정에 추가합니다.';
  }

  @override
  String get accountCarryLocalOff =>
      '이 기기에서 삭제하고 계정의 항목으로 대체합니다. 내려받은 파일은 유지됩니다.';

  @override
  String get accountDropLocalTitle => '이 기기의 데이터를 삭제할까요?';

  @override
  String get accountCreatedOk => '계정이 저장되었습니다. 라이브러리가 안전합니다';

  @override
  String get accountMergedOk => '로그인됨 — 로컬 즐겨찾기가 추가되었습니다';

  @override
  String get accountSignedInOk => '로그인됨';

  @override
  String get playlistEntryMissing => '이 기기에 파일이 없습니다';

  @override
  String get playlistEntryMissingRestorable => '파일 없음 — 다시 내려받을 수 있습니다';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n개 없음',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => '내 계정에 저장';

  @override
  String get playlistBackupSubtitle => '앱을 다시 설치해도 이 재생목록을 유지합니다';

  @override
  String get playlistBackupUpdate => '백업 업데이트';

  @override
  String get playlistBackupUpdateSubtitle => '계정의 사본을 이 버전으로 바꿉니다';

  @override
  String get playlistBackupStop => '저장 중지';

  @override
  String get playlistBackupStopped => '백업이 해제되었습니다';

  @override
  String get playlistBackupDone => '재생목록을 저장했습니다';

  @override
  String get playlistBackupFailed => '저장하지 못했습니다';

  @override
  String get playlistBackupNoAccount => '이 기기에 계정이 없습니다';

  @override
  String get playlistSyncTooltip => '내 계정과 동기화';

  @override
  String get playlistSyncRunning => '동기화 중…';

  @override
  String get playlistSyncDone => '재생목록을 동기화했습니다';

  @override
  String get playlistSyncPartial => '일부 재생목록을 저장하지 못했습니다';

  @override
  String get playlistFetchMissing => '없는 곡 내려받기';

  @override
  String get playlistFetchDone => '없는 곡을 내려받았습니다';

  @override
  String get playlistFetchPartial => '일부 곡을 내려받지 못했습니다';

  @override
  String get playlistEntryFetchFailed => '이 곡을 내려받지 못했습니다';

  @override
  String get accountStatPlaylists => '재생목록';

  @override
  String get accountSyncNow => '지금 동기화';

  @override
  String get accountSyncAuto => '백그라운드에서 자동으로 실행됩니다';

  @override
  String get accountSyncAnonymous => '서버에 백업됨. 다른 기기와 동기화하려면 이메일을 추가하세요.';

  @override
  String get accountSyncPending => '보낼 변경 사항이 남아 있습니다';

  @override
  String accountSyncLast(String when) {
    return '마지막 동기화: $when';
  }

  @override
  String get accountSyncDone => '동기화 완료';

  @override
  String get accountSyncFailed => '동기화 실패, 나중에 다시 시도합니다';

  @override
  String get podiumFirst => '1위';

  @override
  String get podiumSecond => '2위';

  @override
  String get podiumThird => '3위';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return '$production의 음악, $compo $place';
  }

  @override
  String podiumContains(String place, String compo) {
    return '$compo의 $place 수록';
  }

  @override
  String get competitionEmpty => '이 대회에는 출품작이 없습니다';

  @override
  String get competitionEntryNoMusic => '이 출품작의 음원이 카탈로그에 없습니다';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n곡',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingStart => '시작하기';

  @override
  String get onboardingBetaTitle => '베타 버전';

  @override
  String get onboardingBetaBody =>
      'Rewamp는 아직 개발 중입니다. 라이브러리, 재생목록, 즐겨찾기, 청취 통계 같은 로컬 데이터는 1.0 버전 전에 초기화될 수 있습니다. 내려받은 파일 자체는 안전하지만, 소중한 것은 따로 보관해 두세요.';

  @override
  String onboardingVersion(String version, String build) {
    return '버전 $version (빌드 $build)';
  }

  @override
  String get onboardingExploreTitle => '둘러보기';

  @override
  String get onboardingExploreBody =>
      '주요 온라인 아카이브에서 수만 곡의 칩튠과 트래커 모듈을 아티스트, 앨범, 플랫폼, 파티별로 찾아보세요. 눌러서 듣고, 내려받아 보관하세요.';

  @override
  String get onboardingLibraryTitle => '내 라이브러리';

  @override
  String get onboardingLibraryBody =>
      '마음에 드는 곡을 저장하고 재생목록을 만들어 폴더로 정리하세요. 내려받은 곡은 오프라인에서도 재생되고, 로그인하면 라이브러리가 기기 간에 따라옵니다.';

  @override
  String get onboardingPlayerTitle => '플레이어';

  @override
  String get onboardingPlayerBody =>
      '밀어서 곡을 바꾸고 시각화를 열어 보세요. 오실로스코프, 음색별 스코프, 흐르는 음표, 트래커 그리드. 여러 곡이 든 파일은 서브송을 보여주고, 각 음색은 따로 음소거할 수 있습니다.';

  @override
  String get onboardingReplayTitle => '둘러보기';

  @override
  String get onboardingReplaySubtitle => '베타 안내와 기능 소개를 다시 보기';

  @override
  String get settingsPatternTitle => '패턴';

  @override
  String get settingsPatternSubtitle => '트래커 그리드: 색상, 열, 스크롤';

  @override
  String get patternOpaqueBg => '불투명 배경';

  @override
  String get patternOpaqueBgSubtitle => '그리드 뒤의 커버를 가립니다';

  @override
  String get commonSave => '저장';

  @override
  String get accountDisplayName => '공개 이름';

  @override
  String get accountDisplayNameNotSet => '설정 안 됨 — 재생목록을 공개하려면 필요합니다';

  @override
  String get accountDisplayNameHint => '크레딧에 표시할 이름입니다.';

  @override
  String get accountDisplayNameChangeWarning =>
      '이름을 바꾸면 공개된 재생목록이 모두 다시 검토로 돌아갑니다.';

  @override
  String get accountDisplayNameTaken => '이미 사용 중인 이름입니다. 다른 이름을 고르세요.';

  @override
  String get accountDisplayNameLength => '2~40자.';

  @override
  String get accountDisplayNameSaved => '공개 이름을 저장했습니다';

  @override
  String accountDisplayNameBackInReview(int n) {
    return '검토로 돌아간 재생목록: $n';
  }

  @override
  String get playlistPublish => '공개하기';

  @override
  String get playlistPublishSubtitle => '공개 요청 (검토 후)';

  @override
  String get playlistPublishTitle => '이 재생목록을 공개할까요?';

  @override
  String get playlistPublishBody =>
      '승인되면 모두에게 보이며 공개 이름으로 표시됩니다. 커버는 수록곡에서 만들어집니다.';

  @override
  String get playlistPublishCta => '요청';

  @override
  String get playlistPublishSubmitted => '검토 요청을 보냈습니다';

  @override
  String get playlistPublishPending => '승인 대기 중';

  @override
  String get playlistPublishApproved => '공개됨';

  @override
  String playlistPublishRejected(String reason) {
    return '거절됨: $reason';
  }

  @override
  String get playlistPublishRejectedShort => '거절됨';

  @override
  String get playlistPublishNeedName => '크레딧에 표시할 이름을 고르세요';

  @override
  String get playlistPublishNeedTracks => '공개하려면 곡이 5개 이상 필요합니다';

  @override
  String get playlistPublishHasLocal =>
      '기기의 파일은 공개할 수 없습니다 — 다른 사람이 재생할 수 없습니다';

  @override
  String get playlistPublishTooManyPending => '이미 승인 대기 중인 재생목록이 3개 있습니다';

  @override
  String get playlistPublishRefused => '공개가 거절되었습니다: 곡과 대기 중인 요청을 확인하세요';

  @override
  String get playlistPublishFailed => '공개하지 못했습니다';

  @override
  String get playlistPublishWithdrawn => '재생목록이 다시 비공개가 되었습니다';

  @override
  String get playlistUnpublish => '비공개로 전환';

  @override
  String get playlistUnpublishSubtitle => '공개 재생목록에서 내립니다';

  @override
  String get playlistRenamePublishedTitle => '공개된 재생목록의 이름을 바꿀까요?';

  @override
  String get playlistRenamePublishedBody =>
      '검토 대상은 이름입니다. 이름을 바꾸면 재생목록은 다시 검토로 돌아가고 그동안 공개가 해제됩니다. 곡 추가나 순서 변경은 그렇지 않습니다.';

  @override
  String playlistByAuthor(String author) {
    return '$author';
  }

  @override
  String get settingsSpectrumMode => '스펙트럼 모드';

  @override
  String get settingsSpectrumModeStandard => '표준';

  @override
  String get settingsSpectrumModeColored => '컬러';

  @override
  String get settingsSpectrumModeBeam => '빔';

  @override
  String get settingsSpectrumModeLine => '라인';

  @override
  String get settingsSpectrumModeRing => '링';

  @override
  String get releaseNotesTitle => '새로운 기능';

  @override
  String get releaseNotesV4Downloads =>
      '다운로드: 긴 다운로드를 진행 중에 취소할 수 있고, 앨범 압축 파일을 여러 번 내려받지 않습니다.';

  @override
  String get releaseNotesV4Queue => '대기열: 확인을 거쳐 비우는 버튼 — 재생도 함께 멈춥니다.';

  @override
  String get releaseNotesV4DropFiles =>
      '창에 놓은 파일: 지금·다음·마지막에 재생 중에서 선택. 표지와 동반 파일은 제외되고, 압축 파일에 들어 있는 재생 목록을 따릅니다(실제 곡 이름, 빈 트랙 없음).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: 서버 제공 외에 기기에서 자신의 SoundFont를 가져올 수 있습니다.';

  @override
  String get releaseNotesV4Formats =>
      'Wwise, FSB, OGL 게임 스트림이 드디어 재생됩니다(자체 Vorbis).';

  @override
  String get releaseNotesV4Chips =>
      '사운드 칩 6종 추가, 칩별 에뮬레이션 코어 선택(게임보이는 SameBoy), 샘플 기반 칩의 음정도 정확해졌습니다.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: .vt2가 재생되고, 음표와 패턴 보기가 ZX 제품군 전체를 지원합니다.';

  @override
  String get releaseNotesV4Loop =>
      '한 곡 반복이 다시 불러오지 않고 실제로 반복되며, 무한 반복에서도 시간이 멈추지 않습니다.';

  @override
  String get releaseNotesV4Info =>
      'ⓘ 패널이 곡이 실제로 연 파일을 나열합니다 — 동반 파일과 라이브러리 포함.';

  @override
  String get releaseNotesV4Linux => '리눅스 데스크톱 버전.';

  @override
  String get releaseNotesDataReset =>
      '이번 베타를 위해 로컬 데이터를 초기화했습니다. 라이브러리와 재생목록은 계정에서 다시 구성되며, 다운로드는 다시 받아야 합니다.';

  @override
  String get releaseNotesDismiss => '계속';

  @override
  String get pmManagePresets => '프리셋 관리';

  @override
  String get pmPickTooltip => '프리셋 선택';

  @override
  String get pmPickFilter => '프리셋 필터';

  @override
  String get pmSourceTooltip => '프리셋 소스';

  @override
  String get pmAddToPlaylistTooltip => '프리셋을 재생목록에 추가';

  @override
  String pmSlowPresetDropped(String name) {
    return '「$name」은(는) 이 기기에 너무 무거워 제외했습니다.';
  }

  @override
  String get pmSlowDeviceTitle => '이 기기는 너무 느립니다';

  @override
  String get pmSlowDeviceOff => '비주얼라이저를 껐습니다. 이 기기는 Milkdrop 프리셋을 따라가지 못합니다.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프리셋 $count개 제외됨',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle => '이 기기에서 너무 느립니다. 재생 시 건너뜁니다.';

  @override
  String get settingsPmSlowPresetsRestore => '되돌리기';

  @override
  String get pmSourceBundled => '기본 제공 프리셋';

  @override
  String get pmSourceImports => '내가 가져온 프리셋';

  @override
  String get pmSourceAll => '모든 프리셋';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프리셋 $count개',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => '새 재생목록…';

  @override
  String get pmPlaylistName => '재생목록 이름';

  @override
  String get pmAddedToPlaylist => '재생목록에 추가했습니다';

  @override
  String get pmAlreadyInPlaylist => '이미 이 재생목록에 있습니다';

  @override
  String get pmTabPacks => '팩';

  @override
  String get pmTabBrowse => '둘러보기';

  @override
  String get pmTabPlaylists => '재생목록';

  @override
  String get pmTabPopular => '인기';

  @override
  String get pmTabSetAside => '제외됨';

  @override
  String get pmSetAsideEmpty =>
      '제외된 항목이 없습니다. 이 기기가 6 fps 아래로 떨어지는 프리셋이 여기 모입니다.';

  @override
  String get pmSetAsideRestoreAll => '모두 되돌리기';

  @override
  String get pmInstall => '설치';

  @override
  String get pmInstallQueued => '설치 대기 중';

  @override
  String get pmUninstall => '제거';

  @override
  String get pmUninstalled => '팩을 제거했습니다';

  @override
  String get pmUse => '사용';

  @override
  String get pmDefaultPackBanner => '추천 스타터 팩';

  @override
  String pmLicense(String license) {
    return '라이선스: $license';
  }

  @override
  String get pmPacksOffline => '서버에 연결할 수 없습니다';

  @override
  String get pmSearchPresets => '프리셋 검색…';

  @override
  String get pmPlayNow => '지금 재생';

  @override
  String get pmDownloadAction => '다운로드';

  @override
  String get pmDownloaded => '프리셋을 다운로드했습니다';

  @override
  String get pmDownloadFailed => '다운로드 실패';

  @override
  String pmPreviewing(String name) {
    return '재생 중: $name';
  }

  @override
  String get pmLocalSection => '내 재생목록';

  @override
  String get pmCuratedSection => 'Rewamp 재생목록';

  @override
  String get pmImportPlaylist => '다운로드하여 사용';

  @override
  String get pmPlaylistImported => '재생목록이 준비되었습니다';

  @override
  String get pmImportFiles => '파일 가져오기…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프리셋 $count개를 가져왔습니다',
      zero: '가져온 프리셋이 없습니다',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => '프리셋을 projectM 라이브러리에 추가했습니다';

  @override
  String get pmNoPlaylists => '아직 프리셋 재생목록이 없습니다';

  @override
  String get pmSourceApplied => '프리셋 소스를 적용했습니다';

  @override
  String get pmPlaylistEmpty => '이 재생목록은 비어 있습니다';

  @override
  String get pmDays7 => '7일';

  @override
  String get pmDays30 => '30일';

  @override
  String get pmDays365 => '1년';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count회 재생',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => '설치에 실패했습니다';

  @override
  String get pmSingleDownloads => '개별 다운로드';

  @override
  String pmAvailableIn(String pack) {
    return '$pack에 포함';
  }

  @override
  String get pmCleanUp => '정리';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프리셋 $count개 삭제됨',
      zero: '정리할 항목 없음',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => '이 프리셋 잠금';

  @override
  String get pmUnlockAction => '프리셋 잠금 해제';

  @override
  String get pmOrderRandom => '프리셋 무작위';

  @override
  String get pmOrderSequential => '프리셋 순서대로';

  @override
  String get pmUpdateAvailable => '업데이트 있음';

  @override
  String get pmUpdate => '업데이트';

  @override
  String get pmSelectAll => '전체 선택';

  @override
  String get pmSelectNone => '선택 해제';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => '사용하지 않는 텍스처';

  @override
  String pmTexturesFreed(String size) {
    return '$size 확보됨';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '텍스처 $count개',
    );
    return '$_temp0';
  }
}
