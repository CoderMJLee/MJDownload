//
//  ViewController.m
//  MJDownloadExample
//
//  Created by MJ Lee on 15/7/16.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJDownloadManager.h"
#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

static NSString * const url = @"http://120.25.226.186:32812/resources/videos/minion_05.mp4";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[MJDownloadManager sharedInstance] download:url progress:^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
        NSLog(@"下载进度：%f", 1.0 * totalBytesWritten / totalBytesExpectedToWrite);
    } completion:^(NSString *file, NSError *error) {
        NSLog(@"下载完毕。文件：%@ 错误：%@", file, error);
    }];
}

- (IBAction)resume:(id)sender {
    [[MJDownloadManager sharedInstance] resume:url];
}

- (IBAction)suspend:(id)sender {
    [[MJDownloadManager sharedInstance] suspend:url];
}

- (IBAction)cancel:(id)sender {
    [[MJDownloadManager sharedInstance] cancel:url];
}


@end
