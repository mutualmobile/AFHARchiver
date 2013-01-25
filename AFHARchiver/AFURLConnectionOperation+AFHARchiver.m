// AFURLConnectionOperation+HTTPArchive.m
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

#import "AFURLConnectionOperation+AFHARchiver.h"
#import <objc/runtime.h>

//In order to track down the start and end time of the request,
//we need to do some advanced method swizzling as outlined
//by MG below. The NSObject category is purely used to
//allow to call the base implementation of a method from a specific class,
//and then do our own custom implementation.
//http://www.cocoawithlove.com/2008/03/supersequent-implementation.html

#define invokeSupersequent(...) \
([self af_getImplementationOf:_cmd \
after:af_impOfCallingMethod(self, _cmd)]) \
(self, _cmd, ##__VA_ARGS__)

#define invokeSupersequentNoParameters() \
([self af_getImplementationOf:_cmd \
after:af_impOfCallingMethod(self, _cmd)]) \
(self, _cmd)

IMP af_impOfCallingMethod(id lookupObject, SEL selector);

@interface NSObject (_AFSupersequentImplementation)
- (IMP)af_getImplementationOf:(SEL)lookup after:(IMP)skip;
@end

@implementation NSObject (_AFSupersequentImplementation)

// Lookup the next implementation of the given selector after the
// default one. Returns nil if no alternate implementation is found.
- (IMP)af_getImplementationOf:(SEL)lookup after:(IMP)skip
{
    BOOL found = NO;
    
    Class currentClass = object_getClass(self);
    while (currentClass)
    {
        // Get the list of methods for this class
        unsigned int methodCount;
        Method *methodList = class_copyMethodList(currentClass, &methodCount);
        
        // Iterate over all methods
        unsigned int i;
        for (i = 0; i < methodCount; i++)
        {
            // Look for the selector
            if (method_getName(methodList[i]) != lookup)
            {
                continue;
            }
            
            IMP implementation = method_getImplementation(methodList[i]);
            
            // Check if this is the "skip" implementation
            if (implementation == skip)
            {
                found = YES;
            }
            else if (found)
            {
                // Return the match.
                free(methodList);
                return implementation;
            }
        }
        
        // No match found. Traverse up through super class' methods.
        free(methodList);
        
        currentClass = class_getSuperclass(currentClass);
    }
    return nil;
}

IMP af_impOfCallingMethod(id lookupObject, SEL selector)
{
    NSUInteger returnAddress = (NSUInteger)__builtin_return_address(0);
    NSUInteger closest = 0;
    
    // Iterate over the class and all superclasses
    Class currentClass = object_getClass(lookupObject);
    while (currentClass)
    {
        // Iterate over all instance methods for this class
        unsigned int methodCount;
        Method *methodList = class_copyMethodList(currentClass, &methodCount);
        unsigned int i;
        for (i = 0; i < methodCount; i++)
        {
            // Ignore methods with different selectors
            if (method_getName(methodList[i]) != selector)
            {
                continue;
            }
            
            // If this address is closer, use it instead
            NSUInteger address = (NSUInteger)method_getImplementation(methodList[i]);
            if (address < returnAddress && address > closest)
            {
                closest = address;
            }
        }
		
        free(methodList);
        currentClass = class_getSuperclass(currentClass);
    }
    
    return (IMP)closest;
}

@end



static char kAFHTTPArchiveConnectionStartTimeObjectKey;
static char kAFHTTPArchiveConnectionEndTimeObjectKey;

@interface AFURLConnectionOperation (_AFHARchiver)
@property (readwrite, nonatomic, strong, setter = af_setStartTime:) NSDate * af_startTime;
@property (readwrite, nonatomic, strong, setter = af_setEndTime:) NSDate * af_endTime;
@end

@implementation AFURLConnectionOperation (_AFHARchiver)
@dynamic af_startTime;
@dynamic af_endTime;
@end

@implementation AFURLConnectionOperation (AFHARchiver)

- (NSDate* )af_startTime {
    return (NSDate *)objc_getAssociatedObject(self, &kAFHTTPArchiveConnectionStartTimeObjectKey);
}

- (void)af_setStartTime:(NSDate *)startTime {
    objc_setAssociatedObject(self, &kAFHTTPArchiveConnectionStartTimeObjectKey, startTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate* )af_endTime {
    return (NSDate *)objc_getAssociatedObject(self, &kAFHTTPArchiveConnectionEndTimeObjectKey);
}

- (void)af_setEndTime:(NSDate *)endTime {
    objc_setAssociatedObject(self, &kAFHTTPArchiveConnectionEndTimeObjectKey, endTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Property Returns
-(NSDate*)startTime{
    return self.af_startTime;
}

-(NSDate*)endTime{
    return self.af_endTime;
}

-(NSTimeInterval)duration{
    return [self.endTime timeIntervalSinceDate:self.startTime];
}

#pragma mark - Override Methods

-(void)start{
    invokeSupersequentNoParameters();
    [self af_setStartTime:[NSDate date]];
}

-(void)finish{
    [self af_setEndTime:[NSDate date]];
    invokeSupersequentNoParameters();
}


@end
