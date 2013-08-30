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

static void *AFHTTPRequestOperationArchivingStartDate = &AFHTTPRequestOperationArchivingStartDate;
static void *AFHTTPRequestOperationArchivingEndDate = &AFHTTPRequestOperationArchivingEndDate;
static void *AFHTTPRequestOperationArchivingRedirectURLRequest = &AFHTTPRequestOperationArchivingRedirectURLRequest;

static NSDictionary * AFHTTPArchiveRequestDictionaryForRequest(NSURLRequest *request){
    NSMutableDictionary * requestDictionary = [NSMutableDictionary dictionary];
    
    //method [string] - Request method (GET, POST, ...).
    [requestDictionary setValue:request.HTTPMethod forKey:@"method"];
    
    //url [string] - Absolute URL of the request (fragments are not included).
    [requestDictionary setValue:[request.URL absoluteString] forKey:@"url"];
    
    //httpVersion [string] - Request HTTP Version.
    [requestDictionary setValue:@"HTTP/1.1" forKey:@"httpVersion"];
    
    //cookies [array] - List of cookie objects.
    //@TODO: Determine how to use request cookies
    [requestDictionary setValue:[NSArray array] forKey:@"cookies"];
    
    //headers [array] - List of header objects.
    NSMutableArray * headerFieldsArray = [NSMutableArray array];
    [request.allHTTPHeaderFields
     enumerateKeysAndObjectsUsingBlock:^(NSString * name, NSString * value, BOOL *stop) {
         NSDictionary * headerDictionary = @{@"name":name,@"value":value,@"comment":@""};
         [headerFieldsArray addObject:headerDictionary];
     }];
    [requestDictionary setValue:[NSArray arrayWithArray:headerFieldsArray] forKey:@"headers"];
    
    //queryString [array] - List of query parameter objects.
    NSString * fullQueryString = request.URL.query;
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
    if(request.HTTPBody!=nil){
        NSString * contentType = [request.allHTTPHeaderFields valueForKey:@"Content-Type"];
        NSMutableDictionary * postDataDictionary = [NSMutableDictionary dictionary];
        [postDataDictionary setValue:contentType forKey:@"mimeType"];
        //@TODO: Determine how to use params array
        [postDataDictionary setValue:[NSArray array] forKey:@"params"];
        NSString * postString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        [postDataDictionary setValue:postString forKey:@"text"];
        [requestDictionary setValue:[NSDictionary dictionaryWithDictionary:postDataDictionary] forKey:@"postData"];
    }
    
    //headersSize [number] - Total number of bytes from the start of the HTTP request message until (and including) the double CRLF before the body. Set to -1 if the info is not available.
    //@TODO: Determine how to calculate headersSize
    [requestDictionary setValue:@-1 forKey:@"headersSize"];
    
    //bodySize [number] - Size of the request body (POST data payload) in bytes. Set to -1 if the info is not available.
    [requestDictionary setValue:[NSNumber numberWithUnsignedInteger:[request.HTTPBody length]] forKey:@"bodySize"];
    
    return [NSDictionary dictionaryWithDictionary:requestDictionary];
}

