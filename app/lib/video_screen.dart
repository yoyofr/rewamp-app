import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Platform-specific creation params: media playback must not require a user
// gesture (Vimeo autoplay hung "buffering" forever waiting for one).
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'l10n.dart';
import 'orientation_lock.dart';
import 'player_controller.dart';
import 'rewamp_db.dart' show RewampDb, SongVideo;

/// Whether this platform can render the in-app video WebView.
bool get videoWebViewSupported =>
    Platform.isIOS || Platform.isAndroid || Platform.isMacOS;

// ─────────────────────────────────────────────────────────────────────────────
// VideoEmbedController — one YouTube/Vimeo embed with OUR transport.
//
// The native embed controls are disabled (YouTube controls=0; Vimeo honours
// controls=0 only for paying uploader accounts — its native bar may remain)
// and the player is driven through the providers' official JS APIs
// (YT IFrame API / Vimeo player.js) over a JavaScriptChannel bridge, so the
// Flutter side owns play/pause/seek and the placement of every control.
// ─────────────────────────────────────────────────────────────────────────────
class VideoEmbedController {
  final SongVideo video;
  /// Production this video documents, when the video row itself doesn't carry
  /// one (get_production_details videos) — needed by report_video.
  final int? productionIdFallback;
  /// Song these videos were fetched for — report_video's key when the row has
  /// NO production (a video attached manually to a song, server-side).
  final String? songIdFallback;
  late final WebViewController web;
  bool _disposed = false;
  bool _reported = false;

  /// Non-null once the embed told us it cannot play (YT error code / Vimeo
  /// player error): the report_video reason. Drives the failure overlay.
  final ValueNotifier<String?> failure = ValueNotifier(null);

  int? get _productionId => video.productionId ?? productionIdFallback;
  String? get _songId => video.songId ?? songIdFallback;


  /// Playback state mirrored from the embed.
  final ValueNotifier<bool>   playing  = ValueNotifier(false);
  final ValueNotifier<bool>   ended    = ValueNotifier(false);
  /// Vimeo starts MUTED (WebKit blocks audible autoplay — even Safari needs a
  /// gesture; muted autoplay always runs) then unmutes itself; when the
  /// programmatic unmute is refused this stays true and the chrome shows an
  /// unmute button.
  final ValueNotifier<bool>   muted    = ValueNotifier(false);
  final ValueNotifier<double> position = ValueNotifier(0);
  final ValueNotifier<double> duration = ValueNotifier(0);

