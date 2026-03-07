package com.gitglance.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import com.gitglance.data.api.ApiClient
import com.gitglance.data.model.TreeItem
import com.gitglance.databinding.BottomSheetPreviewBinding
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Base64

class FilePreviewBottomSheet : BottomSheetDialogFragment() {

    private var _b: BottomSheetPreviewBinding? = null
    private val b get() = _b!!

    companion object {
        private const val ARG_PATH  = "path"
        private const val ARG_URL   = "url"
        private const val ARG_SIZE  = "size"
        private const val ARG_NAME  = "name"
        private const val ARG_PAT   = "pat"

        fun newInstance(item: TreeItem, pat: String): FilePreviewBottomSheet {
            return FilePreviewBottomSheet().apply {
                arguments = Bundle().apply {
                    putString(ARG_PATH, item.path)
                    putString(ARG_URL,  item.url)
                    putInt(ARG_SIZE,    item.size ?: 0)
                    putString(ARG_NAME, item.displayName)
                    putString(ARG_PAT,  pat)
                }
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _b = BottomSheetPreviewBinding.inflate(inflater, container, false)
        return b.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val name = arguments?.getString(ARG_NAME) ?: ""
        val url  = arguments?.getString(ARG_URL)  ?: ""
        val size = arguments?.getInt(ARG_SIZE)     ?: 0
        val pat  = arguments?.getString(ARG_PAT)   ?: ""

        b.tvFileName.text = name
        b.tvFileSize.text = if (size > 0) formatBytes(size) else ""

        b.btnClose.setOnClickListener { dismiss() }
        b.btnCopy.setOnClickListener { copyToClipboard() }

        // Expand to full height
        val behavior = (dialog as? com.google.android.material.bottomsheet.BottomSheetDialog)
            ?.behavior
        behavior?.state = BottomSheetBehavior.STATE_EXPANDED
        behavior?.skipCollapsed = true

        loadContent(url, pat)
    }

    private fun loadContent(url: String, pat: String) {
        b.progressBar.visibility = View.VISIBLE
        b.tvCode.text = ""

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val auth = if (pat.isNotEmpty()) "token $pat" else ""
                val blob = ApiClient.service.getBlob(url, auth)
                val content = if (blob.content != null) {
                    val b64 = blob.content.replace("\\s".toRegex(), "")
                    String(Base64.getDecoder().decode(b64), Charsets.UTF_8)
                } else "// File content unavailable"

                withContext(Dispatchers.Main) {
                    _b?.progressBar?.visibility = View.GONE
                    _b?.tvCode?.text = content
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    _b?.progressBar?.visibility = View.GONE
                    _b?.tvCode?.text = "// Error: ${e.message}"
                }
            }
        }
    }

    private fun copyToClipboard() {
        val cm = requireContext().getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("code", b.tvCode.text))
        Toast.makeText(requireContext(), "Copied to clipboard", Toast.LENGTH_SHORT).show()
    }

    private fun formatBytes(bytes: Int): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "%.1f KB".format(bytes / 1024f)
            else -> "%.1f MB".format(bytes / (1024f * 1024f))
        }
    }

    override fun onDestroyView() { super.onDestroyView(); _b = null }
}
