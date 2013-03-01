// AFHARchiver.m
//
// Copyright (c) 2013 Mutual Mobile
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFHARchiver.h"
#import "AFImageRequestOperation.h"
#import <objc/runtime.h>

static dispatch_queue_t af_http_request_operation_archiving_queue;
static dispatch_queue_t http_request_operation_archiving_queue() {
    if (af_http_request_operation_archiving_queue == NULL) {
        af_http_request_operation_archiving_queue = dispatch_queue_create("com.alamofire.networking.http-archiving", 0);
    }
    
    return af_http_request_operation_archiving_queue;
}

typedef BOOL (^AFHARchiverShouldArchiveOperationBlock)(AFHTTPRequestOperation * operation);

@interface AFHARchiver ()
@property (nonatomic,assign) BOOL isArchiving;
@property (nonatomic,copy) NSString * filePath;
@property (nonatomic,assign) unsigned long long filePosition;
@property (nonatomic,assign) BOOL hasAddedOneEntry;
@property (nonatomic,strong) NSString * creatorName;
@property (nonatomic,strong) NSString * creatorVersion;
@property (readwrite, nonatomic, copy) AFHARchiverShouldArchiveOperationBlock shouldArchiveOperationHandlerBlock;

@end

@implementation AFHARchiver

-(id)initWithPath:(NSString*)filePath error:(NSError **)error{
    self = [self init];
    if(self){
        [self setFilePath:filePath];
        
        NSString * appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        [self setCreatorName:appName];
        NSString * version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        [self setCreatorVersion:version];
        
        NSString * directoryPath = [filePath stringByDeletingLastPathComponent];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:error];
        
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        
        dispatch_async(http_request_operation_archiving_queue(), ^{
            NSFileHandle * writeHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
            
            NSData * JSONData = [self HTTPArchiveJSONData];
            
            [writeHandle writeData:JSONData];
            
            [writeHandle closeFile];
            
            NSData * entryData = [@"\"entries\":[]" dataUsingEncoding:NSUTF8StringEncoding];
            NSRange range = [JSONData rangeOfData:entryData options:0 range:NSMakeRange(0, [JSONData length])];
            self.filePosition = range.location+range.length-1;

        });
        
    }
    return self;
}

-(void)startArchiving{
    if(self.isArchiving == NO){
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(operationDidStart:)
         name:AFNetworkingOperationDidStartNotification
         object:nil];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(operationDidFinish:)
         name:AFNetworkingOperationDidFinishNotification
         object:nil];
        
        self.isArchiving = YES;
    }
}

-(void)stopArchiving{
    if(self.isArchiving == YES){
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:AFNetworkingOperationDidStartNotification
         object:nil];
        
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:AFNetworkingOperationDidFinishNotification
         object:nil];
        self.isArchiving = NO;
    }
}

-(void)setShouldArchiveOperationBlock:(BOOL (^)(AFHTTPRequestOperation *))block{
    self.shouldArchiveOperationHandlerBlock = block;
}

-(void)dealloc{
    if(self.isArchiving == YES)
        [self stopArchiving];
}

