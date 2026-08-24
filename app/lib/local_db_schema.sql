-- ============================================================
-- Rewamp — schéma SQLite local (sur l'appareil) — version 60
-- ============================================================
--
-- ⚠️ CE FICHIER EST UNE DOCUMENTATION, généré depuis `_kSchemaStatements`
-- (lib/local_db.dart) — le schéma que `_onCreate` exécute VRAIMENT. Il ne
-- crée rien. Un changement de schéma touche TROIS endroits, et les trois
-- portent (règle payée deux fois, migs 23 et 37): la migration numérotée,
-- `_kSchemaStatements`, et ce fichier. `test/schema_doc_sync_test.dart`
-- échoue quand ce fichier dérive du code.
--
-- LOCALISATEUR DE PISTE
-- ---------------------
-- Une piste est identifiée par (file_path, entry_path, subsong_idx):
--   file_path   — chemin local du fichier OU de l'archive
--   entry_path  — chemin du fichier audio DANS l'archive ('' sinon)
--   subsong_idx — le VRAI index de sous-chanson, celui que le moteur joue
--                 (l'invariant visé — des lignes héritées, et celles nées
--                 d'une entrée de playlist re-matérialisée, peuvent porter un
--                 RANG).
--                 0 = la sous-chanson d'index
--                 0 — qui, pour un fichier mono-piste, SE TROUVE être le
--                 fichier entier. Ce n'est pas une valeur « entier » à part:
--                 les clés locales sont toujours subsong-scopées, 0 compris.
--
-- IDENTITÉS
--   online_id       — uuid catalogue NU, ou `<uuid>#<rang>` pour une ligne née
--                     d'un dépliage (le RANG de tracklist, PAS l'index de
--                     sous-chanson: sur un .gbs mesuré, subsong 12 = rang 13).
--   subsong_count   — le nombre de sous-chansons DU FICHIER (jamais le nombre
--                     de pistes d'un album). Catalogue d'abord, sonde moteur
--                     ensuite; ne fait que MONTER (COALESCE).
--
-- COUCHE COMPTE (miroirs, jamais de vérité locale)
--   library_items        — le ♥ et l'appartenance (la SOURCE, pas tracks.*)
--   account_play_events  — timeline des écoutes de tous les appareils
--   account_track_meta   — noms des pistes que cet appareil n'a pas
--   sync_outbox          — gestes en attente de livraison
-- ============================================================

CREATE TABLE IF NOT EXISTS tracks (
    id               TEXT    PRIMARY KEY,
    -- Server album_id (rewamp_db), stored verbatim like recent_albums.album_id
    -- (plain TEXT, no FK — the old local `albums` table was never populated
    -- and was dropped in migration 18; its FK broke plays, see migration 11).
    album_id         TEXT,
    file_path        TEXT    NOT NULL,
    entry_path       TEXT    NOT NULL DEFAULT '',
    subsong_idx      INTEGER NOT NULL DEFAULT 0,
    title            TEXT,
    artist           TEXT,
    meta_album       TEXT,
    position         INTEGER,
    duration_s       REAL,
    format_ext       TEXT,
    -- Le nombre de sous-chansons DU FICHIER — jamais le nombre de pistes d'un
    -- album. Catalogue d'abord, sonde moteur ensuite (elle rend 0 pour les
    -- moteurs qu'elle ne chaîne pas: on ne DESCEND jamais). COALESCE à
    -- l'écriture: ne fait que monter. « Cette ligne est déjà résolue » est un
    -- drapeau à part (SearchResult.resolvedSubsong), qui vivait ici (== 1).
    subsong_count    INTEGER,
    source           TEXT    NOT NULL DEFAULT 'local',
    online_id        TEXT,
    artwork_url      TEXT,
    -- (mig 52) origine catalogue, écrite quand on la CONNAÎT (téléchargement,
    -- lecture) plutôt que re-devinée à la relance. `year` avec elles: c'est le
    -- seul champ d'en-tête que `_backfillIdentity` allait rechercher au SERVEUR
    -- alors que la tracklist le portait déjà.
    collection_slug  TEXT,
    platform_name    TEXT,
    year             INTEGER,
    is_favorite      INTEGER NOT NULL DEFAULT 0,
    in_library       INTEGER NOT NULL DEFAULT 0,
    library_added_at INTEGER,
    play_count       INTEGER NOT NULL DEFAULT 0,
    last_played_at   INTEGER,
    ext_key          TEXT,        -- (mig 45) identité hors catalogue du fichier
    UNIQUE (file_path, entry_path, subsong_idx)
  );

-- pushed (migration 45), trois états: 0 = le compte DEVRAIT l'avoir et ne
-- l'a pas (envoi raté, hors ligne, pas encore livrée) — la vue fusionnée la
-- compte; 1 = livrée (log_play/log_plays_ext) ou rejouée DEPUIS le compte —
-- c'est le miroir qui la porte; 2 = jamais proposée, sous le seuil de
-- log_play (morceau sauté) — la vue fusionnée l'ignore, sinon deux appareils
-- pourtant synchronisés n'afficheraient pas le même total.
CREATE TABLE IF NOT EXISTS play_events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id   TEXT    NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    played_at  INTEGER NOT NULL DEFAULT 0,
    played_ms  INTEGER,
    backend    TEXT,
    pushed     INTEGER NOT NULL DEFAULT 0
  );

