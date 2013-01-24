AFHTTPRequestOperationHARchiver
===============================

An [AFNetworking](https://github.com/AFNetworking/AFNetworking/) extension to automatically generate HTTP Archive files of all of your network requests!

## Overview
What is HTTPArchiving? It's a specification that allows you to store HTTP request/responses as well as meta data, and view that information at a later time to help with debugging.

You can find the HAR specification [here](http://www.softwareishard.com/blog/har-12-spec/), and you can find an online HAR viewer [here](http://www.softwareishard.com/har/viewer/). There is also a long list of tools that support the HAR format [here](http://www.softwareishard.com/blog/har-adopters/).

The full spec has not been fully implemented yet, but basic timing information has been included. By releasing this to the community, we are hopeful more advanced logging data will be implemented.

## How to use the HARchiver

Using a HARChiver is as simple as creating an instance of it, and telling it to start. The archiver will archive requests as they come in directly to disk at the path you specify.

``` objective-c
	self.afArchiver = [[AFHTTPRequestOperationHARchiver alloc] initWithPath:path error:nil];
	[self.afArchiver startArchiving];
```

## Archiving Specific Requests

You will most likely run into a scenerio where you only want to archive specific requests. The most common use has been to ignore logging image files to prevent your archive from growing too large in size. You can use <tt>setShouldArchiveOperationBlock:</tt> to provide custom archiving behavior.

``` objective-c
	[afArchvier setShouldArchiveOperationBlock:^BOOL(AFHTTPRequestOperation *operation) {
            return !([operation isKindOfClass:[AFImageRequestOperation class]]);
    }];
```

## A Few TODO's

There is some advanced functionality that has not yet been implemented that will lead to more advanced logs. These include the following:
* Split the **duration** of the request into the proper time buckets. Currently all time is passed to the duration bucket.
* Determine if responses are returning from a local cache using the **cache** property.
* Log all cookie information to the **cookie** property.
* Include redirect information in the **redirectURL** property.
* Calculate the correct **headerSize**.

## Contact

Follow Mutual Mobile on Twitter ([@MutualMobile](https://twitter.com/MutualMobile))

### Creators

[Kevin Harwood](http://github.com/kcharwood)  
[@kevinharwood](https://twitter.com/kevinharwood)
