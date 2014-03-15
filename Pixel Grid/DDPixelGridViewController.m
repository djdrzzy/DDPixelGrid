//
//  DDPixelGridViewController.m
//  Pixel Grid
//
//  Created by Daniel Drzimotta on 2014-02-25.
//  Copyright (c) 2014 Daniel Drzimotta. All rights reserved.
//

/**
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "DDPixelGridViewController.h"

#import "DDPixelGrid.h"

static const NSUInteger kNumberOfCells = 30;

static const NSUInteger kPixelGridWidth = 80;
static const NSUInteger kPixelGridHeight = 80;

@interface DDPixelGridViewController ()
@property (strong, nonatomic) DDPixelGrid *pixelGrid;
@property (assign, nonatomic) BOOL keepUpdating;
@property (assign, nonatomic) CGFloat viewWidth;
@end

@implementation DDPixelGridViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.viewWidth = CGRectGetWidth(self.view.frame);
    
    self.pixelGrid = [[DDPixelGrid alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.frame), CGRectGetWidth(self.view.frame))];
    self.pixelGrid.colorSpace = [[DDPixelGridColorSpaceIce alloc] init];
    
    [self.view addSubview:self.pixelGrid];
    
    [self.pixelGrid setWidth:kPixelGridWidth height:kPixelGridHeight typesOfCells:kNumberOfCells];
    
    [self randomlyPopulate];
    
    [self.pixelGrid drawView];
}



- (IBAction)rainbowButtonPressed:(id)sender {
    self.pixelGrid.colorSpace = [[DDPixelGridColorSpaceRainbow alloc] init];
    [self randomlyPopulate];
    [self.pixelGrid drawView];
}

- (IBAction)fireButtonPressed:(id)sender {
    self.pixelGrid.colorSpace = [[DDPixelGridColorSpaceFire alloc] init];
    [self randomlyPopulate];
    [self.pixelGrid drawView];
}
- (IBAction)iceButtonPressed:(id)sender {
    self.pixelGrid.colorSpace = [[DDPixelGridColorSpaceIce alloc] init];
    [self randomlyPopulate];
    [self.pixelGrid drawView];
}
- (IBAction)emeraldButtonPressed:(id)sender {
    self.pixelGrid.colorSpace = [[DDPixelGridColorSpaceEmerald alloc] init];
    [self randomlyPopulate];
    [self.pixelGrid drawView];
}
- (IBAction)randomlyUpdateButtonPressed:(id)sender {
    self.keepUpdating = YES;
    [self randomlyPopulate];
}
- (IBAction)stopButtonPressed:(id)sender {
    self.keepUpdating = NO;
}

- (void)randomlyPopulate {
    for (int i = 0; i < kPixelGridWidth; i++) {
        for (int j = 0; j < kPixelGridHeight; j++) {
            [self.pixelGrid updateForX:i y:j newColorValue:arc4random() % 30];
        }
    }
    
    [self.pixelGrid drawView];
    
    if (self.keepUpdating) {
        [self performSelector:@selector(randomlyPopulate) withObject:nil afterDelay:0.01];
    }
}

@end
