import Foundation

struct ToolDefinition: Codable {
    var type: String = "function"
    let function: FunctionDefinition
    
    struct FunctionDefinition: Codable {
        let name: String
        let description: String
        let parameters: ParameterSchema
    }
    
    struct ParameterSchema: Codable {
        let type: String
        let properties: [String: PropertySchema]
        let required: [String]
    }
    
    struct PropertySchema: Codable {
        let type: String
        let description: String
    }
}

extension ToolDefinition {
    static let allTools: [ToolDefinition] = [
        webSearchTool,
        fetchURLTool,
        executeShellTool,
        runAppleScriptTool,
        listDirectoryTool,
        readFileTool
    ]
    
    static let webSearchTool = ToolDefinition(
        function: .init(
            name: "web_search",
            description: "Search the web for information using DuckDuckGo. Returns search results with titles and snippets.",
            parameters: .init(
                type: "object",
                properties: [
                    "query": .init(type: "string", description: "The search query")
                ],
                required: ["query"]
            )
        )
    )
    
    static let fetchURLTool = ToolDefinition(
        function: .init(
            name: "fetch_url",
            description: "Fetch and extract text content from a web URL.",
            parameters: .init(
                type: "object",
                properties: [
                    "url": .init(type: "string", description: "The URL to fetch")
                ],
                required: ["url"]
            )
        )
    )
    
    static let executeShellTool = ToolDefinition(
        function: .init(
            name: "execute_shell",
            description: "Execute a shell command on the Mac. Use with caution. Destructive commands (rm, mv, dd, etc.) require user confirmation.",
            parameters: .init(
                type: "object",
                properties: [
                    "command": .init(type: "string", description: "The shell command to execute"),
                    "explanation": .init(type: "string", description: "Brief explanation of what this command does and why")
                ],
                required: ["command", "explanation"]
            )
        )
    )
    
    static let runAppleScriptTool = ToolDefinition(
        function: .init(
            name: "run_applescript",
            description: "Execute AppleScript to control macOS applications and system features.",
            parameters: .init(
                type: "object",
                properties: [
                    "script": .init(type: "string", description: "The AppleScript code to execute")
                ],
                required: ["script"]
            )
        )
    )
    
    static let listDirectoryTool = ToolDefinition(
        function: .init(
            name: "list_directory",
            description: "List files and folders in a directory.",
            parameters: .init(
                type: "object",
                properties: [
                    "path": .init(type: "string", description: "The directory path to list. Use ~ for home directory.")
                ],
                required: ["path"]
            )
        )
    )
    
    static let readFileTool = ToolDefinition(
        function: .init(
            name: "read_file",
            description: "Read the contents of a text file.",
            parameters: .init(
                type: "object",
                properties: [
                    "path": .init(type: "string", description: "The file path to read. Use ~ for home directory.")
                ],
                required: ["path"]
            )
        )
    )
}