-- Miroir de la timeline du COMPTE (user_play_history, mig serveur 221) —
-- identité serveur, aucun lien vers tracks: une écoute d'un autre appareil
-- porte sur une piste qui peut ne pas exister ici. PK = identité + instant,
-- donc un pull qui rejoue une page (curseur inclusif) n'ajoute rien.
CREATE TABLE IF NOT EXISTS account_play_events (
    kind        TEXT    NOT NULL,
    song_id     TEXT    NOT NULL DEFAULT '',
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    ext_key     TEXT    NOT NULL DEFAULT '',
    played_at   INTEGER NOT NULL,
    played_ms   INTEGER,
    backend     TEXT,           -- (mig 46) moteur, slug tel qu'envoyé
    PRIMARY KEY (song_id, subsong_idx, ext_key, played_at)
  );

-- Albums dont la liste COMPLÈTE a été écrite dans `tracks` (migration 47).
-- La présence de lignes ne prouve rien: une seule piste jouée en crée une.
CREATE TABLE IF NOT EXISTS album_materialised (
    album_id    TEXT    PRIMARY KEY,
    track_count INTEGER NOT NULL,
    at          INTEGER NOT NULL
  );

-- De quoi NOMMER une piste du compte absente de cet appareil (user_songs
-- pour le catalogue, snapshot ext_ref pour le hors-catalogue).
CREATE TABLE IF NOT EXISTS account_track_meta (
    song_id     TEXT    NOT NULL DEFAULT '',
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    ext_key     TEXT    NOT NULL DEFAULT '',
    title       TEXT,
    artist      TEXT,
    album       TEXT,
    album_id    TEXT,
    artwork_url TEXT,
    collection  TEXT,
    platform    TEXT,
    format_ext  TEXT,
    duration_s  REAL,
    PRIMARY KEY (song_id, subsong_idx, ext_key)
  );

CREATE TABLE IF NOT EXISTS playlists (
    id          TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name        TEXT    NOT NULL,
    description TEXT,
    folder_id   TEXT,
    created_at  INTEGER NOT NULL DEFAULT 0,
    updated_at  INTEGER NOT NULL DEFAULT 0,
    server_id   TEXT,
    synced_at   INTEGER,
    server_version TEXT,
    pushed_at   INTEGER,
    dirty_kind  TEXT,
    pushed_count INTEGER,
    folder_changed_at INTEGER
  );

CREATE TABLE IF NOT EXISTS playlist_folders (
    id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name       TEXT    NOT NULL,
    parent_id  TEXT,
    created_at INTEGER NOT NULL DEFAULT 0
  );

CREATE TABLE IF NOT EXISTS playlist_tracks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id TEXT    NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    track_id    TEXT             REFERENCES tracks(id)    ON DELETE SET NULL,
    position    REAL    NOT NULL,
    added_at    INTEGER NOT NULL DEFAULT 0,
    song_id     TEXT,
    file_path   TEXT,
    rel_path    TEXT,
    entry_path  TEXT    NOT NULL DEFAULT '',
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    title       TEXT,
    artist      TEXT,
    album       TEXT,
    -- Server album_id of the entry's album. NOT derivable from the rest: the
    -- catalogue id of a container says nothing about its album, and without it
    -- a track whose first local row is born of a playlist play has none at all
    -- (see PlayerController._backfillIdentity, which exists to paper over it).
    album_id    TEXT,
    format_ext  TEXT,
    duration_s  REAL
  );

-- Trigger: update track play stats on every new play event
CREATE TRIGGER IF NOT EXISTS trg_after_play_insert
  AFTER INSERT ON play_events
  BEGIN
    UPDATE tracks
    SET play_count     = play_count + 1,
        last_played_at = NEW.played_at
    WHERE id = NEW.track_id;
  END;

-- album_key = album_id when known, else "<meta_album>|<album-dir>" — so two
-- same-named albums in different folders/collections don't collapse into one.
CREATE TABLE IF NOT EXISTS recent_albums (
    album_key      TEXT    PRIMARY KEY,
    meta_album     TEXT    NOT NULL,
    album_id       TEXT,
    artist         TEXT,
    file_path      TEXT    NOT NULL,
    artwork_url    TEXT,
    last_played_at INTEGER NOT NULL,
    -- (mig 51) identité catalogue DU FICHIER pointé — un online_id désigne un
    -- fichier, pas une sous-chanson, donc valable pour toutes les subtunes du
    -- même chemin et pour aucun autre chemin.
    online_id      TEXT
  );

