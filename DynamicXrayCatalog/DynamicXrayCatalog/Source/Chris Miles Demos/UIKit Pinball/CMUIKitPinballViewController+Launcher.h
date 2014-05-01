//
//  CMUIKitPinballViewController+Launcher.h
//  DynamicXrayCatalog
//
//  Created by Chris Miles on 7/02/2014.
//  Copyright (c) 2014 Chris Miles. All rights reserved.
//

#import "CMUIKitPinballViewController.h"

@interface CMUIKitPinballViewController (Launcher)

- (void)setupLauncher;

- (void)launchTapGestureRecognized:(UITapGestureRecognizer *)tapGestureRecognizer;

- (CGFloat)launcherEndYPos;

@end