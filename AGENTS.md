# Agent Instructions for OpenCode Flutter Client

## Flutter Development Guidelines

### 🚫 NEVER Run Flutter Apps
- **CRITICAL**: Never run `flutter run`, `flutter build`, or any commands that launch the Flutter app
- Only use `flutter analyze` to check for syntax errors
- The user will handle all app testing and running manually
- Focus on code analysis and static checking only

### Development Workflow
1. Make code changes as requested
2. Run `flutter analyze` to check for errors
3. Fix any analysis warnings or errors
4. **DO NOT** attempt to run or build the app
5. **DO NOT** commit changes automatically - user will test first

### Allowed Flutter Commands
- ✅ `flutter analyze` - Check for code issues
- ✅ `flutter doctor` - Check Flutter installation (if needed)
- ✅ `flutter pub get` - Install dependencies (if needed)
- ❌ `flutter run` - NEVER run the app
- ❌ `flutter build` - NEVER build the app
- ❌ Any emulator or device commands

### Code Quality
- Always run `flutter analyze` after making changes
- Fix all warnings and errors before completing tasks
- Follow Dart/Flutter best practices
- Maintain existing code style and patterns

### Testing & Commits
- User will handle all manual testing
- Focus on static analysis and code correctness
- Ensure changes compile without errors
- No need to verify runtime behavior
- **NEVER commit changes automatically** - user needs to test functionality first
- Only commit when explicitly requested after user testing

## Project-Specific Notes
- This is a Flutter mobile client for OpenCode
- Uses BLoC pattern for state management
- Connects to OpenCode server via HTTP/SSE
- Critical connectivity issues are documented in Obsidian notes