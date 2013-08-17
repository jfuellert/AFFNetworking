//
//  AFFNRequest.m
//  AFFNetworking
//
//  Created by Andrew Apperley on 2013-08-06.
//  Copyright (c) 2013 AFApps. All rights reserved.
//

#import "AFFNRequest.h"
#import "AFFNManager.h"
#import <UIKit/UIImage.h>

#pragma mark - Constants
const NSTimeInterval __AFFNDefaultTimeout = 120;
const NSURLCacheStoragePolicy __AFFNDefaultStoragePolicy = NSURLCacheStorageAllowedInMemoryOnly;
const NSString *__AFFNDefaultMultiSeparator = @"_AFFNBoundary_";

NSString *__AFFNKeyExecuting = @"isExecuting";
NSString *__AFFNKeyFinished = @"isFinished";

@implementation AFFNRequest

@synthesize isConcurrent = _isConcurrent;
@synthesize timeoutInterval = _timeoutInterval;
@synthesize storagePolicy = _storagePolicy;
@synthesize multiSeparator = _multiSeparator;
@synthesize multipartData = _multipartData;

#pragma mark - Init

/*
 * Init function to create the reqest object. It takes the URL in NSString format, POST/GET type, params to be used
 * in the request in NSDictionary format, and a completion/fail block for a callback.
 *
 */
+ (AFFNRequest *)requestWithURL:(NSString *)urlString connectionType:(AFFNPostType)type andParams:(NSDictionary *)params withCompletion:(void (^)(AFFNCallbackObject *result))completion andFailBlock:(void (^)(NSError *error))failure andUpProgressBlock:(void (^)(float __upProgress))upProgressBlock andDProgressBlock:(void (^)(float))downProgressBlock
{
    return [[[self alloc] initWithURL:urlString connectionType:type andParams:params withCompletion:completion andFailBlock:failure andUpProgressBlock:upProgressBlock andDProgressBlock:downProgressBlock] autorelease];
}

- (AFFNRequest *)initWithURL:(NSString *)urlString connectionType:(AFFNPostType)type andParams:(NSDictionary *)params withCompletion:(void (^)(AFFNCallbackObject *))completion andFailBlock:(void (^)(NSError *))failure andUpProgressBlock:(void (^)(float))upProgressBlock andDProgressBlock:(void (^)(float))downProgressBlock
{
    self = [super init];
    if(self)
    {
        executing = FALSE;
        finished = FALSE;
        
        _isConcurrent = TRUE;
        _timeoutInterval = __AFFNDefaultTimeout;
        _storagePolicy = __AFFNDefaultStoragePolicy;
        _multiSeparator = (NSString *)__AFFNDefaultMultiSeparator;
        
        _params = [params copy];
        _urlString = [urlString copy];
        _type = type;
        _completion = [completion copy];
        _failure = [failure copy];
        _upProgress = [upProgressBlock copy];
        _downProgress = [downProgressBlock copy];
    }
    
    return self;
}

#pragma mark - Properties

/*
 * BOOL returning functions that return the state of the request
 */
- (BOOL)isConcurrent
{
    return _isConcurrent;
}

- (BOOL)isExecuting
{
    return executing;
}

- (BOOL)isFinished
{
    return finished;
}

#pragma mark - Generate requests

/*
 * The main function of where the request creates the POST/GET request and the connection object, then starts the process.
 */
- (void)start
{    
    [self willChangeValueForKey:__AFFNKeyExecuting];
    executing = TRUE;
    [self didChangeValueForKey:__AFFNKeyExecuting];
    
    if(self.isCancelled) {
        [self willChangeValueForKey:__AFFNKeyExecuting];
        executing = false;
        [self didChangeValueForKey:__AFFNKeyExecuting];
        
        [self willChangeValueForKey:__AFFNKeyFinished];
        finished = true;
        [self didChangeValueForKey:__AFFNKeyFinished];
        
        //temp custom error code/string
        _failure([NSError errorWithDomain:@"operation.cancelled" code:600 userInfo:nil]);
        return;
    }

    
    [self performSelector:_type == (kAFFNPost | kAFFNMulti) ? @selector(generatePOSTRequest) : @selector(generateGETRequest)];
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:FALSE];
    
    if(_connection) {
        receivedData = [NSMutableData new];
        
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
                               forMode:NSDefaultRunLoopMode];
        [_connection start];
        
        
        requestTime = [[NSDate date] retain];
        
        [finalURL release];
        finalURL = nil;
        
        [request release];
        request = nil;
    }
}

