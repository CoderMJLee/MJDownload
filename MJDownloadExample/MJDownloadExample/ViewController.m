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

static NSString * const ID = @"minion";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableArray *urls = [NSMutableArray array];
    for (int i = 0; i<4; i++) {
        [urls addObject:[NSString stringWithFormat:@"http://120.25.226.186:32812/resources/videos/minion_%02d.mp4", i + 1]];
    }
    
    for (NSString *url in urls) {
        [[MJDownloadManager managerWithIdentifier:ID] download:url progress:^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
            NSLog(@"下载%@进度：%.2f%%",  url.lastPathComponent, 100.0 * totalBytesWritten / totalBytesExpectedToWrite);
        } completion:^(NSString *file, NSError *error) {
            NSLog(@"下载%@完毕。文件：%@ 错误：%@", url.lastPathComponent, file, error);
        }];
    }
}

- (IBAction)resume:(id)sender {
    
}

- (IBAction)suspend:(id)sender {
    
}

- (IBAction)cancel:(id)sender {
    
}

@end
