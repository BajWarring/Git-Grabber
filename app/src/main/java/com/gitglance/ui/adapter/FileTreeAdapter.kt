package com.gitglance.ui.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.gitglance.R
import com.gitglance.data.model.TreeItem
import com.gitglance.databinding.ItemTreeNodeBinding

class FileTreeAdapter(
    private val onFileClick: (TreeItem) -> Unit,
    private val onCheckChanged: () -> Unit
) : RecyclerView.Adapter<FileTreeAdapter.VH>() {

    data class TreeNode(
        val name: String,
        val path: String,
        val type: String,
        val depth: Int,
        val treeItem: TreeItem?,
        var isExpanded: Boolean = false,
        var isChecked: Boolean = false,
        val children: MutableList<TreeNode> = mutableListOf()
    ) {
        val isFolder get() = type == "tree"
        val extension get() = if (!isFolder) name.substringAfterLast(".", "") else ""
    }

    private val rootNodes = mutableListOf<TreeNode>()
    private val flatList = mutableListOf<TreeNode>()

    fun submitTree(items: List<TreeItem>) {
        rootNodes.clear()
        val nodeMap = mutableMapOf<String, TreeNode>()

        val sorted = items.sortedWith(compareBy({ it.type == "blob" }, { it.path.lowercase() }))

        sorted.forEach { item ->
            val parts = item.path.split("/")
            for (i in 1 until parts.size) {
                val folderPath = parts.subList(0, i).joinToString("/")
                if (!nodeMap.containsKey(folderPath)) {
                    val depth = i - 1
                    val fn = TreeNode(name = parts[i - 1], path = folderPath, type = "tree", depth = depth, treeItem = null)
                    nodeMap[folderPath] = fn
                    if (i == 1) rootNodes.add(fn)
                    else {
                        val pPath = parts.subList(0, i - 1).joinToString("/")
                        nodeMap[pPath]?.children?.add(fn)
                    }
                }
            }
            val depth = parts.size - 1
            val node = TreeNode(name = parts.last(), path = item.path, type = item.type, depth = depth, treeItem = item)
            nodeMap[item.path] = node
            if (parts.size == 1) rootNodes.add(node)
            else {
                val pPath = parts.subList(0, parts.size - 1).joinToString("/")
                nodeMap[pPath]?.children?.add(node)
            }
        }

        rebuild()
    }

    private fun rebuild() {
        flatList.clear()
        fun add(nodes: List<TreeNode>) {
            nodes.forEach { n ->
                flatList.add(n)
                if (n.isFolder && n.isExpanded) add(n.children)
            }
        }
        add(rootNodes)
        notifyDataSetChanged()
    }

    fun selectAll(checked: Boolean) {
        fun setAll(nodes: List<TreeNode>) {
            nodes.forEach { n ->
                n.isChecked = checked
                n.treeItem?.checked = checked
                if (n.isFolder) setAll(n.children)
            }
        }
        setAll(rootNodes)
        rebuild()
        onCheckChanged()
    }

    fun getSelectedItems(): List<TreeItem> {
        val result = mutableListOf<TreeItem>()
        fun collect(nodes: List<TreeNode>) {
            nodes.forEach { n ->
                if (!n.isFolder && n.isChecked && n.treeItem != null) result.add(n.treeItem)
                if (n.isFolder) collect(n.children)
            }
        }
        collect(rootNodes)
        return result
    }

    fun getSelectedCount() = getSelectedItems().size

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
        VH(ItemTreeNodeBinding.inflate(LayoutInflater.from(parent.context), parent, false))

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(flatList[position])
    override fun getItemCount() = flatList.size

    inner class VH(private val b: ItemTreeNodeBinding) : RecyclerView.ViewHolder(b.root) {

        fun bind(node: TreeNode) {
            val density = b.root.context.resources.displayMetrics.density
            val lp = b.indentSpace.layoutParams
            lp.width = (node.depth * 18 * density).toInt()
            b.indentSpace.layoutParams = lp

            b.tvName.text = node.name

            if (node.isFolder) {
                b.ivIcon.setImageResource(R.drawable.ic_folder)
                b.ivCaret.visibility = View.VISIBLE
                b.ivCaret.rotation = if (node.isExpanded) 90f else 0f
                b.tvExt.visibility = View.GONE
                b.btnPreview.visibility = View.GONE
            } else {
                b.ivIcon.setImageResource(getFileIcon(node.extension))
                b.ivCaret.visibility = View.INVISIBLE
                if (node.extension.isNotEmpty()) {
                    b.tvExt.text = ".${node.extension}"
                    b.tvExt.visibility = View.VISIBLE
                } else {
                    b.tvExt.visibility = View.GONE
                }
                b.btnPreview.visibility = View.VISIBLE
            }

            b.checkbox.setOnCheckedChangeListener(null)
            b.checkbox.isChecked = node.isChecked
            b.checkbox.setOnCheckedChangeListener { _, checked ->
                node.isChecked = checked
                if (node.isFolder) cascadeCheck(node.children, checked)
                else node.treeItem?.checked = checked
                rebuild()
                onCheckChanged()
            }

            b.root.setOnClickListener {
                if (node.isFolder) {
                    node.isExpanded = !node.isExpanded
                    rebuild()
                } else {
                    node.treeItem?.let { onFileClick(it) }
                }
            }

            b.btnPreview.setOnClickListener { node.treeItem?.let { onFileClick(it) } }
        }

        private fun cascadeCheck(nodes: List<TreeNode>, checked: Boolean) {
            nodes.forEach { n ->
                n.isChecked = checked
                n.treeItem?.checked = checked
                if (n.isFolder) cascadeCheck(n.children, checked)
            }
        }

        private fun getFileIcon(ext: String) = when (ext.lowercase()) {
            "kt", "java" -> R.drawable.ic_file_kotlin
            "py" -> R.drawable.ic_file_code
            "js", "ts", "jsx", "tsx" -> R.drawable.ic_file_js
            "xml", "html", "htm" -> R.drawable.ic_file_xml
            "json", "yaml", "yml", "toml" -> R.drawable.ic_file_config
            "md", "txt", "rst" -> R.drawable.ic_file_text
            "png", "jpg", "jpeg", "gif", "svg", "webp", "ico" -> R.drawable.ic_file_image
            "gradle", "kts" -> R.drawable.ic_file_config
            "sh", "bash", "zsh" -> R.drawable.ic_file_code
            "css", "scss", "less" -> R.drawable.ic_file_code
            "dart", "swift", "go", "rs", "cpp", "c", "h" -> R.drawable.ic_file_code
            else -> R.drawable.ic_file
        }
    }
}
