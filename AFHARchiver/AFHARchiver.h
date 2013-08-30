// AFHARchiver.h
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

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

/**
 `AFHARchiver` is a class for creating an HTTP Archive (HAR) file that can be used for logging information around specific requests. This class will listen for 'AFHTTPRequestOperations' to complete, and log them directly to disk.
 
 ## HTTP Archive
 
 The HTTP Archive Specification ( http://www.softwareishard.com/blog/har-12-spec/ ) outlines how an HTTP request can be archived for viewing. This specification is supported by most HTTP request viewers available today.
 
 There is a online viewer located at http://www.softwareishard.com/har/viewer/ that allows developers to drop HAR files directly into the page and view all of the archived information.
 
 The archiver will asynchronously archive data to disk as operations complete.
 
 */
@interface AFHARchiver : NSObject

/**
 The file path for which the archive file should be stored. This must be set in the 'initWithPath:error:' method.
 */
@property (readonly,nonatomic,copy) NSString * filePath;

/**
 A BOOL flag representing if the archiving is actively listening for request completions, and logging them to disk.
 */
@property (readonly,nonatomic,assign) BOOL isArchiving;

///-----------------------------------------
/// @name Initialization
///-----------------------------------------

/**
 Initializes and returns a newly archiver object and creates a file at the specified file path.
 
 @param filePath The file path that points to where the archive file should be created.
 @param error The error pointer used to let the caller know if there was a problem creating the archiver.
 
 @discussion This is the designated initializer.
 */
-(id)initWithPath:(NSString*)filePath error:(NSError **)error;

///-----------------------------------------
/// @name Getting Starting and Stopping Archiving
///-----------------------------------------

/**
 Called to start archiving.
 
 @discussion When this method is called, the archiver will begin listening for AFHTTPRequestOperations to complete, and log them to disk.
 */
-(void)startArchiving;

/**
 Called to stop archiving.
 
 @discussion When this method is called, the archiver will stop listening for AFHTTPRequestOperations. Note that if previous file writes have been queued up, those will continue to write until finished.
 */
-(void)stopArchiving;

///-----------------------------------------
/// @name Archiving Operations
///-----------------------------------------
/**
 Used to help properly archive the redirects.
 
 @param operation The operation that has been redirected
 @param currentRequest The current request that has been redirected
 @param newRequest The proposed request to redirect to
 @param redirectResponse The redirect response
 
 @discussion In order to properly support redirects, you must call this method from within the operations redirect response block. Please note that you should only call this method if the 'redirectResponse' object of the block is not nil. For example, in the subclass of an AFHTTPClient in `HTTPOperationWithRequest:success:failure:`, you could do the following:
 
 ```
     __weak AFHTTPRequestOperation *weakOp = op;
     [op setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
         if(redirectResponse){
            NSMutableURLRequest * newRequest = [connection.currentRequest mutableCopy];
            [newRequest setURL:request.URL];
         
            [self.afArchiver operationDidRedirect:weakOp
                                   currentRequest:connection.currentRequest
                                       newRequest:newRequest
                                 redirectResponse:(NSHTTPURLResponse*)redirectResponse];
         
            return newRequest;
         }
         else {
            return request;
         }
     }];
 ```
 */
-(void)operationDidRedirect:(AFHTTPRequestOperation *)operation currentRequest:(NSURLRequest*)currentRequest newRequest:(NSURLRequest *)newRequest redirectResponse:(NSHTTPURLResponse *)redirectResponse;

///-----------------------------------------
/// @name Archiving Operations
///-----------------------------------------

/**
 Used to determine if the archiver should log the particular operation.
 
 @param block A block to be called to determine if an operation should be archived.
 
 @discussion This method can be used to prevent certain operations from being logged. For example, you may only want to log specific API requests, so this block can be used to inspect the operation, and determine if it should be logged. A more common use would be to inspect and see if the operation is an 'AFImageRequestOperation', and choose not to log it. This can save a significant amount of disk space.
 */
-(void)setShouldArchiveOperationBlock:(BOOL (^)(AFHTTPRequestOperation * operation))block;

@end
