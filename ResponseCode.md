# ResponseCode.md

## Objective
The purpose of this document is to serve as the source of truth for handling non-200 OK TAPI Response Codes for all currently active analytics SDKs. This document will define how SDKs should handle scenarios such as rate-limiting errors and exponential backoff.

This document considers the architecture of the following libraries:

- **analytics-swift**
- **analytics-kotlin**
- **analytics-next**
- **analytics-react-native**

Other libraries should also be able to implement the prescribed changes.

## Background
Over the last few years, TAPI (our tracking endpoint) has occasionally been overwhelmed by massive amounts of data. This has caused service degradation for our clients and generated SEVs for the organization.

To address these issues, the server-side team has proposed measures to:
1. Allow devices to retry later using the `Retry-After` header.
2. Implement exponential backoff for certain errors.

The living document for this information is located here:

**Client <> TAPI Status Code Agreements**

This document solidifies those suggestions into a pass/fail set of tests that must be added to the SDKs to confirm compliance with TAPI response code requirements.

## Requirements

### HTTP Response Handling Rules

#### 🔴 4xx — Client Errors
These usually indicate that the request should not be retried unless the failure is transient or the request can be fixed.

| Code | Meaning                                      | Should Retry? | Notes                                                                 |
|------|----------------------------------------------|---------------|-----------------------------------------------------------------------|
| 400  | Bad Request - Invalid syntax                | No            | Drop these events entirely                                            |
| 401  | Unauthorized - Missing/invalid auth         | No            | Drop these events entirely                                            |
| 403  | Forbidden - Access denied                   | No            | Drop these events entirely                                            |
| 404  | Not Found - Resource missing                | No            | Drop these events entirely                                            |
| 408  | Request Timeout - Server timed out waiting  | Yes           | Retry based on `Retry-After` value in response header                 |
| 410  | Resource no longer available                | Yes           | Exponential Backoff + Max-retry                                       |
| 413  | Payload too large                           | Maybe         | Retry if payload size can be reduced; otherwise, drop these events    |
| 422  | Unprocessable Entity                        | No            | Returned when max retry count is reached (based on `X-Retry-Count`)   |
| 429  | Too Many Requests                           | Yes           | Retry based on `Retry-After` value in response header                 |
| 460  | Client timeout shorter than ELB idle timeout| Yes           | Exponential Backoff + Max-retry                                       |
| 4xx  | Default                                     | No            | Drop these events entirely                                            |

#### ⚫ 5xx — Server Errors
These typically indicate transient server-side problems and are usually retryable.

| Code | Meaning                                      | Should Retry? | Notes                                                                 |
|------|----------------------------------------------|---------------|-----------------------------------------------------------------------|
| 500  | Internal Server Error                       | Yes           | Exponential Backoff + Max-retry                                       |
| 501  | Not Implemented                             | No            | Drop these events entirely                                            |
| 502  | Bad Gateway                                 | Yes           | Exponential Backoff + Max-retry                                       |
| 503  | Service Unavailable                         | Yes           | Exponential Backoff + Max-retry                                       |
| 504  | Gateway Timeout                             | Yes           | Exponential Backoff + Max-retry                                       |
| 505  | HTTP Version Not Supported                  | No            | Drop these events entirely                                            |
| 508  | Loop Detected                               | Yes           | Exponential Backoff + Max-retry                                       |
| 511  | Network Authentication Required            | Maybe         | Authenticate, then retry                                              |
| 5xx  | Default                                     | Yes           | Exponential Backoff + Max-retry                                       |

### 🔁 Retry Patterns

| Pattern                     | Description                                                                                     | Typical Use Cases          |
|-----------------------------|-------------------------------------------------------------------------------------------------|----------------------------|
| Exponential Backoff + Max-retry | 0.5s -> 1s -> 2s -> 5s -> 10s -> ... 1m. Max retry count: 1000 (configurable).               | 5xx, 410                   |
| Use Retry-After Header      | Server-specified wait time (in seconds or date).                                               | 408, 429, 503 (if available)|

- **Exponential Backoff**: The max retry duration and count must be long enough to cover several hours of sustained retries during a serious or extended TAPI outage.

### Configuration via Settings Object

To ensure flexibility and avoid hardcoded configurations, the retry and backoff logic should be configurable through the `Settings` object. This object is dynamically fetched from the Segment CDN during library startup, allowing updates to be applied without requiring code changes or redeployments.

#### Key Configuration Parameters
The following parameters should be added to the `Settings` object:

- **maxRetryCount**: The maximum number of retry attempts (default: 1000).
- **baseBackoffInterval**: The initial backoff interval in seconds (default: 0.5 seconds).
- **maxBackoffInterval**: The maximum backoff interval in seconds (default: 60 seconds).
- **retryableStatusCodes**: A list of HTTP status codes that should trigger retries (e.g., `5xx`, `408`, `429`).

#### Example Settings Object
```json
{
  "retryConfig": {
    "maxRetryCount": 1000,
    "baseBackoffInterval": 0.5,
    "maxBackoffInterval": 60,
    "retryableStatusCodes": [408, 429, 500, 502, 503, 504]
  }
}
```

#### Integration
1. **Fetch Settings**: The library should fetch the `Settings` object from the Segment CDN during startup.
2. **Apply Configurations**: Use the values from the `retryConfig` section to initialize the retry and backoff logic.
3. **Fallback Defaults**: If the `retryConfig` section is missing or incomplete, fallback to the default values.

