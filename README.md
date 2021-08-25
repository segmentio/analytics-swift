# Analytics-Swift

NOTE: This project is currently in the Pilot phase and is covered by Segment's [First Access & Beta Preview Terms](https://segment.com/legal/first-access-beta-preview/).  We encourage you
to try out this new library. Please provide feedback via Github issues/PRs, and feel free to submit pull requests.  This library will eventually 
supplant our `analytics-ios` library, but customers should not use this library for production applications during our Pilot phase. 

The hassle-free way to add Segment analytics to your Swift app (iOS/tvOS/watchOS/macOS/Linux).

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
	- [Setting up the client](#setting-up-the-client)
	- [Client Options](#client-options)
- [Client Methods](#client-methods)
	- [track](#track)
	- [identify](#identify)
	- [screen](#screen)
	- [group](#group)
	- [add](#add)
	- [find](#find)
	- [remove](#remove)
	- [flush](#flush)
- [Plugin Architecture](#plugin-architecture)
	- [Fundamentals](#fundamentals)
	- [Advanced Concepts](#advanced-concepts)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

## Installation
Add the Swift package as a dependency either via your package.swift, or via Xcode's File->Swift Packages->Add Package Dependency menu item.

`git@github.com:segmentio/analytics-swift.git`

Once completed, Analytics can be referenced by importing Segment's Analytics package

`import Segment`

## Usage
### Setting up the client
The Analytics client will typically be set up at application launch time, such as `applicationDidFinishLaunching`.

Typically the following call may be all that's required.

```swift
Analytics(configuration: Configuration("SEGMENT_API_KEY"))
```

### Configuration Options
When creating a new client, you can configure it in various ways.  Some examples are listed below.

```swift
let config = Configuration(writeKey: "8XpdAWa7qJVBJMK8V4FfXQOrnvCzu3Ie")
	.flushAt(3)
	.trackApplicationLifecycleEvents(true)
	.flushInterval(10)

let analytics = Analytics(configuration: config)
```

| Name |  Default | Description |
| ---- |  ------- | ----- |
| writeKey | *required* |  Your Segment writeKey |
| application | `nil` |  application specific object |
| trackApplicationLifecycleEvents | `true` |  automatically track Lifecycle events |
| trackDeepLinks | `true` |  automatically track deep links |
| flushAt | `20` |  count of events at which we flush events |
| flushInterval | `30` (seconds) |  interval in seconds at which we flush events
| defaultSettings | `{}` |  Settings object that will be used as fallback in case of network failure
| autoAddSegmentDestination | `true` |  automatically add SegmentDestination plugin, disable in case you want to add plugins to SegmentDestination
| apiHost | `api.segment.io/v1` |  set a default apiHost to which Segment sends event

You may notice that some configuration options such as IDFA collection and automatic screen tracking from our previous library have been removed.  
These options have been moved to distinct plugins that can be found in our [Plugin Examples repo](https://github.com/segmentio/analytics-example-plugins/tree/main/plugins/swift).
## Client Methods

### track
The track method is how you record any actions your users perform, along with any properties that describe the action.

Method signatures:
```swift
func track(name: String)
// This signature provides a typed version of properties.
func track<P: Codable>(name: String, properties: P?)
// Generic dictionary for properties
func track(name: String, properties: [String: Any]?)
```

Example usage:
```swift
struct TrackProperties: Codable {
	let someValue: String
}

// ...

analytics.track(name: "My Event", TrackProperties(someValue: "Hello"))

analytics.track(name: "Another Event", ["someValue": "Goodbye"])
```

### identify
The identify call lets you tie a user to their actions and record traits about them. This includes a unique user ID and any optional traits you know about them like their email, name, etc. The traits option can include any information you might want to tie to the user, but when using any of the reserved user traits, you should make sure to only use them for their intended meaning.

Method signatures:
```swift
// These signatures provide for a typed version of user traits
func identify<T: Codable>(userId: String, traits: T)
func identify<T: Codable>(traits: T)
func identify(userId: String)
```

Example Usage:
```swift
struct MyTraits: Codable {
	let favoriteColor: String
}

// ...

analytics.identify("someone@segment.com", MyTraits(favoriteColor: "fuscia"))
```

### screen
The screen call lets you record whenever a user sees a screen in your mobile app, along with any properties about the screen.

Method signatures:
```swift
func screen(screenTitle: String, category: String? = nil)
func screen<P: Codable>(screenTitle: String, category: String? = nil, properties: P?)
```

Example Usage:
```swift
analytics.screen(screenTitle: "SomeScreen")
```

You can enable automatic screen tracking by using the [example plugin](https://github.com/segmentio/analytics-example-plugins/blob/main/plugins/swift/UIKitScreenTracking.swift).

Once the plugin has been added to your project add it to your Analytics instance:
```swift
analytics.add(plugin: UIKitScreenTracking(name: "ScreenTracking", analytics: analytics))
```

### group
The group API call is how you associate an individual user with a group—be it a company, organization, account, project, team or whatever other crazy name you came up with for the same concept! This includes a unique group ID and any optional group traits you know about them like the company name industry, number of employees, etc. The traits option can include any information you might want to tie to the group, but when using any of the reserved group traits, you should make sure to only use them for their intended meaning.
Method signatures:
```swift
func group(groupId: String)
func group<T: Codable>(groupId: String, traits: T?)
```

Example Usage:
```swift
struct MyTraits: Codable {
	let username: String
	let email: String
	let plan: String
}

// ...

analytics.group("user-123", MyTraits(
	username: "MisterWhiskers",
	email: "hello@test.com",
	plan: "premium"))
```

### add
add API allows you to add a plugin to the analytics timeline

Method signature:
```swift
@discardableResult func add(plugin: Plugin) -> String
```

Example Usage:
```swift
analytics.add(plugin: UIKitScreenTracking(name: "ScreenTracking"))
```

### find
find a registered plugin from the analytics timeline

Method signature:
```swift
func find(pluginName: String) -> Plugin?
```

Example Usage:
```swift
let plugin = analytics.find("SomePlugin")
```

### remove
remove a registered plugin from the analytics timeline

Method signature:
```swift
func remove(pluginName: String)
```

Example Usage:
```swift
analytics.remove("SomePlugin")
```

### flush
flushes the current queue of events

Example Usage:
```swift
analytics.flush()
```

## Plugin Architecture
Our new plugin architecture enables you to modify/augment how the analytics client works completely. From modifying event payloads to changing analytics functionality, plugins are the easiest way to get things done.
Plugins are run through a timeline, which executes plugins in order of insertion based on their types.
We have the following [types]
- `before` _Executed before event processing begins_
- `enrichment` _Executed as the first level of event processing_
- `destination` _Executed as events begin to pass off to destinations_
- `after` _Executed after all event processing is completed.  This can be used to perform cleanup operations, etc_
- `utility` _Executed only when called manually, such as Logging_

### Fundamentals
We have 3 types of basic plugins that you can use as a foundation for modifying functionality

- `Plugin`
The most trivial plugin interface that will act on any event payload going through the timeline.
For example if you wanted to add something to the context object of any event payload as an enrichment.
```swift
class SomePlugin: Plugin {
	let type: PluginType = .enrichment
	let name: String
	let analytics: Analytics

	init(name: String) {
		self.name = name
	}
	
	override fun execute(event: BaseEvent): BaseEvent? {
		var workingEvent = event
		if var context = workingEvent?.context?.dictionaryValue {
			context[keyPath: "foo.bar"] = 12
			workingEvent?.context = try? JSON(context)
		}
		return workingEvent
	}
}
```

- `EventPlugin`
A plugin interface that will act only on specific event types. You can choose the event types by only overriding the event functions you want.
For example if you only wanted to act on `track` & `identify` events
```swift
class SomePlugin: EventPlugin {
	let type: PluginType = .enrichment
	let name: String
	let analytics: Analytics

	init(name: String) {
		self.name = name
	}

	func identify(event: IdentifyEvent) -> IdentifyEvent? {
		// code to modify identify event 
		return event
	}
	
	func track(event: TrackEvent) -> TrackEvent? {
		// code to modify track event
		return event
	}
}
```

- `DestinationPlugin`
A plugin interface most commonly used for device-mode destinations. This plugin contains an internal timeline that follows the same process as the analytics timeline,
allowing you to modify/augment how events reach the particular destination.
For example if you wanted to implement a device mode destination plugin for AppsFlyer
```swift
internal struct AppsFlyerSettings: Codable {
    let appsFlyerDevKey: String
    let appleAppID: String
    let trackAttributionData: Bool?
}

@objc
class AppsFlyerDestination: UIResponder, DestinationPlugin, UserActivities, RemoteNotifications {
    
    let timeline: Timeline = Timeline()
    let type: PluginType = .destination
    let name: String
    var analytics: Analytics?
    
    internal var settings: AppsFlyerSettings? = nil
    
     required init(name: String) {
        self.name = name
        analytics?.track(name: "AppsFlyer Loaded")
    }
    
    public func update(settings: Settings, type: UpdateType) {
        if type == .initial {
            // AppsFlyerLib is a singleton, we only want to set it up once.
            guard let settings: AppsFlyerSettings = settings.integrationSettings(name: "AppsFlyer") else {return}
            self.settings = settings
        
            AppsFlyerLib.shared().appsFlyerDevKey = settings.appsFlyerDevKey
            AppsFlyerLib.shared().appleAppID = settings.appleAppID
            AppsFlyerLib.shared().isDebug = true
            AppsFlyerLib.shared().deepLinkDelegate = self
        }
    
        // additional update logic
  }

// ...

analytics.add(plugin: AppsFlyerPlugin(name: "AppsFlyer"))
analytics.track("AppsFlyer Event")
```

### Advanced concepts
- `update(settings:)`
Use this function to react to any settings updates. This will be implicitly called when settings are updated.
- OS Lifecycle hooks
Plugins can also hook into lifecycle events by conforming to the platform appropriate protocol. These functions will get called implicitly as the lifecycle events are processed.
`iOSLifecycleEvents`
`macOSLifecycleEvents`
`watchOSLifecycleEvents`
`LinuxLifecycleEvents`
## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## Code of Conduct

Before contributing, please also see our [code of conduct](CODE_OF_CONDUCT.md).

## License

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
