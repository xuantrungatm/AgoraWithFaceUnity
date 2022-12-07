//
//  CapturerManager.h
//  BeautifyExample
//
//  Created by LSQ on 2020/8/3.
//  Copyright © 2020 Agora. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AgoraRtcKit/AgoraRtcEngineKit.h>
#import <AGMCapturer/AGMCapturer.h>
#import <AGMBase/AGMBase.h>
#import "CapturerManagerDelegate.h"
#import <AGMRenderer/AGMRenderer.h>

NS_ASSUME_NONNULL_BEGIN

@interface CapturerManager : NSObject <AgoraVideoSourceProtocol, AGMVideoCameraDelegate>

- (instancetype)initWithVideoConfig:(AGMCapturerVideoConfig *)config delegate:(id <CapturerManagerDelegate>)delegate;
- (void)startCapture;
- (void)stopCapture;
- (void)switchCamera;
- (void)setExposurePoint:(CGPoint)point inPreviewFrame:(CGRect)frame;
- (void)setExposurePoint:(CGPoint)point;
- (void)setFocusPoint:(CGPoint)point;
- (void)setISOValue:(float)value;
/** If you want to set video orientation, you must set autoRotateBuffers to NO. */
- (void)setCaptureVideoOrientation:(AVCaptureVideoOrientation)orientation;
/** If you want to set video mirrored, you must set videoMirrored to NO. */
- (void)setVideoMirrored:(BOOL)mirror;

@property (nonatomic, strong) AGMEAGLVideoView *videoView;

@end

NS_ASSUME_NONNULL_END
