//
//  S3LoginController.h
//  S3-Objc
//
//  Created by Bruce Chen on 4/7/06.
//  Copyright 2006 Bruce Chen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "S3ActiveWindowController.h"

#define DEFAULT_USER @"defaultAccessKey"

@class S3ConnectionInfo;

@interface S3LoginController : S3ActiveWindowController <NSWindowDelegate> {
	IBOutlet NSButton *_defaultButton;
	IBOutlet NSButton *_keychainCheckbox;
    
    NSString *accessKeyID;
    NSString *secretAccessKeyID;
}

- (IBAction)connect:(id)sender;
- (IBAction)openHelpPage:(id)sender;
- (IBAction)flippedKeychainSupport:(id)sender;

@end
