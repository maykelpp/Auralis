package app.auralis.auralis_player

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "app.auralis/saf"
    private val requestTree = 7412
    private var pendingResult: MethodChannel.Result? = null
    private val extensions = setOf("mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "wma")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "selectMusicFolder" -> {
                        if (pendingResult != null) {
                            result.error("BUSY", "Ya hay un selector abierto", null)
                        } else {
                            pendingResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            }
                            startActivityForResult(intent, requestTree)
                        }
                    }
                    "hasMusicFolder" -> result.success(getPreferences(MODE_PRIVATE).contains("music_tree"))
                    "syncMusicFolder" -> {
                        val saved = getPreferences(MODE_PRIVATE).getString("music_tree", null)
                        if (saved == null) result.success(emptyList<Map<String, String>>())
                        else try { result.success(importTree(Uri.parse(saved))) }
                        catch (e: Exception) { result.error("SAF_SYNC", e.message, null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android API, required for Flutter activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestTree) return
        val callback = pendingResult
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback?.success(emptyList<Map<String, String>>())
            return
        }
        val tree = data.data!!
        try {
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(tree, flags)
            getPreferences(MODE_PRIVATE).edit().putString("music_tree", tree.toString()).apply()
            callback?.success(importTree(tree))
        } catch (e: Exception) {
            callback?.error("SAF_IMPORT", e.message, null)
        }
    }

    private fun importTree(tree: Uri): List<Map<String, String>> {
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val output = File(filesDir, "auralis_music").apply { mkdirs() }
        val imported = mutableListOf<Map<String, String>>()
        val stack = ArrayDeque<String>()
        stack.add(rootId)
        var visited = 0
        while (stack.isNotEmpty() && visited < 5000 && imported.size < 2000) {
            val parentId = stack.removeLast()
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )
            val cursor: Cursor = contentResolver.query(childrenUri, projection, null, null, null) ?: continue
            cursor.use {
                val idCol = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameCol = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeCol = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
                while (it.moveToNext() && visited++ < 5000 && imported.size < 2000) {
                    val id = it.getString(idCol)
                    val name = it.getString(nameCol) ?: "audio"
                    val mime = it.getString(mimeCol)
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        stack.add(id)
                        continue
                    }
                    val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
                    if (ext !in extensions) continue
                    val source = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    val safe = name.replace(Regex("[^A-Za-z0-9._ -]"), "_").take(120)
                    val stableName = "${id.hashCode().toUInt().toString(16)}_$safe"
                    val target = File(output, stableName)
                    try {
                        if (!target.exists()) {
                            contentResolver.openInputStream(source)?.use { input ->
                                FileOutputStream(target).use { dest -> input.copyTo(dest) }
                            } ?: continue
                        }
                        imported.add(mapOf("path" to target.absolutePath,
                            "title" to name.substringBeforeLast('.', name), "artist" to "Artista desconocido"))
                    } catch (_: Exception) {
                        target.delete()
                    }
                }
            }
        }
        return imported
    }
}
