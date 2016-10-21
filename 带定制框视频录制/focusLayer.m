//
//  focusLayer.m
//  带定制框视频录制
//
//  Created by Orangels on 16/10/18.
//  Copyright © 2016年 ls. All rights reserved.
//

#import "focusLayer.h"
#import <UIKit/UIKit.h>
@implementation focusLayer


-(void)drawInContext:(CGContextRef)ctx{
    //1.绘制图形
    //用贝塞尔曲线画圆角
    
    NSLog(@"绘制 layer");
    
    UIColor* color = [UIColor orangeColor];
//    UIColor* backgroundColor = [UIColor clearColor];
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor orangeColor].CGColor);
    CGRect rect = CGRectMake(0, 0, 100, 100);
    CGContextAddPath(ctx, [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(10, 10)].CGPath);
    
//    [color setStroke];
    
//    [backgroundColor setFill];
    
    CGContextDrawPath(ctx, kCGPathStroke);
    
//    CGContextStrokePath(ctx);
}

@end
