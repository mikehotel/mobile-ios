//
//  BaseViewController.m
//  RaisedCenterTabBar
//
//  Created by Peter Boctor on 12/15/10.
//
// Copyright (c) 2011 Peter Boctor
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE
//
#import "BaseViewController.h"


// private
@interface BaseViewController() 
- (void) openTypeCamera;
- (NSMutableDictionary*)currentLocation;
- (UINavigationController*) getUINavigationController:(UIViewController *) controller forHomeScreen:(BOOL) home;
@end

@implementation BaseViewController

@synthesize appSettingsViewController,location;

- (OpenPhotoIASKAppSettingsViewController*)appSettingsViewController {
	if (!appSettingsViewController) {
		appSettingsViewController = [[OpenPhotoIASKAppSettingsViewController alloc] initWithNibName:@"IASKAppSettingsView" bundle:nil];
		appSettingsViewController.delegate = self;
	}
	return appSettingsViewController;
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForKey:(NSString*)key {
    if ([key isEqualToString:@"TestFlighFeed"]){
        [TestFlight openFeedbackView];
    }else if ([key isEqualToString:@"CleanCache"]){
        [GalleryPhotos deleteAllGalleryPhotosInManagedObjectContext:[AppDelegate managedObjectContext]];
        [TimelinePhotos deleteAllTimelineInManagedObjectContext:[AppDelegate managedObjectContext]];
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    coreLocationController = [[CoreLocationController alloc] init];
    coreLocationController.delegate = self;
    
    // for access local images
    assetsLibrary = [[ALAssetsLibrary alloc] init]; 
}

// Create a view controller and setup it's tab bar item with a title and image
-(UIViewController*) viewControllerWithTabTitle:(NSString*) title image:(UIImage*)image
{  
    // Here we keep the link of what is in the BAR and its Controllers
    if (title == @"Home"){
        HomeTableViewController *controller = [[[HomeTableViewController alloc]init]autorelease];
        controller.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:image tag:0] autorelease];
        
        // if it answers to appearance
        if([[UITabBar class] respondsToSelector:@selector(appearance)]){
            // from iOS 5.0
            [controller.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"tab-icon1_active.png"] withFinishedUnselectedImage:image];
        }
        return [self getUINavigationController:controller forHomeScreen:YES];
    }else if (title == @"Gallery"){
        GalleryViewController *controller = [[[GalleryViewController alloc]init] autorelease];
        controller.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:image tag:1] autorelease];
        
        // if it answers to appearance
        if([[UITabBar class] respondsToSelector:@selector(appearance)]){
            // from iOS 5.0
            [controller.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"tab-icon2_active.png"] withFinishedUnselectedImage:image];
        }
        
        return [self getUINavigationController:controller forHomeScreen:NO];
    }else if (title == @"Sync"){
        SyncViewController *photoPicker = [[[SyncViewController alloc]init]autorelease];   
        ELCImagePickerController *controller = [[[ELCImagePickerController alloc] initWithRootViewController:photoPicker] autorelease];
        controller.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:image tag:3] autorelease];      
        // if it answers to appearance
        if([[UITabBar class] respondsToSelector:@selector(appearance)]){
            // from iOS 5.0
            [controller.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"tab-icon6_active.png"] withFinishedUnselectedImage:image];       
        }
        [photoPicker setParent:controller];
        [controller setDelegate:self];
        return controller;
    }else if (title == @"Settings"){
        [self.appSettingsViewController setShowCreditsFooter:NO];   
        self.appSettingsViewController.showDoneButton = NO; 
        
        UINavigationController *controller = [self getUINavigationController:self.appSettingsViewController forHomeScreen:NO];
        controller.tabBarItem = [[[UITabBarItem alloc] initWithTitle:title image:image tag:4] autorelease];
        
        // if it answers to appearance
        if([[UITabBar class] respondsToSelector:@selector(appearance)]){
            // from iOS 5.0
            [controller.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"tab-icon5_active.png"] withFinishedUnselectedImage:image];
        }
        
        return controller;
    }  
    
    UIViewController* viewController = [[[UIViewController alloc] init] autorelease];
    viewController.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Photo" image:nil tag:2] autorelease];
    
    // if it answers to appearance
    if([[UITabBar class] respondsToSelector:@selector(appearance)]){
        // from iOS 5.0
        [viewController.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"tab-icon4_active.png"] withFinishedUnselectedImage:image];
        
    }
    return viewController;
    
}

