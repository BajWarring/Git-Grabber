package com.gitglance

import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.gitglance.data.api.ApiClient
import com.gitglance.data.db.AppDatabase
import com.gitglance.data.db.SearchHistory
import com.gitglance.data.model.TreeItem
import com.gitglance.databinding.ActivityRepoExplorerBinding
import com.gitglance.ui.FilePreviewBottomSheet
import com.gitglance.ui.adapter.FileTreeAdapter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.Base64
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class RepoExplorerActivity : AppCompatActivity() {

    private lateinit var b: ActivityRepoExplorerBinding
    private lateinit var treeAdapter: FileTreeAdapter
    private val db by lazy { AppDatabase.getInstance(this) }

    private var owner = ""
    private var repo  = ""
    private var pat   = ""
    private var currentBranch = ""
    private var branchList = listOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityRepoExplorerBinding.inflate(layoutInflater)
        setContentView(b.root)

        owner = intent.getStringExtra("owner") ?: ""
        repo  = intent.getStringExtra("repo")  ?: ""
        pat   = intent.getStringExtra("pat")   ?: ""

        setSupportActionBar(b.toolbar)
        supportActionBar?.apply { setDisplayHomeAsUpEnabled(true); title = "$owner/$repo" }
        b.toolbar.setNavigationOnClickListener { onBackPressedDispatcher.onBackPressed() }

        treeAdapter = FileTreeAdapter(
            onFileClick = { item ->
                FilePreviewBottomSheet.newInstance(item, pat).show(supportFragmentManager, "preview")
            },
            onCheckChanged = { updateCounts() }
        )
        b.rvTree.layoutManager = LinearLayoutManager(this)
        b.rvTree.adapter = treeAdapter

        b.btnSelectAll.setOnClickListener  { treeAdapter.selectAll(true);  updateCounts() }
        b.btnSelectNone.setOnClickListener { treeAdapter.selectAll(false); updateCounts() }
        b.btnZip.setOnClickListener  { exportZip() }
        b.btnTxt.setOnClickListener  { exportTxt() }

        loadRepo()
    }

    private fun auth() = if (pat.isNotEmpty()) "token $pat" else ""

    private fun loadRepo() {
        setLoading(true)
        lifecycleScope.launch {
            try {
                val info = withContext(Dispatchers.IO) { ApiClient.service.getRepo(owner, repo, auth()) }
                currentBranch = info.defaultBranch

                db.searchHistoryDao().insert(SearchHistory(
                    query = "$owner/$repo", owner = owner, repo = repo,
                    branch = info.defaultBranch, description = info.description,
                    language = info.language, stars = info.stars, isPrivate = info.private
                ))

                loadBranches()
                loadTree(info.defaultBranch)
            } catch (e: Exception) {
                setLoading(false)
                showError(e.message ?: "Failed to load repo")
            }
        }
    }

    private suspend fun loadBranches() {
        try {
            val branches = withContext(Dispatchers.IO) { ApiClient.service.getBranches(owner, repo, auth()) }
            branchList = branches.map { it.name }
            val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, branchList)
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            b.spinnerBranch.adapter = adapter
            val idx = branchList.indexOf(currentBranch)
            if (idx >= 0) b.spinnerBranch.setSelection(idx)
            b.spinnerBranch.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p: AdapterView<*>?, v: View?, pos: Int, id: Long) {
                    val sel = branchList[pos]
                    if (sel != currentBranch) {
                        currentBranch = sel
                        lifecycleScope.launch { loadTree(sel) }
                    }
                }
                override fun onNothingSelected(parent: AdapterView<*>?) {}
            }
        } catch (_: Exception) {}
    }

    private suspend fun loadTree(branch: String) {
        setLoading(true)
        try {
            val res = withContext(Dispatchers.IO) {
                ApiClient.service.getTree(owner, repo, branch, 1, auth())
            }
            treeAdapter.submitTree(res.tree)
            val count = res.tree.count { it.type == "blob" }
            b.tvFileCount.text = "$count files"
            updateCounts()
            setLoading(false)
            if (res.truncated) Toast.makeText(this, "Large repo — tree truncated", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            setLoading(false)
            showError(e.message ?: "Failed to load tree")
        }
    }

    private fun updateCounts() {
        val count = treeAdapter.getSelectedCount()
        b.btnZip.text = if (count > 0) ".zip ($count)" else ".zip"
        b.btnTxt.text = if (count > 0) ".txt ($count)" else ".txt"
    }

    private fun exportZip() {
        val selected = treeAdapter.getSelectedItems()
        if (selected.isEmpty()) { Toast.makeText(this, "No files selected", Toast.LENGTH_SHORT).show(); return }
        setExporting(true)
        lifecycleScope.launch {
            try {
                val baos = ByteArrayOutputStream()
                val zos  = ZipOutputStream(baos)
                selected.forEachIndexed { i, item ->
                    val content = fetchContent(item)
                    zos.putNextEntry(ZipEntry(item.path))
                    zos.write(content.toByteArray())
                    zos.closeEntry()
                    withContext(Dispatchers.Main) {
                        b.exportProgress.progress = ((i + 1) * 100 / selected.size)
                    }
                }
                zos.close()
                saveFile(baos.toByteArray(), "$repo.zip", "application/zip")
                setExporting(false)
                Toast.makeText(this@RepoExplorerActivity, "Saved $repo.zip to Downloads", Toast.LENGTH_LONG).show()
            } catch (e: Exception) {
                setExporting(false)
                showError("Export failed: ${e.message}")
            }
        }
    }

    private fun exportTxt() {
        val selected = treeAdapter.getSelectedItems()
        if (selected.isEmpty()) { Toast.makeText(this, "No files selected", Toast.LENGTH_SHORT).show(); return }
        setExporting(true)
        lifecycleScope.launch {
            try {
                val sb  = StringBuilder()
                val sep = "=".repeat(60)
                sb.appendLine("FILE STRUCTURE").appendLine(sep)
                selected.forEach { sb.appendLine(it.path) }
                sb.appendLine()
                selected.forEachIndexed { i, item ->
                    val content = fetchContent(item)
                    sb.appendLine(sep).appendLine("FILE: ${item.path}").appendLine(sep)
                    sb.appendLine().appendLine(content).appendLine()
                    withContext(Dispatchers.Main) {
                        b.exportProgress.progress = ((i + 1) * 100 / selected.size)
                    }
                }
                saveFile(sb.toString().toByteArray(), "$repo.txt", "text/plain")
                setExporting(false)
                Toast.makeText(this@RepoExplorerActivity, "Saved $repo.txt to Downloads", Toast.LENGTH_LONG).show()
            } catch (e: Exception) {
                setExporting(false)
                showError("Export failed: ${e.message}")
            }
        }
    }

    private suspend fun fetchContent(item: TreeItem): String = withContext(Dispatchers.IO) {
        try {
            val blob = ApiClient.service.getBlob(item.url, auth())
            if (blob.content == null) return@withContext "// Empty"
            val b64 = blob.content.replace("\\s".toRegex(), "")
            String(Base64.getDecoder().decode(b64), Charsets.UTF_8)
        } catch (e: Exception) { "// Error: ${e.message}" }
    }

    private fun saveFile(data: ByteArray, name: String, mime: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cv = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv)!!
            contentResolver.openOutputStream(uri)?.use { it.write(data) }
            cv.clear(); cv.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, cv, null, null)
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val f = java.io.File(dir, name)
            f.writeBytes(data)
        }
    }

    private fun setLoading(show: Boolean) {
        b.progressLoading.visibility = if (show) View.VISIBLE else View.GONE
        b.rvTree.visibility          = if (show) View.GONE    else View.VISIBLE
    }

    private fun setExporting(show: Boolean) {
        b.exportLayout.visibility    = if (show) View.VISIBLE else View.GONE
        b.exportProgress.progress    = 0
    }

    private fun showError(msg: String) =
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
}
