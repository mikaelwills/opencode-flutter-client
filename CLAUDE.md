# Obsidian Notes Feature Implementation Plan

## Project Overview

This document outlines the implementation plan for adding a standalone Obsidian notes feature to the Flutter app. This feature will operate independently alongside the existing OpenCode chat functionality, providing manual note viewing and manipulation capabilities.

## Sequential Analysis & Implementation Plan

### Thought 1: Understanding the Scope
- **Standalone feature** - separate from OpenCode chat functionality
- Manual notes viewing and manipulation interface
- Direct connection to Obsidian via REST API
- Independent UI section in the Flutter app

### Thought 2: Obsidian REST Plugin Requirements
- Install HTTP REST API plugin for Obsidian (separate from existing MCP SSE)
- Popular options:
  - "REST API" plugin
  - "Local REST API" plugin
- Must support basic CRUD operations:
  - Read notes
  - Create new notes
  - Update existing notes
  - Delete notes
- Configuration requirements:
  - Authentication setup (API keys)
  - CORS configuration for Flutter app access

### Thought 3: Flutter App Structure
- Add new notes section/tab to existing app navigation
- Completely separate from OpenCode chat functionality
- Independent state management for notes
- Own set of screens:
  - Notes list view
  - Individual note viewer
  - Note editor

### Thought 4: API Operations Needed
- **GET /notes** - List all notes
- **GET /notes/{id}** - Get specific note content
- **POST /notes** - Create new note
- **PUT /notes/{id}** - Update existing note
- **DELETE /notes/{id}** - Delete note
- Search/filter capabilities
- Folder/tag navigation (if supported by plugin)

### Thought 5: UI Components Required
- **Notes List Screen**:
  - Search and filter functionality
  - Note preview cards
  - Create new note button
- **Note Viewer**:
  - Markdown rendering
  - Edit button
  - Delete option
- **Note Editor**:
  - Markdown editing interface
  - Save/cancel actions
  - Preview mode
- **Navigation**:
  - File tree/folder navigation
  - Tag-based filtering

### Thought 6: Implementation Phases

## Implementation Timeline

### Phase 1: Obsidian Server Setup
1. **Install REST API Plugin**
   - Research and select appropriate plugin
   - Install in Obsidian Docker container
   - Configure plugin settings
2. **Security Configuration**
   - Set up API authentication (API keys)
   - Configure CORS for Flutter app access
   - Test API endpoints with Postman/curl

### Phase 2: Flutter API Service Layer
1. **HTTP Client Setup**
   - Add dio/http package dependencies
   - Create base API client class
   - Implement authentication handling
2. **Obsidian API Service**
   - Create ObsidianApiService class
   - Implement CRUD operations
   - Add error handling and response parsing
3. **Data Models**
   - Note model class
   - Serialization/deserialization
   - Local caching strategy (if needed)

### Phase 3: UI Implementation
1. **Notes List Screen**
   - Create NotesListPage widget
   - Implement search and filter UI
   - Add note preview cards
   - Integrate with API service
2. **Note Viewer Screen**
   - Create NoteViewerPage widget
   - Implement markdown rendering
   - Add edit/delete actions
3. **Note Editor Screen**
   - Create NoteEditorPage widget
   - Implement markdown editing
   - Add save/cancel functionality

### Phase 4: Navigation Integration
1. **Add Notes Tab/Section**
   - Update main navigation
   - Add notes icon and routing
   - Ensure separation from OpenCode chat
2. **Internal Navigation**
   - Implement note-to-note navigation
   - Add deep linking support
   - Handle back navigation properly

### Phase 5: Testing & Polish
1. **Integration Testing**
   - Test with real Obsidian data
   - Verify CRUD operations
   - Test error scenarios
2. **UI/UX Polish**
   - Implement loading states
   - Add offline handling
   - Optimize performance
3. **Security Review**
   - Review API key handling
   - Ensure secure data transmission
   - Test authentication flows

## Technical Considerations

### Dependencies
- `dio` or `http` for API requests
- `flutter_markdown` for note rendering
- State management solution (Provider/Bloc/Riverpod)
- `shared_preferences` for local storage

### Error Handling
- Network connectivity issues
- API authentication failures
- Note not found scenarios
- Server unavailable handling

### Performance
- Lazy loading for large note lists
- Caching frequently accessed notes
- Efficient markdown rendering
- Image handling in notes

## Success Criteria
- [ ] Obsidian REST API plugin installed and configured
- [ ] Flutter app can list all notes from Obsidian
- [ ] Users can view individual notes with proper markdown rendering
- [ ] Users can create new notes through the app
- [ ] Users can edit existing notes
- [ ] Users can delete notes with confirmation
- [ ] Search and filter functionality works
- [ ] Feature operates independently from OpenCode chat
- [ ] Proper error handling and user feedback
- [ ] Secure authentication with Obsidian server

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