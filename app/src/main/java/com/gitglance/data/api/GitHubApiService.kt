package com.gitglance.data.api

import com.gitglance.data.model.*
import retrofit2.http.*

interface GitHubApiService {

    @GET("repos/{owner}/{repo}")
    suspend fun getRepo(
        @Path("owner") owner: String,
        @Path("repo") repo: String,
        @Header("Authorization") auth: String = ""
    ): RepoInfo

    @GET("repos/{owner}/{repo}/git/trees/{branch}")
    suspend fun getTree(
        @Path("owner") owner: String,
        @Path("repo") repo: String,
        @Path("branch") branch: String,
        @Query("recursive") recursive: Int = 1,
        @Header("Authorization") auth: String = ""
    ): TreeResponse

    @GET("repos/{owner}/{repo}/branches")
    suspend fun getBranches(
        @Path("owner") owner: String,
        @Path("repo") repo: String,
        @Header("Authorization") auth: String = ""
    ): List<Branch>

    @GET
    suspend fun getBlob(
        @Url url: String,
        @Header("Authorization") auth: String = ""
    ): BlobContent
}
