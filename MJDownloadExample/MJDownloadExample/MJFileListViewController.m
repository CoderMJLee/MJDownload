//
//  MJFileListViewController.m
//  MJDownloadExample
//
//  Created by MJ Lee on 15/7/19.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJFileListViewController.h"
#import "MJFileCell.h"
#import "MJDownload.h"

@interface MJFileListViewController ()
@property (strong, nonatomic) NSMutableArray *urls;
@end

@implementation MJFileListViewController
- (IBAction)suspendAll:(id)sender {
    [[MJDownloadManager defaultManager] suspendAll];
}

- (IBAction)resumeAll:(id)sender {
    [[MJDownloadManager defaultManager] resumeAll];
}

- (NSMutableArray *)urls
{
    if (!_urls) {
        self.urls = [NSMutableArray array];
        for (int i = 1; i<=10; i++) {
            [self.urls addObject:[NSString stringWithFormat:@"http://120.25.226.186:32812/resources/videos/minion_%02d.mp4", i]];
//            [self.urls addObject:[NSString stringWithFormat:@"http://localhost:8080/MJServer/resources/big_videos/%02d.mp4", i]];
        }
    }
    return _urls;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [MJDownloadManager defaultManager].maxDownloadingCount = 1;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.urls.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *ID = @"file";
    MJFileCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    cell.url = self.urls[indexPath.row];
    return cell;
}

@end
