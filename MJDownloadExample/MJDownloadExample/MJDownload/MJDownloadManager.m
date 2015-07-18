//
//  MJDownloadManager.m
//  MJDownloadExample
//
//  Created by MJ Lee on 15/7/16.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJDownloadManager.h"
#import "NSString+MJDownload.h"
#import "MJDownloadConst.h"

/****************** MJDownloadInfo Begin ******************/
@interface MJDownloadInfo()
/** 存放所有的进度回调 */
@property (copy, nonatomic) MJDownloadProgressBlock progressBlock;
/** 存放所有的完毕回调 */
@property (copy, nonatomic) MJDownloadCompletionBlock completionBlock;
/** 任务 */
@property (strong, nonatomic) NSURLSessionDataTask *task;
/** 文件流 */
@property (strong, nonatomic) NSOutputStream *stream;
@end

@implementation MJDownloadInfo

@end
/****************** MJDownloadInfo End ******************/


/****************** MJDownloadManager Begin ******************/
/** 根文件夹 */
static NSString * const MJDownloadRootDir = @"com_520it_www_mjdownload";

@interface MJDownloadManager() <NSURLSessionDataDelegate>
/** session */
@property (strong, nonatomic) NSURLSession *session;
/** 存放所有的任务 */
@property (strong, nonatomic) NSMutableDictionary *tasks;
/** 存放所有的文件流 */
@property (strong, nonatomic) NSMutableDictionary *streams;
/** 存放所有的文件名 */
@property (strong, nonatomic) NSMutableDictionary *filenames;
/** 存放所有的文件路径 */
@property (strong, nonatomic) NSMutableDictionary *files;
/** 存放所有文件总大小的文件路径 */
@property (copy, nonatomic) NSString *totalFileSizesFile;
/** 存放所有文件总大小 */
@property (strong, nonatomic) NSMutableDictionary *totalFileSizes;
/** 存放所有的进度回调 */
@property (strong, nonatomic) NSMutableDictionary *progressBlocks;
/** 存放所有的完毕回调 */
@property (strong, nonatomic) NSMutableDictionary *completionBlocks;
@end

@implementation MJDownloadManager

#pragma mark - 初始化
MJSingletonM(^{
    
});

#pragma mark - 路径处理
/**
 *  获得文件名
 */
- (NSString *)filenameForURL:(NSString *)url
{
    if (url == nil) return nil;
    
    NSString *filename = self.filenames[url];
    if (filename == nil) {
        filename = url.MD5;
        self.filenames[url] = filename;
    }
    
    return filename;
}

/**
 *  获得文件路径
 */
- (NSString *)fileForURL:(NSString *)url
{
    if (url == nil) return nil;
    
    NSString *file = self.files[url];
    if (file == nil) {
        file = [[NSString stringWithFormat:@"%@/%@", MJDownloadRootDir, [self filenameForURL:url]] prependCaches];
        self.files[url] = file;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:file]) {
        NSString *dir = [file stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return file;
}

/**
 *  获得存放文件总大小的文件路径
 */
- (NSString *)totalFileSizesFile
{
    if (_totalFileSizesFile == nil) {
        _totalFileSizesFile = [[NSString stringWithFormat:@"%@/%@", MJDownloadRootDir, @"MJDownloadFileSizes.plist".MD5] prependCaches];
    }
    return _totalFileSizesFile;
}

/**
 *  获得文件的总大小
 */
- (NSInteger)totalFileSizeForURL:(NSString *)url
{
    return [self.totalFileSizes[url] integerValue];
}

- (NSOutputStream *)streamForURL:(NSString *)url
{
    NSOutputStream *stream = self.streams[url];
    if (stream == nil) {
        stream = [NSOutputStream outputStreamToFileAtPath:[self fileForURL:url] append:YES];
        self.streams[url] = stream;
    }
    return stream;
}

#pragma mark - 懒加载
- (NSURLSession *)session
{
    if (!_session) {
        // 配置
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        // 队列
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 3;
        // session
        self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:queue];
    }
    return _session;
}

