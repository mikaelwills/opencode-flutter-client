# Contributing to OpenCode Flutter Client

Thank you for your interest in contributing to the OpenCode Flutter Client! This document provides guidelines and information for contributors.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- **Flutter SDK**: Version 3.5.4 or higher
- **Dart SDK**: Included with Flutter
- **Git**: For version control
- **IDE**: VS Code, Android Studio, or IntelliJ with Flutter plugins

### Development Setup

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/opencode-flutter-client.git
   cd opencode-flutter-client
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify Setup**:
   ```bash
   flutter doctor
   flutter analyze
   flutter test
   ```

4. **Run the App**:
   ```bash
   flutter run
   ```

## Development Workflow

### Branch Strategy

- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/feature-name`: Individual feature branches
- `bugfix/bug-description`: Bug fix branches
- `hotfix/critical-fix`: Critical production fixes

### Making Changes

1. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**:
   - Follow the coding standards below
   - Write tests for new functionality
   - Update documentation as needed

3. **Test Your Changes**:
   ```bash
   flutter analyze
   flutter test
   flutter run # Manual testing
   ```

4. **Commit Your Changes**:
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. **Push and Create PR**:
   ```bash
   git push origin feature/your-feature-name
   ```

## Coding Standards

### Dart/Flutter Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter analyze` to check code quality
- Format code with `dart format`
- Use meaningful variable and function names
- Add documentation comments for public APIs

### Code Style

```dart
// Good: Clear, descriptive naming
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isUser,
  });

  final String message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Implementation
    );
  }
}
```

### Architecture Patterns

- **BLoC Pattern**: Use for state management
- **Repository Pattern**: For data access
- **Dependency Injection**: Use Provider for DI
- **Clean Architecture**: Separate concerns properly

### File Organization

```
lib/
├── blocs/          # BLoC state management
├── models/         # Data models
├── services/       # API and business services
├── screens/        # UI screens
├── widgets/        # Reusable UI components
├── utils/          # Utility functions
├── config/         # Configuration files
└── main.dart       # App entry point
```

## Testing

### Test Types

1. **Unit Tests**: Test individual functions and classes
2. **Widget Tests**: Test UI components
3. **Integration Tests**: Test complete user flows

### Writing Tests

```dart
// Example unit test
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_flutter_client/models/message.dart';

void main() {
  group('Message Model', () {
    test('should create message from JSON', () {
      // Arrange
      final json = {'content': 'Hello', 'isUser': true};
      
      // Act
      final message = Message.fromJson(json);
      
      // Assert
      expect(message.content, 'Hello');
      expect(message.isUser, true);
    });
  });
}
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/message_test.dart

# Run with coverage
flutter test --coverage
```

## Pull Request Process

### Before Submitting

- [ ] Code follows style guidelines
- [ ] All tests pass (`flutter test`)
- [ ] Code analysis passes (`flutter analyze`)
- [ ] Documentation is updated
- [ ] Self-review completed

### PR Template

When creating a PR, please include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests pass
- [ ] Documentation updated
```

### Review Process

1. **Automated Checks**: CI/CD runs tests and analysis
2. **Code Review**: Maintainers review code quality
3. **Testing**: Manual testing if needed
4. **Approval**: At least one maintainer approval required
5. **Merge**: Squash and merge to main branch

## Issue Reporting

### Bug Reports

Use the bug report template and include:
- Flutter/Dart version
- Device/OS information
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/logs if applicable

### Feature Requests

Use the feature request template and include:
- Problem description
- Proposed solution
- Alternative solutions considered
- Additional context

## Development Tips

### Debugging

```bash
# Enable debug mode
flutter run --debug

# Hot reload during development
# Press 'r' in terminal or use IDE hot reload

# Debug with DevTools
flutter run --debug
# Then open DevTools in browser
```

### Performance

- Use `const` constructors where possible
- Avoid rebuilding widgets unnecessarily
- Use `ListView.builder` for large lists
- Profile with Flutter Inspector

### Common Patterns

```dart
// BLoC usage
class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state is ChatLoading) {
          return CircularProgressIndicator();
        }
        // Handle other states
      },
    );
  }
}

// Service injection
class ChatService {
  final HttpClient _httpClient;
  
  ChatService({required HttpClient httpClient}) 
    : _httpClient = httpClient;
}
```

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH`
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes (backward compatible)

### Release Checklist

- [ ] Version updated in `pubspec.yaml`
- [ ] CHANGELOG.md updated
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Release notes prepared

## Getting Help

### Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [BLoC Library](https://bloclibrary.dev/)
- [OpenCode Documentation](https://opencode.ai/docs)

### Community

- **GitHub Discussions**: For questions and ideas
- **Issues**: For bug reports and feature requests
- **Pull Requests**: For code contributions

### Contact

- Create an issue for bugs or feature requests
- Start a discussion for questions or ideas
- Mention maintainers in PRs for review

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- GitHub contributors page

Thank you for contributing to OpenCode Flutter Client! 🚀