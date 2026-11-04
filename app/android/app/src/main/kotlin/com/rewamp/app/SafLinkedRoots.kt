package com.rewamp.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Dossiers LIÉS sur Android (local_roots.dart, `LocalRootKind.saf`).
 *
 * Différence avec [SafFolderImport]: ici la permission d'arbre est PERSISTÉE
 * (`takePersistableUriPermission`) — l'app relit le dossier à chaque lancement
 * au lieu de le copier une fois. Le moteur, lui, n'ouvre que des CHEMINS et va
 * chercher ses compagnons par nom dans le dossier du fichier: Dart fait donc
 * « mettre en scène » le fichier et ses voisins dans un cache ([copy]) juste
 * avant la lecture. Voir docs/local_roots_proposal.md §5.
 *
 * ⚠️ Un identifiant de document n'est un CHEMIN que chez le fournisseur du
 * stockage interne (`primary:Music/mods/x.mod`); Google Drive, OneDrive…
 * rendent des identifiants OPAQUES. Tout ce qui part d'un chemin relatif se
 * résout donc PAR NOMS, segment par segment ([resolve]) — jamais en
 * fabriquant un identifiant.
 */
object SafLinkedRoots {
    const val CHANNEL = "rewamp/saf_roots"
    const val REQUEST_CODE = 0x5AF1
    private const val TAG = "RewampSafRoots"

    private var pending: MethodChannel.Result? = null

    fun pick(activity: Activity, result: MethodChannel.Result) {
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", "ACTION_OPEN_DOCUMENT_TREE: $e", null)
        }
    }

    /** @return true quand la requête nous appartient. */
    fun onActivityResult(activity: Activity, requestCode: Int, resultCode: Int,
                         data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val r = pending ?: return true
        pending = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) { r.success(null); return true }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: Exception) {
            // Sans permission durable le lien ne survivrait pas au relancement:
            // mieux vaut le dire tout de suite que de lier un dossier mort.
            r.error("no_persist", "takePersistableUriPermission: $e", null)
            return true
        }
        r.success(mapOf("uri" to uri.toString(), "label" to displayName(activity, uri)))
        return true
    }

    fun hasPermission(ctx: Context, uri: Uri): Boolean =
        ctx.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission
        }

    fun release(ctx: Context, uri: Uri) {
        try {
            ctx.contentResolver.releasePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: Exception) {}
    }

    private fun displayName(ctx: Context, treeUri: Uri): String {
        val docUri = DocumentsContract.buildDocumentUriUsingTree(
            treeUri, DocumentsContract.getTreeDocumentId(treeUri))
        try {
            ctx.contentResolver.query(docUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0)?.let { return it }
            }
        } catch (_: Exception) {}
        return treeUri.lastPathSegment ?: "?"
    }

    private data class Child(val id: String, val name: String, val dir: Boolean,
                             val size: Long, val mtime: Long)

    private fun children(ctx: Context, treeUri: Uri, docId: String): List<Child> {
        val out = ArrayList<Child>()
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
        try {
            ctx.contentResolver.query(uri, arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ), null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1) ?: continue
                    // Un nom vient d'ailleurs: il ne doit jamais sortir du cache.
                    if (name == "." || name == ".." || name.contains('/')) continue
                    if (name.startsWith(".")) continue
                    out.add(Child(
                        id = c.getString(0),
                        name = name,
                        dir = c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR,
                        size = if (c.isNull(3)) -1L else c.getLong(3),
                        mtime = if (c.isNull(4)) 0L else c.getLong(4),
                    ))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "children($docId): $e")
        }
        return out
    }

    /** Même règle que `isIndexedFileName` côté Dart: dernière extension, ou
     *  premier segment (préfixe Amiga, `mdat.x`). */
    private fun indexed(name: String, exts: Set<String>): Boolean {
        val lower = name.lowercase()
        val dot = lower.lastIndexOf('.')
        if (dot > 0 && dot < lower.length - 1 && lower.substring(dot + 1) in exts) return true
        val first = lower.indexOf('.')
        return first > 0 && lower.substring(0, first) in exts
    }

    /** Tout l'arbre, fichiers indexables seulement: `[{rel, size, mtime}]`. */
    fun walk(ctx: Context, treeUri: Uri, exts: Set<String>): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        fun visit(docId: String, prefix: String) {
            for (ch in children(ctx, treeUri, docId)) {
                if (ch.dir) {
                    visit(ch.id, "$prefix${ch.name}/")
                } else if (indexed(ch.name, exts)) {
                    out.add(mapOf("rel" to "$prefix${ch.name}",
                                  "size" to ch.size, "mtime" to ch.mtime))
                }
            }
        }
        visit(DocumentsContract.getTreeDocumentId(treeUri), "")
        return out
    }

    /** L'identifiant du document au chemin relatif [rel] ('' = la racine),
     *  résolu PAR NOMS. null = introuvable. */
    private fun resolve(ctx: Context, treeUri: Uri, rel: String): String? {
        var id = DocumentsContract.getTreeDocumentId(treeUri)
        for (seg in rel.split('/').filter { it.isNotEmpty() }) {
            id = children(ctx, treeUri, id).firstOrNull { it.name == seg }?.id
                ?: return null
        }
        return id
    }

    /** Le contenu d'UN dossier: `[{name, size, mtime, dir}]` — pour que Dart
     *  choisisse les voisins à mettre en scène avec les règles de l'app. */
    fun listDir(ctx: Context, treeUri: Uri, relDir: String): List<Map<String, Any>>? {
        val id = resolve(ctx, treeUri, relDir) ?: return null
        return children(ctx, treeUri, id).map {
            mapOf("name" to it.name, "size" to it.size,
                  "mtime" to it.mtime, "dir" to it.dir)
        }
    }

    /**
     * Copie [rels] (relatifs à l'arbre) sous [destRoot] en gardant leur
     * arborescence. Un fichier déjà là, de même taille et pas plus ancien, n'est
     * pas recopié. Rend les relatifs effectivement présents ensuite.
     */
    fun copy(ctx: Context, treeUri: Uri, rels: List<String>, destRoot: String): List<String> {
        val ok = ArrayList<String>()
        val root = File(destRoot).canonicalFile
        // Un dossier résolu sert à tous ses fichiers: une requête par segment,
        // pas une par fichier.
        val dirIds = HashMap<String, String?>()
        for (rel in rels) {
            val slash = rel.lastIndexOf('/')
            val relDir = if (slash < 0) "" else rel.substring(0, slash)
            val name = rel.substring(slash + 1)
            val dirId = dirIds.getOrPut(relDir) { resolve(ctx, treeUri, relDir) } ?: continue
            val ch = children(ctx, treeUri, dirId).firstOrNull { it.name == name && !it.dir }
                ?: continue
            val out = File(root, rel).canonicalFile
            if (!out.path.startsWith(root.path + File.separator)) continue
            if (out.exists() && ch.size >= 0 && out.length() == ch.size &&
                out.lastModified() >= ch.mtime) {
                ok.add(rel)
                continue
            }
            out.parentFile?.mkdirs()
            val tmp = File(out.path + ".part")
            try {
                val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, ch.id)
                ctx.contentResolver.openInputStream(docUri)?.use { input ->
                    tmp.outputStream().use { output -> input.copyTo(output) }
                } ?: continue
                if (out.exists()) out.delete()
                if (!tmp.renameTo(out)) continue
                ok.add(rel)
            } catch (e: Exception) {
                Log.w(TAG, "copie $rel: $e")
                tmp.delete()
            }
        }
        return ok
    }
}
