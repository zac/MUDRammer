//
//  SSAppDelegate.m
//  Mudrammer
//
//  Created by Jonathan Hersh on 10/21/12.
//  Copyright (c) 2012 Jonathan Hersh. All rights reserved.
//

#import "SSAppDelegate.h"
#import "SSClientContainer.h"
#import "SSRadialControl.h"
#import "SSWorldDisplayController.h"
#import <IFTTTSplashView.h>
#import <Keys/MudrammerKeys.h>
#import <MagicalRecord/MagicalRecord.h>

@interface SSAppDelegate ()
+ (void) setupCoreData;
@end

@implementation SSAppDelegate

#pragma mark - setup and scaffolding

+ (void)setupCoreData {
#ifdef DEBUG
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelAll];
#else
    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelOff];
#endif
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:kStoreName];
}

#pragma mark - URL tapped

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {

    if (!url || ![url host]) {
        return NO;
    }

    if ([[url scheme] isEqualToString:@"telnet"]) {

        // Is this world already saved?
        World *existing = [World MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"hostname == %@ AND isHidden == NO",
                                                            [[url host] lowercaseString]]
                                                  sortedBy:[World defaultSortField]
                                                 ascending:[World defaultSortAscending]
                                                 inContext:[NSManagedObjectContext MR_defaultContext]];

        if (!existing) {
            World *w = [World worldFromURL:url];
            w.isHidden = @NO;
            [w saveObjectWithCompletion:^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationWorldChanged
                                                                    object:[w objectID]];
            }
                                   fail:nil];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationWorldChanged
                                                                object:[existing objectID]];
        }

        return YES;
    }

    return NO;
}

#pragma mark - SSApplication

- (void) ss_willFinishLaunchingWithOptions:(NSDictionary *)options {
    [[IFTTTSplashView sharedSplash] showSplash];

    [self.class setupCoreData];

    [World createDefaultWorldsIfNecessary];

    [SSThemes sharedThemer]; // UIAppearance™ Inside®

    self.idleTimerDisabled = YES;
    self.applicationSupportsShakeToEdit = NO;

    // disallow webview cache
    NSURLCache *sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
    [NSURLCache setSharedURLCache:sharedCache];

    _notificationObserver = [SPLNotificationManager new];
}

- (void) ss_willLaunchBackgroundSetup {

}

- (UIViewController *) ss_appRootViewController {
    return [SSClientContainer new];
}

- (NSDictionary *) ss_defaultUserDefaults {
    return @{
             kPrefInitialWorldsCreated  : @NO,
             kPrefLocalEcho             : @YES,
             kPrefAutocorrect           : @NO,
             kPrefMoveControl           : @(SSRadialControlPositionRight),
             kPrefConnectOnStartup      : @YES,
             kPrefStringEncoding        : @"ASCII",
             kPrefKeyboardStyle         : @YES,
             kPrefRadialControl         : @(SSRadialControlPositionLeft),
             kPrefRadialCommands        : @[ @"up", @"in", @"down", @"out", @"look" ],
             kPrefTopBarAlwaysVisible   : @NO,
             kPrefAutocapitalization    : @NO,
             kPrefBTKeyboard            : @NO,
             kPrefSemicolonCommands     : @YES,
             kPrefSemicolonCommandDelimiter : kPrefSemicolonDefaultDelimiter,
    };
}

- (void) ss_receivedApplicationEvent:(SSApplicationEvent)eventType {

    switch (eventType) {
        case SSApplicationEventDidBecomeActive:

            [[UIApplication sharedApplication] cancelAllLocalNotifications];

            [SSRadialControl validateRadialPositions];

            break;

        case SSApplicationEventWillEnterForeground:
        case SSApplicationEventDidEnterBackground:
        case SSApplicationEventWillResignActive:

            break;

        case SSApplicationEventWillTerminate:

            [[UIApplication sharedApplication] cancelAllLocalNotifications];

            [MagicalRecord cleanUp];

            break;

        default:
            break;
    }
}

#pragma mark - Notifications

- (void)application:(UIApplication *)application
didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [self.notificationObserver didRegisterUserNotificationSettings:notificationSettings];
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)(void))completionHandler {
    [self.notificationObserver handleActionWithIdentifier:identifier
                                     forLocalNotification:notification
                                               completion:completionHandler];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {

}

@end
