//
//  DDPixelGrid.h
//  Pixel Grid
//
//  Created by Daniel Drzimotta on 2014-02-25.
//  Copyright (c) 2014 Daniel Drzimotta. All rights reserved.
//

#import <UIKit/UIKit.h>

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

@interface DDPixelGridColorSpace : NSObject {
@public GLubyte colorSpace[30][3];
}
@end

@interface DDPixelGridColorSpaceRainbow : DDPixelGridColorSpace
@end

@interface DDPixelGridColorSpaceFire : DDPixelGridColorSpace
@end

@interface DDPixelGridColorSpaceIce : DDPixelGridColorSpace
@end

@interface DDPixelGridColorSpaceEmerald : DDPixelGridColorSpace
@end

@interface DDPixelGrid : UIView

@property (strong, nonatomic) DDPixelGridColorSpace *colorSpace;

// This is used to draw from. You can set this and it will draw using the
// proper color space. If you have something new to draw you should call this
// first.
- (void)setWidth:(int)arrayWidth height:(int)arrayHeight typesOfCells:(int)typesOfCells;

// This allows you to set a 'pixel' with the given value in the color space.
// Will not actually draw anything. You must call 'drawView' first.
- (void)updateForX:(int)column y:(int)row newColorValue:(int)value;

// Call this whenever you want the view to redraw...
- (void)drawView;

@end