- (UINavigationController*) getUINavigationController:(UIViewController *) controller forHomeScreen:(BOOL) home{
    UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:controller] autorelease];
    navController.navigationBar.barStyle=UIBarStyleBlackOpaque;
    navController.navigationController.navigationBar.barStyle=UIBarStyleBlackOpaque;
    [navController.navigationBar setBackgroundColor:[UIColor blackColor]];
    
    
    UIImage *backgroundImage;
    if ( home == YES){
        backgroundImage = [UIImage imageNamed:@"home-openphoto-bar.png"];
    }else {
        backgroundImage = [UIImage imageNamed:@"appbar_empty.png"];
    } 
    
    // image for the navigator
    if([[UINavigationBar class] respondsToSelector:@selector(appearance)]){
        //iOS >=5.0
        [navController.navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    }else{
        UIImageView *imageView = (UIImageView *)[navController.navigationBar viewWithTag:6183746];
        if (imageView == nil)
        {
            imageView = [[UIImageView alloc] initWithImage:backgroundImage];
            [imageView setTag:6183746];
            [navController.navigationBar insertSubview:imageView atIndex:0];
            [imageView release];
        }
    }
    
    return navController;
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    [self dismissModalViewControllerAnimated:YES];
}

// Create a custom UIButton and add it to the center of our tab bar
-(void) addCenterButtonWithImage:(UIImage*)buttonImage highlightImage:(UIImage*)highlightImage
{
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin;
    button.frame = CGRectMake(0.0, 0.0, buttonImage.size.width, buttonImage.size.height);
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [button setBackgroundImage:highlightImage forState:UIControlStateHighlighted];
    
    CGFloat heightDifference = buttonImage.size.height - self.tabBar.frame.size.height;
    
    if (heightDifference < 0){
        button.center = self.tabBar.center;
    }else{
        CGPoint center = self.tabBar.center;
        center.y =self.tabBar.frame.size.height-(buttonImage.size.height/2.0);
        button.center = center;
    }
    
    // action for this button
    [button addTarget:self action:@selector(buttonEvent) forControlEvents:UIControlEventTouchUpInside];    
    [self.tabBar addSubview:button];
}

-(void)buttonEvent{
    // check if user has camera
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]){
        OpenPhotoAlertView *alert = [[OpenPhotoAlertView alloc] initWithMessage:@"Your device hasn't a camera" duration:5000];
        [alert showAlert];
        [alert release];
    }else{
        // start localtion
        [coreLocationController.locMgr startUpdatingLocation];
        [self openTypeCamera];
    }
}

-(void) openTypeCamera{
    UIImagePickerController *pickerController = [[UIImagePickerController
                                                  alloc]
                                                 init];
    pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    pickerController.delegate = self;
    [self presentModalViewController:pickerController animated:YES];
    [pickerController release];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    // the image itself to save in the library
    UIImage *pickedImage = [info
                            objectForKey:UIImagePickerControllerOriginalImage];
    
    // User come from Snapshot. We will temporary save in the Library. 
    // If in the Settings is configure to not save in the library, we will delete
    NSMutableDictionary *exif = nil;
    
    // check if metadata is available
    if ([info objectForKey:UIImagePickerControllerMediaMetadata] != nil) {
        exif = [NSMutableDictionary dictionaryWithDictionary:[info objectForKey:UIImagePickerControllerMediaMetadata]];
        
        
        NSDictionary *gpsDict  = [self currentLocation];
        if ([gpsDict count] > 0) {
#ifdef DEVELOPMENT_ENABLED
            NSLog(@"There is location");
#endif
            [exif setObject:gpsDict forKey:(NSString*) kCGImagePropertyGPSDictionary];
        }else{
#ifdef DEVELOPMENT_ENABLED
            NSLog(@"No location found");
#endif
        }
        
    }
    
    [assetsLibrary writeImageToSavedPhotosAlbum:[pickedImage CGImage] metadata:exif completionBlock:^(NSURL *newUrl, NSError *error) {
        if (error) {
            NSLog(@"The photo took by the user could not be saved = %@", [error description]);
        } else {
            PhotoViewController* controller = [[PhotoViewController alloc]initWithNibName:@"PhotoViewController" bundle:nil url:newUrl image:pickedImage];
            [picker pushViewController:controller animated:YES];
            [controller release];
        }
    }];
    
    
    // stop location
    [coreLocationController.locMgr stopUpdatingLocation];  
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissModalViewControllerAnimated:YES];
    [coreLocationController.locMgr stopUpdatingLocation];    
}


