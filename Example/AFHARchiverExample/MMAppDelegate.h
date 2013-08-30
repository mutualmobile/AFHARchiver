//
//  MMAppDelegate.h
//  AFHARchiverExample
//
//  Created by Kevin Harwood on 8/26/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AFHARchiver.h"

@interface MMAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) AFHARchiver *afArchiver;

@end
