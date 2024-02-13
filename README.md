# Analytics-Swift
![](https://github.com/segmentio/analytics-swift/actions/workflows/swift.yml/badge.svg)
![](https://img.shields.io/github/license/segmentio/analytics-swift)

### 🎉 Flagship 🎉
This library is one of Segment’s most popular Flagship libraries. It is actively maintained by Segment, benefitting from new feature releases and ongoing support.

The hassle-free way to add Segment analytics to your Swift app (iOS/tvOS/visionOS/watchOS/macOS/Linux/iPadOS). Analytics helps you measure your users, product, and business. It unlocks insights into your app's funnel, core business metrics, and whether you have product-market fit.

## How to get started
1. **Collect analytics data** from your app(s).
  - The top 200 Segment companies collect data from 5+ source types (web, mobile, server, CRM, etc.).
2. **Send the data to analytics tools** (for example, Google Analytics, Amplitude, Mixpanel).
  - Over 250+ Segment companies send data to eight categories of destinations such as analytics tools, warehouses, email marketing and remarketing systems, session recording, and more.
3. **Explore your data** by creating metrics (for example, new signups, retention cohorts, and revenue generation).
  - The best Segment companies use retention cohorts to measure product market fit. Netflix has 70% paid retention after 12 months, 30% after 7 years.

[Segment](https://segment.com) collects analytics data and allows you to send it to more than 250 apps (such as Google Analytics, Mixpanel, Optimizely, Facebook Ads, Slack, Sentry) just by flipping a switch. You only need one Segment code snippet, and you can turn integrations on and off at will, with no additional code. [Sign up with Segment today](https://app.segment.com/signup).

### Why?
1. **Power all your analytics apps with the same data**. Instead of writing code to integrate all of your tools individually, send data to Segment, once.

2. **Install tracking for the last time**. We're the last integration you'll ever need to write. You only need to instrument Segment once. Reduce all of your tracking code and advertising tags into a single set of API calls.

3. **Send data from anywhere**. Send Segment data from any device, and we'll transform and send it on to any tool.

4. **Query your data in SQL**. Slice, dice, and analyze your data in detail with Segment SQL. We'll transform and load your customer behavioral data directly from your apps into Amazon Redshift, Google BigQuery, or Postgres. Save weeks of engineering time by not having to invent your own data warehouse and ETL pipeline.

   For example, you can capture data on any app:
    ```swift
    struct TrackProperties: Codable {
        let price: Double
    }

    // ...

    analytics.track(name: "Order Completed", properties: TrackProperties(price: 99.84))
    ```
   Then, query the resulting data in SQL:
    ```sql
    select * from app.order_completed
    order by price desc
    ```

## Supported Device Mode Destinations

| Partner | Package |
| --- | --- |
| Amplitude | https://github.com/segment-integrations/analytics-swift-amplitude |
| AppsFlyer | https://github.com/segment-integrations/analytics-swift-appsflyer |
| Braze    | https://github.com/segment-integrations/analytics-swift-braze |
| Facebook | https://github.com/segment-integrations/analytics-swift-facebook-app-events |
| Firebase | https://github.com/segment-integrations/analytics-swift-firebase |
| Mixpanel | https://github.com/segment-integrations/analytics-swift-mixpanel |
| Survicate | https://github.com/Survicate/analytics-swift-survicate |

## Documentation

You can find usage documentation at [Segment Docs, Analytics-Swift](https://segment.com/docs/connections/sources/catalog/libraries/mobile/apple/).

Explore more via the [example projects](Examples) which showcase analytics instrumentation on different platforms/languages and usage of plugins. These projects contain sample [plugins](Examples/other_plugins) and [destination plugins](Examples/destination_plugins).

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## Integrating with Segment

Interested in integrating your service with us? Check out our [Partners page](https://segment.com/partners/) for more details.

## Code of Conduct

Before contributing, please also see our [code of conduct](CODE_OF_CONDUCT.md).

## License
```
MIT License

Copyright (c) 2021 Segment

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