static NSDictionary * AFHTTPArchiveResponseDictionaryForResponse(NSHTTPURLResponse *response, NSData *responseData){
    NSMutableDictionary * responseDictionary = [NSMutableDictionary dictionary];
    
    //status [number] - Response status.
    [responseDictionary setValue:[NSNumber numberWithInteger:response.statusCode] forKey:@"status"];
    
    //statusText [string] - Response status description.
    [responseDictionary setValue:[NSHTTPURLResponse localizedStringForStatusCode:response.statusCode] forKey:@"statusText"];
    
    //httpVersion [string] - Request HTTP Version.
    [responseDictionary setValue:@"HTTP/1.1" forKey:@"httpVersion"];
    
    //cookies [array] - List of cookie objects.
    //@TODO: Determine how to use response cookies
    [responseDictionary setValue:[NSArray array] forKey:@"cookies"];
    
    //headers [array] - List of header objects.
    NSMutableArray * headerFieldsArray = [NSMutableArray array];
    [response.allHeaderFields
     enumerateKeysAndObjectsUsingBlock:^(NSString * name, NSString * value, BOOL *stop) {
         NSDictionary * headerDictionary = @{@"name":name,@"value":value,@"comment":@""};
         [headerFieldsArray addObject:headerDictionary];
     }];
    [responseDictionary setValue:[NSArray arrayWithArray:headerFieldsArray] forKey:@"headers"];
    
    //content [object] - Details about the response body.
    NSMutableDictionary * contentDictionary = [NSMutableDictionary dictionary];
    [contentDictionary setValue:[NSNumber numberWithUnsignedInteger:[responseData length]] forKey:@"size"];
    NSString * contentType = [response.allHeaderFields valueForKey:@"Content-Type"];
    if(contentType==nil){
        contentType = @"";
    }
    [contentDictionary setValue:contentType forKey:@"mimeType"];
    if(responseData){
        //@TODO How should better handle not text data?
        NSString * string = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        [contentDictionary setValue:string forKey:@"text"];
    }
    [responseDictionary setValue:[NSDictionary dictionaryWithDictionary:contentDictionary] forKey:@"content"];
    
    //redirectURL [string] - Redirection target URL from the Location response header.
    NSString *redirectURL = @"";
    if([[response allHeaderFields] valueForKey:@"Location"]){
        redirectURL = [[response allHeaderFields] valueForKey:@"Location"];
    }
    [responseDictionary setValue:redirectURL forKey:@"redirectURL"];
    
    //headersSize [number]* - Total number of bytes from the start of the HTTP response message until (and including) the double CRLF before the body. Set to -1 if the info is not available.
    //@TODO: Determine how to calculate headersSize
    [responseDictionary setValue:@-1 forKey:@"headersSize"];
    
    //bodySize [number] - Size of the received response body in bytes. Set to zero in case of responses coming from the cache (304). Set to -1 if the info is not available.
    [responseDictionary setValue:[NSNumber numberWithUnsignedInteger:[responseData length]] forKey:@"bodySize"];
    
    return [NSDictionary dictionaryWithDictionary:responseDictionary];
}

