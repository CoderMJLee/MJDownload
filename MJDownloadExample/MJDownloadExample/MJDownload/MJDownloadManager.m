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

/** 存放所有的文件大小 */
static NSMutableDictionary *_totalFileSizes;
/** 存放所有的文件大小的文件路径 */
static NSString *_totalFileSizesFile;

/** 根文件夹 */
static NSString * const MJDownloadRootDir = @"com_520it_www_mjdownload";

/** 默认manager的标识 */
static NSString * const MJDowndloadManagerDefaultIdentifier = @"com.520it.www.downloadmanager";

/****************** MJDownloadInfo Begin ******************/
@interface MJDownloadInfo()
/******** Readonly Begin ********/
/** 下载状态 */
@property (assign, nonatomic) MJDownloadState state;
/** 这次写入的数量 */
@property (assign, nonatomic) int64_t bytesWritten;
/** 已下载的数量 */
@property (assign, nonatomic) int64_t totalBytesWritten;
/** 文件的总大小 */
@property (assign, nonatomic) int64_t totalBytesExpectedToWrite;
/** 文件名 */
@property (copy, nonatomic) NSString *filename;
/** 文件路径 */
@property (copy, nonatomic) NSString *file;
/** 文件url */
@property (copy, nonatomic) NSString *url;
/** 下载的错误信息 */
@property (strong, nonatomic) NSError *error;
/******** Readonly End ********/

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
- (NSString *)file
{
    if (_file == nil) {
        _file = [[NSString stringWithFormat:@"%@/%@", MJDownloadRootDir, self.filename] prependCaches];
    }
    
    if (_file && ![[NSFileManager defaultManager] fileExistsAtPath:_file]) {
        NSString *dir = [_file stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return _file;
}

- (NSString *)filename
{
    if (_filename == nil) {
        _filename = self.url.MD5;
    }
    return _filename;
}

- (NSOutputStream *)stream
{
    if (_stream == nil) {
        _stream = [NSOutputStream outputStreamToFileAtPath:self.file append:YES];
    }
    return _stream;
}

- (int64_t)totalBytesWritten
{
    if (!_totalBytesWritten) {
        _totalBytesWritten = self.file.fileSize;
    }
    return _totalBytesWritten;
}

- (int64_t)totalBytesExpectedToWrite
{
    if (!_totalBytesExpectedToWrite) {
        _totalBytesExpectedToWrite = [_totalFileSizes[self.url] integerValue];
    }
    return _totalBytesExpectedToWrite;
}

- (MJDownloadState)state
{
    // 如果是下载完毕
    if (self.totalBytesExpectedToWrite && self.totalBytesWritten == self.totalBytesExpectedToWrite) {
        return MJDownloadStateCompleted;
    }
    
    // 如果下载失败
    if (self.task.error) return MJDownloadStateCanceled;
    
    // 根据任务的状态
    switch (self.task.state) {
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

/**
 *  初始化任务
 */
- (void)setupTask:(NSURLSession *)session
{
    if (self.task) return;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.url]];
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", self.totalBytesWritten];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    self.task = [session dataTaskWithRequest:request];
    // 设置描述
    self.task.taskDescription = self.url;
}

/**
 *  通知进度改变
 */
- (void)notifyProgress
{
    !self.progressBlock ? : self.progressBlock(self.bytesWritten, self.totalBytesWritten, self.totalBytesExpectedToWrite);
}

/**
 *  通知下载完毕
 */
- (void)notifyCompletion
{
    !self.completionBlock ? : self.completionBlock(self.file, self.error);
}
@end
/****************** MJDownloadInfo End ******************/


/****************** MJDownloadManager Begin ******************/
@interface MJDownloadManager() <NSURLSessionDataDelegate>
/** session */
@property (strong, nonatomic) NSURLSession *session;
/** 存放所有文件的下载信息 */
@property (strong, nonatomic) NSMutableDictionary *downloadInfoDict;
/** 存放所有文件的下载信息 */
@property (strong, nonatomic) NSMutableArray *downloadInfoArray;
/** 存放正在下载的文件的下载信息 */
@property (strong, nonatomic) NSMutableArray *downloadingDownloadInfoArray;
@end

@implementation MJDownloadManager

/** 存放所有的manager */
static NSMutableDictionary *_managers;

+ (void)initialize
{
    _totalFileSizesFile = [[NSString stringWithFormat:@"%@/%@", MJDownloadRootDir, @"MJDownloadFileSizes.plist".MD5] prependCaches];
    
    _totalFileSizes = [NSMutableDictionary dictionaryWithContentsOfFile:_totalFileSizesFile];
    if (_totalFileSizes == nil) {
        _totalFileSizes = [NSMutableDictionary dictionary];
    }
    
    _managers = [NSMutableDictionary dictionary];
}

+ (instancetype)defaultManager
{
    return [self managerWithIdentifier:MJDowndloadManagerDefaultIdentifier];
}

+ (instancetype)manager
{
    return [[self alloc] init];
}

+ (instancetype)managerWithIdentifier:(NSString *)identifier
{
    if (identifier == nil) return [self manager];
    
    MJDownloadManager *mgr = _managers[identifier];
    if (!mgr) {
        mgr = [self manager];
        _managers[identifier] = mgr;
    }
    return mgr;
}

#pragma mark - 懒加载
- (NSURLSession *)session
{
    if (!_session) {
        // 配置
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        // session
        self.session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:self.queue];
    }
    return _session;
}

- (NSOperationQueue *)queue
{
    if (!_queue) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (NSMutableDictionary *)downloadInfoDict
{
    if (!_downloadInfoDict) {
        self.downloadInfoDict = [NSMutableDictionary dictionary];
    }
    return _downloadInfoDict;
}

- (NSMutableArray *)downloadInfoArray
{
    if (!_downloadInfoArray) {
        self.downloadInfoArray = [NSMutableArray array];
    }
    return _downloadInfoArray;
}

- (NSMutableArray *)downloadingDownloadInfoArray
{
    if (!_downloadingDownloadInfoArray) {
        self.downloadingDownloadInfoArray = [NSMutableArray array];
    }
    return _downloadingDownloadInfoArray;
}

#pragma mark - 私有方法

/**
 *  清除资源
 */
- (void)free:(NSString *)url
{
    if (url == nil) return;
    
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:url];
    
    /** 移除下载信息 */
    [self.downloadInfoArray removeObject:info];
    [self.downloadingDownloadInfoArray removeObject:info];
    [self.downloadInfoDict removeObjectForKey:url];
}

#pragma mark - 公共方法
- (MJDownloadInfo *)download:(NSString *)url toDestinationPath:(NSString *)destinationPath progress:(MJDownloadProgressBlock)progress completion:(MJDownloadCompletionBlock)completion
{
    if (url == nil) return nil;
    
    // 下载信息
    MJDownloadInfo *info = self.downloadInfoDict[url];
    if (info == nil) {
        info = [[MJDownloadInfo alloc] init];
        info.url = url; // 设置url
        self.downloadInfoDict[url] = info;
        [self.downloadInfoArray addObject:info];
    }
    
    // 设置block
    info.progressBlock = progress;
    info.completionBlock = completion;
    
    // 设置文件路径
    if (destinationPath) {
        info.file = destinationPath;
        info.filename = [destinationPath lastPathComponent];
    }
    
    // 如果已经下载完毕
    if (info.state == MJDownloadStateCompleted) {
        // 完毕
        [info notifyCompletion];
        
        // 清理资源
        [self free:url];
        return info;
    }
    
    // 创建任务
    [info setupTask:self.session];
    
    // 开始任务
    [self resume:url];
    
    return info;
}

- (MJDownloadInfo *)download:(NSString *)url progress:(MJDownloadProgressBlock)progress completion:(MJDownloadCompletionBlock)completion
{
    return [self download:url toDestinationPath:nil progress:progress completion:completion];
}

- (void)cancelAll
{
    [self.downloadInfoArray enumerateObjectsUsingBlock:^(MJDownloadInfo *info, NSUInteger idx, BOOL *stop) {
        [self cancel:info.url];
    }];
}

+ (void)cancelAll
{
    [_managers.allValues makeObjectsPerformSelector:@selector(cancelAll)];
}

- (void)suspendAll
{
    [self.downloadInfoArray enumerateObjectsUsingBlock:^(MJDownloadInfo *info, NSUInteger idx, BOOL *stop) {
        [self suspend:info.url];
    }];
}

+ (void)suspendAll
{
    [_managers.allValues makeObjectsPerformSelector:@selector(suspendAll)];
}

- (void)resumeAll
{
    [self.downloadInfoArray enumerateObjectsUsingBlock:^(MJDownloadInfo *info, NSUInteger idx, BOOL *stop) {
        [self resume:info.url];
    }];
}

+ (void)resumeAll
{
    [_managers.allValues makeObjectsPerformSelector:@selector(resumeAll)];
}

- (void)cancel:(NSString *)url
{
    if (url == nil) return;
    
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:url];
    [self.downloadingDownloadInfoArray removeObject:info];
    
    // 取消
    [info.task cancel];
    
    // 清除操作
    [self free:url];
}

