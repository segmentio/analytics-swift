//
//  AppDelegate.m
//  ObjCExample
//
//  Created by Brandon Sneed on 8/13/21.
//

#import "AppDelegate.h"

@import Segment;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    SEGConfiguration *config = [[SEGConfiguration alloc] initWithWriteKey:@"WRITE_KEY"];
    config.trackApplicationLifecycleEvents = TRUE;
    
    SEGAnalytics *analytics = [[SEGAnalytics alloc] initWithConfiguration: config];
    [analytics track:@"test" properties:@{@"email": @"blah@blah.com"}];
    
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