static NSDictionary * AFHTTPArchiveEntryDictionary(NSDate *startDate, NSDate *endDate, NSDictionary *requestDictionary, NSDictionary * responseDictionary){
    NSMutableDictionary * entry = [NSMutableDictionary dictionary];
    
    //startedDateTime [string] - Date and time stamp of the request start (ISO 8601 - YYYY-MM-DDThh:mm:ss.sTZD)
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
    
    NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
    
    NSString *dateString = [formatter stringFromDate:startDate];
    [entry setValue:dateString forKey:@"startedDateTime"];
    
    //time [number] - Total elapsed time of the request in milliseconds. This is the sum of all timings available in the timings object (i.e. not including -1 values).
    [entry setValue:[NSNumber numberWithInt:duration*1000] forKey:@"time"];
    
    //request [object] - Detailed info about the request.
    [entry setValue:requestDictionary forKey:@"request"];
    
    //response [object] - Detailed info about the response.
    [entry setValue:responseDictionary forKey:@"response"];
    
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


static NSDictionary * AFHTTPArchiveEntryDictionaryForOperation(AFHTTPRequestOperation * operation){
    NSDate * startTime = objc_getAssociatedObject(operation, AFHTTPRequestOperationArchivingStartDate);
    NSDate * endTime = objc_getAssociatedObject(operation, AFHTTPRequestOperationArchivingEndDate);
    
    NSURLRequest * redirectRequest = objc_getAssociatedObject(operation, AFHTTPRequestOperationArchivingRedirectURLRequest);
    NSURLRequest * request = operation.request;
    if(redirectRequest){
        request = redirectRequest;
    }
    
    NSDictionary *requestDictionary = AFHTTPArchiveRequestDictionaryForRequest(request);
    NSDictionary *responseDictionary = AFHTTPArchiveResponseDictionaryForResponse(operation.response, operation.responseData);
    
    return AFHTTPArchiveEntryDictionary(startTime,endTime,requestDictionary,responseDictionary);
}

static NSDictionary * AFHTTPArchiveEntryDictionaryForTask(NSURLSessionTask *task, NSDate *startTime, NSDate *endTime){
    NSDictionary *requestDictionary = AFHTTPArchiveRequestDictionaryForRequest(task.currentRequest);
    NSDictionary *responseDictionary = AFHTTPArchiveResponseDictionaryForResponse((NSHTTPURLResponse*)task.response, nil);
    
    return AFHTTPArchiveEntryDictionary(startTime,endTime,requestDictionary,responseDictionary);
}

static dispatch_queue_t af_http_request_operation_archiving_queue;
static dispatch_queue_t http_request_operation_archiving_queue() {
    if (af_http_request_operation_archiving_queue == NULL) {
        af_http_request_operation_archiving_queue = dispatch_queue_create("com.alamofire.networking.http-archiving", 0);
    }
    
    return af_http_request_operation_archiving_queue;
}

#import <objc/runtime.h>
@interface AFURLConnectionOperation(ArchiveRedirect)
- (NSURLRequest *)afharchiverswizzled_connection:(NSURLConnection *)connection
                                 willSendRequest:(NSURLRequest *)request
                                redirectResponse:(NSURLResponse *)redirectResponse;
@end

@interface AFURLSessionManager(ArchiveRedirect)
- (void)afharchiverswizzled_URLSession:(NSURLSession *)session
                                  task:(NSURLSessionTask *)task
            willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                            newRequest:(NSURLRequest *)request
                     completionHandler:(void (^)(NSURLRequest *))completionHandler;
@end

@interface AFHARchiverManager : NSObject
@property (nonatomic, strong) NSMutableArray * archivers;

+ (instancetype)sharedInstance;

-(void)addArchiver:(AFHARchiver*)archiver;
-(void)removeArchiver:(AFHARchiver*)archiver;

@end

typedef BOOL (^AFHARchiverShouldArchiveOperationBlock)(AFHTTPRequestOperation * operation);
typedef BOOL (^AFHARchiverShouldARchiveTaskBlock)(NSURLSessionTask * task);

@interface AFHARchiver ()
@property (nonatomic,assign) BOOL isArchiving;
@property (nonatomic,copy) NSString * filePath;
@property (nonatomic,assign) unsigned long long filePosition;
@property (nonatomic,assign) BOOL hasAddedOneEntry;
@property (nonatomic,strong) NSString * creatorName;
@property (nonatomic,strong) NSString * creatorVersion;

@property (readwrite, nonatomic, copy) AFHARchiverShouldArchiveOperationBlock shouldArchiveOperationHandlerBlock;
@property (readwrite, nonatomic, copy) AFHARchiverShouldARchiveTaskBlock shouldArchiveTaskHandlerBlock;

@property (nonatomic,strong) NSMutableDictionary * taskStartTimeTrackingTable;
@property (nonatomic,strong) NSMutableDictionary * taskEndTimeTrackingTable;

@end

@implementation AFHARchiver

-(id)init{
    NSLog(@"Must use initWithPath:error");
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

-(id)initWithPath:(NSString*)filePath error:(NSError **)error{
    self = [super init];
    if(self){
        [self setupRedirectSwizzle];
        [self setupDefaultSessionValuesForFilePath:filePath];
        [self setupShellFileForFilePath:filePath error:error];
        [[AFHARchiverManager sharedInstance] addArchiver:self];
    }
    return self;
}

-(void)setupRedirectSwizzle{
    Method original, swizzled;
    
    original = class_getInstanceMethod([AFURLConnectionOperation class], @selector(connection:willSendRequest:redirectResponse:));
    swizzled = class_getInstanceMethod([AFURLConnectionOperation class], @selector(afharchiverswizzled_connection:willSendRequest:redirectResponse:));
    method_exchangeImplementations(original, swizzled);
    
    original = class_getInstanceMethod([AFURLSessionManager class], @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:));
    swizzled = class_getInstanceMethod([AFURLSessionManager class], @selector(afharchiverswizzled_URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:));
    method_exchangeImplementations(original, swizzled);
}

-(void)setupDefaultSessionValuesForFilePath:(NSString *)filePath{
    
    self.taskStartTimeTrackingTable = [NSMutableDictionary dictionary];
    self.taskEndTimeTrackingTable = [NSMutableDictionary dictionary];
    
    [self setFilePath:filePath];
    
    NSString * appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if(appName){
        [self setCreatorName:appName];
    }
    
    NSString * version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if(version){
        [self setCreatorVersion:version];
    }
    
}

-(void)setupShellFileForFilePath:(NSString*)filePath error:(NSError**)error{
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
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(taskDidStart:)
         name:AFNetworkingTaskDidStartNotification
         object:nil];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(taskDidFinish:)
         name:AFNetworkingTaskDidFinishNotification
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
        
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:AFNetworkingTaskDidStartNotification
         object:nil];
        
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:AFNetworkingTaskDidFinishNotification
         object:nil];
        
        self.isArchiving = NO;
    }
}

-(void)setShouldArchiveOperationBlock:(BOOL (^)(AFHTTPRequestOperation *))block{
    self.shouldArchiveOperationHandlerBlock = block;
}

