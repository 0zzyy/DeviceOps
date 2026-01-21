# Contributing to DeviceOps

Thanks for helping improve DeviceOps. This project favors clarity, reliability, and enterprise-grade quality.

## Development principles
- Prefer small, focused types and clear naming.
- Use async/await for all I/O.
- Keep UI responsive and avoid work on the main thread.
- Add tests for logic changes.

## Code review checklist
- [ ] Does the change maintain SwiftUI accessibility (labels, VoiceOver, Dynamic Type)?
- [ ] Are network calls using async/await with proper cancellation?
- [ ] Are retries and error mappings updated if needed?
- [ ] Are unit tests added/updated for new logic?
- [ ] Are UI tests updated for any critical user flows?
- [ ] Are logs using `os.Logger` with appropriate subsystem/category?
- [ ] Are secrets stored in Keychain (never committed to repo)?
- [ ] Are new files documented in README where appropriate?
