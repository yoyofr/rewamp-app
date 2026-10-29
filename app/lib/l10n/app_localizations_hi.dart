// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get navHome => 'होम';

  @override
  String get navSearch => 'खोजें';

  @override
  String get navLocal => 'लोकल';

  @override
  String get settingsTabsOrderTitle => 'टैब का क्रम';

  @override
  String get settingsTabsOrderSubtitle =>
      'क्रम बदलने के लिए खींचें। पहले चार नीचे की बार में दिखते हैं; बाकी “अधिक” में रहते हैं।';

  @override
  String get settingsTabsInBar => 'बार में';

  @override
  String get settingsTabsInMore => '“अधिक” में';

  @override
  String get settingsLaunchTab => 'शुरुआत का टैब';

  @override
  String get settingsLaunchTabSubtitle => 'ऐप किस टैब पर खुले';

  @override
  String get navLibrary => 'लाइब्रेरी';

  @override
  String get noFileSelected => 'कोई फ़ाइल नहीं चुनी गई';

  @override
  String get openFile => 'फ़ाइल खोलें';

  @override
  String get pickerLabelAudio => 'ऑडियो';

  @override
  String get formatNotSupported => 'फ़ॉर्मैट समर्थित नहीं है';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'असमर्थित फ़ॉर्मैट: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'इस डिवाइस पर नहीं है: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'फ़ाइल अब सर्वर पर नहीं है: $file';
  }

  @override
  String playbackTrackNotInArchive(String file) {
    return '$file एल्बम के आर्काइव में नहीं है — रिप इसे सूची में दिखाता है पर साथ नहीं देता।';
  }

  @override
  String playbackSourceTimeout(String host) {
    return '$host ने जवाब नहीं दिया। अपना कनेक्शन जाँचें, फिर दोबारा कोशिश करें।';
  }

  @override
  String get failedToLoadFile => 'फ़ाइल लोड नहीं हो सकी';

  @override
  String get libraryEmptyHint =>
      'आपके आर्टिस्ट, एल्बम और प्लेलिस्ट\nयहाँ दिखेंगे।';

  @override
  String get libraryPlaylists => 'प्लेलिस्ट';

  @override
  String get libraryArtists => 'आर्टिस्ट';

  @override
  String get libraryAlbums => 'एल्बम';

  @override
  String get libraryTracks => 'ट्रैक';

  @override
  String get libraryFavorites => 'पसंदीदा';

  @override
  String get libraryFavoritesSubtitle => 'आपके पसंदीदा ट्रैक की ऑटो-प्लेलिस्ट';

  @override
  String get libraryRecentlyAdded => 'हाल ही में जोड़े गए';

  @override
  String get libraryEmpty => 'यहाँ अभी कुछ नहीं है';

  @override
  String get libraryRemoved => 'लाइब्रेरी से हटाया गया';

  @override
  String get searchHint => 'खोजें…';

  @override
  String get searchTypePlaceholder => 'शीर्षक, आर्टिस्ट या एल्बम लिखें…';

  @override
  String get searchNoResults => 'कोई परिणाम नहीं';

  @override
  String get searchDownloading => 'डाउनलोड हो रहा है…';

  @override
  String searchError(String message) {
    return 'त्रुटि: $message';
  }

  @override
  String get tabAll => 'ट्रैक';

  @override
  String get tabArtists => 'आर्टिस्ट';

  @override
  String get tabAlbums => 'एल्बम';

  @override
  String get tabProductions => 'प्रोडक्शन';

  @override
  String get filterWithVideo => 'वीडियो के साथ';

  @override
  String get videoUnavailable => 'यह वीडियो उपलब्ध नहीं है';

  @override
  String get noItems => 'कोई आइटम नहीं';

  @override
  String get sortRelevance => 'प्रासंगिकता';

  @override
  String get sortAZ => 'A–Z';

  @override
  String get recentlyPlayed => 'हाल ही में चलाए गए';

  @override
  String get noRecentTracks => 'हाल ही में कोई ट्रैक नहीं चलाया गया';

  @override
  String get playerSourceLocal => 'लोकल';

  @override
  String get homePlayFiles => 'फ़ाइलें चलाएँ';

  @override
  String get homePlayFolder => 'फ़ोल्डर चलाएँ';

  @override
  String get homeSectionsOrderTitle => 'सेक्शन का क्रम';

  @override
  String get homeSectionsOrderSubtitle =>
      'होम स्क्रीन को अपनी पसंद से सजाने के लिए खींचें।';

  @override
  String get homeSectionsOrderReset => 'डिफ़ॉल्ट क्रम';

  @override
  String get homeSectionsOrderSettings => 'होम सेक्शन का क्रम';

  @override
  String countTotal(int loaded, String total) {
    return '$loaded / $total परिणाम';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded लोड हुए…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded परिणाम';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded लोड हुए — और देखने के लिए स्क्रॉल करें';
  }

  @override
  String countNLoaded(int n) {
    return '$n लोड हुए';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n फ़ाइल(ें)';
  }

  @override
  String get browseFilterByTitle => 'शीर्षक से फ़िल्टर करें…';

  @override
  String get browseNoSongs => 'कोई गाना उपलब्ध नहीं';

  @override
  String get browseByFormat => 'फ़ॉर्मैट के अनुसार';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'फ़ॉर्मैट से फ़िल्टर करें…';

  @override
  String get browseByPlatform => 'प्लेटफ़ॉर्म के अनुसार';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'प्लेटफ़ॉर्म का नाम…';

  @override
  String get browseByChip => 'साउंड चिप के अनुसार';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'जैसे YM2612, SPC700…';

  @override
  String get browseOk => 'ठीक है';

  @override
  String get browseByArtist => 'आर्टिस्ट के अनुसार';

  @override
  String get browseByArtistSubtitle => 'कंपोज़र देखें';

  @override
  String get browseFilterByName => 'नाम से फ़िल्टर करें…';

  @override
  String get browseNoArtistFound => 'कोई आर्टिस्ट नहीं मिला';

  @override
  String get browseNoArtistsAvailable => 'कोई आर्टिस्ट उपलब्ध नहीं';

  @override
  String get browseNoArtist => 'कोई आर्टिस्ट नहीं';

  @override
  String get browseNoAlbum => 'कोई एल्बम नहीं';

  @override
  String get browseTopPacks => 'टॉप पैक';

  @override
  String get browseTopPacksSubtitle => 'सबसे ज़्यादा रेटिंग वाले पैक';

  @override
  String browseTopPacksLabel(String collection) {
    return 'टॉप पैक — $collection';
  }

  @override
  String get browseLatestPacks => 'नए पैक';

  @override
  String get browseLatestPacksSubtitle => 'सबसे हाल में जोड़े गए';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'नए पैक — $collection';
  }

  @override
  String get browseAllSongs => 'सभी गाने';

  @override
  String get browseAllSongsSubtitleAlpha => 'वर्णानुक्रम में देखें';

  @override
  String get browseAlphabetical => 'वर्णानुक्रम में';

  @override
  String browseAllLabel(String collection) {
    return 'सभी — $collection';
  }

  @override
  String get browseCollections => 'कलेक्शन';

  @override
  String browseFilesCount(String count) {
    return '$count फ़ाइलें';
  }

  @override
  String get browseIndexing => 'इंडेक्सिंग जारी है';

  @override
  String browseFilterFacet(String name) {
    return '$name फ़िल्टर करें…';
  }

  @override
  String get browseAllYears => 'सभी साल';

  @override
  String get browseAllYearsSubtitle => 'पार्टी के सभी गाने';

  @override
  String get browseNoCompo => 'इस पार्टी के लिए कोई कॉम्पो इंडेक्स नहीं है।';

  @override
  String get browseOthers => 'अन्य';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n एंट्री — रैंकिंग',
      one: '$n एंट्री — रैंकिंग',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'प्लेलिस्ट चलाएँ';

  @override
  String get browsePlayAllRanked => 'सब चलाएँ (रैंकिंग के क्रम में)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्रैक — रैंकिंग क्रम',
      one: '$n ट्रैक — रैंकिंग क्रम',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'एल्बम के अनुसार देखें';

  @override
  String get browsePlayAll => 'सब चलाएँ';

  @override
  String get browseShuffle => 'शफ़ल';

  @override
  String get browseSearchInFolder => 'इस फ़ोल्डर में खोजें…';

  @override
  String get browseFilterThisList => 'इस सूची को फ़िल्टर करें…';

  @override
  String get browseSearchSubfolders => 'सबफ़ोल्डर में खोजें';

  @override
  String get browseEmptyFolder => 'खाली फ़ोल्डर';

  @override
  String browsePlaybackError(String message) {
    return 'प्लेबैक विफल: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्रैक',
      one: '$n ट्रैक',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'व्यू';

  @override
  String get browseViewList => 'सूची';

  @override
  String get browseViewGrid => 'ग्रिड';

  @override
  String get browseViewGridCompact => 'कॉम्पैक्ट ग्रिड';

  @override
  String get browseSearchAlbum => 'एल्बम खोजें…';

  @override
  String get browseSearchArtist => 'आर्टिस्ट खोजें…';

  @override
  String get browsePlayAlbum => 'एल्बम चलाएँ';

  @override
  String get searchDownloadingAlbum => 'एल्बम डाउनलोड हो रहा है…';

  @override
  String get searchCategoryChip => 'चिप';

  @override
  String get searchCategoryGroup => 'ग्रुप';

  @override
  String get artistRealName => 'असली नाम';

  @override
  String get artistAliases => 'उपनाम';

  @override
  String get artistBorn => 'जन्म';

  @override
  String get artistInterview => 'इंटरव्यू';

  @override
  String get audioOutput => 'ऑडियो आउटपुट';

  @override
  String get audioOutputSystemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get vizRangeAuto => 'ऑटो';

  @override
  String get contextNotes => 'नोट्स';

  @override
  String get notePlacedBadge => 'प्रतियोगिता में स्थान मिला';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '$count सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'गाने देखें';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मॉड्यूल',
      one: '$count मॉड्यूल',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'पार्टी';

  @override
  String get searchCategoryYear => 'साल';

  @override
  String get searchCategoryOrigin => 'मूल';

  @override
  String get searchCategoryProduction => 'प्रोडक्शन';

  @override
  String get searchCategoryProductionType => 'प्रोड के प्रकार';

  @override
  String get searchCategoryPublisher => 'पब्लिशर';

  @override
  String get searchCategoryDeveloper => 'डेवलपर';

  @override
  String get searchCategoryArcadeBoard => 'आर्केड बोर्ड';

  @override
  String get searchCategorySaga => 'सीरीज़';

  @override
  String get searchCategoryGenre => 'शैली';

  @override
  String get searchViaArtist => 'आर्टिस्ट के ज़रिए';

  @override
  String get searchViaAlbum => 'किसी एल्बम के ज़रिए';

  @override
  String get searchViaSong => 'किसी गाने के ज़रिए';

  @override
  String get searchSortPopular => 'लोकप्रिय';

  @override
  String get searchSortYear => 'साल';

  @override
  String get searchSortRandom => 'रैंडम';

  @override
  String get searchSortRating => 'रेटिंग';

  @override
  String statsTopPercent(int percent) {
    return 'टॉप $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वोट',
      one: '$count वोट',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'बढ़ते क्रम में';

  @override
  String get searchSortDesc => 'घटते क्रम में';

  @override
  String get searchFilters => 'फ़िल्टर';

  @override
  String get searchExactSearch => 'सटीक खोज';

  @override
  String get searchExactSearchSubtitle => 'अनुमानित (fuzzy) खोज बंद करता है';

  @override
  String get searchTags => 'टैग';

  @override
  String searchTagSearchHint(String category) {
    return '« $category » में टैग खोजें…';
  }

  @override
  String get searchTagTypeToSearch => 'टैग खोजने के लिए लिखें।';

  @override
  String get searchTagsAndLogic => 'कई टैग = लॉजिकल AND।';

  @override
  String get searchFilterYear => 'साल';

  @override
  String get searchFilterAll => 'सभी';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'साल से फ़िल्टर करने पर बिना तारीख वाले गाने छूट जाते हैं।';

  @override
  String get searchMinRating => 'रेटिंग ≥';

  @override
  String get searchPodium => 'पोडियम';

  @override
  String get searchPodiumAny => 'कोई भी पोडियम';

  @override
  String get searchPodiumUnavailable =>
      'पोडियम फ़िल्टर अभी सर्वर पर उपलब्ध नहीं है';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'रद्द करें';

  @override
  String get searchReset => 'रीसेट करें';

  @override
  String get searchApply => 'लागू करें';

  @override
  String get searchClearRecent => 'हाल की खोजें मिटाएँ';

  @override
  String get searchBrowse => 'ब्राउज़ करें';

  @override
  String get searchBrowseHint =>
      'कैटलॉग देखने के लिए कोई फ़ैसेट (ग्रुप, चिप, साल…) चुनें, या ऊपर से रेडियो/सरप्राइज़ शुरू करें।';

  @override
  String get searchDidYouMean => 'कम परिणाम — अनुमानित खोज आज़माएँ?';

  @override
  String get searchYes => 'हाँ';

  @override
  String get featuredCommunityTitle => 'कम्युनिटी से नया';

  @override
  String get searchPlaylistSourceAll => 'सभी';

  @override
  String get searchPlaylistSourceUser => 'कम्युनिटी';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'फ़ॉर्मैट';

  @override
  String get searchPlatform => 'प्लेटफ़ॉर्म';

  @override
  String get filterCollection => 'कलेक्शन';

  @override
  String get videoWatchDemo => 'डेमो देखें';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'कलेक्शन: $name';
  }

  @override
  String get searchCollectionAll => 'सभी';

  @override
  String get searchRadio => 'रेडियो';

  @override
  String get searchRadioTooltip => 'मौजूदा फ़िल्टर पर रैंडम क्यू';

  @override
  String get searchSurprise => 'सरप्राइज़';

  @override
  String get searchSurpriseTooltip => 'एक रैंडम गाना';

  @override
  String searchTabWithCount(String label, String count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'कोई गाना नहीं';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n गाने',
      one: '$n गाना',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n एल्बम',
      one: '$n एल्बम',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'उर्फ़ $name';
  }

  @override
  String get searchChooseCollection => 'कलेक्शन चुनें';

  @override
  String get searchFilterCollections => 'कलेक्शन फ़िल्टर करें…';

  @override
  String get searchFilterPlaceholder => 'फ़िल्टर करें…';

  @override
  String searchAllOf(String label) {
    return 'सभी ($label)';
  }

  @override
  String get searchNoMatch => 'कोई मेल नहीं';

  @override
  String get searchNoPlaylist => 'कोई प्लेलिस्ट नहीं';

  @override
  String get engineDescOpenmpt => 'ट्रैकर मॉड्यूल (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescXmp =>
      'वे मॉड्यूल जिन्हें libopenmpt नहीं पढ़ सकता (.musx, .liq, .fnk…)';

  @override
  String get engineDescVgm => 'VGM/S98/GYM/DRO — साउंड चिप, हर चैनल का स्कोप';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN आर्काइव';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — हर चैनल की आवाज़ें';

  @override
  String get engineDescGbsplay => 'Game Boy GBS/GBR';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp इंजन)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX चिपट्यून (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace => 'मल्टी-चिप चिपट्यून .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      '68k एमुलेशन से Amiga कस्टम-चिप फ़ॉर्मैट (~320 एक्सटेंशन)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'स्टैंडर्ड MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ सिंथ (16 आवाज़ें)';

  @override
  String get engineDescV2m => 'V2M सिंथ (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — असली 68000 एमुलेशन + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300 एमुलेशन + RSP ऑडियो';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ एमुलेशन';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound चिप';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 => 'ZX Spectrum .pt3 — असली AY-3-8910/YM2149 सिंथ';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixel का अपना इंजन';

  @override
  String get engineDescNtgs =>
      'Apple IIGS (Ensoniq 5503) — NoiseTracker GS मॉड्यूल';

  @override
  String get engineDescRonKlaren => 'Amiga — Ron Klaren मॉड्यूल (.rk)';

  @override
  String get engineDescSamCop =>
      'SAM Coupé — SAA1099 चलाने वाले Z80 प्रोग्राम (.cop)';

  @override
  String get engineDescPxtone => 'Pixel का ट्रैकर — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — emu68 से असली 68000';

  @override
  String get engineDescPmd =>
      'PC-98 Professional Music Driver — OPNA FM + SSG + PPZ8 सैंपल';

  @override
  String get engineDescMdx => 'Sharp X68000 — .mdx (+ .pdx सैंपल), YM2151 FM';

  @override
  String get engineDescFmp =>
      'PC-98 FMP ड्राइवर — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Towns EUPHONY — YM2612 FM + PCM (.eup)';

  @override
  String get engineDescMac => 'लॉसलेस .ape';

  @override
  String get engineDescVgmstream =>
      'स्ट्रीम किए गए गेम ऑडियो फ़ॉर्मैट (700+, .rrds सहित)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — फ़ॉलबैक डिकोडर';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total गाने',
      one: '$loaded / $total गाना',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total एल्बम',
      one: '$loaded / $total एल्बम',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total आर्टिस्ट',
      one: '$loaded / $total आर्टिस्ट',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n गाने',
      one: '$n गाना',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n एल्बम',
      one: '$n एल्बम',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n आर्टिस्ट',
      one: '$n आर्टिस्ट',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ग्रुप',
      one: '$n ग्रुप',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'देश';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n देश',
      one: '$n देश',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'फ़ोल्डर';

  @override
  String get featuredTitle => 'आज की खास पेशकश';

  @override
  String featuredPartyNow(String party) {
    return '$party अभी चल रही है — पिछले संस्करणों के पोडियम';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$party $days दिनों में शुरू होगी — पिछले संस्करणों के पोडियम',
      one: '$party कल शुरू होगी — पिछले संस्करणों के पोडियम',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series का सीज़न — पिछले संस्करणों के पोडियम';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return '$month $year में रिलीज़';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age साल पहले: $year के गेम',
      one: '$age साल पहले: $year के गेम',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade का दशक';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age साल पहले: $year के गेम',
      one: '$age साल पहले: $year के गेम',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return '$month में रिलीज़';
  }

  @override
  String get featuredAnniversaryHeader => 'सालगिरह';

  @override
  String get featuredBirthdayHeader => 'आज के जन्मदिन';

  @override
  String get featuredBirthdayWeekHeader => 'इस हफ़्ते के जन्मदिन';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return 'इस हफ़्ते $artist का जन्मदिन';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्लेलिस्ट',
      one: '$count प्लेलिस्ट',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'फिर से कोशिश करें';

  @override
  String get commonOptions => 'विकल्प';

  @override
  String get commonDownload => 'डाउनलोड करें';

  @override
  String get commonDeleteDownload => 'डाउनलोड हटाएँ';

  @override
  String get commonAddToPlaylist => 'प्लेलिस्ट में जोड़ें';

  @override
  String get commonPlayNext => 'इसके बाद चलाएँ';

  @override
  String get commonAddToQueueEnd => 'क्यू के अंत में जोड़ें';

  @override
  String get commonAddToFavorites => 'पसंदीदा में जोड़ें';

  @override
  String get commonRemoveFromFavorites => 'पसंदीदा से हटाएँ';

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
  String get subsongDeleteDownloadTitle => 'यह डाउनलोड हटाएँ?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'फ़ाइल और उसकी लोकल एंट्री (हिस्ट्री, ट्रैक) हटा दी जाएँगी।\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'ट्रैक पढ़े नहीं जा सके';

  @override
  String subsongTrackNumber(int number) {
    return 'ट्रैक $number';
  }

  @override
  String get subsongDefaultTrack => 'डिफ़ॉल्ट ट्रैक';

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सबसॉन्ग',
      one: '$count सबसॉन्ग',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'सब चलाएँ';

  @override
  String get albumDownloading => 'एल्बम डाउनलोड हो रहा है…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'एल्बम डाउनलोड हो रहा है… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'ट्रैक देखने के लिए एल्बम डाउनलोड करें';

  @override
  String get albumNotDownloadedHint =>
      'एल्बम डाउनलोड नहीं हुआ — डाउनलोड करने के लिए प्लेबैक शुरू करें';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ट्रैक',
      one: '$count ट्रैक',
    );
    return '$_temp0';
  }

  @override
  String playChoiceSkippedShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count छोटे छोड़े गए',
      one: '$count छोटा छोड़ा गया',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'जानकारी लोड हो रही है…';

  @override
  String albumAka(String label) {
    return 'उर्फ़ $label';
  }

  @override
  String get albumPlayAlbum => 'एल्बम चलाएँ';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम',
      one: '$count आइटम',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'डाउनलोड करने के लिए पहले यह ट्रैक खोज से चलाएँ';

  @override
  String get libraryAddedTrack => 'ट्रैक आपकी लाइब्रेरी में जोड़ा गया';

  @override
  String get libraryAddedAlbum => 'एल्बम आपकी लाइब्रेरी में जोड़ा गया';

  @override
  String get libraryAddedArtist => 'आर्टिस्ट आपकी लाइब्रेरी में जोड़ा गया';

  @override
  String get libraryRemovedTrack => 'ट्रैक आपकी लाइब्रेरी से हटाया गया';

  @override
  String get libraryRemovedAlbum => 'एल्बम आपकी लाइब्रेरी से हटाया गया';

  @override
  String get libraryRemovedArtist => 'आर्टिस्ट आपकी लाइब्रेरी से हटाया गया';

  @override
  String get libraryImportBeforeAddTitle => 'पहले इम्पोर्ट करें?';

  @override
  String get libraryImportBeforeAddBody =>
      'यह फ़ाइल एक अस्थायी जगह से चल रही है जिसे सिस्टम मिटा सकता है। इसे अपनी लोकल लाइब्रेरी में इम्पोर्ट करें ताकि एंट्री बनी रहे?';

  @override
  String get libraryImportBeforeAddArchiveBody =>
      'यह ट्रैक एक अस्थायी कैश में खोले गए आर्काइव से है। पूरा आर्काइव, साथी फ़ाइलों सहित, आपकी लोकल लाइब्रेरी में इम्पोर्ट किया जाएगा।';

  @override
  String get libraryAddNeedsCatalogueId =>
      'यह ट्रैक नहीं जोड़ा जा सकता: इस डिवाइस पर इसकी कैटलॉग id अज्ञात है।';

  @override
  String songTilePlayFailed(String message) {
    return 'प्लेबैक विफल: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'डाउनलोड विफल — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'डाउनलोड हो रहा है — $label';
  }

  @override
  String get downloadsTitle => 'डाउनलोड';

  @override
  String get downloadsEmpty => 'कोई डाउनलोड बाकी नहीं';

  @override
  String get downloadsPause => 'रोकें';

  @override
  String get downloadsResume => 'फिर शुरू करें';

  @override
  String get downloadsCancel => 'डाउनलोड रद्द करें';

  @override
  String get downloadsClear => 'सब हटाएँ';

  @override
  String get downloadsPausedBanner =>
      'डाउनलोड रुके हुए हैं — मौजूदा फ़ाइल पहले पूरी होगी';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'डाउनलोड हो रहा है — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'प्लेलिस्ट';

  @override
  String get miniPlayerHideQueue => 'प्लेलिस्ट छिपाएँ';

  @override
  String get transportShuffle => 'शफ़ल';

  @override
  String get transportShuffleOn => 'शफ़ल चालू';

  @override
  String get transportLoopOff => 'लूप बंद';

  @override
  String get transportLoopQueue => 'लूप: कतार';

  @override
  String get transportLoopTrack => 'लूप: मौजूदा ट्रैक';

  @override
  String get vizStereo => 'स्टीरियो';

  @override
  String get vizSpectrum => 'स्पेक्ट्रम';

  @override
  String get vizVoices => 'वॉइस';

  @override
  String get vizNotes => 'नोट्स';

  @override
  String get vizPiano => 'पियानो';

  @override
  String get vizPatterns => 'पैटर्न';

  @override
  String get patternScrollMode => 'स्क्रॉल मोड';

  @override
  String get patternSmoothScroll => 'स्मूद स्क्रॉलिंग';

  @override
  String get patternPinnedRow => 'चल रही पंक्ति स्थिर';

  @override
  String get patternVolumeBars => 'वॉल्यूम बार';

  @override
  String get patternColorScheme => 'रंग योजना';

  @override
  String get patternSize => 'आकार';

  @override
  String get patternColumns => 'कॉलम';

  @override
  String get patternColumnsAll => 'पूरा';

  @override
  String get patternColumnsNoteInstr => 'संक्षिप्त';

  @override
  String get patternColumnsNote => 'न्यूनतम';

  @override
  String get vizClose => 'विज़ुअलाइज़र बंद करें';

  @override
  String get vizFullscreen => 'फ़ुलस्क्रीन';

  @override
  String get vizExitFullscreen => 'फ़ुलस्क्रीन से बाहर निकलें';

  @override
  String get vizPrevPreset => 'पिछला प्रीसेट';

  @override
  String get vizNextPreset => 'अगला प्रीसेट';

  @override
  String get vizProjectmUnavailable => 'projectM उपलब्ध नहीं';

  @override
  String get voicesTitle => 'वॉइस';

  @override
  String get voicesSpeed => 'गति';

  @override
  String get voicesSpeedNormal => 'सामान्य गति';

  @override
  String get voicesSpeedNative => 'इंजन टेम्पो — पिच वही रहती है';

  @override
  String get voicesSpeedResampled => 'रीसैंपल — पिच भी बदलती है';

  @override
  String get voicesNone => 'इस ट्रैक के लिए कोई वॉइस नहीं।';

  @override
  String get voicesLongPressSolo => 'देर तक दबाएँ = सोलो';

  @override
  String get voicesMuteAll => 'सभी म्यूट करें';

  @override
  String get voicesUnmuteAll => 'सभी अनम्यूट करें';

  @override
  String get voicesStereoOutput => 'स्टीरियो आउटपुट';

  @override
  String get voicesLeft => 'बायाँ';

  @override
  String get voicesRight => 'दायाँ';

  @override
  String get enginesFormatsTitle => 'चलाए जा सकने वाले फ़ॉर्मेट';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats चलाए जा सकने वाले फ़ॉर्मेट, $engines प्लेबैक इंजन में।';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ॉर्मेट',
      one: '$count फ़ॉर्मेट',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return '$artist के $title का कवर';
  }

  @override
  String stilCover(String work) {
    return '$work का कवर';
  }

  @override
  String get playerQueue => 'कतार';

  @override
  String get queueEdit => 'संपादित करें';

  @override
  String get queueEditDone => 'हो गया';

  @override
  String get queueClear => 'कतार खाली करें';

  @override
  String get queueAutoplayOn =>
      'ऑटोप्ले चालू: कतार के बाद मिलते-जुलते ट्रैक बजेंगे';

  @override
  String get queueAutoplayOff => 'ऑटोप्ले बंद';

  @override
  String get queueAutoplayRow => 'ऑटोप्ले द्वारा जोड़ा गया';

  @override
  String get queueClearConfirmTitle => 'कतार खाली करें?';

  @override
  String get queueClearConfirmBody =>
      'कतार खाली हो जाएगी और प्लेबैक रुक जाएगा।';

  @override
  String get queueClearConfirm => 'खाली करें';

  @override
  String get queueRemoveSelected => 'चुने हुए हटाएँ';

  @override
  String get queueRemoveTrack => 'कतार से हटाएँ';

  @override
  String get queueReorder => 'क्रम बदलें';

  @override
  String get playerArtwork => 'आर्टवर्क';

  @override
  String get playerVisualizer => 'विज़ुअलाइज़र';

  @override
  String get playerVoices => 'वॉइस';

  @override
  String get playerTrackInfo => 'ट्रैक जानकारी';

  @override
  String get playerShowQueue => 'प्लेलिस्ट';

  @override
  String get playerHideQueue => 'प्लेलिस्ट छिपाएँ';

  @override
  String get playerNoTrackInfo => 'कोई जानकारी उपलब्ध नहीं।';

  @override
  String get playerViewSubsongs => 'सबसॉन्ग देखें';

  @override
  String get playerViewAlbum => 'एल्बम देखें';

  @override
  String get playerViewArtist => 'कलाकार देखें';

  @override
  String get playerAddToPlaylist => 'प्लेलिस्ट में जोड़ें';

  @override
  String get playerEngineSettings => 'इंजन सेटिंग्स';

  @override
  String get queueAddToPlaylist => 'कतार को प्लेलिस्ट में जोड़ें';

  @override
  String get playerMoreOptions => 'और विकल्प';

  @override
  String get playerClose => 'बंद करें';

  @override
  String get playerCancel => 'रद्द करें';

  @override
  String get playerDelete => 'हटाएँ';

  @override
  String get playerAddFavorite => 'पसंदीदा में जोड़ें';

  @override
  String get playerRemoveFavorite => 'पसंदीदा से हटाएँ';

  @override
  String get playerAddToLibrary => 'लाइब्रेरी में जोड़ें';

  @override
  String get playerRemoveFromLibrary => 'लाइब्रेरी से हटाएँ';

  @override
  String get playerAddedToLibrary => 'ट्रैक लाइब्रेरी में जोड़ा गया';

  @override
  String get playerRemovedFromLibrary => 'ट्रैक लाइब्रेरी से हटाया गया';

  @override
  String get playerDeleteDownload => 'डाउनलोड हटाएँ';

  @override
  String get playerRedownload => 'फ़ाइल फिर से डाउनलोड करें';

  @override
  String get playerRedownloadUnavailable =>
      'इस फ़ाइल को फिर से डाउनलोड नहीं किया जा सकता';

  @override
  String get playerDeleteDownloadTitle => 'डाउनलोड हटाएँ?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'फ़ाइल और उसकी लोकल एंट्री (हिस्ट्री, ट्रैक) हटा दी जाएँगी।\n\n$path';
  }

  @override
  String get homeYourTrends => 'आपके ट्रेंड';

  @override
  String get homeYourAllTimeTop => 'आपके अब तक के टॉप';

  @override
  String get homeTrending => 'ट्रेंडिंग';

  @override
  String get homeFeaturedPlaylists => 'फ़ीचर्ड प्लेलिस्ट';

  @override
  String get homeAllTimeTop => 'अब तक के टॉप';

  @override
  String get homePeriod7d => '7 दिन';

  @override
  String get homePeriod30d => '30 दिन';

  @override
  String get homePeriod90d => '90 दिन';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n प्ले',
      one: '$n प्ले',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्रैक',
      one: '$n ट्रैक',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'खाली या अपठनीय प्लेलिस्ट';

  @override
  String get homeExtractingArchive => 'आर्काइव एक्सट्रैक्ट हो रहा है…';

  @override
  String get homeArchiveEmpty => 'आर्काइव में चलाने योग्य कोई फ़ाइल नहीं';

  @override
  String get homeNothingPlayable => 'चयन में चलाने योग्य कुछ नहीं';

  @override
  String get homeAlbumLoadFailed => 'यह एल्बम लोड नहीं हो सका';

  @override
  String get homeSongLoadFailed => 'यह ट्रैक लोड नहीं हो सका';

  @override
  String get navStats => 'आँकड़े';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get playlistMoveUp => 'पैरेंट फ़ोल्डर में ले जाएँ';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n प्लेलिस्ट',
      one: '$n प्लेलिस्ट',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n सबफ़ोल्डर',
      one: '$n सबफ़ोल्डर',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'यह फ़ोल्डर और इसके अंदर का सब कुछ हमेशा के लिए हटा दिया जाएगा:';

  @override
  String get playlistDeleteFolderEmptyBody => 'यह फ़ोल्डर हटा दिया जाएगा।';

  @override
  String get playlistFolderRoot => 'रूट';

  @override
  String get playlistMoveToFolder => 'फ़ोल्डर में ले जाएँ';

  @override
  String playlistDeleteTitle(String name) {
    return '\"$name\" हटाएँ?';
  }

  @override
  String get playlistDeleteBody => 'यह प्लेलिस्ट हमेशा के लिए हटा दी जाएगी।';

  @override
  String get playlistRenameFolderTitle => 'फ़ोल्डर का नाम बदलें';

  @override
  String get playlistClearFavorites => 'सभी पसंदीदा हटाएँ';

  @override
  String get playlistClearFavoritesTitle => 'सभी पसंदीदा हटाएँ?';

  @override
  String get playlistClearFavoritesBody =>
      'आपके सभी पसंदीदा ट्रैक हट जाएँगे। इसे वापस नहीं किया जा सकता।';

  @override
  String get playlistRemoveFromLibrary => 'लाइब्रेरी से हटाएँ';

  @override
  String get playlistServerReadOnly => 'सर्वर प्लेलिस्ट · केवल पढ़ने के लिए';

  @override
  String get navAbout => 'परिचय';

  @override
  String get navMore => 'और';

  @override
  String get shellAlbumQueuedAtEnd => 'एल्बम कतार के अंत में जोड़ा गया';

  @override
  String get shellAlbumQueuedNext => 'एल्बम आगे चलेगा';

  @override
  String get shellAddingToQueue => 'कतार में जोड़ा जा रहा है…';

  @override
  String get shellAddingNext => 'आगे चलाने के लिए जोड़ा जा रहा है…';

  @override
  String shellDownloadFailed(String error) {
    return 'डाउनलोड विफल: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ट्रैक कतार में जोड़े गए',
      one: '$count ट्रैक कतार में जोड़ा गया',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" कतार के अंत में जोड़ा गया';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" आगे चलेगा';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'डाउनलोड विफल: $title — अगले ट्रैक पर जा रहे हैं';
  }

  @override
  String get shellNetworkUnavailable =>
      'प्लेबैक रुक गया: नेटवर्क उपलब्ध नहीं लगता।';

  @override
  String get statsTitle => 'आँकड़े';

  @override
  String statsPeriodDays(int n) {
    return '$n दिन';
  }

  @override
  String get statsPeriodThisYear => 'इस साल';

  @override
  String get statsPeriodAll => 'अब तक';

  @override
  String get statsByMonthOrYear => 'महीने / साल के अनुसार…';

  @override
  String get statsByYear => 'साल के अनुसार';

  @override
  String get statsByMonth => 'महीने के अनुसार';

  @override
  String get statsPlaysLabel => 'प्ले';

  @override
  String get statsTracksLabel => 'ट्रैक';

  @override
  String get statsArtistsLabel => 'कलाकार';

  @override
  String get statsAlbumsLabel => 'एल्बम';

  @override
  String get statsListenTime => 'सुनने का समय';

  @override
  String get statsByCollection => 'संग्रह के अनुसार';

  @override
  String get statsByFormat => 'फ़ॉर्मेट के अनुसार';

  @override
  String get statsByEngine => 'इंजन के अनुसार';

  @override
  String get statsPlaylistsLabel => 'प्लेलिस्ट';

  @override
  String get statsLocalFilesSection => 'डाउनलोड की गई फ़ाइलें';

  @override
  String get statsFilesLabel => 'फ़ाइलें';

  @override
  String get statsSpaceLabel => 'डिस्क स्पेस';

  @override
  String get statsNoPlaysInPeriod => 'इस अवधि में कोई प्ले नहीं';

  @override
  String get statsNoPlays => 'कोई प्ले नहीं';

  @override
  String get statsTopTracks => 'टॉप ट्रैक';

  @override
  String get statsTopAlbums => 'टॉप एल्बम';

  @override
  String get statsTopArtists => 'टॉप कलाकार';

  @override
  String statsTopTracksIn(String period) {
    return 'टॉप ट्रैक — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'टॉप एल्बम — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'टॉप कलाकार — $period';
  }

  @override
  String get statsSeeAll => 'सभी देखें';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n प्ले',
      one: '$n प्ले',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्रैक',
      one: '$n ट्रैक',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'अधिकतम $n';
  }

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonCreate => 'बनाएँ';

  @override
  String get commonOk => 'ठीक है';

  @override
  String get commonDelete => 'हटाएँ';

  @override
  String get commonRename => 'नाम बदलें';

  @override
  String get commonSort => 'क्रमबद्ध करें';

  @override
  String get commonPlayAll => 'सभी चलाएँ';

  @override
  String get sortName => 'नाम';

  @override
  String get sortTitle => 'शीर्षक';

  @override
  String get sortArtist => 'कलाकार';

  @override
  String get sortAlbum => 'एल्बम';

  @override
  String get sortDateAdded => 'जोड़ने की तारीख';

  @override
  String get commonClear => 'साफ़ करें';

  @override
  String get sortRecentlyModified => 'हाल ही में बदले गए';

  @override
  String get sortCreationDate => 'बनाने की तारीख';

  @override
  String get playlistNameHint => 'नाम';

  @override
  String get playlistNew => 'नई प्लेलिस्ट';

  @override
  String get playlistNewFolder => 'नया फ़ोल्डर';

  @override
  String get playlistNewTooltip => 'नई प्लेलिस्ट / फ़ोल्डर';

  @override
  String get playlistAddTo => 'प्लेलिस्ट में जोड़ें';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n प्लेलिस्ट में जोड़ें',
      one: '$n प्लेलिस्ट में जोड़ें',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'एक प्लेलिस्ट चुनें';

  @override
  String get playlistFilterHint => 'प्लेलिस्ट फ़िल्टर करें…';

  @override
  String get playlistSearchHint => 'प्लेलिस्ट खोजें…';

  @override
  String get playlistNoMatch => 'कोई मिलती-जुलती प्लेलिस्ट नहीं';

  @override
  String get playlistNoneCreateHint => 'कोई प्लेलिस्ट नहीं — + से एक बनाएँ';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्रैक',
      one: '$n ट्रैक',
      zero: 'कोई ट्रैक नहीं',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'पहले से मौजूद';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n आइटम चुनी गई प्लेलिस्ट में पहले से हैं।',
      one: '$n आइटम चुनी गई प्लेलिस्ट में पहले से है।',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'डुप्लिकेट छोड़ें';

  @override
  String get playlistAddAgain => 'फिर से जोड़ें';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्रैक जोड़े गए',
      one: '$n ट्रैक जोड़ा गया',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m प्लेलिस्ट',
      one: '$n प्लेलिस्ट',
    );
    return '$_temp0 — $_temp1 में';
  }

  @override
  String playlistAddFailed(String error) {
    return 'जोड़ा नहीं जा सका: $error';
  }

  @override
  String get playlistRenameTitle => 'प्लेलिस्ट का नाम बदलें';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'फ़ोल्डर “$name” हटाएँ?';
  }

  @override
  String get playlistDeleteFolderBody => 'इसकी सामग्री एक स्तर ऊपर चली जाएगी।';

  @override
  String get playlistEmpty => 'खाली प्लेलिस्ट';

  @override
  String get trackOptionsAddToLibrary => 'लाइब्रेरी में जोड़ें';

  @override
  String get trackOptionsRemoveFromLibrary => 'लाइब्रेरी से हटाएँ';

  @override
  String get trackOptionsAddedToLibrary => 'ट्रैक लाइब्रेरी में जोड़ा गया';

  @override
  String get trackOptionsRemovedFromLibrary => 'ट्रैक लाइब्रेरी से हटाया गया';

  @override
  String get trackOptionsViewAlbum => 'एल्बम देखें';

  @override
  String get trackOptionsViewArtist => 'कलाकार देखें';

  @override
  String get trackOptionsPlayNow => 'अभी चलाएँ';

  @override
  String get trackOptionsPlayNext => 'आगे चलाएँ';

  @override
  String get trackOptionsAddToQueueEnd => 'कतार के अंत में जोड़ें';

  @override
  String get trackOptionsPlayLast => 'आख़िर में चलाएँ';

  @override
  String get trackOptionsDeleteDownload => 'डाउनलोड हटाएँ';

  @override
  String get trackOptionsDeleteDownloadTitle => 'यह डाउनलोड हटाएँ?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'फ़ाइल और उसकी लोकल एंट्री (हिस्ट्री, ट्रैक) हटा दी जाएँगी।\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'डाउनलोड हटाया गया';

  @override
  String get trackOptionsAddToFavorites => 'पसंदीदा में जोड़ें';

  @override
  String get trackOptionsRemoveFromFavorites => 'पसंदीदा से हटाएँ';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'एल्बम पसंदीदा में जोड़ा गया';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'एल्बम पसंदीदा से हटाया गया';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'एल्बम डाउनलोड नहीं हुआ — हटाने के लिए कुछ नहीं';

  @override
  String get trackOptionsDeleteAlbumTitle => 'डाउनलोड किया गया एल्बम हटाएँ?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'फ़ोल्डर और उसकी सभी लोकल एंट्री (ट्रैक, हिस्ट्री) हटा दी जाएँगी।\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted => 'एल्बम लोकल स्टोरेज से हटाया गया';

  @override
  String get trackOptionsRedownloadAlbum => 'एल्बम फिर से डाउनलोड करें';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'फ़ाइलें और लोकल एंट्री दोनों फिर से लिखी जाएँगी';

  @override
  String get trackOptionsDeleteAlbumFiles => 'एल्बम फ़ाइलें हटाएँ';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'डाउनलोड किया गया फ़ोल्डर + लोकल एंट्री (हिस्ट्री)';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsGeneral => 'सामान्य';

  @override
  String get settingsGeneralSubtitle => 'थीम';

  @override
  String get settingsVisualisation => 'विज़ुअलाइज़ेशन';

  @override
  String get settingsVisualisationSubtitle => 'ऑसिलोस्कोप, आर्टवर्क बैकग्राउंड';

  @override
  String get settingsPlayback => 'प्लेबैक';

  @override
  String get settingsPlaybackSubtitle => 'लूप, फ़ेड-आउट, साइलेंस';

  @override
  String get settingsEngines => 'इंजन';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'डेटा';

  @override
  String get settingsDataSubtitle => 'ID, हिस्ट्री, रीसेट';

  @override
  String get settingsBackupExport => 'बैकअप एक्सपोर्ट करें';

  @override
  String get settingsBackupExportSubtitle =>
      'अपनी लाइब्रेरी, प्लेलिस्ट और सेटिंग्स एक फ़ाइल में सहेजें';

  @override
  String get settingsBackupImport => 'बैकअप इम्पोर्ट करें';

  @override
  String get settingsBackupImportSubtitle =>
      'बैकअप फ़ाइल से अपना डेटा वापस लाएँ';

  @override
  String get settingsBackupExportFailed => 'बैकअप एक्सपोर्ट विफल';

  @override
  String get settingsBackupImportConfirmTitle => 'बैकअप इम्पोर्ट करें?';

  @override
  String get settingsBackupImportConfirmBody =>
      'इससे इस डिवाइस पर आपकी लाइब्रेरी, प्लेलिस्ट और सेटिंग्स बदल जाएँगी। डाउनलोड की गई फ़ाइलें बनी रहेंगी।';

  @override
  String get settingsBackupImportConfirm => 'इम्पोर्ट करें';

  @override
  String get settingsBackupImportedTitle => 'बैकअप इम्पोर्ट हुआ';

  @override
  String get settingsBackupImportedBody =>
      'आपका डेटा वापस आ गया है। सब कुछ लागू करने के लिए ऐप रीस्टार्ट करें।';

  @override
  String get settingsBackupTooNew => 'यह बैकअप ऐप के नए वर्ज़न से बनाया गया है';

  @override
  String get settingsBackupInvalid => 'मान्य Rewamp बैकअप नहीं है';

  @override
  String get settingsBackupImportFailed => 'बैकअप इम्पोर्ट विफल';

  @override
  String get settingsAbout => 'परिचय';

  @override
  String get settingsAboutSubtitle => 'क्रेडिट और लाइसेंस';

  @override
  String get settingsCreditsSubtitle => 'लाइब्रेरी, डेटा और कंपोनेंट';

  @override
  String get settingsSupport => 'संपर्क और सहायता';

  @override
  String get settingsSupportSubtitle => 'हमसे संपर्क करें, वेबसाइट';

  @override
  String get settingsSupportEmail => 'ईमेल भेजें';

  @override
  String get settingsSupportEmailSubtitle => 'सवाल, बग या सुझाव';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — सहायता';

  @override
  String get settingsSupportEmailIntro =>
      'ऊपर अपना सवाल, बग या सुझाव लिखें। नीचे दी गई जानकारी से हमें आपकी मदद करने में आसानी होगी।';

  @override
  String get settingsSupportWebsite => 'वेबसाइट';

  @override
  String get settingsDonation => 'Rewamp का समर्थन करें';

  @override
  String get settingsDonationSubtitle => 'चाहें तो कुछ टिप दें';

  @override
  String get settingsDonationBlurb =>
      'Rewamp मुफ़्त और विज्ञापन-रहित है — डेमोसीन और रेट्रो संस्कृति को सहेजने के लिए प्यार से बनाया गया। टिप से ऐप के विकास और डेटाबेस होस्टिंग का खर्च चलता है। कोई ज़रूरी नहीं: अगर ऐप आपको खुशी देता है, तो छोटा-सा योगदान भी हमेशा सराहा जाता है।';

  @override
  String get settingsDonationFloppy => 'एक फ़्लॉपी डिस्क';

  @override
  String get settingsDonationCartridge => 'एक कार्ट्रिज';

  @override
  String get settingsDonationBox => 'एक बॉक्स वाला गेम';

  @override
  String get settingsDonationCustom => 'राशि चुनें';

  @override
  String get settingsCancel => 'रद्द करें';

  @override
  String get settingsOk => 'ठीक है';

  @override
  String get settingsDelete => 'हटाएँ';

  @override
  String get settingsReset => 'रीसेट करें';

  @override
  String get settingsRenew => 'नवीनीकरण करें';

  @override
  String get settingsOff => 'बंद';

  @override
  String get settingsOn => 'चालू';

  @override
  String get settingsAuto => 'ऑटो';

  @override
  String get settingsInfinite => 'अनंत';

  @override
  String get settingsDefault => 'डिफ़ॉल्ट';

  @override
  String get settingsCoreNoScope => 'ऑसिलोस्कोप नहीं';

  @override
  String get settingsNone => 'कोई नहीं';

  @override
  String get settingsLevelLow => 'कम';

  @override
  String get settingsLevelHigh => 'ज़्यादा';

  @override
  String get settingsStereo => 'स्टीरियो';

  @override
  String get settingsSurround => 'सराउंड';

  @override
  String settingsValuePercent(int value) {
    return '$value%';
  }

  @override
  String settingsValueSeconds(int value) {
    return '$value से.';
  }

  @override
  String settingsValueSecondsFrac(String value) {
    return '$value से.';
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
  String get settingsTheme => 'थीम';

  @override
  String get settingsThemeLight => 'लाइट';

  @override
  String get settingsThemeDark => 'डार्क';

  @override
  String get settingsArtworkTintTitle => 'आर्टवर्क के रंग से प्लेयर रंगें';

  @override
  String get settingsArtworkTintSubtitle => 'प्लेयर कवर का मुख्य रंग अपनाता है';

  @override
  String get settingsGlassEffectTitle => 'लिक्विड ग्लास इफ़ेक्ट';

  @override
  String get settingsGlassEffectSubtitle =>
      'नीचे की बार पर लेंस और ब्लर — धीमे डिवाइस पर बंद करें';

  @override
  String get settingsResetSection => 'यह सेक्शन रीसेट करें';

  @override
  String get settingsResetEngine => 'यह इंजन रीसेट करें';

  @override
  String get settingsResetChoices => 'ये विकल्प रीसेट करें';

  @override
  String get settingsResetToDefault => 'डिफ़ॉल्ट मान';

  @override
  String get settingsStartInVizTitle => 'विज़ुअलाइज़र मोड में शुरू करें';

  @override
  String get settingsStartInVizSubtitle =>
      'प्लेयर आर्टवर्क के बजाय ऑसिलोस्कोप पर खुलता है';

  @override
  String get settingsVoiceGridTitle => 'वॉइस ऑसिलोस्कोप ग्रिड';

  @override
  String get settingsVoiceGridSubtitle =>
      'हर वॉइस को अलग करने वाली सीमाएँ दिखाएँ';

  @override
  String get settingsKeepAwakeTitle => 'स्क्रीन चालू रखें';

  @override
  String get settingsKeepAwakeSubtitle =>
      'विज़ुअलाइज़र दिखते समय डिस्प्ले मंद या लॉक नहीं होता';

  @override
  String get settingsVoiceNamesTitle => 'वॉइस के नाम';

  @override
  String get settingsVoiceNamesSubtitle =>
      'हर वॉइस का नाम उसके फ़्रेम में दिखाएँ';

  @override
  String get settingsLineThickness => 'लाइन की मोटाई';

  @override
  String get settingsScopeVoiceColor => 'वॉइस ऑसिलोस्कोप';

  @override
  String get settingsStereoColors => 'स्टीरियो: रंग';

  @override
  String get settingsStereoMono => 'मोनो';

  @override
  String get settingsStereoBi => 'दोहरा';

  @override
  String get settingsStereoMonoColor => 'स्टीरियो (मोनो)';

  @override
  String get settingsStereoLeftColor => 'स्टीरियो बायाँ';

  @override
  String get settingsStereoRightColor => 'स्टीरियो दायाँ';

  @override
  String get settingsNotePalette => 'रंग पैलेट';

  @override
  String get settingsNoteBoxStyle => 'ब्लॉक स्टाइल';

  @override
  String get settingsNoteStyleFlat => 'सपाट';

  @override
  String get settingsNoteStyleBox => 'बॉक्स';

  @override
  String get settingsVizAll => 'सभी विज़ुअलाइज़र';

  @override
  String get settingsVizScopes => 'ऑसिलोस्कोप (स्टीरियो और हर वॉइस के लिए)';

  @override
  String get settingsVizFrameRate => 'फ़्रेम रेट';

  @override
  String get settingsVizFrameRateScreen => 'स्क्रीन';

  @override
  String settingsValueFps(int value) {
    return '$value fps';
  }

  @override
  String get settingsCrtSpeed => 'तीव्रता / गति';

  @override
  String get settingsArtworkOpacity => 'बैकग्राउंड आर्टवर्क की अपारदर्शिता';

  @override
  String get settingsProjectMTitle => 'projectM सेटिंग्स';

  @override
  String get settingsProjectMSubtitle => 'प्रीसेट, ट्रांज़िशन, क्वालिटी, मेश…';

  @override
  String get settingsNotifyTrackTitle => 'ट्रैक बदलने की सूचनाएँ';

  @override
  String get settingsNotifyTrackSubtitle =>
      'नए ट्रैक के टाइटल के साथ सिस्टम सूचना';

  @override
  String get settingsSilenceDetection => 'साइलेंस पहचान';

  @override
  String get settingsCrossfade => 'क्रॉसफ़ेड';

  @override
  String get localActionPlay => 'फ़ाइलें या फ़ोल्डर चलाएँ';

  @override
  String get localActionImport => 'फ़ाइलें या फ़ोल्डर इम्पोर्ट करें';

  @override
  String localOpsImporting(String name) {
    return '$name इम्पोर्ट हो रहा है…';
  }

  @override
  String get localOpsImportingSelection =>
      'चुनी गई फ़ाइलें इम्पोर्ट हो रही हैं…';

  @override
  String localOpsDeleting(String name) {
    return '$name डिलीट हो रहा है…';
  }

  @override
  String get localOpsPhaseCopying => 'कॉपी हो रहा है';

  @override
  String get localOpsPhaseExtracting => 'एक्सट्रैक्ट हो रहा है';

  @override
  String get localOpsPhaseRegistering => 'लाइब्रेरी में जोड़ा जा रहा है';

  @override
  String get localOpsPhaseDeleting => 'फ़ाइलें हटाई जा रही हैं';

  @override
  String localOpsScanning(String name) {
    return '$name स्कैन हो रहा है…';
  }

  @override
  String get localOpsPhaseScanning => 'फ़ाइलें सूचीबद्ध हो रही हैं';

  @override
  String get linkedRootsSection => 'लिंक किए गए फ़ोल्डर';

  @override
  String get linkedRootAppFolder => 'Rewamp फ़ोल्डर (फ़ाइलें ऐप)';

  @override
  String get linkedRootAppFolderHint =>
      'अपनी फ़ाइलें फ़ाइलें ऐप › मेरे iPhone पर › Rewamp में रखें, या Finder से किसी कंप्यूटर से कॉपी करें। वे वहीं से चलती हैं, कुछ भी कॉपी नहीं होता।';

  @override
  String get linkedRootsLink => 'फ़ोल्डर लिंक करें…';

  @override
  String get linkedRootsLinkSubtitle =>
      'जहाँ है वहीं से चलता है, कुछ भी कॉपी नहीं होता';

  @override
  String linkedRootsSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें',
      one: '$count फ़ाइल',
      zero: 'अभी कोई फ़ाइल सूचीबद्ध नहीं',
    );
    return '$_temp0';
  }

  @override
  String get linkedRootUnavailable => 'अभी उपलब्ध नहीं';

  @override
  String get linkedRootRescan => 'रीफ़्रेश करें';

  @override
  String get linkedRootRename => 'नाम बदलें';

  @override
  String get linkedRootUnlink => 'अनलिंक करें';

  @override
  String get linkedRootUnlinkConfirmTitle => 'इस फ़ोल्डर को अनलिंक करें?';

  @override
  String get linkedRootUnlinkConfirmBody =>
      'डिस्क से कुछ भी नहीं हटाया जाता। इसके पसंदीदा और प्लेलिस्ट प्रविष्टियाँ बनी रहती हैं, और दोबारा लिंक होने तक धुंधली दिखती हैं।';

  @override
  String get linkedRootEmpty => 'इस फ़ोल्डर में चलाने योग्य कोई फ़ाइल नहीं है।';

  @override
  String get linkedRootSearchHint => 'इस फ़ोल्डर में खोजें';

  @override
  String linkedRootSearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मेल',
      one: '$count मेल',
      zero: 'कोई मेल नहीं',
    );
    return '$_temp0';
  }

  @override
  String get localImportFiles => 'फ़ाइलें इम्पोर्ट करें';

  @override
  String get storageLocalImports => 'लोकल इम्पोर्ट';

  @override
  String get settingsVgmJapaneseTags => 'जापानी टैग (GD3)';

  @override
  String get settingsVgmJapaneseTagsHelp =>
      'VGM टैग में जापानी टाइटल/गेम/आर्टिस्ट फ़ील्ड हों तो उन्हें प्राथमिकता दें।';

  @override
  String get settingsVgmLoopFade => 'लूप वाले ट्रैक के अंत में फ़ेड';

  @override
  String get settingsVgmLoopFadeHelp =>
      'VGM फ़ॉर्मेट में फ़ेड-आउट नहीं होता: लूप वाला ट्रैक अपना लूप दो बार चलाता है, फिर इतने समय में फ़ेड होता है। बंद = सीधे रुक जाता है। बिना लूप वाले ट्रैक जैसे लिखे हैं वैसे ही ख़त्म होते हैं।';

  @override
  String get localImportFolder => 'फ़ोल्डर इम्पोर्ट करें';

  @override
  String get localLibraryTitle => 'इस डिवाइस पर';

  @override
  String get libraryOnAnotherDevice => 'दूसरे डिवाइस पर';

  @override
  String get libraryHideElsewhere =>
      'जो आइटम इस डिवाइस पर नहीं हैं उन्हें छिपाएँ';

  @override
  String get localLibraryEmpty =>
      'अभी तक कोई लोकल इम्पोर्ट नहीं। होम से “फ़ाइलें इम्पोर्ट करें” या “फ़ोल्डर इम्पोर्ट करें” का इस्तेमाल करें।';

  @override
  String queueLimitReached(int count) {
    return 'क्यू पहले $count ट्रैक तक सीमित है';
  }

  @override
  String localDeleteTrackConfirm(String name) {
    return '“$name” डिलीट करें? फ़ाइल और उसकी साथी फ़ाइलें (आर्टवर्क…) हटा दी जाएँगी।';
  }

  @override
  String localDeleteFolderConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'फ़ोल्डर “$name” और उसके $count ट्रैक डिलीट करें?',
      one: 'फ़ोल्डर “$name” और उसका $count ट्रैक डिलीट करें?',
    );
    return '$_temp0';
  }

  @override
  String localImportDone(int count) {
    return '$count ट्रैक लाइब्रेरी में इम्पोर्ट हुए';
  }

  @override
  String localImportDoneAlbums(int tracks, int albums) {
    return '$tracks ट्रैक इम्पोर्ट हुए — $albums एल्बम';
  }

  @override
  String localImportFailed(String error) {
    return 'इम्पोर्ट विफल: $error';
  }

  @override
  String get settingsCrossfadeHelp =>
      'हर ट्रैक के अंत को अगले की शुरुआत में मिला देता है। 0 पर भी प्लेबैक बिना गैप के रहता है।';

  @override
  String get settingsMinSubsongSection => 'छोटे सबसॉन्ग';

  @override
  String get settingsMinSubsongTitle => 'न्यूनतम लंबाई';

  @override
  String get settingsMinSubsongHelp =>
      'इससे छोटे सबसॉन्ग सूची और क्यू से बाहर रहते हैं — गेम फ़ाइल में अक्सर संगीत से ज़्यादा साउंड इफ़ेक्ट होते हैं। 0 पर कुछ नहीं हटता; जिस लंबाई को डिकोडर नहीं बता सकता उसे कभी छोटा नहीं माना जाता।';

  @override
  String get localNewFolder => 'नया फ़ोल्डर';

  @override
  String get localFolderName => 'फ़ोल्डर का नाम';

  @override
  String get localRename => 'नाम बदलें';

  @override
  String get localMoveTo => 'यहाँ ले जाएँ…';

  @override
  String get localMove => 'ले जाएँ';

  @override
  String get localMoveNothing => 'कुछ नहीं ले जाया गया';

  @override
  String get localNameInvalid => 'अमान्य नाम';

  @override
  String get localNameTaken => 'यह नाम पहले से इस्तेमाल में है';

  @override
  String get localMoveIntoItself =>
      'किसी फ़ोल्डर को उसी के अंदर नहीं ले जाया जा सकता';

  @override
  String get localManageFailed => 'कार्रवाई विफल';

  @override
  String subsongSkippedShort(int seconds) {
    return 'क्यू में नहीं: $seconds s से कम (सेटिंग्स → प्लेबैक)';
  }

  @override
  String get settingsAutoplaySection => 'ऑटोप्ले';

  @override
  String get settingsAutoplayTitle => 'कतार के बाद भी बजाते रहें';

  @override
  String get settingsAutoplaySubtitle =>
      'जब कतार समाप्त होने के करीब हो, तो उसमें मिलते-जुलते ट्रैक जोड़ दिए जाते हैं। कतार का ∞ बटन यही सेटिंग है।';

  @override
  String get settingsAutoplaySize => 'हर बार जोड़े जाने वाले ट्रैक';

  @override
  String get settingsAutoplayMode => 'ट्रैक कैसे चुने जाएँ';

  @override
  String get settingsAutoplayModeAuto => 'स्वचालित';

  @override
  String get settingsAutoplayModeAutoHint =>
      'पहले वही कलाकार, फिर उनके ग्रुप, फिर वही संग्रह।';

  @override
  String get settingsAutoplayModeArtist => 'वही कलाकार';

  @override
  String get settingsAutoplayModeArtistHint =>
      'केवल अभी बजे कलाकारों के ट्रैक।';

  @override
  String get settingsAutoplayModeGroup => 'वही ग्रुप';

  @override
  String get settingsAutoplayModeGroupHint =>
      'उन ग्रुपों के ट्रैक जिनसे ये कलाकार जुड़े हैं।';

  @override
  String get settingsAutoplayModeCollection => 'वही संग्रह';

  @override
  String get settingsAutoplayModeCollectionHint =>
      'उसी संग्रह से बेतरतीब ट्रैक, पहले उसी प्लैटफ़ॉर्म से।';

  @override
  String get settingsAutoplayModeRecent => 'हाल में सुने गए';

  @override
  String get settingsAutoplayModeRecentHint =>
      'केवल कतार से नहीं, बल्कि हाल में सुने गए गानों से भी चुने जाते हैं।';

  @override
  String get settingsQueuePrefetchSection => 'क्यू डाउनलोड';

  @override
  String get settingsQueuePrefetchTitle => 'पूरी क्यू डाउनलोड करें';

  @override
  String get settingsQueuePrefetchSubtitle =>
      'एक बार में एक फ़ाइल; पिछली फ़ाइल आते ही अगला गायब ट्रैक शुरू होता है। बंद: सिर्फ़ अगला ट्रैक लाया जाता है।';

  @override
  String get settingsCdRipDeclickSection => 'CD रिप';

  @override
  String get settingsCdRipDeclickTitle => 'ट्रैक की शुरुआत में क्लिक हटाएँ';

  @override
  String get settingsCdRipDeclickSubtitle =>
      'ख़राब CD रिप (mp3, ape, ogg, flac…) अक्सर कुछ ख़राब सैंपल से शुरू होते हैं। 200 ms असली संगीत बजने तक उन्हें ठीक किया जाता है; फिर फ़िल्टर हट जाता है।';

  @override
  String get settingsSilenceSkipTitle => 'साइलेंस पर अगले ट्रैक पर जाएँ';

  @override
  String get settingsSilenceSkipSubtitle =>
      'आउटपुट चुप रहने पर अपने-आप आगे बढ़ता है';

  @override
  String get settingsSilenceDelay => 'साइलेंस देरी';

  @override
  String get settingsDefaultDuration => 'डिफ़ॉल्ट अवधि';

  @override
  String get settingsDefaultDurationHelp =>
      'तब इस्तेमाल होती है जब ट्रैक की कोई ज्ञात अवधि नहीं होती (न टैग, न सर्वर मेटाडेटा) — ताकि वह हमेशा न चलता या लूप होता रहे। Amiga ट्रैक (UADE) पर कभी लागू नहीं होती, उनका अपना songlength डेटाबेस है।';

  @override
  String get settingsForcedLoopHeader => 'ज़बरदस्ती लूप / फ़ेड-आउट';

  @override
  String get settingsForcedLoopHelp =>
      'कुछ फ़ॉर्मेट किसी ख़ास हिस्से को लूप करते हैं (VGM, ट्रैकर मॉड्यूल…); बाकी नहीं। \"अनंत\" ट्रैक के स्वाभाविक अंत को नज़रअंदाज़ करता है।';

  @override
  String get settingsForceLoopCount => 'लूप की संख्या तय करें';

  @override
  String get settingsLoopCount => 'लूप की संख्या';

  @override
  String get settingsForceFadeout => 'ज़बरदस्ती फ़ेड-आउट';

  @override
  String get settingsFadeoutDuration => 'फ़ेड की अवधि';

  @override
  String get settingsResetEnginesTitle => 'इंजन सेटिंग्स रीसेट करें?';

  @override
  String get settingsResetEnginesBody =>
      'सभी इंजन सेटिंग्स अपनी डिफ़ॉल्ट वैल्यू पर लौट आएँगी।';

  @override
  String get settingsResetDefaultsTitle => 'डिफ़ॉल्ट वैल्यू पर रीसेट करें';

  @override
  String get settingsResetDefaultsSubtitle => 'सभी इंजन';

  @override
  String get settingsDefaultDecoders => 'डिफ़ॉल्ट डिकोडर';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'ऐसे फ़ॉर्मेट जिन्हें कई इंजन चला सकते हैं';

  @override
  String get settingsDecodersHelp =>
      'कुछ फ़ॉर्मेट कई इंजन चला सकते हैं। डिफ़ॉल्ट रूप से कौन-सा इस्तेमाल हो, चुनें — बाकी हर फ़ॉर्मेट अपने-आप सही इंजन पर जाता है।';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga ट्रैकर (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'ट्रैकर — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineXmpSubtitle =>
      'वे मॉड्यूल जिन्हें libopenmpt नहीं पढ़ सकता — .musx, .liq, .fnk…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, स्टीरियो';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — क्वालिटी, फ़िल्टर, हर चिप के विकल्प';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — हाई-पास फ़िल्टर';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — इस्तेमाल में SoundFont';

  @override
  String get settingsEngineGsfSubtitle => 'GBA / GSF — इंटरपोलेशन, लो-पास, इको';

  @override
  String get settingsEngineUadeSubtitle => 'Amiga — पैनिंग, हेडफ़ोन, गेन, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — क्लॉक, मॉडल, ReSIDfp फ़िल्टर';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — स्टीरियो/सराउंड हार्मोनिक मोड';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, रिवर्ब';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612, OPL3, QSound कोर…';

  @override
  String get settingsMasterVolume => 'मास्टर वॉल्यूम';

  @override
  String get settingsAmplification => 'एम्प्लीफ़िकेशन';

  @override
  String get settingsAmigaFilter => 'Amiga फ़िल्टर';

  @override
  String get settingsInterpolation => 'इंटरपोलेशन';

  @override
  String get settingsPolyphony => 'पॉलीफ़ोनी';

  @override
  String get settingsReverb => 'रिवर्ब';

  @override
  String get settingsChorus => 'कोरस';

  @override
  String get playbackMt32NoRoms =>
      'यह MIDI Roland MT-32 के लिए लिखा गया था। उसकी ROM के बिना यह SoundFont पर बजता है, इंस्ट्रूमेंट General MIDI पर मैप किए जाते हैं — असली आवाज़ के लिए सेटिंग्स › इंजन › Munt में ROM इम्पोर्ट करें।';

  @override
  String get settingsMidiMt32ToGm => 'MT-32 फ़ाइलें अनुकूलित करें';

  @override
  String get settingsMidiMt32ToGmSubtitle =>
      'Roland MT-32 के लिए लिखा MIDI अपने प्रोग्राम MT-32 की अपनी सूची के हिसाब से नंबर करता है: उन्हें सबसे क़रीबी General MIDI इंस्ट्रूमेंट पर मैप करने से वह बेतरतीब की बजाय सही लगने वाले इंस्ट्रूमेंट से बजता है।';

  @override
  String get settingsInterpNone => 'कोई नहीं';

  @override
  String get settingsInterpLinear => 'लीनियर';

  @override
  String get settingsInterpCubic => 'क्यूबिक';

  @override
  String get settingsInterpSinc => 'Sinc (सबसे अच्छा)';

  @override
  String get settingsStereoSeparation => 'स्टीरियो सेपरेशन';

  @override
  String get settingsGmeSilenceSubtitle =>
      'इंजन को लंबी चुप्पी मिलने पर ट्रैक ख़त्म कर देता है';

  @override
  String get settingsStereoDepth => 'स्टीरियो गहराई';

  @override
  String get settingsEqualizer => 'इक्वलाइज़र';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — SPC पर कोई असर नहीं';

  @override
  String get settingsBass => 'बेस';

  @override
  String get settingsTreble => 'ट्रेबल';

  @override
  String get settingsAppliedLive => 'तुरंत लागू, प्लेबैक के दौरान भी।';

  @override
  String get settingsAppliedNextTrack => 'अगले लोड होने वाले ट्रैक पर लागू।';

  @override
  String get settingsSidEmulation => 'एम्यूलेशन';

  @override
  String get settingsSidResidfp => 'ReSIDfp (सटीक)';

  @override
  String get settingsSidLite => 'SIDLite (तेज़)';

  @override
  String get settingsSidSampling => 'सैंपलिंग';

  @override
  String get settingsSidSamplingInterp => 'इंटरपोलेशन (तेज़)';

  @override
  String get settingsSidSamplingResample => 'रीसैंपल (सबसे अच्छा)';

  @override
  String get settingsSidClock => 'क्लॉक';

  @override
  String get settingsSidModel => 'SID मॉडल';

  @override
  String get settingsSidFilter => 'SID फ़िल्टर';

  @override
  String get settingsSidForceSecond => 'दूसरा SID ज़बरदस्ती चालू करें';

  @override
  String get settingsSidSecondSubtitle => 'स्टीरियो 2SID धुनें';

  @override
  String get settingsSidSecondAddr => 'दूसरे SID का पता';

  @override
  String get settingsSidForceThird => 'तीसरा SID ज़बरदस्ती चालू करें';

  @override
  String get settingsSidThirdAddr => 'तीसरे SID का पता';

  @override
  String get settingsSidAutoFilter => 'ऑटो 6581 फ़िल्टर रेंज';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'धुन के रचयिता के लिए सुझाई गई वैल्यू (sidplayfp टेबल)';

  @override
  String get settingsSid6581Range => '6581 फ़िल्टर रेंज';

  @override
  String get settingsSid6581Curve => '6581 फ़िल्टर कर्व';

  @override
  String get settingsSid8580Curve => '8580 फ़िल्टर कर्व';

  @override
  String get settingsSidNote =>
      'SID फ़िल्टर और कर्व तुरंत लागू होते हैं; एम्यूलेशन/सैंपलिंग/क्लॉक/मॉडल/दूसरा-तीसरा SID अगले ट्रैक पर लागू होते हैं।';

  @override
  String get settingsAudioOutput => 'ऑडियो आउटपुट';

  @override
  String get settingsAdplugNote =>
      'सराउंड: दो थोड़ी अलग ट्यून की गई OPL चिप। अगले ट्रैक पर लागू।';

  @override
  String get settingsHeSpuMain => 'मुख्य वॉइस (SPU)';

  @override
  String get settingsHeSpuReverb => 'रिवर्ब (SPU)';

  @override
  String get settingsNsfQuality => 'क्वालिटी (nsfplay)';

  @override
  String get settingsLowpassFilter => 'लो-पास फ़िल्टर';

  @override
  String get settingsHighpassFilter => 'हाई-पास फ़िल्टर';

  @override
  String get settingsRegion => 'क्षेत्र';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC ज़बरदस्ती';

  @override
  String get settingsNsfRegionPalForced => 'PAL ज़बरदस्ती';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy ज़बरदस्ती';

  @override
  String get settingsNsfForceIrq => 'IRQ ज़बरदस्ती';

  @override
  String get settingsNsfApu1Title => '2A03 — पल्स (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — ट्रायंगल / नॉइज़ / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'रीसेट पर अनम्यूट';

  @override
  String get settingsNsfPhaseRefresh => 'फ़ेज़ रिफ़्रेश';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'पीरियड लिखे जाने पर फ़ेज़ रीसेट करें';

  @override
  String get settingsNsfNonlinearMixer => 'नॉन-लीनियर मिक्सिंग';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      '2A03 का असली मिक्स (वरना लीनियर)';

  @override
  String get settingsNsfDutySwap => 'ड्यूटी साइकिल बदलें';

  @override
  String get settingsNsfDutySwapSubtitle => '25% / 50% ड्यूटी का क्रम';

  @override
  String get settingsNsfNegateSweep => 'इनिट पर नेगेटिव स्वीप';

  @override
  String get settingsNsfEnable4011 => 'रजिस्टर \$4011 चालू';

  @override
  String get settingsNsfEnable4011Subtitle => 'डायरेक्ट DAC आउटपुट (मूल क्लिक)';

  @override
  String get settingsNsfPeriodicNoise => 'पीरियॉडिक नॉइज़';

  @override
  String get settingsNsfPeriodicNoiseSubtitle => 'नॉइज़ जनरेटर का शॉर्ट मोड';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM एंटी-क्लिक';

  @override
  String get settingsNsfRandomizeNoise => 'इनिट पर नॉइज़ रैंडम करें';

  @override
  String get settingsNsfTriangleMute => 'ट्रायंगल म्यूट करें';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'अल्ट्रासोनिक पीरियड पर ट्रायंगल को चुप करता है';

  @override
  String get settingsNsfRandomizeTri => 'इनिट पर ट्रायंगल रैंडम करें';

  @override
  String get settingsNsfDpcmReverse => 'उल्टा DPCM';

  @override
  String get settingsNsfN163Serial => 'सीरियल मल्टीप्लेक्सिंग';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'मल्टी-वॉइस धुनों पर N163 की असली भिनभिनाहट';

  @override
  String get settingsNsfN163PhaseReadOnly => 'रीड-ओनली फ़ेज़';

  @override
  String get settingsNsfN163LimitWavelength => 'वेवलेंथ सीमित करें';

  @override
  String get settingsNsfFdsCutoff => 'लो-पास कटऑफ़';

  @override
  String get settingsNsfFds4085Reset => '\$4085 रीसेट';

  @override
  String get settingsNsfFdsWriteProtect => 'राइट प्रोटेक्शन';

  @override
  String get settingsNsfVrc7Patch => 'पैच सेट';

  @override
  String get settingsNsfVrc7Opll => 'OPLL मोड';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'VRC7 की जगह YM2413 एम्यूलेट करें';

  @override
  String get settingsGbsHpFilter => 'हाई-पास फ़िल्टर (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (क्लासिक GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'इको';

  @override
  String get settingsUadePostfx => 'पोस्ट-प्रोसेसिंग';

  @override
  String get settingsUadePostfxSubtitle =>
      'इफ़ेक्ट चेन चालू करता है (नीचे की हर चीज़ के लिए ज़रूरी)';

  @override
  String get settingsUadePan => 'पैनिंग (स्टीरियो सेपरेशन)';

  @override
  String get settingsUadePanValue => 'पैनिंग की मात्रा';

  @override
  String get settingsUadeHeadphones => 'हेडफ़ोन';

  @override
  String get settingsUadeLed => 'LED (Paula फ़िल्टर)';

  @override
  String get settingsUadeLedAuto => 'ऑटो (हर धुन के अनुसार)';

  @override
  String get settingsUadeLedOn => 'ज़बरदस्ती चालू';

  @override
  String get settingsUadeLedOff => 'ज़बरदस्ती बंद';

  @override
  String get settingsUadeFilterType => 'फ़िल्टर टाइप';

  @override
  String get settingsUadeGain => 'गेन';

  @override
  String get settingsUadeGainValue => 'गेन की मात्रा';

  @override
  String get settingsSoundfontLoading => 'कैटलॉग लोड हो रहा है…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'कैटलॉग उपलब्ध नहीं ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'डाउनलोड विफल: $error';
  }

  @override
  String get settingsSoundfontImport => 'SoundFont इम्पोर्ट करें…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'इस डिवाइस पर कोई .sf2 फ़ाइल चुनें';

  @override
  String get settingsSoundfontImported => 'इम्पोर्ट किया गया';

  @override
  String get settingsSoundfontInvalid => 'यह फ़ाइल SoundFont (.sf2) नहीं है';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'इम्पोर्ट विफल — $error';
  }

  @override
  String get settingsSoundfontDelete => 'फ़ाइल डिलीट करें';

  @override
  String get settingsCreditsHeader => 'क्रेडिट और लाइसेंस';

  @override
  String get settingsRightsNotice =>
      'Rewamp एक प्लेयर है: यह कोई फ़ाइल होस्ट नहीं करता और कोई संगीत वितरित नहीं करता। ट्रैक ऑनलाइन संरक्षण आर्काइव से आते हैं और अपने अधिकार-धारकों की संपत्ति बने रहते हैं। उन्हें सुनना, डाउनलोड करना और रखना लागू अधिकारों और आपके देश के क़ानून के अनुरूप हो, यह सुनिश्चित करना आपकी ज़िम्मेदारी है।';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ॉर्मेट समर्थित',
      one: '$count फ़ॉर्मेट समर्थित',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्लेबैक इंजन में बँटे हुए — विवरण देखें',
      one: '$count प्लेबैक इंजन द्वारा संभाले जाते हैं — विवरण देखें',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga songlengths और मेटाडेटा';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb, Matti Tiainen (mvtiaine) द्वारा, CC BY-NC-SA 4.0।';

  @override
  String get settingsGb64Title => 'C64 / SID डेटा और कवर आर्ट';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — C64 गेम मेटाडेटा और विज़ुअल।';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 फ़ॉन्ट';

  @override
  String get settingsFt2FontSubtitle =>
      'पैटर्न विज़ुअलाइज़र की FastTracker II स्टाइल 8bitbubsy (16-bits.org) के ft2-clone का FT2 बिटमैप फ़ॉन्ट इस्तेमाल करती है।';

  @override
  String settingsLinkCopied(String url) {
    return '$url कॉपी किया गया';
  }

  @override
  String get settingsOpenLink => 'लिंक खोलें';

  @override
  String get settingsEnginesHeader => 'प्लेबैक इंजन';

  @override
  String get settingsComponentsHeader => 'अन्य कंपोनेंट';

  @override
  String get settingsResetAll => 'सभी सेटिंग्स रीसेट करें';

  @override
  String get settingsResetAllSubtitle =>
      'सामान्य, विज़ुअलाइज़ेशन, प्लेबैक, इंजन — लाइब्रेरी नहीं';

  @override
  String get settingsResetAllTitle => 'सभी सेटिंग्स रीसेट करें?';

  @override
  String get settingsResetAllBody =>
      'सामान्य, विज़ुअलाइज़ेशन, प्लेबैक और हर इंजन अपनी डिफ़ॉल्ट वैल्यू पर लौट आएँगे। आपकी लाइब्रेरी और हिस्ट्री पर कोई असर नहीं होगा।';

  @override
  String get settingsRenewUserId => 'गुमनाम ID नई करें';

  @override
  String get settingsRenewUserIdTitle => 'गुमनाम ID नई करें?';

  @override
  String get settingsRenewUserIdBody =>
      'सर्वर आँकड़ों के लिए एक नई गुमनाम ID बनाई जाएगी।\n\nपुरानी ID अब इस्तेमाल नहीं होगी। आपकी लोकल हिस्ट्री और पसंदीदा पर कोई असर नहीं होगा।';

  @override
  String get settingsRenewUserIdFailed => 'विफल — सर्वर तक नहीं पहुँच पाए';

  @override
  String settingsNewUserId(String id) {
    return 'नई ID: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get settingsNoUserId => 'कोई ID रजिस्टर नहीं';

  @override
  String get settingsCleanDb => 'लोकल डेटाबेस साफ़ करें';

  @override
  String get settingsCleanDbSubtitle =>
      'ऐसी एंट्री हटाता है जिनकी फ़ाइल अब मौजूद नहीं (डिलीट किए डाउनलोड, पुरानी त्रुटियाँ)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अनाथ एंट्री हटाई गईं',
      one: '$count अनाथ एंट्री हटाई गई',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean => 'लोकल डेटाबेस साफ़ है — हटाने को कुछ नहीं';

  @override
  String get settingsClearCache => 'कैश साफ़ करें (आर्टवर्क और मेटाडेटा)';

  @override
  String get settingsClearCacheSubtitle =>
      'कैश किए कवर और लाया गया मेटाडेटा (STIL, songlengths) हटाता है — अगली बार चलाने पर फिर डाउनलोड होगा';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कैश साफ़ हुआ ($count कवर)',
      one: 'कैश साफ़ हुआ ($count कवर)',
    );
    return '$_temp0';
  }

  @override
  String get storageTitle => 'स्टोरेज';

  @override
  String get storageSubtitle =>
      'ऐप डिस्क पर क्या रखता है, डिलीट करने के विकल्प के साथ';

  @override
  String get storageDownloads => 'डाउनलोड';

  @override
  String get storageArtworkCache => 'आर्टवर्क कैश';

  @override
  String get storageSoundfonts => 'SoundFonts';

  @override
  String get storagePresets => 'विज़ुअलाइज़र प्रीसेट';

  @override
  String get storageOpenedFiles => 'खोली गई फ़ाइलें';

  @override
  String get storageOpenedEmpty =>
      'ऐप के बाहर से खोली गई फ़ाइलें (शेयर, “इसके साथ खोलें”, मोबाइल पर फ़ाइल पिकर) यहाँ कॉपी की जाती हैं।';

  @override
  String get storageInUse => 'किसी प्लेलिस्ट या लाइब्रेरी में';

  @override
  String get storageDeleteAll => 'सब डिलीट करें';

  @override
  String get storageClear => 'साफ़ करें';

  @override
  String get storageDeleteSelection => 'चुने हुए डिलीट करें';

  @override
  String get storageSelectAll => 'सभी चुनें';

  @override
  String get storageFilterHint => 'नाम से फ़िल्टर करें';

  @override
  String get storageNoMatch => 'इस फ़िल्टर से कोई फ़ाइल मेल नहीं खाती।';

  @override
  String storageSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए',
      one: '$count चुना गया',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें डिलीट करें?',
      one: '$count फ़ाइल डिलीट करें?',
    );
    return '$_temp0';
  }

  @override
  String storageDeleteSelectionInUseBody(int count, int inUse) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count फ़ाइलें डिलीट करें? इनमें से $inUse किसी प्लेलिस्ट या लाइब्रेरी में इस्तेमाल हो रही हैं — उन एंट्री की फ़ाइल चली जाएगी।',
    );
    return '$_temp0';
  }

  @override
  String get storageDownloadsClearBody =>
      'हर डाउनलोड की गई फ़ाइल और उसकी लाइब्रेरी पंक्तियाँ डिलीट करें? पसंदीदा और प्लेलिस्ट अपनी एंट्री रखेंगे, लेकिन फ़ाइलें फिर से डाउनलोड करनी होंगी।';

  @override
  String get storageSoundfontsClearBody =>
      'हर SoundFont डिलीट करें, इम्पोर्ट किए हुए भी? कैटलॉग के SoundFont ज़रूरत पड़ने पर फिर डाउनलोड होंगे; इम्पोर्ट की गई फ़ाइलें खो जाएँगी।';

  @override
  String get storagePresetsClearBody =>
      'डाउनलोड किए प्रीसेट पैक और इम्पोर्ट किए प्रीसेट डिलीट करें? ऐप के साथ आए प्रीसेट रहेंगे; पैक ज़रूरत पड़ने पर फिर डाउनलोड होंगे, इम्पोर्ट की गई फ़ाइलें खो जाएँगी।';

  @override
  String get storageOpenedDeleteAllTitle => 'खोली गई फ़ाइलें डिलीट करें';

  @override
  String get storageInUseDeleteTitle => 'फ़ाइल इस्तेमाल में है';

  @override
  String get storageInUseDeleteBody =>
      'कोई प्लेलिस्ट या लाइब्रेरी अभी भी इस फ़ाइल की ओर इशारा करती है। इसे डिलीट करने पर उन एंट्री की फ़ाइल नहीं रहेगी।';

  @override
  String storageCategoryStat(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें — $size',
      one: '$count फ़ाइल — $size',
    );
    return '$_temp0';
  }

  @override
  String storageDownloadsSubtitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें — $size · एल्बम और ट्रैक से मैनेज करें',
      one: '$count फ़ाइल — $size · एल्बम और ट्रैक से मैनेज करें',
    );
    return '$_temp0';
  }

  @override
  String storageOpenedDeleteAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count फ़ाइलें डिलीट करें? किसी प्लेलिस्ट या लाइब्रेरी में इस्तेमाल होने वाली फ़ाइलें रखी जाएँगी।',
      one:
          '$count फ़ाइल डिलीट करें? किसी प्लेलिस्ट या लाइब्रेरी में इस्तेमाल होने वाली फ़ाइलें रखी जाएँगी।',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'आँकड़े रीसेट करें';

  @override
  String get settingsResetStatsSubtitle =>
      'सुनने की हिस्ट्री और प्ले काउंटर हटाता है';

  @override
  String get settingsClearStatsTitle => 'आँकड़े रीसेट करें?';

  @override
  String get settingsClearStatsBody =>
      'यह हमेशा के लिए डिलीट कर देगा:\n• सुनने की पूरी हिस्ट्री\n• प्ले काउंटर\n\nआपके पसंदीदा और लाइब्रेरी पर कोई असर नहीं होगा।';

  @override
  String get settingsStatsCleared => 'आँकड़े डिलीट किए गए';

  @override
  String get settingsResetDatabase => 'डेटाबेस रीसेट करें';

  @override
  String get settingsResetDatabaseSubtitle =>
      'सब कुछ डिलीट करता है: हिस्ट्री, पसंदीदा, प्लेलिस्ट, कैश';

  @override
  String get settingsResetDbTitle => 'डेटाबेस रीसेट करें?';

  @override
  String get settingsCleanLocalTitle => 'न चलने वाली लोकल एंट्री साफ़ करें';

  @override
  String get cleanStageScan => 'एंट्री स्कैन हो रही हैं…';

  @override
  String get cleanStageSync => 'आपके अकाउंट से सिंक हो रहा है…';

  @override
  String get cleanStagePurge => 'आपके अकाउंट से हटाया जा रहा है…';

  @override
  String get cleanStageDelete => 'लोकल रूप से हटाया जा रहा है…';

  @override
  String get settingsCleanLocalBody =>
      'लाइब्रेरी की वे एंट्री जो ऐसी फ़ाइल बताती हैं जो अब इस डिवाइस पर नहीं है। वे आपके अकाउंट से भी हटाई जाती हैं, इसलिए आपके दूसरे डिवाइस से भी गायब हो जाती हैं।';

  @override
  String settingsCleanLocalDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count एंट्री हटाई गईं',
      one: '$count एंट्री हटाई गई',
      zero: 'साफ़ करने को कुछ नहीं',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetDbBody =>
      'यह हमेशा के लिए डिलीट कर देगा:\n• सुनने की पूरी हिस्ट्री\n• हर काउंटर\n• हर पसंदीदा\n• हर प्लेलिस्ट\n• सारा कैश किया मेटाडेटा\n\nआपकी ऑडियो फ़ाइलें डिलीट नहीं होंगी।';

  @override
  String get settingsDbReset => 'डेटाबेस रीसेट हुआ';

  @override
  String get settingsDeleteDownloads => 'डाउनलोड डिलीट करें';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'online फ़ोल्डर की हर फ़ाइल डिलीट करता है (ट्रैक, आर्टवर्क)';

  @override
  String get settingsCleanAll => 'लोकल डेटाबेस और कैश साफ़ करें';

  @override
  String get settingsCleanAllSubtitle =>
      'ऐसी एंट्री जिनकी फ़ाइल नहीं रही, दूसरे डिवाइस पर रखी फ़ाइलों की ओर इशारा करती लाइब्रेरी एंट्री, और आर्टवर्क व मेटाडेटा कैश हटाता है';

  @override
  String get settingsCleanAllConfirmBody =>
      'दूसरे डिवाइस पर रखी फ़ाइलों की ओर इशारा करती लाइब्रेरी एंट्री आपके अकाउंट से भी हटाई जाती हैं, यानी आपके दूसरे डिवाइस से भी। आर्टवर्क और मेटाडेटा अगली बार चलाने पर फिर डाउनलोड होते हैं।';

  @override
  String get settingsDataAdvanced => 'एडवांस्ड';

  @override
  String get settingsDataAdvancedSubtitle =>
      'हर सफ़ाई चरण अलग से, कैश, और रीसेट';

  @override
  String get settingsDataGroupDb => 'डेटाबेस';

  @override
  String get settingsDataGroupCache => 'कैश';

  @override
  String get settingsDataGroupReset => 'रीसेट';

  @override
  String get settingsDeleteDownloadsTitle => 'डाउनलोड डिलीट करें?';

  @override
  String get settingsDeleteDownloadsBody =>
      'यह online फ़ोल्डर से हर डाउनलोड की गई फ़ाइल (ट्रैक, एल्बम, आर्टवर्क) हमेशा के लिए डिलीट कर देगा।\n\nडेटाबेस की एंट्री रहेंगी, लेकिन ऐसी फ़ाइलों की ओर इशारा करेंगी जो अब मौजूद नहीं।';

  @override
  String get settingsDownloadsDeleted => 'डाउनलोड डिलीट किए गए';

  @override
  String get settingsColor => 'रंग';

  @override
  String get settingsPmPresets => 'प्रीसेट';

  @override
  String get settingsPmRandomNext => 'अगला प्रीसेट रैंडम';

  @override
  String get settingsPmRandomNextSubtitle => 'बंद: प्रीसेट क्रम से चलाएँ';

  @override
  String get settingsPmLockPreset => 'प्रीसेट लॉक करें';

  @override
  String get settingsPmLockPresetSubtitle => 'अपने-आप नहीं बदलेगा';

  @override
  String get settingsPmPresetDuration => 'प्रीसेट के बीच का समय';

  @override
  String get settingsPmTransitions => 'ट्रांज़िशन';

  @override
  String get settingsPmBlend => 'क्रॉस-फ़ेड ट्रांज़िशन';

  @override
  String get settingsPmBlendSubtitle => 'बंद: प्रीसेट तुरंत बदलें';

  @override
  String get settingsPmTransitionStyle => 'ट्रांज़िशन स्टाइल';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'ब्लेंड कौन-सा पैटर्न इस्तेमाल करे';

  @override
  String get settingsPmTransitionRandom => 'रैंडम';

  @override
  String get settingsPmHardcut => 'हार्डकट';

  @override
  String get settingsPmHardcutSubtitle => 'बीट के साथ प्रीसेट बदलना';

  @override
  String get settingsPmHardcutTime => 'हार्डकट: न्यूनतम समय';

  @override
  String get settingsPmHardcutSensitivity => 'हार्डकट: संवेदनशीलता';

  @override
  String get settingsPmRendering => 'रेंडरिंग';

  @override
  String get settingsPmQuality => 'क्वालिटी';

  @override
  String get settingsPmQualitySubtitle =>
      'रेंडर रिज़ॉल्यूशन (Max = नेटिव रिज़ॉल्यूशन)';

  @override
  String get settingsPmBeatSensitivity => 'बीट संवेदनशीलता';

  @override
  String get settingsPmAspectRatio => 'आस्पेक्ट रेशियो बनाए रखें';

  @override
  String get settingsPmAspectRatioSubtitle =>
      'उन शेडर के लिए जो इसे सपोर्ट करते हैं';

  @override
  String get settingsPmPermissive => 'उदार मोड';

  @override
  String get settingsPmPermissiveSubtitle =>
      'स्क्रिप्ट त्रुटियों वाली .milk फ़ाइलें भी लोड करें';

  @override
  String get accountTitle => 'अकाउंट';

  @override
  String get accountSubtitle => 'अपनी लाइब्रेरी सेव और सिंक करें';

  @override
  String get accountAnonymous => 'गुमनाम अकाउंट';

  @override
  String get accountAnonymousExplain =>
      'आपके पसंदीदा और आपकी हिस्ट्री सर्वर पर सेव हैं, लेकिन सिर्फ़ यही डिवाइस उन तक पहुँच सकता है। उन्हें कहीं और पाने के लिए ईमेल पता जोड़ें।';

  @override
  String get accountEmailAttached =>
      'पता कन्फ़र्म — यह अकाउंट रीस्टोर किया जा सकता है';

  @override
  String get accountEmailPending => 'पता अभी कन्फ़र्म नहीं हुआ';

  @override
  String get accountInsecureStorage =>
      'इस डिवाइस का सुरक्षित स्टोरेज उपलब्ध नहीं है: अकाउंट पहचानकर्ता बिना एन्क्रिप्शन के सेव है।';

  @override
  String get accountSaveCta => 'मेरा अकाउंट सेव करें';

  @override
  String get accountStatSongs => 'पसंदीदा ट्रैक';

  @override
  String get accountStatAlbums => 'पसंदीदा एल्बम';

  @override
  String get accountStatPlays => 'प्ले';

  @override
  String get accountCreatedLabel => 'बनाया गया';

  @override
  String get accountSignOut => 'साइन आउट';

  @override
  String get accountRevoke => 'हर जगह से लॉग आउट';

  @override
  String get accountRevokeSubtitle => 'बाकी सभी डिवाइस से साइन आउट करता है';

  @override
  String get accountRevokeBody =>
      'बाकी सभी डिवाइस साइन आउट हो जाएँगे। यह डिवाइस कनेक्टेड रहेगा।';

  @override
  String get accountRevokeDone => 'बाकी डिवाइस साइन आउट हो गए';

  @override
  String get accountDelete => 'मेरा अकाउंट डिलीट करें';

  @override
  String get accountDeleteSubtitle =>
      'सर्वर से अकाउंट और उसका डेटा मिटा देता है। यह वापस नहीं होगा।';

  @override
  String accountDeleteBody(int items, int lists) {
    return '$items पसंदीदा और $lists प्लेलिस्ट सर्वर से डिलीट हो जाएँगी। इसे पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'आपके डाउनलोड और इस डिवाइस की लाइब्रेरी पर कोई असर नहीं पड़ेगा।';

  @override
  String get accountDeleteDone => 'अकाउंट डिलीट हो गया';

  @override
  String get accountSignOutSubtitle =>
      'यह डिवाइस एक नए, खाली अकाउंट पर लौट जाता है';

  @override
  String get accountSignOutTitle => 'साइन आउट करें?';

  @override
  String accountSignOutBody(String email) {
    return '$email पर भेजे गए कोड से आप इस अकाउंट में वापस आ सकते हैं।';
  }

  @override
  String get accountSignedOut => 'साइन आउट हो गया';

  @override
  String get accountNoSignOut => 'साइन आउट उपलब्ध नहीं है';

  @override
  String get accountNoSignOutSubtitle =>
      'ईमेल पते के बिना यह अकाउंट कभी रिकवर नहीं हो पाएगा।';

  @override
  String get accountDetach => 'पता अनलिंक करें';

  @override
  String get accountDetachSubtitle =>
      'अकाउंट फिर से गुमनाम हो जाता है, कोई डेटा डिलीट नहीं होता';

  @override
  String get accountDetachBody =>
      'पते के बिना यह अकाउंट किसी दूसरे डिवाइस से रिकवर नहीं हो पाएगा।';

  @override
  String get accountDetachDone => 'पता अनलिंक हो गया';

  @override
  String get accountOffline => 'ऑफ़लाइन अकाउंट उपलब्ध नहीं';

  @override
  String get accountEmailTitle => 'ईमेल पता';

  @override
  String get accountEmailExplain =>
      'पता कन्फ़र्म करने के लिए हम आपको 6 अंकों का कोड भेजते हैं। इसका इस्तेमाल सिर्फ़ आपका अकाउंट रिकवर करने के लिए होता है।';

  @override
  String get accountEmailLabel => 'ईमेल पता';

  @override
  String get accountCodeTitle => 'कन्फ़र्मेशन कोड';

  @override
  String accountCodeExplain(String email) {
    return 'कोड $email पर भेजा गया। यह 10 मिनट तक मान्य है।';
  }

  @override
  String get accountCodeLabel => '6 अंकों का कोड';

  @override
  String get accountSendCode => 'कोड भेजें';

  @override
  String get accountVerify => 'कन्फ़र्म करें';

  @override
  String get accountResend => 'कोड फिर से भेजें';

  @override
  String accountResendIn(int n) {
    return '$n s में फिर से भेजें';
  }

  @override
  String get accountCheckSpam =>
      'ईमेल आने में एक मिनट तक लग सकता है — अपना स्पैम फ़ोल्डर देखें।';

  @override
  String get accountErrorInvalidEmail => 'अमान्य पता';

  @override
  String get accountErrorTooMany =>
      'बहुत ज़्यादा अनुरोध, कुछ मिनट बाद फिर कोशिश करें';

  @override
  String get accountErrorInvalidCode => 'गलत या एक्सपायर्ड कोड';

  @override
  String get accountErrorCodeLength => 'कोड 6 अंकों का होता है';

  @override
  String get albumOfflinePartial =>
      'ऑफ़लाइन — इस डिवाइस पर पहले से मौजूद चीज़ें दिख रही हैं';

  @override
  String get accountErrorNetwork => 'कनेक्शन विफल, फिर कोशिश करें';

  @override
  String get accountMergeTitle => 'यह लाइब्रेरी मर्ज करें?';

  @override
  String accountMergeBody(String email) {
    return 'इस डिवाइस के पसंदीदा और हिस्ट्री $email अकाउंट में जोड़ दिए जाएँगे। इसे पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String get accountMergeConfirm => 'मर्ज करें';

  @override
  String get accountCarryLocal => 'इस डिवाइस के पसंदीदा रखें';

  @override
  String accountCarryLocalOn(int n) {
    return 'इस डिवाइस के $n पसंदीदा और प्लेलिस्ट अकाउंट में जोड़ दिए जाते हैं।';
  }

  @override
  String get accountCarryLocalOff =>
      'वे इस डिवाइस से डिलीट होकर अकाउंट वालों से बदल दिए जाते हैं। डाउनलोड की गई फ़ाइलें रहती हैं।';

  @override
  String get accountDropLocalTitle => 'इस डिवाइस का डेटा हटाएँ?';

  @override
  String get accountCreatedOk =>
      'अकाउंट सेव हो गया, आपकी लाइब्रेरी का बैकअप हो गया';

  @override
  String get accountMergedOk =>
      'साइन इन हो गया — आपके लोकल पसंदीदा जोड़ दिए गए';

  @override
  String get accountSignedInOk => 'साइन इन हो गया';

  @override
  String get playlistEntryMissing => 'इस डिवाइस पर फ़ाइल नहीं है';

  @override
  String get playlistEntryMissingRestorable =>
      'फ़ाइल नहीं है — फिर से डाउनलोड की जा सकती है';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n गायब',
      one: '$n गायब',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'मेरे अकाउंट में बैकअप करें';

  @override
  String get playlistBackupSubtitle =>
      'ऐप दोबारा इंस्टॉल करने पर भी यह प्लेलिस्ट बनी रहती है';

  @override
  String get playlistBackupUpdate => 'बैकअप अपडेट करें';

  @override
  String get playlistBackupUpdateSubtitle =>
      'अकाउंट वाली कॉपी को इस वर्शन से बदल देता है';

  @override
  String get playlistBackupStop => 'बैकअप बंद करें';

  @override
  String get playlistBackupStopped => 'बैकअप हटा दिया गया';

  @override
  String get playlistBackupDone => 'प्लेलिस्ट का बैकअप हो गया';

  @override
  String get playlistBackupFailed => 'बैकअप विफल';

  @override
  String get playlistBackupNoAccount => 'इस डिवाइस पर कोई अकाउंट नहीं';

  @override
  String get playlistSyncTooltip => 'मेरे अकाउंट से सिंक करें';

  @override
  String get playlistSyncRunning => 'सिंक हो रहा है…';

  @override
  String get playlistSyncDone => 'प्लेलिस्ट सिंक हो गईं';

  @override
  String get playlistSyncPartial => 'कुछ प्लेलिस्ट का बैकअप नहीं हो सका';

  @override
  String get playlistFetchMissing => 'गायब ट्रैक डाउनलोड करें';

  @override
  String get playlistFetchDone => 'गायब ट्रैक डाउनलोड हो गए';

  @override
  String get playlistFetchPartial => 'कुछ ट्रैक डाउनलोड नहीं हो सके';

  @override
  String get playlistEntryFetchFailed => 'यह ट्रैक डाउनलोड नहीं हो सका';

  @override
  String get accountStatPlaylists => 'प्लेलिस्ट';

  @override
  String get accountSyncNow => 'अभी सिंक करें';

  @override
  String get accountSyncAuto => 'बैकग्राउंड में अपने-आप चलता है';

  @override
  String get accountSyncAnonymous =>
      'सर्वर पर बैकअप हो गया। दूसरा डिवाइस सिंक करने के लिए ईमेल जोड़ें।';

  @override
  String get accountSyncPending => 'बदलाव भेजे जाने की प्रतीक्षा में';

  @override
  String accountSyncLast(String when) {
    return 'पिछला सिंक: $when';
  }

  @override
  String get accountSyncDone => 'सिंक पूरा हुआ';

  @override
  String get accountSyncFailed => 'सिंक विफल, फिर कोशिश की जाएगी';

  @override
  String get podiumFirst => 'पहला';

  @override
  String get podiumSecond => 'दूसरा';

  @override
  String get podiumThird => 'तीसरा';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return '$production का संगीत, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return '$compo का $place शामिल है';
  }

  @override
  String get podiumBrowserTitle => 'पोडियम';

  @override
  String get podiumHubBias =>
      'हर गाना एक बार गिना जाता है, अपने सबसे अच्छे स्थान के लिए।';

  @override
  String get podiumRecentWinners => 'हाल के विजेता';

  @override
  String get podiumRecentWinnersSubtitle =>
      'पिछले दो साल के गोल्ड, सबसे नई compo पहले';

  @override
  String get podiumViaSelf => 'म्यूज़िक compo';

  @override
  String get podiumViaSelfSubtitle => 'गाने ने खुद मुकाबले में हिस्सा लिया';

  @override
  String get podiumViaProduction => 'डेमो साउंडट्रैक';

  @override
  String get podiumViaProductionSubtitle =>
      'जिस डेमो या गेम का यह संगीत है, उसे स्थान मिला';

  @override
  String get podiumByKind => 'compo के प्रकार से';

  @override
  String get podiumByEra => 'दौर के अनुसार';

  @override
  String get podiumByParty => 'पार्टी के अनुसार';

  @override
  String get podiumByPartySubtitle =>
      'मेडल के हिसाब से पार्टी सीरीज़ की रैंकिंग';

  @override
  String get podiumTopArtists => 'सबसे ज़्यादा पुरस्कृत आर्टिस्ट';

  @override
  String get podiumAll => 'सभी पोडियम';

  @override
  String get podiumAllSubtitle => 'सबसे नई compo पहले, फिर रैंक के अनुसार';

  @override
  String get podiumChipVia => 'प्रकृति';

  @override
  String get podiumChipKind => 'compo का प्रकार';

  @override
  String get podiumChipSeries => 'पार्टी';

  @override
  String get podiumChipEra => 'दौर';

  @override
  String get compoKindTracked => 'Tracked';

  @override
  String get compoKindChip => 'Chip';

  @override
  String get compoKindStreaming => 'स्ट्रीमिंग';

  @override
  String get compoKindExecutable => 'Executable';

  @override
  String get compoKindOldskool => 'Oldskool';

  @override
  String get compoKindCombined => 'Combined';

  @override
  String get compoKindSoundtrack => 'साउंडट्रैक';

  @override
  String get compoKindTrackedHint => 'ट्रैकर मॉड्यूल: MOD, XM, IT…';

  @override
  String get compoKindChipHint => 'चिप म्यूज़िक: SID, AY, NES, Game Boy…';

  @override
  String get compoKindStreamingHint => 'स्ट्रीम ऑडियो: MP3, OGG, WAV…';

  @override
  String get compoKindExecutableHint => 'एक छोटे प्रोग्राम से बना संगीत';

  @override
  String get compoKindOldskoolHint =>
      'पुराना हार्डवेयर या tracked, स्ट्रीमिंग नहीं';

  @override
  String get compoKindCombinedHint => 'बिना फ़ॉर्मेट पाबंदी वाली compo';

  @override
  String get compoKindSoundtrackHint => 'स्थान पाने वाले डेमो या गेम का संगीत';

  @override
  String podiumDecadeLabel(String decade) {
    return '$decade का दशक';
  }

  @override
  String get podiumSortPodium => 'सबसे नई compo पहले';

  @override
  String get competitionEmpty => 'इस प्रतियोगिता में कोई एंट्री नहीं है';

  @override
  String get competitionEntryNoMusic =>
      'इस एंट्री का कोई संगीत कैटलॉग में नहीं है';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ट्यून',
      one: '$n ट्यून',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'छोड़ें';

  @override
  String get onboardingNext => 'आगे';

  @override
  String get onboardingStart => 'शुरू करें';

  @override
  String get onboardingWelcomeTitle => 'Rewamp में आपका स्वागत है';

  @override
  String get onboardingWelcomeBody =>
      'चिपट्यून, ट्रैकर मॉड्यूल और गेम म्यूज़िक का प्लेयर — Amiga, Atari, C64, कंसोल, आर्केड और PC। बड़े ऑनलाइन आर्काइव से सुनें, या अपनी फ़ाइलें खोलें।';

  @override
  String onboardingVersion(String version, String build) {
    return 'वर्शन $version (बिल्ड $build)';
  }

  @override
  String get onboardingExploreTitle => 'एक्सप्लोर करें';

  @override
  String get onboardingExploreBody =>
      'बड़े ऑनलाइन आर्काइव से हज़ारों चिपट्यून और ट्रैकर मॉड्यूल ब्राउज़ और सर्च करें — आर्टिस्ट, एल्बम, प्लेटफ़ॉर्म या पार्टी के अनुसार। सुनने के लिए टैप करें, रखने के लिए डाउनलोड करें।';

  @override
  String get onboardingLibraryTitle => 'आपकी लाइब्रेरी';

  @override
  String get onboardingLibraryBody =>
      'जो पसंद आए उसे सेव करें, प्लेलिस्ट बनाएँ, उन्हें फ़ोल्डर में रखें। डाउनलोड की गई हर चीज़ ऑफ़लाइन चलती है, और साइन इन करने पर आपकी लाइब्रेरी हर डिवाइस पर साथ रहती है।';

  @override
  String get onboardingPlayerTitle => 'प्लेयर';

  @override
  String get onboardingPlayerBody =>
      'ट्रैक बदलने के लिए स्वाइप करें, और विज़ुअलाइज़र खोलें: ऑसिलोस्कोप, हर वॉइस के स्कोप, स्क्रॉल होते नोट, ट्रैकर ग्रिड। मल्टी-ट्रैक फ़ाइलें अपने सबसॉन्ग दिखाती हैं, और हर वॉइस को अलग से म्यूट किया जा सकता है।';

  @override
  String get onboardingReplayTitle => 'स्वागत टूर';

  @override
  String get onboardingReplaySubtitle => 'परिचय और फ़ीचर टूर फिर से देखें';

  @override
  String get settingsPatternTitle => 'पैटर्न';

  @override
  String get settingsPatternSubtitle => 'ट्रैकर ग्रिड: रंग, कॉलम, स्क्रॉलिंग';

  @override
  String get patternOpaqueBg => 'अपारदर्शी बैकग्राउंड';

  @override
  String get patternOpaqueBgSubtitle => 'ग्रिड के पीछे कवर आर्ट छिपाता है';

  @override
  String get commonSave => 'सेव करें';

  @override
  String get commonImport => 'इंपोर्ट करें';

  @override
  String get accountDisplayName => 'सार्वजनिक नाम';

  @override
  String get accountDisplayNameNotSet =>
      'सेट नहीं — प्लेलिस्ट पब्लिश करने के लिए ज़रूरी';

  @override
  String get accountDisplayNameHint =>
      'वह नाम जिससे आप क्रेडिट पाना चाहते हैं।';

  @override
  String get accountDisplayNameChangeWarning =>
      'इसे बदलने पर आपकी पब्लिश की गई हर प्लेलिस्ट फिर से रिव्यू में चली जाती है।';

  @override
  String get accountDisplayNameTaken =>
      'यह नाम पहले से लिया हुआ है। कोई दूसरा चुनें।';

  @override
  String get accountDisplayNameLength => '2 से 40 अक्षरों के बीच।';

  @override
  String get accountDisplayNameSaved => 'सार्वजनिक नाम सेव हो गया';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'रिव्यू के लिए वापस भेजी गई प्लेलिस्ट: $n';
  }

  @override
  String get playlistPublish => 'सार्वजनिक करें';

  @override
  String get playlistPublishSubtitle =>
      'पब्लिश करने का अनुरोध करें (पहले रिव्यू होगा)';

  @override
  String get playlistPublishTitle => 'यह प्लेलिस्ट पब्लिश करें?';

  @override
  String get playlistPublishBody =>
      'मंज़ूरी मिलने पर यह सबको दिखेगी, आपके सार्वजनिक नाम के साथ। कवर इसके ट्रैक से आता है।';

  @override
  String get playlistPublishCta => 'अनुरोध करें';

  @override
  String get playlistPublishSubmitted => 'रिव्यू के लिए भेजा गया';

  @override
  String get playlistPublishPending => 'मंज़ूरी की प्रतीक्षा में';

  @override
  String get playlistPublishApproved => 'सार्वजनिक';

  @override
  String playlistPublishRejected(String reason) {
    return 'अस्वीकृत: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'अस्वीकृत';

  @override
  String get playlistPublishNeedName =>
      'वह नाम चुनें जिससे आप क्रेडिट पाना चाहते हैं';

  @override
  String get playlistPublishNeedTracks =>
      'पब्लिश करने के लिए कम से कम 5 ट्रैक चाहिए';

  @override
  String get playlistPublishHasLocal =>
      'आपके डिवाइस की फ़ाइलें पब्लिश नहीं हो सकतीं — दूसरे उन्हें नहीं चला सकते';

  @override
  String get playlistPublishTooManyPending =>
      'आपकी 3 प्लेलिस्ट पहले से मंज़ूरी की प्रतीक्षा में हैं';

  @override
  String get playlistPublishRefused =>
      'पब्लिश अस्वीकृत: ट्रैक और लंबित अनुरोध जाँचें';

  @override
  String get playlistPublishFailed => 'पब्लिश विफल';

  @override
  String get playlistPublishWithdrawn => 'प्लेलिस्ट फिर से प्राइवेट है';

  @override
  String get playlistUnpublish => 'प्राइवेट करें';

  @override
  String get playlistUnpublishSubtitle => 'इसे सार्वजनिक प्लेलिस्ट से हटाता है';

  @override
  String get playlistRenamePublishedTitle =>
      'पब्लिश की गई प्लेलिस्ट का नाम बदलें?';

  @override
  String get playlistRenamePublishedBody =>
      'रिव्यू नाम का ही होता है: नाम बदलने पर प्लेलिस्ट फिर से मंज़ूरी के लिए जाती है और तब तक अनपब्लिश रहती है। ट्रैक जोड़ने या उनका क्रम बदलने से ऐसा नहीं होता।';

  @override
  String playlistByAuthor(String author) {
    return '$author द्वारा';
  }

  @override
  String get settingsSpectrumMode => 'स्पेक्ट्रम मोड';

  @override
  String get settingsSpectrumModeStandard => 'स्टैंडर्ड';

  @override
  String get settingsSpectrumModeColored => 'रंगीन';

  @override
  String get settingsSpectrumModeBeam => 'बीम';

  @override
  String get settingsSpectrumModeLine => 'लाइन';

  @override
  String get settingsSpectrumModeRing => 'रिंग';

  @override
  String get settingsPianoMode => 'पियानो का रूप';

  @override
  String get settingsPianoModeRoll => 'कीबोर्ड';

  @override
  String get settingsPianoModeFalling => 'गिरते नोट';

  @override
  String get settingsPianoColor => 'रंग';

  @override
  String get settingsPianoColorVoice => 'वॉइस के अनुसार';

  @override
  String get settingsPianoColorInstrument => 'इंस्ट्रूमेंट के अनुसार';

  @override
  String get settingsPianoGlow => 'दबाई गई कीज़ पर चमक';

  @override
  String get settingsPianoLighting => 'कीज़ पर रोशनी और छाया';

  @override
  String get settingsPianoVoiceNames => 'वॉइस के नाम';

  @override
  String get featuredAdditionsHeader => 'कैटलॉग में नया';

  @override
  String get featuredAdditionsCard => 'अभी जोड़ा गया';

  @override
  String get featuredAdditionsPlaylist => 'ताज़ा जोड़ी गई ट्यून';

  @override
  String get releaseNotesTitle => 'नया क्या है';

  @override
  String get releaseNotesV10Loading =>
      'धीमा ट्रैक खोलने पर अब ऐप अटकता नहीं: प्ले/पॉज़ के चारों ओर एक पतली रिंग दिखाती है कि वह अभी लोड हो रहा है।';

  @override
  String get releaseNotesV10Piano =>
      'पियानो विज़ुअलाइज़र: एक साथ कई वॉइस या इंस्ट्रूमेंट वाले गाने ज़्यादा कीबोर्ड पर फैलाए जाते हैं।';

  @override
  String get releaseNotesV10Amiga =>
      'Amiga: StoneTracker, SUNtronic (TSM रिप) और Soundtracker 2.6 के और मॉड्यूल अब चलते हैं, और SoundPlayer गाने iOS पर चलते हैं।';

  @override
  String get releaseNotesV10ZxSpectrum =>
      'ZX Spectrum: zxart की .mt3 फ़ाइलें चलती हैं, और Linux पर ZXTune फ़ॉर्मेट और SAM Coupé .cop प्रोग्राम शामिल हैं।';

  @override
  String get releaseNotesV10OpenWith =>
      'macOS और iOS: हर समर्थित फ़ॉर्मेट अब “इसके साथ खोलें” में दिखता है।';

  @override
  String get releaseNotesV10MtcCrash =>
      'ठीक किया: PT3 को TFM या PSG के साथ मिलाने वाली कुछ .mtc फ़ाइलों से ऐप क्रैश होता था।';

  @override
  String get releaseNotesV10Podiums =>
      'नया “पोडियम” ब्राउज़र: डेमोसीन प्रतियोगिता के विजेता पार्टी, साल या compo के प्रकार के अनुसार, हॉल ऑफ़ फ़ेम के साथ।';

  @override
  String get releaseNotesV10Arcade =>
      'आर्केड: Ensoniq ES5505/ES5506 संगीत (Taito F3…) अब चलता है, Apple IIGS VGM फ़ाइलों से ऐप अब क्रैश नहीं होता, और इंजन अपडेट हैं (FM-Kingtracker .fmk जोड़ा गया)।';

  @override
  String get releaseNotesV10InfoPanel =>
      'जानकारी पैनल: फ़ॉर्मेट, इंजन, चैनल और लूप पॉइंट सबसे पहले आते हैं, और फ़ील्ड के नाम उभरकर दिखते हैं।';

  @override
  String get releaseNotesV10LocalAlbums =>
      'एल्बम और सबसॉन्ग स्क्रीन कलेक्शन दिखाती हैं; ड्रॉप किया गया आर्काइव अपने सभी ट्रैक दिखाता है, “लोकल” लिखा होता है, और बदलने के बाद दो बार नहीं दिखता।';

  @override
  String get releaseNotesV10Crossfade =>
      'ठीक किया: क्रॉसफ़ेड चालू होने पर फ़ेड से छोटा ट्रैक सुनाई नहीं देता था।';

  @override
  String get releaseNotesV10Artwork =>
      'ठीक किया: सर्वर पर बदली गई आर्टवर्क अब “फ़ाइल फिर से डाउनलोड करें” के बाद हर जगह दिखती है।';

  @override
  String get releaseNotesDataReset =>
      'इस वर्शन के लिए लोकल डेटा रीसेट किया गया। आपकी लाइब्रेरी और प्लेलिस्ट आपके अकाउंट से फिर से बनती हैं; डाउनलोड नए सिरे से शुरू होते हैं।';

  @override
  String get releaseNotesDismiss => 'जारी रखें';

  @override
  String get pmManagePresets => 'प्रीसेट मैनेज करें';

  @override
  String get pmPickTooltip => 'प्रीसेट चुनें';

  @override
  String get pmPickFilter => 'प्रीसेट फ़िल्टर करें';

  @override
  String get pmSourceTooltip => 'प्रीसेट स्रोत';

  @override
  String get pmAddToPlaylistTooltip => 'प्रीसेट को प्लेलिस्ट में जोड़ें';

  @override
  String pmSlowPresetDropped(String name) {
    return '“$name” इस डिवाइस के लिए बहुत भारी है और अलग रख दिया गया।';
  }

  @override
  String get pmSlowDeviceTitle => 'यह डिवाइस बहुत धीमा है';

  @override
  String get pmSlowDeviceOff =>
      'विज़ुअलाइज़र बंद कर दिया गया: यह डिवाइस Milkdrop प्रीसेट के साथ नहीं चल पाता।';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रीसेट अलग रखे गए',
      one: '$count प्रीसेट अलग रखा गया',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'इस डिवाइस पर बहुत धीमे। प्लेबैक इन्हें छोड़ देता है।';

  @override
  String get settingsPmSlowPresetsRestore => 'वापस लाएँ';

  @override
  String get pmSourceBundled => 'बिल्ट-इन प्रीसेट';

  @override
  String get pmSourceImports => 'मेरे इंपोर्ट';

  @override
  String get pmSourceAll => 'सभी प्रीसेट';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रीसेट',
      one: '$count प्रीसेट',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'नई प्लेलिस्ट…';

  @override
  String get pmPlaylistName => 'प्लेलिस्ट का नाम';

  @override
  String get pmAddedToPlaylist => 'प्लेलिस्ट में जोड़ा गया';

  @override
  String get pmAlreadyInPlaylist => 'पहले से इस प्लेलिस्ट में है';

  @override
  String get pmTabPacks => 'पैक';

  @override
  String get pmTabBrowse => 'ब्राउज़';

  @override
  String get pmTabPlaylists => 'प्लेलिस्ट';

  @override
  String get pmTabPopular => 'लोकप्रिय';

  @override
  String get pmTabSetAside => 'अलग रखे गए';

  @override
  String get pmSetAsideEmpty =>
      'कुछ भी अलग नहीं रखा गया। जिन प्रीसेट से यह डिवाइस 6 fps से नीचे चला जाता है, वे यहाँ आते हैं।';

  @override
  String get pmSetAsideRestoreAll => 'सभी वापस लाएँ';

  @override
  String get pmInstall => 'इंस्टॉल करें';

  @override
  String get pmInstallQueued => 'इंस्टॉल कतार में';

  @override
  String get pmUninstall => 'अनइंस्टॉल करें';

  @override
  String get pmUninstalled => 'पैक हटा दिया गया';

  @override
  String get pmUse => 'इस्तेमाल करें';

  @override
  String get pmDefaultPackBanner => 'सुझाया गया स्टार्टर पैक';

  @override
  String pmLicense(String license) {
    return 'लाइसेंस: $license';
  }

  @override
  String get pmPacksOffline => 'सर्वर से संपर्क नहीं हो पा रहा';

  @override
  String get pmSearchPresets => 'प्रीसेट खोजें…';

  @override
  String get pmPlayNow => 'अभी चलाएँ';

  @override
  String get pmDownloadAction => 'डाउनलोड करें';

  @override
  String get pmDownloaded => 'प्रीसेट डाउनलोड हो गया';

  @override
  String get pmDownloadFailed => 'डाउनलोड विफल';

  @override
  String pmPreviewing(String name) {
    return 'चल रहा है: $name';
  }

  @override
  String get pmLocalSection => 'मेरी प्लेलिस्ट';

  @override
  String get pmCuratedSection => 'Rewamp प्लेलिस्ट';

  @override
  String get pmImportPlaylist => 'डाउनलोड करें और इस्तेमाल करें';

  @override
  String get pmPlaylistImported => 'प्लेलिस्ट तैयार है';

  @override
  String get pmImportFiles => 'फ़ाइलें इंपोर्ट करें…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रीसेट इंपोर्ट हुए',
      one: '$count प्रीसेट इंपोर्ट हुआ',
      zero: 'कोई प्रीसेट इंपोर्ट नहीं हुआ',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'प्रीसेट projectM लाइब्रेरी में जोड़े गए';

  @override
  String get pmNoPlaylists => 'अभी कोई प्रीसेट प्लेलिस्ट नहीं';

  @override
  String get pmSourceApplied => 'प्रीसेट स्रोत लागू किया गया';

  @override
  String get pmPlaylistEmpty => 'यह प्लेलिस्ट खाली है';

  @override
  String get pmDays7 => '7 दिन';

  @override
  String get pmDays30 => '30 दिन';

  @override
  String get pmDays365 => '1 साल';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्ले',
      one: '$count प्ले',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'इंस्टॉल विफल';

  @override
  String get pmSingleDownloads => 'अलग-अलग डाउनलोड';

  @override
  String pmAvailableIn(String pack) {
    return '$pack में उपलब्ध';
  }

  @override
  String get pmCleanUp => 'साफ़ करें';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रीसेट डिलीट हुए',
      one: '$count प्रीसेट डिलीट हुआ',
      zero: 'साफ़ करने को कुछ नहीं',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'यह प्रीसेट लॉक करें';

  @override
  String get pmUnlockAction => 'प्रीसेट अनलॉक करें';

  @override
  String get pmOrderRandom => 'प्रीसेट शफ़ल करें';

  @override
  String get pmOrderSequential => 'प्रीसेट क्रम से चलाएँ';

  @override
  String get pmUpdateAvailable => 'अपडेट उपलब्ध';

  @override
  String get pmUpdate => 'अपडेट करें';

  @override
  String get pmSelectAll => 'सभी चुनें';

  @override
  String get pmSelectNone => 'सभी का चयन हटाएँ';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए',
      one: '$count चुना गया',
      zero: 'कोई नहीं चुना',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'बिना इस्तेमाल के टेक्सचर';

  @override
  String pmTexturesFreed(String size) {
    return '$size खाली हुआ';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टेक्सचर',
      one: '$count टेक्सचर',
    );
    return '$_temp0';
  }

  @override
  String get browseCharts => 'चार्ट';

  @override
  String get chartsGlobal => 'ग्लोबल';

  @override
  String get chartsByCollection => 'कलेक्शन के अनुसार';

  @override
  String get chartsTopSongs => 'टॉप गाने';

  @override
  String get chartsTopAlbums => 'टॉप एल्बम';

  @override
  String get chartsRewampSection => 'टॉप Rewamp';

  @override
  String get chartsPublishedSection => 'प्रकाशित चार्ट';

  @override
  String chartsUpdated(String date) {
    return 'अपडेट: $date';
  }

  @override
  String get chartsSource => 'स्रोत';

  @override
  String get settingsMidiSynth => 'MIDI सिंथेसाइज़र';

  @override
  String get settingsMidiSynthAuto => 'ऑटोमैटिक (जब फ़ाइल माँगे तब MT-32)';

  @override
  String get settingsMidiSynthSoundfont => 'SoundFont (FluidLite)';

  @override
  String get settingsMidiSynthMt32 => 'Roland MT-32 (एमुलेशन)';

  @override
  String get settingsMt32Section => 'Roland MT-32 एमुलेशन';

  @override
  String get settingsMt32RomsTitle => 'MT-32 ROM';

  @override
  String get settingsMt32RomsMissing =>
      'कोई इस्तेमाल लायक ROM सेट नहीं — किसी MT-32 या CM-32L के control और PCM ROM इंपोर्ट करें';

  @override
  String settingsMt32RomsActive(String set) {
    return 'सक्रिय सेट: $set';
  }

  @override
  String get settingsMt32Import => 'ROM फ़ाइलें इंपोर्ट करें…';

  @override
  String get settingsMt32ImportSubtitle =>
      'Control + PCM ROM (.rom/.bin), MAME के बँटे हुए हिस्से भी मान्य। ROM ऐप के साथ नहीं दिए जाते।';

  @override
  String settingsMt32ImportRejected(String name) {
    return '$name कोई ज्ञात MT-32 / CM-32L ROM नहीं है';
  }

  @override
  String settingsMt32ImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ROM फ़ाइलें इंपोर्ट हुईं',
      one: '$count ROM फ़ाइल इंपोर्ट हुई',
    );
    return '$_temp0';
  }

  @override
  String get settingsMt32Model => 'मॉडल';

  @override
  String get settingsMt32ModelAuto => 'ऑटोमैटिक (उपलब्ध हो तो CM-32L)';

  @override
  String get settingsMt32Reverb => 'रिवर्ब';

  @override
  String get engineDescMt32 =>
      'MIDI (.mid/.midi/.kar/.rmi) के लिए Roland MT-32 / CM-32L एमुलेशन';

  @override
  String get miniWindowEnter => 'मिनी प्लेयर';

  @override
  String get miniWindowExit => 'मुख्य विंडो पर वापस';

  @override
  String get miniWindowIdle => 'कुछ नहीं चल रहा';

  @override
  String get settingsAlwaysOnTopTitle => 'हमेशा सबसे ऊपर';

  @override
  String get settingsAlwaysOnTopSubtitle =>
      'विंडो को बाकी सब के ऊपर रखें — मुख्य विंडो और मिनी प्लेयर दोनों';

  @override
  String get windowAlwaysOnTopOn => 'हमेशा सबसे ऊपर: चालू';

  @override
  String get miniWindowCoverFill => 'कवर को ज़ूम करके भरें';

  @override
  String get miniWindowCoverFit => 'पूरा कवर दिखाएँ';

  @override
  String get libraryFileMissing => 'फ़ाइल नहीं है';

  @override
  String get settingsPlayStartSection => 'प्लेबैक शुरू करना';

  @override
  String get settingsPlayStartInApp => 'ऐप में किसी ट्रैक पर टैप करना';

  @override
  String get settingsPlayStartInAppHint =>
      'देर तक दबाने (राइट-क्लिक) पर हमेशा विकल्प मिलता है।';

  @override
  String get settingsPlayStartExternal => 'सिस्टम से खोली गई फ़ाइल';

  @override
  String get settingsPlayStartExternalHint =>
      'डबल-क्लिक, “इसके साथ खोलें”, ऐप आइकन पर छोड़ना।';

  @override
  String get settingsPlayStartAsk => 'पूछें';

  @override
  String get settingsLaunchWindow => 'शुरू होने पर';

  @override
  String get settingsLaunchWindowNormal => 'सामान्य विंडो';

  @override
  String get settingsLaunchWindowMini => 'मिनी प्लेयर';

  @override
  String get settingsLaunchWindowLast => 'जैसा बंद करते समय था';

  @override
  String get miniWindowQuit => 'Rewamp बंद करें';

  @override
  String get miniWindowCompact => 'कॉम्पैक्ट मिनी प्लेयर';
}