By making these parameters configurable, the SDK can adapt to changing requirements without requiring updates to the client application.

## Approach
We will add support for both exponential backoff and 429 rate-limiting using a class that encapsulates the required logic. This class will be:

- **Configurable**: Allow developers to adjust retry limits and backoff parameters via the `Settings` object, which is dynamically fetched from the Segment CDN. This ensures that configurations can be updated without requiring code changes or redeployments.
- **Integrable**: Easily integrated into existing SDKs.
- **Testable**: Designed with unit tests to ensure compliance with the rules outlined above.

By leveraging the `Settings` object, the retry and backoff logic can adapt dynamically to changes in server-side configurations, providing greater flexibility and control.

### Architecture
The architecture for implementing exponential backoff and 429 rate-limiting includes the following components:

#### State Machine
The state machine is responsible for managing the upload pipeline's state. It defines the states and transitions based on HTTP responses and retry logic.

- **States**:
  | State   | Description                          |
  |---------|--------------------------------------|
  | READY   | The pipeline is ready to upload.     |
  | WAITING | The pipeline is waiting to retry.    |

- **Transitions**:
  | Current State | Event                     | Next State | Action                                   |
  |---------------|---------------------------|------------|------------------------------------------|
  | READY         | 429 or 5xx response       | WAITING    | Set `waitUntilTime` based on backoff.    |
  | WAITING       | `waitUntilTime` reached   | READY      | Reset state and attempt upload.          |

The state machine ensures that uploads are only attempted when the pipeline is in the `READY` state.

#### Upload Gate
The concept of an upload gate replaces the need for a traditional timer. Instead of setting a timer to trigger uploads, the pipeline checks the state and `waitUntilTime` whenever an upload is triggered (e.g., by a new event).

- **How It Works**:
  - When an upload is triggered (e.g., a new event is added to the queue), the pipeline retrieves the current state from the state machine.
  - If the current time is past the `waitUntilTime`, the state machine transitions to `READY`, and the upload proceeds.
  - If the current time is before the `waitUntilTime`, the pipeline remains in the `WAITING` state, and the upload is deferred.

- **Advantages**:
  - Simplifies the implementation by removing the need for timers.
  - Ensures that uploads are only attempted when triggered by an event or other external factor.
  - Maintains the one-at-a-time upload loop while respecting backoff and retry rules.

By using an upload gate, the SDK ensures that uploads are managed efficiently and only occur when the pipeline is ready, without relying on timers to schedule retries.

#### Persistence
Persistence ensures that the state machine's state and `waitUntilTime` are retained across app restarts. This is particularly useful for SDKs that support long-running applications.

- **Options**:
  - **Persistent SDKs**: Use local storage (e.g., `UserDefaults`, SQLite) to save the state and `waitUntilTime`.
  - **In-Memory SDKs**: If persistence is not possible, the state resets on app restart, and the pipeline starts fresh.

- **Guarantees**:
  - Persistent SDKs must ensure that the saved state is consistent and does not lead to duplicate uploads.
  - The `waitUntilTime` must be validated to ensure it is not in the past upon app restart.

#### Integration
Integration involves embedding the retry and backoff logic into the SDK's upload pipeline.

- **Advice**:
  - Ensure that the state machine is checked before every upload attempt.
  - Use the `Settings` object to configure retry parameters dynamically.
  - Log state transitions and retry attempts for debugging and monitoring.

- **Requirements**:
  - The retry logic must be modular and testable.
  - The integration must not block other SDK operations, ensuring that the upload pipeline operates independently.

By following this architecture, the SDKs can implement robust and configurable retry and backoff mechanisms that align with the requirements outlined in this document.

---

This document will evolve as new requirements emerge or as TAPI behavior changes. All SDKs must adhere to the rules and patterns outlined here to ensure consistent and reliable behavior across platforms.

### Client <> TAPI Status Code Agreements

This section explicitly outlines the agreements between the client SDKs and the TAPI server, as referenced in the TAPI documentation. These agreements ensure consistent handling of HTTP response codes across all SDKs.

#### Key Agreements
1. **HTTP Auth Header**:
   - The SDKs will include the writekey in the `Authorization` header, as has been done historically.

2. **HTTP X-Retry-Count Header**:
   - The SDKs will set the `X-Retry-Count` header for all requests to upload events.
   - The value will start at `0` and increment with each retryable or backoff HTTP response.

3. **Upload Loop**:
   - The SDKs will maintain the current one-at-a-time upload loop.
   - The loop will respect `Retry-After` and exponential backoff rules, ensuring no upload attempts occur before the prescribed time.
   - Uploads may be retried after the prescribed time, typically triggered by a timer or event.

4. **Retry-After**:
   - The SDKs will adhere to the `Retry-After` time specified in the server response.
   - The retry time is usually less than 1 minute, with a maximum cap of 300 seconds.

5. **Error Handling Tables**:
   - The SDKs will adhere to the error handling rules outlined in the tables for `4xx` and `5xx` HTTP response codes above.
   - These rules include whether to retry, drop events, or apply exponential backoff based on the specific status code.

By adhering to these agreements, the SDKs ensure reliable and consistent communication with the TAPI server, minimizing the risk of overloading the server while maintaining robust error handling.