//
//  DDPixelGrid.m
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

#import "DDPixelGrid.h"

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

typedef struct {
    GLshort x;
    GLshort y;
} Vertex2D;

typedef struct {
    GLubyte r;
    GLubyte g;
    GLubyte b;
    GLubyte a;
} ColorRGBA;

@interface DDPixelGrid ()
@property (strong, nonatomic) EAGLContext *context;
@end

@implementation DDPixelGrid {
    GLint _backingWidth;
    GLint _backingHeight;
    GLuint _viewRenderbuffer;
    GLuint _viewFramebuffer;
    GLuint _depthRenderbuffer;
    
    int _arrayWidth;
    int _arrayHeight;
    int _typesOfCells;
    
    double _cellWidth;
    double _cellHeight;
    
    
    NSUInteger _numberOfRows;
    NSUInteger _numberOfRows_minus_one;
    NSUInteger _numberOfColumns;
    
    NSUInteger _vertices_numberOfRows;
    NSUInteger _vertices_numberOfRows_doubled;
    NSUInteger _vertices_numberOfColumns;
    NSUInteger _vertices_numberOfColumns_doubled_plus_2;
    NSUInteger _numberOfVerticesToDraw;
    
    Vertex2D *_normalizedVertices;
    Vertex2D *_triangleStripArray;
    ColorRGBA *_vertexColors;
    
    ColorRGBA *_moddedColorSpace;
}


+ (Class) layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],
                                        kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGB565,
                                        kEAGLDrawablePropertyColorFormat, nil];
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        [EAGLContext setCurrentContext:_context];
        
        if (!_context || ![EAGLContext setCurrentContext:_context]) {
            return nil;
        }
    }
    
    self.colorSpace = [[DDPixelGridColorSpaceRainbow alloc] init];
    
    return self;
}

- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],
                                        kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGB565,
                                        kEAGLDrawablePropertyColorFormat, nil];
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        [EAGLContext setCurrentContext:_context];
        
        if (!_context || ![EAGLContext setCurrentContext:_context]) {
            return nil;
        }
        
    }
    
    self.colorSpace = [[DDPixelGridColorSpaceRainbow alloc] init];
    
    return self;
}

- (void)dealloc {
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    free(_normalizedVertices);
    free(_triangleStripArray);
    free(_vertexColors);
}


- (void)layoutSubviews {
    [EAGLContext setCurrentContext:_context];
    [self destroyFramebuffer];
    [self createFramebuffer];
    [self drawView];
}

- (BOOL)createFramebuffer {
    
    glGenFramebuffersOES(1, &_viewFramebuffer);
    glGenRenderbuffersOES(1, &_viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, _viewRenderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, _viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &_backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &_backingHeight);
    
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        return NO;
    }
    
    return YES;
}

- (void)destroyFramebuffer {
    
    glDeleteFramebuffersOES(1, &_viewFramebuffer);
    _viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &_viewRenderbuffer);
    _viewRenderbuffer = 0;
    
    if(_depthRenderbuffer) {
        glDeleteRenderbuffersOES(1, &_depthRenderbuffer);
        _depthRenderbuffer = 0;
    }
}


