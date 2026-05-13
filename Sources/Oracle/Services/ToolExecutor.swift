import Foundation
import CoreServices

enum ToolExecutionError: Error, LocalizedError {
    case unknownTool(String)
    case invalidArguments(String)
    case commandFailed(String)
    case appleScriptFailed(String)
    case webRequestFailed(String)
    case fileAccessDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Unknown tool: \(name)"
        case .invalidArguments(let msg):
            return "Invalid arguments: \(msg)"
        case .commandFailed(let msg):
            return "Command failed: \(msg)"
        case .appleScriptFailed(let msg):
            return "AppleScript failed: \(msg)"
        case .webRequestFailed(let msg):
            return "Web request failed: \(msg)"
        case .fileAccessDenied(let msg):
            return "File access denied: \(msg)"
        }
    }
}

struct ToolExecutor {
    private let destructivePatterns = [
        "rm ", "rm\t", "rm\n",
        "mv ", "mv\t",
        "dd ", "dd\t",
        "mkfs", "format",
        "> /", ">~/",
        "sudo", "chmod -R", "chown -R",
        "curl.*|.*sh", "wget.*|.*sh"
    ]
    
    func requiresConfirmation(toolCall: ToolCall) -> Bool {
        guard toolCall.name == "execute_shell" else { return false }
        
        guard let argsData = toolCall.arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: String],
              let command = args["command"] else {
            return false
        }
        
