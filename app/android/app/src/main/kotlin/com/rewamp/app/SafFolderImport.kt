package com.rewamp.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Import d'un DOSSIER sur Android, par le Storage Access Framework.
 *
 * ⚠️ Le sélecteur de `file_picker` ne convient pas ICI: il rend un CHEMIN de
 * système de fichiers, reconstruit depuis l'URI de l'arbre
 * (`getFullPathFromTreeUri`), du genre `/storage/emulated/0/Music/sid`. Or
 * l'app ne déclare AUCUNE permission de stockage — et depuis Android 11 il n'y
 * en a plus qui donne l'accès par chemin à des fichiers non-médias: un `.sid`
 * n'est pas un média pour MediaStore, donc `READ_MEDIA_AUDIO` ne l'ouvre pas
 * davantage. L'énumération rendait donc ZÉRO fichier, et l'import se terminait
 * sur « rien de jouable dans la sélection » — un import qui « réussit » sans
 * rien importer, exactement le piège déjà payé côté iOS avec la portée de
 * sécurité.
 *
 * La permission d'arbre que l'utilisateur vient d'accorder, elle, ouvre TOUT le
 * sous-arbre par `ContentResolver`, sans aucune permission déclarée. On copie
 * donc ici même, vers le dossier que Dart nous désigne (`<support>/local/…`),
 * et Dart n'a plus qu'à enregistrer ce qui a atterri.
 *
 * La permission n'est PAS persistée: la copie a lieu tout de suite et l'app ne
 * relit jamais l'original. Prendre une permission durable serait demander à
 * garder un accès dont on n'a plus besoin dès la copie finie.
 */
object SafFolderImport {
    const val CHANNEL = "rewamp/saf_folder"
    const val REQUEST_CODE = 0x5AF0

    private const val TAG = "RewampSaf"

    private var pending: MethodChannel.Result? = null

    /** Ouvre le sélecteur d'arbre. Le résultat part par [onActivityResult]. */
    fun pick(activity: Activity, result: MethodChannel.Result) {
        // Un seul sélecteur à la fois: le précédent est abandonné proprement
        // plutôt que laissé sans réponse (une promesse Dart qui n'aboutit
        // jamais fige le geste pour toujours).
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", "ACTION_OPEN_DOCUMENT_TREE: $e", null)
        }
    }

    /** @return true quand la requête nous appartient. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val r = pending ?: return true
        pending = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) { r.success(null); return true }   // annulé
        r.success(uri.toString())
        return true
    }

    /**
     * Copie récursive de l'arbre [treeUri] vers [destPath]. Rend le nombre de
     * fichiers écrits.
     *
     * Parcours par `DocumentsContract` et non par `DocumentFile`: celui-ci fait
     * une requête PAR fichier pour chaque attribut (nom, type, taille), là où
     * une seule projection par dossier suffit — sur un dossier de plusieurs
     * centaines de modules la différence se voit.
     */
    fun copyTree(activity: Activity, treeUri: Uri, destPath: String): Int {
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val dest = File(destPath)
        dest.mkdirs()
        return copyDir(activity, treeUri, rootId, dest)
    }

    private fun copyDir(activity: Activity, treeUri: Uri, docId: String, dest: File): Int {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
        var written = 0
        val cursor = activity.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null, null, null,
        ) ?: return 0
        cursor.use { c ->
            while (c.moveToNext()) {
                val childId = c.getString(0)
                val name = c.getString(1) ?: continue
                val mime = c.getString(2)
                // Un nom de document vient d'ailleurs: il ne doit pas pouvoir
                // désigner un chemin HORS de la destination.
                if (name == "." || name == ".." || name.contains('/')) continue
                if (name.startsWith(".")) continue
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    val sub = File(dest, name)
                    sub.mkdirs()
                    written += copyDir(activity, treeUri, childId, sub)
                    continue
                }
                val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                val out = File(dest, name)
                try {
                    activity.contentResolver.openInputStream(docUri)?.use { input ->
                        out.outputStream().use { output -> input.copyTo(output) }
                    } ?: continue
                    written++
                } catch (e: Exception) {
                    // Un fichier illisible ne fait pas échouer le lot — même
                    // règle que la copie côté Dart.
                    Log.w(TAG, "copie impossible: $name ($e)")
                }
            }
        }
        return written
    }
}
