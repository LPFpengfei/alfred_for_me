import AppKit
import Combine

// MARK: - Search Plugin Protocol

protocol SearchPlugin: AnyObject {
    /// Unique identifier for this plugin
    var id: String { get }

    /// Display name
    var name: String { get }

    /// Plugin keyword (optional). If set, plugin only activates when query starts with keyword
    var keyword: String? { get }

    /// Whether this plugin is enabled
    var isEnabled: Bool { get set }

    /// Priority for result ordering (higher = shown first)
    var priority: Int { get }

    /// Whether this plugin handles the given query
    func canHandle(query: SearchQuery) -> Bool

    /// Perform search and return results
    func search(query: SearchQuery) async -> [SearchResult]

    /// Execute the primary action for a result
    func execute(result: SearchResult) async

    /// Get available actions for a result (for action panel)
    func actions(for result: SearchResult) -> [ResultAction]

    /// Called when plugin is loaded
    func initialize()

    /// Called when plugin is unloaded
    func cleanup()
}

// MARK: - Default Implementations

extension SearchPlugin {
    var keyword: String? { nil }
    var priority: Int { 50 }

    func canHandle(query: SearchQuery) -> Bool {
        if let kw = keyword {
            return query.keyword?.lowercased() == kw.lowercased()
        }
        return !query.raw.isEmpty
    }

    func actions(for result: SearchResult) -> [ResultAction] { [] }
    func initialize() {}
    func cleanup() {}
}

// MARK: - Plugin Manager

final class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published private(set) var plugins: [SearchPlugin] = []
    private var pluginMap: [String: SearchPlugin] = [:]

    private init() {}

    func register(plugin: SearchPlugin) {
        guard pluginMap[plugin.id] == nil else {
            print("⚠️ Plugin '\(plugin.id)' already registered, skipping")
            return
        }

        plugin.initialize()
        plugins.append(plugin)
        pluginMap[plugin.id] = plugin
        print("✅ Registered plugin: \(plugin.name) (\(plugin.id))")
    }

    func unregister(pluginId: String) {
        if let plugin = pluginMap[pluginId] {
            plugin.cleanup()
            plugins.removeAll { $0.id == pluginId }
            pluginMap.removeValue(forKey: pluginId)
        }
    }

    func plugin(for id: String) -> SearchPlugin? {
        pluginMap[id]
    }

    func enabledPlugins() -> [SearchPlugin] {
        plugins.filter { $0.isEnabled }
    }

    func plugins(for query: SearchQuery) -> [SearchPlugin] {
        enabledPlugins()
            .filter { $0.canHandle(query: query) }
            .sorted { $0.priority > $1.priority }
    }
}