// This method is with help from:
// http://dan.lecocq.us/wordpress/2009/12/25/triangle-strip-for-grids-a-construction/
-(void) setWidth:(int)newArrayWidth
          height:(int)newArrayHeight
    typesOfCells:(int)newTypesOfCells {
    
    if (newArrayWidth != _arrayWidth
        || newArrayHeight != _arrayHeight) {
        _arrayWidth = newArrayWidth;
        _arrayHeight = newArrayHeight;
        _typesOfCells = newTypesOfCells;
        
        _cellWidth = [self bounds].size.width/(double)_arrayWidth;
        _cellHeight = [self bounds].size.height/(double)_arrayHeight;
        
        _numberOfRows = newArrayWidth;
        _numberOfRows_minus_one = _numberOfRows - 1;
        _numberOfColumns = newArrayHeight;
        
        _vertices_numberOfRows = _numberOfRows + 1;
        _vertices_numberOfRows_doubled = _vertices_numberOfRows * 2;
        _vertices_numberOfColumns = _numberOfColumns + 1;
        _vertices_numberOfColumns_doubled_plus_2 = (_vertices_numberOfColumns * 2) + 2;
        
        // Our 'logical' vertices. Not the ones we use for our triangle strip.
        if (_normalizedVertices) {
            free(_normalizedVertices);
        }
        _normalizedVertices = malloc(sizeof(Vertex2D) * _vertices_numberOfColumns * _vertices_numberOfRows);
        
        for (int i = 0; i < _vertices_numberOfColumns; i++) {
            for (int j = 0; j < _vertices_numberOfRows; j++) {
                
                Vertex2D newVertex = (Vertex2D){
                    .x = (GLfloat)(j * _cellWidth),
                    .y = (GLfloat)(i * _cellHeight),
                };
                
                unsigned long normalizedVerticesIndex = i * _vertices_numberOfRows + j;
                _normalizedVertices[normalizedVerticesIndex] = newVertex;
            }
        }
        
        
        if (_triangleStripArray) {
            free(_triangleStripArray);
        }
        
        _numberOfVerticesToDraw = (_vertices_numberOfColumns * _vertices_numberOfRows * 2) - (_vertices_numberOfRows * 2);
        
        
        _triangleStripArray = malloc(sizeof(Vertex2D) * _numberOfVerticesToDraw);
        
        int vertSideCounter = 0;
        int currentIndex = 0;
        int vertSideModifier = -1;
        
        // If yes we add (vertside), if no we add (vertside + (vertSideModifier))
        BOOL vertSideModifierOperationAddition = YES;
        int lastIndex = 0;
        
        for (int i = 0; i < _numberOfVerticesToDraw; i++) {
            
            _triangleStripArray[i] = _normalizedVertices[currentIndex];
            
            lastIndex = currentIndex;
            if (vertSideModifierOperationAddition) {
                // Num rows? We only walked through it on paper when the sides were even
                currentIndex += _vertices_numberOfRows;
            } else {
                currentIndex -= (_vertices_numberOfRows + (vertSideModifier));
            }
            vertSideModifierOperationAddition = !vertSideModifierOperationAddition;
            vertSideCounter++;
            
            // We now have our row end case where we loop around...
            // We detect if our vertSideCounter is equal to numberOfColumns * 2 and set
            // up the next row iteration
            if (vertSideCounter >= _vertices_numberOfRows * 2) {
                vertSideCounter = 0;
                vertSideModifier *= -1;
                currentIndex = lastIndex;
            }
        }
        
        
        if (_vertexColors) {
            free(_vertexColors);
        }
        
        _vertexColors = malloc(sizeof(ColorRGBA) * _numberOfVerticesToDraw);
        for (int i = 0; i < _numberOfVerticesToDraw; i++) {
            _vertexColors[i] = (ColorRGBA) {
                .r = 0.0f,
                .g = 0.0f,
                .b = 0.0f,
                .a = 0.0f,
            };
        }
        
    }
    
    _arrayWidth = newArrayWidth;
    _arrayHeight = newArrayHeight;
    _typesOfCells = newTypesOfCells;
    
    _cellWidth = [self bounds].size.width/(double)_arrayWidth;
    _cellHeight = [self bounds].size.height/(double)_arrayHeight;
}

-(void) updateForX:(int)column y:(int)row newColorValue:(int)currentValue {
    int colorSpacePosition = ((double)currentValue/(double)_typesOfCells) * 30.0;
    
    ColorRGBA color3D = _moddedColorSpace[colorSpacePosition];
    
    
    unsigned long currentColumn = column;
    if (row & 1) {
        // We do this as on odd rows our triangle strips go backwards
        currentColumn = _numberOfRows_minus_one - column;
        
    }
    unsigned long firstIndex = (_vertices_numberOfRows_doubled * row) + (currentColumn << 1) + 2;
    
    _vertexColors[firstIndex] = _vertexColors[firstIndex + 1] = color3D;
}

- (void)drawView {
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, _viewFramebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    
    //Loads our identity matrix
    glLoadIdentity();
    
    glOrthof(0.0f, [self bounds].size.width, [self bounds].size.height, 0.0f, -1.0f, 1.0f);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    
    glDisable(GL_DEPTH_TEST);
    
    glShadeModel(GL_FLAT);
    
    glVertexPointer(2, GL_SHORT, 0, _triangleStripArray);
    glColorPointer(4, GL_UNSIGNED_BYTE, 0, _vertexColors);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, (GLsizei)_numberOfVerticesToDraw);
    
    //Draw everything in all the pipelines to the screen.
    glFlush();
    
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, _viewRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (void)setColorSpace:(DDPixelGridColorSpace *)colorSpace {
    _colorSpace = colorSpace;
    if (_moddedColorSpace) {
        free(_moddedColorSpace);
    }
    
    _moddedColorSpace = malloc(sizeof(ColorRGBA) * 30);
    
    for (int i = 0; i < 30; i++) {
        _moddedColorSpace[i] = (ColorRGBA) {
            .r = _colorSpace->colorSpace[i][0],
            .g = _colorSpace->colorSpace[i][1],
            .b = _colorSpace->colorSpace[i][2],
            .a = 255,
        };
    }
}


@end



@implementation DDPixelGridColorSpace
@end

