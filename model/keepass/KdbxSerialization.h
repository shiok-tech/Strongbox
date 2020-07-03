//
//  KeePassXmlSerialization.h
//  Strongbox-iOS
//
//  Created by Mark on 16/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SerializationData.h"
#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct _BlockHeader {
    uint8_t id[4];
    uint8_t hash[32];
    uint8_t size[4];
} BlockHeader;
#define SIZE_OF_BLOCK_HEADER 40

typedef void (^SerializeCompletionBlock)(BOOL userCancelled, NSString*_Nullable hash, NSError*_Nullable error);

typedef void (^DeserializeCompletionBlock)(BOOL userCancelled, SerializationData*_Nullable serializationData, NSError*_Nullable error);

@interface KdbxSerialization : NSObject

+ (BOOL)isValidDatabase:(NSData*)prefix error:(NSError**)error;

+ (void)deserialize:(NSInputStream*)stream
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
      xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
         completion:(DeserializeCompletionBlock)completion;

- (instancetype)init:(SerializationData*)serializationData;

- (void)stage1Serialize:(CompositeKeyFactors *)compositeKeyFactors
             completion:(SerializeCompletionBlock)completion;

- (nullable NSData*)stage2Serialize:(NSString*)xml error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
