// Canonical audio-format extension groups — the single source of truth shared
// by the archive extractor (RewampDb._findExtractedAudio via _kExtractedAudioExts)
// and the file picker + folder scan (home_screen._audioExtensions). Grouped by
// decoder so a new format lands in ONE obvious place instead of drifting between
// two hand-maintained lists (they had already diverged: `dln` vs `dl_deli`, a
// missing `sndh`, etc.).
//
// vgmstream's 700+ set (RewampDb.kVgmstreamExts) and the container list
// (RewampDb.kContainerFormats) live in rewamp_db.dart and are spread in
// alongside kAllDecoderExts by each consumer — keeping them there avoids a
// circular import (this file imports nothing).

/// OpenMPT + generic tracker modules.
const kTrackerExts = <String>{
  'mod', 'xm', 's3m', 'it', 'mptm', 'mo3', 'stm', 'nst', 'm15', 'stk',
  'wow', 'ult', '669', 'mtm', 'med', 'far', 'mdl', 'ams', 'dsm',
  'amf', 'okt', 'dmf', 'ptm', 'psm', 'mt2', 'dbm', 'digi',
  'imf', 'j2b', 'gdm', 'umx',
};

/// Furnace (DivEngine) native + the FamiTracker family it imports.
const kFurnaceExts = <String>{ 'fur', 'ftm', '0cc', 'dnm', 'eft' };

/// libzxtune ZX Spectrum / AY chiptunes (+ .chp via libchpconv).
const kZxtuneExts = <String>{
  'ay', 'ym', 'vtx', 'psg', 'pt1', 'pt2', 'pt3', 'stc', 'st1', 'stp',
  'asc', 'sqt', 'psc', 'gtr', 'chi', 'dst', 'sqd', 'str', 'dmm',
  'tfc', 'tfd', 'tfe', 'ftc', 'pdt', 'chp', 'vt2',
};

