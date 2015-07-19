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
@property (strong, nonatomic) NSMutableArray *urls;
@property (strong, nonatomic) NSMutableArray *completionFiles;
@end

@implementation ViewController

static NSString * const ID = @"minion";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.urls = [NSMutableArray array];
    for (int i = 0; i<5; i++) {
        [self.urls addObject:[NSString stringWithFormat:@"http://localhost:8080/MJServer/resources/videos/minion_%02d.mp4", i + 1]];
    }
    
    self.completionFiles = [NSMutableArray array];
    for (NSString *url in self.urls) {
        [[MJDownloadManager managerWithIdentifier:ID] download:url progress:^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
            NSLog(@"下载%@进度：%.2f%%",  url.lastPathComponent, 100.0 * totalBytesWritten / totalBytesExpectedToWrite);
        } completion:^(NSString *file, NSError *error) {
            NSLog(@"下载%@完毕。文件：%@ 错误：%@", url.lastPathComponent, file, error);
            [self.completionFiles addObject:file];
        }];
    }
}

- (IBAction)resume:(id)sender {
    
}

- (IBAction)suspend:(id)sender {
    
}

- (IBAction)cancel:(id)sender {
    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (NSString *file in self.completionFiles) {
        [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    }
}

@end
