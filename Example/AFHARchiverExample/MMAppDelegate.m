//
//  MMAppDelegate.m
//  AFHARchiverExample
//
//  Created by Kevin Harwood on 8/26/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import "MMAppDelegate.h"
#import "GlobalTimelineViewController.h"

#import "AFNetworkActivityIndicatorManager.h"
#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFSerialization.h>

@implementation MMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupArchiver];
    
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:20 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    UITableViewController *viewController = [[GlobalTimelineViewController alloc] initWithStyle:UITableViewStylePlain];
    self.navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

-(void)setupArchiver{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSDateFormatter * df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString * fileName = [NSString stringWithFormat:@"%@_log.har",[df stringFromDate:[NSDate date]]];
    
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    NSLog(@"Logging HAR file at %@",filePath);
    
    self.afArchiver = [[AFHARchiver alloc] initWithPath:filePath error:nil];
    [self.afArchiver
     setShouldArchiveOperationBlock:^BOOL(AFHTTPRequestOperation *operation) {
         return [operation.responseSerializer isKindOfClass:[AFJSONResponseSerializer class]];
     }];
    [self.afArchiver
     setShouldArchiveTaskBlock:^BOOL(NSURLSessionTask *task, id<AFURLResponseSerialization> responseSerializer, id serializedResponse) {
         return YES;
     }];
    [self.afArchiver startArchiving];
}

@end
