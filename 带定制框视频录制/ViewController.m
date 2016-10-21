//
//  ViewController.m
//  带定制框视频录制
//
//  Created by Orangels on 16/10/17.
//  Copyright © 2016年 ls. All rights reserved.
//
/*
 步骤:
 创建AVCaptureSession对象。
 使用AVCaptureDevice的静态方法获得需要使用的设备，例如拍照和录像就需要获得摄像头设备，录音就要获得麦克风设备。
 利用输入设备AVCaptureDevice初始化AVCaptureDeviceInput对象。
 初始化输出数据管理对象，如果要拍照就初始化AVCaptureStillImageOutput对象；如果拍摄视频就初始化AVCaptureMovieFileOutput对象。
 将数据输入对象AVCaptureDeviceInput、数据输出对象AVCaptureOutput添加到媒体会话管理对象AVCaptureSession中。
 创建视频预览图层AVCaptureVideoPreviewLayer并指定媒体会话，添加图层到显示容器中，调用AVCaptureSession的startRuning方法开始捕获。
 将捕获的音频或视频数据输出到指定文件。
 */

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
//iOS8 之前管理相册的 framework
#import <AssetsLibrary/AssetsLibrary.h>
//iOS8 之后管理相册的 framework
#import <Photos/Photos.h>

#import "focusLayer.h"
typedef void(^propertyChangeBlock)(AVCaptureDevice* device);

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, strong) AVCaptureSession           * captureSession;//负责输入和输出设置之间的数据传递
@property (nonatomic, strong) AVCaptureDeviceInput       * captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (nonatomic, strong) AVCaptureStillImageOutput  * captureStillImageOutput;//照片输出流
@property (nonatomic, strong) AVCaptureVideoPreviewLayer * captureVideoPreviewLayer;//相机预览图层
@property (weak, nonatomic  ) IBOutlet UIView            * viewContainer;
@property (weak, nonatomic  ) IBOutlet UIButton          * takeButton;
@property (weak, nonatomic  ) IBOutlet UIButton          * flashAutoButton;
@property (weak, nonatomic  ) IBOutlet UIButton          * flashOnButton;
@property (weak, nonatomic  ) IBOutlet UIButton          * flashOffButton;

//摄像
@property (weak, nonatomic  ) IBOutlet UIButton          * takeViedoBtn;
@property (strong ,nonatomic) AVCaptureMovieFileOutput   * captureMovieFileOutput;
@property (assign ,nonatomic) BOOL                         enableRotation;//是否旋转(录制过程禁止旋转)
@property (assign ,nonatomic) CGRect                       lastRect;//旋转前大小
@property (assign ,nonatomic) AVCaptureDevicePosition      lastPosition;
@property (assign ,nonatomic) UIBackgroundTaskIdentifier   backgroundTaskIdentifier;//后台任务标识



@property (weak, nonatomic)            focusLayer        * focusLayer;
@property (strong, nonatomic)            CALayer           * cameraLayer;



@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //初始化session 会话
    _captureSession = [[AVCaptureSession alloc] init];
    //设置分辨率
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
#if 1
    //获取视频输入设备(默认后置摄像头)
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        NSLog(@"获取摄像头未通过");
        return;
    }
#endif
    //根据输入设备初始化输入对象,用于获得数据输入
    NSError* error = nil;
    _captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错,错误原因%@",error.localizedDescription);
        return;
    }
    
    //获取音频输入设备
    AVCaptureDevice* audioDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio][0];
    //获取数据输入
    AVCaptureDeviceInput* audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错,错误原因%@",error.localizedDescription);
        return;
    }
    
    //初始化设备输出对象,用于获得输出数据
    _captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary* outputsettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    _captureStillImageOutput.outputSettings = outputsettings;
    
    _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        //添加音频输入
        [_captureSession addInput:audioInput];
        
        AVCaptureConnection* captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
    }
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureStillImageOutput]) {
        [_captureSession addOutput:_captureStillImageOutput];
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    [self creatLayers];
    
    [self addNotificationToCaptureDevice:device];
    [self addGenstureRecognizer];
    [self setFlashModeButtonStatus];
    //允许旋转
    _enableRotation = YES;
}

/**
 *  创建_captureVideoPreviewLayer focusLayer 和 cameraLayer
 */
