package com.gitglance.ui.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.gitglance.data.db.SearchHistory
import com.gitglance.databinding.ItemSearchHistoryBinding
import java.text.SimpleDateFormat
import java.util.*

class SearchHistoryAdapter(
    private val onItemClick: (SearchHistory) -> Unit,
    private val onDeleteClick: (SearchHistory) -> Unit
) : ListAdapter<SearchHistory, SearchHistoryAdapter.VH>(DIFF) {

    companion object {
        val DIFF = object : DiffUtil.ItemCallback<SearchHistory>() {
            override fun areItemsTheSame(a: SearchHistory, b: SearchHistory) = a.query == b.query
            override fun areContentsTheSame(a: SearchHistory, b: SearchHistory) = a == b
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
        VH(ItemSearchHistoryBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(getItem(position))

    inner class VH(private val b: ItemSearchHistoryBinding) : RecyclerView.ViewHolder(b.root) {
        fun bind(h: SearchHistory) {
            b.tvRepo.text = h.repo
            b.tvOwner.text = h.owner
            b.tvDescription.text = h.description ?: ""
            b.tvDescription.visibility = if (h.description.isNullOrEmpty()) android.view.View.GONE else android.view.View.VISIBLE

            if (!h.language.isNullOrEmpty()) {
                b.tvLanguage.text = h.language
                b.tvLanguage.visibility = android.view.View.VISIBLE
            } else {
                b.tvLanguage.visibility = android.view.View.GONE
            }

            if (h.stars > 0) {
                b.tvStars.text = formatStars(h.stars)
                b.tvStars.visibility = android.view.View.VISIBLE
            } else {
                b.tvStars.visibility = android.view.View.GONE
            }

            b.tvTime.text = timeAgo(h.timestamp)
            b.ivPrivate.visibility = if (h.isPrivate) android.view.View.VISIBLE else android.view.View.GONE

            b.root.setOnClickListener { onItemClick(h) }
            b.btnDelete.setOnClickListener { onDeleteClick(h) }
        }

        private fun formatStars(count: Int): String = when {
            count >= 1000 -> "%.1fk".format(count / 1000f).trimEnd('0').trimEnd('.') + "k ★"
            else -> "$count ★"
        }

        private fun timeAgo(ts: Long): String {
            val diff = System.currentTimeMillis() - ts
            val mins = diff / 60_000
            val hours = diff / 3_600_000
            val days = diff / 86_400_000
            return when {
                mins < 1 -> "just now"
                mins < 60 -> "${mins}m ago"
                hours < 24 -> "${hours}h ago"
                days < 30 -> "${days}d ago"
                else -> SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(ts))
            }
        }
    }
}
