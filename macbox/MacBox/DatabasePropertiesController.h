//
//  DatabasePropertiesController.h
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabasePropertiesController : NSTabViewController

- (void)setModel:(ViewModel*)model;

@end

NS_ASSUME_NONNULL_END
