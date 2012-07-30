//
//  AuthenticationViewController.m
//  OpenPhoto
//
//  Created by Patrick Santana on 07/09/11.
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

#import "AuthenticationViewController.h"

// Private interface definition
@interface AuthenticationViewController() 

- (void) saveUrl:(NSString *) text;
- (BOOL) validateUrl: (NSString *) url;
- (void) eventHandler: (NSNotification *) notification;

@end

@implementation AuthenticationViewController
@synthesize serverURL = _serverURL;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        //register to listen for to remove the login screen.    
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(eventHandler:)
                                                     name:kNotificationLoginAuthorize         
                                                   object:nil ];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setServerURL:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (IBAction)login:(id)sender {
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Url Login %@",self.serverURL.text);
#endif
    
    // check if the user typed something
    if ( self.serverURL.text != nil &&
        [self.serverURL.text isEqualToString:@"username.openphoto.me"]){
        
        // user should add URL
        OpenPhotoAlertView *alert = [[OpenPhotoAlertView alloc] initWithMessage:@"Please, set the URL to the OpenPhoto Server." duration:5000];
        [alert showAlert];
        [alert release];
    }else{
        // the same actin as click the button from keyboard
        if ( [self validateUrl:self.serverURL.text]==YES){
            
            // save the url method. It removes the last / if exists
            [self saveUrl:self.serverURL.text];
            
            // to the login in the website
            WebService* service = [[WebService alloc]init];
            [[UIApplication sharedApplication] openURL:[service getOAuthInitialUrl]];
            [service release];   
        }
    }
}

// Action if user clicks in DONE in the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField {  
    
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Url %@",self.serverURL.text);
#endif
    
    if ([self validateUrl:textField.text] == YES){
        
        // save the url method. It removes the last / if exists
        [self saveUrl:textField.text];
        
        // to the login
        WebService* service = [[WebService alloc]init];
        [[UIApplication sharedApplication] openURL:[service getOAuthInitialUrl]];
        [service release];   
        
        // return
        [textField resignFirstResponder];
        return YES;
    }
    
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationCurveEaseOut animations:^{
        // move the view a little bit up
        [self.view setCenter:CGPointMake([self.view  center].x, [self.view  center].y - 40)];
    }completion:^(BOOL finished){
        if([textField respondsToSelector:@selector(selectedTextRange)]){
            
            //iOS >=5.0            
            if ( [textField.text isEqualToString:@"username.openphoto.me"]){
                // get the actual range
                UITextRange *selectedRange = [textField selectedTextRange];       
                
                //Calculate the new position, - for left and + for right
                UITextPosition *fromPosition = [textField positionFromPosition:selectedRange.start offset:-21];  
                UITextPosition *toPosition = [textField positionFromPosition:selectedRange.start offset:-13];
                
                //Construct a new range and set  in the textfield
                UITextRange *newRange = [textField textRangeFromPosition:fromPosition toPosition:toPosition];
                textField.selectedTextRange = newRange;
            }
        }
    }];
}



///////////////////////////////////
// PRIVATES METHODS
//////////////////////////////////
- (BOOL) validateUrl: (NSString *) url {
    NSString *theURL =
    @"((http|https)://)?((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", theURL]; 
    
    // validate URL
    if ( [urlTest evaluateWithObject:url] == NO){
        // show alert to user
        OpenPhotoAlertView *alert = [[OpenPhotoAlertView alloc] initWithMessage:@"Invalid URL, please try again." duration:5000];
        [alert showAlert];
        [alert release];
        
        return NO;
    }
    
    return YES;
}

-(void) saveUrl:(NSString *) text{
    // save the url for the app
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    
    NSURL *url;
    if ([text rangeOfString:@"http://"].location == NSNotFound) {
        
#ifdef DEVELOPMENT_ENABLED
        NSLog(@"URL does not contain http://");
#endif
        
        NSString *urlString = [[NSString alloc] initWithFormat:@"http://%@",text];
        url = [NSURL URLWithString:urlString];
        [urlString release];
    }else{
        url = [NSURL URLWithString:text];
    }
    
    // removes form the URL if it ends with "/"
    if ([[url lastPathComponent] isEqualToString:@"/"]){
        [standardUserDefaults setValue:[text stringByReplacingCharactersInRange:NSMakeRange(text.length-1, 1) withString:@""] forKey:kOpenPhotoServer];
    }else{
        [standardUserDefaults setValue:[url relativeString] forKey:kOpenPhotoServer];
    }
    [standardUserDefaults synchronize];  
}

//event handler when event occurs
-(void)eventHandler: (NSNotification *) notification
{
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"###### Event triggered: %@", notification);
#endif
    
    if ([notification.name isEqualToString:kNotificationLoginAuthorize]){
        // we don't need the screen anymore
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)dealloc {
    [_serverURL release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}
@end
