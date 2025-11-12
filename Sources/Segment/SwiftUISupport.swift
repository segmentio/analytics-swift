//
//  SwiftUISupport.swift
//  Segment
//
//  Created by Brandon Sneed on 11/3/25.
//

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
struct AnalyticsLifecycleModifier: ViewModifier {
    let analytics: Analytics
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousPhase: ScenePhase?
    @State private var hasLaunched = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                handleInitialLaunch()
            }
            .onChange(of: scenePhase) { newPhase in
                handlePhaseChange(newPhase)
            }
    }
    
    private func handleInitialLaunch() {
        guard !hasLaunched else { return }
        
        // First launch - check install/update and track opened
        analytics.checkAndTrackInstallOrUpdate()
        
        if analytics.configuration.values.trackedApplicationLifecycleEvents.contains(.applicationOpened) {
            analytics.trackApplicationOpened(fromBackground: false)
        }
        
        hasLaunched = true
        previousPhase = scenePhase
    }
    
    private func handlePhaseChange(_ newPhase: ScenePhase) {
        defer { previousPhase = newPhase }
        
        // Only handle transitions after initial launch
        guard hasLaunched else { return }
        
        let config = analytics.configuration.values.trackedApplicationLifecycleEvents
        
        switch (previousPhase, newPhase) {
        case (.background, .active):
            // Coming from background to foreground
            if config.contains(.applicationOpened) {
                analytics.trackApplicationOpened(fromBackground: true)
            }
            if config.contains(.applicationForegrounded) {
                analytics.trackApplicationForegrounded()
            }
            
        case (.active, .background), (.inactive, .background):
            // Going to background
            /// NOTE: this isn't needed because the regular lifecycle notifications capture this.
            /*if config.contains(.applicationBackgrounded) {
                analytics.trackApplicationBackgrounded()
            }*/
            break
            
        case (.background, .inactive):
            // Transitioning from background through inactive to active
            // Don't track anything here, wait for .active
            break
            
        case (.active, .inactive):
            // Brief interruption (like control center pull-down)
            // Don't track as background yet
            break
            
        case (.inactive, .active):
            // Resuming from brief interruption
            // Don't track as opened from background
            break
            
        default:
            break
        }
    }
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
public extension View {
    /// Automatically tracks Analytics lifecycle events for SwiftUI apps.
    ///
    /// Attach this modifier to your root view to enable automatic tracking of:
    /// - Application Installed (first launch only)
    /// - Application Updated (when version/build changes)
    /// - Application Opened (cold start and from background)
    /// - Application Backgrounded
    /// - Application Foregrounded
    ///
    /// Example:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     let analytics = Analytics(configuration: config)
    ///
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///                 .trackAnalyticsLifecycle(analytics)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter analytics: The Analytics instance to track events with
    /// - Returns: A view with lifecycle tracking enabled
    func trackAnalyticsLifecycle(_ analytics: Analytics) -> some View {
        self.modifier(AnalyticsLifecycleModifier(analytics: analytics))
    }
}

#endif
