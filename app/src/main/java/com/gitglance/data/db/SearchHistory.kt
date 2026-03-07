package com.gitglance.data.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "search_history")
data class SearchHistory(
    @PrimaryKey val query: String,
    val owner: String,
    val repo: String,
    val branch: String,
    val timestamp: Long = System.currentTimeMillis(),
    val description: String? = null,
    val language: String? = null,
    val stars: Int = 0,
    val isPrivate: Boolean = false
)