- (void)creatLayers{
    //创建视频预览层,用于显示摄像头状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    CALayer* viewLayer                     = _viewContainer.layer;
    viewLayer.masksToBounds                = YES;
    _captureVideoPreviewLayer.frame        = viewLayer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [_viewContainer.layer addSublayer:_captureVideoPreviewLayer];
    
    //focusLayer
    
    focusLayer* focuslayer = [focusLayer layer];
    focuslayer.bounds = CGRectMake(0, 0, 100, 100);
    focuslayer.anchorPoint = CGPointMake(0.5, 0.5);
    focuslayer.position = viewLayer.position;
    [focuslayer setNeedsDisplay];
    _focusLayer = focuslayer;
    [_viewContainer.layer addSublayer:_focusLayer];
    
    //cameraLayer
    _cameraLayer = [CALayer layer];
    _cameraLayer.frame = viewLayer.bounds;
    _cameraLayer.backgroundColor = [UIColor clearColor].CGColor;
    [_viewContainer.layer addSublayer:_cameraLayer];
    //    CALayer* focusLayer=[CALayer layer];
    //    //2.设置layer的属性
    //    focusLayer.backgroundColor=[UIColor clearColor].CGColor;
    //    focusLayer.bounds=CGRectMake(0, 0, 60, 60);
    //    focusLayer.anchorPoint = CGPointMake(0.5, 0.5);
    //    focusLayer.position=viewLayer.position;
    //    //设置代理
    //    focusLayer.delegate=self;
    //    [focusLayer setNeedsDisplay];
    //    //3.添加layer
    //    [_viewContainer.layer addSublayer:focusLayer];
}

//-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx{
//    //1.绘制图形
//    //用贝塞尔曲线画圆角
//    
//    NSLog(@"绘制 layer");
//    
//    CGRect rect = CGRectMake(0, 0, 60, 60);
//    CGContextAddPath(ctx, [UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(10, 10)].CGPath);
//    UIColor* color = [UIColor orangeColor];
//    UIColor* backgroundColor = [UIColor clearColor];
//    
//    [color setStroke];
//    [backgroundColor setFill];
//    
//    CGContextDrawPath(ctx, kCGPathStroke);
//}

/**
 *  添加手势
 */
- (void)addGenstureRecognizer{
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    [_viewContainer addGestureRecognizer:tap];
}

- (void)tapScreen:(UITapGestureRecognizer*)tap{
    CGPoint point = [tap locationInView:_viewContainer];
    //将 ui 坐标转化为camera 坐标
    CGPoint cameraPoint = [_captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    //设置聚光标位置
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}
/**
 *  设置聚光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point{
    _focusLayer.position = point;
    [_focusLayer setAffineTransform:CGAffineTransformMakeScale(1.5, 1.5)];
    _focusLayer.opacity = 1;
    [UIView animateWithDuration:1.0 animations:^{
        [_focusLayer setAffineTransform:CGAffineTransformIdentity];
        _focusLayer.backgroundColor = [UIColor blackColor].CGColor;
    } completion:^(BOOL finished) {
        _focusLayer.opacity = 1;
        _focusLayer.backgroundColor = [UIColor clearColor].CGColor;
    }];
}

/**
 *  设置闪光灯按钮设置
 */
- (void)setFlashModeButtonStatus{
    AVCaptureDevice* device = _captureDeviceInput.device;
    AVCaptureFlashMode flashMode = device.flashMode;
    if ([device isFlashAvailable]) {
        _flashAutoButton.hidden = NO;
        _flashOnButton.hidden = NO;
        _flashOffButton.hidden = NO;
        
        _flashAutoButton.enabled = YES;
        _flashOnButton.enabled = YES;
        _flashOffButton.enabled = YES;
        switch (flashMode) {
            case AVCaptureFlashModeOff: {
                _flashOffButton.enabled = NO;
                break;
            }
            case AVCaptureFlashModeOn: {
                _flashOnButton.enabled = NO;
                break;
            }
            case AVCaptureFlashModeAuto: {
                _flashAutoButton.enabled = NO;
                break;
            }
        }
    }else{
        _flashAutoButton.hidden = YES;
        _flashOnButton.hidden = YES;
        _flashOffButton.hidden = YES;
    }
}
/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
- (void)setFlashMode:(AVCaptureFlashMode)flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isFlashModeSupported:flashMode]) {
            device.flashMode = flashMode;
//            [self setFlashModeButtonStatus];
        }
    }];
}