#pragma mark - Private Class Methods
+(NSDictionary*)HTTPArchiveEntryDictionaryForOperation:(AFHTTPRequestOperation*)operation{
    NSMutableDictionary * entry = [NSMutableDictionary dictionary];
    
    //startedDateTime [string] - Date and time stamp of the request start (ISO 8601 - YYYY-MM-DDThh:mm:ss.sTZD)
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
    
    NSDate * startDate = objc_getAssociatedObject(operation, AFHTTPRequestOperationArchivingStartDate);
    NSAssert(startDate, @"Start Date cannot be nil");
    NSDate * endDate = objc_getAssociatedObject(operation, AFHTTPRequestOperationArchivingEndDate);
    NSAssert(endDate, @"End Date cannot be nil");
    NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
    
    NSString *dateString = [formatter stringFromDate:startDate];
    [entry setValue:dateString forKey:@"startedDateTime"];
    
    //time [number] - Total elapsed time of the request in milliseconds. This is the sum of all timings available in the timings object (i.e. not including -1 values).
    [entry setValue:[NSNumber numberWithInt:duration*1000] forKey:@"time"];
    
    //request [object] - Detailed info about the request.
    [entry setValue:[AFHARchiver HTTPArchiveRequestDictionaryForOperation:operation] forKey:@"request"];
    
    //response [object] - Detailed info about the response.
    [entry setValue:[AFHARchiver HTTPArchiveResponseDictionaryForOperation:operation] forKey:@"response"];
    
    //cache [object] - Info about cache usage.
    //@TODO: Determine how to use cache
    [entry setValue:[NSDictionary dictionary] forKey:@"cache"];
    
    //timings [object] - Detailed timing info about request/response round trip.
    //@TODO: Determine how to properly time the request. Currently we are putting
    //       the entire time in the send bucket.
    int durationInMS = duration * 1000;
    
    NSMutableDictionary * timingDictionary = [NSMutableDictionary dictionary];
    [timingDictionary setValue:@-1 forKey:@"blocked"];
    [timingDictionary setValue:@-1 forKey:@"dns"];
    [timingDictionary setValue:@0 forKey:@"connect"];
    [timingDictionary setValue:[NSNumber numberWithInt:durationInMS] forKey:@"send"];
    [timingDictionary setValue:@0 forKey:@"wait"];
    [timingDictionary setValue:@0 forKey:@"receive"];
    [timingDictionary setValue:@-1 forKey:@"ssl"];
    [entry setValue:timingDictionary forKey:@"timings"];
    
    return [NSDictionary dictionaryWithDictionary:entry];
}

#pragma mark - Private Instance Methods
-(NSData*)HTTPArchiveJSONData{
    NSMutableDictionary * logDictionary = [NSMutableDictionary dictionary];
    
    [logDictionary setValue:@"1.2" forKey:@"version"];
    
    [logDictionary setValue:[self HTTPArchiveCreatorDictionary] forKey:@"creator"];
    
    [logDictionary setValue:@[] forKey:@"entries"];
    
    NSDictionary * harDictionary = @{@"log":logDictionary};
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:harDictionary options:0 error:nil];
    
    return jsonData;
}

static void *AFHTTPRequestOperationArchivingStartDate = &AFHTTPRequestOperationArchivingStartDate;

