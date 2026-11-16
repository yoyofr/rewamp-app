// Bibliothèque et ♥ de la piste EN COURS — le geste des boutons du lecteur,
// partagé avec l'écran « À l'écoute » de CarPlay.
//
// La garde d'AJOUT (library_identity.dart) a deux visages: `ensureLibraryRefForAdd`
// parle à l'utilisateur (proposer l'import, dire pourquoi c'est refusé), ce que
// CarPlay ne peut pas faire — pas de feuille, pas de snack sur l'écran de la
// voiture: il passe par `acceptedLibraryRefForAdd` (library_identity.dart).
import 'local_db.dart';
import 'player_controller.dart';
import 'sync_service.dart';

/// Pose ou retire la piste en cours de la bibliothèque. [refId] est déjà
/// passé par la garde pour un AJOUT (un retrait n'est jamais gardé).
Future<void> setCurrentTrackInLibrary(
    PlayerController ctrl, String refId, bool value) async {
  if (value) {
    await LocalDb.instance.addToLibrary(
      type:       'track',
      refId:      refId,
      name:       ctrl.displayTitle,
      artist:     ctrl.currentArtist,
      album:      ctrl.currentAlbum,
      albumId:    ctrl.currentAlbumId,
      artworkUrl: ctrl.artworkUrl,
      formatExt:  ctrl.currentFormatExt,
    );
  } else {
    await LocalDb.instance.removeFromLibrary('track', refId);
  }
  await SyncService.recordTrackMembership(
    refId:     refId,
    value:     value,
    title:     ctrl.displayTitle,
    artist:    ctrl.currentArtist,
    album:     ctrl.currentAlbum,
    formatExt: ctrl.currentFormatExt,
  );
}