-(void)setShouldArchiveTaskBlock:(BOOL (^)(NSURLSessionTask *))block{
    self.shouldArchiveTaskHandlerBlock = block;
}

-(void)dealloc{
    if(self.isArchiving == YES){
        [self stopArchiving];
    }
    [[AFHARchiverManager sharedInstance] removeArchiver:self];
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

-(NSDictionary*)HTTPArchiveCreatorDictionary{
    
    NSDictionary * creatorDictionary = @{@"name" : (self.creatorName!=nil ? self.creatorName:@"Unknown"),@"version":(self.creatorVersion!=nil?self.creatorVersion:@"Unknown"),@"comment":@"HTTPArchive Created by AFHARchiver"};
    
    return creatorDictionary;
}

-(void)archiveHTTPArchiveDictionary:(NSDictionary*)HTTPArchiveDictionary{
    dispatch_async(http_request_operation_archiving_queue(), ^{
        NSData * JSONData = [NSJSONSerialization dataWithJSONObject:HTTPArchiveDictionary options:0 error:nil];
        
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

#pragma mark - Private NSURLSessionTask Methods
-(void)taskDidStart:(NSNotification*)notification{
    NSURLSessionTask * task = [notification object];
    NSString * taskID = [NSString stringWithFormat:@"%d",[task taskIdentifier]];
    if(![self.taskStartTimeTrackingTable valueForKey:taskID]){
        [self.taskStartTimeTrackingTable setValue:[NSDate date] forKey:taskID];
    }
}

-(void)taskDidFinish:(NSNotification*)notification{
    NSURLSessionTask * task = [notification object];
    NSString * taskID = [NSString stringWithFormat:@"%d",[task taskIdentifier]];
    [self.taskEndTimeTrackingTable setValue:[NSDate date] forKey:taskID];
    if([self shouldArchiveTask:task]){
        [self archiveTask:task];
    }
    
    [self.taskEndTimeTrackingTable removeObjectForKey:taskID];
    [self.taskStartTimeTrackingTable removeObjectForKey:taskID];
}

-(void)taskDidRedirect:(NSURLSessionTask *)task currentRequest:(NSURLRequest*)currentRequest newRequest:(NSURLRequest *)newRequest redirectResponse:(NSHTTPURLResponse *)redirectResponse{
    NSDate * endTime = [NSDate date];
    NSDictionary * requestDictionary = AFHTTPArchiveRequestDictionaryForRequest(currentRequest);
    NSDictionary * responseDictionary = AFHTTPArchiveResponseDictionaryForResponse(redirectResponse, nil);
    
    NSString * taskID = [NSString stringWithFormat:@"%d",[task taskIdentifier]];
    NSDate * startTime = [self.taskStartTimeTrackingTable valueForKey:taskID];
    if(!startTime){
        startTime = endTime;
    }
    if([self shouldArchiveTask:task]){
        [self archiveHTTPArchiveDictionary:AFHTTPArchiveEntryDictionary(startTime, endTime, requestDictionary, responseDictionary)];
    }
    [self.taskStartTimeTrackingTable setValue:[NSDate date] forKey:taskID];
}

-(BOOL)shouldArchiveTask:(NSURLSessionTask*)task{
    if(self.shouldArchiveTaskHandlerBlock){
        return self.shouldArchiveTaskHandlerBlock(task);
    }
    else {
        return YES;
    }
}

-(void)archiveTask:(NSURLSessionTask*)task{
    NSString * taskID = [NSString stringWithFormat:@"%d",[task taskIdentifier]];
    NSDate * startTime = [self.taskStartTimeTrackingTable valueForKey:taskID];
    NSDate * endTime = [self.taskEndTimeTrackingTable valueForKey:taskID];
    NSDictionary * dictionary = AFHTTPArchiveEntryDictionaryForTask(task, startTime, endTime);
    [self archiveHTTPArchiveDictionary:dictionary];
}

#pragma mark - Private AFHTTPRequestOperation Methods
-(void)operationDidStart:(NSNotification*)notification{
    AFHTTPRequestOperation * operation = [notification object];
    objc_setAssociatedObject(operation, AFHTTPRequestOperationArchivingStartDate, [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(void)operationDidFinish:(NSNotification*)notification{
    AFHTTPRequestOperation * operation = [notification object];
    objc_setAssociatedObject(operation, AFHTTPRequestOperationArchivingEndDate, [NSDate date], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if([self shouldArchiveOperation:operation]){
        [self archiveOperation:operation];
    }
}

-(void)operationDidRedirect:(AFHTTPRequestOperation *)operation currentRequest:(NSURLRequest*)currentRequest newRequest:(NSURLRequest *)newRequest redirectResponse:(NSHTTPURLResponse *)redirectResponse{
    NSDate * endTime = [NSDate date];
    objc_setAssociatedObject(operation, AFHTTPRequestOperationArchivingRedirectURLRequest, newRequest, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSDate * startTime = objc_getAssociatedObject(operation, AFHTTPRequestOperationArchivingStartDate);
    //May not have a start time, if the 301 has been cached.
    if(!startTime){
        startTime = endTime;
    }
    NSDictionary * requestDictionary = AFHTTPArchiveRequestDictionaryForRequest(currentRequest);
    NSDictionary * responseDictionary = AFHTTPArchiveResponseDictionaryForResponse(redirectResponse, nil);
    if([self shouldArchiveOperation:operation]){
        [self archiveHTTPArchiveDictionary:AFHTTPArchiveEntryDictionary(startTime, endTime, requestDictionary, responseDictionary)];
    }
    //Reset the start time
    objc_setAssociatedObject(operation, AFHTTPRequestOperationArchivingStartDate, endTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+(NSDictionary*)HTTPArchiveRequestDictionaryForOperation:(AFHTTPRequestOperation*)operation{
    return AFHTTPArchiveRequestDictionaryForRequest(operation.request);
}

+(NSDictionary*)HTTPArchiveResponseDictionaryForOperation:(AFHTTPRequestOperation*)operation{
    return AFHTTPArchiveResponseDictionaryForResponse(operation.response, operation.responseData);
}

-(BOOL)shouldArchiveOperation:(AFHTTPRequestOperation*)operation{
    if(self.shouldArchiveOperationHandlerBlock)
        return self.shouldArchiveOperationHandlerBlock(operation);
    else
        return YES;
}

-(void)archiveOperation:(AFHTTPRequestOperation *)operation{
    NSDictionary * dictionary = AFHTTPArchiveEntryDictionaryForOperation(operation);
    [self archiveHTTPArchiveDictionary:dictionary];
}

@end


@implementation AFHARchiverManager

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(id)init{
    self = [super init];
    if(self){
        self.archivers = [NSMutableArray array];
    }
    return self;
}

-(void)addArchiver:(AFHARchiver *)archiver{
    [self.archivers addObject:archiver];
}

-(void)removeArchiver:(AFHARchiver *)archiver{
    [self.archivers removeObject:archiver];
}

@end

@implementation AFURLConnectionOperation(ArchiveRedirect)

- (NSURLRequest *)afharchiverswizzled_connection:(NSURLConnection *)connection
                                 willSendRequest:(NSURLRequest *)request
                                redirectResponse:(NSURLResponse *)redirectResponse{
    NSURLRequest * returnedRequest = [self afharchiverswizzled_connection:connection
                                                          willSendRequest:request
                                                         redirectResponse:redirectResponse];
    if(redirectResponse){
        [[[AFHARchiverManager sharedInstance] archivers]
         enumerateObjectsUsingBlock:^(AFHARchiver *archiver, NSUInteger idx, BOOL *stop) {
             [archiver operationDidRedirect:(AFHTTPRequestOperation*)self
                             currentRequest:connection.currentRequest
                                 newRequest:returnedRequest
                           redirectResponse:(NSHTTPURLResponse*)redirectResponse];
         }];
    }
    return returnedRequest;
}
@end

@implementation AFURLSessionManager(ArchiveRedirect)

- (void)afharchiverswizzled_URLSession:(NSURLSession *)session
                                  task:(NSURLSessionTask *)task
            willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                            newRequest:(NSURLRequest *)request
                     completionHandler:(void (^)(NSURLRequest *))completionHandler{
    [self
     afharchiverswizzled_URLSession:session
     task:task
     willPerformHTTPRedirection:response
     newRequest:request
     completionHandler:^(NSURLRequest *redirectedRequest) {
         if(response){
             [[[AFHARchiverManager sharedInstance] archivers]
              enumerateObjectsUsingBlock:^(AFHARchiver *archiver, NSUInteger idx, BOOL *stop) {
                  [archiver taskDidRedirect:task
                             currentRequest:task.currentRequest
                                 newRequest:redirectedRequest
                           redirectResponse:response];
              }];
         }
         if(completionHandler){
             completionHandler(redirectedRequest);
         }
     }];
}

@end