//Generates a POST type request
- (void)generatePOSTRequest
{
    
    finalURL = [[NSURL alloc] initWithString:_urlString];
    
    request = [[NSMutableURLRequest alloc] initWithURL:finalURL cachePolicy:_storagePolicy timeoutInterval:_timeoutInterval];
    
    [request setHTTPMethod:@"POST"];
    
    NSMutableData *data = [NSMutableData new];
    
    if(_type == kAFFNMulti) {
        data = [self generateMultiRequestWithData:data];
        [data appendData:[[NSString stringWithFormat:@"--%@\r\n",_multiSeparator] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSData *jsonData = [NSData data];
    
    NSError *error;
    
    jsonData = [NSJSONSerialization dataWithJSONObject:_params options:NSJSONWritingPrettyPrinted error:&error];
    
    if(error)
        assert(error);
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"params\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];

    [data appendData:[NSData dataWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]]];
    
    
    
    [jsonString release];
    
    if(_type == kAFFNMulti) {
        [data appendData:[[NSString stringWithFormat:@"%@--\r\n",_multiSeparator] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [request setHTTPBody:data];
    [request setValue:[NSString stringWithFormat:@"%d", data.length] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"iOS" forHTTPHeaderField:@"User-Agent"];
    
    [data release];
    data = nil;
   
}

//Generates a Multi POST type request
- (NSMutableData *)generateMultiRequestWithData:(NSMutableData *)data
{
    [request addValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", _multiSeparator] forHTTPHeaderField:@"Content-Type"];
    
    for (id item in _multipartData) {
        if([item isKindOfClass:[NSString class]])
        {
            [data appendData:[[NSString stringWithFormat:@"--%@\r\n", _multiSeparator] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", item] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"%@\r\n", item] dataUsingEncoding:NSUTF8StringEncoding]];
        } else if([item isKindOfClass:[NSData class]])
        {
            [data appendData:[[NSString stringWithFormat:@"--%@\r\n", _multiSeparator] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", [NSString stringWithFormat:@"%@-%d-%d",[((NSData *)item).description substringWithRange:NSMakeRange(1, 8)], ((NSData *)item).hash, (rand() % 1000 + 1) ]] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:(NSData *)item];
            [data appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            @throw [NSException
                    exceptionWithName:@"File Format Exception"
                    reason:@"NSData or NSString only"
                    userInfo:nil];
        }
    }
    
    return data;
    
}

//Generates a GET type request
- (void)generateGETRequest
{
    //construct the url with the key/value pairs in the params
    NSMutableString *paramsString = [[NSMutableString alloc] initWithString:_urlString];
    [paramsString appendString:@"?"];

    for (id key in _params) {
        [paramsString appendFormat:@"%@=%@",key,[_params objectForKey:key]];
    }

    finalURL = [[NSURL alloc] initWithString:paramsString];
    
    [paramsString release];
    paramsString = nil;
    
    request = [[NSMutableURLRequest alloc] initWithURL:finalURL cachePolicy:_storagePolicy timeoutInterval:_timeoutInterval];
    
    [request setHTTPMethod:@"GET"];

    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"iOS" forHTTPHeaderField:@"User-Agent"];

}

#pragma mark - Connection handling

//Calculates the progress of the request
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if(_upDone)
        return;
    
    if(MAX(1, ((float)totalBytesWritten / (float)totalBytesExpectedToWrite)) >= 1)
        _upDone = true;
    
    _upProgress(MAX(1, ((float)totalBytesWritten / (float)totalBytesExpectedToWrite)));
}

//Failure of the connection, returns the error through the failure block
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [_connection release];
    _connection = nil;
    
    _failure(error);
    
    [self willChangeValueForKey:__AFFNKeyExecuting];
    executing = false;
    [self didChangeValueForKey:__AFFNKeyExecuting];

    [self willChangeValueForKey:__AFFNKeyFinished];
    finished = true;
    [self didChangeValueForKey:__AFFNKeyFinished];

    if(error)
        assert(error);
}

//Sets the progress and data to 0 as a request/attempt has started
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [receivedData setLength:0];
    downloadDataLength = 0;
    expectedDataLength = response.expectedContentLength;
    _downDone = false;
}

//Appends data to the data object
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    downloadDataLength += data.length;
    [receivedData appendData:data];
    
    if(_downDone)
        return;
    
    if(MAX(1, (downloadDataLength / expectedDataLength)) >= 1)
        _downDone = true;
    
    _downProgress(MAX(1, (downloadDataLength / expectedDataLength)));
    
}

//Successful request function. Returns the total request time and data to the completion block in a AFFNCallbackObject
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [_connection release];
    _connection = nil;
    
    NSTimeInterval totalRequestTime = [[NSDate date] timeIntervalSinceDate:requestTime];
    
    AFFNCallbackObject *callBack = [AFFNCallbackObject callbackWithData:receivedData andReqestTime:totalRequestTime];
    
    _completion(callBack);
        
    [self willChangeValueForKey:__AFFNKeyExecuting];
    executing = false;
    [self didChangeValueForKey:__AFFNKeyExecuting];
    
    [self willChangeValueForKey:__AFFNKeyFinished];
    finished = true;
    [self didChangeValueForKey:__AFFNKeyFinished];
}

#pragma mark - Dealloc

//Clean up memory
- (void)dealloc
{
    [_params release];
    _params = nil;
    
    [_urlString release];
    _urlString = nil;
    
    [finalURL release];
    finalURL = nil;
    
    [request release];
    request = nil;
    
    if(_connection){
        [_connection release];
        _connection = nil;
    }
    
    [_completion release];
    _completion = nil;
    
    [_failure release];
    _failure = nil;
    
    [_upProgress release];
    _upProgress = nil;
    
    [_downProgress release];
    _downProgress = nil;
    
    [requestTime release];
    requestTime = nil;
    
    [_multipartData release];
    _multipartData = nil;
    
    if(receivedData){
        [receivedData release];
        receivedData = nil;
    }
    
    [super dealloc];
}

@end