        let lower = command.lowercased()
        return destructivePatterns.contains { lower.contains($0) }
    }
    
    func execute(toolCall: ToolCall) async throws -> ToolResult {
        guard let argsData = toolCall.arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw ToolExecutionError.invalidArguments("Could not parse arguments")
        }
        
        switch toolCall.name {
        case "web_search":
            guard let query = args["query"] as? String else {
                throw ToolExecutionError.invalidArguments("Missing 'query'")
            }
            let result = try await webSearch(query: query)
            return ToolResult(toolCallId: toolCall.id, content: result)
            
        case "fetch_url":
            guard let urlString = args["url"] as? String,
                  let url = URL(string: urlString) else {
                throw ToolExecutionError.invalidArguments("Missing or invalid 'url'")
            }
            let result = try await fetchURL(url: url)
            return ToolResult(toolCallId: toolCall.id, content: result)
            
        case "execute_shell":
            guard let command = args["command"] as? String else {
                throw ToolExecutionError.invalidArguments("Missing 'command'")
            }
            let result = try await executeShell(command: command)
            return ToolResult(toolCallId: toolCall.id, content: result)
            
        case "run_applescript":
            guard let script = args["script"] as? String else {
                throw ToolExecutionError.invalidArguments("Missing 'script'")
            }
            let result = try await runAppleScript(script: script)
            return ToolResult(toolCallId: toolCall.id, content: result)
            
        case "list_directory":
            guard let path = args["path"] as? String else {
                throw ToolExecutionError.invalidArguments("Missing 'path'")
            }
            let result = try listDirectory(path: path)
            return ToolResult(toolCallId: toolCall.id, content: result)
            
        case "read_file":
            guard let path = args["path"] as? String else {
                throw ToolExecutionError.invalidArguments("Missing 'path'")
            }
            let result = try readFile(path: path)
            return ToolResult(toolCallId: toolCall.id, content: result)
            
        default:
            throw ToolExecutionError.unknownTool(toolCall.name)
        }
    }
    
    // MARK: - Web Search
    
    private func webSearch(query: String) async throws -> String {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)")!
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ToolExecutionError.webRequestFailed("Failed to fetch search results")
        }
        
        let html = String(data: data, encoding: .utf8) ?? ""
        
        // Parse DuckDuckGo HTML results
        var results: [String] = []
        let resultPattern = #"<a[^>]*class="result__a"[^>]*>(.*?)</a>.*?<a[^>]*class="result__snippet"[^>]*>(.*?)</a>"#
        
        if let regex = try? NSRegularExpression(pattern: resultPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            for match in matches.prefix(5) {
                if let titleRange = Range(match.range(at: 1), in: html),
                   let snippetRange = Range(match.range(at: 2), in: html) {
                    let title = String(html[titleRange]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    let snippet = String(html[snippetRange]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    results.append("• \(title): \(snippet)")
                }
            }
        }
        
        if results.isEmpty {
            // Fallback to simpler parsing
            let simplePattern = #"<a[^>]*class="result__a"[^>]*>(.*?)</a>"#
            if let regex = try? NSRegularExpression(pattern: simplePattern, options: []) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                for match in matches.prefix(5) {
                    if let range = Range(match.range(at: 1), in: html) {
                        let title = String(html[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        results.append("• \(title)")
                    }
                }
            }
        }
        
        if results.isEmpty {
            return "No search results found. The search service may be temporarily unavailable."
        }
        
        return "Search results for '\(query)':\n\n" + results.joined(separator: "\n")
    }
    
    // MARK: - Fetch URL
    
    private func fetchURL(url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ToolExecutionError.webRequestFailed("Failed to fetch URL")
        }
        
        let html = String(data: data, encoding: .utf8) ?? ""
        // Strip HTML tags
        let text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let maxLength = 8000
        let truncated = text.count > maxLength ? String(text.prefix(maxLength)) + "\n\n[Content truncated...]" : text
        return truncated
    }
    
    // MARK: - Shell
    
    private func executeShell(command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                
                if proc.terminationStatus != 0 {
                    let errorOutput = stderr.isEmpty ? stdout : stderr
                    continuation.resume(throwing: ToolExecutionError.commandFailed("Exit code \(proc.terminationStatus): \(errorOutput)"))
                } else {
                    let output = stdout + stderr
                    continuation.resume(returning: output.isEmpty ? "Command executed successfully (no output)." : output)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ToolExecutionError.commandFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - AppleScript

    private func checkAppleEventsPermission() -> Bool {
        // Check automation permission for System Events (most common AppleScript target)
        var targetDesc = AEDesc()
        let bundleID = "com.apple.systemevents"
        let status = AECreateDesc(
            typeApplicationBundleID,
            bundleID,
            bundleID.utf8.count,
            &targetDesc
        )
        guard status == noErr else { return false }
        defer { AEDisposeDesc(&targetDesc) }

        let permission = AEDeterminePermissionToAutomateTarget(
            &targetDesc,
            typeWildCard,
            typeWildCard,
            false // Don't prompt — just check current status
        )
        return permission == noErr || permission == procNotFound
    }

    private func runAppleScript(script: String) async throws -> String {
        #if os(macOS)
        guard checkAppleEventsPermission() else {
            throw ToolExecutionError.appleScriptFailed(
                "Oracle does not have permission to control other apps via AppleScript. " +
                "Please enable it in System Settings > Privacy & Security > Automation."
            )
        }

        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let errorInfo = errorInfo {
            let errorMsg = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            throw ToolExecutionError.appleScriptFailed(errorMsg)
        }

        return result?.stringValue ?? "AppleScript executed successfully."
        #else
        throw ToolExecutionError.appleScriptFailed("AppleScript is only available on macOS")
        #endif
    }
    
    // MARK: - File System
    
    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return path.replacingCharacters(in: path.startIndex...path.startIndex, with: FileManager.default.homeDirectoryForCurrentUser.path)
        }
        return path
    }
    
    private func listDirectory(path: String) throws -> String {
        let resolvedPath = resolvePath(path)
        let url = URL(fileURLWithPath: resolvedPath)
        
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
        
        var items: [String] = []
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let prefix = isDir ? "📁" : "📄"
            items.append("\(prefix) \(item.lastPathComponent)")
        }
        
        return items.sorted().joined(separator: "\n")
    }
    
    private func readFile(path: String) throws -> String {
        let resolvedPath = resolvePath(path)
        let url = URL(fileURLWithPath: resolvedPath)
        
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw ToolExecutionError.fileAccessDenied("File does not exist: \(path)")
        }
        
        let data = try Data(contentsOf: url)
        
        // Limit file size
        let maxBytes = 100_000
        let readData = data.count > maxBytes ? data.prefix(maxBytes) : data
        
        guard let text = String(data: readData, encoding: .utf8) else {
            throw ToolExecutionError.fileAccessDenied("Could not decode file as UTF-8 text")
        }
        
        let result = data.count > maxBytes ? text + "\n\n[File truncated...]" : text
        return result
    }
}
