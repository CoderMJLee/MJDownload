//
//  MJFileCell.m
//  MJDownloadExample
//
//  Created by MJ Lee on 15/7/19.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJFileCell.h"
#import "MJDownload.h"
#import "MJProgressView.h"
#import <MediaPlayer/MediaPlayer.h>

@interface MJFileCell()
@property (weak, nonatomic) IBOutlet MJProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *openButton;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton;
@end

@implementation MJFileCell

- (void)setUrl:(NSString *)url
{
    _url = [url copy];
    
    // 设置文字
    self.textLabel.text = [url lastPathComponent];
    
    // 控制状态
    MJDownloadInfo *info = [[MJDownloadManager defaultManager] downloadInfoForURL:url];
    
    if (info.state == MJDownloadStateCompleted) {
        self.openButton.hidden = NO;
        self.downloadButton.hidden = YES;
        self.progressView.hidden = YES;
    } else if (info.state == MJDownloadStateWillResume) {
        self.openButton.hidden = YES;
        self.downloadButton.hidden = NO;
        self.progressView.hidden = NO;
        
        [self.downloadButton setBackgroundImage:[UIImage imageNamed:@"clock"] forState:UIControlStateNormal];
    } else {
        self.openButton.hidden = YES;
        self.downloadButton.hidden = NO;
        
        if (info.state == MJDownloadStateNone ) {
            self.progressView.hidden = YES;
        } else {
            self.progressView.hidden = NO;
            
            if (info.totalBytesExpectedToWrite) {
                self.progressView.progress = 1.0 * info.totalBytesWritten / info.totalBytesExpectedToWrite;
            } else {
                self.progressView.progress = 0.0;
            }
        }
        
        if (info.state == MJDownloadStateResumed) {
            [self.downloadButton setBackgroundImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        } else {
            [self.downloadButton setBackgroundImage:[UIImage imageNamed:@"download"] forState:UIControlStateNormal];
        }
    }
}

- (IBAction)download:(UIButton *)sender {
    MJDownloadInfo *info = [[MJDownloadManager defaultManager] downloadInfoForURL:self.url];
    
    if (info.state == MJDownloadStateResumed || info.state == MJDownloadStateWillResume) {
        [[MJDownloadManager defaultManager] suspend:info.url];
    } else {
        [[MJDownloadManager defaultManager] download:self.url progress:^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.url = self.url;
            });
        } state:^(MJDownloadState state, NSString *file, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.url = self.url;
            });
        }];
    }
}

- (IBAction)open:(UIButton *)sender {
    MJDownloadInfo *info = [[MJDownloadManager defaultManager] downloadInfoForURL:self.url];
    
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    MPMoviePlayerViewController *mpc = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:info.file]];
    [vc presentViewController:mpc animated:YES completion:nil];
}

@end
