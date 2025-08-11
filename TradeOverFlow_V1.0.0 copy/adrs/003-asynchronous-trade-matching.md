# Asynchronous Trade Matching Triggered by EventBridge

**Status**: Accepted

## Context

At the core of the system is the logic that continuously matches buyers and sellers. A naive implementation would be to trigger a matching check synchronously each time a new item is listed or a new bid is submitted. However, this approach has several issues:

- It increases API response latency for users, who would have to wait for the matching logic to complete.

- Under high load, concurrent matching operations may cause database contention or performance bottlenecks.

- It tightly couples the matching logic with the user-facing API layer, violating the single-responsibility principle and reducing maintainability.

## Decision

I decided to decouple the trade matching logic from the user API entirely by handling it asynchronously.

- API operations like `listItem` and `submitBid` simply write data to DynamoDB and return a response immediately.

- A dedicated Lambda function named `processTrades` is responsible for running the complex trade matching logic.

- Using Amazon EventBridge, I configured a scheduled rule (e.g., every minute) to reliably and automatically trigger the `processTrades` function at fixed intervals.

## Consequences

### Pros

- **Improved User Experience**: API requests for listing items or submitting bids are fast and responsive, as they are no longer blocked by backend processing.

- **Greater System Resilience**: Even if the trade matching engine fails temporarily, users can continue interacting with the platform. The API and backend are logically isolated.

- **Better Maintainability**: The trade matching logic is encapsulated in a dedicated function, making it easier to test, debug, and evolve independently.

- **Smoother Load Management**: Batch processing at regular intervals helps smooth out load on the database and avoids performance spikes caused by sudden bursts of activity.

### Cons

- **Non-Real-Time Matching**: Trades are not matched instantly but after a short delay (e.g., up to one minute). This may not be suitable for applications requiring real-time execution.

- **Increased Observability Complexity**: I need to implement additional monitoring and logging to ensure EventBridge scheduling and `processTrades` executions are reliable and functioning correctly.