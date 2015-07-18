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
    
    [[MJDownloadManager sharedInstance] download:url progress:^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%f", 1.0 * totalBytesWritten / totalBytesExpectedToWrite);
    } completion:^(NSString *file, NSError *error) {
        NSLog(@"%@ %@", file, error);
    }];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[MJDownloadManager sharedInstance] cancel:url];
}

@end