/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
- (void)setFocusMode:(AVCaptureFocusMode)focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isFocusModeSupported:focusMode]) {
            device.focusMode = focusMode;
        }
    }];
}

/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
- (void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isExposureModeSupported:exposureMode]) {
            device.exposureMode = exposureMode;
        }
    }];
}

/**
 *  设置聚焦点
 *
 *  @param focusMode    聚焦模式
 *  @param exposureMode 曝光模式
 *  @param point        聚焦点
 */
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        if ([device isFocusModeSupported:focusMode]) {
            [device setFocusMode:focusMode];
        }
        if ([device isExposureModeSupported:exposureMode]) {
            [device setExposureMode:exposureMode];
        }
        if ([device isFocusPointOfInterestSupported]) {
            device.focusPointOfInterest = point;
        }
        if ([device isExposurePointOfInterestSupported]) {
            device.exposurePointOfInterest = point;
        }
    }];
    
}

- (AVCaptureDevice*)getCameraDeviceWithPosition:(AVCaptureDevicePosition)captureDevicePosition{
    NSArray* arr = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice* device in arr) {
        if (device.position == captureDevicePosition) {
            return device;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一方法
 *
 *  @param propertyChangeBlock 改变设备属性的操作 block
 */
- (void)changeDeviceProperty:(propertyChangeBlock)propertyChangeBlock{
    AVCaptureDevice* captureDevice = _captureDeviceInput.device;
    NSError* error = nil;
    //改变设备属性,改变属性之前要先对设备上锁,改变结束之后再解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChangeBlock(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误,错误信息%@",error.localizedDescription);
    }
}

#pragma mark notification

- (void)addNotificationToCaptureDevice:(AVCaptureDevice*)device{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *device) {
        device.subjectAreaChangeMonitoringEnabled = YES;
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(areaChange) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}

- (void)removeNotifacation{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice*)device{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:device];
}

#pragma mark 通知方法
- (void)areaChange{
    NSLog(@"捕获区域发生变化");
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [_captureSession startRunning];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_captureSession stopRunning];
}

-(void)dealloc{
    [self removeNotifacation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UI方法

- (IBAction)takeButtonClick:(UIButton *)sender {
    //根据设备输出获得connection
    AVCaptureConnection* captureConnection = [_captureStillImageOutput connectionWithMediaType: AVMediaTypeVideo];
    [_captureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer) {
            NSData* data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage* image = [[UIImage alloc] initWithData:data];
            //保存图片到相册
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }
    }];
    //做一个照相效果
    _cameraLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self performSelector:@selector(changeColor) withObject:nil afterDelay:0.1];
}
/**
 *  0.5s 后_captureVideoPreviewLayer变成透明
 */
- (void)changeColor{
    _cameraLayer.backgroundColor = [UIColor clearColor].CGColor;
}

