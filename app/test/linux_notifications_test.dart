// Les arguments de `org.freedesktop.Notifications.Notify` — construits à part
// pour être testés sans bus: c'est là que se jouent l'échappement du texte, le
// REMPLACEMENT de la notification précédente, et les indications.
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/linux_notifications.dart';

void main() {
  List<DBusValue> args({String body = 'Konami', String? image, int id = 0}) =>
      LinuxTrackNotifier.notifyArgs(
          title: '千菜（秋）', body: body, imagePath: image, replacesId: id);

  test('signature conforme à la spec: susssasa{sv}i', () {
    expect(args().map((a) => a.signature.value).join(), 'susssasa{sv}i');
  });

  test('replaces_id est repassé: la piste suivante REMPLACE la précédente', () {
    expect((args(id: 42)[1] as DBusUint32).value, 42);
  });

  test('le corps est ÉCHAPPÉ (balisage), le titre non', () {
    final a = args(body: 'Tom & Jerry <live>');
    expect((a[4] as DBusString).value, 'Tom &amp; Jerry &lt;live&gt;');
    expect((a[3] as DBusString).value, '千菜（秋）', reason: 'kanji intacts');
  });

  test('indications: transient, desktop-entry, et la pochette en URI', () {
    final hints = (args(image: '/tmp/a b.png')[6] as DBusDict).children
        .map((k, v) => MapEntry((k as DBusString).value, (v as DBusVariant).value));
    expect((hints['transient'] as DBusBoolean).value, isTrue,
        reason: 'une annonce de piste passée ne reste pas dans l\'historique');
    expect((hints['desktop-entry'] as DBusString).value, 'app.rewamp.Rewamp');
    expect((hints['image-path'] as DBusString).value, 'file:///tmp/a%20b.png');
  });

  test('sans pochette: pas d\'indication image-path', () {
    final hints = (args()[6] as DBusDict).children.keys
        .map((k) => (k as DBusString).value);
    expect(hints, isNot(contains('image-path')));
  });
}
