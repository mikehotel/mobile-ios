//
//  OpenPhotoAppDelegate.m
//  OpenPhoto
//
//  Created by Patrick Santana on 28/07/11.
//  Copyright 2012 OpenPhoto
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
#import "OpenPhotoAppDelegate.h"
#import "OpenPhotoViewController.h"



@interface OpenPhotoAppDelegate()
-(void) shareTwitterOrFacebook:(NSString *) message;
-(void) prepareConnectionInformation;
-(void) checkNetworkStatus:(NSNotification *) notice;
@end

@implementation OpenPhotoAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize internetActive = _internetActive;
@synthesize hostActive = _hostActive;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    // Allow HTTP response size to be unlimited.
    [[TTURLRequestQueue mainQueue] setMaxContentLength:0];
    
    // Configure the in-memory image cache to keep approximately
    // 20 images in memory, assuming that each picture's dimensions
    // are 640x960. Note that your images can have whatever dimensions
    // you want, I am just setting this to a reasonable value
    // since the default is unlimited.
    [[TTURLCache sharedCache] setMaxPixelCount:20*640*960];
    
    // in development phase we use the UID of user
#ifdef DEVELOPMENT_ENABLED
    [TestFlight setDeviceIdentifier:[[UIDevice currentDevice] uniqueIdentifier]];
#endif
    
#ifdef TEST_FLIGHT_ENABLED
    // to start the TestFlight SDK
    [TestFlight takeOff:@"407f45aed7c5bc2fc88cb567078edb1f_MjMyNTUyMDExLTA5LTEyIDEyOjEyOjU3Ljc1Nzg5MA"];
#endif
    
    [self prepareConnectionInformation];
    
    UpdateUtilities *updater = [UpdateUtilities instance];
    if ([updater needsUpdate] == YES){
        
#ifdef DEVELOPMENT_ENABLED
        NSLog(@"App needs to be updated");
        NSLog(@"Version to install %@", [updater getVersion]);
#endif
        
        [updater update];
    }
    
    
    InitializerHelper *helper = [[InitializerHelper alloc]init];
    if ([helper isInitialized] == NO){
        [helper initialize];
    }
    [helper release];
    
    
    // open the default view controller
    self.window.rootViewController = self.viewController;
    
    // now if it is not authenticated, show the screen in the TOP of the view controller
    // check if user is authenticated or not
    AuthenticationHelper *auth = [[AuthenticationHelper alloc]init];
    if ([auth isValid]== NO){
        // open the authentication screen
        AuthenticationViewController *controller = [[AuthenticationViewController alloc]init];
        [self.window.rootViewController presentModalViewController:controller animated:YES];
        [controller release];
    }
    [auth release];
    [self.window makeKeyAndVisible];
    
    //register to share data.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(eventHandler:)
                                                 name:kNotificationShareInformationToFacebookOrTwitter
                                               object:nil ];
    
    // start the job
    [[JobUploaderController getController] start];
    return YES;
}


+ (void) initialize
{
    //configure iRate
    [iRate sharedInstance].daysUntilPrompt = 10;
    [iRate sharedInstance].usesUntilPrompt = 6;
    [iRate sharedInstance].appStoreID = 511845345;
    [iRate sharedInstance].applicationBundleID = @"me.OpenPhoto.ios";
    [iRate sharedInstance].applicationName=@"OpenPhoto";
}


- (void) openTab:(int) position{
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Opening the tab with position id = %i",position);
#endif
    
    if (position == 0 || position == 1 || position == 3 || position == 4){
        UIViewController *controller = self.window.rootViewController;
        if ([controller isKindOfClass:[OpenPhotoViewController class]]){
            [((OpenPhotoViewController*) controller) setSelectedIndex:position];
        }
    }else{
        NSException *exception = [NSException exceptionWithName: @"IncorrectPosition"
                                                         reason: [NSString stringWithFormat:@"Position %i is not support to open the tab. Please, select 0,1,3 or 4",position]
                                                       userInfo: nil];
        @throw exception;
    }
}


//event handler when event occurs
-(void)eventHandler: (NSNotification *) notification
{
    if ([notification.name isEqualToString:kNotificationShareInformationToFacebookOrTwitter]){
        [self performSelector:@selector(shareTwitterOrFacebook:) withObject:notification afterDelay:1.0f];
    }
}

