//
//  AppDelegate.m
//  ObjCExample
//
//  Created by Brandon Sneed on 8/13/21.
//

#import "AppDelegate.h"
#import "ObjCExample-Swift.h"

@import Segment;
@import SegmentMixpanel;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    SEGConfiguration *config = [[SEGConfiguration alloc] initWithWriteKey:@"<WRITE KEY>"];
    config.trackApplicationLifecycleEvents = YES;
    config.flushAt = 1;
    
    _analytics = [[SEGAnalytics alloc] initWithConfiguration: config];
    
    [self.analytics track:@"test"];
    [self.analytics track:@"testProps" properties:@{@"email": @"blah@blah.com"}];
    
    [self.analytics flush];
    
    SEGTestDestination *testDestination = [[SEGTestDestination alloc] init];
    [self.analytics addPlugin:testDestination];
    
    SEGBlockPlugin *customizeAllTrackCalls = [[SEGBlockPlugin alloc] initWithBlock:^id<SEGRawEvent> _Nullable(id<SEGRawEvent> _Nullable event) {
        if ([event isKindOfClass: [SEGTrackEvent class]]) {
            SEGTrackEvent *track = (SEGTrackEvent *)event;
            // change the name
            NSString *newName = [NSString stringWithFormat: @"[New] %@", track.event];
            track.event = newName;
            // add a property
            NSMutableDictionary *newProps = (track.properties != nil) ? [track.properties mutableCopy] : [@{} mutableCopy];
            newProps[@"customAttribute"] = @"Hello";
            track.properties = newProps;
            
            return track;
        }
        return event;
    }];
    
    [self.analytics addPlugin:customizeAllTrackCalls];
    
    SEGBlockPlugin *booyaAllTrackCalls = [[SEGBlockPlugin alloc] initWithBlock:^id<SEGRawEvent> _Nullable(id<SEGRawEvent> _Nullable event) {
        if ([event isKindOfClass: [SEGTrackEvent class]]) {
            SEGTrackEvent *track = (SEGTrackEvent *)event;
            // change the name
            NSString *newName = [NSString stringWithFormat: @"[Booya] %@", track.event];
            track.event = newName;
            // add a property
            NSMutableDictionary *newProps = (track.properties != nil) ? [track.properties mutableCopy] : [@{} mutableCopy];
            newProps[@"customAttribute"] = @"Booya!";
            track.properties = newProps;
            
            return track;
        }
        return event;
    }];
    
    [self.analytics addPlugin:booyaAllTrackCalls destinationKey:@"Segment.io"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.analytics track:@"schneeble schnobble"];
    });
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
