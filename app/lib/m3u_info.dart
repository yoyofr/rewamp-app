/// Ce qu'un M3U ÉTENDU dit de l'album, au-delà de sa liste de pistes.
///
/// Un rip soigné met dans l'en-tête de sa playlist tout ce que le catalogue ne
/// sait pas d'un fichier local: le vrai titre de l'album, les compositeurs,
/// l'éditeur, l'année, la version du rip, les sources. Rien de tout ça n'était
/// lu — seuls la liste, les durées et les titres de piste l'étaient — et ces
/// fichiers n'ont par définition aucune ligne serveur pour compenser.
///
/// Deux vocabulaires cohabitent dans le même fichier, et ils ne se lisent pas
/// pareil:
///
///  * **les directives du M3U étendu**, `#DIRECTIVE:valeur` — `#PLAYLIST`,
///    `#EXTALB`, `#EXTART`, `#EXTGENRE`, `#EXTIMG`. Séparateur `:`.
///  * **les tags vgmstream/joshw**, `# @TAG valeur` — `@ALBUM`, `@ARTIST`,
///    `@COMPOSER`, `@DATE`. Séparateur ESPACE. Déjà lus ailleurs
///    (`_m3uGlobalTag`, `_parseM3uArtists`, `_parseM3uYear`), on ne les
///    redéfinit pas ici.
///
/// …plus un troisième, libre: un bloc de commentaires `# Clé: valeur` que les
/// ripeurs écrivent à la main (Game, Developer, Publisher, Release, Composer(s),
/// Series, Sources…). On ne peut pas en faire une liste fermée — chaque rip
/// invente la sienne — donc on garde l'ORDRE et les intitulés du fichier, tels
/// quels. C'est ce que le panneau ⓘ affiche.
library;

/// Une ligne `Clé: valeur` du bloc de commentaires libre.
typedef M3uField = ({String key, String value});

class M3uInfo {
  /// `#PLAYLIST:` — le nom de la LISTE, qui peut préciser la version du rip
  /// (« … (Roland MT-32) ») là où `#EXTALB` nomme l'œuvre.
  final String? playlist;

  /// `#EXTALB:` — le titre de l'album.
  final String? album;

  /// `#EXTART:` — les artistes, déjà découpés.
  final List<String> artists;

  /// `#EXTGENRE:`
  final String? genre;

  /// `#EXTIMG:` — un nom de fichier RELATIF au dossier du M3U.
  final String? image;

  /// Le bloc `# Clé: valeur`, dans l'ordre du fichier.
  final List<M3uField> fields;

  const M3uInfo({
    this.playlist,
    this.album,
    this.artists = const [],
    this.genre,
    this.image,
    this.fields = const [],
  });

  bool get isEmpty =>
      playlist == null &&
      album == null &&
      artists.isEmpty &&
      genre == null &&
      image == null &&
      fields.isEmpty;

  /// La valeur du premier champ libre dont la clé est l'une de [keys]
  /// (comparaison insensible à la casse). null si aucune.
  String? field(List<String> keys) {
    for (final k in keys) {
      for (final f in fields) {
        if (f.key.toLowerCase() == k.toLowerCase()) return f.value;
      }
    }
    return null;
  }
}

/// Découpe une liste d'artistes: « A, B and C » / « A, B & C » → [A, B, C].
///
/// Même nettoyage que `_parseM3uArtists` côté rewamp_db — les deux lisent le
/// même genre de chaîne, écrite par le même genre de main.
List<String> splitM3uArtists(String raw) {
  final parts = raw
      .split(RegExp(r',|\bet\b|\band\b|&', caseSensitive: false))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return parts.isEmpty ? [raw.trim()] : parts;
}

/// Vrai quand la clé d'un champ libre nomme des AUTEURS de la musique.
///
/// Liste volontairement courte: ce qui sert à remplir l'artiste d'une piste,
/// pas tout ce qui ressemble à un crédit. « Other music credits » reste dans
/// le panneau ⓘ et ne devient pas un artiste.
const _kComposerKeys = [
  'composer', 'composers', 'composer(s)', 'compositeur', 'compositeurs',
  'music', 'music by', 'musique',
];

final _kDirective = RegExp(
    r'^#(PLAYLIST|EXTALB|EXTART|EXTGENRE|EXTIMG)\s*:\s*(.*)$',
    caseSensitive: false);

/// `# Clé: valeur`.
///
/// ⚠️ `(?!/)` après le `:` — sans lui une URL NUE en commentaire
/// (« # https://example.org/… ») devenait un champ dont la clé était « https »
/// et la valeur « //example.org/… ». La clé elle-même n'admet ni `:` ni `/`.
final _kFreeField = RegExp(r'^([^:/]{1,40}):(?!/)\s*(.+)$');

/// Lit l'en-tête d'un M3U étendu.
///
/// S'arrête à la première entrée de piste: tout ce qui suit décrit des pistes,
/// pas l'album — et un `#EXTINF` porte un titre qui n'a rien à faire ici.
M3uInfo parseM3uInfo(String text) {
  String? playlist, album, genre, image;
  var artists = const <String>[];
  final fields = <M3uField>[];

  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    if (!line.startsWith('#')) break;            // 1re piste: l'en-tête finit
    if (line.startsWith('#EXTINF')) break;       // idem, par la directive
    if (line.toUpperCase().startsWith('#EXTM3U')) continue;

    final d = _kDirective.firstMatch(line);
    if (d != null) {
      final v = d.group(2)!.trim();
      if (v.isEmpty) continue;
      switch (d.group(1)!.toUpperCase()) {
        case 'PLAYLIST':  playlist = v;
        case 'EXTALB':    album = v;
        case 'EXTART':    artists = splitM3uArtists(v);
        case 'EXTGENRE':  genre = v;
        case 'EXTIMG':    image = v;
      }
      continue;
    }

    // Bloc libre. ⚠️ Une ligne de CONTINUATION est indentée d'au moins DEUX
    // espaces après le `#` — c'est la convention du corpus (« # Sources: … »
    // suivi de « #          Cover: … »), et sans elle la continuation devient
    // un champ « Cover » qui n'existe pas. Un champ normal n'a qu'un espace.
    final body = line.substring(1);
    if (body.trim().isEmpty) continue;           // « # » seul = séparateur
    if (body.startsWith('  ') && fields.isNotEmpty) {
      final last = fields.removeLast();
      fields.add((key: last.key, value: '${last.value}\n${body.trim()}'));
      continue;
    }
    final f = _kFreeField.firstMatch(body.trim());
    if (f != null) {
      final k = f.group(1)!.trim();
      final v = f.group(2)!.trim();
      if (k.isNotEmpty && v.isNotEmpty) fields.add((key: k, value: v));
    }
    // Une ligne de commentaire sans « Clé: » n'est pas une information
    // structurée: on ne l'invente pas en champ.
  }

  // Les compositeurs du bloc libre valent `#EXTART` quand celui-ci manque —
  // c'est la forme que prennent la plupart des rips écrits à la main.
  if (artists.isEmpty) {
    for (final f in fields) {
      if (_kComposerKeys.contains(f.key.toLowerCase())) {
        artists = splitM3uArtists(f.value);
        break;
      }
    }
  }

  return M3uInfo(
    playlist: playlist,
    album:    album,
    artists:  artists,
    genre:    genre,
    image:    image,
    fields:   fields,
  );
}
