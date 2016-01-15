//
//  main.m
//  DiawiUploadMac
//
//  Created by Alexander Stepanov on 13.01.16.
//  Copyright © 2016 Alexander Stepanov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking.h>

// 1mb
#define CHUNK_SIZE 1048576

void postResult();
void postChunk(NSInteger chunk, NSInteger chunks, NSData* data);


NSString* tmpName;
NSString* fileName;
NSString* result;


NSString* randomStringWithLength(int len) {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
    }
    return randomString;
}


void post(NSString* url, void (^block)(id <AFMultipartFormData> formData), void (^success)(NSURLResponse *response, id responseObject)) {
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST"
                                                                                              URLString:url
                                                                                             parameters:nil
                                                                              constructingBodyWithBlock:block
                                                                                                  error:nil];
    
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    AFHTTPResponseSerializer* serializer = manager.responseSerializer;
    serializer.acceptableContentTypes = [NSSet setWithArray:@[@"text/html", @"text/plain"]];
    
    NSURLSessionUploadTask *uploadTask;
    uploadTask = [manager
                  uploadTaskWithStreamedRequest:request
                  progress:^(NSProgress * _Nonnull uploadProgress) {
                  }
                  completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                      if (error) {
                          //NSLog(@"Error: %@", error);
                          result = [NSString stringWithFormat:@"Error: %@", error];
                      }else{
                          success(response, responseObject);
                      }
                  }];
    
    [uploadTask resume];
}

int main(int argc, const char * argv[]) {
    
    do{
        if (argc < 2){
            result = @"Error: no input file";
            break;
        }
        
        NSString* filePath = [NSString stringWithUTF8String:argv[1]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            result = @"Error: file not exist";
            break;
        }
        
        fileName = [filePath lastPathComponent];
        
        tmpName = [randomStringWithLength(20) stringByAppendingString:@".ipa"];
        //NSLog(@"tmp name %@", tmpName);
        
        NSData* data = [NSData dataWithContentsOfFile:filePath];
        
        NSInteger count = data.length / CHUNK_SIZE;
        postChunk(0, count, data);
        
        while (result == nil) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
        
    }while (false);

    printf("%s\r\n", [result UTF8String]);
    return 0;
}
    

void postChunk(NSInteger chunk, NSInteger chunks, NSData* data) {
    //NSLog(@"chunk %@", @(chunk));
    
    post(@"https://www.diawi.com/upload.php", ^(id<AFMultipartFormData> formData) {
        
        NSString* chunkStr = [@(chunk) stringValue];
        NSString* chunksStr = [@(chunks) stringValue];
        
        NSInteger loc = chunk*CHUNK_SIZE;
        NSInteger len = chunk == chunks-1 ? data.length - loc : CHUNK_SIZE;
        
        NSData* chunkData = [data subdataWithRange:NSMakeRange(loc, len)];
        
        [formData appendPartWithFormData:[tmpName dataUsingEncoding:NSUTF8StringEncoding] name:@"name"];
        [formData appendPartWithFormData:[chunkStr dataUsingEncoding:NSUTF8StringEncoding] name:@"chunk"];
        [formData appendPartWithFormData:[chunksStr dataUsingEncoding:NSUTF8StringEncoding] name:@"chunks"];
        [formData appendPartWithFileData:chunkData name:@"file" fileName:@"blob" mimeType:@"application/octet-stream"];
        
    }, ^(NSURLResponse *response, id responseObject) {
        
        if (chunk == chunks-1){
            postResult();
        }else{
            postChunk(chunk+1, chunks, data);
        }
        
    });
}

void postResult() {
    
    post(@"https://www.diawi.com/result.php", ^(id<AFMultipartFormData> formData) {
        
        [formData appendPartWithFormData:[tmpName dataUsingEncoding:NSUTF8StringEncoding] name:@"uploader_0_tmpname"];
        [formData appendPartWithFormData:[fileName dataUsingEncoding:NSUTF8StringEncoding] name:@"uploader_0_name"];
        [formData appendPartWithFormData:[@"done" dataUsingEncoding:NSUTF8StringEncoding] name:@"uploader_0_status"];
        [formData appendPartWithFormData:[@"1" dataUsingEncoding:NSUTF8StringEncoding] name:@"uploader_count"];
        [formData appendPartWithFormData:[@"" dataUsingEncoding:NSUTF8StringEncoding] name:@"password"];
        [formData appendPartWithFormData:[@"" dataUsingEncoding:NSUTF8StringEncoding] name:@"comment"];
        [formData appendPartWithFormData:[@"" dataUsingEncoding:NSUTF8StringEncoding] name:@"email"];
        [formData appendPartWithFormData:[@"on" dataUsingEncoding:NSUTF8StringEncoding] name:@"udid"];
        [formData appendPartWithFormData:[@"on" dataUsingEncoding:NSUTF8StringEncoding] name:@"wall"];
        
    }, ^(NSURLResponse *response, id responseObject) {
        
        //NSLog(@"%@ %@", response, responseObject);
        result = responseObject[@"url"];
        if (result.length == 0){
            result = [NSString stringWithFormat:@"Error: invalid response %@", response];
        }
    });
}