//换摄像头
- (IBAction)toggleButtonClick:(UIButton *)sender {
    AVCaptureDevice* currentDevice = _captureDeviceInput.device;
    AVCaptureDevicePosition currentPosition = currentDevice.position;
    //移除当前设备通知
    [self removeNotificationFromCaptureDevice:currentDevice];
    
    AVCaptureDevicePosition toChangeDevicePosition = (currentPosition == AVCaptureDevicePositionFront ?
    AVCaptureDevicePositionBack : AVCaptureDevicePositionFront);
    AVCaptureDevice* toChangeDevice = [self getCameraDeviceWithPosition:toChangeDevicePosition];
    //添加设备通知
    [self addNotificationToCaptureDevice:toChangeDevice];
    //获取要调整的输入设备对象
    AVCaptureDeviceInput* toChangeDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:toChangeDevice error:nil];
    
    //改变会话前要一定要先开启配置,配置完成后提交配置改变
    [_captureSession beginConfiguration];
    //移除原输出
    [_captureSession removeInput:_captureDeviceInput];
    //添加新输出
    if ([_captureSession canAddInput:toChangeDeviceInput]) {
        [_captureSession addInput:toChangeDeviceInput];
        _captureDeviceInput = toChangeDeviceInput;
    }
    //调教session 配置
    [_captureSession commitConfiguration];
    [self setFlashModeButtonStatus];
}
- (IBAction)flashAutoClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeAuto];
    [self setFlashModeButtonStatus];
}
- (IBAction)flashOnClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeOn];
    [self setFlashModeButtonStatus];
}
- (IBAction)flashOffClick:(UIButton *)sender {
    [self setFlashMode:AVCaptureFlashModeOff];
    [self setFlashModeButtonStatus];
}
- (IBAction)takeVideo:(UIButton *)sender {
    //选择判断在 视频录制的代理中 改变
//    sender.selected = !sender.selected;
    
#if 1
    //根据设备输出获得连接
    AVCaptureConnection* captureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    //根据连接取得设备输出数据
    if (!self.captureMovieFileOutput.recording) {
        //开始录制
        self.enableRotation = NO;
        //如果支持多任务则开始多任务
        if ([UIDevice currentDevice].isMultitaskingSupported) {
            self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        //视频方向和预览图层方向一致
        captureConnection.videoOrientation = _captureVideoPreviewLayer.connection.videoOrientation;
        NSString* fileName = [NSString stringWithFormat:@"%@.mov",[self getTimeString]];
        NSString* outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        NSLog(@"保存路径 : %@",outputFilePath);
        NSURL* urlPath = [NSURL fileURLWithPath:outputFilePath];
        
        [self.captureMovieFileOutput startRecordingToOutputFileURL:urlPath recordingDelegate:self];
    }else{
        //停止录制
        [self.captureMovieFileOutput stopRecording];
    }
#endif
}

#pragma mark 获取当前时间(作为视频输出文件名)

- (NSString*)getTimeString{
    //1.获取本地时间
    NSDate *nowdate = [NSDate date];
    //2.自定义格式
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmSS";
    return [formatter stringFromDate:nowdate];
}

#pragma mark 调整图层方向(重写父类方法)

//重写 UIViewController 的方法
- (BOOL)shouldAutorotate{
    return self.enableRotation;
}

//-(void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
//    
//}

//iOS8 以后的方法
-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    //这里不会超出范围,UIDeviceOrientationFaceUp和UIDeviceOrientationFaceDown 这两个方向不会触发该方法
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)[UIDevice currentDevice].orientation;
    AVCaptureConnection* captureConnection = _captureVideoPreviewLayer.connection;
    captureConnection.videoOrientation = (AVCaptureVideoOrientation)orientation;
    CGRect rect = _captureVideoPreviewLayer.frame;
    rect.size = size;
    _captureVideoPreviewLayer.frame = rect;
    //视频方向和预览图层方向一致
    AVCaptureConnection* outCaptureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    outCaptureConnection.videoOrientation = (AVCaptureVideoOrientation)orientation;
    
}
#if 0
//iOS8 之前的方法
-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    AVCaptureConnection* captureConnection = _captureVideoPreviewLayer.connection;
    captureConnection.videoOrientation = (AVCaptureVideoOrientation)toInterfaceOrientation;
}
//iOS8 之前的方法
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    _captureVideoPreviewLayer.frame = self.viewContainer.bounds;
}
#endif

#pragma mark AVCaptureFileOutputRecordingDelegate
/*
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制");
    NSLog(@"arr:%ld",connections.count);
    self.takeViedoBtn.selected = YES;
}

-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"视频录制完成");
    //录制完成后在后台将视频保存到相册
    self.enableRotation = YES;
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = self.backgroundTaskIdentifier;
    //设置默认值
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    
    //iOS8 之后的 photoKit , 一下写法来自 apple 文档
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest* createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputFileURL];
        PHObjectPlaceholder* assetPlaceholder = [createAssetRequest placeholderForCreatedAsset];
        //获取相机相册
        PHFetchResult *smartAlbumsFetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:smartAlbumsFetchResult[0]];
        [albumChangeRequest addAssets:@[assetPlaceholder]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        }
        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
    }];
    self.takeViedoBtn.selected = NO;
}
*/

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
    self.takeViedoBtn.selected = YES;
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"视频录制完成.");
    //视频录入完成之后在后台将视频存储到相簿
    self.enableRotation=YES;
    UIBackgroundTaskIdentifier lastBackgroundTaskIdentifier=self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier=UIBackgroundTaskInvalid;
    ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
        }
        if (lastBackgroundTaskIdentifier!=UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:lastBackgroundTaskIdentifier];
        }
        self.takeViedoBtn.selected = NO;
        NSLog(@"成功保存视频到相簿.");
    }];
    
}

@end
























