/// UADE Amiga custom-chip formats (68k emulation; prefix-convention names like
/// cust.NAME / mdat.NAME resolve via the prefix check in _findExtractedAudio).
const kUadeExts = <String>{
  // Quartet ST (Atari ST, Microdeal): modland names the score NAME.4v and
  // ships its sample bank as a sibling SMP.set; UADE knows it as `qts`.
  '4v',
  'arp', 'ast', 'ahx', 'thx', 'hvl', 'amc', 'abk', 'aam', 'alp', 'aon', 'aon4',
  'aon8', 'adsc', 'mod_adsc4', 'bss', 'bd', 'bds', 'uds', 'kris', 'cin', 'core',
  'cus', 'cust', 'custom', 'cm', 'rk', 'rkb', 'dz', 'mkiio', 'dl', 'dl_deli',
  'dln', 'dh', 'dw', 'dwold', 'dlm2', 'dm2', 'dlm1', 'dm1', 'dsr', 'db',
  'dsc', 'dss', 'dns', 'ems', 'emsv6', 'ex', 'fc13', 'fc3', 'fc', 'fc14',
  'fc4', 'fred', 'gray', 'bfc', 'bsi', 'fc-bsi', 'fp', 'fw', 'glue', 'gm',
  'ea', 'mg', 'hd', 'hipc', 'soc', 'emod', 'qc', 'ims', 'dum', 'is',
  'is20', 'jam', 'jc', 'jmf', 'jcb', 'jcbo', 'jpn', 'jpnd', 'jp', 'jt',
  'mon_old', 'jo', 'hip', 'mcmd', 'sog', 'hip7', 's7g', 'hst', 'kh', 'powt',
  'pt', 'lme', 'mon', 'mfp', 'hn', 'mtp2', 'thn', 'mc', 'mcr', 'mco',
  'mk2', 'mkii', 'avp', 'mw', 'max', 'mcmd_org', 'mmd0', 'mmd1', 'mmd2', 'mso',
  'md', 'mmdc', 'dmu', 'mug', 'dmu2', 'mug2', 'ma', 'mm4', 'mm8', 'mms',
  'ntp', 'two', 'octamed', 'okta', 'one', 'ps', 'snk', 'pvp', 'pap', 'psa',
  'mod_doc', 'mod15', 'mod15_mst', 'mod_ntk', 'mod_ntk1', 'mod_ntk2', 'mod_ntkamp', 'mod_flt4', 'mod_comp', '40a',
  '40b', '41a', '50a', '60a', '61a', 'ac1', 'ac1d', 'aval', 'chan', 'cp',
  'cplx', 'crb', 'di', 'eu', 'fc-m', 'fcm', 'ft', 'fuz', 'fuzz', 'gmc',
  'gv', 'hmc', 'hrt', 'ice', 'it1', 'kef', 'kef7', 'krs', 'ksm', 'lax',
  'mexxmp', 'mpro', 'np', 'np1', 'np2', 'noisepacker2', 'np3', 'noisepacker3', 'nr', 'nru',
  'ntpk', 'p10', 'p21', 'p30', 'p40a', 'p40b', 'p41a', 'p4x', 'p50a', 'p5a',
  'p5x', 'p60', 'p60a', 'p61', 'p61a', 'p6x', 'pha', 'pin', 'pm', 'pm0',
  'pm01', 'pm1', 'pm10c', 'pm18a', 'pm2', 'pm20', 'pm4', 'pm40', 'pmz', 'polk',
  'pp10', 'pp20', 'pp21', 'pp30', 'ppk', 'pr1', 'pr2', 'prom', 'pru', 'pru1',
  'pru2', 'prun', 'prun1', 'prun2', 'pwr', 'pyg', 'pygm', 'pygmy', 'skt', 'skyt',
  'snt', 'st2', 'st26', 'st30', 'star', 'stpk', 'tp', 'tp1', 'tp2', 'tp3',
  'un2', 'unic', 'unic2', 'wn', 'xan', 'xann', 'zen', 'puma', 'rjp', 'sng',
  'riff', 'rh', 'rho', 'sa-p', 'scumm', 's-c', 'scn', 'scr', 'sid1', 'smn',
  'sid2', 'mok', 'sa', 'sonic', 'sa_old', 'smus', 'snx', 'tiny', 'spl', 'sc',
  'sct', 'sfx', 'sfx13', 'tw', 'sm', 'sm1', 'sm2', 'sm3', 'smpro', 'bp',
  'sndmon', 'bp3', 'sjs', 'jd', 'doda', 'sas', 'ss', 'sb', 'jpo', 'jpold',
  'sun', 'syn', 'sdr', 'osp', 'st', 'synmod', 'tfmx7v', 'tfhd7v', 'mdat', 'tfmxpro',
  'tfhdpro', 'tfmx', 'mdst', 'thm', 'tf', 'tme', 'sg', 'dp', 'trc', 'tro',
  'tronic', 'mod15_ust', 'vss', 'wb', 'ml', 'mod15_st-iv', 'agi', 'tpu', 'qpa', 'qts',
  'oss', 'ymst', 'lion', 'bye',
  '!pm!', 'aps', 'ash', 'dm', 'hot', 'hrt!', 'ism', 'jb', 'js', 'kim',
  'mod3', 'mosh', 'mth', 'npp', 'oldw', 'pat', 'pn', 'prt', 'rj', 'sdata',
  'sdc', 'sfx20', 'sj', 'smod', 'snt!', 'tcb', 'tits', 'tmk', 'tron', 'ufo',
  // webUADE+ soundcore players (audio.device/multitasking): Digital Sound
  // Creations (han - UnExotica's Hanlon rips), Music-X driver, MaxTrax,
  // GT Game Systems, SoundTracker Pro II, Stonetracker, PlayAY's amad/strc.
  // 'ay' itself stays with zxtune.
  // 'stp' intentionally absent - already in kZxtuneExts (dedup would be fine,
  // but the zx engine keeps the suffix; the Amiga prefix-form stp.NAME routes
  // to uade natively regardless).
  'han', 'mx', 'mxp', 'mxtx', 'dux', 'spm', 'amad', 'strc',
};

/// libvgm VGM/S98/GYM/DRO (incl. gzip-compressed .vgz).
const kVgmChipExts = <String>{ 'vgm', 'vgz', 's98', 'gym', 'dro', 'dr0' };

/// libsidplayfp C64 SID.
const kSidExts = <String>{
  'sid', 'psid', 'rsid', 'mus', 'str', 'dat', 'prg', 'p00',
};

/// libgme NES/GB/SNES/PCE/AY/HES/KSS/SAP + RSN archive.
const kGmeExts = <String>{
  'nsf', 'nsfe', 'gbs', 'spc', 'hes', 'kss', 'sap', 'ay', 'rsn',
};