//Creates an EXIF field for the current geo location.
- (NSMutableDictionary*)currentLocation {
    NSMutableDictionary *locDict = [[NSMutableDictionary alloc] init];
	
	if (self.location != nil) {
		CLLocationDegrees exifLatitude = self.location.coordinate.latitude;
		CLLocationDegrees exifLongitude = self.location.coordinate.longitude;
        
		[locDict setObject:self.location.timestamp forKey:(NSString*) kCGImagePropertyGPSTimeStamp];
		
		if (exifLatitude < 0.0) {
			exifLatitude = exifLatitude*(-1);
			[locDict setObject:@"S" forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
		} else {
			[locDict setObject:@"N" forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
		}
		[locDict setObject:[NSNumber numberWithFloat:exifLatitude] forKey:(NSString*)kCGImagePropertyGPSLatitude];
        
		if (exifLongitude < 0.0) {
			exifLongitude=exifLongitude*(-1);
			[locDict setObject:@"W" forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
		} else {
			[locDict setObject:@"E" forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
		}
		[locDict setObject:[NSNumber numberWithFloat:exifLongitude] forKey:(NSString*) kCGImagePropertyGPSLongitude];
	}
	
    return [locDict autorelease];
    
}

- (void)locationUpdate:(CLLocation *)position{
    self.location = position;
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Position %@", position);
#endif
}

- (void)locationError:(NSError *)error {
    NSLog(@"Location error %@", [error description]);
    
    if ([error code] == kCLErrorDenied){
        // validate if we had checked once if user allowed location
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        if (standardUserDefaults) {
            
            if (![[NSUserDefaults standardUserDefaults] boolForKey:kValidateNotAllowedLocation] || 
                [[NSUserDefaults standardUserDefaults] boolForKey:kValidateNotAllowedLocation] == NO){
                // validated
                [standardUserDefaults setBool:YES forKey:kValidateNotAllowedLocation];
                
                // synchronize the keys
                [standardUserDefaults synchronize];
                
#ifdef TEST_FLIGHT_ENABLED
                [TestFlight passCheckpoint:@"Not allowed location"];
#endif                 
            }
        }
    }
}

// Sync 
#pragma mark ELCImagePickerControllerDelegate Methods

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info {	
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Selected some images");
#endif
    
    if (info != nil && [info count]>0 ){
        // convert to nsarray
        NSMutableArray *urls = [NSMutableArray array];
        for(NSDictionary *dict in info) {
            [urls addObject:[dict objectForKey:UIImagePickerControllerReferenceURL]];
        }
        
        PhotoViewController* controller = [[PhotoViewController alloc]initWithNibName:@"PhotoViewController" bundle:nil images:urls];
        [picker pushViewController:controller animated:YES];
        [controller release];
    }else{
        // no photo select
        OpenPhotoAlertView *alert = [[OpenPhotoAlertView alloc] initWithMessage:@"Please select at least 1 photo!" duration:5000];
        [alert showAlert];
        [alert release];
        
        // go to the home
        [AppDelegate openTab:0];
    }
    
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker {
    // this one is not used.
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Cancel Sync");
#endif
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    return YES;
}


- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    if (item.tag == 1)
    {
        // set that needs update - Gallery
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNeededsUpdate object:nil];
        
    }
}

- (void)dealloc {
    [appSettingsViewController release];
    appSettingsViewController = nil;
    [coreLocationController release];
    [location release];
    [assetsLibrary release];
    
    [super dealloc];
}

@end