- (void) shareTwitterOrFacebook:(NSNotification*) notification{
    NSDictionary *dictionary = [notification object];
    
    // create the item
    SHKItem *item = [SHKItem URL:[NSURL URLWithString:[dictionary objectForKey:@"url"]] title:[dictionary objectForKey:@"title"]];
    
    if ( [[dictionary objectForKey:@"type"] isEqualToString:@"Twitter"]){
        // send a tweet
        [SHKTwitter shareItem:item];
    }else{
        // facebook
        [SHKFacebook shareItem:item];
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Application should handleOpenUrl = %@",url);
#endif
    
    // the "openphoto-test" is used for TestFlight tester
    if ([[url scheme] isEqualToString:@"openphoto"] ||
        [[url scheme] isEqualToString:@"openphoto-test"]){
        AuthenticationHelper *auth = [[AuthenticationHelper alloc]init];
        
        if ([auth isValid] == NO){
            [auth startOAuthProcedure:url];
        }
        
        [auth release];
    }else if ([[url scheme] hasPrefix:[NSString stringWithFormat:@"fb%@", SHKCONFIG(facebookAppId)]]){
        return [SHKFacebook handleOpenURL:url];
    }
    
    return YES;
}



- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"App applicationWillResignActived, save database");
#endif
    
    // set the Timeline objects with state Uploading to RETRY
    [TimelinePhotos resetEntitiesOnStateUploadingInManagedObjectContext:[AppDelegate managedObjectContext]];
    
    NSError *saveError = nil;
    if (![[AppDelegate managedObjectContext] save:&saveError]){
        NSLog(@"Error to save context = %@",[saveError localizedDescription]);
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
    
    // set the Timeline objects with state Uploading to RETRY
    [TimelinePhotos resetEntitiesOnStateUploadingInManagedObjectContext:[AppDelegate managedObjectContext]];
    
    NSError *saveError = nil;
    if (![[AppDelegate managedObjectContext] save:&saveError]){
        NSLog(@"Error to save context = %@",[saveError localizedDescription]);
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
    NSError *saveError = nil;
    if (![[AppDelegate managedObjectContext] save:&saveError]){
        NSLog(@"Error to save context = %@",[saveError localizedDescription]);
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    // needs to update the Sync
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationUpdateTableWithAllPhotosAgain object:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"App will terminate, save database");
#endif
    
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    NSError *saveError = nil;
    if (![[AppDelegate managedObjectContext] save:&saveError]){
        NSLog(@"Error to save context = %@",[saveError localizedDescription]);
    }
}


//////// CORE DATA
#pragma mark -
#pragma mark Core Data stack

- (NSManagedObjectContext *) managedObjectContext {
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    NSURL *storeUrl = [self getStoreUrl];
    
    // automatic update
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    
    NSError *error = nil;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                  initWithManagedObjectModel:[self managedObjectModel]];
    if(![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                 configuration:nil URL:storeUrl options:options error:&error]) {
        NSLog(@"Unresolved error with PersistStoreCoordinator %@, %@.", error, [error userInfo]);
        NSLog(@"Create the persistent file again.");
        
        // let's recreate it
        [managedObjectContext reset];
        [managedObjectContext lock];
        
        // delete file
        if ([[NSFileManager defaultManager] fileExistsAtPath:storeUrl.path]) {
            if (![[NSFileManager defaultManager] removeItemAtPath:storeUrl.path error:&error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
        
        [persistentStoreCoordinator release];
        persistentStoreCoordinator = nil;
        
        NSPersistentStoreCoordinator *r = [self persistentStoreCoordinator];
        [managedObjectContext unlock];
        
        return r;
        
    }
    
    return persistentStoreCoordinator;
}

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

- (NSURL *) getStoreUrl{
    return [NSURL fileURLWithPath: [[self applicationDocumentsDirectory]
                                    stringByAppendingPathComponent: @"OpenPhotoCoreData.sqlite"]];
}

- (void) cleanDatabase{
    // let's recreate it
    if (managedObjectContext != nil){
        [managedObjectContext reset];
        [managedObjectContext lock];
    }
    
    // delete file
    NSURL *storeUrl = [self getStoreUrl];
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:storeUrl.path]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:storeUrl.path error:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
    
    [persistentStoreCoordinator release];
    persistentStoreCoordinator = nil;
    
    if (managedObjectContext != nil){
        [managedObjectContext unlock];
        [managedObjectContext release];
        managedObjectContext = nil;
    }
}

- (NSString *) user
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:kOpenPhotoServer];
}


//////// Internet details
#pragma mark -
#pragma mark Internet details
- (void) prepareConnectionInformation
{
    // check for internet connection
    // no internet assume
    self.internetActive = NO;
    self.hostActive = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkNetworkStatus:) name:kReachabilityChangedNotification object:nil];
    
    internetReachable = [[Reachability reachabilityForInternetConnection] retain];
    [internetReachable startNotifier];
    
    // check if a pathway to a random host exists
    hostReachable = [[Reachability reachabilityWithHostName: @"www.apple.com"] retain];
    [hostReachable startNotifier];
    
    // do the first network check
    [self checkNetworkStatus:nil];
}

- (void) checkNetworkStatus:(NSNotification *)notice
{
    // called after network status changes
    NetworkStatus internetStatus = [internetReachable currentReachabilityStatus];
    switch (internetStatus)
    
    {
        case NotReachable:
        {
            self.internetActive = NO;
            break;
        }
        case ReachableViaWiFi:
        {
            self.internetActive = YES;
            break;
        }
        case ReachableViaWWAN:
        {
            self.internetActive = YES;
            break;
        }
    }
    
    
    NetworkStatus hostStatus = [hostReachable currentReachabilityStatus];
    switch (hostStatus)
    {
        case NotReachable:
        {
            self.hostActive = NO;
            break;
        }
        case ReachableViaWiFi:
        {
            self.hostActive = YES;
            break;
        }
        case ReachableViaWWAN:
        {
            self.hostActive = YES;
            break;
        }
    }
}


- (void)dealloc
{
    [_window release];
    [_viewController release];
    [managedObjectContext release];
    [managedObjectModel release];
    [persistentStoreCoordinator release];
    [internetReachable release];
    [hostReachable release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
