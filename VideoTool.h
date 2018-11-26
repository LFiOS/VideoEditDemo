//
//  VideoTool.h
//  LFCamera
//
//  Created by LF on 2018/7/18.
//  Copyright © 2018年 LF. All rights reserved.
//
//  iOS开发中音视频的获取、压缩上传：https://www.jianshu.com/p/f136c6d991ca

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


typedef enum: NSInteger {
    VideoOrientationUp = 1,               //Device starts recording in Portrait
    VideoOrientationDown,             //Device starts recording in Portrait upside down
    VideoOrientationLeft,             //Device Landscape Left  (home button on the left side)
    VideoOrientationRight,            //Device Landscape Right (home button on the Right side)
    VideoOrientationNotFound = 99     //An Error occurred or AVAsset doesn't contains video track
} VideoOrientation;


@class AVAsset;
@interface VideoTool : NSObject

/**
 *  单列工具类
 */
+ (instancetype)shareVideoTool;

/**
 *  通过视频的URL，压缩视频
 *  @param  videoURL        原视频沙盒url
 *  @param  complatedBlcok  压缩后     沙盒路径输出compressVideoURL
 */
- (void)compressVideWithURL:(NSURL *)videoURL
                  complated:(void (^)(NSURL *compressVideoURL))complatedBlcok;
/**
 *  压缩完视频后的路径
 *  @return 压缩完视频后的路径
 */
- (NSString *)compressVideoPath;

/**
 *  通过视频的url，将视频保存到相册
 *  @param outputFileURL 视频url
 *  @param complateBlock 视频保存是否成功
 */
//- (BOOL)saveVideo:(NSURL *)outputFileURL;
- (void)saveVideo:(NSURL *)videoURL
         complate:(void(^)(BOOL success))complateBlcok;


/**
 *  通过视频的URL，获得视频缩略图
 *  @param  videoURL 视频URL
 *  @return 首帧缩略图
 */
- (UIImage *)imageWithVideoURL:(NSURL *)videoURL;



/**
 判断视频方向

 @param asset 视频asset
 @return 视频方向
 */
+ (VideoOrientation)videoOrientationWithAsset:(AVAsset *)asset;



/**
 *  计算data数据大小(单位：M)
 */
- (CGFloat)dataSize:(NSData *)data;





@end
