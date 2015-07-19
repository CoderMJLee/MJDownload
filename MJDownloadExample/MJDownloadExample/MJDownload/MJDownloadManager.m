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
        NSString *pathExtension = self.url.pathExtension;
        if (pathExtension.length) {
            _filename = [NSString stringWithFormat:@"%@.%@", self.url.MD5, pathExtension];
        } else {
            _filename = self.url.MD5;
        }
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
    if (self.task.error) return MJDownloadStateNone;
    
    return _state;
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
    
    // 发通知
    [self postProgressDidChange];
}

/**
 *  通知下载完毕
 */
- (void)notifyCompletion
{
    !self.completionBlock ? : self.completionBlock(self.file, self.error);
    
    // 发通知
    [self postStateDidChange];
}

/**
 *  通知：下载状态发生改变
 */
- (void)postStateDidChange
{
    [MJDownloadNoteCenter postNotificationName:MJDownloadStateDidChangeNotification object:self userInfo:@{
                                                                                                           MJDownloadInfoKey : self
                                                                                                           }];
}

/**
 *  通知：下载进度发生改变
 */
- (void)postProgressDidChange
{
    [MJDownloadNoteCenter postNotificationName:MJDownloadProgressDidChangeNotification object:self userInfo:@{
                                                                                                           MJDownloadInfoKey : self
                                                                                                           }];
}

#pragma mark - 状态控制
/**
 *  取消
 */
- (void)cancel
{
    if (self.state == MJDownloadStateCompleted || self.state == MJDownloadStateNone) return;
    
    [self.task cancel];
    self.state = MJDownloadStateNone;
    
    // 发通知
    [self postStateDidChange];
}

/**
 *  恢复
 */
- (void)resume
{
    if (self.state == MJDownloadStateCompleted || self.state == MJDownloadStateResumed) return;
    
    [self.task resume];
    self.state = MJDownloadStateResumed;
    
    // 发通知
    [self postStateDidChange];
}

/**
 *  暂停
 */
- (void)suspend
{
    if (self.state == MJDownloadStateCompleted || self.state == MJDownloadStateSuspened) return;
    
    [self.task suspend];
    self.state = MJDownloadStateSuspened;
    
    // 发通知
    [self postStateDidChange];
}

#pragma mark - 代理方法处理
- (void)didReceiveResponse:(NSHTTPURLResponse *)response
{
    // 获得文件总长度
    if (!self.totalBytesExpectedToWrite) {
        self.totalBytesExpectedToWrite = [response.allHeaderFields[@"Content-Length"] integerValue] + self.totalBytesWritten;
        // 存储文件总长度
        _totalFileSizes[self.url] = @(self.totalBytesExpectedToWrite);
        [_totalFileSizes writeToFile:_totalFileSizesFile atomically:YES];
    }
    
    // 打开流
    [self.stream open];
    
    // 清空错误
    self.error = nil;
}

- (void)didReceiveData:(NSData *)data
{
    // 写数据
    self.bytesWritten = data.length;
    self.totalBytesWritten += data.length;
    [self.stream write:data.bytes maxLength:data.length];
    
    // 通知
    [self notifyProgress];
}

- (void)didCompleteWithError:(NSError *)error
{
    // 关闭流
    [self.stream close];
    self.stream = nil;
    self.task = nil;
    
    // 错误
    self.error = error;
    
    // 通知(如果下载完毕 或者 下载出错了)
    if (self.state == MJDownloadStateCompleted || error) {
        // 设置状态
        self.state = error ? MJDownloadStateNone : MJDownloadStateCompleted;
        
        [self notifyCompletion];
    }
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
/** 锁 */
static NSRecursiveLock *_lock;

+ (void)initialize
{
    _totalFileSizesFile = [[NSString stringWithFormat:@"%@/%@", MJDownloadRootDir, @"MJDownloadFileSizes.plist".MD5] prependCaches];
    
    _totalFileSizes = [NSMutableDictionary dictionaryWithContentsOfFile:_totalFileSizesFile];
    if (_totalFileSizes == nil) {
        _totalFileSizes = [NSMutableDictionary dictionary];
    }
    
    _managers = [NSMutableDictionary dictionary];
    
    _lock = [[NSRecursiveLock alloc] init];
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

#pragma mark - 公共方法
- (MJDownloadInfo *)download:(NSString *)url toDestinationPath:(NSString *)destinationPath progress:(MJDownloadProgressBlock)progress completion:(MJDownloadCompletionBlock)completion
{
    if (url == nil) return nil;
    
    // 下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:url];
    
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
        return info;
    } else if (info.state == MJDownloadStateResumed) {
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

- (MJDownloadInfo *)download:(NSString *)url completion:(MJDownloadCompletionBlock)completion
{
    return [self download:url toDestinationPath:nil progress:nil completion:completion];
}

- (MJDownloadInfo *)download:(NSString *)url
{
    return [self download:url toDestinationPath:nil progress:nil completion:nil];
}

#pragma mark - 文件操作
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
    [info cancel];
}

- (void)suspend:(NSString *)url
{
    if (url == nil) return;
    
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:url];
    if (![self.downloadingDownloadInfoArray containsObject:info]) return;
    [self.downloadingDownloadInfoArray removeObject:info];
    // 暂停
    [info suspend];
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
    [info resume];
}

#pragma mark - 获得下载信息
- (MJDownloadInfo *)downloadInfoForURL:(NSString *)url
{
    if (url == nil) return nil;
    
    MJDownloadInfo *info = self.downloadInfoDict[url];
    if (info == nil) {
        info = [[MJDownloadInfo alloc] init];
        info.url = url; // 设置url
        self.downloadInfoDict[url] = info;
        [self.downloadInfoArray addObject:info];
    }
    return info;
}

#pragma mark - <NSURLSessionDataDelegate>
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:dataTask.taskDescription];
    
    // 处理响应
    [info didReceiveResponse:response];
    
    // 继续
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:dataTask.taskDescription];
    
    // 处理数据
    [info didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // 获得下载信息
    MJDownloadInfo *info = [self downloadInfoForURL:task.taskDescription];
    
    // 处理结束
    [info didCompleteWithError:error];
    
    // 清除
    [self.downloadingDownloadInfoArray removeObject:info];
}
@end
/****************** MJDownloadManager End ******************/
