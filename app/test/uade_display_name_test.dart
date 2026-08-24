import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/uade_info.dart';

/// Amiga modules name their FORMAT before the dot ("mdat.monkey island"), so
/// the usual basename-minus-extension answers the format token instead of the
/// tune — which is how the player ended up titled "mdat".
void main() {
  test('prefix form: the name is what follows the token', () {
    expect(UadeInfoService.displayName('mdat.monkey island'), 'monkey island');
    expect(UadeInfoService.displayName('/a/b/mdat.monkey island'),
        'monkey island');
    expect(UadeInfoService.displayName('smpl.turrican 2'), 'turrican 2');
    expect(UadeInfoService.displayName('AHX.Nightshift'), 'Nightshift');
  });

  test('suffix form and plain names keep the usual rule', () {
    expect(UadeInfoService.displayName('/a/b/monkey island.mod'),
        'monkey island');
    expect(UadeInfoService.displayName('great giana sisters.ahx'),
        'great giana sisters');
    expect(UadeInfoService.displayName('no_extension'), 'no_extension');
  });

  test('an unknown token is an extension, not a format prefix', () {
    // "Mr" is no UADE format, so this is a plain name with a suffix.
    expect(UadeInfoService.displayName('Mr.Beat'), 'Mr');
  });
}
