package dev.cgimenes.composespike

import android.Manifest
import android.content.Context
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    private val log = mutableStateListOf<String>()
    private var hasDir by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {}
            .launch(Manifest.permission.POST_NOTIFICATIONS)

        hasDir = Store.hasPersistedPermission(this)
        say(if (Store.tree(this) == null) "no stored uri" else "restored uri, persisted permission = $hasDir")
        Notifier.sync(this) // re-post if dismissed while app was away

        setContent {
            MaterialTheme {
                Screen(log, hasDir, onPicked = { hasDir = true }, say = ::say)
            }
        }
    }

    // Simulates "external edits (sync) detected on resume".
    override fun onResume() {
        super.onResume()
        onExternalChange = { say("running list changed from notification") }
        if (hasDir) say(runCatching { Store.stat(this) }.getOrElse { "stat FAILED: ${it.message}" })
    }

    override fun onPause() {
        super.onPause()
        onExternalChange = null
    }

    private fun say(msg: String) = log.add(0, msg)

    companion object {
        var onExternalChange: (() -> Unit)? = null
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Screen(log: List<String>, hasDir: Boolean, onPicked: () -> Unit, say: (String) -> Unit) {
    val ctx: Context = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()

    fun run(label: String, block: () -> String?) {
        scope.launch {
            val t0 = System.currentTimeMillis()
            val result = withContext(Dispatchers.IO) { runCatching(block) }
            result.onSuccess { out ->
                out?.let(say)
                say("$label ok (${System.currentTimeMillis() - t0}ms)")
            }.onFailure { say("$label FAILED: ${it.message}") }
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult say("pick cancelled")
        Store.saveTree(ctx, uri)
        onPicked()
        say("picked $uri")
    }

    Column(Modifier.statusBarsPadding().padding(8.dp)) {
        Text("SAF spike (Compose)", style = MaterialTheme.typography.titleMedium)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Button(onClick = { picker.launch(null) }) { Text("Pick dir") }
            Button(enabled = hasDir, onClick = {
                run("append") { Store.appendLine(ctx, "i ${stamp()} spike:append\n"); null }
            }) { Text("Append") }
            Button(enabled = hasDir, onClick = {
                run("rewrite") { "rewrote, ${Store.rewriteDropLast(ctx)} lines left" }
            }) { Text("Rewrite") }
            Button(enabled = hasDir, onClick = { run("read") { "content:\n${Store.read(ctx)}" } }) { Text("Read") }
            Button(enabled = hasDir, onClick = { run("list") { "files: ${Store.list(ctx)}" } }) { Text("List") }
            Button(enabled = hasDir, onClick = {
                run("start A") { Store.startEntry(ctx, "work:acme:dev"); null }
            }) { Text("Start A") }
            Button(enabled = hasDir, onClick = {
                run("start B") { Store.startEntry(ctx, "work:acme:meet"); null }
            }) { Text("Start B") }
        }
        LazyColumn { items(log) { Text(it, Modifier.padding(vertical = 4.dp)) } }
    }
}
