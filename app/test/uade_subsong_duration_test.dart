import 'package:flutter_test/flutter_test.dart';
import 'package:rewamp/uade_info.dart';

/// A multi-subsong Amiga module: the catalogue holds ONE length per file (the
/// first subsong's), so every per-subsong duration has to come from the songdb.
/// Values are the real ones for modland's TFMX "mdat.monkey island"
/// (md5 c95aa4f4…, min_subsong 0, 22 subsongs).
UadeInfo _monkeyIsland() => const UadeInfo(
      minSubsong: 0,
      subsongCount: 22,
      subsongs: [
        UadeSubsong(idx: 0, lengthMs: 43180, songend: 'p'),
        UadeSubsong(idx: 1, lengthMs: 40380, songend: 'p'),
        UadeSubsong(idx: 2, lengthMs: 43180, songend: 'p'),
        UadeSubsong(idx: 3, lengthMs: 62040, songend: 'p'),
        UadeSubsong(idx: 4, lengthMs: 97660, songend: 'p'),
        UadeSubsong(idx: 17, lengthMs: 0, songend: 'n'),
        UadeSubsong(idx: 20, lengthMs: 148720, songend: 'p'),
      ],
    );

void main() {
  test('each subsong reports its OWN songdb length', () {
    final info = _monkeyIsland();
    expect(info.durationMsFor(0), 43180);
    expect(info.durationMsFor(1), 40380);
    expect(info.durationMsFor(3), 62040);
    expect(info.durationMsFor(20), 148720);
  });

  test('a 1-based songdb is matched on idx, not on position', () {
    // min_subsong 1: the queue enqueues idx 1..3, and reading those as
    // positions would shift every duration by one entry.
    const info = UadeInfo(
      minSubsong: 1,
      subsongCount: 3,
      subsongs: [
        UadeSubsong(idx: 1, lengthMs: 10000, songend: 'p'),
        UadeSubsong(idx: 2, lengthMs: 20000, songend: 'p'),
        UadeSubsong(idx: 3, lengthMs: 30000, songend: 'p'),
      ],
    );
    expect(info.durationMsFor(1), 10000);
    expect(info.durationMsFor(2), 20000);
    expect(info.durationMsFor(3), 30000);
    // No entry claims idx 0 → read as a position: the first subsong.
    expect(info.durationMsFor(0), 10000);
  });

  test('playableSubsongs drops the NOSOUND slot but keeps its idx', () {
    final playable = _monkeyIsland().playableSubsongs;
    expect(playable.any((s) => s.idx == 17), isFalse);
    // The idx is what the queue enqueues, so it must survive the filtering —
    // position 5 of the filtered list is still subsong 20.
    expect(playable.last.idx, 20);
    expect(playable.last.lengthMs, 148720);
  });
}
