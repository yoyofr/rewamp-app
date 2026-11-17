// Texte dicté (Siri) ↔ catalogue, SANS dépendre de la langue de l'utilisateur.
//
// Le catalogue est surtout en alphabet latin, souvent sans accents (titres
// anglais, romaji). Siri transcrit dans la langue de l'utilisateur: accents
// (« Légende »), cyrillique (« Тетрис »), grec, kana (« テトリス »). Plutôt
// qu'une liste par langue: (1) on retire TOUS les diacritiques latins, (2) on
// translittère les écritures qui ont une forme latine conventionnelle
// (cyrillique, grec, kana). Les kanji / hanzi n'en ont pas — ils restent tels
// quels, et seul un titre catalogué dans sa graphie d'origine les trouvera.

/// [s] en minuscules, sans diacritiques, translittéré en latin quand c'est
/// possible. Ne retire ni la ponctuation ni les espaces.
String foldVoiceText(String s) {
  final out = StringBuffer();
  final lower = s.toLowerCase();
  final runes = lower.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    // Kana: une syllabe peut tenir sur DEUX caractères (きゃ = kya).
    if (i + 1 < runes.length) {
      final pair = ch + String.fromCharCode(runes[i + 1]);
      final k2 = _greekPairs[pair] ?? _kanaPairs[_toHiragana(pair)];
      if (k2 != null) {
        out.write(k2);
        i++;
        continue;
      }
    }
    final k = _kana[_toHiragana(ch)];
    if (k != null) {
      out.write(k);
      continue;
    }
    out.write(_single[ch] ?? ch);
  }
  // Petit tsu (っ/ッ) = consonne doublée: « っと » → « tto ».
  return out
      .toString()
      .replaceAllMapped(RegExp(r'~([a-z])'), (m) => '${m[1]}${m[1]}')
      .replaceAll('~', '');
}

/// Vrai si [s] contient une écriture que [foldVoiceText] translittère
/// (cyrillique, grec, kana): la requête serveur mérite alors un second essai
/// sous sa forme latine.
bool hasTransliterableScript(String s) =>
    RegExp(r'[Ͱ-ϿЀ-ӿ぀-ヿ]').hasMatch(s);

// Katakana → hiragana (même table pour les deux).
String _toHiragana(String s) => String.fromCharCodes(s.runes.map(
    (r) => (r >= 0x30A1 && r <= 0x30F6) ? r - 0x60 : r));

const Map<String, String> _single = {
  // Latin: diacritiques et lettres liées.
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
  'ď': 'd', 'đ': 'd', 'ð': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ğ': 'g', 'ģ': 'g', 'ĥ': 'h', 'ħ': 'h',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
  'ķ': 'k', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'ŕ': 'r', 'ř': 'r', 'ś': 's', 'ş': 's', 'š': 's', 'ș': 's', 'ß': 'ss',
  'ţ': 't', 'ť': 't', 'ț': 't', 'þ': 'th',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
  'æ': 'ae', 'œ': 'oe',
  // Cyrillique (translittération courante, russe/ukrainien/bulgare/serbe).
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'ґ': 'g', 'д': 'd', 'ђ': 'dj', 'е': 'e',
  'ё': 'e', 'є': 'ye', 'ж': 'zh', 'з': 'z', 'и': 'i', 'і': 'i', 'ї': 'yi', 'й': 'y',
  'ј': 'j', 'к': 'k', 'л': 'l', 'љ': 'lj', 'м': 'm', 'н': 'n', 'њ': 'nj', 'о': 'o',
  'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'ћ': 'c', 'у': 'u', 'ф': 'f', 'х': 'kh',
  'ц': 'ts', 'ч': 'ch', 'џ': 'dz', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y',
  'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  // Grec.
  'α': 'a', 'ά': 'a', 'β': 'v', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'έ': 'e', 'ζ': 'z',
  'η': 'i', 'ή': 'i', 'θ': 'th', 'ι': 'i', 'ί': 'i', 'ϊ': 'i', 'ΐ': 'i', 'κ': 'k',
  'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x', 'ο': 'o', 'ό': 'o', 'π': 'p', 'ρ': 'r',
  'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y', 'ύ': 'y', 'ϋ': 'y', 'ΰ': 'y', 'φ': 'f',
  'χ': 'ch', 'ψ': 'ps', 'ω': 'o', 'ώ': 'o',
  // Ponctuation japonaise / pleine chasse courante.
  'ー': '', '・': ' ', '　': ' ',
};

// Digrammes grecs dont la lecture n'est pas la somme des lettres.
const Map<String, String> _greekPairs = {
  'ου': 'ou', 'ού': 'ou', 'αι': 'ai', 'αί': 'ai', 'ει': 'ei', 'εί': 'ei',
  'οι': 'oi', 'οί': 'oi', 'μπ': 'b', 'ντ': 'd', 'γκ': 'g', 'γγ': 'ng',
};

// Hiragana (les katakana y sont ramenés par _toHiragana), romaji Hepburn.
const Map<String, String> _kana = {
  'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
  'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
  'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
  'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
  'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
  'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
  'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
  'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
  'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
  'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
  'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
  'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
  'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
  'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
  'わ': 'wa', 'ゐ': 'i', 'ゑ': 'e', 'を': 'o', 'ん': 'n', 'ゔ': 'vu',
  'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o',
  'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'っ': '~',
};

// Syllabes composées (consonne + petit ya/yu/yo, et quelques formes katakana).
const Map<String, String> _kanaPairs = {
  'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo', 'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
  'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho', 'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo',
  'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho', 'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
  'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo', 'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
  'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo', 'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
  'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
  'ふぁ': 'fa', 'ふぃ': 'fi', 'ふぇ': 'fe', 'ふぉ': 'fo', 'てぃ': 'ti', 'でぃ': 'di',
  'うぃ': 'wi', 'うぇ': 'we', 'うぉ': 'wo', 'ゔぁ': 'va', 'ゔぃ': 'vi', 'ゔぇ': 've', 'ゔぉ': 'vo',
  'しぇ': 'she', 'じぇ': 'je', 'ちぇ': 'che',
};
