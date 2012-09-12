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

#import "PhotoSource.h"

@implementation PhotoSource

@synthesize title = _title;
@synthesize tagName = _tagName;
@synthesize numberOfPhotos = _numberOfPhotos;
@synthesize currentPage = _currentPage;
@synthesize actualMaxPhotoIndex = _actualMaxPhotoIndex;
@synthesize service;
@synthesize photos;

BOOL isLoading = NO;

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)initWithTitle:(NSString*)title photos:(NSArray*)listPhotos size:(int) size tag:(NSString*) tag{
    if (self = [super init]) {
        _title = [title copy];
        self.photos =  [listPhotos mutableCopy];
        _numberOfPhotos = size;
        _tagName = tag;
        
        // the first page
        _currentPage = 1;        
        self.actualMaxPhotoIndex = 24;
        
        // create service and the delegate
        WebService *web = [[WebService alloc]init];
        self.service = web;
        [service setDelegate:self];
        [web release];
        
        for (int i = 0; i < self.photos.count; ++i) {
            id<TTPhoto> photo = [self.photos objectAtIndex:i];
            if ((NSNull*)photo != [NSNull null]) {
                photo.photoSource = self;
                photo.index = i;
            }
        }
    }
    return self;
}

- (id)init {
    return [self initWithTitle:nil photos:nil size:0 tag:nil];
}

