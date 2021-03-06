//
//  AutoFillSettings.h
//  Strongbox
//
//  Created by Strongbox on 13/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillSettings : NSObject

+ (instancetype)sharedInstance;

@property BOOL autoFillExitedCleanly;
@property (nonatomic) BOOL hasShownAutoFillLaunchWelcome;
@property BOOL haveWarnedAboutAutoFillCrash;

@end

NS_ASSUME_NONNULL_END
