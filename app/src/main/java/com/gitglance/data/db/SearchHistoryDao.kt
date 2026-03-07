package com.gitglance.data.db

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface SearchHistoryDao {

    @Query("SELECT * FROM search_history ORDER BY timestamp DESC")
    fun getAllHistory(): Flow<List<SearchHistory>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(history: SearchHistory)

    @Delete
    suspend fun delete(history: SearchHistory)

    @Query("DELETE FROM search_history")
    suspend fun clearAll()
}
