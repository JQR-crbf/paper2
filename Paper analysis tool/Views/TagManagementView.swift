import SwiftUI

struct TagManagementView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddTag = false
    @State private var newTagName = ""
    @State private var selectedColor: TagColor = .blue
    @State private var editingTag: Tag? = nil
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                TagSearchBar(text: $searchText, placeholder: "搜索标签...")
                    .padding(.horizontal)
                
                // 标签列表
                List {
                    ForEach(filteredTags) { tag in
                        TagRow(tag: tag) {
                            editingTag = tag
                            newTagName = tag.name
                            selectedColor = tag.color
                            showingAddTag = true
                        }
                    }
                    .onDelete(perform: deleteTags)
                }
                .listStyle(InsetGroupedListStyle())
                
                // 底部添加按钮
                Button(action: {
                    editingTag = nil
                    newTagName = ""
                    selectedColor = .blue
                    showingAddTag = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加新标签")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("标签管理")
            .sheet(isPresented: $showingAddTag) {
                AddTagView(
                    tagName: $newTagName,
                    selectedColor: $selectedColor,
                    editingTag: editingTag
                ) { name, color in
                    if let editTag = editingTag {
                        updateTag(editTag, name: name, color: color)
                    } else {
                        addNewTag(name: name, color: color)
                    }
                    showingAddTag = false
                }
            }
        }
    }
    
    // 过滤后的标签
    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return dataStore.tags
        } else {
            return dataStore.tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // 删除标签
    private func deleteTags(at offsets: IndexSet) {
        let tagsToDelete = offsets.map { filteredTags[$0] }
        dataStore.deleteTags(tagsToDelete)
    }
    
    // 更新标签
    private func updateTag(_ tag: Tag, name: String, color: TagColor) {
        guard !name.isEmpty else { return }
        var updatedTag = tag
        updatedTag.name = name
        updatedTag.color = color
        dataStore.updateTag(updatedTag)
    }
    
    // 添加新标签
    private func addNewTag(name: String, color: TagColor) {
        guard !name.isEmpty else { return }
        let newTag = Tag(name: name, color: color)
        dataStore.addTag(newTag)
    }
}

// 标签行
struct TagRow: View {
    let tag: Tag
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(tag.color.color)
                .frame(width: 12, height: 12)
            
            Text(tag.name)
                .font(.body)
            
            Spacer()
            
            if tag.count > 0 {
                Text("\(tag.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// 添加/编辑标签视图
struct AddTagView: View {
    @Binding var tagName: String
    @Binding var selectedColor: TagColor
    var editingTag: Tag?
    var onSave: (String, TagColor) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("标签名称")) {
                    TextField("标签名称", text: $tagName)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("标签颜色")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 15) {
                        ForEach(TagColor.allCases) { color in
                            ColorCircle(color: color, selected: color == selectedColor)
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical)
                }
                
                Section {
                    // 预览
                    HStack {
                        Text("预览")
                        Spacer()
                        TagView(tag: Tag(name: tagName.isEmpty ? "标签" : tagName, color: selectedColor))
                    }
                }
            }
            .navigationTitle(editingTag == nil ? "新建标签" : "编辑标签")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave(tagName, selectedColor)
                }
                .disabled(tagName.isEmpty)
            )
        }
    }
}

// 颜色选择圆圈
struct ColorCircle: View {
    let color: TagColor
    let selected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.color)
                .frame(width: 40, height: 40)
                .shadow(color: .gray.opacity(0.3), radius: 2)
            
            if selected {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: 46, height: 46)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
    }
}

// 标签视图组件
struct TagView: View {
    let tag: Tag
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Text(tag.name)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tag.backgroundColor)
            .foregroundColor(tag.color.color)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tag.color.color, lineWidth: 1)
            )
            .onTapGesture {
                if let onTap = onTap {
                    onTap()
                }
            }
    }
}

// 搜索栏
struct TagSearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// 标签选择器
struct TagSelector: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var selectedTags: [Tag]
    var showAddButton: Bool = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("标签")
                .font(.headline)
                .padding(.bottom, 5)
            
            if dataStore.tags.isEmpty {
                Text("暂无标签，请先添加标签")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(dataStore.tags) { tag in
                            TagView(tag: tag, onTap: {
                                toggleTag(tag)
                            })
                            .opacity(selectedTags.contains(tag) ? 1.0 : 0.6)
                            .overlay(
                                selectedTags.contains(tag) ?
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(tag.color.color, lineWidth: 2)
                                : nil
                            )
                        }
                    }
                }
            }
            
            if showAddButton {
                Button(action: {
                    // 打开标签管理视图
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("管理标签")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.top, 5)
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.removeAll { $0.id == tag.id }
        } else {
            selectedTags.append(tag)
        }
    }
}

// 预览
struct TagManagementView_Previews: PreviewProvider {
    static var previews: some View {
        TagManagementView()
            .environmentObject(DataStore())
    }
} 