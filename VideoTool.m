//
//  VideoTool.m
//  LFCamera
//
//  Created by LF on 2018/7/18.
//  Copyright © 2018年 LF. All rights reserved.
//

#import "VideoTool.h"

#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>

/*
 * https://www.jianshu.com/p/52d1867b0aa4
 * 判断视频方向,会根据视频第一帧的 CGAffineTransform 的 b / a 的反正切值，然后再算出视频偏转角度
 */
static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};

@implementation VideoTool


+ (instancetype)shareVideoTool {
    static VideoTool *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


#pragma mark 压缩视频（videoURL原视频沙盒url，compressVideoURL压缩后 沙盒路url）
- (void)compressVideWithURL:(NSURL *)videoURL
                  complated:(void (^)(NSURL *compressVideoURL))complatedBlcok {
    
    // 存在上次压缩视频 移除
    [self removeFileAtPath:[self compressVideoPath]];
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPreset1280x720];
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputURL = [NSURL fileURLWithPath:[self compressVideoPath]];
    exportSession.outputFileType = AVFileTypeMPEG4;
    // 旋转视频方向
    exportSession.videoComposition = [self getVideoComposition:asset];
    
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^ {
        int exportStatus = exportSession.status;
        switch (exportStatus) {
            case AVAssetExportSessionStatusFailed: {
                if (complatedBlcok) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        complatedBlcok(nil);
                    });
                }
                NSError *exportError = exportSession.error;
                NSLog(@"AVAssetExportSessionStatusFailed:%@", exportError);
                break;
            }
            case AVAssetExportSessionStatusCompleted: {
                if (complatedBlcok) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        complatedBlcok(exportSession.outputURL);
                    });
                }
                NSError *error;
                NSData *data = [NSData dataWithContentsOfFile:[self compressVideoPath]];
                if (error) {
                    NSLog(@"AVAssetExportSessionStatusCompleted--erro:%@", error);
                }else {
                    NSLog(@"视频压缩解码成功:%lu--->压缩后%.2fM", (unsigned long)data.length, [self dataSize:data]);
                }
                break;
            }
            default:
                break;
        }
        
    }];
    
}

#pragma mark 视频压缩后 沙盒路径输出
- (NSString *)compressVideoPath {
    
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    documents = [documents stringByAppendingString:@"/myMovie.mov"];
    return documents;
    
}
- (void)removeFileAtPath:(NSString *)filePath {
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:nil]) {
            NSLog(@"移除%@成功", filePath);
        }else {
            NSLog(@"移除%@失败", filePath);
        }
    }
    
}

#pragma mark 保存视频到相册
/**
 *  通过视频的url，将视频保存到相册
 *  @param outputFileURL 视频url
 *  @return nil
 */
- (BOOL)saveVideo:(NSURL *)outputFileURL {
    __block BOOL success = NO;
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"%s保存视频失败:%@", __FUNCTION__,error);
        } else {
            NSLog(@"%s保存视频到相册成功", __FUNCTION__);
            success = YES;
        }
    }];
    return success;
}

- (void)saveVideo:(NSURL *)videoURL
         complate:(void(^)(BOOL success))complateBlcok {
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"%s保存视频失败:%@", __FUNCTION__,error);
            if (complateBlcok) {
                complateBlcok(NO);
            }
        } else {
            NSLog(@"%s保存视频到相册成功", __FUNCTION__);
            if (complateBlcok) {
                complateBlcok(YES);
            }
        }
    }];
    
}




#pragma mark 获取视频的首帧缩略图
/**
 *  通过视频的URL，获得视频缩略图
 *  @param  videoURL 视频URL
 *  @return 首帧缩略图
 */
- (UIImage *)imageWithVideoURL:(NSURL *)videoURL
{
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:videoURL options:opts];
    // 根据asset构造一张图
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
    // 设定缩略图的方向
    // 如果不设定，可能会在视频旋转90/180/270°时，获取到的缩略图是被旋转过的，而不是正向的（自己的理解）
    generator.appliesPreferredTrackTransform = YES;
    // 设置图片的最大size(分辨率)
    generator.maximumSize = CGSizeMake(600, 450);
    NSError *error = nil;
    // 根据时间，获得第N帧的图片
    // CMTimeMake(a, b)可以理解为获得第a/b秒的frame
    CGImageRef img = [generator copyCGImageAtTime:CMTimeMake(0, 10000) actualTime:NULL error:&error];
    UIImage *image = [UIImage imageWithCGImage: img];
    return image;
}



