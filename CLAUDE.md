# NEVER TRY TO RUN THE APP AFTER MAKING CHANGES, USER ALWAYS HAS THE APP RUNNING IN ANOTHER TERMINAL


## Current Server Configuration
- Obsidian server: `http://192.168.1.161:22360`
- Current interface: MCP SSE (for Claude integration)
- REST API plugin: Local REST API (installed and configured)

### REST API Configuration
- **HTTPS Port**: 27124
- **HTTP Port**: 27123 (insecure, enabled for development)
- **API Key**: `d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b`
- **Base URL**: `http://192.168.1.161:27123` (via Tailscale)
- **Authentication**: `Authorization: Bearer <api-key>` header
- **Status**: ✅ **WORKING** - API tested and functional

## Complete API Reference

### Core Endpoints

#### **1. System Information**
- **GET /** - Get server status and info
  - Returns: Server version, authentication status, plugin info
  - Auth: Not required

#### **2. Vault Operations**
- **GET /vault/** - List all files in vault root
  - Returns: `{"files": ["note1.md", "note2.md", "folder/"]}`
  - Auth: Required

- **GET /vault/{path}** - Get file content or folder contents
  - For files: Returns raw markdown content
  - For folders: Returns `{"files": [...]}`
  - Auth: Required

- **POST /vault/{path}** - Create new note ✅ Tested
  - Content-Type: `text/markdown`
  - Body: Raw markdown content
  - Returns: 200 on success
  - Auth: Required

- **PUT /vault/{path}** - Update existing note
  - Content-Type: `text/markdown`
  - Body: Raw markdown content
  - Auth: Required

- **PATCH /vault/{path}** - Insert content into specific sections ⚠️ Advanced
  - **Purpose**: Insert content relative to headings, block references, or frontmatter
  - **Headers Required**:
    - `Target-Type: heading|block|frontmatter`
    - `Target-Value: <heading name or block reference>`
    - `Operation: append|prepend|replace`
  - **Use Cases**: Add content under specific headings, update frontmatter fields
  - **Note**: Complex API - may need experimentation for exact syntax
  - Auth: Required

- **DELETE /vault/{path}** - Delete note
  - Returns: 204 on success
  - Auth: Required

#### **3. Commands**
- **GET /commands/** - List all available Obsidian commands ✅ Tested
  - Returns: Array of command objects with `id` and `name`
  - Useful for automation and integrations
  - Auth: Required

#### **4. Advanced Features**
- **GET /search/** - Search notes (endpoint exists but may not be functional)
- **GET /search/simple/** - Simple search interface
- **GET /active/** - Get currently active note
- **GET /openapi.yaml** - API specification ✅ Available

### Authentication
- **Method**: `Authorization: Bearer <api-key>`
- **API Key**: `d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b`
- **Required**: All endpoints except `/`

### Example Requests
```bash
# List all notes
curl -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  "http://192.168.1.161:27123/vault/"

# Get specific note
curl -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  "http://192.168.1.161:27123/vault/Welcome.md"

# Create new note
curl -X POST \
  -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  -H "Content-Type: text/markdown" \
  -d "# My New Note\n\nContent here" \
  "http://192.168.1.161:27123/vault/my-note.md"

# Get available commands
curl -H "Authorization: Bearer d8c56f738e76182b8963ff34ca9dd4c4a76b40e00da2371cda90a26a551c4b8b" \
  "http://192.168.1.161:27123/commands/"
```

### Data Models
```json
// File list response
{
  "files": ["note1.md", "note2.md", "folder/"]
}

// Command object
{
  "id": "editor:save-file",
  "name": "Save current file"
}

// Error response
{
  "message": "Error description",
  "errorCode": 40101
}
```

# Flutter Widget Structure Guidelines

## MANDATORY STRUCTURE ORDER
ALL Flutter widgets MUST follow this exact order:

1. **CONSTRUCTOR** - Widget constructor and state variables
2. **INIT** - `initState()` and `dispose()` lifecycle methods
3. **BUILD** - The main `build()` method
4. **WIDGET FUNCTIONS** - All `Widget _buildXXX()` helper methods
5. **HELPER FUNCTIONS** - All other utility methods and event handlers

## Example Structure
```dart
class MyWidget extends StatefulWidget {
  // 1. CONSTRUCTOR
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // State variables here

  // 2. INIT
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 3. BUILD
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildContent(),
      ],
    );
  }

  // 4. WIDGET FUNCTIONS
  Widget _buildHeader() {
    return Container(/* header */);
  }

  Widget _buildContent() {
    return Container(/* content */);
  }

  // 5. HELPER FUNCTIONS
  void _onTap() {
    // event handler
  }

  String _formatData() {
    // utility method
  }
}
```

**NEVER deviate from this order!**
