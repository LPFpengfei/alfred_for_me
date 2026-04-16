import AppKit
import Foundation
import UserNotifications

// MARK: - Workflow Engine

final class WorkflowEngine: ObservableObject {
    static let shared = WorkflowEngine()

    @Published var workflows: [Workflow] = []
    @Published var workflowPlugins: [WorkflowPlugin] = []

    private let workflowsDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        workflowsDirectory = appSupport.appendingPathComponent("AlfredForMe/Workflows")

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: workflowsDirectory, withIntermediateDirectories: true)
    }

    func loadWorkflows() {
        // Load from disk
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: workflowsDirectory,
                includingPropertiesForKeys: nil
            )
        else { return }

        workflows = contents.compactMap { url -> Workflow? in
            let configURL = url.appendingPathComponent("workflow.json")
            guard let data = try? Data(contentsOf: configURL),
                var workflow = try? JSONDecoder().decode(Workflow.self, from: data)
            else {
                return nil
            }
            workflow.bundlePath = url.path
            return workflow
        }

        // Create plugin wrappers
        workflowPlugins = workflows.map { WorkflowPlugin(workflow: $0, engine: self) }
        print("⚡️ Loaded \(workflows.count) workflows")
    }

    func saveWorkflow(_ workflow: Workflow) {
        let workflowDir = workflowsDirectory.appendingPathComponent(workflow.id)
        try? FileManager.default.createDirectory(at: workflowDir, withIntermediateDirectories: true)

        let configURL = workflowDir.appendingPathComponent("workflow.json")
        if let data = try? JSONEncoder().encode(workflow) {
            try? data.write(to: configURL)
        }
    }

    func deleteWorkflow(_ workflow: Workflow) {
        let workflowDir = workflowsDirectory.appendingPathComponent(workflow.id)
        try? FileManager.default.removeItem(at: workflowDir)

        workflows.removeAll { $0.id == workflow.id }
        workflowPlugins.removeAll { $0.id == "workflow:\(workflow.id)" }
    }

    func executeWorkflow(_ workflow: Workflow, input: String) async {
        var currentInput = input

        for step in workflow.steps {
            guard let output = await executeStep(step, input: currentInput) else { break }
            currentInput = output
        }
    }

    private func executeStep(_ step: WorkflowStep, input: String) async -> String? {
        switch step.type {
        case .script:
            return await executeScript(step.config, input: input)

        case .openURL:
            if let urlTemplate = step.config["url"] {
                let url = urlTemplate.replacingOccurrences(of: "{input}", with: input)
                if let finalURL = URL(string: url) {
                    await MainActor.run {
                        _ = NSWorkspace.shared.open(finalURL)
                    }
                }
            }
            return input

        case .openFile:
            if let path = step.config["path"]?.replacingOccurrences(of: "{input}", with: input) {
                await MainActor.run {
                    _ = NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
            }
            return input

        case .copyToClipboard:
            let content =
                step.config["content"]?.replacingOccurrences(of: "{input}", with: input) ?? input
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(content, forType: .string)
            }
            return content

        case .notification:
            let title = step.config["title"] ?? "AlfredForMe"
            let message =
                step.config["message"]?.replacingOccurrences(of: "{input}", with: input) ?? input
            sendNotification(title: title, message: message)
            return input

        case .filter:
            // Filter input based on pattern
            if let pattern = step.config["pattern"] {
                let regex = try? NSRegularExpression(pattern: pattern)
                let range = NSRange(input.startIndex..., in: input)
                if let match = regex?.firstMatch(in: input, range: range) {
                    return (input as NSString).substring(with: match.range)
                }
                return nil
            }
            return input

        case .transform:
            return applyTransform(step.config, input: input)

        case .keyword:
            return input
        }
    }

    private func executeScript(_ config: [String: String], input: String) async -> String? {
        guard let script = config["script"] else { return nil }
        let language = config["language"] ?? "bash"

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let shellPath = SettingsManager.shared.shellPath

                switch language {
                case "applescript":
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                    process.arguments = ["-e", script]

                case "python", "python3":
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = ["python3", "-c", script]

                default:  // bash, zsh, sh
                    process.executableURL = URL(fileURLWithPath: shellPath)
                    process.arguments = ["-c", script]
                }

                // Pass input as environment variable
                var env = ProcessInfo.processInfo.environment
                env["WORKFLOW_INPUT"] = input
                process.environment = env

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func applyTransform(_ config: [String: String], input: String) -> String {
        guard let transform = config["type"] else { return input }

        switch transform {
        case "uppercase": return input.uppercased()
        case "lowercase": return input.lowercased()
        case "trim": return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case "replace":
            let from = config["from"] ?? ""
            let to = config["to"] ?? ""
            return input.replacingOccurrences(of: from, with: to)
        case "prefix":
            return (config["prefix"] ?? "") + input
        case "suffix":
            return input + (config["suffix"] ?? "")
        default:
            return input
        }
    }

    private func sendNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// MARK: - Workflow Plugin

final class WorkflowPlugin: SearchPlugin {
    let id: String
    let name: String
    let keyword: String?
    var isEnabled: Bool
    let priority = 50

    private let workflow: Workflow
    private weak var engine: WorkflowEngine?

    init(workflow: Workflow, engine: WorkflowEngine) {
        self.id = "workflow:\(workflow.id)"
        self.name = workflow.name
        self.keyword = workflow.keyword
        self.isEnabled = workflow.isEnabled
        self.workflow = workflow
        self.engine = engine
    }

    func canHandle(query: SearchQuery) -> Bool {
        guard let kw = keyword else { return false }
        return query.keyword?.lowercased() == kw.lowercased()
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let input = query.argument ?? ""

        return [
            SearchResult(
                id: "workflow:\(workflow.id):\(input)",
                title: workflow.name,
                subtitle: input.isEmpty
                    ? workflow.description
                    : "\(LocalizationManager.shared.t("plugin.workflow.run")) \(input)",
                icon: NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil),
                category: .workflow,
                relevanceScore: 0.85,
                plugin: id,
                userData: [
                    "workflowId": workflow.id,
                    "input": input,
                ]
            )
        ]
    }

    func execute(result: SearchResult) async {
        let input = result.userData["input"] ?? ""
        await engine?.executeWorkflow(workflow, input: input)
    }
}
