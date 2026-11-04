import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/l10n/app_localizations.dart';
import 'package:rewamp/rewamp_db.dart';
import 'package:rewamp/search_screen.dart';
import 'package:rewamp/local_db.dart';
import 'package:rewamp/download_cancel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Database db;
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('carplay-download-');
    RewampDb.debugDownloadsBaseOverride = temp;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE tracks (online_id TEXT)');
    await db
        .execute('CREATE TABLE download_sources (online_id TEXT PRIMARY KEY, '
            'source_url TEXT, updated_at INTEGER)');
    LocalDb.instance.debugUseDatabase(db);
  });
  tearDown(() async {
    RewampDb.debugDownloadsBaseOverride = null;
    RewampDb.downloadStatus.value = null;
    await db.close();
    await temp.delete(recursive: true);
  });

  SearchResult row(String path) => SearchResult(
      songId: path,
      collection: 'local',
      filename: 'tune.sid',
      title: 'Tune',
      album: null,
      formatExt: 'sid',
      downloadUrl: null,
      fileSize: 0,
      year: null,
      artistNames: const ['Composer'],
      totalCount: 0,
      localPath: path,
      subsongIdx: 7);

  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) {
          context = ctx;
          return const Scaffold(body: Text('Phone remains usable'));
        })));
    await tester.pumpAndSettle();
    return context;
  }

  testWidgets(
      'CarPlay cached playback preserves the subsong and never opens/pops a phone route',
      (tester) async {
    final context = await host(tester);
    final file = File('${temp.path}/tune.sid')..writeAsBytesSync([1, 2, 3]);
    String? playedPath;
    int? playedSubsong;
    await tester.runAsync(() => downloadAndPlay(context, row(file.path),
            (path, title,
                {artist,
                album,
                albumId,
                formatExt,
                onlineId,
                artworkUrl,
                artworkTargetDir,
                int subsongIdx = 0,
                durationS,
                subsongCount}) {
          playedPath = path;
          playedSubsong = subsongIdx;
        }, showUI: false));
    await tester.pumpAndSettle();
    expect(playedPath, file.path);
    expect(playedSubsong, 7);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Phone remains usable'), findsOneWidget);
  });

  testWidgets(
      'CarPlay resolver errors reach the car without a phone dialog or snackbar',
      (tester) async {
    final context = await host(tester);
    var callbackCalled = false;
    await tester.runAsync(() async {
      await expectLater(
          downloadAndPlay(context, row('${temp.path}/missing.sid'),
              (path, title,
                  {artist,
                  album,
                  albumId,
                  formatExt,
                  onlineId,
                  artworkUrl,
                  artworkTargetDir,
                  int subsongIdx = 0,
                  durationS,
                  subsongCount}) {
            callbackCalled = true;
          }, showUI: false),
          throwsA(isA<Exception>()));
    });
    await tester.pumpAndSettle();
    expect(callbackCalled, false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Phone remains usable'), findsOneWidget);
  });
  testWidgets(
      'uncached selection waits for all bytes and reports download progress',
      (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final started = Completer<void>();
      final release = Completer<void>();
      server.listen((request) async {
        request.response.contentLength = 8;
        request.response.add([1, 2, 3, 4]);
        await request.response.flush();
        started.complete();
        await release.future;
        request.response.add([5, 6, 7, 8]);
        await request.response.close();
      });
      final song = SearchResult(
          songId: 'new-track',
          collection: 'test',
          filename: 'new.sid',
          title: 'New tune',
          album: 'Album',
          albumId: 'album-id',
          formatExt: 'sid',
          downloadUrl: 'http://127.0.0.1:${server.port}/new.sid',
          fileSize: 8,
          year: null,
          artistNames: const [],
          totalCount: 0);
      String? playedPath;
      final token = DownloadCancelToken();
      final download = token.run(() => downloadAndPlay(context, song,
              (path, title,
                  {artist,
                  album,
                  albumId,
                  formatExt,
                  onlineId,
                  artworkUrl,
                  artworkTargetDir,
                  int subsongIdx = 0,
                  durationS,
                  subsongCount}) {
            playedPath = path;
          }, showUI: false));
      try {
        await started.future.timeout(const Duration(seconds: 5));
        expect(playedPath, isNull);
        expect(RewampDb.downloadStatus.value?.label, 'New tune');
        expect(RewampDb.downloadStatus.value?.error, isNull);
        release.complete();
        await download.timeout(const Duration(seconds: 5));
        expect(await File(playedPath!).readAsBytes(), [1, 2, 3, 4, 5, 6, 7, 8]);
        expect(RewampDb.downloadStatus.value, isNull);
      } finally {
        if (!release.isCompleted) release.complete();
        token.cancel();
        await server.close(force: true);
      }
    });
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
