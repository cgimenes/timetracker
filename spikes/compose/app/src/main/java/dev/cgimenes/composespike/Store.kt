package dev.cgimenes.composespike

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.edit
import androidx.documentfile.provider.DocumentFile
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private const val FILE_NAME = "spike.timeclock"
private const val PREFS = "spike"
private const val TREE_URI = "treeUri"
private const val RUNNING = "running" // lines of "epochMs|account"

data class Running(val start: Long, val account: String)

fun stamp(ms: Long = System.currentTimeMillis()): String =
    SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).format(Date(ms))

object Store {
    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Stores the picked tree and keeps access across restarts. */
    fun saveTree(ctx: Context, uri: Uri) {
        ctx.contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        prefs(ctx).edit { putString(TREE_URI, uri.toString()) }
    }

    fun tree(ctx: Context): Uri? = prefs(ctx).getString(TREE_URI, null)?.let(Uri::parse)

    fun hasPersistedPermission(ctx: Context): Boolean {
        val uri = tree(ctx) ?: return false
        return ctx.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
    }

    private fun dir(ctx: Context): DocumentFile =
        DocumentFile.fromTreeUri(ctx, tree(ctx) ?: error("no directory")) ?: error("bad tree uri")

    private fun file(ctx: Context): DocumentFile? = dir(ctx).findFile(FILE_NAME)

    /** octet-stream: with text/plain the provider appends ".txt". */
    private fun fileOrCreate(ctx: Context): DocumentFile =
        file(ctx) ?: dir(ctx).createFile("application/octet-stream", FILE_NAME)
        ?: error("cannot create file")

    @Synchronized
    fun appendLine(ctx: Context, line: String) {
        val f = fileOrCreate(ctx)
        ctx.contentResolver.openOutputStream(f.uri, "wa")!!.use { it.write(line.toByteArray()) }
    }

    fun read(ctx: Context): String {
        val f = file(ctx) ?: error("file missing")
        return ctx.contentResolver.openInputStream(f.uri)!!.use { it.readBytes().decodeToString() }
    }

    /** Drops the last line (the "remove entry" path). Returns lines left. */
    @Synchronized
    fun rewriteDropLast(ctx: Context): Int {
        val f = file(ctx) ?: error("file missing")
        val lines = read(ctx).lines().filter { it.isNotEmpty() }.dropLast(1)
        val out = if (lines.isEmpty()) "" else lines.joinToString("\n") + "\n"
        ctx.contentResolver.openOutputStream(f.uri, "wt")!!.use { it.write(out.toByteArray()) }
        return lines.size
    }

    fun list(ctx: Context): String =
        dir(ctx).listFiles().joinToString { "${it.name}(${it.length()}b)" }

    fun stat(ctx: Context): String {
        val f = file(ctx) ?: return "stat: missing"
        return "stat: ${f.length()}b mtime=${stamp(f.lastModified())}"
    }

    fun running(ctx: Context): List<Running> =
        (prefs(ctx).getString(RUNNING, "") ?: "")
            .lines()
            .filter { it.isNotEmpty() }
            .map { Running(it.substringBefore('|').toLong(), it.substringAfter('|')) }
            .sortedBy { it.start }

    private fun saveRunning(ctx: Context, list: List<Running>) =
        prefs(ctx).edit { putString(RUNNING, list.joinToString("\n") { "${it.start}|${it.account}" }) }

    @Synchronized
    fun startEntry(ctx: Context, account: String) {
        val now = System.currentTimeMillis()
        appendLine(ctx, "i ${stamp(now)} $account\n")
        saveRunning(ctx, running(ctx) + Running(now, account))
        Notifier.sync(ctx)
    }

    @Synchronized
    fun stopEntry(ctx: Context, account: String) {
        val list = running(ctx).toMutableList()
        val idx = list.indexOfFirst { it.account == account }
        if (idx < 0) return
        appendLine(ctx, "o ${stamp()} $account\n")
        list.removeAt(idx)
        saveRunning(ctx, list)
        Notifier.sync(ctx)
    }
}
