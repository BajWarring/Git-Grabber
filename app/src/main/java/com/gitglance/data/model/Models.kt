package com.gitglance.data.model

import com.google.gson.annotations.SerializedName

data class RepoInfo(
    val name: String,
    @SerializedName("default_branch") val defaultBranch: String,
    val description: String?,
    @SerializedName("stargazers_count") val stars: Int = 0,
    @SerializedName("forks_count") val forks: Int = 0,
    val language: String?,
    val private: Boolean = false
)

data class TreeResponse(
    val tree: List<TreeItem>,
    val truncated: Boolean
)

data class TreeItem(
    val path: String,
    val type: String,   // "blob" or "tree"
    val sha: String,
    val size: Int?,
    val url: String
) {
    var checked: Boolean = false
    val displayName: String get() = path.split("/").last()
}

data class BlobContent(
    val content: String?,
    val encoding: String?
)

data class Branch(
    val name: String
)
