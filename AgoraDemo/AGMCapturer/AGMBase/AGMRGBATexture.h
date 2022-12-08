//
//  AGMRGBATexture.h
//  AGMBase
//
//  Created by LSQ on 2020/10/11.
//  Copyright © 2020 Agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "AGMVideoFrame.h"
#import "AGMOpenGLDefines.h"
#import "AGMEAGLContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface AGMRGBATexture : NSObject <AGMVideoFrame>

@property (nonatomic, readonly) GLuint rgbaTexture;
@property (nonatomic, readonly) CVPixelBufferRef pixelBuffer;

- (BOOL)uploadPixelBufferToTextures:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
