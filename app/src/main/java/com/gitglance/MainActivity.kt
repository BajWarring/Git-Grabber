package com.gitglance

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.gitglance.data.db.AppDatabase
import com.gitglance.databinding.ActivityMainBinding
import com.gitglance.ui.adapter.SearchHistoryAdapter
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var b: ActivityMainBinding
    private lateinit var historyAdapter: SearchHistoryAdapter
    private val db by lazy { AppDatabase.getInstance(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)

        setupAdapter()
        setupSearch()
        observeHistory()
    }

    private fun setupAdapter() {
        historyAdapter = SearchHistoryAdapter(
            onItemClick = { h -> openRepo(h.owner, h.repo) },
            onDeleteClick = { h -> lifecycleScope.launch { db.searchHistoryDao().delete(h) } }
        )
        b.rvHistory.layoutManager = LinearLayoutManager(this)
        b.rvHistory.adapter = historyAdapter
    }

    private fun setupSearch() {
        b.etSearch.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(s: Editable?) {
                val q = s?.toString()?.trim() ?: ""
                filterHistory(q)
            }
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
        })

        b.etSearch.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH) { performSearch(); true } else false
        }

        b.btnSearch.setOnClickListener { performSearch() }

        b.btnPat.setOnClickListener {
            if (b.patWrapper.visibility == View.VISIBLE) {
                b.patWrapper.visibility = View.GONE
            } else {
                b.patWrapper.visibility = View.VISIBLE
                b.etPat.requestFocus()
            }
        }

        b.btnClearHistory.setOnClickListener {
            lifecycleScope.launch { db.searchHistoryDao().clearAll() }
        }
    }

    private var allHistory = listOf<com.gitglance.data.db.SearchHistory>()

    private fun filterHistory(query: String) {
        val filtered = if (query.isEmpty()) allHistory
        else allHistory.filter {
            it.query.contains(query, true) ||
            it.repo.contains(query, true) ||
            it.owner.contains(query, true) ||
            it.description?.contains(query, true) == true
        }
        historyAdapter.submitList(filtered)
        b.tvNoResults.visibility = if (filtered.isEmpty() && query.isNotEmpty()) View.VISIBLE else View.GONE
    }

    private fun observeHistory() {
        lifecycleScope.launch {
            db.searchHistoryDao().getAllHistory().collectLatest { history ->
                allHistory = history
                filterHistory(b.etSearch.text?.toString() ?: "")
                val empty = history.isEmpty()
                b.emptyState.visibility = if (empty) View.VISIBLE else View.GONE
                b.rvHistory.visibility  = if (empty) View.GONE else View.VISIBLE
                b.historyHeader.visibility = if (empty) View.GONE else View.VISIBLE
            }
        }
    }

    private fun performSearch() {
        val input = b.etSearch.text.toString().trim()
        if (input.isEmpty()) return

        val owner: String
        val repo: String

        if (input.contains("github.com")) {
            val m = Regex("github\\.com/([^/\\?#]+)/([^/\\?#]+)").find(input)
                ?: run { b.etSearch.error = "Invalid GitHub URL"; return }
            owner = m.groupValues[1]
            repo  = m.groupValues[2].replace(Regex("\\.git$"), "").replace(Regex("[\\?#].*$"), "")
        } else if (input.contains("/")) {
            val parts = input.split("/")
            if (parts.size < 2) { b.etSearch.error = "Use owner/repo"; return }
            owner = parts[0].trim()
            repo  = parts[1].trim()
        } else {
            b.etSearch.error = "Use owner/repo or a full GitHub URL"
            return
        }

        hideKeyboard()
        openRepo(owner, repo)
    }

    private fun openRepo(owner: String, repo: String) {
        val intent = Intent(this, RepoExplorerActivity::class.java).apply {
            putExtra("owner", owner)
            putExtra("repo",  repo)
            putExtra("pat",   b.etPat.text.toString().trim())
        }
        startActivity(intent)
    }

    private fun hideKeyboard() {
        val imm = getSystemService(InputMethodManager::class.java)
        imm.hideSoftInputFromWindow(b.etSearch.windowToken, 0)
    }
}
