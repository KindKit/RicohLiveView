/*
 * Copyright Ricoh Company, Ltd. All rights reserved.
 */

#import "RicohLiveViewStream.h"

// Start and end markers for images in JPEG format
const Byte SOI_MARKER[] = {0xFF, 0xD8};
const Byte EOI_MARKER[] = {0xFF, 0xD9};

/**
 * Live view data acquisition class
 */
@interface RicohLiveViewStream() <NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
{
    NSURLSession* _session;
    NSURLSessionDataTask* _task;
    NSMutableData* _buffer;
    void (^_onBuffered)(UIImage *frame, NSError* error);
}
@end

@implementation RicohLiveViewStream

/**
 * Set block to be executed when receiving data
 * @param bufferBlock Block to be executed when receiving data
 */
- (void)setDelegate:(void(^)(UIImage *frame, NSError* error))bufferBlock
{
    _onBuffered = bufferBlock;
}

/**
 * Specified initializer
 * @param request HTTP request
 * @return Instance
 */
- (id)init
{
    if (self = [super init]) {
        NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSOperationQueue* queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:queue];
        _buffer = [NSMutableData data];
    }
    return self;
}

- (void)dealloc {
    [_session invalidateAndCancel];
}

/**
 * Start data acquisition
 */
- (void)startWithHost:(NSString*)host sessionId:(NSString*)sessionId
{
    if (_task == nil) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/osc/commands/execute", host]];

        // Create the url-request.
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        // request.timeoutInterval = 20;

        // Set the method(HTTP-POST)
        [request setHTTPMethod:@"POST"];

        [request setValue:@"application/json; charaset=utf-8" forHTTPHeaderField:@"Content-Type"];
        
        // Create JSON data
        NSDictionary *body = @{
            @"name": @"camera.getLivePreview"
        };
        
        // Set the request-body.
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];
        
        
        // Start data acquisition task
        _task = [_session dataTaskWithRequest:request];
        [_task resume];
    }
}

/**
 * Stop data acquisition task
 */
- (void)cancel
{
    [_task cancel];
    _task = nil;
}

/**
 * Delegate for notification that part of the data has been received by the data acquisition task
 * @param session Session
 * @param dataTask Task
 * @param data Received data
 */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    if(_task != dataTask) {
        return;
    }
    [_buffer appendData:data];
    Byte b1[2];

    // Search for SOI marker position from buffer
    NSUInteger soi;
    NSUInteger eoi;
    do {
        soi = 0;
        eoi = 0;
        NSInteger i = 0;
    
        for (; i < (NSInteger)_buffer.length - 1; i++) {
            [_buffer getBytes:b1 range:NSMakeRange(i, 2)];
            if (SOI_MARKER[0] == b1[0]) {
                if (SOI_MARKER[1] == b1[1]) {
                    soi = i;
                    break;
                }
            }
        }

        for (; i < (NSInteger)_buffer.length - 1; i++) {
            [_buffer getBytes:b1 range:NSMakeRange(i, 2)];
            if (EOI_MARKER[0] == b1[0]) {
                if (EOI_MARKER[1] == b1[1]) {
                    eoi = i;
                    break;
                }
            }
        }

        // Exit process if EOI not found
        if (eoi == 0) {
            if([dataTask.response isKindOfClass:NSHTTPURLResponse.class] == YES) {
                NSHTTPURLResponse* response = (NSHTTPURLResponse*)dataTask.response;
                if((response.statusCode < 200) || (response.statusCode > 299)) {
                    __weak typeof(self) weakSelf = self;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        typeof(self) strongSelf = weakSelf;
                        if((strongSelf != nil) && (strongSelf->_onBuffered != nil)) {
                            strongSelf->_onBuffered(nil, nil);
                        }
                    });
                }
            }
            return;
        }
        NSData *frameData = [_buffer subdataWithRange:NSMakeRange(soi, eoi - soi)];

        // Draw
        UIImage* frame = [UIImage imageWithData:frameData];
        if(frame != nil) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(self) strongSelf = weakSelf;
                if((strongSelf != nil) && (strongSelf->_onBuffered != nil)) {
                    strongSelf->_onBuffered(frame, nil);
                }
            });
        }
            
        // Delete used parts of data
        NSUInteger remainLength = _buffer.length - eoi - 2;
        Byte remain[remainLength];
        [_buffer getBytes:remain range:NSMakeRange(eoi + 2, remainLength)];
        _buffer = [NSMutableData dataWithBytes:remain length:remainLength];
    } while (0 < eoi);
}

/**
 * Delegate for notification that the data task has finished receiving data
 * @param session Session
 * @param task Task
 * @param error Error information
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    if(_task != task) {
        return;
    }
    [_buffer setLength:0];
    _task = nil;
    if(error != nil) {
        BOOL isCancelled = (([error.domain isEqualToString:NSURLErrorDomain] == YES) && (error.code == NSURLErrorCancelled));
        if(isCancelled == NO) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(self) strongSelf = weakSelf;
                if((strongSelf != nil) && (strongSelf->_onBuffered != nil)) {
                    strongSelf->_onBuffered(nil, error);
                }
            });
        }
    } else {
        _task = [_session dataTaskWithRequest:task.originalRequest];
        [_task resume];
    }
}

@end
