import SwiftUI

@available(macOS 12.3, *)
struct MemoriesView: View {
    @ObservedObject var service: AppService
    @State private var searchText: String = ""
    
    var filteredMemories: [Memory] {
        if searchText.isEmpty {
            return service.memories
        }
        return service.memories.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Memories")
                    .font(.largeTitle.bold())
                Text("Browse and search your captured memories")
                    .foregroundColor(.secondary)
            }
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search memories...", text: $searchText)
                
                Button("Search") {}
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Memories List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredMemories) { memory in
                        MemoryCard(memory: memory)
                    }
                }
            }
        }
        .padding(32)
    }
}
