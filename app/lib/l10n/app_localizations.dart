import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_da.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_no.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('da'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fi'),
    Locale('fr'),
    Locale('hu'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('no'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('sv'),
    Locale('zh')
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;

  /// No description provided for @pickerLabelAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get pickerLabelAudio;

  /// No description provided for @formatNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Format not supported'**
  String get formatNotSupported;

  /// No description provided for @playbackFormatUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format: {file} (.{ext})'**
  String playbackFormatUnsupported(String file, String ext);

  /// No description provided for @playbackFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Not on this device: {file}'**
  String playbackFileMissing(String file);

  /// No description provided for @playbackFileGone.
  ///
  /// In en, this message translates to:
  /// **'File no longer on the server: {file}'**
  String playbackFileGone(String file);

  /// No description provided for @failedToLoadFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load file'**
  String get failedToLoadFile;

  /// No description provided for @libraryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your artists, albums and playlists\nwill appear here.'**
  String get libraryEmptyHint;

  /// No description provided for @libraryPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get libraryPlaylists;

  /// No description provided for @libraryArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryArtists;

  /// No description provided for @libraryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryAlbums;

  /// No description provided for @libraryTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get libraryTracks;

  /// No description provided for @libraryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libraryFavorites;

  /// No description provided for @libraryFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-playlist of your favorite tracks'**
  String get libraryFavoritesSubtitle;

  /// No description provided for @libraryRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get libraryRecentlyAdded;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get libraryEmpty;

  /// No description provided for @libraryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from library'**
  String get libraryRemoved;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchHint;

  /// No description provided for @searchTypePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type a title, artist or album…'**
  String get searchTypePlaceholder;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @searchDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get searchDownloading;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String searchError(String message);

  /// No description provided for @tabAll.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tabAll;

  /// No description provided for @tabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get tabArtists;

  /// No description provided for @tabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get tabAlbums;

  /// No description provided for @tabProductions.
  ///
  /// In en, this message translates to:
  /// **'Productions'**
  String get tabProductions;

  /// No description provided for @filterWithVideo.
  ///
  /// In en, this message translates to:
  /// **'With video'**
  String get filterWithVideo;

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This video is unavailable'**
  String get videoUnavailable;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get noItems;

  /// No description provided for @sortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get sortRelevance;

  /// No description provided for @sortAZ.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get sortAZ;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

  /// No description provided for @noRecentTracks.
  ///
  /// In en, this message translates to:
  /// **'No recently played tracks'**
  String get noRecentTracks;

  /// No description provided for @openLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Open local file'**
  String get openLocalFile;

  /// No description provided for @playerSourceLocal.
  ///
  /// In en, this message translates to:
  /// **'local'**
  String get playerSourceLocal;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @countTotal.
  ///
  /// In en, this message translates to:
  /// **'{loaded} / {total} results'**
  String countTotal(int loaded, int total);

  /// No description provided for @countLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'{loaded} loaded…'**
  String countLoadingMore(int loaded);

  /// No description provided for @countComplete.
  ///
  /// In en, this message translates to:
  /// **'{loaded} results'**
  String countComplete(int loaded);

  /// No description provided for @countScrollMore.
  ///
  /// In en, this message translates to:
  /// **'{loaded} loaded — scroll for more'**
  String countScrollMore(int loaded);

  /// No description provided for @countNLoaded.
  ///
  /// In en, this message translates to:
  /// **'{n} loaded'**
  String countNLoaded(int n);

  /// No description provided for @countFilesLoaded.
  ///
  /// In en, this message translates to:
  /// **'{n} file(s)'**
  String countFilesLoaded(int n);

  /// No description provided for @browseFilterByTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter by title…'**
  String get browseFilterByTitle;

  /// No description provided for @browseNoSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs available'**
  String get browseNoSongs;

  /// No description provided for @browseByFormat.
  ///
  /// In en, this message translates to:
  /// **'By format'**
  String get browseByFormat;

  /// No description provided for @browseByFormatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MOD, XM, S3M, IT…'**
  String get browseByFormatSubtitle;

  /// No description provided for @browseFilterByFormat.
  ///
  /// In en, this message translates to:
  /// **'Filter by format…'**
  String get browseFilterByFormat;

  /// No description provided for @browseByPlatform.
  ///
  /// In en, this message translates to:
  /// **'By platform'**
  String get browseByPlatform;

  /// No description provided for @browseByPlatformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'NES, SNES, Mega Drive, PlayStation…'**
  String get browseByPlatformSubtitle;

  /// No description provided for @browsePlatformNameHint.
  ///
  /// In en, this message translates to:
  /// **'Platform name…'**
  String get browsePlatformNameHint;

  /// No description provided for @browseByChip.
  ///
  /// In en, this message translates to:
  /// **'By sound chip'**
  String get browseByChip;

  /// No description provided for @browseByChipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'YM2612, SPC700, APU…'**
  String get browseByChipSubtitle;

  /// No description provided for @browseChipHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. YM2612, SPC700…'**
  String get browseChipHint;

  /// No description provided for @browseOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get browseOk;

  /// No description provided for @browseByArtist.
  ///
  /// In en, this message translates to:
  /// **'By artist'**
  String get browseByArtist;

  /// No description provided for @browseByArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse the composers'**
  String get browseByArtistSubtitle;

  /// No description provided for @browseFilterByName.
  ///
  /// In en, this message translates to:
  /// **'Filter by name…'**
  String get browseFilterByName;

  /// No description provided for @browseNoArtistFound.
  ///
  /// In en, this message translates to:
  /// **'No artist found'**
  String get browseNoArtistFound;

  /// No description provided for @browseNoArtistsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No artists available'**
  String get browseNoArtistsAvailable;

  /// No description provided for @browseNoArtist.
  ///
  /// In en, this message translates to:
  /// **'No artists'**
  String get browseNoArtist;

  /// No description provided for @browseNoAlbum.
  ///
  /// In en, this message translates to:
  /// **'No albums'**
  String get browseNoAlbum;

  /// No description provided for @browseTopPacks.
  ///
  /// In en, this message translates to:
  /// **'Top packs'**
  String get browseTopPacks;

  /// No description provided for @browseTopPacksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The highest-rated packs'**
  String get browseTopPacksSubtitle;

  /// No description provided for @browseTopPacksLabel.
  ///
  /// In en, this message translates to:
  /// **'Top packs — {collection}'**
  String browseTopPacksLabel(String collection);

  /// No description provided for @browseLatestPacks.
  ///
  /// In en, this message translates to:
  /// **'Latest packs'**
  String get browseLatestPacks;

  /// No description provided for @browseLatestPacksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The most recent additions'**
  String get browseLatestPacksSubtitle;

  /// No description provided for @browseLatestPacksLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest packs — {collection}'**
  String browseLatestPacksLabel(String collection);

  /// No description provided for @browseAllSongs.
  ///
  /// In en, this message translates to:
  /// **'All songs'**
  String get browseAllSongs;

  /// No description provided for @browseAllSongsSubtitleAlpha.
  ///
  /// In en, this message translates to:
  /// **'Browse in alphabetical order'**
  String get browseAllSongsSubtitleAlpha;

  /// No description provided for @browseAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'In alphabetical order'**
  String get browseAlphabetical;

  /// No description provided for @browseAllLabel.
  ///
  /// In en, this message translates to:
  /// **'All — {collection}'**
  String browseAllLabel(String collection);

  /// No description provided for @browseCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get browseCollections;

  /// No description provided for @browseFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String browseFilesCount(String count);

  /// No description provided for @browseIndexing.
  ///
  /// In en, this message translates to:
  /// **'Indexing in progress'**
  String get browseIndexing;

  /// No description provided for @browseFilterFacet.
  ///
  /// In en, this message translates to:
  /// **'Filter {name}…'**
  String browseFilterFacet(String name);

  /// No description provided for @browseAllYears.
  ///
  /// In en, this message translates to:
  /// **'All years'**
  String get browseAllYears;

  /// No description provided for @browseAllYearsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All the party\'s songs'**
  String get browseAllYearsSubtitle;

  /// No description provided for @browseNoCompo.
  ///
  /// In en, this message translates to:
  /// **'No compo indexed for this party.'**
  String get browseNoCompo;

  /// No description provided for @browseOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get browseOthers;

  /// No description provided for @browseCompoEntries.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} entry — ranking} other{{n} entries — ranking}}'**
  String browseCompoEntries(int n);

  /// No description provided for @browsePlayPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Play playlist'**
  String get browsePlayPlaylist;

  /// No description provided for @browsePlayAllRanked.
  ///
  /// In en, this message translates to:
  /// **'Play all (in ranking order)'**
  String get browsePlayAllRanked;

  /// No description provided for @browsePlaylistTracksRanked.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} track — ranking order} other{{n} tracks — ranking order}}'**
  String browsePlaylistTracksRanked(int n);

  /// No description provided for @browseByAlbums.
  ///
  /// In en, this message translates to:
  /// **'Browse by album'**
  String get browseByAlbums;

  /// No description provided for @browsePlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get browsePlayAll;

  /// No description provided for @browseShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get browseShuffle;

  /// No description provided for @browseSearchInFolder.
  ///
  /// In en, this message translates to:
  /// **'Search in this folder…'**
  String get browseSearchInFolder;

  /// No description provided for @browseFilterThisList.
  ///
  /// In en, this message translates to:
  /// **'Filter this list…'**
  String get browseFilterThisList;

  /// No description provided for @browseSearchSubfolders.
  ///
  /// In en, this message translates to:
  /// **'Search subfolders'**
  String get browseSearchSubfolders;

  /// No description provided for @browseEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get browseEmptyFolder;

  /// No description provided for @browsePlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {message}'**
  String browsePlaybackError(String message);

  /// No description provided for @browseTracksCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} track} other{{n} tracks}}'**
  String browseTracksCount(int n);

  /// No description provided for @browseViewMode.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get browseViewMode;

  /// No description provided for @browseViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get browseViewList;

  /// No description provided for @browseViewGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get browseViewGrid;

  /// No description provided for @browseViewGridCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact grid'**
  String get browseViewGridCompact;

  /// No description provided for @browseSearchAlbum.
  ///
  /// In en, this message translates to:
  /// **'Search for an album…'**
  String get browseSearchAlbum;

  /// No description provided for @browseSearchArtist.
  ///
  /// In en, this message translates to:
  /// **'Search for an artist…'**
  String get browseSearchArtist;

  /// No description provided for @browsePlayAlbum.
  ///
  /// In en, this message translates to:
  /// **'Play album'**
  String get browsePlayAlbum;

  /// No description provided for @searchDownloadingAlbum.
  ///
  /// In en, this message translates to:
  /// **'Downloading album…'**
  String get searchDownloadingAlbum;

  /// No description provided for @searchCategoryChip.
  ///
  /// In en, this message translates to:
  /// **'Chips'**
  String get searchCategoryChip;

  /// No description provided for @searchCategoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get searchCategoryGroup;

  /// No description provided for @artistRealName.
  ///
  /// In en, this message translates to:
  /// **'Real name'**
  String get artistRealName;

  /// No description provided for @artistAliases.
  ///
  /// In en, this message translates to:
  /// **'Aliases'**
  String get artistAliases;

  /// No description provided for @artistBorn.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get artistBorn;

  /// No description provided for @artistInterview.
  ///
  /// In en, this message translates to:
  /// **'Interview'**
  String get artistInterview;

  /// No description provided for @audioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio output'**
  String get audioOutput;

  /// No description provided for @audioOutputSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get audioOutputSystemDefault;

  /// No description provided for @vizRangeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get vizRangeAuto;

  /// No description provided for @contextNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get contextNotes;

  /// No description provided for @notePlacedBadge.
  ///
  /// In en, this message translates to:
  /// **'Placed in competition'**
  String get notePlacedBadge;

  /// No description provided for @groupMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} member} other{{count} members}}'**
  String groupMembersCount(int count);

  /// No description provided for @groupViewSongs.
  ///
  /// In en, this message translates to:
  /// **'View songs'**
  String get groupViewSongs;

  /// No description provided for @artistModules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} module} other{{count} modules}}'**
  String artistModules(int count);

  /// No description provided for @searchCategoryParty.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get searchCategoryParty;

  /// No description provided for @searchCategoryYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get searchCategoryYear;

  /// No description provided for @searchCategoryOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get searchCategoryOrigin;

  /// No description provided for @searchCategoryProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get searchCategoryProduction;

  /// No description provided for @searchCategoryProductionType.
  ///
  /// In en, this message translates to:
  /// **'Prod types'**
  String get searchCategoryProductionType;

  /// Tag-category card on the browse landing
  ///
  /// In en, this message translates to:
  /// **'Publishers'**
  String get searchCategoryPublisher;

  /// Tag-category card on the browse landing
  ///
  /// In en, this message translates to:
  /// **'Developers'**
  String get searchCategoryDeveloper;

  /// Tag-category card on the browse landing
  ///
  /// In en, this message translates to:
  /// **'Arcade boards'**
  String get searchCategoryArcadeBoard;

  /// No description provided for @searchCategorySaga.
  ///
  /// In en, this message translates to:
  /// **'Saga'**
  String get searchCategorySaga;

  /// No description provided for @searchCategoryGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get searchCategoryGenre;

  /// No description provided for @searchViaArtist.
  ///
  /// In en, this message translates to:
  /// **'via artist'**
  String get searchViaArtist;

  /// No description provided for @searchViaAlbum.
  ///
  /// In en, this message translates to:
  /// **'via an album'**
  String get searchViaAlbum;

  /// No description provided for @searchViaSong.
  ///
  /// In en, this message translates to:
  /// **'via a song'**
  String get searchViaSong;

  /// No description provided for @searchSortPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get searchSortPopular;

  /// No description provided for @searchSortYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get searchSortYear;

  /// No description provided for @searchSortRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get searchSortRandom;

  /// Sort option: by rating (server migrations 207/208)
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get searchSortRating;

  /// Popularity badge — {percent} is 100 minus the percentile
  ///
  /// In en, this message translates to:
  /// **'Top {percent} %'**
  String statsTopPercent(int percent);

  /// How many accounts the rating averages
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} vote} other{{count} votes}}'**
  String ratingVotes(int count);

  /// No description provided for @searchSortAsc.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get searchSortAsc;

  /// No description provided for @searchSortDesc.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get searchSortDesc;

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilters;

  /// No description provided for @searchExactSearch.
  ///
  /// In en, this message translates to:
  /// **'Exact search'**
  String get searchExactSearch;

  /// No description provided for @searchExactSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disables approximate (fuzzy) search'**
  String get searchExactSearchSubtitle;

  /// No description provided for @searchTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get searchTags;

  /// No description provided for @searchTagSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a tag in « {category} »…'**
  String searchTagSearchHint(String category);

  /// No description provided for @searchTagTypeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search for tags.'**
  String get searchTagTypeToSearch;

  /// No description provided for @searchTagsAndLogic.
  ///
  /// In en, this message translates to:
  /// **'Multiple tags = logical AND.'**
  String get searchTagsAndLogic;

  /// No description provided for @searchFilterYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get searchFilterYear;

  /// No description provided for @searchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get searchFilterAll;

  /// No description provided for @searchYearRange.
  ///
  /// In en, this message translates to:
  /// **'{min} – {max}'**
  String searchYearRange(int min, int max);

  /// No description provided for @searchYearFilterNote.
  ///
  /// In en, this message translates to:
  /// **'Filtering by year excludes undated songs.'**
  String get searchYearFilterNote;

  /// No description provided for @searchMinRating.
  ///
  /// In en, this message translates to:
  /// **'Rating ≥'**
  String get searchMinRating;

  /// No description provided for @searchRatingValue.
  ///
  /// In en, this message translates to:
  /// **'★ {value}'**
  String searchRatingValue(String value);

  /// No description provided for @searchCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get searchCancel;

  /// No description provided for @searchReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get searchReset;

  /// No description provided for @searchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchApply;

  /// No description provided for @searchClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear recent searches'**
  String get searchClearRecent;

  /// No description provided for @searchBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get searchBrowse;

  /// No description provided for @searchBrowseHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a facet (group, chip, year…) to explore the catalogue, or start Radio/Surprise above.'**
  String get searchBrowseHint;

  /// No description provided for @searchDidYouMean.
  ///
  /// In en, this message translates to:
  /// **'Few results — try an approximate search?'**
  String get searchDidYouMean;

  /// No description provided for @searchYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get searchYes;

  /// No description provided for @featuredCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'New from the community'**
  String get featuredCommunityTitle;

  /// No description provided for @searchPlaylistSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchPlaylistSourceAll;

  /// No description provided for @searchPlaylistSourceUser.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get searchPlaylistSourceUser;

  /// No description provided for @searchPlaylistSourceServer.
  ///
  /// In en, this message translates to:
  /// **'Rewamp'**
  String get searchPlaylistSourceServer;

  /// No description provided for @searchFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get searchFormat;

  /// No description provided for @searchPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get searchPlatform;

  /// No description provided for @filterCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get filterCollection;

  /// No description provided for @videoWatchDemo.
  ///
  /// In en, this message translates to:
  /// **'Watch the demo'**
  String get videoWatchDemo;

  /// No description provided for @searchFacetSelected.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String searchFacetSelected(String label, String value);

  /// No description provided for @searchCollectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Collection: {name}'**
  String searchCollectionLabel(String name);

  /// No description provided for @searchCollectionAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchCollectionAll;

  /// No description provided for @searchRadio.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get searchRadio;

  /// No description provided for @searchRadioTooltip.
  ///
  /// In en, this message translates to:
  /// **'Random queue over the current filters'**
  String get searchRadioTooltip;

  /// No description provided for @searchSurprise.
  ///
  /// In en, this message translates to:
  /// **'Surprise'**
  String get searchSurprise;

  /// No description provided for @searchSurpriseTooltip.
  ///
  /// In en, this message translates to:
  /// **'A random song'**
  String get searchSurpriseTooltip;

  /// No description provided for @searchTabWithCount.
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String searchTabWithCount(String label, int count);

  /// No description provided for @searchNoSongs.
  ///
  /// In en, this message translates to:
  /// **'No songs'**
  String get searchNoSongs;

  /// No description provided for @searchSongsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} song} other{{n} songs}}'**
  String searchSongsCount(int n);

  /// No description provided for @searchAlbumsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} album} other{{n} albums}}'**
  String searchAlbumsCount(int n);

  /// No description provided for @searchAka.
  ///
  /// In en, this message translates to:
  /// **'aka {name}'**
  String searchAka(String name);

  /// No description provided for @searchChooseCollection.
  ///
  /// In en, this message translates to:
  /// **'Choose collection'**
  String get searchChooseCollection;

  /// No description provided for @searchFilterCollections.
  ///
  /// In en, this message translates to:
  /// **'Filter collections…'**
  String get searchFilterCollections;

  /// No description provided for @searchFilterPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Filter…'**
  String get searchFilterPlaceholder;

  /// No description provided for @searchAllOf.
  ///
  /// In en, this message translates to:
  /// **'All ({label})'**
  String searchAllOf(String label);

  /// No description provided for @searchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No match'**
  String get searchNoMatch;

  /// No description provided for @searchNoPlaylist.
  ///
  /// In en, this message translates to:
  /// **'No playlists'**
  String get searchNoPlaylist;

  /// No description provided for @engineDescOpenmpt.
  ///
  /// In en, this message translates to:
  /// **'Tracker modules (MOD/XM/S3M/IT/…)'**
  String get engineDescOpenmpt;

  /// No description provided for @engineDescVgm.
  ///
  /// In en, this message translates to:
  /// **'VGM/S98/GYM/DRO — sound chips, per-channel scope'**
  String get engineDescVgm;

  /// No description provided for @engineDescGme.
  ///
  /// In en, this message translates to:
  /// **'NES/GB/SNES/PC-Engine/AY/HES/KSS/SAP + RSN archives'**
  String get engineDescGme;

  /// No description provided for @engineDescNsfplay.
  ///
  /// In en, this message translates to:
  /// **'NES NSF/NSFe — per-channel voices'**
  String get engineDescNsfplay;

  /// No description provided for @engineDescGbsplay.
  ///
  /// In en, this message translates to:
  /// **'Game Boy GBS'**
  String get engineDescGbsplay;

  /// No description provided for @engineDescSidplayfp.
  ///
  /// In en, this message translates to:
  /// **'Commodore 64 SID (reSIDfp engine)'**
  String get engineDescSidplayfp;

  /// No description provided for @engineDescNez.
  ///
  /// In en, this message translates to:
  /// **'PC-Engine HES + Sega SGC (SN76489/YM2413)'**
  String get engineDescNez;

  /// No description provided for @engineDescKss.
  ///
  /// In en, this message translates to:
  /// **'MSX chiptunes (KSS/MGS/BGM/MPK/MBM/OPX)'**
  String get engineDescKss;

  /// No description provided for @engineDescFurnace.
  ///
  /// In en, this message translates to:
  /// **'Multi-chip chiptunes .fur / FamiTracker .ftm'**
  String get engineDescFurnace;

  /// No description provided for @engineDescZxtune.
  ///
  /// In en, this message translates to:
  /// **'ZX Spectrum / AY (.ay/.vtx/.pt3/.stc/…) + .chp'**
  String get engineDescZxtune;

  /// No description provided for @engineDescUade.
  ///
  /// In en, this message translates to:
  /// **'Amiga custom-chip formats via 68k emulation (~320 exts)'**
  String get engineDescUade;

  /// No description provided for @engineDescHively.
  ///
  /// In en, this message translates to:
  /// **'AHX / Hively Tracker (.ahx/.hvl/.thx)'**
  String get engineDescHively;

  /// No description provided for @engineDescAsap.
  ///
  /// In en, this message translates to:
  /// **'Atari 8-bit POKEY (.sap/.rmt/.cmc/.tmc/…)'**
  String get engineDescAsap;

  /// No description provided for @engineDescAdplug.
  ///
  /// In en, this message translates to:
  /// **'AdLib OPL2/OPL3 (.d00/.hsc/.cmf/.a2m/.rol/…)'**
  String get engineDescAdplug;

  /// No description provided for @engineDescMidi.
  ///
  /// In en, this message translates to:
  /// **'Standard MIDI + SoundFont (.mid/.midi/.kar/.rmi)'**
  String get engineDescMidi;

  /// No description provided for @engineDescHighlyExp.
  ///
  /// In en, this message translates to:
  /// **'PlayStation PSF/PSF2'**
  String get engineDescHighlyExp;

  /// No description provided for @engineDescGsf.
  ///
  /// In en, this message translates to:
  /// **'Game Boy Advance .gsf/.minigsf'**
  String get engineDescGsf;

  /// No description provided for @engineDescVio2sf.
  ///
  /// In en, this message translates to:
  /// **'Nintendo DS .2sf/.mini2sf'**
  String get engineDescVio2sf;

  /// No description provided for @engineDescNcsf.
  ///
  /// In en, this message translates to:
  /// **'Nintendo DS .ncsf/.minincsf — SDAT/SSEQ synth (16 voices)'**
  String get engineDescNcsf;

  /// No description provided for @engineDescV2m.
  ///
  /// In en, this message translates to:
  /// **'V2M synth (.v2m/.v2mz)'**
  String get engineDescV2m;

  /// No description provided for @engineDescSndh.
  ///
  /// In en, this message translates to:
  /// **'Atari ST .sndh — real 68000 emulation + YM2149 + STE DAC'**
  String get engineDescSndh;

  /// No description provided for @engineDescLazyusf.
  ///
  /// In en, this message translates to:
  /// **'Nintendo 64 .usf — R4300 emulation + RSP audio'**
  String get engineDescLazyusf;

  /// No description provided for @engineDescWonderswan.
  ///
  /// In en, this message translates to:
  /// **'WonderSwan .wsr — NEC V30MZ emulation'**
  String get engineDescWonderswan;

  /// No description provided for @engineDescQsf.
  ///
  /// In en, this message translates to:
  /// **'Capcom QSound .qsf — Z80 + QSound chip'**
  String get engineDescQsf;

  /// No description provided for @engineDescHighlyTheoritical.
  ///
  /// In en, this message translates to:
  /// **'Saturn .ssf / Dreamcast .dsf — 68000/ARM7 + SCSP'**
  String get engineDescHighlyTheoritical;

  /// No description provided for @engineDescPt3.
  ///
  /// In en, this message translates to:
  /// **'ZX Spectrum .pt3 — real AY-3-8910/YM2149 synth'**
  String get engineDescPt3;

  /// No description provided for @engineDescOrganya.
  ///
  /// In en, this message translates to:
  /// **'Cave Story .org — Pixel\'s own engine'**
  String get engineDescOrganya;

  /// No description provided for @engineDescPxtone.
  ///
  /// In en, this message translates to:
  /// **'Pixel\'s tracker — .ptcop/.pttune'**
  String get engineDescPxtone;

  /// No description provided for @engineDescSc68.
  ///
  /// In en, this message translates to:
  /// **'Atari ST (YM2149/STE) + Amiga (Paula) — real 68000 via emu68'**
  String get engineDescSc68;

  /// No description provided for @engineDescPmd.
  ///
  /// In en, this message translates to:
  /// **'PC-98 Professional Music Driver — OPNA FM + SSG + PPZ8 samples'**
  String get engineDescPmd;

  /// No description provided for @engineDescMdx.
  ///
  /// In en, this message translates to:
  /// **'Sharp X68000 — .mdx (+ .pdx samples), YM2151 FM'**
  String get engineDescMdx;

  /// No description provided for @engineDescFmp.
  ///
  /// In en, this message translates to:
  /// **'PC-98 FMP driver — OPNA + PPZ8 (.opi/.ovi/.ozi)'**
  String get engineDescFmp;

  /// No description provided for @engineDescEup.
  ///
  /// In en, this message translates to:
  /// **'FM Towns EUPHONY — YM2612 FM + PCM (.eup)'**
  String get engineDescEup;

  /// No description provided for @engineDescMac.
  ///
  /// In en, this message translates to:
  /// **'Lossless .ape'**
  String get engineDescMac;

  /// No description provided for @engineDescVgmstream.
  ///
  /// In en, this message translates to:
  /// **'Streamed game audio formats (700+, incl. .rrds)'**
  String get engineDescVgmstream;

  /// No description provided for @engineDescMiniaudio.
  ///
  /// In en, this message translates to:
  /// **'PCM/MP3/FLAC/OGG — fallback decoder'**
  String get engineDescMiniaudio;

  /// No description provided for @browseCountSongs.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{loaded} / 1 song} other{{loaded} / {total} songs}}'**
  String browseCountSongs(int total, int loaded);

  /// No description provided for @browseCountAlbums.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{loaded} / 1 album} other{{loaded} / {total} albums}}'**
  String browseCountAlbums(int total, int loaded);

  /// No description provided for @browseCountArtists.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{loaded} / 1 artist} other{{loaded} / {total} artists}}'**
  String browseCountArtists(int total, int loaded);

  /// No description provided for @browseLoadedSongs.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} song} other{{n} songs}}'**
  String browseLoadedSongs(int n);

  /// No description provided for @browseLoadedAlbums.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} album} other{{n} albums}}'**
  String browseLoadedAlbums(int n);

  /// No description provided for @browseLoadedArtists.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} artist} other{{n} artists}}'**
  String browseLoadedArtists(int n);

  /// Group count on the collection hub card and group rows
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} group} other{{n} groups}}'**
  String browseGroupsCount(int n);

  /// Countries card on the collection hub
  ///
  /// In en, this message translates to:
  /// **'Countries'**
  String get browseCountries;

  /// Country count under the hub's Countries card
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} country} other{{n} countries}}'**
  String browseCountriesCount(int n);

  /// Folder-tree card on the collection hub (modland, hvsc, ...)
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get browseFoldersCard;

  /// No description provided for @featuredTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured today'**
  String get featuredTitle;

  /// No description provided for @featuredPartyNow.
  ///
  /// In en, this message translates to:
  /// **'{party} is on right now — podiums from past editions'**
  String featuredPartyNow(String party);

  /// No description provided for @featuredPartyStartsIn.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{{party} starts tomorrow — podiums from past editions} other{{party} starts in {days} days — podiums from past editions}}'**
  String featuredPartyStartsIn(int days, String party);

  /// No description provided for @featuredPartySeason.
  ///
  /// In en, this message translates to:
  /// **'{series} season — podiums from past editions'**
  String featuredPartySeason(String series);

  /// No description provided for @featuredMonthReleased.
  ///
  /// In en, this message translates to:
  /// **'Released in {month} {year}'**
  String featuredMonthReleased(String month, String year);

  /// No description provided for @featuredAnniversaryYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{age, plural, =1{One year ago: the games of {year}} other{{age} years ago: the games of {year}}}'**
  String featuredAnniversaryYearsAgo(int age, String year);

  /// No description provided for @featuredMonthDecade.
  ///
  /// In en, this message translates to:
  /// **'The {decade}s'**
  String featuredMonthDecade(String decade);

  /// No description provided for @featuredAnniversaryAge.
  ///
  /// In en, this message translates to:
  /// **'{age, plural, =1{One year ago: the games of {year}} other{{age} years ago: the games of {year}}}'**
  String featuredAnniversaryAge(int age, String year);

  /// No description provided for @featuredMonthHeader.
  ///
  /// In en, this message translates to:
  /// **'Released in {month}'**
  String featuredMonthHeader(String month);

  /// No description provided for @featuredAnniversaryHeader.
  ///
  /// In en, this message translates to:
  /// **'Anniversaries'**
  String get featuredAnniversaryHeader;

  /// No description provided for @featuredBirthdayHeader.
  ///
  /// In en, this message translates to:
  /// **'Today\'s birthdays'**
  String get featuredBirthdayHeader;

  /// No description provided for @featuredBirthdayWeekHeader.
  ///
  /// In en, this message translates to:
  /// **'This week\'s birthdays'**
  String get featuredBirthdayWeekHeader;

  /// Series header with the week's date range; header = featuredBirthdayWeekHeader, start/end = localized dates (e.g. 'Jul 13').
  ///
  /// In en, this message translates to:
  /// **'{header} ({start} – {end})'**
  String featuredBirthdayWeekHeaderRange(
      String header, String start, String end);

  /// No description provided for @featuredBirthdayWeekArtist.
  ///
  /// In en, this message translates to:
  /// **'{artist}\'s birthday this week'**
  String featuredBirthdayWeekArtist(String artist);

  /// No description provided for @featuredGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} playlist} other{{count} playlists}}'**
  String featuredGroupCount(int count);

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get commonOptions;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// No description provided for @commonDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get commonDeleteDownload;

  /// No description provided for @commonAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get commonAddToPlaylist;

  /// No description provided for @commonPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get commonPlayNext;

  /// No description provided for @commonAddToQueueEnd.
  ///
  /// In en, this message translates to:
  /// **'Add to end of queue'**
  String get commonAddToQueueEnd;

  /// No description provided for @commonAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get commonAddToFavorites;

  /// No description provided for @commonRemoveFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get commonRemoveFromFavorites;

  /// No description provided for @unitBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String unitBytes(String value);

  /// No description provided for @unitKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String unitKilobytes(String value);

  /// No description provided for @unitMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String unitMegabytes(String value);

  /// No description provided for @subsongDeleteDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this download?'**
  String get subsongDeleteDownloadTitle;

  /// No description provided for @subsongDeleteDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'The file and its local entries (history, tracks) will be deleted.\n\n{path}'**
  String subsongDeleteDownloadBody(String path);

  /// No description provided for @subsongReadTracksFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the tracks'**
  String get subsongReadTracksFailed;

  /// No description provided for @subsongTrackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String subsongTrackNumber(int number);

  /// No description provided for @subsongCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} subsong} other{{count} subsongs}}'**
  String subsongCount(int count);

  /// No description provided for @subsongPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get subsongPlayAll;

  /// No description provided for @albumDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading album…'**
  String get albumDownloading;

  /// No description provided for @albumDownloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading album… ({done}/{total})'**
  String albumDownloadingProgress(int done, int total);

  /// No description provided for @albumDownloadToSeeTracks.
  ///
  /// In en, this message translates to:
  /// **'Download the album to see its tracks'**
  String get albumDownloadToSeeTracks;

  /// No description provided for @albumNotDownloadedHint.
  ///
  /// In en, this message translates to:
  /// **'Album not downloaded — start playback to download it'**
  String get albumNotDownloadedHint;

  /// No description provided for @albumTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} track} other{{count} tracks}}'**
  String albumTrackCount(int count);

  /// No description provided for @albumLoadingInfo.
  ///
  /// In en, this message translates to:
  /// **'Loading details…'**
  String get albumLoadingInfo;

  /// No description provided for @albumAka.
  ///
  /// In en, this message translates to:
  /// **'aka {label}'**
  String albumAka(String label);

  /// No description provided for @albumPlayAlbum.
  ///
  /// In en, this message translates to:
  /// **'Play album'**
  String get albumPlayAlbum;

  /// No description provided for @libraryItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} item} other{{count} items}}'**
  String libraryItemCount(int count);

  /// No description provided for @libraryDownloadFromSearchFirst.
  ///
  /// In en, this message translates to:
  /// **'Play this track from search first to download it'**
  String get libraryDownloadFromSearchFirst;

  /// No description provided for @libraryAddedTrack.
  ///
  /// In en, this message translates to:
  /// **'Track added to your library'**
  String get libraryAddedTrack;

  /// No description provided for @libraryAddedAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album added to your library'**
  String get libraryAddedAlbum;

  /// No description provided for @libraryAddedArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist added to your library'**
  String get libraryAddedArtist;

  /// No description provided for @libraryRemovedTrack.
  ///
  /// In en, this message translates to:
  /// **'Track removed from your library'**
  String get libraryRemovedTrack;

  /// No description provided for @libraryRemovedAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album removed from your library'**
  String get libraryRemovedAlbum;

  /// No description provided for @libraryRemovedArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist removed from your library'**
  String get libraryRemovedArtist;

  /// No description provided for @songTilePlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {message}'**
  String songTilePlayFailed(String message);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed — {label}'**
  String downloadFailed(String label);

  /// No description provided for @downloadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading — {label}'**
  String downloadInProgress(String label);

  /// Download queue screen
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// Download queue screen
  ///
  /// In en, this message translates to:
  /// **'No pending downloads'**
  String get downloadsEmpty;

  /// Download queue screen
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadsPause;

  /// Download queue screen
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadsResume;

  /// Abort the download in flight (queue screen + download banner)
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get downloadsCancel;

  /// Download queue screen
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get downloadsClear;

  /// Download queue screen
  ///
  /// In en, this message translates to:
  /// **'Downloads paused — the current file finishes first'**
  String get downloadsPausedBanner;

  /// No description provided for @downloadInProgressPct.
  ///
  /// In en, this message translates to:
  /// **'Downloading — {label} {percent} %'**
  String downloadInProgressPct(String label, int percent);

  /// No description provided for @miniPlayerQueue.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get miniPlayerQueue;

  /// No description provided for @miniPlayerHideQueue.
  ///
  /// In en, this message translates to:
  /// **'Hide playlist'**
  String get miniPlayerHideQueue;

  /// No description provided for @transportShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get transportShuffle;

  /// No description provided for @transportShuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle on'**
  String get transportShuffleOn;

  /// No description provided for @transportLoopOff.
  ///
  /// In en, this message translates to:
  /// **'Loop off'**
  String get transportLoopOff;

  /// No description provided for @transportLoopQueue.
  ///
  /// In en, this message translates to:
  /// **'Loop: queue'**
  String get transportLoopQueue;

  /// No description provided for @transportLoopTrack.
  ///
  /// In en, this message translates to:
  /// **'Loop: current track'**
  String get transportLoopTrack;

  /// No description provided for @vizStereo.
  ///
  /// In en, this message translates to:
  /// **'Stereo'**
  String get vizStereo;

  /// No description provided for @vizSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get vizSpectrum;

  /// No description provided for @vizVoices.
  ///
  /// In en, this message translates to:
  /// **'Voices'**
  String get vizVoices;

  /// No description provided for @vizNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get vizNotes;

  /// No description provided for @vizPatterns.
  ///
  /// In en, this message translates to:
  /// **'Patterns'**
  String get vizPatterns;

  /// No description provided for @patternScrollMode.
  ///
  /// In en, this message translates to:
  /// **'Scroll mode'**
  String get patternScrollMode;

  /// No description provided for @patternSmoothScroll.
  ///
  /// In en, this message translates to:
  /// **'Smooth scrolling'**
  String get patternSmoothScroll;

  /// No description provided for @patternVolumeBars.
  ///
  /// In en, this message translates to:
  /// **'Volume bars'**
  String get patternVolumeBars;

  /// No description provided for @patternColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get patternColorScheme;

  /// No description provided for @patternSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get patternSize;

  /// No description provided for @patternColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get patternColumns;

  /// No description provided for @patternColumnsAll.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get patternColumnsAll;

  /// No description provided for @patternColumnsNoteInstr.
  ///
  /// In en, this message translates to:
  /// **'Reduced'**
  String get patternColumnsNoteInstr;

  /// No description provided for @patternColumnsNote.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get patternColumnsNote;

  /// No description provided for @vizClose.
  ///
  /// In en, this message translates to:
  /// **'Close the visualizer'**
  String get vizClose;

  /// No description provided for @vizFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get vizFullscreen;

  /// No description provided for @vizExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get vizExitFullscreen;

  /// No description provided for @vizPrevPreset.
  ///
  /// In en, this message translates to:
  /// **'Previous preset'**
  String get vizPrevPreset;

  /// No description provided for @vizNextPreset.
  ///
  /// In en, this message translates to:
  /// **'Next preset'**
  String get vizNextPreset;

  /// No description provided for @vizProjectmUnavailable.
  ///
  /// In en, this message translates to:
  /// **'projectM unavailable'**
  String get vizProjectmUnavailable;

  /// No description provided for @voicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Voices'**
  String get voicesTitle;

  /// No description provided for @voicesNone.
  ///
  /// In en, this message translates to:
  /// **'No voices for this track.'**
  String get voicesNone;

  /// No description provided for @voicesLongPressSolo.
  ///
  /// In en, this message translates to:
  /// **'long-press = solo'**
  String get voicesLongPressSolo;

  /// No description provided for @voicesMuteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute all'**
  String get voicesMuteAll;

  /// No description provided for @voicesUnmuteAll.
  ///
  /// In en, this message translates to:
  /// **'Unmute all'**
  String get voicesUnmuteAll;

  /// No description provided for @voicesStereoOutput.
  ///
  /// In en, this message translates to:
  /// **'Stereo output'**
  String get voicesStereoOutput;

  /// No description provided for @voicesLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get voicesLeft;

  /// No description provided for @voicesRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get voicesRight;

  /// No description provided for @enginesFormatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Playable formats'**
  String get enginesFormatsTitle;

  /// No description provided for @enginesFormatsSummary.
  ///
  /// In en, this message translates to:
  /// **'{formats} playable formats, across {engines} playback engines.'**
  String enginesFormatsSummary(int formats, int engines);

  /// No description provided for @enginesLicenseFormats.
  ///
  /// In en, this message translates to:
  /// **'{license} · {count, plural, =1{1 format} other{{count} formats}}'**
  String enginesLicenseFormats(String license, int count);

  /// ⓘ panel: STIL TITLE/ARTIST name the work the tune covers, never the track itself
  ///
  /// In en, this message translates to:
  /// **'Covers {title} by {artist}'**
  String stilCoverOf(String title, String artist);

  /// Same, when STIL names only one of the two
  ///
  /// In en, this message translates to:
  /// **'Covers {work}'**
  String stilCover(String work);

  /// No description provided for @playerQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerQueue;

  /// Button opening the queue multi-select edit mode
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get queueEdit;

  /// Button leaving the queue edit mode
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get queueEditDone;

  /// Queue panel: empty the queue and stop playback
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get queueClear;

  /// Queue panel: empty the queue and stop playback
  ///
  /// In en, this message translates to:
  /// **'Clear the queue?'**
  String get queueClearConfirmTitle;

  /// Queue panel: empty the queue and stop playback
  ///
  /// In en, this message translates to:
  /// **'The queue will be emptied and playback will stop.'**
  String get queueClearConfirmBody;

  /// Queue panel: empty the queue and stop playback
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get queueClearConfirm;

  /// Removes the checked queue rows
  ///
  /// In en, this message translates to:
  /// **'Remove selected'**
  String get queueRemoveSelected;

  /// Swipe action / tooltip removing one queue row
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get queueRemoveTrack;

  /// Drag handle tooltip in the queue
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get queueReorder;

  /// No description provided for @playerArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get playerArtwork;

  /// No description provided for @playerVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get playerVisualizer;

  /// No description provided for @playerVoices.
  ///
  /// In en, this message translates to:
  /// **'Voices'**
  String get playerVoices;

  /// No description provided for @playerTrackInfo.
  ///
  /// In en, this message translates to:
  /// **'Track info'**
  String get playerTrackInfo;

  /// No description provided for @playerShowQueue.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playerShowQueue;

  /// No description provided for @playerHideQueue.
  ///
  /// In en, this message translates to:
  /// **'Hide playlist'**
  String get playerHideQueue;

  /// No description provided for @playerNoTrackInfo.
  ///
  /// In en, this message translates to:
  /// **'No information available.'**
  String get playerNoTrackInfo;

  /// No description provided for @playerViewSubsongs.
  ///
  /// In en, this message translates to:
  /// **'View subsongs'**
  String get playerViewSubsongs;

  /// No description provided for @playerViewAlbum.
  ///
  /// In en, this message translates to:
  /// **'View album'**
  String get playerViewAlbum;

  /// No description provided for @playerViewArtist.
  ///
  /// In en, this message translates to:
  /// **'View artist'**
  String get playerViewArtist;

  /// No description provided for @playerAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playerAddToPlaylist;

  /// No description provided for @queueAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add queue to a playlist'**
  String get queueAddToPlaylist;

  /// No description provided for @playerMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get playerMoreOptions;

  /// No description provided for @playerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get playerClose;

  /// No description provided for @playerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get playerCancel;

  /// No description provided for @playerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get playerDelete;

  /// No description provided for @playerAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get playerAddFavorite;

  /// No description provided for @playerRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get playerRemoveFavorite;

  /// No description provided for @playerAddToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get playerAddToLibrary;

  /// No description provided for @playerRemoveFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get playerRemoveFromLibrary;

  /// No description provided for @playerAddedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Track added to library'**
  String get playerAddedToLibrary;

  /// No description provided for @playerRemovedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Track removed from library'**
  String get playerRemovedFromLibrary;

  /// No description provided for @playerDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get playerDeleteDownload;

  /// No description provided for @playerRedownload.
  ///
  /// In en, this message translates to:
  /// **'Re-download file'**
  String get playerRedownload;

  /// No description provided for @playerRedownloadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Re-download unavailable for this file'**
  String get playerRedownloadUnavailable;

  /// No description provided for @playerDeleteDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get playerDeleteDownloadTitle;

  /// No description provided for @playerDeleteDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'The file and its local entries (history, tracks) will be deleted.\n\n{path}'**
  String playerDeleteDownloadBody(String path);

  /// No description provided for @homeYourTrends.
  ///
  /// In en, this message translates to:
  /// **'Your trends'**
  String get homeYourTrends;

  /// No description provided for @homeYourAllTimeTop.
  ///
  /// In en, this message translates to:
  /// **'Your all-time top'**
  String get homeYourAllTimeTop;

  /// No description provided for @homeTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get homeTrending;

  /// No description provided for @homeFeaturedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Featured playlists'**
  String get homeFeaturedPlaylists;

  /// No description provided for @homeAllTimeTop.
  ///
  /// In en, this message translates to:
  /// **'All-time top'**
  String get homeAllTimeTop;

  /// No description provided for @homePeriod7d.
  ///
  /// In en, this message translates to:
  /// **'7 d'**
  String get homePeriod7d;

  /// No description provided for @homePeriod30d.
  ///
  /// In en, this message translates to:
  /// **'30 d'**
  String get homePeriod30d;

  /// No description provided for @homePeriod90d.
  ///
  /// In en, this message translates to:
  /// **'90 d'**
  String get homePeriod90d;

  /// No description provided for @homePlaysCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} play} other{{n} plays}}'**
  String homePlaysCount(int n);

  /// No description provided for @homeTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} track} other{{n} tracks}}'**
  String homeTrackCount(int n);

  /// No description provided for @homePlaylistUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Empty or unreadable playlist'**
  String get homePlaylistUnreadable;

  /// No description provided for @homeExtractingArchive.
  ///
  /// In en, this message translates to:
  /// **'Extracting archive…'**
  String get homeExtractingArchive;

  /// No description provided for @homeArchiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playable files in the archive'**
  String get homeArchiveEmpty;

  /// No description provided for @homeNothingPlayable.
  ///
  /// In en, this message translates to:
  /// **'Nothing playable in the selection'**
  String get homeNothingPlayable;

  /// No description provided for @homeAlbumLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this album'**
  String get homeAlbumLoadFailed;

  /// No description provided for @homeSongLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this track'**
  String get homeSongLoadFailed;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @playlistMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move to parent folder'**
  String get playlistMoveUp;

  /// No description provided for @playlistFolderPlaylistCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} playlist} other{{n} playlists}}'**
  String playlistFolderPlaylistCount(int n);

  /// No description provided for @playlistFolderSubfolderCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} subfolder} other{{n} subfolders}}'**
  String playlistFolderSubfolderCount(int n);

  /// No description provided for @playlistDeleteFolderContentsHeader.
  ///
  /// In en, this message translates to:
  /// **'This folder and everything inside will be permanently deleted:'**
  String get playlistDeleteFolderContentsHeader;

  /// No description provided for @playlistDeleteFolderEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'This folder will be deleted.'**
  String get playlistDeleteFolderEmptyBody;

  /// No description provided for @playlistFolderRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get playlistFolderRoot;

  /// No description provided for @playlistMoveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get playlistMoveToFolder;

  /// No description provided for @playlistDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String playlistDeleteTitle(String name);

  /// No description provided for @playlistDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This playlist will be permanently deleted.'**
  String get playlistDeleteBody;

  /// No description provided for @playlistRenameFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get playlistRenameFolderTitle;

  /// No description provided for @playlistClearFavorites.
  ///
  /// In en, this message translates to:
  /// **'Delete all favorites'**
  String get playlistClearFavorites;

  /// No description provided for @playlistClearFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all favorites?'**
  String get playlistClearFavoritesTitle;

  /// No description provided for @playlistClearFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'You will lose all your favorite tracks. This can\'t be undone.'**
  String get playlistClearFavoritesBody;

  /// No description provided for @playlistRemoveFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get playlistRemoveFromLibrary;

  /// No description provided for @playlistServerReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Server playlist · read-only'**
  String get playlistServerReadOnly;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @shellAlbumQueuedAtEnd.
  ///
  /// In en, this message translates to:
  /// **'Album added to the end of the queue'**
  String get shellAlbumQueuedAtEnd;

  /// No description provided for @shellAlbumQueuedNext.
  ///
  /// In en, this message translates to:
  /// **'Album will play next'**
  String get shellAlbumQueuedNext;

  /// No description provided for @shellAddingToQueue.
  ///
  /// In en, this message translates to:
  /// **'Adding to queue…'**
  String get shellAddingToQueue;

  /// No description provided for @shellAddingNext.
  ///
  /// In en, this message translates to:
  /// **'Adding to play next…'**
  String get shellAddingNext;

  /// No description provided for @shellDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String shellDownloadFailed(String error);

  /// No description provided for @shellTracksQueued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} track added to the queue} other{{count} tracks added to the queue}}'**
  String shellTracksQueued(int count);

  /// No description provided for @shellTrackQueuedAtEnd.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" added to the end of the queue'**
  String shellTrackQueuedAtEnd(String title);

  /// No description provided for @shellTrackQueuedNext.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will play next'**
  String shellTrackQueuedNext(String title);

  /// No description provided for @shellDownloadFailedSkipping.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {title} — skipping to next track'**
  String shellDownloadFailedSkipping(String title);

  /// No description provided for @shellNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Playback stopped: the network appears to be unavailable.'**
  String get shellNetworkUnavailable;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsPeriodDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String statsPeriodDays(int n);

  /// No description provided for @statsPeriodThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get statsPeriodThisYear;

  /// No description provided for @statsPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get statsPeriodAll;

  /// No description provided for @statsByMonthOrYear.
  ///
  /// In en, this message translates to:
  /// **'By month / year…'**
  String get statsByMonthOrYear;

  /// No description provided for @statsByYear.
  ///
  /// In en, this message translates to:
  /// **'By year'**
  String get statsByYear;

  /// No description provided for @statsByMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get statsByMonth;

  /// No description provided for @statsPlaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get statsPlaysLabel;

  /// No description provided for @statsTracksLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get statsTracksLabel;

  /// No description provided for @statsArtistsLabel.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get statsArtistsLabel;

  /// No description provided for @statsAlbumsLabel.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get statsAlbumsLabel;

  /// No description provided for @statsListenTime.
  ///
  /// In en, this message translates to:
  /// **'Listening time'**
  String get statsListenTime;

  /// No description provided for @statsByCollection.
  ///
  /// In en, this message translates to:
  /// **'By collection'**
  String get statsByCollection;

  /// No description provided for @statsByFormat.
  ///
  /// In en, this message translates to:
  /// **'By format'**
  String get statsByFormat;

  /// No description provided for @statsByEngine.
  ///
  /// In en, this message translates to:
  /// **'By engine'**
  String get statsByEngine;

  /// No description provided for @statsPlaylistsLabel.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get statsPlaylistsLabel;

  /// No description provided for @statsLocalFilesSection.
  ///
  /// In en, this message translates to:
  /// **'Downloaded files'**
  String get statsLocalFilesSection;

  /// No description provided for @statsFilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get statsFilesLabel;

  /// No description provided for @statsSpaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Disk space'**
  String get statsSpaceLabel;

  /// No description provided for @statsNoPlaysInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No plays in this period'**
  String get statsNoPlaysInPeriod;

  /// No description provided for @statsNoPlays.
  ///
  /// In en, this message translates to:
  /// **'No plays'**
  String get statsNoPlays;

  /// No description provided for @statsTopTracks.
  ///
  /// In en, this message translates to:
  /// **'Top tracks'**
  String get statsTopTracks;

  /// No description provided for @statsTopAlbums.
  ///
  /// In en, this message translates to:
  /// **'Top albums'**
  String get statsTopAlbums;

  /// No description provided for @statsTopArtists.
  ///
  /// In en, this message translates to:
  /// **'Top artists'**
  String get statsTopArtists;

  /// No description provided for @statsTopTracksIn.
  ///
  /// In en, this message translates to:
  /// **'Top tracks — {period}'**
  String statsTopTracksIn(String period);

  /// No description provided for @statsTopAlbumsIn.
  ///
  /// In en, this message translates to:
  /// **'Top albums — {period}'**
  String statsTopAlbumsIn(String period);

  /// No description provided for @statsTopArtistsIn.
  ///
  /// In en, this message translates to:
  /// **'Top artists — {period}'**
  String statsTopArtistsIn(String period);

  /// No description provided for @statsSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get statsSeeAll;

  /// No description provided for @statsPlays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} play} other{{n} plays}}'**
  String statsPlays(int n);

  /// No description provided for @statsTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} track} other{{n} tracks}}'**
  String statsTrackCount(int n);

  /// No description provided for @statsChartMax.
  ///
  /// In en, this message translates to:
  /// **'max {n}'**
  String statsChartMax(int n);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get commonSort;

  /// No description provided for @commonPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get commonPlayAll;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get sortArtist;

  /// No description provided for @sortAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get sortAlbum;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortDateAdded;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @sortRecentlyModified.
  ///
  /// In en, this message translates to:
  /// **'Recently modified'**
  String get sortRecentlyModified;

  /// No description provided for @sortCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Creation date'**
  String get sortCreationDate;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get playlistNameHint;

  /// No description provided for @playlistNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistNew;

  /// No description provided for @playlistNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get playlistNewFolder;

  /// No description provided for @playlistNewTooltip.
  ///
  /// In en, this message translates to:
  /// **'New playlist / folder'**
  String get playlistNewTooltip;

  /// No description provided for @playlistAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistAddTo;

  /// No description provided for @playlistAddToN.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Add to {n} playlist} other{Add to {n} playlists}}'**
  String playlistAddToN(int n);

  /// No description provided for @playlistSelectOne.
  ///
  /// In en, this message translates to:
  /// **'Select a playlist'**
  String get playlistSelectOne;

  /// No description provided for @playlistFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter playlists…'**
  String get playlistFilterHint;

  /// No description provided for @playlistSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a playlist…'**
  String get playlistSearchHint;

  /// No description provided for @playlistNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching playlist'**
  String get playlistNoMatch;

  /// No description provided for @playlistNoneCreateHint.
  ///
  /// In en, this message translates to:
  /// **'No playlist — create one with +'**
  String get playlistNoneCreateHint;

  /// No description provided for @playlistTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{No tracks} =1{{n} track} other{{n} tracks}}'**
  String playlistTrackCount(int n);

  /// No description provided for @playlistDuplicatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Already there'**
  String get playlistDuplicatesTitle;

  /// No description provided for @playlistDuplicatesBody.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} item is already in the selected playlists.} other{{n} items are already in the selected playlists.}}'**
  String playlistDuplicatesBody(int n);

  /// No description provided for @playlistSkipDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Skip duplicates'**
  String get playlistSkipDuplicates;

  /// No description provided for @playlistAddAgain.
  ///
  /// In en, this message translates to:
  /// **'Add again'**
  String get playlistAddAgain;

  /// No description provided for @playlistTracksAdded.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} track added} other{{n} tracks added}} to {m, plural, =1{{n} playlist} other{{m} playlists}}'**
  String playlistTracksAdded(int n, int m);

  /// No description provided for @playlistAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add: {error}'**
  String playlistAddFailed(String error);

  /// No description provided for @playlistRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistRenameTitle;

  /// No description provided for @playlistDeleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the folder “{name}”?'**
  String playlistDeleteFolderTitle(String name);

  /// No description provided for @playlistDeleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Its contents move up one level.'**
  String get playlistDeleteFolderBody;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty playlist'**
  String get playlistEmpty;

  /// No description provided for @playlistRemoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlistRemoveEntry;

  /// No description provided for @trackOptionsAddToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get trackOptionsAddToLibrary;

  /// No description provided for @trackOptionsRemoveFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get trackOptionsRemoveFromLibrary;

  /// No description provided for @trackOptionsAddedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Track added to the library'**
  String get trackOptionsAddedToLibrary;

  /// No description provided for @trackOptionsRemovedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Track removed from the library'**
  String get trackOptionsRemovedFromLibrary;

  /// No description provided for @trackOptionsViewAlbum.
  ///
  /// In en, this message translates to:
  /// **'View album'**
  String get trackOptionsViewAlbum;

  /// No description provided for @trackOptionsViewArtist.
  ///
  /// In en, this message translates to:
  /// **'View artist'**
  String get trackOptionsViewArtist;

  /// First action of the track options sheet and rail popups: play immediately, replacing the queue
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get trackOptionsPlayNow;

  /// No description provided for @trackOptionsPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get trackOptionsPlayNext;

  /// No description provided for @trackOptionsAddToQueueEnd.
  ///
  /// In en, this message translates to:
  /// **'Add to end of queue'**
  String get trackOptionsAddToQueueEnd;

  /// No description provided for @trackOptionsPlayLast.
  ///
  /// In en, this message translates to:
  /// **'Play last'**
  String get trackOptionsPlayLast;

  /// No description provided for @trackOptionsDeleteDownload.
  ///
  /// In en, this message translates to:
  /// **'Delete download'**
  String get trackOptionsDeleteDownload;

  /// No description provided for @trackOptionsDeleteDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this download?'**
  String get trackOptionsDeleteDownloadTitle;

  /// No description provided for @trackOptionsDeleteDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'The file and its local entries (history, tracks) will be deleted.\n\n{path}'**
  String trackOptionsDeleteDownloadBody(String path);

  /// No description provided for @trackOptionsDownloadDeleted.
  ///
  /// In en, this message translates to:
  /// **'Download deleted'**
  String get trackOptionsDownloadDeleted;

  /// No description provided for @trackOptionsAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get trackOptionsAddToFavorites;

  /// No description provided for @trackOptionsRemoveFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get trackOptionsRemoveFromFavorites;

  /// No description provided for @trackOptionsAlbumAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Album added to favorites'**
  String get trackOptionsAlbumAddedToFavorites;

  /// No description provided for @trackOptionsAlbumRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Album removed from favorites'**
  String get trackOptionsAlbumRemovedFromFavorites;

  /// No description provided for @trackOptionsAlbumNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Album not downloaded — nothing to delete'**
  String get trackOptionsAlbumNotDownloaded;

  /// No description provided for @trackOptionsDeleteAlbumTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the downloaded album?'**
  String get trackOptionsDeleteAlbumTitle;

  /// No description provided for @trackOptionsDeleteAlbumBody.
  ///
  /// In en, this message translates to:
  /// **'The folder and all its local entries (tracks, history) will be deleted.\n\n{dir}'**
  String trackOptionsDeleteAlbumBody(String dir);

  /// No description provided for @trackOptionsAlbumDeleted.
  ///
  /// In en, this message translates to:
  /// **'Album deleted from local storage'**
  String get trackOptionsAlbumDeleted;

  /// No description provided for @trackOptionsRedownloadAlbum.
  ///
  /// In en, this message translates to:
  /// **'Re-download album'**
  String get trackOptionsRedownloadAlbum;

  /// No description provided for @trackOptionsRedownloadAlbumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rewrites files AND local entries'**
  String get trackOptionsRedownloadAlbumSubtitle;

  /// No description provided for @trackOptionsDeleteAlbumFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete album files'**
  String get trackOptionsDeleteAlbumFiles;

  /// No description provided for @trackOptionsDeleteAlbumFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloaded folder + local entries (history)'**
  String get trackOptionsDeleteAlbumFilesSubtitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsGeneralSubtitle;

  /// No description provided for @settingsVisualisation.
  ///
  /// In en, this message translates to:
  /// **'Visualization'**
  String get settingsVisualisation;

  /// No description provided for @settingsVisualisationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Oscilloscopes, artwork background'**
  String get settingsVisualisationSubtitle;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsPlaybackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Loops, fade-out, silence'**
  String get settingsPlaybackSubtitle;

  /// No description provided for @settingsEngines.
  ///
  /// In en, this message translates to:
  /// **'Engines'**
  String get settingsEngines;

  /// No description provided for @settingsEnginesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'libopenmpt, NSF, GBS, MIDI'**
  String get settingsEnginesSubtitle;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ID, history, reset'**
  String get settingsDataSubtitle;

  /// No description provided for @settingsBackupExport.
  ///
  /// In en, this message translates to:
  /// **'Export a backup'**
  String get settingsBackupExport;

  /// No description provided for @settingsBackupExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your library, playlists and settings to a file'**
  String get settingsBackupExportSubtitle;

  /// No description provided for @settingsBackupImport.
  ///
  /// In en, this message translates to:
  /// **'Import a backup'**
  String get settingsBackupImport;

  /// No description provided for @settingsBackupImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore your data from a backup file'**
  String get settingsBackupImportSubtitle;

  /// No description provided for @settingsBackupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup export failed'**
  String get settingsBackupExportFailed;

  /// No description provided for @settingsBackupImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import backup?'**
  String get settingsBackupImportConfirmTitle;

  /// No description provided for @settingsBackupImportConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This replaces your library, playlists and settings on this device. Downloaded files are kept.'**
  String get settingsBackupImportConfirmBody;

  /// No description provided for @settingsBackupImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsBackupImportConfirm;

  /// No description provided for @settingsBackupImportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup imported'**
  String get settingsBackupImportedTitle;

  /// No description provided for @settingsBackupImportedBody.
  ///
  /// In en, this message translates to:
  /// **'Your data has been restored. Restart the app to apply everything.'**
  String get settingsBackupImportedBody;

  /// No description provided for @settingsBackupTooNew.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of the app'**
  String get settingsBackupTooNew;

  /// No description provided for @settingsBackupInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid Rewamp backup'**
  String get settingsBackupInvalid;

  /// No description provided for @settingsBackupImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup import failed'**
  String get settingsBackupImportFailed;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Credits and licenses'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsCreditsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Libraries, data & components'**
  String get settingsCreditsSubtitle;

  /// No description provided for @settingsSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact & support'**
  String get settingsSupport;

  /// No description provided for @settingsSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reach us, website'**
  String get settingsSupportSubtitle;

  /// No description provided for @settingsSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Send an email'**
  String get settingsSupportEmail;

  /// No description provided for @settingsSupportEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Question, bug or suggestion'**
  String get settingsSupportEmailSubtitle;

  /// No description provided for @settingsSupportEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Rewamp — support'**
  String get settingsSupportEmailSubject;

  /// No description provided for @settingsSupportEmailIntro.
  ///
  /// In en, this message translates to:
  /// **'Describe your question, bug or suggestion above. The information below helps us help you.'**
  String get settingsSupportEmailIntro;

  /// No description provided for @settingsSupportWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get settingsSupportWebsite;

  /// No description provided for @settingsDonation.
  ///
  /// In en, this message translates to:
  /// **'Support Rewamp'**
  String get settingsDonation;

  /// No description provided for @settingsDonationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a tip, if you\'d like'**
  String get settingsDonationSubtitle;

  /// No description provided for @settingsDonationBlurb.
  ///
  /// In en, this message translates to:
  /// **'Rewamp is free and ad-free — a labour of love devoted to preserving demoscene and retro culture. Tips help fund the app\'s development and cover the database hosting costs. There\'s no obligation: if the app brings you joy, a little something is always appreciated.'**
  String get settingsDonationBlurb;

  /// No description provided for @settingsDonationFloppy.
  ///
  /// In en, this message translates to:
  /// **'A floppy disk'**
  String get settingsDonationFloppy;

  /// No description provided for @settingsDonationCartridge.
  ///
  /// In en, this message translates to:
  /// **'A cartridge'**
  String get settingsDonationCartridge;

  /// No description provided for @settingsDonationBox.
  ///
  /// In en, this message translates to:
  /// **'A boxed game'**
  String get settingsDonationBox;

  /// No description provided for @settingsDonationCustom.
  ///
  /// In en, this message translates to:
  /// **'Choose an amount'**
  String get settingsDonationCustom;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get settingsOk;

  /// No description provided for @settingsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsDelete;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @settingsRenew.
  ///
  /// In en, this message translates to:
  /// **'Renew'**
  String get settingsRenew;

  /// No description provided for @settingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// No description provided for @settingsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsOn;

  /// No description provided for @settingsAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsAuto;

  /// No description provided for @settingsInfinite.
  ///
  /// In en, this message translates to:
  /// **'Infinite'**
  String get settingsInfinite;

  /// No description provided for @settingsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsDefault;

  /// No description provided for @settingsCoreNoScope.
  ///
  /// In en, this message translates to:
  /// **'no oscilloscope'**
  String get settingsCoreNoScope;

  /// No description provided for @settingsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsNone;

  /// No description provided for @settingsLevelLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settingsLevelLow;

  /// No description provided for @settingsLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsLevelHigh;

  /// No description provided for @settingsStereo.
  ///
  /// In en, this message translates to:
  /// **'Stereo'**
  String get settingsStereo;

  /// No description provided for @settingsSurround.
  ///
  /// In en, this message translates to:
  /// **'Surround'**
  String get settingsSurround;

  /// No description provided for @settingsValuePercent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String settingsValuePercent(int value);

  /// No description provided for @settingsValueSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String settingsValueSeconds(int value);

  /// No description provided for @settingsValueSecondsFrac.
  ///
  /// In en, this message translates to:
  /// **'{value} s'**
  String settingsValueSecondsFrac(String value);

  /// No description provided for @settingsValueHz.
  ///
  /// In en, this message translates to:
  /// **'{value} Hz'**
  String settingsValueHz(int value);

  /// No description provided for @settingsValueDb.
  ///
  /// In en, this message translates to:
  /// **'{value} dB'**
  String settingsValueDb(int value);

  /// No description provided for @settingsValueTimes.
  ///
  /// In en, this message translates to:
  /// **'×{value}'**
  String settingsValueTimes(String value);

  /// No description provided for @settingsSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String settingsSizeMb(String value);

  /// No description provided for @settingsSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} kB'**
  String settingsSizeKb(String value);

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsArtworkTintTitle.
  ///
  /// In en, this message translates to:
  /// **'Tint the player with the artwork'**
  String get settingsArtworkTintTitle;

  /// No description provided for @settingsArtworkTintSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The player picks up the cover\'s dominant color'**
  String get settingsArtworkTintSubtitle;

  /// No description provided for @settingsGlassEffectTitle.
  ///
  /// In en, this message translates to:
  /// **'Liquid glass effect'**
  String get settingsGlassEffectTitle;

  /// No description provided for @settingsGlassEffectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lens and blur on the bottom bars — turn off on slow devices'**
  String get settingsGlassEffectSubtitle;

  /// No description provided for @settingsResetSection.
  ///
  /// In en, this message translates to:
  /// **'Reset this section'**
  String get settingsResetSection;

  /// No description provided for @settingsResetEngine.
  ///
  /// In en, this message translates to:
  /// **'Reset this engine'**
  String get settingsResetEngine;

  /// No description provided for @settingsResetChoices.
  ///
  /// In en, this message translates to:
  /// **'Reset these choices'**
  String get settingsResetChoices;

  /// No description provided for @settingsResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Default value'**
  String get settingsResetToDefault;

  /// No description provided for @settingsStartInVizTitle.
  ///
  /// In en, this message translates to:
  /// **'Start in visualizer mode'**
  String get settingsStartInVizTitle;

  /// No description provided for @settingsStartInVizSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The player opens on the oscilloscopes instead of the artwork'**
  String get settingsStartInVizSubtitle;

  /// No description provided for @settingsVoiceGridTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice oscilloscope grid'**
  String get settingsVoiceGridTitle;

  /// No description provided for @settingsVoiceGridSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the borders separating each voice'**
  String get settingsVoiceGridSubtitle;

  /// No description provided for @settingsKeepAwakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on'**
  String get settingsKeepAwakeTitle;

  /// No description provided for @settingsKeepAwakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'While a visualizer is showing, the display does not dim or lock'**
  String get settingsKeepAwakeSubtitle;

  /// No description provided for @settingsVoiceNamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice names'**
  String get settingsVoiceNamesTitle;

  /// No description provided for @settingsVoiceNamesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show each voice\'s name inside its frame'**
  String get settingsVoiceNamesSubtitle;

  /// No description provided for @settingsLineThickness.
  ///
  /// In en, this message translates to:
  /// **'Line thickness'**
  String get settingsLineThickness;

  /// No description provided for @settingsColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get settingsColors;

  /// No description provided for @settingsScopeVoiceColor.
  ///
  /// In en, this message translates to:
  /// **'Voice oscilloscope'**
  String get settingsScopeVoiceColor;

  /// No description provided for @settingsStereoColors.
  ///
  /// In en, this message translates to:
  /// **'Stereo: colors'**
  String get settingsStereoColors;

  /// No description provided for @settingsStereoMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get settingsStereoMono;

  /// No description provided for @settingsStereoBi.
  ///
  /// In en, this message translates to:
  /// **'Bi'**
  String get settingsStereoBi;

  /// No description provided for @settingsStereoMonoColor.
  ///
  /// In en, this message translates to:
  /// **'Stereo (mono)'**
  String get settingsStereoMonoColor;

  /// No description provided for @settingsStereoLeftColor.
  ///
  /// In en, this message translates to:
  /// **'Stereo left'**
  String get settingsStereoLeftColor;

  /// No description provided for @settingsStereoRightColor.
  ///
  /// In en, this message translates to:
  /// **'Stereo right'**
  String get settingsStereoRightColor;

  /// No description provided for @settingsNotation.
  ///
  /// In en, this message translates to:
  /// **'Notation (notes)'**
  String get settingsNotation;

  /// No description provided for @settingsNotePalette.
  ///
  /// In en, this message translates to:
  /// **'Color palette'**
  String get settingsNotePalette;

  /// No description provided for @settingsNoteBoxStyle.
  ///
  /// In en, this message translates to:
  /// **'Block style'**
  String get settingsNoteBoxStyle;

  /// No description provided for @settingsNoteStyleFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get settingsNoteStyleFlat;

  /// No description provided for @settingsNoteStyleBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get settingsNoteStyleBox;

  /// No description provided for @settingsCrtEffects.
  ///
  /// In en, this message translates to:
  /// **'CRT effects'**
  String get settingsCrtEffects;

  /// No description provided for @settingsCrtGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get settingsCrtGlow;

  /// No description provided for @settingsCrtSpeed.
  ///
  /// In en, this message translates to:
  /// **'Intensity / speed'**
  String get settingsCrtSpeed;

  /// No description provided for @settingsArtworkOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background artwork opacity'**
  String get settingsArtworkOpacity;

  /// No description provided for @settingsProjectMTitle.
  ///
  /// In en, this message translates to:
  /// **'projectM settings'**
  String get settingsProjectMTitle;

  /// No description provided for @settingsProjectMSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Presets, transitions, quality, mesh…'**
  String get settingsProjectMSubtitle;

  /// Settings toggle: desktop notification on track change
  ///
  /// In en, this message translates to:
  /// **'Track-change notifications'**
  String get settingsNotifyTrackTitle;

  /// Settings toggle: desktop notification on track change
  ///
  /// In en, this message translates to:
  /// **'System notification with the new track\'s title'**
  String get settingsNotifyTrackSubtitle;

  /// No description provided for @settingsSilenceDetection.
  ///
  /// In en, this message translates to:
  /// **'Silence detection'**
  String get settingsSilenceDetection;

  /// No description provided for @settingsSilenceSkipTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip to the next track on silence'**
  String get settingsSilenceSkipTitle;

  /// No description provided for @settingsSilenceSkipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Moves on automatically when the output stays silent'**
  String get settingsSilenceSkipSubtitle;

  /// No description provided for @settingsSilenceDelay.
  ///
  /// In en, this message translates to:
  /// **'Silence delay'**
  String get settingsSilenceDelay;

  /// No description provided for @settingsDefaultDuration.
  ///
  /// In en, this message translates to:
  /// **'Default duration'**
  String get settingsDefaultDuration;

  /// No description provided for @settingsDefaultDurationHelp.
  ///
  /// In en, this message translates to:
  /// **'Used when a track reports no known duration (no tag, no server metadata) — keeps it from playing or looping forever. Never applies to Amiga tracks (UADE), which have their own songlength database.'**
  String get settingsDefaultDurationHelp;

  /// No description provided for @settingsForcedLoopHeader.
  ///
  /// In en, this message translates to:
  /// **'Forced loop / fade-out'**
  String get settingsForcedLoopHeader;

  /// No description provided for @settingsForcedLoopHelp.
  ///
  /// In en, this message translates to:
  /// **'Some formats loop a specific section (VGM, tracker modules…); others don\'t. \"Infinite\" ignores the track\'s natural end.'**
  String get settingsForcedLoopHelp;

  /// No description provided for @settingsForceLoopCount.
  ///
  /// In en, this message translates to:
  /// **'Force the number of loops'**
  String get settingsForceLoopCount;

  /// No description provided for @settingsLoopCount.
  ///
  /// In en, this message translates to:
  /// **'Number of loops'**
  String get settingsLoopCount;

  /// No description provided for @settingsForceFadeout.
  ///
  /// In en, this message translates to:
  /// **'Force a fade-out'**
  String get settingsForceFadeout;

  /// No description provided for @settingsFadeoutDuration.
  ///
  /// In en, this message translates to:
  /// **'Fade duration'**
  String get settingsFadeoutDuration;

  /// No description provided for @settingsResetEnginesTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset engine settings?'**
  String get settingsResetEnginesTitle;

  /// No description provided for @settingsResetEnginesBody.
  ///
  /// In en, this message translates to:
  /// **'All engine settings will go back to their default values.'**
  String get settingsResetEnginesBody;

  /// No description provided for @settingsResetDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to default values'**
  String get settingsResetDefaultsTitle;

  /// No description provided for @settingsResetDefaultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All engines'**
  String get settingsResetDefaultsSubtitle;

  /// No description provided for @settingsDefaultDecoders.
  ///
  /// In en, this message translates to:
  /// **'Default decoders'**
  String get settingsDefaultDecoders;

  /// No description provided for @settingsDefaultDecodersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Formats several engines can play'**
  String get settingsDefaultDecodersSubtitle;

  /// No description provided for @settingsDecodersHelp.
  ///
  /// In en, this message translates to:
  /// **'Some formats can be played by several engines. Pick which one to use by default — every other format is routed automatically.'**
  String get settingsDecodersHelp;

  /// No description provided for @settingsDecoderAmigaTrackers.
  ///
  /// In en, this message translates to:
  /// **'Amiga trackers (mod, med, okt…)'**
  String get settingsDecoderAmigaTrackers;

  /// No description provided for @settingsEngineOpenmptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trackers — MOD, XM, S3M, IT…'**
  String get settingsEngineOpenmptSubtitle;

  /// No description provided for @settingsEngineGmeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SPC, VGM(gme), KSS, AY… — EQ, stereo'**
  String get settingsEngineGmeSubtitle;

  /// No description provided for @settingsEngineNsfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'NES / NSF — quality, filters, per-chip options'**
  String get settingsEngineNsfSubtitle;

  /// No description provided for @settingsEngineGbsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Game Boy / GBS — high-pass filter'**
  String get settingsEngineGbsSubtitle;

  /// No description provided for @settingsEngineMidiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'MIDI — SoundFont in use'**
  String get settingsEngineMidiSubtitle;

  /// No description provided for @settingsEngineGsfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GBA / GSF — interpolation, low-pass, echo'**
  String get settingsEngineGsfSubtitle;

  /// No description provided for @settingsEngineUadeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Amiga — panning, headphones, gain, LED'**
  String get settingsEngineUadeSubtitle;

  /// No description provided for @settingsEngineSidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'C64 / SID — clock, model, ReSIDfp filters'**
  String get settingsEngineSidSubtitle;

  /// No description provided for @settingsEngineAdplugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AdLib OPL — stereo/surround harmonic mode'**
  String get settingsEngineAdplugSubtitle;

  /// No description provided for @settingsEngineHeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PSF / PS1-PS2 — SPU, reverb'**
  String get settingsEngineHeSubtitle;

  /// No description provided for @settingsEngineVgmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'VGM / S98 / DRO — YM2612, OPL3, QSound cores…'**
  String get settingsEngineVgmSubtitle;

  /// No description provided for @settingsMasterVolume.
  ///
  /// In en, this message translates to:
  /// **'Master volume'**
  String get settingsMasterVolume;

  /// No description provided for @settingsAmigaFilter.
  ///
  /// In en, this message translates to:
  /// **'Amiga filter'**
  String get settingsAmigaFilter;

  /// No description provided for @settingsInterpolation.
  ///
  /// In en, this message translates to:
  /// **'Interpolation'**
  String get settingsInterpolation;

  /// No description provided for @settingsPolyphony.
  ///
  /// In en, this message translates to:
  /// **'Polyphony'**
  String get settingsPolyphony;

  /// No description provided for @settingsReverb.
  ///
  /// In en, this message translates to:
  /// **'Reverb'**
  String get settingsReverb;

  /// No description provided for @settingsChorus.
  ///
  /// In en, this message translates to:
  /// **'Chorus'**
  String get settingsChorus;

  /// No description provided for @settingsInterpNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsInterpNone;

  /// No description provided for @settingsInterpLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get settingsInterpLinear;

  /// No description provided for @settingsInterpCubic.
  ///
  /// In en, this message translates to:
  /// **'Cubic'**
  String get settingsInterpCubic;

  /// No description provided for @settingsInterpSinc.
  ///
  /// In en, this message translates to:
  /// **'Sinc (best)'**
  String get settingsInterpSinc;

  /// No description provided for @settingsStereoSeparation.
  ///
  /// In en, this message translates to:
  /// **'Stereo separation'**
  String get settingsStereoSeparation;

  /// No description provided for @settingsGmeSilenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ends the track when the engine detects a long silence'**
  String get settingsGmeSilenceSubtitle;

  /// No description provided for @settingsStereoDepth.
  ///
  /// In en, this message translates to:
  /// **'Stereo depth'**
  String get settingsStereoDepth;

  /// No description provided for @settingsEqualizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get settingsEqualizer;

  /// No description provided for @settingsGmeEqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AY, GBS, HES, KSS, NSF, NSFe, SAP, VGM — no effect on SPC'**
  String get settingsGmeEqSubtitle;

  /// No description provided for @settingsBass.
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get settingsBass;

  /// No description provided for @settingsTreble.
  ///
  /// In en, this message translates to:
  /// **'Treble'**
  String get settingsTreble;

  /// No description provided for @settingsAppliedLive.
  ///
  /// In en, this message translates to:
  /// **'Applied immediately, even during playback.'**
  String get settingsAppliedLive;

  /// No description provided for @settingsAppliedNextTrack.
  ///
  /// In en, this message translates to:
  /// **'Applied to the next track loaded.'**
  String get settingsAppliedNextTrack;

  /// No description provided for @settingsSidEmulation.
  ///
  /// In en, this message translates to:
  /// **'Emulation'**
  String get settingsSidEmulation;

  /// No description provided for @settingsSidResidfp.
  ///
  /// In en, this message translates to:
  /// **'ReSIDfp (accurate)'**
  String get settingsSidResidfp;

  /// No description provided for @settingsSidLite.
  ///
  /// In en, this message translates to:
  /// **'SIDLite (fast)'**
  String get settingsSidLite;

  /// No description provided for @settingsSidSampling.
  ///
  /// In en, this message translates to:
  /// **'Sampling'**
  String get settingsSidSampling;

  /// No description provided for @settingsSidSamplingInterp.
  ///
  /// In en, this message translates to:
  /// **'Interpolation (fast)'**
  String get settingsSidSamplingInterp;

  /// No description provided for @settingsSidSamplingResample.
  ///
  /// In en, this message translates to:
  /// **'Resample (best)'**
  String get settingsSidSamplingResample;

  /// No description provided for @settingsSidClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get settingsSidClock;

  /// No description provided for @settingsSidModel.
  ///
  /// In en, this message translates to:
  /// **'SID model'**
  String get settingsSidModel;

  /// No description provided for @settingsSidFilter.
  ///
  /// In en, this message translates to:
  /// **'SID filter'**
  String get settingsSidFilter;

  /// No description provided for @settingsSidForceSecond.
  ///
  /// In en, this message translates to:
  /// **'Force a 2nd SID'**
  String get settingsSidForceSecond;

  /// No description provided for @settingsSidSecondSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stereo 2SID tunes'**
  String get settingsSidSecondSubtitle;

  /// No description provided for @settingsSidSecondAddr.
  ///
  /// In en, this message translates to:
  /// **'2nd SID address'**
  String get settingsSidSecondAddr;

  /// No description provided for @settingsSidForceThird.
  ///
  /// In en, this message translates to:
  /// **'Force a 3rd SID'**
  String get settingsSidForceThird;

  /// No description provided for @settingsSidThirdAddr.
  ///
  /// In en, this message translates to:
  /// **'3rd SID address'**
  String get settingsSidThirdAddr;

  /// No description provided for @settingsSidAutoFilter.
  ///
  /// In en, this message translates to:
  /// **'Auto 6581 filter range'**
  String get settingsSidAutoFilter;

  /// No description provided for @settingsSidAutoFilterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Value recommended for the tune\'s author (sidplayfp tables)'**
  String get settingsSidAutoFilterSubtitle;

  /// No description provided for @settingsSid6581Range.
  ///
  /// In en, this message translates to:
  /// **'6581 filter range'**
  String get settingsSid6581Range;

  /// No description provided for @settingsSid6581Curve.
  ///
  /// In en, this message translates to:
  /// **'6581 filter curve'**
  String get settingsSid6581Curve;

  /// No description provided for @settingsSid8580Curve.
  ///
  /// In en, this message translates to:
  /// **'8580 filter curve'**
  String get settingsSid8580Curve;

  /// No description provided for @settingsSidNote.
  ///
  /// In en, this message translates to:
  /// **'SID filter and curves are applied live; emulation/sampling/clock/model/2nd-3rd SID take effect on the next track.'**
  String get settingsSidNote;

  /// No description provided for @settingsAudioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio output'**
  String get settingsAudioOutput;

  /// No description provided for @settingsAdplugNote.
  ///
  /// In en, this message translates to:
  /// **'Surround: two slightly detuned OPL chips. Applied to the next track.'**
  String get settingsAdplugNote;

  /// No description provided for @settingsHeSpuMain.
  ///
  /// In en, this message translates to:
  /// **'Main voices (SPU)'**
  String get settingsHeSpuMain;

  /// No description provided for @settingsHeSpuReverb.
  ///
  /// In en, this message translates to:
  /// **'Reverb (SPU)'**
  String get settingsHeSpuReverb;

  /// No description provided for @settingsNsfQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality (nsfplay)'**
  String get settingsNsfQuality;

  /// No description provided for @settingsLowpassFilter.
  ///
  /// In en, this message translates to:
  /// **'Low-pass filter'**
  String get settingsLowpassFilter;

  /// No description provided for @settingsHighpassFilter.
  ///
  /// In en, this message translates to:
  /// **'High-pass filter'**
  String get settingsHighpassFilter;

  /// No description provided for @settingsRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get settingsRegion;

  /// No description provided for @settingsNsfRegionNtscForced.
  ///
  /// In en, this message translates to:
  /// **'NTSC forced'**
  String get settingsNsfRegionNtscForced;

  /// No description provided for @settingsNsfRegionPalForced.
  ///
  /// In en, this message translates to:
  /// **'PAL forced'**
  String get settingsNsfRegionPalForced;

  /// No description provided for @settingsNsfRegionDendyForced.
  ///
  /// In en, this message translates to:
  /// **'Dendy forced'**
  String get settingsNsfRegionDendyForced;

  /// No description provided for @settingsNsfForceIrq.
  ///
  /// In en, this message translates to:
  /// **'Force IRQ'**
  String get settingsNsfForceIrq;

  /// No description provided for @settingsNsfApu1Title.
  ///
  /// In en, this message translates to:
  /// **'2A03 — pulses (APU1)'**
  String get settingsNsfApu1Title;

  /// No description provided for @settingsNsfApu2Title.
  ///
  /// In en, this message translates to:
  /// **'2A03 — triangle / noise / DPCM (APU2)'**
  String get settingsNsfApu2Title;

  /// No description provided for @settingsNsfUnmuteOnReset.
  ///
  /// In en, this message translates to:
  /// **'Unmute on reset'**
  String get settingsNsfUnmuteOnReset;

  /// No description provided for @settingsNsfPhaseRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh phase'**
  String get settingsNsfPhaseRefresh;

  /// No description provided for @settingsNsfPhaseRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the phase when the period is written'**
  String get settingsNsfPhaseRefreshSubtitle;

  /// No description provided for @settingsNsfNonlinearMixer.
  ///
  /// In en, this message translates to:
  /// **'Non-linear mixing'**
  String get settingsNsfNonlinearMixer;

  /// No description provided for @settingsNsfApu1NonlinearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The 2A03\'s real mix (otherwise linear)'**
  String get settingsNsfApu1NonlinearSubtitle;

  /// No description provided for @settingsNsfDutySwap.
  ///
  /// In en, this message translates to:
  /// **'Swap duty cycles'**
  String get settingsNsfDutySwap;

  /// No description provided for @settingsNsfDutySwapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Order of the 25% / 50% duties'**
  String get settingsNsfDutySwapSubtitle;

  /// No description provided for @settingsNsfNegateSweep.
  ///
  /// In en, this message translates to:
  /// **'Negative sweep on init'**
  String get settingsNsfNegateSweep;

  /// No description provided for @settingsNsfEnable4011.
  ///
  /// In en, this message translates to:
  /// **'Register \$4011 enabled'**
  String get settingsNsfEnable4011;

  /// No description provided for @settingsNsfEnable4011Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Direct DAC output (original clicks)'**
  String get settingsNsfEnable4011Subtitle;

  /// No description provided for @settingsNsfPeriodicNoise.
  ///
  /// In en, this message translates to:
  /// **'Periodic noise'**
  String get settingsNsfPeriodicNoise;

  /// No description provided for @settingsNsfPeriodicNoiseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short mode of the noise generator'**
  String get settingsNsfPeriodicNoiseSubtitle;

  /// No description provided for @settingsNsfDpcmAntiClick.
  ///
  /// In en, this message translates to:
  /// **'DPCM anti-click'**
  String get settingsNsfDpcmAntiClick;

  /// No description provided for @settingsNsfRandomizeNoise.
  ///
  /// In en, this message translates to:
  /// **'Randomize noise on init'**
  String get settingsNsfRandomizeNoise;

  /// No description provided for @settingsNsfTriangleMute.
  ///
  /// In en, this message translates to:
  /// **'Mute the triangle'**
  String get settingsNsfTriangleMute;

  /// No description provided for @settingsNsfTriangleMuteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Silences the triangle at ultrasonic periods'**
  String get settingsNsfTriangleMuteSubtitle;

  /// No description provided for @settingsNsfRandomizeTri.
  ///
  /// In en, this message translates to:
  /// **'Randomize triangle on init'**
  String get settingsNsfRandomizeTri;

  /// No description provided for @settingsNsfDpcmReverse.
  ///
  /// In en, this message translates to:
  /// **'Reversed DPCM'**
  String get settingsNsfDpcmReverse;

  /// No description provided for @settingsNsfN163Serial.
  ///
  /// In en, this message translates to:
  /// **'Serial multiplexing'**
  String get settingsNsfN163Serial;

  /// No description provided for @settingsNsfN163SerialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The real N163 buzz on multi-voice tunes'**
  String get settingsNsfN163SerialSubtitle;

  /// No description provided for @settingsNsfN163PhaseReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only phase'**
  String get settingsNsfN163PhaseReadOnly;

  /// No description provided for @settingsNsfN163LimitWavelength.
  ///
  /// In en, this message translates to:
  /// **'Limit the wavelength'**
  String get settingsNsfN163LimitWavelength;

  /// No description provided for @settingsNsfFdsCutoff.
  ///
  /// In en, this message translates to:
  /// **'Low-pass cutoff'**
  String get settingsNsfFdsCutoff;

  /// No description provided for @settingsNsfFds4085Reset.
  ///
  /// In en, this message translates to:
  /// **'\$4085 reset'**
  String get settingsNsfFds4085Reset;

  /// No description provided for @settingsNsfFdsWriteProtect.
  ///
  /// In en, this message translates to:
  /// **'Write protection'**
  String get settingsNsfFdsWriteProtect;

  /// No description provided for @settingsNsfVrc7Patch.
  ///
  /// In en, this message translates to:
  /// **'Patch set'**
  String get settingsNsfVrc7Patch;

  /// No description provided for @settingsNsfVrc7Opll.
  ///
  /// In en, this message translates to:
  /// **'OPLL mode'**
  String get settingsNsfVrc7Opll;

  /// No description provided for @settingsNsfVrc7OpllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Emulate a YM2413 instead of the VRC7'**
  String get settingsNsfVrc7OpllSubtitle;

  /// No description provided for @settingsGbsHpFilter.
  ///
  /// In en, this message translates to:
  /// **'High-pass filter (gbsplay)'**
  String get settingsGbsHpFilter;

  /// No description provided for @settingsGbsFilterDmg.
  ///
  /// In en, this message translates to:
  /// **'DMG (classic GB)'**
  String get settingsGbsFilterDmg;

  /// No description provided for @settingsGbsFilterCgb.
  ///
  /// In en, this message translates to:
  /// **'CGB (GB Color)'**
  String get settingsGbsFilterCgb;

  /// No description provided for @settingsEcho.
  ///
  /// In en, this message translates to:
  /// **'Echo'**
  String get settingsEcho;

  /// No description provided for @settingsUadePostfx.
  ///
  /// In en, this message translates to:
  /// **'Post-processing'**
  String get settingsUadePostfx;

  /// No description provided for @settingsUadePostfxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enables the effect chain (required for everything below)'**
  String get settingsUadePostfxSubtitle;

  /// No description provided for @settingsUadePan.
  ///
  /// In en, this message translates to:
  /// **'Panning (stereo separation)'**
  String get settingsUadePan;

  /// No description provided for @settingsUadePanValue.
  ///
  /// In en, this message translates to:
  /// **'Panning amount'**
  String get settingsUadePanValue;

  /// No description provided for @settingsUadeHeadphones.
  ///
  /// In en, this message translates to:
  /// **'Headphones'**
  String get settingsUadeHeadphones;

  /// No description provided for @settingsUadeLed.
  ///
  /// In en, this message translates to:
  /// **'LED (Paula filter)'**
  String get settingsUadeLed;

  /// No description provided for @settingsUadeLedAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (per tune)'**
  String get settingsUadeLedAuto;

  /// No description provided for @settingsUadeLedOn.
  ///
  /// In en, this message translates to:
  /// **'Forced ON'**
  String get settingsUadeLedOn;

  /// No description provided for @settingsUadeLedOff.
  ///
  /// In en, this message translates to:
  /// **'Forced OFF'**
  String get settingsUadeLedOff;

  /// No description provided for @settingsUadeFilterType.
  ///
  /// In en, this message translates to:
  /// **'Filter type'**
  String get settingsUadeFilterType;

  /// No description provided for @settingsUadeGain.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get settingsUadeGain;

  /// No description provided for @settingsUadeGainValue.
  ///
  /// In en, this message translates to:
  /// **'Gain amount'**
  String get settingsUadeGainValue;

  /// No description provided for @settingsSoundfontLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the catalogue…'**
  String get settingsSoundfontLoading;

  /// No description provided for @settingsSoundfontCatalogueError.
  ///
  /// In en, this message translates to:
  /// **'Catalogue unavailable ({error})'**
  String settingsSoundfontCatalogueError(String error);

  /// No description provided for @settingsSoundfontDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String settingsSoundfontDownloadFailed(String error);

  /// Settings: import a personal SoundFont from the device
  ///
  /// In en, this message translates to:
  /// **'Import a SoundFont…'**
  String get settingsSoundfontImport;

  /// Settings: import a personal SoundFont from the device
  ///
  /// In en, this message translates to:
  /// **'Choose an .sf2 file on this device'**
  String get settingsSoundfontImportSubtitle;

  /// Settings: import a personal SoundFont from the device
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get settingsSoundfontImported;

  /// Settings: import a personal SoundFont from the device
  ///
  /// In en, this message translates to:
  /// **'That file is not a SoundFont (.sf2)'**
  String get settingsSoundfontInvalid;

  /// No description provided for @settingsSoundfontImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed — {error}'**
  String settingsSoundfontImportFailed(String error);

  /// No description provided for @settingsSoundfontDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete the file'**
  String get settingsSoundfontDelete;

  /// No description provided for @settingsCreditsHeader.
  ///
  /// In en, this message translates to:
  /// **'Credits & licenses'**
  String get settingsCreditsHeader;

  /// No description provided for @settingsRightsNotice.
  ///
  /// In en, this message translates to:
  /// **'Rewamp is a player: it hosts no files and distributes no music. Tracks come from online preservation archives and remain the property of their rights holders. It is your responsibility to ensure that listening to them, downloading them and keeping them complies with the applicable rights and with the law of your country.'**
  String get settingsRightsNotice;

  /// No description provided for @settingsFormatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} format supported} other{{count} formats supported}}'**
  String settingsFormatsCount(int count);

  /// No description provided for @settingsFormatsEngines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Handled by {count} playback engine — see the details} other{Spread across {count} playback engines — see the details}}'**
  String settingsFormatsEngines(int count);

  /// No description provided for @settingsUadeDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Amiga songlengths & metadata'**
  String get settingsUadeDataTitle;

  /// No description provided for @settingsUadeDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'audacious-uade songdb by Matti Tiainen (mvtiaine), CC BY-NC-SA 4.0.'**
  String get settingsUadeDataSubtitle;

  /// No description provided for @settingsGb64Title.
  ///
  /// In en, this message translates to:
  /// **'C64 / SID data & cover art'**
  String get settingsGb64Title;

  /// No description provided for @settingsGb64Subtitle.
  ///
  /// In en, this message translates to:
  /// **'GameBase64 (gb64.com) — C64 game metadata and visuals.'**
  String get settingsGb64Subtitle;

  /// No description provided for @settingsFt2FontTitle.
  ///
  /// In en, this message translates to:
  /// **'FastTracker 2 font'**
  String get settingsFt2FontTitle;

  /// No description provided for @settingsFt2FontSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The pattern visualizer\'s FastTracker II style uses the FT2 bitmap font from ft2-clone by 8bitbubsy (16-bits.org).'**
  String get settingsFt2FontSubtitle;

  /// No description provided for @settingsLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'{url} copied'**
  String settingsLinkCopied(String url);

  /// No description provided for @settingsOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get settingsOpenLink;

  /// No description provided for @settingsEnginesHeader.
  ///
  /// In en, this message translates to:
  /// **'Playback engines'**
  String get settingsEnginesHeader;

  /// No description provided for @settingsComponentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Other components'**
  String get settingsComponentsHeader;

  /// No description provided for @settingsResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all settings'**
  String get settingsResetAll;

  /// No description provided for @settingsResetAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'General, Visualization, Playback, Engines — not the library'**
  String get settingsResetAllSubtitle;

  /// No description provided for @settingsResetAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all settings?'**
  String get settingsResetAllTitle;

  /// No description provided for @settingsResetAllBody.
  ///
  /// In en, this message translates to:
  /// **'General, Visualization, Playback and every engine will go back to their default values. Your library and history are untouched.'**
  String get settingsResetAllBody;

  /// No description provided for @settingsRenewUserId.
  ///
  /// In en, this message translates to:
  /// **'Renew the anonymous ID'**
  String get settingsRenewUserId;

  /// No description provided for @settingsRenewUserIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew the anonymous ID?'**
  String get settingsRenewUserIdTitle;

  /// No description provided for @settingsRenewUserIdBody.
  ///
  /// In en, this message translates to:
  /// **'A new anonymous ID will be created for server statistics.\n\nThe old one will no longer be used. Your local history and favorites are unaffected.'**
  String get settingsRenewUserIdBody;

  /// No description provided for @settingsRenewUserIdFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed — server unreachable'**
  String get settingsRenewUserIdFailed;

  /// No description provided for @settingsNewUserId.
  ///
  /// In en, this message translates to:
  /// **'New ID: {id}'**
  String settingsNewUserId(String id);

  /// No description provided for @settingsUserIdValue.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String settingsUserIdValue(String id);

  /// No description provided for @settingsNoUserId.
  ///
  /// In en, this message translates to:
  /// **'No ID registered'**
  String get settingsNoUserId;

  /// No description provided for @settingsCleanDb.
  ///
  /// In en, this message translates to:
  /// **'Clean up the local database'**
  String get settingsCleanDb;

  /// No description provided for @settingsCleanDbSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes entries whose file no longer exists (deleted downloads, old errors)'**
  String get settingsCleanDbSubtitle;

  /// No description provided for @settingsOrphansRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} orphan entry removed} other{{count} orphan entries removed}}'**
  String settingsOrphansRemoved(int count);

  /// No description provided for @settingsDbClean.
  ///
  /// In en, this message translates to:
  /// **'Local database is clean — nothing to remove'**
  String get settingsDbClean;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear the cache (artwork & metadata)'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes cached covers and fetched metadata (STIL, songlengths) — re-downloaded on the next play'**
  String get settingsClearCacheSubtitle;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cache cleared ({count} cover)} other{Cache cleared ({count} covers)}}'**
  String settingsCacheCleared(int count);

  /// No description provided for @settingsResetStats.
  ///
  /// In en, this message translates to:
  /// **'Reset the statistics'**
  String get settingsResetStats;

  /// No description provided for @settingsResetStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes the listening history and the play counters'**
  String get settingsResetStatsSubtitle;

  /// No description provided for @settingsClearStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the statistics?'**
  String get settingsClearStatsTitle;

  /// No description provided for @settingsClearStatsBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:\n• the whole listening history\n• the play counters\n\nYour favorites and your library are unaffected.'**
  String get settingsClearStatsBody;

  /// No description provided for @settingsStatsCleared.
  ///
  /// In en, this message translates to:
  /// **'Statistics deleted'**
  String get settingsStatsCleared;

  /// No description provided for @settingsResetDatabase.
  ///
  /// In en, this message translates to:
  /// **'Reset the database'**
  String get settingsResetDatabase;

  /// No description provided for @settingsResetDatabaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes everything: history, favorites, playlists, cache'**
  String get settingsResetDatabaseSubtitle;

  /// No description provided for @settingsResetDbTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the database?'**
  String get settingsResetDbTitle;

  /// No description provided for @settingsResetDbBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:\n• the whole listening history\n• every counter\n• every favorite\n• every playlist\n• all cached metadata\n\nYour audio files are not deleted.'**
  String get settingsResetDbBody;

  /// No description provided for @settingsDbReset.
  ///
  /// In en, this message translates to:
  /// **'Database reset'**
  String get settingsDbReset;

  /// No description provided for @settingsDeleteDownloads.
  ///
  /// In en, this message translates to:
  /// **'Delete the downloads'**
  String get settingsDeleteDownloads;

  /// No description provided for @settingsDeleteDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes every file in the online folder (tracks, artwork)'**
  String get settingsDeleteDownloadsSubtitle;

  /// No description provided for @settingsDeleteDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the downloads?'**
  String get settingsDeleteDownloadsTitle;

  /// No description provided for @settingsDeleteDownloadsBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete every downloaded file (tracks, albums, artwork) from the online folder.\n\nThe database entries will stay but will point at files that no longer exist.'**
  String get settingsDeleteDownloadsBody;

  /// No description provided for @settingsDownloadsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Downloads deleted'**
  String get settingsDownloadsDeleted;

  /// No description provided for @settingsColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get settingsColor;

  /// No description provided for @settingsPmPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get settingsPmPresets;

  /// No description provided for @settingsPmRandomNext.
  ///
  /// In en, this message translates to:
  /// **'Random next preset'**
  String get settingsPmRandomNext;

  /// No description provided for @settingsPmRandomNextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off: play the presets in order'**
  String get settingsPmRandomNextSubtitle;

  /// No description provided for @settingsPmLockPreset.
  ///
  /// In en, this message translates to:
  /// **'Lock the preset'**
  String get settingsPmLockPreset;

  /// No description provided for @settingsPmLockPresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No automatic switching'**
  String get settingsPmLockPresetSubtitle;

  /// No description provided for @settingsPmPresetDuration.
  ///
  /// In en, this message translates to:
  /// **'Time between presets'**
  String get settingsPmPresetDuration;

  /// No description provided for @settingsPmTransitions.
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get settingsPmTransitions;

  /// No description provided for @settingsPmBlend.
  ///
  /// In en, this message translates to:
  /// **'Cross-fade transition'**
  String get settingsPmBlend;

  /// No description provided for @settingsPmBlendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off: switch presets instantly'**
  String get settingsPmBlendSubtitle;

  /// No description provided for @settingsPmTransitionStyle.
  ///
  /// In en, this message translates to:
  /// **'Transition style'**
  String get settingsPmTransitionStyle;

  /// No description provided for @settingsPmTransitionStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which pattern the blend uses'**
  String get settingsPmTransitionStyleSubtitle;

  /// No description provided for @settingsPmTransitionRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get settingsPmTransitionRandom;

  /// No description provided for @settingsPmHardcut.
  ///
  /// In en, this message translates to:
  /// **'Hardcut'**
  String get settingsPmHardcut;

  /// No description provided for @settingsPmHardcutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Beat-synced preset switching'**
  String get settingsPmHardcutSubtitle;

  /// No description provided for @settingsPmHardcutTime.
  ///
  /// In en, this message translates to:
  /// **'Hardcut: minimum time'**
  String get settingsPmHardcutTime;

  /// No description provided for @settingsPmHardcutSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Hardcut: sensitivity'**
  String get settingsPmHardcutSensitivity;

  /// No description provided for @settingsPmRendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering'**
  String get settingsPmRendering;

  /// No description provided for @settingsPmQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get settingsPmQuality;

  /// No description provided for @settingsPmQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Render resolution (Max = native resolution)'**
  String get settingsPmQualitySubtitle;

  /// No description provided for @settingsPmBeatSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Beat sensitivity'**
  String get settingsPmBeatSensitivity;

  /// No description provided for @settingsPmAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Respect the aspect ratio'**
  String get settingsPmAspectRatio;

  /// No description provided for @settingsPmAspectRatioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For the shaders that support it'**
  String get settingsPmAspectRatioSubtitle;

  /// No description provided for @settingsPmPermissive.
  ///
  /// In en, this message translates to:
  /// **'Permissive mode'**
  String get settingsPmPermissive;

  /// No description provided for @settingsPmPermissiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load .milk files that have script errors'**
  String get settingsPmPermissiveSubtitle;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save and sync your library'**
  String get accountSubtitle;

  /// No description provided for @accountAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous account'**
  String get accountAnonymous;

  /// No description provided for @accountAnonymousExplain.
  ///
  /// In en, this message translates to:
  /// **'Your favourites and your history are stored on the server, but only this device can reach them. Add an email address to find them again elsewhere.'**
  String get accountAnonymousExplain;

  /// No description provided for @accountEmailAttached.
  ///
  /// In en, this message translates to:
  /// **'Address confirmed — this account can be restored'**
  String get accountEmailAttached;

  /// No description provided for @accountEmailPending.
  ///
  /// In en, this message translates to:
  /// **'Address not confirmed yet'**
  String get accountEmailPending;

  /// No description provided for @accountInsecureStorage.
  ///
  /// In en, this message translates to:
  /// **'This device\'s secure storage is unavailable: the account identifier is stored unencrypted.'**
  String get accountInsecureStorage;

  /// No description provided for @accountSaveCta.
  ///
  /// In en, this message translates to:
  /// **'Save my account'**
  String get accountSaveCta;

  /// No description provided for @accountStatSongs.
  ///
  /// In en, this message translates to:
  /// **'Favourite tracks'**
  String get accountStatSongs;

  /// No description provided for @accountStatAlbums.
  ///
  /// In en, this message translates to:
  /// **'Favourite albums'**
  String get accountStatAlbums;

  /// No description provided for @accountStatPlays.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get accountStatPlays;

  /// No description provided for @accountCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get accountCreatedLabel;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountRevoke.
  ///
  /// In en, this message translates to:
  /// **'Log out everywhere'**
  String get accountRevoke;

  /// No description provided for @accountRevokeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Signs out every other device'**
  String get accountRevokeSubtitle;

  /// No description provided for @accountRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'Every other device is signed out. This one stays connected.'**
  String get accountRevokeBody;

  /// No description provided for @accountRevokeDone.
  ///
  /// In en, this message translates to:
  /// **'Other devices signed out'**
  String get accountRevokeDone;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get accountDelete;

  /// No description provided for @accountDeleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Erases the account and its data on the server. Irreversible.'**
  String get accountDeleteSubtitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{items} favourites and {lists} playlists will be deleted from the server. This cannot be undone.'**
  String accountDeleteBody(int items, int lists);

  /// No description provided for @accountDeleteKeepsLocal.
  ///
  /// In en, this message translates to:
  /// **'Your downloads and this device\'s library are not affected.'**
  String get accountDeleteKeepsLocal;

  /// No description provided for @accountDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleteDone;

  /// No description provided for @accountSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This device goes back to a new, empty account'**
  String get accountSignOutSubtitle;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get accountSignOutTitle;

  /// No description provided for @accountSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You can come back to this account with a code sent to {email}.'**
  String accountSignOutBody(String email);

  /// No description provided for @accountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get accountSignedOut;

  /// No description provided for @accountNoSignOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out is unavailable'**
  String get accountNoSignOut;

  /// No description provided for @accountNoSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Without an email address, this account could never be recovered.'**
  String get accountNoSignOutSubtitle;

  /// No description provided for @accountDetach.
  ///
  /// In en, this message translates to:
  /// **'Unlink address'**
  String get accountDetach;

  /// No description provided for @accountDetachSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The account goes back to anonymous, no data is deleted'**
  String get accountDetachSubtitle;

  /// No description provided for @accountDetachBody.
  ///
  /// In en, this message translates to:
  /// **'Without an address, this account can no longer be recovered from another device.'**
  String get accountDetachBody;

  /// No description provided for @accountDetachDone.
  ///
  /// In en, this message translates to:
  /// **'Address unlinked'**
  String get accountDetachDone;

  /// No description provided for @accountOffline.
  ///
  /// In en, this message translates to:
  /// **'Account unavailable offline'**
  String get accountOffline;

  /// No description provided for @accountEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get accountEmailTitle;

  /// No description provided for @accountEmailExplain.
  ///
  /// In en, this message translates to:
  /// **'We send you a 6-digit code to confirm the address. It is only used to recover your account.'**
  String get accountEmailExplain;

  /// No description provided for @accountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get accountEmailLabel;

  /// No description provided for @accountCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code'**
  String get accountCodeTitle;

  /// No description provided for @accountCodeExplain.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {email}. It is valid for 10 minutes.'**
  String accountCodeExplain(String email);

  /// No description provided for @accountCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get accountCodeLabel;

  /// No description provided for @accountSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send the code'**
  String get accountSendCode;

  /// No description provided for @accountVerify.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get accountVerify;

  /// No description provided for @accountResend.
  ///
  /// In en, this message translates to:
  /// **'Resend the code'**
  String get accountResend;

  /// No description provided for @accountResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {n} s'**
  String accountResendIn(int n);

  /// No description provided for @accountCheckSpam.
  ///
  /// In en, this message translates to:
  /// **'The email can take up to a minute to arrive — check your spam folder.'**
  String get accountCheckSpam;

  /// No description provided for @accountErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid address'**
  String get accountErrorInvalidEmail;

  /// No description provided for @accountErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, try again in a few minutes'**
  String get accountErrorTooMany;

  /// No description provided for @accountErrorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong or expired code'**
  String get accountErrorInvalidCode;

  /// No description provided for @accountErrorCodeLength.
  ///
  /// In en, this message translates to:
  /// **'The code has 6 digits'**
  String get accountErrorCodeLength;

  /// No description provided for @accountErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, try again'**
  String get accountErrorNetwork;

  /// No description provided for @accountMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge this library?'**
  String get accountMergeTitle;

  /// No description provided for @accountMergeBody.
  ///
  /// In en, this message translates to:
  /// **'This device\'s favourites and history will be added to the {email} account. This cannot be undone.'**
  String accountMergeBody(String email);

  /// No description provided for @accountMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get accountMergeConfirm;

  /// No description provided for @accountCarryLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep this device\'s favourites'**
  String get accountCarryLocal;

  /// No description provided for @accountCarryLocalOn.
  ///
  /// In en, this message translates to:
  /// **'The {n} favourites and the playlists on this device are added to the account.'**
  String accountCarryLocalOn(int n);

  /// No description provided for @accountCarryLocalOff.
  ///
  /// In en, this message translates to:
  /// **'They are deleted from this device and replaced by the account\'s. Downloaded files are kept.'**
  String get accountCarryLocalOff;

  /// No description provided for @accountDropLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop this device\'s data?'**
  String get accountDropLocalTitle;

  /// No description provided for @accountCreatedOk.
  ///
  /// In en, this message translates to:
  /// **'Account saved, your library is backed up'**
  String get accountCreatedOk;

  /// No description provided for @accountMergedOk.
  ///
  /// In en, this message translates to:
  /// **'Signed in — your local favourites were added'**
  String get accountMergedOk;

  /// No description provided for @accountSignedInOk.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedInOk;

  /// No description provided for @playlistEntryMissing.
  ///
  /// In en, this message translates to:
  /// **'File missing on this device'**
  String get playlistEntryMissing;

  /// No description provided for @playlistEntryMissingRestorable.
  ///
  /// In en, this message translates to:
  /// **'File missing — can be downloaded again'**
  String get playlistEntryMissingRestorable;

  /// No description provided for @playlistMissingCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} missing} other{{n} missing}}'**
  String playlistMissingCount(int n);

  /// No description provided for @playlistBackupToAccount.
  ///
  /// In en, this message translates to:
  /// **'Back up to my account'**
  String get playlistBackupToAccount;

  /// No description provided for @playlistBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keeps this playlist even if the app is reinstalled'**
  String get playlistBackupSubtitle;

  /// No description provided for @playlistBackupUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update the backup'**
  String get playlistBackupUpdate;

  /// No description provided for @playlistBackupUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replaces the account copy with this version'**
  String get playlistBackupUpdateSubtitle;

  /// No description provided for @playlistBackupStop.
  ///
  /// In en, this message translates to:
  /// **'Stop backing up'**
  String get playlistBackupStop;

  /// No description provided for @playlistBackupStopped.
  ///
  /// In en, this message translates to:
  /// **'Backup removed'**
  String get playlistBackupStopped;

  /// No description provided for @playlistBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Playlist backed up'**
  String get playlistBackupDone;

  /// No description provided for @playlistBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get playlistBackupFailed;

  /// No description provided for @playlistBackupNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account on this device'**
  String get playlistBackupNoAccount;

  /// No description provided for @playlistSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync with my account'**
  String get playlistSyncTooltip;

  /// No description provided for @playlistSyncRunning.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get playlistSyncRunning;

  /// No description provided for @playlistSyncDone.
  ///
  /// In en, this message translates to:
  /// **'Playlists synced'**
  String get playlistSyncDone;

  /// No description provided for @playlistSyncPartial.
  ///
  /// In en, this message translates to:
  /// **'Some playlists could not be backed up'**
  String get playlistSyncPartial;

  /// No description provided for @playlistFetchMissing.
  ///
  /// In en, this message translates to:
  /// **'Download the missing tracks'**
  String get playlistFetchMissing;

  /// No description provided for @playlistFetchDone.
  ///
  /// In en, this message translates to:
  /// **'Missing tracks downloaded'**
  String get playlistFetchDone;

  /// No description provided for @playlistFetchPartial.
  ///
  /// In en, this message translates to:
  /// **'Some tracks could not be downloaded'**
  String get playlistFetchPartial;

  /// No description provided for @playlistEntryFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'This track could not be downloaded'**
  String get playlistEntryFetchFailed;

  /// No description provided for @accountStatPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get accountStatPlaylists;

  /// No description provided for @accountSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get accountSyncNow;

  /// No description provided for @accountSyncAuto.
  ///
  /// In en, this message translates to:
  /// **'Runs on its own in the background'**
  String get accountSyncAuto;

  /// No description provided for @accountSyncAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Backed up to the server. Add an email to sync another device.'**
  String get accountSyncAnonymous;

  /// No description provided for @accountSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Changes waiting to be sent'**
  String get accountSyncPending;

  /// No description provided for @accountSyncLast.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {when}'**
  String accountSyncLast(String when);

  /// No description provided for @accountSyncDone.
  ///
  /// In en, this message translates to:
  /// **'Sync done'**
  String get accountSyncDone;

  /// No description provided for @accountSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed, will retry'**
  String get accountSyncFailed;

  /// No description provided for @podiumFirst.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get podiumFirst;

  /// No description provided for @podiumSecond.
  ///
  /// In en, this message translates to:
  /// **'2nd'**
  String get podiumSecond;

  /// No description provided for @podiumThird.
  ///
  /// In en, this message translates to:
  /// **'3rd'**
  String get podiumThird;

  /// No description provided for @podiumMusicOf.
  ///
  /// In en, this message translates to:
  /// **'music of {production}, {place} — {compo}'**
  String podiumMusicOf(String production, String place, String compo);

  /// No description provided for @podiumContains.
  ///
  /// In en, this message translates to:
  /// **'contains the {place} of {compo}'**
  String podiumContains(String place, String compo);

  /// No description provided for @competitionEmpty.
  ///
  /// In en, this message translates to:
  /// **'This competition has no entries'**
  String get competitionEmpty;

  /// No description provided for @competitionEntryNoMusic.
  ///
  /// In en, this message translates to:
  /// **'No music in the catalogue for this entry'**
  String get competitionEntryNoMusic;

  /// No description provided for @competitionEntryTunes.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} tune} other{{n} tunes}}'**
  String competitionEntryTunes(int n);

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboardingBetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Beta version'**
  String get onboardingBetaTitle;

  /// No description provided for @onboardingBetaBody.
  ///
  /// In en, this message translates to:
  /// **'Rewamp is still being built. Local data — library, playlists, favourites, listening stats — may be wiped before version 1.0. Nothing you download is at risk, but keep anything precious backed up elsewhere.'**
  String get onboardingBetaBody;

  /// No description provided for @onboardingVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build})'**
  String onboardingVersion(String version, String build);

  /// No description provided for @onboardingExploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get onboardingExploreTitle;

  /// No description provided for @onboardingExploreBody.
  ///
  /// In en, this message translates to:
  /// **'Browse and search tens of thousands of chiptunes and tracker modules from the great online archives, by artist, album, platform or party. Tap to listen, download to keep.'**
  String get onboardingExploreBody;

  /// No description provided for @onboardingLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get onboardingLibraryTitle;

  /// No description provided for @onboardingLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Save what you like, build playlists, organise them in folders. Anything downloaded plays offline, and your library follows you across devices once you sign in.'**
  String get onboardingLibraryBody;

  /// No description provided for @onboardingPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'The player'**
  String get onboardingPlayerTitle;

  /// No description provided for @onboardingPlayerBody.
  ///
  /// In en, this message translates to:
  /// **'Swipe to change track, and open the visualizers: oscilloscope, per-voice scopes, scrolling notes, tracker grid. Multi-track files expose their subsongs, and every voice can be muted on its own.'**
  String get onboardingPlayerBody;

  /// No description provided for @onboardingReplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome tour'**
  String get onboardingReplayTitle;

  /// No description provided for @onboardingReplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay the beta notice and the feature tour'**
  String get onboardingReplaySubtitle;

  /// No description provided for @settingsPatternTitle.
  ///
  /// In en, this message translates to:
  /// **'Patterns'**
  String get settingsPatternTitle;

  /// No description provided for @settingsPatternSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tracker grid: colours, columns, scrolling'**
  String get settingsPatternSubtitle;

  /// No description provided for @patternOpaqueBg.
  ///
  /// In en, this message translates to:
  /// **'Opaque background'**
  String get patternOpaqueBg;

  /// No description provided for @patternOpaqueBgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides the cover art behind the grid'**
  String get patternOpaqueBgSubtitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @accountDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Public name'**
  String get accountDisplayName;

  /// No description provided for @accountDisplayNameNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set — required to publish a playlist'**
  String get accountDisplayNameNotSet;

  /// No description provided for @accountDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'The name you want to be credited under.'**
  String get accountDisplayNameHint;

  /// No description provided for @accountDisplayNameChangeWarning.
  ///
  /// In en, this message translates to:
  /// **'Changing it sends every playlist you published back for review.'**
  String get accountDisplayNameChangeWarning;

  /// No description provided for @accountDisplayNameTaken.
  ///
  /// In en, this message translates to:
  /// **'This name is taken. Choose another one.'**
  String get accountDisplayNameTaken;

  /// No description provided for @accountDisplayNameLength.
  ///
  /// In en, this message translates to:
  /// **'Between 2 and 40 characters.'**
  String get accountDisplayNameLength;

  /// No description provided for @accountDisplayNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Public name saved'**
  String get accountDisplayNameSaved;

  /// No description provided for @accountDisplayNameBackInReview.
  ///
  /// In en, this message translates to:
  /// **'Playlists sent back for review: {n}'**
  String accountDisplayNameBackInReview(int n);

  /// No description provided for @playlistPublish.
  ///
  /// In en, this message translates to:
  /// **'Make public'**
  String get playlistPublish;

  /// No description provided for @playlistPublishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Request publication (reviewed first)'**
  String get playlistPublishSubtitle;

  /// No description provided for @playlistPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish this playlist?'**
  String get playlistPublishTitle;

  /// No description provided for @playlistPublishBody.
  ///
  /// In en, this message translates to:
  /// **'It becomes visible to everyone once approved, credited to your public name. The cover comes from its tracks.'**
  String get playlistPublishBody;

  /// No description provided for @playlistPublishCta.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get playlistPublishCta;

  /// No description provided for @playlistPublishSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent for review'**
  String get playlistPublishSubmitted;

  /// No description provided for @playlistPublishPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get playlistPublishPending;

  /// No description provided for @playlistPublishApproved.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get playlistPublishApproved;

  /// No description provided for @playlistPublishRejected.
  ///
  /// In en, this message translates to:
  /// **'Refused: {reason}'**
  String playlistPublishRejected(String reason);

  /// No description provided for @playlistPublishRejectedShort.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get playlistPublishRejectedShort;

  /// No description provided for @playlistPublishNeedName.
  ///
  /// In en, this message translates to:
  /// **'Choose the name you want to be credited under'**
  String get playlistPublishNeedName;

  /// No description provided for @playlistPublishNeedTracks.
  ///
  /// In en, this message translates to:
  /// **'At least 5 tracks are needed to publish'**
  String get playlistPublishNeedTracks;

  /// No description provided for @playlistPublishHasLocal.
  ///
  /// In en, this message translates to:
  /// **'Files from your device cannot be published — others cannot play them'**
  String get playlistPublishHasLocal;

  /// No description provided for @playlistPublishTooManyPending.
  ///
  /// In en, this message translates to:
  /// **'You already have 3 playlists waiting for approval'**
  String get playlistPublishTooManyPending;

  /// No description provided for @playlistPublishRefused.
  ///
  /// In en, this message translates to:
  /// **'Publication refused: check the tracks and the pending requests'**
  String get playlistPublishRefused;

  /// No description provided for @playlistPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Publication failed'**
  String get playlistPublishFailed;

  /// No description provided for @playlistPublishWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Playlist is private again'**
  String get playlistPublishWithdrawn;

  /// No description provided for @playlistUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Make private'**
  String get playlistUnpublish;

  /// No description provided for @playlistUnpublishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes it from public playlists'**
  String get playlistUnpublishSubtitle;

  /// No description provided for @playlistRenamePublishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename a published playlist?'**
  String get playlistRenamePublishedTitle;

  /// No description provided for @playlistRenamePublishedBody.
  ///
  /// In en, this message translates to:
  /// **'The name is what gets reviewed: renaming sends the playlist back for approval and unpublishes it meanwhile. Adding or reordering tracks does not.'**
  String get playlistRenamePublishedBody;

  /// No description provided for @playlistByAuthor.
  ///
  /// In en, this message translates to:
  /// **'by {author}'**
  String playlistByAuthor(String author);

  /// No description provided for @settingsSpectrumMode.
  ///
  /// In en, this message translates to:
  /// **'Spectrum mode'**
  String get settingsSpectrumMode;

  /// No description provided for @settingsSpectrumModeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsSpectrumModeStandard;

  /// No description provided for @settingsSpectrumModeColored.
  ///
  /// In en, this message translates to:
  /// **'Colored'**
  String get settingsSpectrumModeColored;

  /// No description provided for @settingsSpectrumModeBeam.
  ///
  /// In en, this message translates to:
  /// **'Beam'**
  String get settingsSpectrumModeBeam;

  /// No description provided for @settingsSpectrumModeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get settingsSpectrumModeLine;

  /// No description provided for @settingsSpectrumModeRing.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get settingsSpectrumModeRing;

  /// No description provided for @releaseNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get releaseNotesTitle;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Downloads: a long one can be cancelled while it runs, and an album archive is no longer fetched several times over.'**
  String get releaseNotesV4Downloads;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Queue: a button to empty it, with a confirmation — it also stops what is playing.'**
  String get releaseNotesV4Queue;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Files dropped on the window: choose play now, next or at the end; artwork and companion files are left out, and a playlist shipped inside an archive is honoured (real track names, no dead slots).'**
  String get releaseNotesV4DropFiles;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'MIDI: import your own SoundFont from the device, alongside the ones offered by the server.'**
  String get releaseNotesV4Soundfont;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Wwise, FSB and OGL game streams play at last (custom Vorbis).'**
  String get releaseNotesV4Formats;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Six more sound chips, a choice of emulation core per chip (SameBoy for Game Boy), and correct pitch on sampled chips.'**
  String get releaseNotesV4Chips;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'ZX Spectrum: .vt2 tunes play, and note and pattern views now cover the whole ZX family.'**
  String get releaseNotesV4Zx;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Repeat one really loops the tune instead of reloading it, and the time counter no longer freezes on an endless loop.'**
  String get releaseNotesV4Loop;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'The ⓘ panel lists the files a tune actually opened — companions and libraries included.'**
  String get releaseNotesV4Info;

  /// Beta 4 release note bullet
  ///
  /// In en, this message translates to:
  /// **'Linux desktop build.'**
  String get releaseNotesV4Linux;

  /// No description provided for @releaseNotesDataReset.
  ///
  /// In en, this message translates to:
  /// **'Local data was reset for this beta. Your library and playlists rebuild from your account; downloads start over.'**
  String get releaseNotesDataReset;

  /// No description provided for @releaseNotesDismiss.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get releaseNotesDismiss;

  /// No description provided for @pmManagePresets.
  ///
  /// In en, this message translates to:
  /// **'Manage presets'**
  String get pmManagePresets;

  /// No description provided for @pmPickTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pick a preset'**
  String get pmPickTooltip;

  /// No description provided for @pmPickFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter presets'**
  String get pmPickFilter;

  /// No description provided for @pmSourceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preset source'**
  String get pmSourceTooltip;

  /// No description provided for @pmAddToPlaylistTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add preset to a playlist'**
  String get pmAddToPlaylistTooltip;

  /// No description provided for @pmSlowPresetDropped.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is too heavy for this device and was set aside.'**
  String pmSlowPresetDropped(String name);

  /// No description provided for @pmSlowDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'This device is too slow'**
  String get pmSlowDeviceTitle;

  /// No description provided for @pmSlowDeviceOff.
  ///
  /// In en, this message translates to:
  /// **'The visualiser was turned off: this device cannot keep up with Milkdrop presets.'**
  String get pmSlowDeviceOff;

  /// No description provided for @settingsPmSlowPresets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 preset set aside} other{{count} presets set aside}}'**
  String settingsPmSlowPresets(int count);

  /// No description provided for @settingsPmSlowPresetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Too slow on this device. Playback skips them.'**
  String get settingsPmSlowPresetsSubtitle;

  /// No description provided for @settingsPmSlowPresetsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get settingsPmSlowPresetsRestore;

  /// No description provided for @pmSourceBundled.
  ///
  /// In en, this message translates to:
  /// **'Built-in presets'**
  String get pmSourceBundled;

  /// No description provided for @pmSourceImports.
  ///
  /// In en, this message translates to:
  /// **'My imports'**
  String get pmSourceImports;

  /// No description provided for @pmSourceAll.
  ///
  /// In en, this message translates to:
  /// **'All presets'**
  String get pmSourceAll;

  /// No description provided for @pmPresetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} preset} other{{count} presets}}'**
  String pmPresetCount(int count);

  /// No description provided for @pmNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist…'**
  String get pmNewPlaylist;

  /// No description provided for @pmPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get pmPlaylistName;

  /// No description provided for @pmAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to playlist'**
  String get pmAddedToPlaylist;

  /// No description provided for @pmAlreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Already in this playlist'**
  String get pmAlreadyInPlaylist;

  /// No description provided for @pmTabPacks.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get pmTabPacks;

  /// No description provided for @pmTabBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get pmTabBrowse;

  /// No description provided for @pmTabPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get pmTabPlaylists;

  /// No description provided for @pmTabPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get pmTabPopular;

  /// No description provided for @pmTabSetAside.
  ///
  /// In en, this message translates to:
  /// **'Set aside'**
  String get pmTabSetAside;

  /// No description provided for @pmSetAsideEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing set aside. Presets that make this device drop below 6 fps land here.'**
  String get pmSetAsideEmpty;

  /// No description provided for @pmSetAsideRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get pmSetAsideRestoreAll;

  /// No description provided for @pmInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get pmInstall;

  /// No description provided for @pmInstallQueued.
  ///
  /// In en, this message translates to:
  /// **'Install queued'**
  String get pmInstallQueued;

  /// No description provided for @pmUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get pmUninstall;

  /// No description provided for @pmUninstalled.
  ///
  /// In en, this message translates to:
  /// **'Pack removed'**
  String get pmUninstalled;

  /// No description provided for @pmUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get pmUse;

  /// No description provided for @pmDefaultPackBanner.
  ///
  /// In en, this message translates to:
  /// **'Recommended starter pack'**
  String get pmDefaultPackBanner;

  /// No description provided for @pmLicense.
  ///
  /// In en, this message translates to:
  /// **'License: {license}'**
  String pmLicense(String license);

  /// No description provided for @pmPacksOffline.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get pmPacksOffline;

  /// No description provided for @pmSearchPresets.
  ///
  /// In en, this message translates to:
  /// **'Search presets…'**
  String get pmSearchPresets;

  /// No description provided for @pmPlayNow.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get pmPlayNow;

  /// No description provided for @pmDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get pmDownloadAction;

  /// No description provided for @pmDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Preset downloaded'**
  String get pmDownloaded;

  /// No description provided for @pmDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get pmDownloadFailed;

  /// No description provided for @pmPreviewing.
  ///
  /// In en, this message translates to:
  /// **'Playing: {name}'**
  String pmPreviewing(String name);

  /// No description provided for @pmLocalSection.
  ///
  /// In en, this message translates to:
  /// **'My playlists'**
  String get pmLocalSection;

  /// No description provided for @pmCuratedSection.
  ///
  /// In en, this message translates to:
  /// **'Rewamp playlists'**
  String get pmCuratedSection;

  /// No description provided for @pmImportPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Download and use'**
  String get pmImportPlaylist;

  /// No description provided for @pmPlaylistImported.
  ///
  /// In en, this message translates to:
  /// **'Playlist ready'**
  String get pmPlaylistImported;

  /// No description provided for @pmImportFiles.
  ///
  /// In en, this message translates to:
  /// **'Import files…'**
  String get pmImportFiles;

  /// No description provided for @pmImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No preset imported} =1{{count} preset imported} other{{count} presets imported}}'**
  String pmImported(int count);

  /// No description provided for @pmPresetsImported.
  ///
  /// In en, this message translates to:
  /// **'Presets added to the projectM library'**
  String get pmPresetsImported;

  /// No description provided for @pmNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No preset playlists yet'**
  String get pmNoPlaylists;

  /// No description provided for @pmSourceApplied.
  ///
  /// In en, this message translates to:
  /// **'Preset source applied'**
  String get pmSourceApplied;

  /// No description provided for @pmPlaylistEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get pmPlaylistEmpty;

  /// No description provided for @pmDays7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get pmDays7;

  /// No description provided for @pmDays30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get pmDays30;

  /// No description provided for @pmDays365.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get pmDays365;

  /// No description provided for @pmUsesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} play} other{{count} plays}}'**
  String pmUsesCount(int count);

  /// No description provided for @pmInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Install failed'**
  String get pmInstallFailed;

  /// No description provided for @pmSingleDownloads.
  ///
  /// In en, this message translates to:
  /// **'Individual downloads'**
  String get pmSingleDownloads;

  /// No description provided for @pmAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Available in {pack}'**
  String pmAvailableIn(String pack);

  /// No description provided for @pmCleanUp.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get pmCleanUp;

  /// No description provided for @pmCleanedUp.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to clean up} =1{{count} preset deleted} other{{count} presets deleted}}'**
  String pmCleanedUp(int count);

  /// No description provided for @pmLockAction.
  ///
  /// In en, this message translates to:
  /// **'Lock this preset'**
  String get pmLockAction;

  /// No description provided for @pmUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock the preset'**
  String get pmUnlockAction;

  /// No description provided for @pmOrderRandom.
  ///
  /// In en, this message translates to:
  /// **'Shuffle presets'**
  String get pmOrderRandom;

  /// No description provided for @pmOrderSequential.
  ///
  /// In en, this message translates to:
  /// **'Play presets in order'**
  String get pmOrderSequential;

  /// No description provided for @pmUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get pmUpdateAvailable;

  /// No description provided for @pmUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get pmUpdate;

  /// No description provided for @pmSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get pmSelectAll;

  /// No description provided for @pmSelectNone.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get pmSelectNone;

  /// No description provided for @pmSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None selected} one{{count} selected} other{{count} selected}}'**
  String pmSelectedCount(int count);

  /// No description provided for @pmUnusedTextures.
  ///
  /// In en, this message translates to:
  /// **'Unused textures'**
  String get pmUnusedTextures;

  /// No description provided for @pmTexturesFreed.
  ///
  /// In en, this message translates to:
  /// **'{size} freed'**
  String pmTexturesFreed(String size);

  /// No description provided for @pmTexturesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} texture} other{{count} textures}}'**
  String pmTexturesCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'cs',
        'da',
        'de',
        'en',
        'es',
        'fi',
        'fr',
        'hu',
        'it',
        'ja',
        'ko',
        'nl',
        'no',
        'pl',
        'pt',
        'ru',
        'sv',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'da':
      return AppLocalizationsDa();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'hu':
      return AppLocalizationsHu();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'no':
      return AppLocalizationsNo();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'sv':
      return AppLocalizationsSv();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