- (NSMutableDictionary *)tasks
{
    if (!_tasks) {
        self.tasks = [NSMutableDictionary dictionary];
    }
    return _tasks;
}

- (NSMutableDictionary *)streams
{
    if (!_streams) {
        self.streams = [NSMutableDictionary dictionary];
    }
    return _streams;
}

- (NSMutableDictionary *)filenames
{
    if (!_filenames) {
        self.filenames = [NSMutableDictionary dictionary];
    }
    return _filenames;
}

- (NSMutableDictionary *)files
{
    if (!_files) {
        self.files = [NSMutableDictionary dictionary];
    }
    return _files;
}

- (NSMutableDictionary *)totalFileSizes
{
    if (!_totalFileSizes) {
        self.totalFileSizes = [NSMutableDictionary dictionaryWithContentsOfFile:self.totalFileSizesFile];
        if (_totalFileSizes == nil) {
            self.totalFileSizes = [NSMutableDictionary dictionary];
        }
    }
    return _totalFileSizes;
}

- (NSMutableDictionary *)progressBlocks
{
    if (!_progressBlocks) {
        self.progressBlocks = [NSMutableDictionary dictionary];
    }
    return _progressBlocks;
}

- (NSMutableDictionary *)completionBlocks
{
    if (!_completionBlocks) {
        self.completionBlocks = [NSMutableDictionary dictionary];
    }
    return _completionBlocks;
}

#pragma mark - 私有方法
/**
 *  清除资源
 */
- (void)free:(NSString *)url
{
    if (url == nil) return;
    
    /** 存放所有的任务 */
    [self.tasks removeObjectForKey:url];
    
    /** 存放所有的文件流 */
    [self.streams removeObjectForKey:url];
    
    /** 存放所有的文件名 */
    [self.filenames removeObjectForKey:url];
    
    /** 存放所有的文件路径 */
    [self.files removeObjectForKey:url];
    
    /** 存放所有文件总大小 */
    [self.totalFileSizes removeObjectForKey:url];
    
    /** 存放所有的进度回调 */
    [self.progressBlocks removeObjectForKey:url];
    
    /** 存放所有的完毕回调 */
    [self.completionBlocks removeObjectForKey:url];
}

/**
 *  通知进度改变
 */
- (void)notifyProgressWithUrl:(NSString *)url bytesWritten:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    // block
    MJDownloadProgressBlock block = self.progressBlocks[url];
    !block ? : block(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
}

/**
 *  通知下载完毕
 */
- (void)notifyCompletionWithUrl:(NSString *)url file:(NSString *)file error:(NSError *)error
{
    // block
    MJDownloadCompletionBlock block = self.completionBlocks[url];
    !block ? : block(file, error);
}

#pragma mark - 公共方法
- (BOOL)download:(NSString *)url toDestinationPath:(NSString *)destinationPath progress:(MJDownloadProgressBlock)progress completion:(MJDownloadCompletionBlock)completion
{
    if (url == nil) return NO;
    
    // 设置文件路径
    if (destinationPath) {
        self.files[url] = destinationPath;
        self.filenames[url] = [destinationPath lastPathComponent];
    }
    
    // 更新block
    if (progress) self.progressBlocks[url] = progress;
    if (completion) self.completionBlocks[url] = completion;
    
    // 如果已经下载完毕
    if ([self downloadStateForURL:url] == MJDownloadStateCompleted) {
        // 完毕
        [self notifyCompletionWithUrl:url file:[self fileForURL:url] error:nil];
        
        // 清理资源
        [self free:url];
        return YES;
    }
    
    // 获得任务
    NSURLSessionDataTask *task = self.tasks[url];
    
    // 如果没有，就创建任务，开始
    if (task == nil) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-", [self fileForURL:url].fileSize];
        [request setValue:range forHTTPHeaderField:@"Range"];
        task = [self.session dataTaskWithRequest:request];
        // 设置描述
        task.taskDescription = url;
        self.tasks[url] = task;
    }
    
    // 开始任务
    [self resume:url];
    
    return NO;
}