- (void)dealloc {
    TT_RELEASE_SAFELY(_title);
    [service release];
    [photos release];
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTModel
- (BOOL)isLoaded {
    return !!self.photos;
}

- (BOOL) isLoading{
    return isLoading;
}

- (void)load:(TTURLRequestCachePolicy)cachePolicy more:(BOOL)more {
    if (cachePolicy & TTURLRequestCachePolicyNetwork) {
        _currentPage++;
        self.actualMaxPhotoIndex = self.actualMaxPhotoIndex+24;
        
        if (self.photos != nil && _title != nil && _currentPage > 1){
            isLoading = YES;
            [_delegates perform:@selector(modelDidStartLoad:) withObject:self];
            
            NSArray *keys;           
            NSArray *objects;
            NSNumber* number=[NSNumber numberWithInt:_currentPage];
            
            if (_tagName != nil){
                keys = [NSArray arrayWithObjects:@"tag", @"page",nil];
                objects= [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@", _tagName], number, nil];  
            }else{
                keys = [NSArray arrayWithObjects:@"page",nil];
                objects= [NSArray arrayWithObjects:number, nil];
            }
            NSDictionary *values = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
            
            // to send the request we add a thread.
            [NSThread detachNewThreadSelector:@selector(loadNewPhotosOnDetachTread:) 
                                     toTarget:self 
                                   withObject:values];
        }
    }
}
-(void) loadNewPhotosOnDetachTread:(NSDictionary*) values
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if ([values objectForKey:@"tag"] == nil){
        [service loadGallery:24 onPage:[[values objectForKey:@"page"] intValue] ];
    }else{
        [service loadGallery:24 withTag:[values objectForKey:@"tag"]  onPage:[[values objectForKey:@"page"] intValue] ];
    } 
    
    [pool release];
}


- (void)cancel {
    isLoading = NO;
}

- (void) notifyUserNoInternet{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // problem with internet, show message to user    
    OpenPhotoAlertView *alert = [[OpenPhotoAlertView alloc] initWithMessage:@"Failed! Check your internet connection" duration:5000];
    [alert showAlert];
    [alert release];
    
    
    // Finishes
    isLoading = NO;
    [_delegates perform:@selector(modelDidFinishLoad:) withObject:self];

}

// delegate to add more pictures 
-(void) receivedResponse:(NSDictionary *)response{
    // check if message is valid
    if (![WebService isMessageValid:response]){
        NSString* message = [WebService getResponseMessage:response];
        NSLog(@"Invalid response = %@",message);
        
        // show alert to user
        OpenPhotoAlertView *alert = [[OpenPhotoAlertView alloc] initWithMessage:message duration:5000];
        [alert showAlert];
        [alert release];
        
        // Finishes
        isLoading = NO;
        [_delegates perform:@selector(modelDidFinishLoad:) withObject:self];
        
        return;
    }
    
    NSArray *responsePhotos = [response objectForKey:@"result"] ;
    NSMutableArray *localPhotos = [[NSMutableArray alloc] init];
    int photoId=self.photos.count;
    
    // result can be null
    if ([responsePhotos class] != [NSNull class]) {
        
        // Loop through each entry in the dictionary and create an array of MockPhoto
        for (NSDictionary *photo in responsePhotos){           
            // Get title of the image
            NSString *title = [photo objectForKey:@"title"];
            if ([title class] == [NSNull class])
                title = @"";
            
#ifdef DEVELOPMENT_ENABLED                
            NSLog(@"Photo Add More url [%@] with tile [%@]", [photo objectForKey:@"path200x200"],title);
#endif            
            
            float width = [[photo objectForKey:@"width"] floatValue];
            float height = [[photo objectForKey:@"height"] floatValue];
            
            // calculate the real size of the image. It will keep the aspect ratio.
            float realWidth = 0;
            float realHeight = 0;
            
            if(width/height >= 1) { 
                // portrait or square
                realWidth = 640;
                realHeight = height/width*640;
            } else { 
                // landscape
                realHeight = 960;
                realWidth = width/height*960;
            }
            Photo* obj = [[[Photo alloc]
                           initWithURL:[NSString stringWithFormat:@"%@", [photo objectForKey:@"path640x960"]]
                           smallURL:[NSString stringWithFormat:@"%@",[photo objectForKey:@"path200x200"]] 
                           size:CGSizeMake(realWidth, realHeight) caption:title page:[NSString stringWithFormat:@"%@",[photo objectForKey:@"url"]]] autorelease];
            obj.index=photoId;
            obj.photoSource = self;
            // add to array
            [localPhotos addObject:obj];
            // index photo
            photoId++;
        } 
    }
    [self.photos addObjectsFromArray:localPhotos];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // Finishes
    isLoading = NO;
    [localPhotos release];
    [_delegates perform:@selector(modelDidFinishLoad:) withObject:self];
    
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTPhotoSource

- (NSInteger)numberOfPhotos {
    return _numberOfPhotos;
}

- (NSInteger)maxPhotoIndex {
    return self.actualMaxPhotoIndex-1;
}

- (id<TTPhoto>)photoAtIndex:(NSInteger)photoIndex {
    if (photoIndex < self.photos.count) {
        id photo = [self.photos objectAtIndex:photoIndex];
        if (photo == [NSNull null]) {
            return nil;
        } else {
            return photo;
        }
    } else {
        return nil;
    }
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation Photo

@synthesize photoSource = _photoSource, size = _size, index = _index, caption = _caption, pageUrl = _pageUrl;

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)initWithURL:(NSString*)URL smallURL:(NSString*)smallURL size:(CGSize)size page:(NSString*) page{
    return [self initWithURL:URL smallURL:smallURL size:size caption:nil page:page];
}

- (id)initWithURL:(NSString*)URL smallURL:(NSString*)smallURL size:(CGSize)size
          caption:(NSString*)caption page:(NSString*) page{
    if (self = [super init]) {
        _photoSource = nil;
        _URL = [URL copy];
        _smallURL = [smallURL copy];
        _thumbURL = [smallURL copy];
        _size = size;
        _caption = [caption copy];
        _index = NSIntegerMax;
        self.pageUrl = page;
    }
    return self;
}

- (void)dealloc {
    TT_RELEASE_SAFELY(_URL);
    TT_RELEASE_SAFELY(_smallURL);
    TT_RELEASE_SAFELY(_thumbURL);
    TT_RELEASE_SAFELY(_caption);
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTPhoto

- (NSString*)URLForVersion:(TTPhotoVersion)version {
    if (version == TTPhotoVersionLarge) {
        return _URL;
    } else if (version == TTPhotoVersionMedium) {
        return _URL;
    } else if (version == TTPhotoVersionSmall) {
        return _smallURL;
    } else if (version == TTPhotoVersionThumbnail) {
        return _thumbURL;
    } else {
        return nil;
    }
}

@end
