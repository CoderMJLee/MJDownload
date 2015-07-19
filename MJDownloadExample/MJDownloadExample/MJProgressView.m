//
//  MJProgressView.m
//  MJDownloadExample
//
//  Created by MJ Lee on 15/7/19.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJProgressView.h"

@implementation MJProgressView

- (void)setProgress:(CGFloat)progress
{
    _progress = progress;
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [[UIColor redColor] set];
    UIRectFill(CGRectMake(0, 0, self.progress * rect.size.width, rect.size.height));
}

@end