/// libkss MSX chiptunes (.kss shared with GME; the rest libkss-only).
const kKssExts = <String>{ 'kss', 'mgs', 'bgm', 'opx', 'mpk', 'mbm' };

/// Highly Experimental PlayStation PSF/PSF2.
const kPsfExts = <String>{ 'psf', 'minipsf', 'psf2', 'minipsf2' };

/// GBA GSF (libgsf / VBA); .gsflib is a shared sibling.
const kGsfExts = <String>{ 'gsf', 'minigsf', 'gsflib' };

/// Nintendo DS 2SF (vio2sf / melonDS); .2sflib is a shared sibling.
const kVio2sfExts = <String>{ '2sf', 'mini2sf', '2sflib' };

/// NCSF — Nintendo DS SDAT sequences (SSEQPlayer software synth; same console
/// as vio2sf, different engine entirely).
const kNcsfExts = <String>{ 'ncsf', 'minincsf', 'ncsflib' };

/// SNSF — Super Nintendo rips (snsf9x : snes9x + APU SPC700/S-DSP, 8 voix).
const kSnsfExts = <String>{ 'snsf', 'minisnsf', 'snsflib' };

/// Monkey's Audio lossless (MACLib).
const kApeExts = <String>{ 'ape' };

/// Farbrausch V2 synth.
const kV2mExts = <String>{ 'v2m', 'v2mz' };

/// Standard MIDI (FluidLite + SoundFont).
const kMidiExts = <String>{ 'mid', 'midi', 'kar', 'rmi' };

/// ASAP Atari 8-bit POKEY.
const kAsapExts = <String>{
  'sap', 'cmc', 'cm3', 'cmr', 'cms', 'dmc', 'dlt', 'mpt', 'mpd',
  'rmt', 'tmc', 'tm8', 'tm2',
};

/// AdPlug AdLib OPL2/OPL3.
const kAdplugExts = <String>{
  'a2m', 'a2t', 'adl', 'adlib', 'agd', 'amd', 'as3m', 'bam', 'bmf', 'cff',
  'cmf', 'd00', 'dfm', 'dm0', 'dmo', 'dtm', 'got', 'ha2', 'hsc', 'hsp', 'hsq',
  'jbm', 'laa', 'lds', 'mad', 'mdi', 'mdy', 'mkf', 'mkj', 'msc', 'mtk', 'mtr',
  'pis', 'plx', 'rac', 'rad', 'rix', 'rol', 'sa2', 'sat', 'sci', 'sdb', 'sop',
  'sqx', 'wlf', 'xad', 'xms', 'xsm',
};

/// HivelyTracker + misc chip/synth formats not covered by the groups above.
const kMiscChipExts = <String>{ 'ahx', 'hvl', 'thx', 'sndh' };

/// libLazyusf Nintendo 64 (.usf main file; .miniusf references a shared
/// sibling _libN — resolved transparently by psflib, same convention as
/// .minigsf/.mini2sf/.minipsf).
const kLazyusfExts = <String>{ 'usf', 'miniusf' };

/// WonderSwan rip (beetle-wswan NEC V30MZ core).
const kWonderswanExts = <String>{ 'wsr' };

/// Capcom QSound (Highly Quixotic, real Z80 + QSound DSP core).
const kHighlyQuixoticExts = <String>{ 'qsf', 'miniqsf', 'qsflib' };

/// Sega Saturn SSF (SCSP) + Sega Dreamcast DSF (AICA) — highlytheoritical,
/// real Musashi 68000 (Saturn) / ARM7 (Dreamcast) core.
const kHighlyTheoriticalExts = <String>{
  'ssf', 'minissf', 'ssflib', 'dsf', 'minidsf', 'dsflib',
};

/// ZX Spectrum PT3 (ProTracker 3) — real AY-3-8910/YM2149 synth (ayumi),
/// takes priority over zxtune's own generic .pt3 claim.
const kLibpt3Exts = <String>{ 'pt3' };

/// Cave Story's own tracker format (Organya, webPixel/Wothke adapter).
const kOrganyaExts = <String>{ 'org' };

/// PxTone Collage — Pixel's own tracker (project files + compiled tunes).
const kPxtoneExts = <String>{ 'ptcop', 'pttune' };