@implementation DDPixelGridColorSpaceRainbow
-(id) init {
    self = [super init];
    if (self) {
        colorSpace[0][0] = 255;
        colorSpace[0][1] = 0;
        colorSpace[0][2] = 0;
        
        colorSpace[1][0] = 255;
        colorSpace[1][1] = 0.2 * 255;
        colorSpace[1][2] = 0;
        
        colorSpace[2][0] = 255;
        colorSpace[2][1] = 0.4 * 255;
        colorSpace[2][2] = 0;
        
        colorSpace[3][0] = 255;
        colorSpace[3][1] = 0.6 * 255;
        colorSpace[3][2] = 0;
        
        colorSpace[4][0] = 255;
        colorSpace[4][1] = 0.8 * 255;
        colorSpace[4][2] = 0;
        
        colorSpace[5][0] = 255;
        colorSpace[5][1] = 255;
        colorSpace[5][2] = 0;
        
        colorSpace[6][0] = 0.8 * 255;
        colorSpace[6][1] = 255;
        colorSpace[6][2] = 0;
        
        colorSpace[7][0] = 0.6 * 255;
        colorSpace[7][1] = 255;
        colorSpace[7][2] = 0;
        
        colorSpace[8][0] = 0.4 * 255;
        colorSpace[8][1] = 255;
        colorSpace[8][2] = 0;
        
        colorSpace[9][0] = 0.2 * 255;
        colorSpace[9][1] = 255;
        colorSpace[9][2] = 0;
        
        colorSpace[10][0] = 0;
        colorSpace[10][1] = 255;
        colorSpace[10][2] = 0;
        
        colorSpace[11][0] = 0;
        colorSpace[11][1] = 255;
        colorSpace[11][2] = 0.2 * 255;
        
        colorSpace[12][0] = 0;
        colorSpace[12][1] = 255;
        colorSpace[12][2] = 0.4 * 255;
        
        colorSpace[13][0] = 0;
        colorSpace[13][1] = 255;
        colorSpace[13][2] = 0.6 * 255;
        
        colorSpace[14][0] = 0;
        colorSpace[14][1] = 255;
        colorSpace[14][2] = 0.8 * 255;
        
        colorSpace[15][0] = 0;
        colorSpace[15][1] = 255;
        colorSpace[15][2] = 255;
        
        colorSpace[16][0] = 0;
        colorSpace[16][1] = 0.8 * 255;
        colorSpace[16][2] = 255;
        
        colorSpace[17][0] = 0;
        colorSpace[17][1] = 0.6 * 255;
        colorSpace[17][2] = 255;
        
        colorSpace[18][0] = 0;
        colorSpace[18][1] = 0.4 * 255;
        colorSpace[18][2] = 255;
        
        colorSpace[19][0] = 0;
        colorSpace[19][1] = 0.2 * 255;
        colorSpace[19][2] = 255;
        
        colorSpace[20][0] = 0;
        colorSpace[20][1] = 0;
        colorSpace[20][2] = 255;
        
        colorSpace[21][0] = 0.2 * 255;
        colorSpace[21][1] = 0;
        colorSpace[21][2] = 255;
        
        colorSpace[22][0] = 0.4 * 255;
        colorSpace[22][1] = 0;
        colorSpace[22][2] = 255;
        
        colorSpace[23][0] = 0.6 * 255;
        colorSpace[23][1] = 0;
        colorSpace[23][2] = 255;
        
        colorSpace[24][0] = 0.8 * 255;
        colorSpace[24][1] = 0;
        colorSpace[24][2] = 255;
        
        colorSpace[25][0] = 255;
        colorSpace[25][1] = 0;
        colorSpace[25][2] = 255;
        
        colorSpace[26][0] = 255;
        colorSpace[26][1] = 0;
        colorSpace[26][2] = 0.8 * 255;
        
        colorSpace[27][0] = 255;
        colorSpace[27][1] = 0;
        colorSpace[27][2] = 0.6 * 255;
        
        colorSpace[28][0] = 255;
        colorSpace[28][1] = 0;
        colorSpace[28][2] = 0.4 * 255;
        
        colorSpace[29][0] = 255;
        colorSpace[29][1] = 0;
        colorSpace[29][2] = 0.2 * 255;
    }
    return self;
}
@end

@implementation DDPixelGridColorSpaceFire
-(id) init {
    self = [super init];
    if (self) {
        for(int i = 0; i < 30; i++) {
            colorSpace[i][0] = 255;
            colorSpace[i][1] =(float)i / 30.0 * 255.0;
            colorSpace[i][2] = 0;			
        }
    }
    return self;
}
@end


@implementation DDPixelGridColorSpaceIce
-(id) init {
    self = [super init];
    if (self) {
        for(int i = 0; i < 30; i++) {
            colorSpace[i][0] = 0;
            colorSpace[i][1] = (float)i / 30.0 * 255.0;
            colorSpace[i][2] = 255;			
        }
    }
    return self;
}
@end

@implementation DDPixelGridColorSpaceEmerald
-(id) init {
    self = [super init];
    if (self) {
        for(GLubyte i = 0; i < 30; i++) {
            colorSpace[i][0] = 0;
            colorSpace[i][1] = (float)i / 30.0 * 255.0;
            colorSpace[i][2] = 102;		
        }
    }
    return self;
}
@end