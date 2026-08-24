// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get navHome => 'Etusivu';

  @override
  String get navSearch => 'Haku';

  @override
  String get navLibrary => 'Kirjasto';

  @override
  String get noFileSelected => 'Ei valittua tiedostoa';

  @override
  String get openFile => 'Avaa tiedosto';

  @override
  String get pickerLabelAudio => 'Ääni';

  @override
  String get formatNotSupported => 'Muotoa ei tueta';

  @override
  String playbackFormatUnsupported(String file, String ext) {
    return 'Tukematon muoto: $file (.$ext)';
  }

  @override
  String playbackFileMissing(String file) {
    return 'Ei tällä laitteella: $file';
  }

  @override
  String playbackFileGone(String file) {
    return 'Tiedostoa ei enää ole palvelimella: $file';
  }

  @override
  String get failedToLoadFile => 'Tiedoston lataus epäonnistui';

  @override
  String get libraryEmptyHint =>
      'Artistisi, albumisi ja soittolistasi\nnäkyvät täällä.';

  @override
  String get libraryPlaylists => 'Soittolistat';

  @override
  String get libraryArtists => 'Artistit';

  @override
  String get libraryAlbums => 'Albumit';

  @override
  String get libraryTracks => 'Kappaleet';

  @override
  String get libraryFavorites => 'Suosikit';

  @override
  String get libraryFavoritesSubtitle =>
      'Automaattinen soittolista suosikkikappaleistasi';

  @override
  String get libraryRecentlyAdded => 'Viimeksi lisätyt';

  @override
  String get libraryEmpty => 'Täällä ei ole vielä mitään';

  @override
  String get libraryRemoved => 'Poistettu kirjastosta';

  @override
  String get searchHint => 'Hae…';

  @override
  String get searchTypePlaceholder => 'Kirjoita nimi, artisti tai albumi…';

  @override
  String get searchNoResults => 'Ei tuloksia';

  @override
  String get searchDownloading => 'Ladataan…';

  @override
  String searchError(String message) {
    return 'Virhe: $message';
  }

  @override
  String get tabAll => 'Kappaleet';

  @override
  String get tabArtists => 'Artistit';

  @override
  String get tabAlbums => 'Albumit';

  @override
  String get tabProductions => 'Tuotannot';

  @override
  String get filterWithVideo => 'Videolla';

  @override
  String get videoUnavailable => 'Tämä video ei ole saatavilla';

  @override
  String get noItems => 'Ei kohteita';

  @override
  String get sortRelevance => 'Osuvuus';

  @override
  String get sortAZ => 'A–Ö';

  @override
  String get recentlyPlayed => 'Viimeksi toistetut';

  @override
  String get noRecentTracks => 'Ei viimeksi toistettuja kappaleita';

  @override
  String get openLocalFile => 'Avaa paikallinen tiedosto';

  @override
  String get playerSourceLocal => 'paikallinen';

  @override
  String get browseFiles => 'Selaa tiedostoja';

  @override
  String countTotal(int loaded, int total) {
    return '$loaded / $total tulosta';
  }

  @override
  String countLoadingMore(int loaded) {
    return '$loaded ladattu…';
  }

  @override
  String countComplete(int loaded) {
    return '$loaded tulosta';
  }

  @override
  String countScrollMore(int loaded) {
    return '$loaded ladattu — vieritä nähdäksesi lisää';
  }

  @override
  String countNLoaded(int n) {
    return '$n ladattu';
  }

  @override
  String countFilesLoaded(int n) {
    return '$n tiedostoa';
  }

  @override
  String get browseFilterByTitle => 'Suodata nimen mukaan…';

  @override
  String get browseNoSongs => 'Ei kappaleita saatavilla';

  @override
  String get browseByFormat => 'Formaatin mukaan';

  @override
  String get browseByFormatSubtitle => 'MOD, XM, S3M, IT…';

  @override
  String get browseFilterByFormat => 'Suodata formaatin mukaan…';

  @override
  String get browseByPlatform => 'Alustan mukaan';

  @override
  String get browseByPlatformSubtitle => 'NES, SNES, Mega Drive, PlayStation…';

  @override
  String get browsePlatformNameHint => 'Alustan nimi…';

  @override
  String get browseByChip => 'Äänipiirin mukaan';

  @override
  String get browseByChipSubtitle => 'YM2612, SPC700, APU…';

  @override
  String get browseChipHint => 'esim. YM2612, SPC700…';

  @override
  String get browseOk => 'OK';

  @override
  String get browseByArtist => 'Artistin mukaan';

  @override
  String get browseByArtistSubtitle => 'Selaa säveltäjiä';

  @override
  String get browseFilterByName => 'Suodata nimen mukaan…';

  @override
  String get browseNoArtistFound => 'Artistia ei löytynyt';

  @override
  String get browseNoArtistsAvailable => 'Ei artisteja saatavilla';

  @override
  String get browseNoArtist => 'Ei artisteja';

  @override
  String get browseNoAlbum => 'Ei albumeita';

  @override
  String get browseTopPacks => 'Parhaat paketit';

  @override
  String get browseTopPacksSubtitle => 'Parhaiten arvostellut paketit';

  @override
  String browseTopPacksLabel(String collection) {
    return 'Parhaat paketit — $collection';
  }

  @override
  String get browseLatestPacks => 'Uusimmat paketit';

  @override
  String get browseLatestPacksSubtitle => 'Viimeisimmät lisäykset';

  @override
  String browseLatestPacksLabel(String collection) {
    return 'Uusimmat paketit — $collection';
  }

  @override
  String get browseAllSongs => 'Kaikki kappaleet';

  @override
  String get browseAllSongsSubtitleAlpha => 'Selaa aakkosjärjestyksessä';

  @override
  String get browseAlphabetical => 'Aakkosjärjestyksessä';

  @override
  String browseAllLabel(String collection) {
    return 'Kaikki — $collection';
  }

  @override
  String get browseCollections => 'Kokoelmat';

  @override
  String browseFilesCount(String count) {
    return '$count tiedostoa';
  }

  @override
  String get browseIndexing => 'Indeksointi käynnissä';

  @override
  String browseFilterFacet(String name) {
    return 'Suodata: $name…';
  }

  @override
  String get browseAllYears => 'Kaikki vuodet';

  @override
  String get browseAllYearsSubtitle => 'Kaikki partyn kappaleet';

  @override
  String get browseNoCompo => 'Tälle partylle ei ole indeksoitu yhtään compoa.';

  @override
  String get browseOthers => 'Muut';

  @override
  String browseCompoEntries(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kilpailutyötä — sijoitusjärjestys',
      one: '$n kilpailutyö — sijoitusjärjestys',
    );
    return '$_temp0';
  }

  @override
  String get browsePlayPlaylist => 'Toista soittolista';

  @override
  String get browsePlayAllRanked => 'Toista kaikki (sijoitusjärjestyksessä)';

  @override
  String browsePlaylistTracksRanked(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta — sijoitusjärjestys',
      one: '$n kappale — sijoitusjärjestys',
    );
    return '$_temp0';
  }

  @override
  String get browseByAlbums => 'Selaa albumeittain';

  @override
  String get browsePlayAll => 'Toista kaikki';

  @override
  String get browseShuffle => 'Satunnaistoisto';

  @override
  String get browseSearchInFolder => 'Hae tästä kansiosta…';

  @override
  String get browseFilterThisList => 'Suodata tätä luetteloa…';

  @override
  String get browseSearchSubfolders => 'Etsi alikansioista';

  @override
  String get browseEmptyFolder => 'Tyhjä kansio';

  @override
  String browsePlaybackError(String message) {
    return 'Toisto epäonnistui: $message';
  }

  @override
  String browseTracksCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    return '$_temp0';
  }

  @override
  String get browseViewMode => 'Näkymä';

  @override
  String get browseViewList => 'Lista';

  @override
  String get browseViewGrid => 'Ruudukko';

  @override
  String get browseViewGridCompact => 'Tiivis ruudukko';

  @override
  String get browseSearchAlbum => 'Hae albumia…';

  @override
  String get browseSearchArtist => 'Hae artistia…';

  @override
  String get browsePlayAlbum => 'Toista albumi';

  @override
  String get searchDownloadingAlbum => 'Ladataan albumia…';

  @override
  String get searchCategoryChip => 'Äänipiirit';

  @override
  String get searchCategoryGroup => 'Ryhmät';

  @override
  String get artistRealName => 'Oikea nimi';

  @override
  String get artistAliases => 'Aliakset';

  @override
  String get artistBorn => 'Syntynyt';

  @override
  String get artistInterview => 'Haastattelu';

  @override
  String get audioOutput => 'Äänilähtö';

  @override
  String get audioOutputSystemDefault => 'Järjestelmän oletus';

  @override
  String get vizRangeAuto => 'Auto';

  @override
  String get contextNotes => 'Muistiinpanot';

  @override
  String get notePlacedBadge => 'Sijoittui kilpailussa';

  @override
  String groupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jäsentä',
      one: '$count jäsen',
    );
    return '$_temp0';
  }

  @override
  String get groupViewSongs => 'Näytä kappaleet';

  @override
  String artistModules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moduulia',
      one: '$count moduuli',
    );
    return '$_temp0';
  }

  @override
  String get searchCategoryParty => 'Partyt';

  @override
  String get searchCategoryYear => 'Vuosi';

  @override
  String get searchCategoryOrigin => 'Alkuperä';

  @override
  String get searchCategoryProduction => 'Tuotanto';

  @override
  String get searchCategoryProductionType => 'Tuotantotyypit';

  @override
  String get searchCategoryPublisher => 'Julkaisijat';

  @override
  String get searchCategoryDeveloper => 'Kehittäjät';

  @override
  String get searchCategoryArcadeBoard => 'Arcade-levyt';

  @override
  String get searchCategorySaga => 'Sarja';

  @override
  String get searchCategoryGenre => 'Genre';

  @override
  String get searchViaArtist => 'artistin kautta';

  @override
  String get searchViaAlbum => 'albumin kautta';

  @override
  String get searchViaSong => 'kappaleen kautta';

  @override
  String get searchSortPopular => 'Suositut';

  @override
  String get searchSortYear => 'Vuosi';

  @override
  String get searchSortRandom => 'Satunnainen';

  @override
  String get searchSortRating => 'Arvio';

  @override
  String statsTopPercent(int percent) {
    return 'Top $percent %';
  }

  @override
  String ratingVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ääntä',
      one: '$count ääni',
    );
    return '$_temp0';
  }

  @override
  String get searchSortAsc => 'Nouseva';

  @override
  String get searchSortDesc => 'Laskeva';

  @override
  String get searchFilters => 'Suodattimet';

  @override
  String get searchExactSearch => 'Tarkka haku';

  @override
  String get searchExactSearchSubtitle =>
      'Poistaa käytöstä sumean (fuzzy) haun';

  @override
  String get searchTags => 'Tunnisteet';

  @override
  String searchTagSearchHint(String category) {
    return 'Hae tunnistetta luokasta « $category »…';
  }

  @override
  String get searchTagTypeToSearch => 'Kirjoita hakeaksesi tunnisteita.';

  @override
  String get searchTagsAndLogic => 'Useampi tunniste = looginen JA.';

  @override
  String get searchFilterYear => 'Vuosi';

  @override
  String get searchFilterAll => 'kaikki';

  @override
  String searchYearRange(int min, int max) {
    return '$min – $max';
  }

  @override
  String get searchYearFilterNote =>
      'Vuoden mukaan suodattaminen jättää pois kappaleet, joilla ei ole vuosilukua.';

  @override
  String get searchMinRating => 'Arvosana ≥';

  @override
  String searchRatingValue(String value) {
    return '★ $value';
  }

  @override
  String get searchCancel => 'Peruuta';

  @override
  String get searchReset => 'Nollaa';

  @override
  String get searchApply => 'Käytä';

  @override
  String get searchClearRecent => 'Tyhjennä viimeisimmät haut';

  @override
  String get searchBrowse => 'Selaa';

  @override
  String get searchBrowseHint =>
      'Valitse näkökulma (ryhmä, äänipiiri, vuosi…) ja tutki katalogia, tai käynnistä yltä Radio tai Yllätys.';

  @override
  String get searchDidYouMean => 'Vähän tuloksia — kokeillaanko sumeaa hakua?';

  @override
  String get searchYes => 'Kyllä';

  @override
  String get featuredCommunityTitle => 'Uutta yhteisöltä';

  @override
  String get searchPlaylistSourceAll => 'Kaikki';

  @override
  String get searchPlaylistSourceUser => 'Yhteisö';

  @override
  String get searchPlaylistSourceServer => 'Rewamp';

  @override
  String get searchFormat => 'Formaatti';

  @override
  String get searchPlatform => 'Alusta';

  @override
  String get filterCollection => 'Kokoelma';

  @override
  String get videoWatchDemo => 'Katso demo';

  @override
  String searchFacetSelected(String label, String value) {
    return '$label: $value';
  }

  @override
  String searchCollectionLabel(String name) {
    return 'Kokoelma: $name';
  }

  @override
  String get searchCollectionAll => 'Kaikki';

  @override
  String get searchRadio => 'Radio';

  @override
  String get searchRadioTooltip => 'Satunnainen jono nykyisillä suodattimilla';

  @override
  String get searchSurprise => 'Yllätys';

  @override
  String get searchSurpriseTooltip => 'Satunnainen kappale';

  @override
  String searchTabWithCount(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get searchNoSongs => 'Ei kappaleita';

  @override
  String searchSongsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    return '$_temp0';
  }

  @override
  String searchAlbumsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albumia',
      one: '$n albumi',
    );
    return '$_temp0';
  }

  @override
  String searchAka(String name) {
    return 'alias $name';
  }

  @override
  String get searchChooseCollection => 'Valitse kokoelma';

  @override
  String get searchFilterCollections => 'Suodata kokoelmia…';

  @override
  String get searchFilterPlaceholder => 'Suodata…';

  @override
  String searchAllOf(String label) {
    return 'Kaikki ($label)';
  }

  @override
  String get searchNoMatch => 'Ei osumia';

  @override
  String get searchNoPlaylist => 'Ei soittolistoja';

  @override
  String get engineDescOpenmpt => 'Tracker-moduulit (MOD/XM/S3M/IT/…)';

  @override
  String get engineDescVgm =>
      'VGM/S98/GYM/DRO — äänipiirit, kanavakohtainen skooppi';

  @override
  String get engineDescGme =>
      'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN-arkistot';

  @override
  String get engineDescNsfplay => 'NES NSF/NSFe — kanavakohtaiset äänet';

  @override
  String get engineDescGbsplay => 'Game Boy GBS';

  @override
  String get engineDescSidplayfp => 'Commodore 64 SID (reSIDfp-moottori)';

  @override
  String get engineDescNez => 'PC-Engine HES + Sega SGC (SN76489/YM2413)';

  @override
  String get engineDescKss => 'MSX-chiptunet (KSS/MGS/BGM/MPK/MBM/OPX)';

  @override
  String get engineDescFurnace =>
      'Monipiiriset chiptunet .fur / FamiTracker .ftm';

  @override
  String get engineDescZxtune =>
      'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp';

  @override
  String get engineDescUade =>
      'Amigan custom chip -formaatit 68k-emuloinnilla (~320 tiedostopäätettä)';

  @override
  String get engineDescHively => 'AHX / Hively Tracker (.ahx/.hvl/.thx)';

  @override
  String get engineDescAsap => 'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)';

  @override
  String get engineDescAdplug => 'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)';

  @override
  String get engineDescMidi =>
      'Standardi-MIDI + SoundFont (.mid/.midi/.kar/.rmi)';

  @override
  String get engineDescHighlyExp => 'PlayStation PSF/PSF2';

  @override
  String get engineDescGsf => 'Game Boy Advance .gsf/.minigsf';

  @override
  String get engineDescVio2sf => 'Nintendo DS .2sf/.mini2sf';

  @override
  String get engineDescNcsf =>
      'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ-syntetisaattori (16 ääntä)';

  @override
  String get engineDescV2m => 'V2M-syntetisaattori (.v2m/.v2mz)';

  @override
  String get engineDescSndh =>
      'Atari ST .sndh — aito 68000-emulointi + YM2149 + STE DAC';

  @override
  String get engineDescLazyusf =>
      'Nintendo 64 .usf — R4300-emulointi + RSP-ääni';

  @override
  String get engineDescWonderswan => 'WonderSwan .wsr — NEC V30MZ -emulointi';

  @override
  String get engineDescQsf => 'Capcom QSound .qsf — Z80 + QSound-piiri';

  @override
  String get engineDescHighlyTheoritical =>
      'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP';

  @override
  String get engineDescPt3 =>
      'ZX Spectrum .pt3 — aito AY-3-8910/YM2149-syntetisaattori';

  @override
  String get engineDescOrganya => 'Cave Story .org — Pixelin oma moottori';

  @override
  String get engineDescPxtone => 'Pixelin tracker — .ptcop/.pttune';

  @override
  String get engineDescSc68 =>
      'Atari ST (YM2149/STE) + Amiga (Paula) — aito 68000 emu68:lla';

  @override
  String get engineDescPmd =>
      'PC-98:n Professional Music Driver — OPNA-FM + SSG + PPZ8-näytteet';

  @override
  String get engineDescMdx =>
      'Sharp X68000 — .mdx (+ .pdx-näytteet), YM2151-FM';

  @override
  String get engineDescFmp =>
      'PC-98:n FMP-ajuri — OPNA + PPZ8 (.opi/.ovi/.ozi)';

  @override
  String get engineDescEup => 'FM Townsin EUPHONY — YM2612-FM + PCM (.eup)';

  @override
  String get engineDescMac => 'Häviötön .ape';

  @override
  String get engineDescVgmstream =>
      'Pelien suoratoistetut äänimuodot (700+, mm. .rrds)';

  @override
  String get engineDescMiniaudio => 'PCM/MP3/FLAC/OGG — varadekooderi';

  @override
  String browseCountSongs(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total kappaletta',
      one: '$loaded / 1 kappale',
    );
    return '$_temp0';
  }

  @override
  String browseCountAlbums(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total albumia',
      one: '$loaded / 1 albumi',
    );
    return '$_temp0';
  }

  @override
  String browseCountArtists(int total, int loaded) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$loaded / $total artistia',
      one: '$loaded / 1 artisti',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedSongs(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedAlbums(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n albumia',
      one: '$n albumi',
    );
    return '$_temp0';
  }

  @override
  String browseLoadedArtists(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artistia',
      one: '$n artisti',
    );
    return '$_temp0';
  }

  @override
  String browseGroupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ryhmää',
      one: '$n ryhmä',
    );
    return '$_temp0';
  }

  @override
  String get browseCountries => 'Maat';

  @override
  String browseCountriesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n maata',
      one: '$n maa',
    );
    return '$_temp0';
  }

  @override
  String get browseFoldersCard => 'Kansiot';

  @override
  String get featuredTitle => 'Päivän nostot';

  @override
  String featuredPartyNow(String party) {
    return '$party on parhaillaan käynnissä — aiempien vuosien palkintosijat';
  }

  @override
  String featuredPartyStartsIn(int days, String party) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          '$party alkaa $days päivän kuluttua — aiempien vuosien palkintosijat',
      one: '$party alkaa huomenna — aiempien vuosien palkintosijat',
    );
    return '$_temp0';
  }

  @override
  String featuredPartySeason(String series) {
    return '$series-kausi — aiempien vuosien palkintosijat';
  }

  @override
  String featuredMonthReleased(String month, String year) {
    return 'Julkaistu $month $year';
  }

  @override
  String featuredAnniversaryYearsAgo(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age vuotta sitten: vuoden $year pelit',
      one: 'Vuosi sitten: vuoden $year pelit',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthDecade(String decade) {
    return '$decade-luku';
  }

  @override
  String featuredAnniversaryAge(int age, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age vuotta sitten: vuoden $year pelit',
      one: 'Vuosi sitten: vuoden $year pelit',
    );
    return '$_temp0';
  }

  @override
  String featuredMonthHeader(String month) {
    return 'Julkaisut: $month';
  }

  @override
  String get featuredAnniversaryHeader => 'Vuosipäivät';

  @override
  String get featuredBirthdayHeader => 'Tämän päivän syntymäpäivät';

  @override
  String get featuredBirthdayWeekHeader => 'Tämän viikon syntymäpäivät';

  @override
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end) {
    return '$header ($start – $end)';
  }

  @override
  String featuredBirthdayWeekArtist(String artist) {
    return '$artist viettää syntymäpäivää tällä viikolla';
  }

  @override
  String featuredGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soittolistaa',
      one: '$count soittolista',
    );
    return '$_temp0';
  }

  @override
  String get commonRetry => 'Yritä uudelleen';

  @override
  String get commonOptions => 'Valinnat';

  @override
  String get commonDownload => 'Lataa';

  @override
  String get commonDeleteDownload => 'Poista lataus';

  @override
  String get commonAddToPlaylist => 'Lisää soittolistaan';

  @override
  String get commonPlayNext => 'Toista seuraavaksi';

  @override
  String get commonAddToQueueEnd => 'Lisää jonon loppuun';

  @override
  String get commonAddToFavorites => 'Lisää suosikkeihin';

  @override
  String get commonRemoveFromFavorites => 'Poista suosikeista';

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
  String get subsongDeleteDownloadTitle => 'Poistetaanko tämä lataus?';

  @override
  String subsongDeleteDownloadBody(String path) {
    return 'Tiedosto ja sen paikalliset merkinnät (historia, kappaleet) poistetaan.\n\n$path';
  }

  @override
  String get subsongReadTracksFailed => 'Kappaleita ei voitu lukea';

  @override
  String subsongTrackNumber(int number) {
    return 'Raita $number';
  }

  @override
  String subsongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alikappaletta',
      one: '$count alikappale',
    );
    return '$_temp0';
  }

  @override
  String get subsongPlayAll => 'Toista kaikki';

  @override
  String get albumDownloading => 'Ladataan albumia…';

  @override
  String albumDownloadingProgress(int done, int total) {
    return 'Ladataan albumia… ($done/$total)';
  }

  @override
  String get albumDownloadToSeeTracks =>
      'Lataa albumi nähdäksesi sen kappaleet';

  @override
  String get albumNotDownloadedHint =>
      'Albumia ei ole ladattu — aloita toisto, niin se latautuu';

  @override
  String albumTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kappaletta',
      one: '$count kappale',
    );
    return '$_temp0';
  }

  @override
  String get albumLoadingInfo => 'Ladataan tietoja…';

  @override
  String albumAka(String label) {
    return 'alias $label';
  }

  @override
  String get albumPlayAlbum => 'Toista albumi';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kohdetta',
      one: '$count kohde',
    );
    return '$_temp0';
  }

  @override
  String get libraryDownloadFromSearchFirst =>
      'Toista tämä kappale ensin haun kautta, niin se latautuu';

  @override
  String get libraryAddedTrack => 'Kappale lisätty kirjastoosi';

  @override
  String get libraryAddedAlbum => 'Albumi lisätty kirjastoosi';

  @override
  String get libraryAddedArtist => 'Artisti lisätty kirjastoosi';

  @override
  String get libraryRemovedTrack => 'Kappale poistettu kirjastostasi';

  @override
  String get libraryRemovedAlbum => 'Albumi poistettu kirjastostasi';

  @override
  String get libraryRemovedArtist => 'Artisti poistettu kirjastostasi';

  @override
  String songTilePlayFailed(String message) {
    return 'Toisto epäonnistui: $message';
  }

  @override
  String downloadFailed(String label) {
    return 'Lataus epäonnistui — $label';
  }

  @override
  String downloadInProgress(String label) {
    return 'Ladataan — $label';
  }

  @override
  String get downloadsTitle => 'Lataukset';

  @override
  String get downloadsEmpty => 'Ei odottavia latauksia';

  @override
  String get downloadsPause => 'Keskeytä';

  @override
  String get downloadsResume => 'Jatka';

  @override
  String get downloadsCancel => 'Peruuta lataus';

  @override
  String get downloadsClear => 'Poista kaikki';

  @override
  String get downloadsPausedBanner =>
      'Lataukset keskeytetty — nykyinen tiedosto valmistuu ensin';

  @override
  String downloadInProgressPct(String label, int percent) {
    return 'Ladataan — $label $percent %';
  }

  @override
  String get miniPlayerQueue => 'Soittolista';

  @override
  String get miniPlayerHideQueue => 'Piilota soittolista';

  @override
  String get transportShuffle => 'Satunnaistoisto';

  @override
  String get transportShuffleOn => 'Satunnaistoisto käytössä';

  @override
  String get transportLoopOff => 'Kertaus pois käytöstä';

  @override
  String get transportLoopQueue => 'Kertaus: jono';

  @override
  String get transportLoopTrack => 'Kertaus: nykyinen kappale';

  @override
  String get vizStereo => 'Stereo';

  @override
  String get vizSpectrum => 'Spektri';

  @override
  String get vizVoices => 'Äänet';

  @override
  String get vizNotes => 'Nuotit';

  @override
  String get vizPatterns => 'Patternit';

  @override
  String get patternScrollMode => 'Vieritystila';

  @override
  String get patternSmoothScroll => 'Pehmeä vieritys';

  @override
  String get patternVolumeBars => 'Äänenvoimakkuuspalkit';

  @override
  String get patternColorScheme => 'Väriteema';

  @override
  String get patternSize => 'Koko';

  @override
  String get patternColumns => 'Sarakkeet';

  @override
  String get patternColumnsAll => 'Täysi';

  @override
  String get patternColumnsNoteInstr => 'Suppea';

  @override
  String get patternColumnsNote => 'Minimi';

  @override
  String get vizClose => 'Sulje visualisointi';

  @override
  String get vizFullscreen => 'Koko näyttö';

  @override
  String get vizExitFullscreen => 'Poistu koko näytöstä';

  @override
  String get vizPrevPreset => 'Edellinen preset';

  @override
  String get vizNextPreset => 'Seuraava preset';

  @override
  String get vizProjectmUnavailable => 'projectM ei ole käytettävissä';

  @override
  String get voicesTitle => 'Äänet';

  @override
  String get voicesNone => 'Tälle kappaleelle ei ole ääniä.';

  @override
  String get voicesLongPressSolo => 'pitkä painallus = soolo';

  @override
  String get voicesMuteAll => 'Mykistä kaikki';

  @override
  String get voicesUnmuteAll => 'Poista kaikkien mykistys';

  @override
  String get voicesStereoOutput => 'Stereolähtö';

  @override
  String get voicesLeft => 'Vasen';

  @override
  String get voicesRight => 'Oikea';

  @override
  String get enginesFormatsTitle => 'Toistettavat formaatit';

  @override
  String enginesFormatsSummary(int formats, int engines) {
    return '$formats toistettavaa formaattia $engines toistomoottorilla.';
  }

  @override
  String enginesLicenseFormats(String license, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formaattia',
      one: '1 formaatti',
    );
    return '$license · $_temp0';
  }

  @override
  String stilCoverOf(String title, String artist) {
    return 'Cover kappaleesta $title ($artist)';
  }

  @override
  String stilCover(String work) {
    return 'Cover: $work';
  }

  @override
  String get playerQueue => 'Jono';

  @override
  String get queueEdit => 'Muokkaa';

  @override
  String get queueEditDone => 'Valmis';

  @override
  String get queueClear => 'Tyhjennä jono';

  @override
  String get queueClearConfirmTitle => 'Tyhjennetäänkö jono?';

  @override
  String get queueClearConfirmBody =>
      'Jono tyhjennetään ja toisto pysäytetään.';

  @override
  String get queueClearConfirm => 'Tyhjennä';

  @override
  String get queueRemoveSelected => 'Poista valitut';

  @override
  String get queueRemoveTrack => 'Poista jonosta';

  @override
  String get queueReorder => 'Järjestä uudelleen';

  @override
  String get playerArtwork => 'Kansikuva';

  @override
  String get playerVisualizer => 'Visualisointi';

  @override
  String get playerVoices => 'Äänet';

  @override
  String get playerTrackInfo => 'Kappaleen tiedot';

  @override
  String get playerShowQueue => 'Soittolista';

  @override
  String get playerHideQueue => 'Piilota soittolista';

  @override
  String get playerNoTrackInfo => 'Tietoja ei ole saatavilla.';

  @override
  String get playerViewSubsongs => 'Näytä alikappaleet';

  @override
  String get playerViewAlbum => 'Näytä albumi';

  @override
  String get playerViewArtist => 'Näytä artisti';

  @override
  String get playerAddToPlaylist => 'Lisää soittolistaan';

  @override
  String get queueAddToPlaylist => 'Lisää jono soittolistaan';

  @override
  String get playerMoreOptions => 'Lisää valintoja';

  @override
  String get playerClose => 'Sulje';

  @override
  String get playerCancel => 'Peruuta';

  @override
  String get playerDelete => 'Poista';

  @override
  String get playerAddFavorite => 'Lisää suosikkeihin';

  @override
  String get playerRemoveFavorite => 'Poista suosikeista';

  @override
  String get playerAddToLibrary => 'Lisää kirjastoon';

  @override
  String get playerRemoveFromLibrary => 'Poista kirjastosta';

  @override
  String get playerAddedToLibrary => 'Kappale lisätty kirjastoon';

  @override
  String get playerRemovedFromLibrary => 'Kappale poistettu kirjastosta';

  @override
  String get playerDeleteDownload => 'Poista lataus';

  @override
  String get playerRedownload => 'Lataa tiedosto uudelleen';

  @override
  String get playerRedownloadUnavailable =>
      'Uudelleenlataus ei ole käytettävissä tälle tiedostolle';

  @override
  String get playerDeleteDownloadTitle => 'Poistetaanko lataus?';

  @override
  String playerDeleteDownloadBody(String path) {
    return 'Tiedosto ja sen paikalliset merkinnät (historia, kappaleet) poistetaan.\n\n$path';
  }

  @override
  String get homeYourTrends => 'Sinun trendisi';

  @override
  String get homeYourAllTimeTop => 'Kaikkien aikojen suosikkisi';

  @override
  String get homeTrending => 'Nousussa';

  @override
  String get homeFeaturedPlaylists => 'Nostetut soittolistat';

  @override
  String get homeAllTimeTop => 'Kaikkien aikojen suosituimmat';

  @override
  String get homePeriod7d => '7 pv';

  @override
  String get homePeriod30d => '30 pv';

  @override
  String get homePeriod90d => '90 pv';

  @override
  String homePlaysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n toistokertaa',
      one: '$n toistokerta',
    );
    return '$_temp0';
  }

  @override
  String homeTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    return '$_temp0';
  }

  @override
  String get homePlaylistUnreadable => 'Tyhjä tai lukukelvoton soittolista';

  @override
  String get homeExtractingArchive => 'Puretaan arkistoa…';

  @override
  String get homeArchiveEmpty => 'Arkistossa ei ole toistettavia tiedostoja';

  @override
  String get homeNothingPlayable => 'Valinnassa ei ole toistettavaa';

  @override
  String get homeAlbumLoadFailed => 'Tätä albumia ei voitu ladata';

  @override
  String get homeSongLoadFailed => 'Tätä kappaletta ei voitu ladata';

  @override
  String get navStats => 'Tilastot';

  @override
  String get navSettings => 'Asetukset';

  @override
  String get playlistMoveUp => 'Siirrä yläkansioon';

  @override
  String playlistFolderPlaylistCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n soittolistaa',
      one: '$n soittolista',
    );
    return '$_temp0';
  }

  @override
  String playlistFolderSubfolderCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n alikansiota',
      one: '$n alikansio',
    );
    return '$_temp0';
  }

  @override
  String get playlistDeleteFolderContentsHeader =>
      'Tämä kansio ja kaikki sen sisältö poistetaan pysyvästi:';

  @override
  String get playlistDeleteFolderEmptyBody => 'Tämä kansio poistetaan.';

  @override
  String get playlistFolderRoot => 'Juuri';

  @override
  String get playlistMoveToFolder => 'Siirrä kansioon';

  @override
  String playlistDeleteTitle(String name) {
    return 'Poistetaanko ”$name”?';
  }

  @override
  String get playlistDeleteBody => 'Tämä soittolista poistetaan pysyvästi.';

  @override
  String get playlistRenameFolderTitle => 'Nimeä kansio uudelleen';

  @override
  String get playlistClearFavorites => 'Poista kaikki suosikit';

  @override
  String get playlistClearFavoritesTitle => 'Poistetaanko kaikki suosikit?';

  @override
  String get playlistClearFavoritesBody =>
      'Menetät kaikki suosikkikappaleesi. Tätä ei voi kumota.';

  @override
  String get playlistRemoveFromLibrary => 'Poista kirjastosta';

  @override
  String get playlistServerReadOnly => 'Palvelimen soittolista · vain luku';

  @override
  String get navAbout => 'Tietoja';

  @override
  String get navMore => 'Lisää';

  @override
  String get shellAlbumQueuedAtEnd => 'Albumi lisätty jonon loppuun';

  @override
  String get shellAlbumQueuedNext => 'Albumi toistetaan seuraavaksi';

  @override
  String get shellAddingToQueue => 'Lisätään jonoon…';

  @override
  String get shellAddingNext => 'Lisätään seuraavaksi toistettavaksi…';

  @override
  String shellDownloadFailed(String error) {
    return 'Lataus epäonnistui: $error';
  }

  @override
  String shellTracksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kappaletta lisätty jonoon',
      one: '$count kappale lisätty jonoon',
    );
    return '$_temp0';
  }

  @override
  String shellTrackQueuedAtEnd(String title) {
    return '\"$title\" lisätty jonon loppuun';
  }

  @override
  String shellTrackQueuedNext(String title) {
    return '\"$title\" toistetaan seuraavaksi';
  }

  @override
  String shellDownloadFailedSkipping(String title) {
    return 'Lataus epäonnistui: $title — siirrytään seuraavaan kappaleeseen';
  }

  @override
  String get shellNetworkUnavailable =>
      'Toisto pysäytetty: verkkoyhteyttä ei näytä olevan.';

  @override
  String get statsTitle => 'Tilastot';

  @override
  String statsPeriodDays(int n) {
    return '$n päivää';
  }

  @override
  String get statsPeriodThisYear => 'Tänä vuonna';

  @override
  String get statsPeriodAll => 'Koko ajalta';

  @override
  String get statsByMonthOrYear => 'Kuukausittain / vuosittain…';

  @override
  String get statsByYear => 'Vuosittain';

  @override
  String get statsByMonth => 'Kuukausittain';

  @override
  String get statsPlaysLabel => 'Toistot';

  @override
  String get statsTracksLabel => 'Kappaleet';

  @override
  String get statsArtistsLabel => 'Artistit';

  @override
  String get statsAlbumsLabel => 'Albumit';

  @override
  String get statsListenTime => 'Kuunteluaika';

  @override
  String get statsByCollection => 'Kokoelmittain';

  @override
  String get statsByFormat => 'Formaateittain';

  @override
  String get statsByEngine => 'Moottoreittain';

  @override
  String get statsPlaylistsLabel => 'Soittolistat';

  @override
  String get statsLocalFilesSection => 'Ladatut tiedostot';

  @override
  String get statsFilesLabel => 'Tiedostot';

  @override
  String get statsSpaceLabel => 'Levytila';

  @override
  String get statsNoPlaysInPeriod => 'Ei toistoja tällä ajanjaksolla';

  @override
  String get statsNoPlays => 'Ei toistoja';

  @override
  String get statsTopTracks => 'Kuunnelluimmat kappaleet';

  @override
  String get statsTopAlbums => 'Kuunnelluimmat albumit';

  @override
  String get statsTopArtists => 'Kuunnelluimmat artistit';

  @override
  String statsTopTracksIn(String period) {
    return 'Kuunnelluimmat kappaleet — $period';
  }

  @override
  String statsTopAlbumsIn(String period) {
    return 'Kuunnelluimmat albumit — $period';
  }

  @override
  String statsTopArtistsIn(String period) {
    return 'Kuunnelluimmat artistit — $period';
  }

  @override
  String get statsSeeAll => 'Näytä kaikki';

  @override
  String statsPlays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n toistokertaa',
      one: '$n toistokerta',
    );
    return '$_temp0';
  }

  @override
  String statsTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    return '$_temp0';
  }

  @override
  String statsChartMax(int n) {
    return 'maks. $n';
  }

  @override
  String get commonCancel => 'Peruuta';

  @override
  String get commonCreate => 'Luo';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Poista';

  @override
  String get commonRename => 'Nimeä uudelleen';

  @override
  String get commonSort => 'Järjestä';

  @override
  String get commonPlayAll => 'Toista kaikki';

  @override
  String get sortName => 'Nimi';

  @override
  String get sortTitle => 'Nimi';

  @override
  String get sortArtist => 'Esittäjä';

  @override
  String get sortAlbum => 'Albumi';

  @override
  String get sortDateAdded => 'Lisäyspäivä';

  @override
  String get commonClear => 'Tyhjennä';

  @override
  String get sortRecentlyModified => 'Viimeksi muokatut';

  @override
  String get sortCreationDate => 'Luontipäivä';

  @override
  String get playlistNameHint => 'Nimi';

  @override
  String get playlistNew => 'Uusi soittolista';

  @override
  String get playlistNewFolder => 'Uusi kansio';

  @override
  String get playlistNewTooltip => 'Uusi soittolista / kansio';

  @override
  String get playlistAddTo => 'Lisää soittolistaan';

  @override
  String playlistAddToN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Lisää $n soittolistaan',
      one: 'Lisää $n soittolistaan',
    );
    return '$_temp0';
  }

  @override
  String get playlistSelectOne => 'Valitse soittolista';

  @override
  String get playlistFilterHint => 'Suodata soittolistoja…';

  @override
  String get playlistSearchHint => 'Hae soittolistaa…';

  @override
  String get playlistNoMatch => 'Ei osuvia soittolistoja';

  @override
  String get playlistNoneCreateHint =>
      'Ei soittolistoja — luo sellainen +-painikkeella';

  @override
  String playlistTrackCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
      zero: 'Ei kappaleita',
    );
    return '$_temp0';
  }

  @override
  String get playlistDuplicatesTitle => 'Jo listalla';

  @override
  String playlistDuplicatesBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kohdetta on jo valituilla soittolistoilla.',
      one: '$n kohde on jo valituilla soittolistoilla.',
    );
    return '$_temp0';
  }

  @override
  String get playlistSkipDuplicates => 'Ohita kaksoiskappaleet';

  @override
  String get playlistAddAgain => 'Lisää uudelleen';

  @override
  String playlistTracksAdded(int n, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    String _temp1 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$m soittolistaan',
      one: '$n soittolistaan',
    );
    return '$_temp0 lisätty $_temp1';
  }

  @override
  String playlistAddFailed(String error) {
    return 'Lisääminen epäonnistui: $error';
  }

  @override
  String get playlistRenameTitle => 'Nimeä soittolista uudelleen';

  @override
  String playlistDeleteFolderTitle(String name) {
    return 'Poistetaanko kansio ”$name”?';
  }

  @override
  String get playlistDeleteFolderBody =>
      'Sen sisältö siirtyy yhden tason ylemmäs.';

  @override
  String get playlistEmpty => 'Tyhjä soittolista';

  @override
  String get playlistRemoveEntry => 'Poista soittolistalta';

  @override
  String get trackOptionsAddToLibrary => 'Lisää kirjastoon';

  @override
  String get trackOptionsRemoveFromLibrary => 'Poista kirjastosta';

  @override
  String get trackOptionsAddedToLibrary => 'Kappale lisätty kirjastoon';

  @override
  String get trackOptionsRemovedFromLibrary => 'Kappale poistettu kirjastosta';

  @override
  String get trackOptionsViewAlbum => 'Näytä albumi';

  @override
  String get trackOptionsViewArtist => 'Näytä artisti';

  @override
  String get trackOptionsPlayNow => 'Toista nyt';

  @override
  String get trackOptionsPlayNext => 'Toista seuraavaksi';

  @override
  String get trackOptionsAddToQueueEnd => 'Lisää jonon loppuun';

  @override
  String get trackOptionsPlayLast => 'Toista viimeisenä';

  @override
  String get trackOptionsDeleteDownload => 'Poista lataus';

  @override
  String get trackOptionsDeleteDownloadTitle => 'Poistetaanko tämä lataus?';

  @override
  String trackOptionsDeleteDownloadBody(String path) {
    return 'Tiedosto ja sen paikalliset merkinnät (historia, kappaleet) poistetaan.\n\n$path';
  }

  @override
  String get trackOptionsDownloadDeleted => 'Lataus poistettu';

  @override
  String get trackOptionsAddToFavorites => 'Lisää suosikkeihin';

  @override
  String get trackOptionsRemoveFromFavorites => 'Poista suosikeista';

  @override
  String get trackOptionsAlbumAddedToFavorites => 'Albumi lisätty suosikkeihin';

  @override
  String get trackOptionsAlbumRemovedFromFavorites =>
      'Albumi poistettu suosikeista';

  @override
  String get trackOptionsAlbumNotDownloaded =>
      'Albumia ei ole ladattu — ei mitään poistettavaa';

  @override
  String get trackOptionsDeleteAlbumTitle => 'Poistetaanko ladattu albumi?';

  @override
  String trackOptionsDeleteAlbumBody(String dir) {
    return 'Kansio ja kaikki sen paikalliset merkinnät (kappaleet, historia) poistetaan.\n\n$dir';
  }

  @override
  String get trackOptionsAlbumDeleted =>
      'Albumi poistettu paikallisesta tallennustilasta';

  @override
  String get trackOptionsRedownloadAlbum => 'Lataa albumi uudelleen';

  @override
  String get trackOptionsRedownloadAlbumSubtitle =>
      'Kirjoittaa uudelleen sekä tiedostot ETTÄ paikalliset merkinnät';

  @override
  String get trackOptionsDeleteAlbumFiles => 'Poista albumin tiedostot';

  @override
  String get trackOptionsDeleteAlbumFilesSubtitle =>
      'Ladattu kansio + paikalliset merkinnät (historia)';

  @override
  String get settingsTitle => 'Asetukset';

  @override
  String get settingsGeneral => 'Yleiset';

  @override
  String get settingsGeneralSubtitle => 'Teema';

  @override
  String get settingsVisualisation => 'Visualisointi';

  @override
  String get settingsVisualisationSubtitle =>
      'Oskilloskoopit, kansikuva taustana';

  @override
  String get settingsPlayback => 'Toisto';

  @override
  String get settingsPlaybackSubtitle => 'Kertaukset, häivytys, hiljaisuus';

  @override
  String get settingsEngines => 'Moottorit';

  @override
  String get settingsEnginesSubtitle => 'libopenmpt, NSF, GBS, MIDI';

  @override
  String get settingsData => 'Tiedot';

  @override
  String get settingsDataSubtitle => 'Tunniste, historia, nollaus';

  @override
  String get settingsBackupExport => 'Vie varmuuskopio';

  @override
  String get settingsBackupExportSubtitle =>
      'Tallenna kirjasto, soittolistat ja asetukset tiedostoon';

  @override
  String get settingsBackupImport => 'Tuo varmuuskopio';

  @override
  String get settingsBackupImportSubtitle =>
      'Palauta tiedot varmuuskopiotiedostosta';

  @override
  String get settingsBackupExportFailed => 'Varmuuskopion vienti epäonnistui';

  @override
  String get settingsBackupImportConfirmTitle => 'Tuodaanko varmuuskopio?';

  @override
  String get settingsBackupImportConfirmBody =>
      'Tämä korvaa kirjaston, soittolistat ja asetukset tällä laitteella. Ladatut tiedostot säilytetään.';

  @override
  String get settingsBackupImportConfirm => 'Tuo';

  @override
  String get settingsBackupImportedTitle => 'Varmuuskopio tuotu';

  @override
  String get settingsBackupImportedBody =>
      'Tietosi on palautettu. Käynnistä sovellus uudelleen ottaaksesi kaiken käyttöön.';

  @override
  String get settingsBackupTooNew =>
      'Tämä varmuuskopio on tehty sovelluksen uudemmalla versiolla';

  @override
  String get settingsBackupInvalid => 'Ei kelvollinen Rewamp-varmuuskopio';

  @override
  String get settingsBackupImportFailed => 'Varmuuskopion tuonti epäonnistui';

  @override
  String get settingsAbout => 'Tietoja';

  @override
  String get settingsAboutSubtitle => 'Tekijät ja lisenssit';

  @override
  String get settingsCreditsSubtitle => 'Kirjastot, data ja komponentit';

  @override
  String get settingsSupport => 'Yhteystiedot ja tuki';

  @override
  String get settingsSupportSubtitle => 'Ota yhteyttä, verkkosivu';

  @override
  String get settingsSupportEmail => 'Lähetä sähköposti';

  @override
  String get settingsSupportEmailSubtitle => 'Kysymys, virhe tai ehdotus';

  @override
  String get settingsSupportEmailSubject => 'Rewamp — tuki';

  @override
  String get settingsSupportEmailIntro =>
      'Kuvaile yllä kysymyksesi, virhe tai ehdotus. Alla olevat tiedot auttavat meitä auttamaan sinua.';

  @override
  String get settingsSupportWebsite => 'Verkkosivu';

  @override
  String get settingsDonation => 'Tue Rewampia';

  @override
  String get settingsDonationSubtitle => 'Tippi, jos haluat';

  @override
  String get settingsDonationBlurb =>
      'Rewamp on ilmainen ja mainokseton — intohimosta tehty työ demoscene- ja retrokulttuurin säilyttämiseksi. Lahjoitukset auttavat rahoittamaan sovelluksen kehitystä ja kattamaan tietokannan ylläpitokulut. Ei velvoitetta: jos sovellus ilahduttaa sinua, pieni ele on aina tervetullut.';

  @override
  String get settingsDonationFloppy => 'Levyke';

  @override
  String get settingsDonationCartridge => 'Kasetti';

  @override
  String get settingsDonationBox => 'Kotelopeli';

  @override
  String get settingsDonationCustom => 'Valitse summa';

  @override
  String get settingsCancel => 'Peruuta';

  @override
  String get settingsOk => 'OK';

  @override
  String get settingsDelete => 'Poista';

  @override
  String get settingsReset => 'Nollaa';

  @override
  String get settingsRenew => 'Uudista';

  @override
  String get settingsOff => 'Pois';

  @override
  String get settingsOn => 'Päällä';

  @override
  String get settingsAuto => 'Auto';

  @override
  String get settingsInfinite => 'Ääretön';

  @override
  String get settingsDefault => 'Oletus';

  @override
  String get settingsCoreNoScope => 'ei oskilloskooppia';

  @override
  String get settingsNone => 'Ei mitään';

  @override
  String get settingsLevelLow => 'Matala';

  @override
  String get settingsLevelHigh => 'Korkea';

  @override
  String get settingsStereo => 'Stereo';

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
  String get settingsTheme => 'Teema';

  @override
  String get settingsThemeLight => 'Vaalea';

  @override
  String get settingsThemeDark => 'Tumma';

  @override
  String get settingsArtworkTintTitle => 'Sävytä soitin kansikuvan mukaan';

  @override
  String get settingsArtworkTintSubtitle =>
      'Soitin poimii kannen hallitsevan värin';

  @override
  String get settingsGlassEffectTitle => 'Liquid glass -tehoste';

  @override
  String get settingsGlassEffectSubtitle =>
      'Linssi ja sumennus alapalkeissa — poista käytöstä hitailla laitteilla';

  @override
  String get settingsResetSection => 'Nollaa tämä osio';

  @override
  String get settingsResetEngine => 'Nollaa tämä moottori';

  @override
  String get settingsResetChoices => 'Nollaa nämä valinnat';

  @override
  String get settingsResetToDefault => 'Oletusarvo';

  @override
  String get settingsStartInVizTitle => 'Käynnistä visualisointitilassa';

  @override
  String get settingsStartInVizSubtitle =>
      'Soitin avautuu oskilloskooppeihin kansikuvan sijaan';

  @override
  String get settingsVoiceGridTitle => 'Ääniskoopin ruudukko';

  @override
  String get settingsVoiceGridSubtitle =>
      'Näytä äänet toisistaan erottavat reunaviivat';

  @override
  String get settingsKeepAwakeTitle => 'Pidä näyttö päällä';

  @override
  String get settingsKeepAwakeSubtitle =>
      'Kun visualisointi on näkyvissä, näyttö ei himmene eikä lukitu';

  @override
  String get settingsVoiceNamesTitle => 'Äänten nimet';

  @override
  String get settingsVoiceNamesSubtitle =>
      'Näytä kunkin äänen nimi sen omassa kehyksessä';

  @override
  String get settingsLineThickness => 'Viivan paksuus';

  @override
  String get settingsColors => 'Värit';

  @override
  String get settingsScopeVoiceColor => 'Ääniskooppi';

  @override
  String get settingsStereoColors => 'Stereo: värit';

  @override
  String get settingsStereoMono => 'Mono';

  @override
  String get settingsStereoBi => 'Bi';

  @override
  String get settingsStereoMonoColor => 'Stereo (mono)';

  @override
  String get settingsStereoLeftColor => 'Stereo vasen';

  @override
  String get settingsStereoRightColor => 'Stereo oikea';

  @override
  String get settingsNotation => 'Nuotinnus (nuotit)';

  @override
  String get settingsNotePalette => 'Väripaletti';

  @override
  String get settingsNoteBoxStyle => 'Palkkien tyyli';

  @override
  String get settingsNoteStyleFlat => 'Flat';

  @override
  String get settingsNoteStyleBox => 'Box';

  @override
  String get settingsCrtEffects => 'CRT-efektit';

  @override
  String get settingsCrtGlow => 'Hehku (glow)';

  @override
  String get settingsCrtSpeed => 'Voimakkuus / nopeus';

  @override
  String get settingsArtworkOpacity => 'Taustan kansikuvan peittävyys';

  @override
  String get settingsProjectMTitle => 'projectM-asetukset';

  @override
  String get settingsProjectMSubtitle => 'Presetit, siirtymät, laatu, mesh…';

  @override
  String get settingsNotifyTrackTitle => 'Ilmoitukset kappaleen vaihtuessa';

  @override
  String get settingsNotifyTrackSubtitle =>
      'Järjestelmäilmoitus uuden kappaleen nimellä';

  @override
  String get settingsSilenceDetection => 'Hiljaisuuden tunnistus';

  @override
  String get settingsSilenceSkipTitle =>
      'Siirry seuraavaan kappaleeseen hiljaisuuden kohdalla';

  @override
  String get settingsSilenceSkipSubtitle =>
      'Etenee automaattisesti, kun ulostulo pysyy hiljaisena';

  @override
  String get settingsSilenceDelay => 'Hiljaisuuden viive';

  @override
  String get settingsDefaultDuration => 'Oletuskesto';

  @override
  String get settingsDefaultDurationHelp =>
      'Käytetään, kun kappale ei ilmoita tunnettua kestoa (ei tagia, ei palvelimen metatietoja) — estää sitä soimasta tai kertautumasta loputtomiin. Ei koskaan käytössä Amiga-kappaleilla (UADE), joilla on oma kestotietokantansa.';

  @override
  String get settingsForcedLoopHeader => 'Pakotettu kertaus / häivytys';

  @override
  String get settingsForcedLoopHelp =>
      'Osa formaateista kertaa tietyn osan (VGM, tracker-moduulit…), osa ei. \"Ääretön\" ohittaa kappaleen luonnollisen lopun.';

  @override
  String get settingsForceLoopCount => 'Pakota kertausten määrä';

  @override
  String get settingsLoopCount => 'Kertausten määrä';

  @override
  String get settingsForceFadeout => 'Pakota häivytys';

  @override
  String get settingsFadeoutDuration => 'Häivytyksen kesto';

  @override
  String get settingsResetEnginesTitle => 'Nollataanko moottoriasetukset?';

  @override
  String get settingsResetEnginesBody =>
      'Kaikki moottoriasetukset palautuvat oletusarvoihinsa.';

  @override
  String get settingsResetDefaultsTitle => 'Palauta oletusarvot';

  @override
  String get settingsResetDefaultsSubtitle => 'Kaikki moottorit';

  @override
  String get settingsDefaultDecoders => 'Oletusdekooderit';

  @override
  String get settingsDefaultDecodersSubtitle =>
      'Formaatit, joita useampi moottori osaa toistaa';

  @override
  String get settingsDecodersHelp =>
      'Osaa formaateista pystyy toistamaan useampi moottori. Valitse, mitä niistä käytetään oletuksena — muut formaatit ohjautuvat automaattisesti.';

  @override
  String get settingsDecoderAmigaTrackers => 'Amiga-trackerit (mod, med, okt…)';

  @override
  String get settingsEngineOpenmptSubtitle => 'Trackerit — MOD, XM, S3M, IT…';

  @override
  String get settingsEngineGmeSubtitle =>
      'SPC, VGM(gme), KSS, AY… — EQ, stereo';

  @override
  String get settingsEngineNsfSubtitle =>
      'NES / NSF — laatu, suodattimet, piirikohtaiset valinnat';

  @override
  String get settingsEngineGbsSubtitle => 'Game Boy / GBS — ylipäästösuodatin';

  @override
  String get settingsEngineMidiSubtitle => 'MIDI — käytössä oleva SoundFont';

  @override
  String get settingsEngineGsfSubtitle =>
      'GBA / GSF — interpolointi, alipäästö, kaiku';

  @override
  String get settingsEngineUadeSubtitle =>
      'Amiga — panorointi, kuulokkeet, vahvistus, LED';

  @override
  String get settingsEngineSidSubtitle =>
      'C64 / SID — kello, malli, ReSIDfp-suodattimet';

  @override
  String get settingsEngineAdplugSubtitle =>
      'AdLib OPL — stereo/surround-harmoniatila';

  @override
  String get settingsEngineHeSubtitle => 'PSF / PS1-PS2 — SPU, kaiunta';

  @override
  String get settingsEngineVgmSubtitle =>
      'VGM / S98 / DRO — YM2612-, OPL3- ja QSound-ytimet…';

  @override
  String get settingsMasterVolume => 'Kokonaisäänenvoimakkuus';

  @override
  String get settingsAmigaFilter => 'Amiga-suodatin';

  @override
  String get settingsInterpolation => 'Interpolointi';

  @override
  String get settingsPolyphony => 'Polyfonia';

  @override
  String get settingsReverb => 'Kaiku';

  @override
  String get settingsChorus => 'Chorus';

  @override
  String get settingsInterpNone => 'Ei mitään';

  @override
  String get settingsInterpLinear => 'Lineaarinen';

  @override
  String get settingsInterpCubic => 'Kuutiollinen';

  @override
  String get settingsInterpSinc => 'Sinc (paras)';

  @override
  String get settingsStereoSeparation => 'Stereoerottelu';

  @override
  String get settingsGmeSilenceSubtitle =>
      'Päättää kappaleen, kun moottori havaitsee pitkän hiljaisuuden';

  @override
  String get settingsStereoDepth => 'Stereosyvyys';

  @override
  String get settingsEqualizer => 'Taajuuskorjain';

  @override
  String get settingsGmeEqSubtitle =>
      'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — ei vaikuta SPC:hen';

  @override
  String get settingsBass => 'Basso';

  @override
  String get settingsTreble => 'Diskantti';

  @override
  String get settingsAppliedLive => 'Tulee voimaan heti, myös toiston aikana.';

  @override
  String get settingsAppliedNextTrack =>
      'Tulee voimaan seuraavaksi ladattavassa kappaleessa.';

  @override
  String get settingsSidEmulation => 'Emulointi';

  @override
  String get settingsSidResidfp => 'ReSIDfp (tarkka)';

  @override
  String get settingsSidLite => 'SIDLite (nopea)';

  @override
  String get settingsSidSampling => 'Näytteistys';

  @override
  String get settingsSidSamplingInterp => 'Interpolointi (nopea)';

  @override
  String get settingsSidSamplingResample => 'Resample (paras)';

  @override
  String get settingsSidClock => 'Kello';

  @override
  String get settingsSidModel => 'SID-malli';

  @override
  String get settingsSidFilter => 'SID-suodatin';

  @override
  String get settingsSidForceSecond => 'Pakota 2. SID';

  @override
  String get settingsSidSecondSubtitle => 'Stereot 2SID-kappaleet';

  @override
  String get settingsSidSecondAddr => '2. SID:n osoite';

  @override
  String get settingsSidForceThird => 'Pakota 3. SID';

  @override
  String get settingsSidThirdAddr => '3. SID:n osoite';

  @override
  String get settingsSidAutoFilter => 'Automaattinen 6581-suodatinalue';

  @override
  String get settingsSidAutoFilterSubtitle =>
      'Kappaleen tekijälle suositeltu arvo (sidplayfp-taulukot)';

  @override
  String get settingsSid6581Range => '6581-suodatinalue';

  @override
  String get settingsSid6581Curve => '6581-suodatinkäyrä';

  @override
  String get settingsSid8580Curve => '8580-suodatinkäyrä';

  @override
  String get settingsSidNote =>
      'SID-suodatin ja käyrät tulevat voimaan heti; emulointi, näytteistys, kello, malli sekä 2. ja 3. SID vasta seuraavassa kappaleessa.';

  @override
  String get settingsAudioOutput => 'Äänilähtö';

  @override
  String get settingsAdplugNote =>
      'Surround: kaksi hieman epävireistä OPL-piiriä. Tulee voimaan seuraavassa kappaleessa.';

  @override
  String get settingsHeSpuMain => 'Pääasialliset äänet (SPU)';

  @override
  String get settingsHeSpuReverb => 'Kaiunta (SPU)';

  @override
  String get settingsNsfQuality => 'Laatu (nsfplay)';

  @override
  String get settingsLowpassFilter => 'Alipäästösuodatin';

  @override
  String get settingsHighpassFilter => 'Ylipäästösuodatin';

  @override
  String get settingsRegion => 'Alue';

  @override
  String get settingsNsfRegionNtscForced => 'NTSC pakotettu';

  @override
  String get settingsNsfRegionPalForced => 'PAL pakotettu';

  @override
  String get settingsNsfRegionDendyForced => 'Dendy pakotettu';

  @override
  String get settingsNsfForceIrq => 'Pakota IRQ';

  @override
  String get settingsNsfApu1Title => '2A03 — pulssit (APU1)';

  @override
  String get settingsNsfApu2Title => '2A03 — kolmio / kohina / DPCM (APU2)';

  @override
  String get settingsNsfUnmuteOnReset => 'Poista mykistys nollauksessa';

  @override
  String get settingsNsfPhaseRefresh => 'Päivitä vaihe';

  @override
  String get settingsNsfPhaseRefreshSubtitle =>
      'Nollaa vaihe, kun jakso kirjoitetaan';

  @override
  String get settingsNsfNonlinearMixer => 'Epälineaarinen miksaus';

  @override
  String get settingsNsfApu1NonlinearSubtitle =>
      '2A03:n aito miksaus (muuten lineaarinen)';

  @override
  String get settingsNsfDutySwap => 'Vaihda duty-syklit keskenään';

  @override
  String get settingsNsfDutySwapSubtitle =>
      '25 %:n ja 50 %:n duty-syklien järjestys';

  @override
  String get settingsNsfNegateSweep => 'Negatiivinen sweep alustuksessa';

  @override
  String get settingsNsfEnable4011 => 'Rekisteri \$4011 käytössä';

  @override
  String get settingsNsfEnable4011Subtitle =>
      'Suora DAC-ulostulo (alkuperäiset naksahdukset)';

  @override
  String get settingsNsfPeriodicNoise => 'Jaksollinen kohina';

  @override
  String get settingsNsfPeriodicNoiseSubtitle =>
      'Kohinageneraattorin lyhyt tila';

  @override
  String get settingsNsfDpcmAntiClick => 'DPCM-naksahdusten esto';

  @override
  String get settingsNsfRandomizeNoise => 'Satunnaista kohina alustuksessa';

  @override
  String get settingsNsfTriangleMute => 'Mykistä kolmio';

  @override
  String get settingsNsfTriangleMuteSubtitle =>
      'Vaimentaa kolmion ultraäänijaksoilla';

  @override
  String get settingsNsfRandomizeTri => 'Satunnaista kolmio alustuksessa';

  @override
  String get settingsNsfDpcmReverse => 'Käänteinen DPCM';

  @override
  String get settingsNsfN163Serial => 'Sarjamultipleksaus';

  @override
  String get settingsNsfN163SerialSubtitle =>
      'N163:n aito surina moniäänisissä kappaleissa';

  @override
  String get settingsNsfN163PhaseReadOnly => 'Vaihe vain luettavissa';

  @override
  String get settingsNsfN163LimitWavelength => 'Rajoita aallonpituutta';

  @override
  String get settingsNsfFdsCutoff => 'Alipäästön rajataajuus';

  @override
  String get settingsNsfFds4085Reset => '\$4085-nollaus';

  @override
  String get settingsNsfFdsWriteProtect => 'Kirjoitussuojaus';

  @override
  String get settingsNsfVrc7Patch => 'Patch-sarja';

  @override
  String get settingsNsfVrc7Opll => 'OPLL-tila';

  @override
  String get settingsNsfVrc7OpllSubtitle => 'Emuloi YM2413:a VRC7:n sijaan';

  @override
  String get settingsGbsHpFilter => 'Ylipäästösuodatin (gbsplay)';

  @override
  String get settingsGbsFilterDmg => 'DMG (klassinen GB)';

  @override
  String get settingsGbsFilterCgb => 'CGB (GB Color)';

  @override
  String get settingsEcho => 'Kaiku';

  @override
  String get settingsUadePostfx => 'Jälkikäsittely';

  @override
  String get settingsUadePostfxSubtitle =>
      'Ottaa efektiketjun käyttöön (vaaditaan kaikkiin alla oleviin)';

  @override
  String get settingsUadePan => 'Panorointi (stereoerottelu)';

  @override
  String get settingsUadePanValue => 'Panoroinnin määrä';

  @override
  String get settingsUadeHeadphones => 'Kuulokkeet';

  @override
  String get settingsUadeLed => 'LED (Paula-suodatin)';

  @override
  String get settingsUadeLedAuto => 'Auto (kappaleen mukaan)';

  @override
  String get settingsUadeLedOn => 'Pakotettu päälle';

  @override
  String get settingsUadeLedOff => 'Pakotettu pois';

  @override
  String get settingsUadeFilterType => 'Suodattimen tyyppi';

  @override
  String get settingsUadeGain => 'Vahvistus';

  @override
  String get settingsUadeGainValue => 'Vahvistuksen määrä';

  @override
  String get settingsSoundfontLoading => 'Ladataan luetteloa…';

  @override
  String settingsSoundfontCatalogueError(String error) {
    return 'Luettelo ei ole käytettävissä ($error)';
  }

  @override
  String settingsSoundfontDownloadFailed(String error) {
    return 'Lataus epäonnistui: $error';
  }

  @override
  String get settingsSoundfontImport => 'Tuo SoundFont…';

  @override
  String get settingsSoundfontImportSubtitle =>
      'Valitse .sf2-tiedosto tältä laitteelta';

  @override
  String get settingsSoundfontImported => 'Tuotu';

  @override
  String get settingsSoundfontInvalid =>
      'Tämä tiedosto ei ole SoundFont (.sf2)';

  @override
  String settingsSoundfontImportFailed(String error) {
    return 'Tuonti epäonnistui — $error';
  }

  @override
  String get settingsSoundfontDelete => 'Poista tiedosto';

  @override
  String get settingsCreditsHeader => 'Tekijät ja lisenssit';

  @override
  String get settingsRightsNotice =>
      'Rewamp on soitin: se ei isännöi tiedostoja eikä jaa musiikkia. Kappaleet ovat peräisin verkossa toimivista säilytysarkistoista ja pysyvät oikeudenhaltijoidensa omaisuutena. Sinun vastuullasi on varmistaa, että niiden kuuntelu, lataaminen ja säilyttäminen on sovellettavien oikeuksien ja maasi lainsäädännön mukaista.';

  @override
  String settingsFormatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tuettua formaattia',
      one: '$count tuettu formaatti',
    );
    return '$_temp0';
  }

  @override
  String settingsFormatsEngines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jakautuvat $count toistomoottorille — katso tiedot',
      one: 'Yksi toistomoottori hoitaa ne — katso tiedot',
    );
    return '$_temp0';
  }

  @override
  String get settingsUadeDataTitle => 'Amiga-kestot ja -metatiedot';

  @override
  String get settingsUadeDataSubtitle =>
      'audacious-uade songdb, tekijä Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.';

  @override
  String get settingsGb64Title => 'C64 / SID -tiedot ja kansikuvat';

  @override
  String get settingsGb64Subtitle =>
      'GameBase64 (gb64.com) — C64-pelien metatiedot ja kuvat.';

  @override
  String get settingsFt2FontTitle => 'FastTracker 2 -fontti';

  @override
  String get settingsFt2FontSubtitle =>
      'Pattern-visualisoijan FastTracker II -tyyli käyttää ft2-clonen FT2-bittikarttafonttia, tekijä 8bitbubsy (16-bits.org).';

  @override
  String settingsLinkCopied(String url) {
    return '$url kopioitu';
  }

  @override
  String get settingsOpenLink => 'Avaa linkki';

  @override
  String get settingsEnginesHeader => 'Toistomoottorit';

  @override
  String get settingsComponentsHeader => 'Muut komponentit';

  @override
  String get settingsResetAll => 'Nollaa kaikki asetukset';

  @override
  String get settingsResetAllSubtitle =>
      'Yleiset, Visualisointi, Toisto, Moottorit — ei kirjastoa';

  @override
  String get settingsResetAllTitle => 'Nollataanko kaikki asetukset?';

  @override
  String get settingsResetAllBody =>
      'Yleiset, Visualisointi, Toisto ja kaikki moottorit palautuvat oletusarvoihinsa. Kirjastoosi ja historiaasi ei kosketa.';

  @override
  String get settingsRenewUserId => 'Uudista anonyymi tunniste';

  @override
  String get settingsRenewUserIdTitle => 'Uudistetaanko anonyymi tunniste?';

  @override
  String get settingsRenewUserIdBody =>
      'Palvelintilastoja varten luodaan uusi anonyymi tunniste.\n\nVanhaa ei enää käytetä. Paikallinen historiasi ja suosikkisi säilyvät ennallaan.';

  @override
  String get settingsRenewUserIdFailed =>
      'Epäonnistui — palvelimeen ei saatu yhteyttä';

  @override
  String settingsNewUserId(String id) {
    return 'Uusi tunniste: $id';
  }

  @override
  String settingsUserIdValue(String id) {
    return 'Tunniste: $id';
  }

  @override
  String get settingsNoUserId => 'Ei rekisteröityä tunnistetta';

  @override
  String get settingsCleanDb => 'Siivoa paikallinen tietokanta';

  @override
  String get settingsCleanDbSubtitle =>
      'Poistaa merkinnät, joiden tiedostoa ei enää ole (poistetut lataukset, vanhat virheet)';

  @override
  String settingsOrphansRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orpoa merkintää poistettu',
      one: '$count orpo merkintä poistettu',
    );
    return '$_temp0';
  }

  @override
  String get settingsDbClean =>
      'Paikallinen tietokanta on siisti — ei poistettavaa';

  @override
  String get settingsClearCache =>
      'Tyhjennä välimuisti (kansikuvat ja metatiedot)';

  @override
  String get settingsClearCacheSubtitle =>
      'Poistaa välimuistiin tallennetut kannet ja haetut metatiedot (STIL, kestot) — ne ladataan uudelleen seuraavalla toistolla';

  @override
  String settingsCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Välimuisti tyhjennetty ($count kansikuvaa)',
      one: 'Välimuisti tyhjennetty ($count kansikuva)',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetStats => 'Nollaa tilastot';

  @override
  String get settingsResetStatsSubtitle =>
      'Poistaa kuunteluhistorian ja toistolaskurit';

  @override
  String get settingsClearStatsTitle => 'Nollataanko tilastot?';

  @override
  String get settingsClearStatsBody =>
      'Tämä poistaa pysyvästi:\n• koko kuunteluhistorian\n• toistolaskurit\n\nSuosikkisi ja kirjastosi säilyvät ennallaan.';

  @override
  String get settingsStatsCleared => 'Tilastot poistettu';

  @override
  String get settingsResetDatabase => 'Nollaa tietokanta';

  @override
  String get settingsResetDatabaseSubtitle =>
      'Poistaa kaiken: historian, suosikit, soittolistat, välimuistin';

  @override
  String get settingsResetDbTitle => 'Nollataanko tietokanta?';

  @override
  String get settingsResetDbBody =>
      'Tämä poistaa pysyvästi:\n• koko kuunteluhistorian\n• kaikki laskurit\n• kaikki suosikit\n• kaikki soittolistat\n• kaikki välimuistiin tallennetut metatiedot\n\nÄänitiedostojasi ei poisteta.';

  @override
  String get settingsDbReset => 'Tietokanta nollattu';

  @override
  String get settingsDeleteDownloads => 'Poista lataukset';

  @override
  String get settingsDeleteDownloadsSubtitle =>
      'Poistaa kaikki tiedostot online-kansiosta (kappaleet, kansikuvat)';

  @override
  String get settingsDeleteDownloadsTitle => 'Poistetaanko lataukset?';

  @override
  String get settingsDeleteDownloadsBody =>
      'Tämä poistaa pysyvästi kaikki ladatut tiedostot (kappaleet, albumit, kansikuvat) online-kansiosta.\n\nTietokantamerkinnät jäävät, mutta ne osoittavat tiedostoihin, joita ei enää ole.';

  @override
  String get settingsDownloadsDeleted => 'Lataukset poistettu';

  @override
  String get settingsColor => 'Väri';

  @override
  String get settingsPmPresets => 'Presetit';

  @override
  String get settingsPmRandomNext => 'Satunnainen seuraava preset';

  @override
  String get settingsPmRandomNextSubtitle =>
      'Pois: presetit soivat järjestyksessä';

  @override
  String get settingsPmLockPreset => 'Lukitse preset';

  @override
  String get settingsPmLockPresetSubtitle => 'Ei automaattista vaihtoa';

  @override
  String get settingsPmPresetDuration => 'Aika presettien välillä';

  @override
  String get settingsPmTransitions => 'Siirtymät';

  @override
  String get settingsPmBlend => 'Ristihäivytyssiirtymä';

  @override
  String get settingsPmBlendSubtitle => 'Pois: preset vaihtuu välittömästi';

  @override
  String get settingsPmTransitionStyle => 'Siirtymän tyyli';

  @override
  String get settingsPmTransitionStyleSubtitle =>
      'Ristihäivytyksen käyttämä kuvio';

  @override
  String get settingsPmTransitionRandom => 'Satunnainen';

  @override
  String get settingsPmHardcut => 'Hardcut';

  @override
  String get settingsPmHardcutSubtitle =>
      'Presetin vaihto tahtiin synkronoituna';

  @override
  String get settingsPmHardcutTime => 'Hardcut: vähimmäisaika';

  @override
  String get settingsPmHardcutSensitivity => 'Hardcut: herkkyys';

  @override
  String get settingsPmRendering => 'Renderöinti';

  @override
  String get settingsPmQuality => 'Laatu';

  @override
  String get settingsPmQualitySubtitle =>
      'Renderöinnin tarkkuus (Max = natiivi tarkkuus)';

  @override
  String get settingsPmBeatSensitivity => 'Iskuherkkyys';

  @override
  String get settingsPmAspectRatio => 'Säilytä kuvasuhde';

  @override
  String get settingsPmAspectRatioSubtitle => 'Sitä tukeville shadereille';

  @override
  String get settingsPmPermissive => 'Salliva tila';

  @override
  String get settingsPmPermissiveSubtitle =>
      'Lataa .milk-tiedostot, joissa on skriptivirheitä';

  @override
  String get accountTitle => 'Tili';

  @override
  String get accountSubtitle => 'Tallenna ja synkronoi kirjastosi';

  @override
  String get accountAnonymous => 'Nimetön tili';

  @override
  String get accountAnonymousExplain =>
      'Suosikkisi ja historiasi ovat palvelimella, mutta vain tämä laite pääsee niihin. Lisää sähköpostiosoite, niin löydät ne muualtakin.';

  @override
  String get accountEmailAttached =>
      'Osoite vahvistettu — tämä tili voidaan palauttaa';

  @override
  String get accountEmailPending => 'Osoitetta ei ole vielä vahvistettu';

  @override
  String get accountInsecureStorage =>
      'Laitteen suojattu tallennus ei ole käytettävissä: tilin tunnus tallennetaan salaamattomana.';

  @override
  String get accountSaveCta => 'Tallenna tilini';

  @override
  String get accountStatSongs => 'Suosikkikappaleet';

  @override
  String get accountStatAlbums => 'Suosikkialbumit';

  @override
  String get accountStatPlays => 'Toistot';

  @override
  String get accountCreatedLabel => 'Luotu';

  @override
  String get accountSignOut => 'Kirjaudu ulos';

  @override
  String get accountRevoke => 'Kirjaudu ulos kaikkialta';

  @override
  String get accountRevokeSubtitle => 'Kirjaa ulos kaikki muut laitteet';

  @override
  String get accountRevokeBody =>
      'Kaikki muut laitteet kirjataan ulos. Tämä pysyy kirjautuneena.';

  @override
  String get accountRevokeDone => 'Muut laitteet kirjattu ulos';

  @override
  String get accountDelete => 'Poista tilini';

  @override
  String get accountDeleteSubtitle =>
      'Poistaa tilin ja sen tiedot palvelimelta. Peruuttamaton.';

  @override
  String accountDeleteBody(int items, int lists) {
    return 'Palvelimelta poistetaan $items suosikkia ja $lists soittolistaa. Tätä ei voi perua.';
  }

  @override
  String get accountDeleteKeepsLocal =>
      'Lataukset ja tämän laitteen kirjasto säilyvät ennallaan.';

  @override
  String get accountDeleteDone => 'Tili poistettu';

  @override
  String get accountSignOutSubtitle =>
      'Laite aloittaa uudelta, tyhjältä tililtä';

  @override
  String get accountSignOutTitle => 'Kirjaudutaanko ulos?';

  @override
  String accountSignOutBody(String email) {
    return 'Voit palata tälle tilille koodilla, joka lähetetään osoitteeseen $email.';
  }

  @override
  String get accountSignedOut => 'Kirjauduttu ulos';

  @override
  String get accountNoSignOut => 'Uloskirjautuminen ei ole käytettävissä';

  @override
  String get accountNoSignOutSubtitle =>
      'Ilman sähköpostiosoitetta tämä tili menetettäisiin lopullisesti.';

  @override
  String get accountDetach => 'Irrota osoite';

  @override
  String get accountDetachSubtitle =>
      'Tili muuttuu jälleen nimettömäksi, mitään tietoja ei poisteta';

  @override
  String get accountDetachBody =>
      'Ilman osoitetta tätä tiliä ei voi enää palauttaa toiselta laitteelta.';

  @override
  String get accountDetachDone => 'Osoite irrotettu';

  @override
  String get accountOffline => 'Tili ei ole käytettävissä offline-tilassa';

  @override
  String get accountEmailTitle => 'Sähköpostiosoite';

  @override
  String get accountEmailExplain =>
      'Lähetämme 6-numeroisen koodin osoitteen vahvistamiseksi. Sitä käytetään vain tilin palauttamiseen.';

  @override
  String get accountEmailLabel => 'Sähköpostiosoite';

  @override
  String get accountCodeTitle => 'Vahvistuskoodi';

  @override
  String accountCodeExplain(String email) {
    return 'Koodi lähetetty osoitteeseen $email. Se on voimassa 10 minuuttia.';
  }

  @override
  String get accountCodeLabel => '6-numeroinen koodi';

  @override
  String get accountSendCode => 'Lähetä koodi';

  @override
  String get accountVerify => 'Vahvista';

  @override
  String get accountResend => 'Lähetä koodi uudelleen';

  @override
  String accountResendIn(int n) {
    return 'Uusi lähetys $n s kuluttua';
  }

  @override
  String get accountCheckSpam =>
      'Viesti voi kestää minuutin — tarkista myös roskapostikansio.';

  @override
  String get accountErrorInvalidEmail => 'Virheellinen osoite';

  @override
  String get accountErrorTooMany =>
      'Liian monta pyyntöä, yritä muutaman minuutin kuluttua';

  @override
  String get accountErrorInvalidCode => 'Väärä tai vanhentunut koodi';

  @override
  String get accountErrorCodeLength => 'Koodissa on 6 numeroa';

  @override
  String get accountErrorNetwork => 'Yhteys epäonnistui, yritä uudelleen';

  @override
  String get accountMergeTitle => 'Yhdistetäänkö tämä kirjasto?';

  @override
  String accountMergeBody(String email) {
    return 'Tämän laitteen suosikit ja historia lisätään tiliin $email. Toimintoa ei voi perua.';
  }

  @override
  String get accountMergeConfirm => 'Yhdistä';

  @override
  String get accountCarryLocal => 'Säilytä tämän laitteen suosikit';

  @override
  String accountCarryLocalOn(int n) {
    return 'Tämän laitteen suosikit ($n) ja soittolistat lisätään tiliin.';
  }

  @override
  String get accountCarryLocalOff =>
      'Ne poistetaan tästä laitteesta ja korvataan tilin omilla. Ladatut tiedostot säilyvät.';

  @override
  String get accountDropLocalTitle => 'Poistetaanko tämän laitteen tiedot?';

  @override
  String get accountCreatedOk => 'Tili tallennettu, kirjastosi on turvassa';

  @override
  String get accountMergedOk =>
      'Kirjauduttu — paikalliset suosikkisi lisättiin';

  @override
  String get accountSignedInOk => 'Kirjauduttu sisään';

  @override
  String get playlistEntryMissing => 'Tiedosto puuttuu tästä laitteesta';

  @override
  String get playlistEntryMissingRestorable =>
      'Tiedosto puuttuu — voi ladata uudelleen';

  @override
  String playlistMissingCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n puuttuu',
      one: '$n puuttuu',
    );
    return '$_temp0';
  }

  @override
  String get playlistBackupToAccount => 'Tallenna tililleni';

  @override
  String get playlistBackupSubtitle =>
      'Säilyttää soittolistan myös uudelleenasennuksen jälkeen';

  @override
  String get playlistBackupUpdate => 'Päivitä varmuuskopio';

  @override
  String get playlistBackupUpdateSubtitle =>
      'Korvaa tilin kopion tällä versiolla';

  @override
  String get playlistBackupStop => 'Lopeta tallentaminen';

  @override
  String get playlistBackupStopped => 'Varmuuskopio poistettu';

  @override
  String get playlistBackupDone => 'Soittolista tallennettu';

  @override
  String get playlistBackupFailed => 'Tallennus epäonnistui';

  @override
  String get playlistBackupNoAccount => 'Tällä laitteella ei ole tiliä';

  @override
  String get playlistSyncTooltip => 'Synkronoi tilini kanssa';

  @override
  String get playlistSyncRunning => 'Synkronoidaan…';

  @override
  String get playlistSyncDone => 'Soittolistat synkronoitu';

  @override
  String get playlistSyncPartial => 'Kaikkia soittolistoja ei voitu tallentaa';

  @override
  String get playlistFetchMissing => 'Lataa puuttuvat kappaleet';

  @override
  String get playlistFetchDone => 'Puuttuvat kappaleet ladattu';

  @override
  String get playlistFetchPartial => 'Kaikkia kappaleita ei voitu ladata';

  @override
  String get playlistEntryFetchFailed => 'Tätä kappaletta ei voitu ladata';

  @override
  String get accountStatPlaylists => 'Soittolistat';

  @override
  String get accountSyncNow => 'Synkronoi nyt';

  @override
  String get accountSyncAuto => 'Tapahtuu itsestään taustalla';

  @override
  String get accountSyncAnonymous =>
      'Varmuuskopioitu palvelimelle. Lisää sähköposti, niin voit synkronoida toisen laitteen.';

  @override
  String get accountSyncPending => 'Muutoksia odottaa lähetystä';

  @override
  String accountSyncLast(String when) {
    return 'Viimeisin synkronointi: $when';
  }

  @override
  String get accountSyncDone => 'Synkronointi valmis';

  @override
  String get accountSyncFailed =>
      'Synkronointi epäonnistui, yritetään myöhemmin';

  @override
  String get podiumFirst => '1.';

  @override
  String get podiumSecond => '2.';

  @override
  String get podiumThird => '3.';

  @override
  String podiumMusicOf(String production, String place, String compo) {
    return 'musiikki teoksesta $production, $place — $compo';
  }

  @override
  String podiumContains(String place, String compo) {
    return 'sisältää kilpailun $compo sijan $place';
  }

  @override
  String get competitionEmpty => 'Tässä kilpailussa ei ole osallistujia';

  @override
  String get competitionEntryNoMusic =>
      'Tälle osallistujalle ei ole musiikkia luettelossa';

  @override
  String competitionEntryTunes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n kappaletta',
      one: '$n kappale',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSkip => 'Ohita';

  @override
  String get onboardingNext => 'Seuraava';

  @override
  String get onboardingStart => 'Aloita';

  @override
  String get onboardingBetaTitle => 'Beta-versio';

  @override
  String get onboardingBetaBody =>
      'Rewamp on vielä kesken. Paikalliset tiedot — kirjasto, soittolistat, suosikit, tilastot — voidaan nollata ennen versiota 1.0. Lataamasi tiedostot eivät ole vaarassa, mutta säilytä tärkeät muualla.';

  @override
  String onboardingVersion(String version, String build) {
    return 'Versio $version (koontiversio $build)';
  }

  @override
  String get onboardingExploreTitle => 'Tutki';

  @override
  String get onboardingExploreBody =>
      'Selaa ja hae kymmeniätuhansia chiptuneja ja trackermoduuleja suurista verkkoarkistoista artistin, albumin, alustan tai partyn mukaan. Kosketa kuunnellaksesi, lataa säilyttääksesi.';

  @override
  String get onboardingLibraryTitle => 'Kirjastosi';

  @override
  String get onboardingLibraryBody =>
      'Tallenna mistä pidät, kokoa soittolistoja ja järjestä ne kansioihin. Ladattu soi ilman verkkoa, ja kirjasto seuraa mukanasi laitteelta toiselle kirjautumisen jälkeen.';

  @override
  String get onboardingPlayerTitle => 'Soitin';

  @override
  String get onboardingPlayerBody =>
      'Pyyhkäise vaihtaaksesi kappaletta ja avaa visualisoinnit: oskilloskooppi, äänikanavat, vierivät nuotit, trackerruudukko. Monikappaleiset tiedostot näyttävät alikappaleensa ja jokainen ääni voidaan mykistää erikseen.';

  @override
  String get onboardingReplayTitle => 'Esittely';

  @override
  String get onboardingReplaySubtitle =>
      'Katso beta-ilmoitus ja esittelykierros uudelleen';

  @override
  String get settingsPatternTitle => 'Patternit';

  @override
  String get settingsPatternSubtitle =>
      'Trackerruudukko: värit, sarakkeet, vieritys';

  @override
  String get patternOpaqueBg => 'Läpinäkymätön tausta';

  @override
  String get patternOpaqueBgSubtitle => 'Piilottaa kansikuvan ruudukon takaa';

  @override
  String get commonSave => 'Tallenna';

  @override
  String get accountDisplayName => 'Julkinen nimi';

  @override
  String get accountDisplayNameNotSet =>
      'Ei asetettu — tarvitaan soittolistan julkaisuun';

  @override
  String get accountDisplayNameHint => 'Nimi, jolla haluat tulla mainituksi.';

  @override
  String get accountDisplayNameChangeWarning =>
      'Nimen vaihto palauttaa kaikki julkaisemasi soittolistat tarkistukseen.';

  @override
  String get accountDisplayNameTaken =>
      'Tämä nimi on jo varattu. Valitse toinen.';

  @override
  String get accountDisplayNameLength => '2–40 merkkiä.';

  @override
  String get accountDisplayNameSaved => 'Julkinen nimi tallennettu';

  @override
  String accountDisplayNameBackInReview(int n) {
    return 'Tarkistukseen palautetut soittolistat: $n';
  }

  @override
  String get playlistPublish => 'Julkaise';

  @override
  String get playlistPublishSubtitle => 'Pyydä julkaisua (tarkistetaan ensin)';

  @override
  String get playlistPublishTitle => 'Julkaistaanko tämä soittolista?';

  @override
  String get playlistPublishBody =>
      'Hyväksynnän jälkeen se näkyy kaikille julkisella nimelläsi. Kansikuva tulee sen kappaleista.';

  @override
  String get playlistPublishCta => 'Pyydä';

  @override
  String get playlistPublishSubmitted => 'Lähetetty tarkistukseen';

  @override
  String get playlistPublishPending => 'Odottaa hyväksyntää';

  @override
  String get playlistPublishApproved => 'Julkinen';

  @override
  String playlistPublishRejected(String reason) {
    return 'Hylätty: $reason';
  }

  @override
  String get playlistPublishRejectedShort => 'Hylätty';

  @override
  String get playlistPublishNeedName =>
      'Valitse nimi, jolla haluat tulla mainituksi';

  @override
  String get playlistPublishNeedTracks =>
      'Julkaisuun tarvitaan vähintään 5 kappaletta';

  @override
  String get playlistPublishHasLocal =>
      'Laitteesi tiedostoja ei voi julkaista — muut eivät voi toistaa niitä';

  @override
  String get playlistPublishTooManyPending =>
      'Sinulla on jo 3 soittolistaa odottamassa hyväksyntää';

  @override
  String get playlistPublishRefused =>
      'Julkaisu hylätty: tarkista kappaleet ja odottavat pyynnöt';

  @override
  String get playlistPublishFailed => 'Julkaisu epäonnistui';

  @override
  String get playlistPublishWithdrawn => 'Soittolista on taas yksityinen';

  @override
  String get playlistUnpublish => 'Tee yksityiseksi';

  @override
  String get playlistUnpublishSubtitle =>
      'Poistaa sen julkisista soittolistoista';

  @override
  String get playlistRenamePublishedTitle =>
      'Nimetäänkö julkaistu soittolista uudelleen?';

  @override
  String get playlistRenamePublishedBody =>
      'Tarkistuksen kohteena on nimi: uudelleennimeäminen palauttaa soittolistan tarkistukseen ja piilottaa sen siksi aikaa. Kappaleiden lisääminen tai järjestäminen ei.';

  @override
  String playlistByAuthor(String author) {
    return 'tekijä $author';
  }

  @override
  String get settingsSpectrumMode => 'Spektrin tila';

  @override
  String get settingsSpectrumModeStandard => 'Perus';

  @override
  String get settingsSpectrumModeColored => 'Värillinen';

  @override
  String get settingsSpectrumModeBeam => 'Säde';

  @override
  String get settingsSpectrumModeLine => 'Viiva';

  @override
  String get settingsSpectrumModeRing => 'Rengas';

  @override
  String get releaseNotesTitle => 'Uutta';

  @override
  String get releaseNotesV4Downloads =>
      'Lataukset: pitkän latauksen voi perua kesken, eikä albumin arkistoa haeta enää useaan kertaan.';

  @override
  String get releaseNotesV4Queue =>
      'Jono: painike sen tyhjentämiseen, vahvistuksella — se myös pysäyttää toiston.';

  @override
  String get releaseNotesV4DropFiles =>
      'Ikkunaan pudotetut tiedostot: toista nyt, seuraavaksi tai lopuksi; kansikuvat ja oheistiedostot jäävät pois, ja arkiston mukana tullutta soittolistaa noudatetaan (oikeat nimet, ei kuolleita raitoja).';

  @override
  String get releaseNotesV4Soundfont =>
      'MIDI: tuo oma SoundFont laitteelta palvelimen tarjoamien rinnalle.';

  @override
  String get releaseNotesV4Formats =>
      'Wwise-, FSB- ja OGL-pelivirrat soivat vihdoin (oma Vorbis).';

  @override
  String get releaseNotesV4Chips =>
      'Kuusi äänipiiriä lisää, emulointiytimen valinta piirikohtaisesti (SameBoy Game Boylle) ja oikea sävelkorkeus näytepiireillä.';

  @override
  String get releaseNotesV4Zx =>
      'ZX Spectrum: .vt2-kappaleet soivat, ja nuotti- ja kuvionäkymät kattavat koko ZX-perheen.';

  @override
  String get releaseNotesV4Loop =>
      'Kappaleen toisto kiertää oikeasti sen sijaan että lataisi uudelleen, eikä laskuri jäädy loputtomassa kierrossa.';

  @override
  String get releaseNotesV4Info =>
      'ⓘ-paneeli listaa tiedostot, jotka kappale todella avasi — oheistiedostot ja kirjastot mukaan lukien.';

  @override
  String get releaseNotesV4Linux => 'Linux-työpöytäversio.';

  @override
  String get releaseNotesDataReset =>
      'Paikalliset tiedot nollattiin tätä betaa varten. Kirjasto ja soittolistat rakentuvat tililtä; lataukset on tehtävä uudelleen.';

  @override
  String get releaseNotesDismiss => 'Jatka';

  @override
  String get pmManagePresets => 'Hallitse presetejä';

  @override
  String get pmPickTooltip => 'Valitse preset';

  @override
  String get pmPickFilter => 'Suodata presetejä';

  @override
  String get pmSourceTooltip => 'Presetien lähde';

  @override
  String get pmAddToPlaylistTooltip => 'Lisää preset soittolistaan';

  @override
  String pmSlowPresetDropped(String name) {
    return '”$name” on tälle laitteelle liian raskas ja jätettiin pois.';
  }

  @override
  String get pmSlowDeviceTitle => 'Tämä laite on liian hidas';

  @override
  String get pmSlowDeviceOff =>
      'Visualisointi kytkettiin pois: tämä laite ei pysy Milkdrop-esiasetusten perässä.';

  @override
  String settingsPmSlowPresets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count esiasetusta jätetty pois',
      one: '1 esiasetus jätetty pois',
    );
    return '$_temp0';
  }

  @override
  String get settingsPmSlowPresetsSubtitle =>
      'Liian hitaita tällä laitteella. Toisto ohittaa ne.';

  @override
  String get settingsPmSlowPresetsRestore => 'Palauta';

  @override
  String get pmSourceBundled => 'Sisäänrakennetut presetit';

  @override
  String get pmSourceImports => 'Omat tuonnit';

  @override
  String get pmSourceAll => 'Kaikki presetit';

  @override
  String pmPresetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presetiä',
      one: '$count preset',
    );
    return '$_temp0';
  }

  @override
  String get pmNewPlaylist => 'Uusi soittolista…';

  @override
  String get pmPlaylistName => 'Soittolistan nimi';

  @override
  String get pmAddedToPlaylist => 'Lisätty soittolistaan';

  @override
  String get pmAlreadyInPlaylist => 'On jo tällä soittolistalla';

  @override
  String get pmTabPacks => 'Packs';

  @override
  String get pmTabBrowse => 'Selaa';

  @override
  String get pmTabPlaylists => 'Soittolistat';

  @override
  String get pmTabPopular => 'Suositut';

  @override
  String get pmTabSetAside => 'Sivuun jätetyt';

  @override
  String get pmSetAsideEmpty =>
      'Mitään ei ole jätetty sivuun. Tänne päätyvät esiasetukset, joilla laite putoaa alle 6 fps:n.';

  @override
  String get pmSetAsideRestoreAll => 'Palauta kaikki';

  @override
  String get pmInstall => 'Asenna';

  @override
  String get pmInstallQueued => 'Asennus jonossa';

  @override
  String get pmUninstall => 'Poista asennus';

  @override
  String get pmUninstalled => 'Pack poistettu';

  @override
  String get pmUse => 'Käytä';

  @override
  String get pmDefaultPackBanner => 'Suositeltu aloitus-pack';

  @override
  String pmLicense(String license) {
    return 'Lisenssi: $license';
  }

  @override
  String get pmPacksOffline => 'Palvelin ei ole tavoitettavissa';

  @override
  String get pmSearchPresets => 'Hae presetejä…';

  @override
  String get pmPlayNow => 'Toista nyt';

  @override
  String get pmDownloadAction => 'Lataa';

  @override
  String get pmDownloaded => 'Preset ladattu';

  @override
  String get pmDownloadFailed => 'Lataus epäonnistui';

  @override
  String pmPreviewing(String name) {
    return 'Toistetaan: $name';
  }

  @override
  String get pmLocalSection => 'Omat soittolistat';

  @override
  String get pmCuratedSection => 'Rewamp-soittolistat';

  @override
  String get pmImportPlaylist => 'Lataa ja käytä';

  @override
  String get pmPlaylistImported => 'Soittolista valmis';

  @override
  String get pmImportFiles => 'Tuo tiedostoja…';

  @override
  String pmImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presetiä tuotu',
      one: '$count preset tuotu',
      zero: 'Yhtään presetiä ei tuotu',
    );
    return '$_temp0';
  }

  @override
  String get pmPresetsImported => 'Presetit lisätty projectM-kirjastoon';

  @override
  String get pmNoPlaylists => 'Ei vielä preset-soittolistoja';

  @override
  String get pmSourceApplied => 'Presetien lähde otettu käyttöön';

  @override
  String get pmPlaylistEmpty => 'Tämä soittolista on tyhjä';

  @override
  String get pmDays7 => '7 päivää';

  @override
  String get pmDays30 => '30 päivää';

  @override
  String get pmDays365 => '1 vuosi';

  @override
  String pmUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count toistokertaa',
      one: '$count toistokerta',
    );
    return '$_temp0';
  }

  @override
  String get pmInstallFailed => 'Asennus epäonnistui';

  @override
  String get pmSingleDownloads => 'Yksittäiset lataukset';

  @override
  String pmAvailableIn(String pack) {
    return 'Saatavilla paketissa $pack';
  }

  @override
  String get pmCleanUp => 'Siivoa';

  @override
  String pmCleanedUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count presetiä poistettu',
      one: '$count preset poistettu',
      zero: 'Ei siivottavaa',
    );
    return '$_temp0';
  }

  @override
  String get pmLockAction => 'Lukitse tämä preset';

  @override
  String get pmUnlockAction => 'Avaa presetin lukitus';

  @override
  String get pmOrderRandom => 'Presetit satunnaisesti';

  @override
  String get pmOrderSequential => 'Presetit järjestyksessä';

  @override
  String get pmUpdateAvailable => 'Päivitys saatavilla';

  @override
  String get pmUpdate => 'Päivitä';

  @override
  String get pmSelectAll => 'Valitse kaikki';

  @override
  String get pmSelectNone => 'Poista valinnat';

  @override
  String pmSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valittua',
      one: '$count valittu',
      zero: 'Ei valintoja',
    );
    return '$_temp0';
  }

  @override
  String get pmUnusedTextures => 'Käyttämättömät tekstuurit';

  @override
  String pmTexturesFreed(String size) {
    return '$size vapautettu';
  }

  @override
  String pmTexturesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tekstuuria',
      one: '$count tekstuuri',
    );
    return '$_temp0';
  }
}