-- SID metadata cache — keyed by HVSC MD5 + subsong index (1-based).
-- subsong_idx=0 reserved for global/file-level STIL (not used as a playable track).
CREATE TABLE IF NOT EXISTS sid_info (
    md5          TEXT    NOT NULL,
    subsong_idx  INTEGER NOT NULL,
    length_ms    INTEGER,
    -- STIL NAME/AUTHOR: le nom et le compositeur du SOUS-CHANT — titre et
    -- artiste de la piste.
    stil_name    TEXT,
    stil_author  TEXT,
    -- STIL TITLE/ARTIST: l'ŒUVRE REPRISE et son auteur — panneau ⓘ seulement.
    stil_title   TEXT,
    stil_artist  TEXT,
    stil_comment TEXT,
    fetched_at   INTEGER NOT NULL,
    PRIMARY KEY (md5, subsong_idx)
  );

-- SAP metadata cache — keyed by standard file MD5 (no subsong dimension).
CREATE TABLE IF NOT EXISTS sap_info (
    md5          TEXT    PRIMARY KEY,
    stil_title   TEXT,
    stil_artist  TEXT,
    stil_comment TEXT,
    fetched_at   INTEGER NOT NULL
  );

CREATE TABLE IF NOT EXISTS library_items (
    id              TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    type            TEXT    NOT NULL,
    ref_id          TEXT    NOT NULL,
    name            TEXT    NOT NULL,
    artist          TEXT,
    album           TEXT,
    artwork_url     TEXT,
    format_ext      TEXT,
    collection_slug TEXT,
    platform_name   TEXT,
    filename        TEXT,
    download_url    TEXT,
    album_id        TEXT,
    is_favorite     INTEGER NOT NULL DEFAULT 0,
    favorited_at    INTEGER,
    added_at        INTEGER NOT NULL DEFAULT 0,
    folder_id       TEXT,
    folder_changed_at INTEGER,
    fav_changed_at  INTEGER,
    saved           INTEGER NOT NULL DEFAULT 1,  -- 1 = explicit add; 0 = favorite-only
    UNIQUE (type, ref_id)
  );

CREATE TABLE IF NOT EXISTS sync_outbox (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    kind        TEXT    NOT NULL,
    item_type   TEXT    NOT NULL,
    item_id     TEXT    NOT NULL,
    subsong_idx INTEGER NOT NULL DEFAULT 0,
    ext_key     TEXT,
    ext_ref     TEXT,
    value       INTEGER NOT NULL,
    favourite   INTEGER,
    changed_at  INTEGER NOT NULL,
    attempts    INTEGER NOT NULL DEFAULT 0
  );

-- Remembers the download_url a song was fetched from (keyed by server
-- song_id). When the server replaces a file (same song_id, NEW url), the play
-- path compares this and purges the stale local copy before re-downloading —
-- otherwise the old extraction shadows the fix forever. See migration 24.
CREATE TABLE IF NOT EXISTS download_sources (
    online_id   TEXT PRIMARY KEY,
    source_url  TEXT NOT NULL,
    updated_at  INTEGER
  );

-- Outbox des écoutes de fichiers LOCAUX vers log_plays_ext (migration 44) —
-- livrées par lot, idempotentes serveur (PK user/ext_key/played_at).
CREATE TABLE IF NOT EXISTS ext_play_outbox (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    ext_key       TEXT    NOT NULL,
    ext_ref       TEXT,
    duration_ms   INTEGER NOT NULL,
    played_at     INTEGER NOT NULL,
    attempts      INTEGER NOT NULL DEFAULT 0,
    play_event_id INTEGER,             -- ligne locale à marquer pushed=1
    backend       TEXT                 -- (mig 46) moteur de décodage
  );

-- Playlists de presets projectM (migration 50, locales — pas de synchro
-- serveur en v1). `path` est RELATIF à <datadir>/projectm/ (packs/…,
-- presets/…, user/…, single/…): le conteneur iOS change d'UUID à chaque
-- mise à jour, un chemin absolu casserait.
CREATE TABLE IF NOT EXISTS pm_playlists (
    id         TEXT    PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
    name       TEXT    NOT NULL,
    server_id  TEXT,    -- curated server playlist this one mirrors (import)
    created_at INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL DEFAULT 0
  );

CREATE TABLE IF NOT EXISTS pm_playlist_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id TEXT    NOT NULL REFERENCES pm_playlists(id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,
    path        TEXT    NOT NULL,
    preset_id   TEXT,
    name        TEXT
  );

-- Cache chemin→preset_id serveur (uuid5 stable) pour log_preset_uses.
CREATE TABLE IF NOT EXISTS pm_preset_ids (
    path       TEXT PRIMARY KEY,
    preset_id  TEXT NOT NULL
  );
