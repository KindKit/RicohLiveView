/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import <UIKit/UIKit.h>

@interface RicohLiveViewStream : NSObject

- (void)setDelegate:(void(^_Nullable)(UIImage* _Nullable frame, NSError* _Nullable error))bufferBlock;

- (void)startWithHost:(nonnull NSString*)host sessionId:(nullable NSString*)sessionId;

- (void)cancel;

@end