-(void)operationDidStart:(NSNotification*)notification{
    AFHTTPRequestOperation * operation = [notification object];
    objc_setAssociatedObject(operation, AFHTTPRequestOperationArchivingStartDate, [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if([self shouldArchiveOperation:operation]){
        
    }
}

static void *AFHTTPRequestOperationArchivingEndDate = &AFHTTPRequestOperationArchivingEndDate;

-(void)operationDidFinish:(NSNotification*)notification{
    AFHTTPRequestOperation * operation = [notification object];
    objc_setAssociatedObject(operation, AFHTTPRequestOperationArchivingEndDate, [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if([self shouldArchiveOperation:operation]){
        [self archiveOperation:operation];
    }
}


-(NSDictionary*)HTTPArchiveCreatorDictionary{
    
    NSDictionary * creatorDictionary = @{@"name" : self.creatorName,@"version":self.creatorVersion,@"comment":@"HTTPArchive Created by AFNetworking+HAR"};
    
    return creatorDictionary;
}

#pragma mark Private Operation Conversion Methods
+(NSDictionary*)HTTPArchiveRequestDictionaryForOperation:(AFHTTPRequestOperation*)operation{
    NSMutableDictionary * requestDictionary = [NSMutableDictionary dictionary];
    
    //method [string] - Request method (GET, POST, ...).
    [requestDictionary setValue:operation.request.HTTPMethod forKey:@"method"];
    
    //url [string] - Absolute URL of the request (fragments are not included).
    [requestDictionary setValue:[operation.request.URL absoluteString] forKey:@"url"];
    
    //httpVersion [string] - Request HTTP Version.
    [requestDictionary setValue:@"HTTP/1.1" forKey:@"httpVersion"];
    
    //cookies [array] - List of cookie objects.
    //@TODO: Determine how to use request cookies
    [requestDictionary setValue:[NSArray array] forKey:@"cookies"];
    
    //headers [array] - List of header objects.
    NSMutableArray * headerFieldsArray = [NSMutableArray array];
    [operation.request.allHTTPHeaderFields
     enumerateKeysAndObjectsUsingBlock:^(NSString * name, NSString * value, BOOL *stop) {
         NSDictionary * headerDictionary = @{@"name":name,@"value":value,@"comment":@""};
         [headerFieldsArray addObject:headerDictionary];
     }];
    [requestDictionary setValue:[NSArray arrayWithArray:headerFieldsArray] forKey:@"headers"];
    
    //queryString [array] - List of query parameter objects.
    NSString * fullQueryString = operation.request.URL.query;
    NSArray * splitQueryString = [fullQueryString componentsSeparatedByString:@"&"];
    NSMutableArray * queryArray = [NSMutableArray array];
    if(splitQueryString){
        [splitQueryString enumerateObjectsUsingBlock:
         ^(NSString * singleQueryString, NSUInteger idx, BOOL *stop) {
             NSArray * queryComponents = [singleQueryString componentsSeparatedByString:@"="];
             if([queryComponents count]==2){
                 NSString * name = [queryComponents objectAtIndex:0];
                 NSString * value = [queryComponents objectAtIndex:1];
                 NSDictionary * query = @{@"name":name,@"value":value,@"comment":@""};
                 [queryArray addObject:query];
             }
         }];
    }
    [requestDictionary setValue:[NSArray arrayWithArray:queryArray] forKey:@"queryString"];
    
    //postData [object, optional] - Posted data info.
    if(operation.request.HTTPBody!=nil){
        NSString * contentType = [operation.request.allHTTPHeaderFields valueForKey:@"Content-Type"];
        NSMutableDictionary * postDataDictionary = [NSMutableDictionary dictionary];
        [postDataDictionary setValue:contentType forKey:@"mimeType"];
        //@TODO: Determine how to use params array
        [postDataDictionary setValue:[NSArray array] forKey:@"params"];
        NSString * postString = [[NSString alloc] initWithData:operation.request.HTTPBody encoding:NSUTF8StringEncoding];
        [postDataDictionary setValue:postString forKey:@"text"];
        [requestDictionary setValue:[NSDictionary dictionaryWithDictionary:postDataDictionary] forKey:@"postData"];
    }
    
    //headersSize [number] - Total number of bytes from the start of the HTTP request message until (and including) the double CRLF before the body. Set to -1 if the info is not available.
    //@TODO: Determine how to calculate headersSize
    [requestDictionary setValue:@-1 forKey:@"headersSize"];
    
    //bodySize [number] - Size of the request body (POST data payload) in bytes. Set to -1 if the info is not available.
    [requestDictionary setValue:[NSNumber numberWithInt:[operation.request.HTTPBody length]] forKey:@"bodySize"];
    
    return [NSDictionary dictionaryWithDictionary:requestDictionary];
}

+(NSDictionary*)HTTPArchiveResponseDictionaryForOperation:(AFHTTPRequestOperation*)operation{
    NSMutableDictionary * responseDictionary = [NSMutableDictionary dictionary];
    
    //status [number] - Response status.
    [responseDictionary setValue:[NSNumber numberWithInt:operation.response.statusCode] forKey:@"status"];
    
    //statusText [string] - Response status description.
    [responseDictionary setValue:[NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode] forKey:@"statusText"];
    
    //httpVersion [string] - Request HTTP Version.
    [responseDictionary setValue:@"HTTP/1.1" forKey:@"httpVersion"];
    
    //cookies [array] - List of cookie objects.
    //@TODO: Determine how to use response cookies
    [responseDictionary setValue:[NSArray array] forKey:@"cookies"];
    
    //headers [array] - List of header objects.
    NSMutableArray * headerFieldsArray = [NSMutableArray array];
    [operation.response.allHeaderFields
     enumerateKeysAndObjectsUsingBlock:^(NSString * name, NSString * value, BOOL *stop) {
         NSDictionary * headerDictionary = @{@"name":name,@"value":value,@"comment":@""};
         [headerFieldsArray addObject:headerDictionary];
     }];
    [responseDictionary setValue:[NSArray arrayWithArray:headerFieldsArray] forKey:@"headers"];
    
    //content [object] - Details about the response body.
    NSMutableDictionary * contentDictionary = [NSMutableDictionary dictionary];
    [contentDictionary setValue:[NSNumber numberWithInt:[operation.responseData length]] forKey:@"size"];
    NSString * contentType = [operation.response.allHeaderFields valueForKey:@"Content-Type"];
    if(contentType==nil)
        contentType = @"";
    [contentDictionary setValue:contentType forKey:@"mimeType"];
    if(operation.responseString){
        [contentDictionary setValue:operation.responseString forKey:@"text"];
    }
    else if(operation.responseData){
        //@TODO How should better handle not text data?
        NSString * string = [[NSString alloc] initWithData:operation.responseData encoding:NSUTF8StringEncoding];
        [contentDictionary setValue:string forKey:@"text"];
    }
    else {
        [contentDictionary setValue:@"" forKey:@"text"];
    }
    [responseDictionary setValue:[NSDictionary dictionaryWithDictionary:contentDictionary] forKey:@"content"];
    
    //redirectURL [string] - Redirection target URL from the Location response header.
    //@TODO: Determine if we should be using redirectURL?
    [responseDictionary setValue:@"" forKey:@"redirectURL"];
    
    //headersSize [number]* - Total number of bytes from the start of the HTTP response message until (and including) the double CRLF before the body. Set to -1 if the info is not available.
    //@TODO: Determine how to calculate headersSize
    [responseDictionary setValue:@-1 forKey:@"headersSize"];
    
    //bodySize [number] - Size of the received response body in bytes. Set to zero in case of responses coming from the cache (304). Set to -1 if the info is not available.
    [responseDictionary setValue:[NSNumber numberWithInt:[operation.responseData length]] forKey:@"bodySize"];
    
    return [NSDictionary dictionaryWithDictionary:responseDictionary];
}

-(BOOL)shouldArchiveOperation:(AFHTTPRequestOperation*)operation{
    if(self.shouldArchiveOperationHandlerBlock)
        return self.shouldArchiveOperationHandlerBlock(operation);
    else
        return YES;
}

-(void)archiveOperation:(AFHTTPRequestOperation *)operation{
    dispatch_async(http_request_operation_archiving_queue(), ^{
        NSDictionary * dictonary = [AFHARchiver HTTPArchiveEntryDictionaryForOperation:operation];
        NSData * JSONData = [NSJSONSerialization dataWithJSONObject:dictonary options:0 error:nil];
                
        NSMutableData * mutableData = [NSMutableData data];
        
        //We need to append a comma if we have already logged one item.
        if(self.hasAddedOneEntry == YES)
            [mutableData appendData:[@"," dataUsingEncoding:NSUTF8StringEncoding]];
        
        [self setHasAddedOneEntry:YES];
        [mutableData appendData:JSONData];
        
        NSFileHandle * readHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
        NSFileHandle * writeHandle = [NSFileHandle fileHandleForWritingAtPath:self.filePath];
        
        [readHandle seekToFileOffset:self.filePosition];
        NSData * existingData = [readHandle readDataToEndOfFile];
        
        [writeHandle seekToFileOffset:self.filePosition];
        
        [writeHandle writeData:mutableData];
        self.filePosition = [writeHandle offsetInFile];
        [writeHandle writeData:existingData];
        
        [readHandle closeFile];
        [writeHandle closeFile];
        
    });
}

@end