/// PC-98 PMD (Professional Music Driver) — OPNA FM + SSG + PPZ8 samples.
const kPmdExts = <String>{ 'm', 'm2', 'mz' };

/// PC-98 FMP — 98fmplayer's FM driver (OPNA FM + SSG + rhythm + ADPCM + PPZ8).
const kFmpExts = <String>{ 'opi', 'ovi', 'ozi' };

/// Sharp X68000 MDX — YM2151 FM + PCM8 samples (the samples live in a sibling
/// .pdx the engine resolves by the name the .mdx header carries).
const kMdxExts = <String>{ 'mdx' };

/// FM Towns EUPHONY — YM2612 FM + FM Towns PCM (the .fmb/.pmb instrument
/// banks are siblings the engine loads by the names the .eup header carries).
const kEupExts = <String>{ 'eup' };

/// sc68 — Atari ST (YM-2149 + STE DMA) and Amiga (Paula) chip music, real
/// emu68 68000 emulation running the original replay routines.
const kSc68Exts = <String>{ 'sc68' };

/// SunVox — Alexander Zolotov's modular synth + tracker (its own project format).
const kSunvoxExts = <String>{ 'sunvox' };

/// TIATracker — Atari VCS 2600 (TIA, 2 channels). The tracker's project files,
/// which are JSON rather than a binary module.
const kTiaTrackerExts = <String>{ 'ttt' };

/// Plain PCM / lossy audio (miniaudio fallback).
const kPlainAudioExts = <String>{
  'mp3', 'ogg', 'flac', 'wav', 'opus', 'm4a', 'aiff', 'aif',
};

/// Palier 0 — formats dont rewamp rend les PATTERNS nativement, c'est-à-dire
/// exactement les quatre moteurs qui exposent un curseur de pattern
/// (`pattern_cursor` dans `rewamp_plugin.h`): libopenmpt, Furnace, SunVox,
/// TIATracker. Ce sont eux qu'un choix entre plusieurs fichiers doit préférer:
/// ils donnent la vue patterns ET les voix, donc la version la plus riche du
/// même morceau.
final kPatternExts = <String>{
  ...kTrackerExts,
  ...kFurnaceExts,
  ...kSunvoxExts,
  ...kTiaTrackerExts,
};

/// Palier 2 — les FLUX: pas de puce, pas de voies à montrer, rien d'autre à
/// afficher qu'un oscilloscope stéréo. vgmstream (700+ extensions, dans
/// `RewampDb.kVgmstreamExts`) en fait partie et est ajouté par le consommateur,
/// même raison de dépendance circulaire que `kAllDecoderExts`.
final kStreamAudioExts = <String>{
  ...kPlainAudioExts,
  ...kApeExts,
};

/// The union of every decoder group above. Does NOT include vgmstream's 700+ set
/// (RewampDb.kVgmstreamExts) or the container list (RewampDb.kContainerFormats) —
/// consumers spread those in alongside this to avoid a circular import.
/// `final`, not `const`: the groups overlap (e.g. `ay` in zxtune+gme, `kss` in
/// gme+kss, `sap` in gme+asap) and a const set can't hold duplicates; the Set
/// literal dedupes at runtime.
final kAllDecoderExts = <String>{
  ...kTrackerExts,
  ...kFurnaceExts,
  ...kZxtuneExts,
  ...kUadeExts,
  ...kVgmChipExts,
  ...kSidExts,
  ...kGmeExts,
  ...kKssExts,
  ...kPsfExts,
  ...kGsfExts,
  ...kVio2sfExts,
  ...kNcsfExts,
  ...kSnsfExts,
  ...kApeExts,
  ...kV2mExts,
  ...kMidiExts,
  ...kAsapExts,
  ...kAdplugExts,
  ...kMiscChipExts,
  ...kLazyusfExts,
  ...kWonderswanExts,
  ...kHighlyQuixoticExts,
  ...kHighlyTheoriticalExts,
  ...kLibpt3Exts,
  ...kOrganyaExts,
  ...kPxtoneExts,
  ...kPmdExts,
  ...kMdxExts,
  ...kFmpExts,
  ...kEupExts,
  ...kSc68Exts,
  ...kSunvoxExts,
  ...kTiaTrackerExts,
  ...kPlainAudioExts,
};