- (void)suspend:(NSString *)url
{
    if (url == nil) return;
    
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:url];
    if (![self.downloadingDownloadInfoArray containsObject:info]) return;
    [self.downloadingDownloadInfoArray removeObject:info];
    // 暂停
    [info.task suspend];
    
#warning 发通知
}

- (void)resume:(NSString *)url
{
    if (url == nil) return;
    
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:url];
    // 正在下载
    if ([self.downloadingDownloadInfoArray containsObject:info]) return;
    [self.downloadingDownloadInfoArray addObject:info];
    // 继续
    [info.task resume];
    
#warning 发通知
}

- (MJDownloadInfo *)downloadInfoForURL:(NSString *)url
{
    if (url == nil) return nil;
    
    return self.downloadInfoDict[url];
}

#pragma mark - <NSURLSessionDataDelegate>
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    // 获得下载信息
    MJDownloadInfo *info = self.downloadInfoDict[dataTask.taskDescription];
    
    // 获得文件总长度
    if (!info.totalBytesExpectedToWrite) {
        info.totalBytesExpectedToWrite = [response.allHeaderFields[@"Content-Length"] integerValue] + info.totalBytesWritten;
        // 存储文件总长度
        _totalFileSizes[info.url] = @(info.totalBytesExpectedToWrite);
        [_totalFileSizes writeToFile:_totalFileSizesFile atomically:YES];
    }
    
    // 打开流
    [info.stream open];
    
    // 继续
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // 获得下载信息
    MJDownloadInfo *info = self.downloadInfoDict[dataTask.taskDescription];
    
    // 写数据
    info.bytesWritten = data.length;
    info.totalBytesWritten += data.length;
    [info.stream write:data.bytes maxLength:data.length];
    
    // 通知
    [info notifyProgress];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // 获得下载信息
    MJDownloadInfo *info = self.downloadInfoDict[task.taskDescription];
    
    // 关闭流
    [info.stream close];
    
    // 通知(如果下载完毕 或者 下载出错了)
    if (info.state == MJDownloadStateCompleted || error) {
        [info notifyCompletion];
    }
    
    // 清除
    [self free:info.url];
}
@end
/****************** MJDownloadManager End ******************/
