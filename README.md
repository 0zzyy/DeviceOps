# DeviceOps

DeviceOps is a internal tools system that makes enterprise device management feel invisible. Combining SwiftUI admin workflows, a Swift CLI, and a local mock server for end-to-end demos across MDM, ITAM, and software distribution.

## Architecture

**Modules**
- `DeviceOpsAPI`: OpenAPI-generated client types and transport layer using `OpenAPIRuntime` + `OpenAPIURLSession`.
- `DeviceOpsCore`: Shared domain models, API service, error handling, retries, reconciliation logic, and GenAI assist protocol.
- `devicectl`: Swift CLI executable.
- `deviceops-mock-server`: Local mock server powered by SwiftNIO.
- `DeviceOpsApp`: SwiftUI admin console (macOS + iOS/iPadOS) built via XcodeGen.

**Data flow**
SwiftUI → ViewModels → `DeviceOpsServicing` → OpenAPI client → mock server.

## Getting started

### 1) Start the mock server
```
swift run deviceops-mock-server
```

### 2) Run the CLI
```
swift run devicectl devices list --page 1
swift run devicectl devices info D0001
swift run devicectl commands send D0001 queryDeviceInformation
swift run devicectl reconcile-assets --export /tmp/recon.csv
swift run devicectl report compliance --export /tmp/compliance.json
```

### 3) Run the SwiftUI app
This repo uses XcodeGen to generate the Xcode project.

```
brew install xcodegen
xcodegen generate
open DeviceOps.xcodeproj
```

### 4) Regenerate the OpenAPI client (optional)
If you want to regenerate the client, install the Swift OpenAPI Generator and run:
```
./Scripts/generate-openapi.sh
```

## Configuration

You can provide configuration using environment variables or `Configs/deviceops.json`.

```json
{
  "baseURL": "http://localhost:8080",
  "token": null
}
```

Environment variables:
- `DEVICEOPS_BASE_URL`
- `DEVICEOPS_TOKEN`

## Testing

```
swift test
```

In Xcode:
- Run `DeviceOpsAppTests` and `DeviceOpsAppUITests`.

## GenAI Assist Privacy & Guardrails

The Assist tab uses a pluggable `AIAssistantProviding` protocol:
- **LocalAssistant** (default): rule-based summaries with no network usage.
- **RemoteAssistant** (opt-in): stubbed example that demonstrates safe redaction.

If you enable the RemoteAssistant, only redacted fields are prepared:
- Device ID
- Platform
- Compliance signals (boolean + counts)

No user names, asset tags, or serial numbers are sent. The remote call is disabled by default and can only be enabled in-app. The stub has no API key requirement and will not send network traffic unless you wire it up.

## Mock API endpoints
- `GET /v1/devices?page=…&q=…&platform=…&compliance=…`
- `GET /v1/devices/{id}`
- `POST /v1/devices/{id}/commands`
- `GET /v1/commands/{jobId}`
- `GET /v1/assets?page=…&q=…`
- `GET /v1/software?page=…&platform=…`
- `POST /v1/software/{id}/install`

## File tree (high level)

```
App/
CLI/
Server/
Shared/
Configs/
openapi.yaml
openapi-generator-config.yaml
```