#pragma mark - <-----------V判断视频方向V----------->
+ (VideoOrientation)videoOrientationWithAsset:(AVAsset *)asset {
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] == 0) {
        return VideoOrientationNotFound;
    }
    
    AVAssetTrack* videoTrack    = [videoTracks objectAtIndex:0];
    CGAffineTransform txf       = [videoTrack preferredTransform];
    CGFloat videoAngleInDegree  = RadiansToDegrees(atan2(txf.b, txf.a));
    
    VideoOrientation orientation = 0;
    switch ((int)videoAngleInDegree) {
        case 0:
            orientation = VideoOrientationRight;
            break;
        case 90:
            orientation = VideoOrientationUp;
            break;
        case 180:
            orientation = VideoOrientationLeft;
            break;
        case -90:
            orientation     = VideoOrientationDown;
            break;
        default:
            orientation = VideoOrientationNotFound;
            break;
    }
    
    return orientation;
    
}
#pragma mark <最后根据视频的角度旋转视频>
+ (void)videoRotateWithAsset:(AVAsset *)asset {

    VideoOrientation  videoOrientation = [self videoOrientationWithAsset:asset];

    CGAffineTransform t1 = CGAffineTransformIdentity;
    CGAffineTransform t2 = CGAffineTransformIdentity;

    NSLog(@" --- 视频转向 -- %ld",(long)videoOrientation);
    switch (videoOrientation) {
        case VideoOrientationUp:
            break;
        case VideoOrientationDown:

            break;
        case  VideoOrientationRight:

            break;
        case VideoOrientationLeft:
            break;
        default:
            NSLog(@"【该视频未发现设置支持的转向】");
            break;
    }
    
    CGAffineTransform finalTransform = t2;
    //[transformer setTransform:finalTransform atTime:kCMTimeZero];

}
#pragma mark - <------------^暂未用到^---------->


#pragma mark - private
/**
 视频旋转的角度

 @param url 视频url
 @return 视频旋转的角度
 */
+ (NSUInteger)degressFromVideoFileWithURL:(NSURL *)url {
    NSUInteger degress = 0;
    
    AVAsset *asset = [AVAsset assetWithURL:url];
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        
        if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
            // Portrait
            degress = 90;
        }else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
            // PortraitUpsideDown
            degress = 270;
        }else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
            // LandscapeRight
            degress = 0;
        }else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
            // LandscapeLeft
            degress = 180;
        }
    }
    return degress;
}

/**
 修正视频的旋转方向

 @param asset 视频asset
 @return AVMutableVideoComposition
 */
- (AVMutableVideoComposition *)getVideoComposition:(AVAsset *)asset {
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    CGSize videoSize = videoTrack.naturalSize;
    
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if([tracks count] > 0) {
        AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
        CGAffineTransform t = videoTrack.preferredTransform;
        if((t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) ||
           (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0)){
            videoSize = CGSizeMake(videoSize.height, videoSize.width);
        }
    }
    composition.naturalSize    = videoSize;
    videoComposition.renderSize = videoSize;
    videoComposition.frameDuration = CMTimeMakeWithSeconds( 1 / videoTrack.nominalFrameRate, 600);
    
    AVMutableCompositionTrack *compositionVideoTrack;
    compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    AVMutableVideoCompositionLayerInstruction *layerInst;
    layerInst = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    [layerInst setTransform:videoTrack.preferredTransform atTime:kCMTimeZero];
    AVMutableVideoCompositionInstruction *inst = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    inst.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    inst.layerInstructions = [NSArray arrayWithObject:layerInst];
    videoComposition.instructions = [NSArray arrayWithObject:inst];
    return videoComposition;
}




#pragma mark - 计算data数据大小(单位：M)
// 计算data数据大小(单位：M)
- (CGFloat)dataSize:(NSData *)data {
    CGFloat size = data.length / (1024.0 * 1024.0);
    return size;
}








@end
