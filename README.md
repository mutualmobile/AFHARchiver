AFHARchiver
===============================

An [AFNetworking](https://github.com/AFNetworking/AFNetworking/) extension to automatically generate a HTTP Archive file of all of your network requests!

## Overview
What is HTTP Archiving (HAR)? It's a specification that allows you to store HTTP request/responses as well as meta data, and view that information at a later time to help with debugging.

You can find the HAR specification [here](http://www.softwareishard.com/blog/har-12-spec/), and you can find an online HAR viewer [here](http://www.softwareishard.com/har/viewer/). You can download a sample HAR log from [here](http://mutualmobile.github.com/AFHARchiver/files/01-16-2013_02_24_30_log.HAR) and drag it into the online viewer to take a look.

There is also a long list of tools that support the HAR format [here](http://www.softwareishard.com/blog/har-adopters/).

The full spec has not been fully implemented yet, but basic timing information has been included. By releasing this to the community, we are hopeful more advanced logging data will be implemented.

## How to use the HARchiver

Using a HARchiver is as simple as creating an instance of it, and telling it to start. The archiver will archive requests as they come in directly to disk at the path you specify.

``` objective-c
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
NSString *documentsDirectory = [paths objectAtIndex:0];
NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"log.har"];

self.afArchiver = [[AFHARchiver alloc] initWithPath:filePath error:nil];
[self.afArchiver startArchiving];
```

## Archiving Specific AFHTTPRequestOperations / NSURLSessionTasks

You will most likely run into a scenario where you only want to archive specific operations. The most common use has been to ignore logging image files to prevent your archive from growing too large in size. For AFHTTPRequestOperations, you can use <tt>setShouldArchiveOperationBlock:</tt>. For NSURLSessionTasks, you can use <tt>setShouldArchiveTaskBlock:</tt>.

``` objective-c
[self.afArchiver
 setShouldArchiveOperationBlock:^BOOL(AFHTTPRequestOperation *operation) {
     return [operation.responseSerializer isKindOfClass:[AFJSONResponseSerializer class]];
 }];
[self.afArchiver
 setShouldArchiveTaskBlock:^BOOL(NSURLSessionTask *task, id<AFURLResponseSerialization> responseSerializer, id serializedResponse) {
     return [(NSObject*)responseSerializer isKindOfClass:[AFJSONResponseSerializer class]];
 }];
}];
```

## A Few TODO's

There is some advanced functionality that has not yet been implemented that will lead to more advanced logs. These include the following:
* Split the **duration** of the request into the proper time buckets. Currently all time is passed to the duration bucket.
* Determine if responses are returning from a local cache using the **cache** property.
* Log all cookie information to the **cookie** property.
* Calculate the correct **headerSize**.

## Credits

Created by Kevin Harwood ([Email](kevin.harwood@mutualmobile.com) | [Twitter](https://twitter.com/kevinharwood)) at [Mutual Mobile](http://mutualmobile.com).

## License

AFHARchiver is available under the MIT license. See the LICENSE file for more info