  VideoEmbedController(this.video,
      {this.productionIdFallback, this.songIdFallback}) {
    // WKWebView (iOS/macOS) blocks autoplaying media-with-sound until a user
    // gesture by default — YouTube's player recovers, Vimeo just spins
    // "buffering" forever. Allow inline, gesture-free media playback.
    final PlatformWebViewControllerCreationParams params =
        WebViewPlatform.instance is WebKitWebViewPlatform
            ? WebKitWebViewControllerCreationParams(
                allowsInlineMediaPlayback: true,
                mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
              )
            : const PlatformWebViewControllerCreationParams();
    web = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Bridge', onMessageReceived: (m) {
        // The native WKWebView outlives this controller (its JS keeps posting
        // t:/state: every 500 ms) — a message landing after dispose() wrote
        // into a disposed ValueNotifier in an endless error loop.
        if (_disposed) return;
        final msg = m.message;
        if (msg.startsWith('state:')) {
          final s = msg.substring(6);
          if (s == 'playing' || s == 'paused' || s == 'ended') {
            playing.value = s == 'playing';
          }
          if (s == 'ended') ended.value = true;
          if (s == 'playing') ended.value = false;
          if (s == 'muted')   muted.value = true;
          if (s == 'unmuted') muted.value = false;
        } else if (msg.startsWith('err:')) {
          _onEmbedError(msg.substring(4));
        } else if (msg.startsWith('t:')) {
          final parts = msg.substring(2).split(':');
          if (parts.length == 2) {
            position.value = double.tryParse(parts[0]) ?? position.value;
            final d = double.tryParse(parts[1]) ?? 0;
            if (d > 0) duration.value = d;
          }
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // Sub-frames (the embed itself + provider API scripts) load freely —
          // wkwebview reports EVERY frame here. Only a main-frame navigation
          // away from the hosted page (e.g. the "Watch on YouTube" link an
          // un-embeddable video shows) goes to the external browser.
          if (!req.isMainFrame) return NavigationDecision.navigate;
          final u = Uri.tryParse(req.url);
          if (u != null &&
              (u.scheme == 'http' || u.scheme == 'https') &&
              u.host != 'rewamp.app' &&
              u.host != 'player.vimeo.com') {
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    // A full Safari UA: Vimeo fingerprints embedded-webview UAs (the app's
    // default UA carries the binary name) and serves a degraded/gated player.
    if (Platform.isMacOS) {
      web.setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/17.4 Safari/605.1.15');
    } else if (Platform.isIOS) {
      web.setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) '
          'Version/17.4 Mobile/15E148 Safari/604.1');
    }
    // Android: same gesture-free media policy.
    if (web.platform is AndroidWebViewController) {
      (web.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // wkwebview throws UnimplementedError("opaque is not implemented on
    // macOS") — the frame behind is black anyway, skip there.
    if (!Platform.isMacOS) web.setBackgroundColor(Colors.black);
    // Hosted HTML page with an https baseUrl: a bare top-level /embed/ load
    // has no Referer/origin, which YouTube rejects with "error 153".
    // Vimeo: pretend to BE player.vimeo.com — the host page and the iframe
    // become same-origin, so WebKit's per-frame autoplay/gesture gating and
    // Vimeo's referer checks see a first-party embed (this is what the
    // vimeo_video_player package does, and its playback works).
    web.loadHtmlString(_html(),
        baseUrl: _vimeoId != null
            ? 'https://player.vimeo.com'
            : 'https://rewamp.app/');
  }

  /// The embed reported an error. Classify it into a report_video reason and
  /// signal it ONCE per video — the providers fire their error events
  /// repeatedly (YT re-fires on every retry, Vimeo on every API call).
  void _onEmbedError(String raw) {
    final reason = _reasonFor(raw);
    if (failure.value == null) failure.value = reason;
    if (_reported) return;
    final prodId = _productionId;
    // A manual video has no production: it is keyed on the song instead.
    final songId = prodId == null ? _songId : null;
    if (prodId == null && (songId == null || songId.isEmpty)) {
      return;   // nothing to key the report on
    }
    _reported = true;
    RewampDb.reportVideo(
      productionId: prodId,
      songId:       songId,
      reason:       reason,
      provider:     video.provider.isEmpty ? null : video.provider,
      videoId:      video.videoId ?? _ytId ?? _vimeoId,
      detail:       raw.length > 300 ? raw.substring(0, 300) : raw,
    );
  }

  /// YouTube IFrame API error codes: 2 = malformed id, 5 = HTML5 player error,
  /// 100 = removed/private, 101/150 = embedding disabled by the uploader.
  /// Vimeo player.js: PrivacyError/PasswordError = private, NotFoundError =
  /// gone. Anything else stays `other` — the raw string travels as detail.
  static String _reasonFor(String raw) {
    final r = raw.toLowerCase();
    if (r.startsWith('yt:')) {
      switch (r.substring(3).trim()) {
        case '2':   return 'wrong_video';      // the id itself is bad
        case '100': return 'video_unavailable';
        // Closed/terminated account, or a pull YouTube renders in-iframe
        // instead of raising: the deadProbe watchdog's verdict.
        case 'dead': return 'video_unavailable';
        case '101':
        case '150': return 'other';            // embeddable? no. gone? no.
        default:    return 'other';
      }
    }
    if (r.contains('privacyerror') || r.contains('passworderror')) {
      return 'video_private';
    }
    if (r.contains('notfounderror')) return 'video_unavailable';
    return 'other';
  }

  void play()  => web.runJavaScript('vPlay && vPlay()');
  void pause() => web.runJavaScript('vPause && vPause()');
  void unmute() => web.runJavaScript('vUnmute && vUnmute()');
  void seekTo(double seconds) {
    // Never exactly 0: the Vimeo/WebKit stream wedges at position 0.
    final s = seconds < 0.1 ? 0.1 : seconds;
    web.runJavaScript('vSeek && vSeek(${s.toStringAsFixed(2)})');
  }

  void dispose() {
    _disposed = true;
    // Actually STOP the page: kill the embed (audio kept playing otherwise)
    // and its interval timers, and drop the bridge channel.
    try {
      web.removeJavaScriptChannel('Bridge');
      web.loadHtmlString('<html></html>');
    } catch (_) {}
    playing.dispose();
    failure.dispose();
    muted.dispose();
    ended.dispose();
    position.dispose();
    duration.dispose();
  }

  /// Every provider keeps its NATIVE transport now: YouTube's carries the
  /// quality + captions (on/off, language) menus the IFrame API cannot
  /// replicate (setPlaybackQuality is a no-op for years), and Vimeo never
  /// starts without an in-page gesture on its own play button.
  bool get nativeControls => true;

  /// YouTube video id, or null when this is not a YouTube URL. The server's
  /// cleaned `video_id` wins; a raw demozoo url can carry junk after the id
  /// ("?v=ID/688" — that trailing number is the start offset), which the
  /// IFrame API rejects with error 2.
  String? get _ytId {
    final clean = video.videoId;
    if (clean != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(clean)) {
      return clean;
    }
    final u = Uri.tryParse(video.url);
    if (u == null) return null;
    final host = u.host.toLowerCase();
    if (host.endsWith('youtu.be')) {
      return u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
    }
    if (host.contains('youtube.com')) {
      final raw = u.queryParameters['v'] ??
          (u.pathSegments.length >= 2 &&
                  (u.pathSegments.first == 'shorts' ||
                      u.pathSegments.first == 'embed')
              ? u.pathSegments[1]
              : null);
      if (raw == null) return null;
      return RegExp(r'^[A-Za-z0-9_-]{11}').firstMatch(raw)?.group(0) ?? raw;
    }
    return null;
  }

  String? get _vimeoId {
    final u = Uri.tryParse(video.url);
    if (u == null || !u.host.toLowerCase().contains('vimeo.com')) return null;
    final id = u.pathSegments
        .lastWhere((s) => int.tryParse(s) != null, orElse: () => '');
    return id.isEmpty ? null : id;
  }

  String _html() {
    const style = '<style>html,body{margin:0;height:100%;background:#000;'
        'overflow:hidden}#p,iframe{position:absolute;inset:0;width:100%;'
        'height:100%;border:0}</style>';
    const head = '<!doctype html><html><head>'
        '<meta name="viewport" content="initial-scale=1.0, width=device-width"/>'
        '$style</head><body>';
    final yt = _ytId;
    if (yt != null) {
      // Official IFrame API: controls=0 hands the transport to us entirely.
      return '''
$head
<div id="p"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
var pl=null, ready=false, everPlayed=false;
function post(m){ if (window.Bridge) Bridge.postMessage(m); }
// A video whose OWNER's account was closed (or that was pulled) renders
// YouTube's own "video unavailable" card INSIDE the iframe and never fires
// onError. What it does do is stay at state -1 with no metadata at all, so
// probe for that: no duration AND no title, twice, several seconds apart
// (a slow network has no metadata yet either, but recovers by the 2nd probe;
// blocked autoplay keeps its metadata, so it never trips this).
function deadProbe(last){
  if(everPlayed) return;
  var d=0,t='';
  try{ d=pl.getDuration()||0; }catch(e){}
  try{ var vd=pl.getVideoData(); t=(vd&&vd.title)||''; }catch(e){}
  if(d>0||t!=='') return;
  if(last) post('err:yt:dead');
  else setTimeout(function(){deadProbe(true);},7000);
}
function onYouTubeIframeAPIReady(){
  pl=new YT.Player('p',{videoId:'$yt',
    playerVars:{autoplay:1,controls:1,playsinline:1,rel:0,fs:0,
                iv_load_policy:3${(video.startSeconds ?? 0) > 0 ? ',start:${video.startSeconds}' : ''}},
    events:{
      onReady:function(){
        ready=true; post('state:ready');
        setTimeout(function(){deadProbe(false);},8000);
      },
      onError:function(e){ post('err:yt:'+e.data); },
      onStateChange:function(e){
        var s=e.data;
        if(s==1||s==3) everPlayed=true;
        post('state:'+(s==1?'playing':s==0?'ended':s==2?'paused':
                       s==3?'buffering':'other'));
      }}});
}
setInterval(function(){
  if(ready&&pl&&pl.getCurrentTime){
    try{post('t:'+pl.getCurrentTime()+':'+pl.getDuration());}catch(e){}
  }},500);
function vPlay(){ if(pl) pl.playVideo(); }
function vPause(){ if(pl) pl.pauseVideo(); }
function vSeek(s){ if(pl) pl.seekTo(s,true); }
</script>
</body></html>''';
    }
    final vm = _vimeoId;
    if (vm != null) {
      // player.js: same bridge; controls=0 is only honoured for paying
      // uploader accounts — the native Vimeo bar may stay visible.
      return '''
$head
<iframe id="v" src="https://player.vimeo.com/video/$vm"
        allow="autoplay; encrypted-media"></iframe>
<script src="https://player.vimeo.com/api/player.js"></script>
<script>
function post(m){ if (window.Bridge) Bridge.postMessage(m); }
window.onerror=function(msg,src,l){ post('err:js:'+msg+' @'+src+':'+l); };
var pl=null;
try { pl=new Vimeo.Player('v'); } catch(e){ post('err:init:'+e); }
if (pl) {
pl.ready().then(function(){ post('state:ready'); })
          .catch(function(e){ post('err:ready:'+(e&&e.name)+' '+(e&&e.message)); });
pl.on('error', function(e){ post('err:player:'+(e&&e.name)+' '+(e&&e.message)); });
pl.on('loaded', function(){ post('state:loaded'); });
pl.on('play',  function(){ post('state:playing'); });
pl.on('pause', function(){ post('state:paused'); });
pl.on('ended', function(){ post('state:ended'); });
var lastWall=Date.now();
pl.on('timeupdate', function(d){
  lastWall=Date.now();
  post('t:'+d.seconds+':'+d.duration);
});
// Anti-stall watchdog: WebKit+Vimeo wedges "playing" at position 0 (and
// after a seek back to 0) with no frames ever arriving — a tiny seek to a
// non-zero position reliably kicks the stream (observed empirically: any
// user seek >0 unblocked it). Nudge whenever playing with no timeupdate
// for 2 s.
setInterval(function(){
  if(Date.now()-lastWall<2000) return;
  pl.getPaused().then(function(p){
    if(p) return;
    lastWall=Date.now();
    pl.getCurrentTime().then(function(t){
      pl.setCurrentTime(t<0.05?0.1:t+0.01)
        .then(function(x){ post('state:kick-ok:'+x); })
        .catch(function(e){ post('err:kick:'+(e&&e.name)+' '+(e&&e.message)); });
    });
  }).catch(function(){});
},1000);
}
function vUnmute(){
  if(!pl) return;
  pl.setMuted(false).then(function(){ pl.setVolume(1); post('state:unmuted'); })
    .catch(function(e){ post('err:unmute:'+(e&&e.name)); });
}
function vPlay(){ if(pl) pl.play().catch(function(e){ post('err:play:'+(e&&e.name)); }); }
function vPause(){ if(pl) pl.pause(); }
function vSeek(s){ if(pl) pl.setCurrentTime(s); }
</script>
</body></html>''';
    }
    // Unknown provider: plain iframe, no bridge (raw URL, native controls).
    return '$head<iframe src="${video.url}" '
        'allow="autoplay; encrypted-media"></iframe></body></html>';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoPlayerPanel — embed + OUR chrome (top bar + bottom transport), shared
// by the inline viz-frame mode and the fullscreen screen. The chrome auto-
// hides on mobile (tap to reveal); desktop keeps it visible (clicks over the
// native WebView never reach Flutter).
// ─────────────────────────────────────────────────────────────────────────────
class VideoPlayerPanel extends StatefulWidget {
  final List<SongVideo> videos;
  final int initialIndex;
  final VoidCallback onClose;
  /// Inline mode: called to expand to fullscreen (hidden when null — the
  /// fullscreen screen itself passes null).
  final void Function(int index)? onFullscreen;
  /// True while the SAME panel is displayed fullscreen (in-place expand, the
  /// WebView is never re-created) — flips the button to fullscreen_exit.
  final bool isFullscreen;
  final bool compact; // inline: tighter paddings, smaller icons
  /// Production the videos belong to, for report_video when the rows
  /// themselves carry no production_id (get_production_details videos).
  final int? productionId;
  /// Song the videos were fetched for — report_video's key for a manual video
  /// (production_id null on its row and no production behind it at all).
  final String? songId;

  const VideoPlayerPanel({
    super.key,
    required this.videos,
    required this.onClose,
    this.initialIndex = 0,
    this.onFullscreen,
    this.isFullscreen = false,
    this.compact = false,
    this.productionId,
    this.songId,
  });

  @override
  State<VideoPlayerPanel> createState() => _VideoPlayerPanelState();
}

class _VideoPlayerPanelState extends State<VideoPlayerPanel> {
  late int _index;
  VideoEmbedController? _embed;
  bool _chromeVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _setEmbed(VideoEmbedController(widget.videos[_index],
        productionIdFallback: widget.productionId,
        songIdFallback: widget.songId));
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _embed?.failure.removeListener(_onFailure);
    _embed?.dispose();
    super.dispose();
  }

  void _setEmbed(VideoEmbedController next) {
    _embed?.failure.removeListener(_onFailure);
    _embed = next;
    next.failure.addListener(_onFailure);
  }

  /// The embed says it cannot play. The chrome carries the ONLY way out of
  /// this screen, so it stops auto-hiding: the failure card is opaque and sits
  /// over both the WebView and the reveal strip, so once the chrome had faded
  /// nothing could bring it back and the screen was a dead end.
  void _onFailure() {
    if (!mounted || _embed?.failure.value == null) return;
    _hideTimer?.cancel();
    if (!_chromeVisible) setState(() => _chromeVisible = true);
  }

  void _scheduleHide() {
    // Desktop included: the in-page hotzone posts ui:activity through the
    // bridge, so the hidden chrome is always recoverable (platform-view
    // clicks never reach Flutter listeners there).
    _hideTimer?.cancel();
    if (_embed?.failure.value != null) return;   // see _onFailure
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  void _showChrome() {
    if (!_chromeVisible && mounted) setState(() => _chromeVisible = true);
    _scheduleHide();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.videos.length - 1);
    if (next == _index) return;
    setState(() {
      _index = next;
      final gone = _embed;
      _setEmbed(VideoEmbedController(widget.videos[next],
          productionIdFallback: widget.productionId,
          songIdFallback: widget.songId));
      gone?.dispose();
    });
    _showChrome();
  }

  @override
  Widget build(BuildContext context) {
    final l10n  = context.l10n;
    final v     = widget.videos[_index];
    final many  = widget.videos.length > 1;
    final embed = _embed!;
    final iconSize = widget.compact ? 20.0 : 24.0;

    Widget btn(IconData icon, VoidCallback? onTap, {String? tip}) =>
        IconButton(
          icon: Icon(icon, color: Colors.white, size: iconSize),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          onPressed: onTap == null
              ? null
              : () {
                  onTap();
                  _showChrome();
                },
        );

    // Compact TOP-LEFT pill (max 2 rows): the embeds' own controls live at
    // the bottom (both) and top-right (Vimeo like/share) — a full-width bar
    // overlapped them.
    final chrome = IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedOpacity(
        opacity: _chromeVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  btn(Icons.close, widget.onClose),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: widget.compact ? 180 : 280),
                    child: Text(
                      v.title ?? l10n.videoWatchDemo,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.compact ? 12 : 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (many) ...[
                    btn(Icons.chevron_left, _index > 0 ? () => _go(-1) : null),
                    Text('${_index + 1}/${widget.videos.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                    btn(Icons.chevron_right,
                        _index < widget.videos.length - 1
                            ? () => _go(1)
                            : null),
                  ],
                  if (widget.onFullscreen != null)
                    btn(
                        widget.isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        () => widget.onFullscreen!(_index)),
                  btn(Icons.open_in_new,
                      () => launchUrl(Uri.parse(v.url),
                          mode: LaunchMode.externalApplication),
                      tip: v.url),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          // The WebView eats its own gestures; a translucent Listener above
          // still sees the pointer-down → any touch re-shows the chrome.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _showChrome(),
              child: WebViewWidget(
                key: ValueKey('embed_${v.url}'),
                controller: embed.web,
              ),
            ),
          ),
          // Reveal strip: thin band along the top edge; hover/tap re-shows
          // the auto-hidden chrome. Chosen over an in-page hotzone div, which
          // killed hit-testing on the whole embed (WebKit + cross-origin
          // iframe). Costs a 24-px dead zone over the embed's top edge only.
          Positioned(
            top: 0, left: 0, right: 0, height: 24,
            child: MouseRegion(
              onHover: (_) => _showChrome(),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _showChrome(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Failure overlay: the embed said it cannot play (and the report
          // has already been sent). The provider page usually still works in
          // a real browser, so offer that rather than a dead end.
          Positioned.fill(
            child: ValueListenableBuilder<String?>(
              valueListenable: embed.failure,
              builder: (ctx, reason, __) {
                if (reason == null) return const SizedBox.shrink();
                // Translucent Listener on top: the card is opaque and covers
                // the WebView AND the reveal strip, so without this a touch on
                // it could not bring the faded chrome back.
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _showChrome(),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off_outlined,
                              color: Colors.white70, size: 32),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(l10n.videoUnavailable,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(l10n.settingsOpenLink),
                                onPressed: () => launchUrl(Uri.parse(v.url),
                                    mode: LaunchMode.externalApplication),
                              ),
                              // The way OUT, spelled out. The chrome's close
                              // button stays visible on failure too, but the
                              // card is what the eye is on, and a dead end is
                              // exactly what this screen must never be.
                              TextButton.icon(
                                icon: const Icon(Icons.close, size: 18),
                                label: Text(l10n.playerClose),
                                onPressed: widget.onClose,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(child: chrome),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoScreen — fullscreen host of VideoPlayerPanel (mirrors the visualizers'
// fullscreen mode). The music is PAUSED on open (the demo capture carries its
// own audio); it is not auto-resumed on close.
// ─────────────────────────────────────────────────────────────────────────────
class VideoScreen extends StatefulWidget {
  final List<SongVideo> videos;
  final int initialIndex;
  /// Production the videos document — report_video's key when the video rows
  /// carry none (get_production_details).
  final int? productionId;
  /// Song the videos belong to — report_video's key for a manual video.
  final String? songId;

  const VideoScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.productionId,
    this.songId,
  });

  /// Entry point: pauses [ctrl] if playing, then either pushes the fullscreen
  /// screen (mobile/macOS) or launches the external browser (other desktops).
  static Future<void> open(
    BuildContext context,
    PlayerController? ctrl,
    List<SongVideo> videos, {
    int index = 0,
    int? productionId,
    String? songId,
  }) async {
    if (videos.isEmpty) return;
    if (ctrl != null && ctrl.isPlaying) ctrl.togglePlay();
    if (!videoWebViewSupported) {
      await launchUrl(Uri.parse(videos[index].url),
          mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoScreen(
          videos: videos,
          initialIndex: index,
          productionId: productionId,
          songId: songId),
    ));
  }

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  // Phones are portrait-locked; a fullscreen visual is exactly the exception
  // (PlayerScreen does the same around its fullscreen viz/video). Opened
  // straight from a production row, this screen is not the player's, so it has
  // to unlock for itself — otherwise a demo capture, which is landscape by
  // nature, plays in a letterboxed portrait strip with no way to rotate.
  @override
  void initState() {
    super.initState();
    OrientationLock.unlock();
  }

  @override
  void dispose() {
    OrientationLock.lock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: VideoPlayerPanel(
          videos: widget.videos,
          initialIndex: widget.initialIndex,
          productionId: widget.productionId,
          songId: widget.songId,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
