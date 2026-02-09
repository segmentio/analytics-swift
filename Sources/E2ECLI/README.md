# analytics-swift e2e-cli

E2E test CLI for the [analytics-swift](https://github.com/segmentio/analytics-swift) SDK. Accepts a JSON input describing events and SDK configuration, sends them through the real SDK, and outputs results as JSON.

Defined as a target in the Swift package and built with Swift Package Manager.

## Setup

```bash
swift build
```

## Usage

```bash
swift run e2e-cli --input '{"writeKey":"...", ...}'
```

Or use the built binary directly:

```bash
.build/debug/e2e-cli --input '{"writeKey":"...", ...}'
```

## Input Format

```jsonc
{
  "writeKey": "your-write-key",       // required
  "apiHost": "https://...",           // optional — SDK default if omitted
  "cdnHost": "https://...",           // optional — SDK default if omitted
  "sequences": [                      // required — event sequences to send
    {
      "delayMs": 0,
      "events": [
        { "type": "track", "event": "Test", "userId": "user-1" }
      ]
    }
  ],
  "config": {                         // optional
    "flushAt": 20,
    "flushInterval": 30,
    "maxRetries": 10,
    "timeout": 15
  }
}
```

## Output Format

```json
{ "success": true, "sentBatches": 1 }
```

On failure:

```json
{ "success": false, "error": "description", "sentBatches": 0 }
```