- (BOOL)download:(NSString *)url progress:(MJDownloadProgressBlock)progress completion:(MJDownloadCompletionBlock)completion
{
    return [self download:url toDestinationPath:nil progress:progress completion:completion];
}

- (void)cancelAll
{
    [self.tasks enumerateKeysAndObjectsUsingBlock:^(NSString *url, NSURLSessionDataTask *task, BOOL *stop) {
        [self cancel:url];
    }];
}

- (void)suspendAll
{
    [self.tasks enumerateKeysAndObjectsUsingBlock:^(NSString *url, NSURLSessionDataTask *task, BOOL *stop) {
        [self suspend:url];
    }];
}

- (void)resumeAll
{
    [self.tasks enumerateKeysAndObjectsUsingBlock:^(NSString *url, NSURLSessionDataTask *task, BOOL *stop) {
        [self resume:url];
    }];
}

- (void)cancel:(NSString *)url
{
    if (url == nil) return;
    
    // 获得任务
    NSURLSessionDataTask *task = self.tasks[url];
    
    // 取消
    [task cancel];
    
    // 清除操作
    [self free:url];
}

- (void)suspend:(NSString *)url
{
    if (url == nil) return;
    
    // 获得任务
    NSURLSessionDataTask *task = self.tasks[url];
    
    // 取消
    [task suspend];
}

- (void)resume:(NSString *)url
{
    if (url == nil) return;
    
    // 获得任务
    NSURLSessionDataTask *task = self.tasks[url];
    
    // 取消
    [task resume];
}

- (MJDownloadState)downloadStateForURL:(NSString *)url
{
    if (url == nil) return MJDownloadStateNone;
    
    // 如果是下载完毕
    NSInteger fileSize = [self fileForURL:url].fileSize;
    if (fileSize && fileSize == [self totalFileSizeForURL:url]) {
        return MJDownloadStateCompleted;
    }
    
    // 获得任务
    NSURLSessionDataTask *task = self.tasks[url];
    
    // 如果下载失败
    if (task.error) return MJDownloadStateCanceled;
    
    // 根据任务的状态
    switch (task.state) {
        case NSURLSessionTaskStateCanceling: // 取消
            return MJDownloadStateCanceled;
            
        case NSURLSessionTaskStateRunning: // 下载中
            return MJDownloadStateResumed;
            
        case NSURLSessionTaskStateSuspended: // 暂停中
            return MJDownloadStateSuspened;
            
        default:
            break;
    }
    
    return MJDownloadStateNone;
}

#pragma mark - <NSURLSessionDataDelegate>
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSString *url = dataTask.taskDescription;
    // 获得文件总长度
    if (![self totalFileSizeForURL:url]) {
        NSInteger totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] + [self fileForURL:url].fileSize;
        // 存储文件总长度
        self.totalFileSizes[url] = @(totalLength);
        [self.totalFileSizes writeToFile:self.totalFileSizesFile atomically:YES];
    }
    
    
    // 打开流
    [[self streamForURL:dataTask.taskDescription] open];
    
    // 继续
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    NSString *url = dataTask.taskDescription;
    // 写数据
    [[self streamForURL:url] write:data.bytes maxLength:data.length];
    
    // 通知
    [self notifyProgressWithUrl:url bytesWritten:data.length totalBytesWritten:[self fileForURL:url].fileSize totalBytesExpectedToWrite:[self totalFileSizeForURL:url]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    NSString *url = task.taskDescription;
    // 关闭流
    [[self streamForURL:url] close];
    
    // 通知(如果下载完毕 或者 下载出错了)
    if ([self downloadStateForURL:url] == MJDownloadStateCompleted || error) {
        [self notifyCompletionWithUrl:url file:[self fileForURL:url] error:error];
    }
    
    // 清除
    [self free:task.taskDescription];
}
@end
/****************** MJDownloadManager End ******************/
