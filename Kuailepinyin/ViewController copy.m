//
//  ViewController.m
//  Kuailepinyin
//
//  Created by True Pai on 7/29/18.
//  Copyright © 2018 True Pai. All rights reserved.
//
#define IMPEDE_PLAYBACK NO
#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIWebView *webview;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic) AVAudioRecorder *audioRecorder;
@property (nonatomic) AVAudioPlayer *audioPlayer;
@property (nonatomic) NSURL *recordedAudioURL;
@end

// Record speech using audio Engine
AVAudioInputNode *inputNode;
AVAudioEngine *audioEngine;
int totalSeconds;
CGFloat width,height;

NSString *audioFileName;
NSString *mp3FilePath;

@implementation ViewController
@synthesize audioPlayer, audioRecorder, recordedAudioURL;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    if (IMPEDE_PLAYBACK) {
        [AudioSessionManager setAudioSessionCategory:AVAudioSessionCategoryPlayAndRecord];
    }
    width = self.view.bounds.size.width;
    height = self.view.bounds.size.height;
    NSString *urlAddress = @"https://kuaile.hulalaedu.com/student";
    NSURL *url = [NSURL URLWithString:urlAddress];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    _webview.allowsLinkPreview = true;
    _webview.allowsInlineMediaPlayback = YES;
    _webview.allowsPictureInPictureMediaPlayback = YES;
    _webview.mediaPlaybackRequiresUserAction = NO;
    _webview.delegate = self;
    [_webview loadRequest:requestObj];
    
    _indicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(width/2 - 100, height/2 - 77.5, 200,155)];
    [self.view addSubview:_indicator];
    CGAffineTransform transform = CGAffineTransformMakeScale(3.0f,3.0f);
    _indicator.transform = transform;
    _indicator.hidden = YES;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    
    NSLog(@"Loading URL :%@", request.URL.absoluteString);
    if ([request.URL.scheme isEqualToString:@"recordstop"]) {
        NSString *receiveString = [request.URL.absoluteString stringByReplacingOccurrencesOfString:@"recordstop://" withString:@""];
        NSString *taskId = [[receiveString componentsSeparatedByString:@";"] objectAtIndex:0];
        NSString *probId = [[receiveString componentsSeparatedByString:@";"] objectAtIndex:1];
        if ([self.audioRecorder isRecording])[self.audioRecorder stop];
        else if (self.audioPlayer.playing)[self.audioPlayer stop];
        [self uploadAudio:taskId :probId];
    }else if ([request.URL.scheme isEqualToString:@"recordstart"]) {
        if(!audioEngine.isRunning){
            [self startRecording];
        }
    }else if ([request.URL.scheme isEqualToString:@"audioplay"]) {
        NSLog(@"Playing AUDIO...");
        [self AudioPlay];
    }else if ([request.URL.scheme isEqualToString:@"audiopause"]) {
        NSLog(@"Pausing AUDIO...");
        [self AudioStop];
    }
    
    return YES;
}


// recording
- (void)startRecording {
    if (!IMPEDE_PLAYBACK) {
        [AudioSessionManager setAudioSessionCategory:AVAudioSessionCategoryRecord];
    }
    
    // sets the path for audio file
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               [NSString stringWithFormat:@"record.m4a"],
                               nil];
    recordedAudioURL = [NSURL fileURLWithPathComponents:pathComponents];
    
    // settings for the recorder
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    [recordSetting setValue:[NSNumber numberWithInt: 16] forKey:AVLinearPCMBitDepthKey];
    [recordSetting setValue:[NSNumber numberWithBool: NO] forKey:AVLinearPCMIsBigEndianKey];
    [recordSetting setValue:[NSNumber numberWithBool: NO] forKey:AVLinearPCMIsFloatKey];
    [recordSetting setValue:[NSNumber numberWithInt: AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    
    // initiate recorder
    NSError *error;
    audioRecorder = [[AVAudioRecorder alloc] initWithURL:[self recordedAudioURL] settings:recordSetting error:&error];
    [audioRecorder prepareToRecord];
    [audioRecorder recordForDuration:30];
    
}

-(void)AudioPlay
{
    if (!self.audioRecorder.recording) {
        NSLog(@"Audio PlayBack");
        
        if (!IMPEDE_PLAYBACK) {
            [AudioSessionManager setAudioSessionCategory:AVAudioSessionCategoryPlayback];
        }
        
        NSError *audioError;
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[self recordedAudioURL] error:&audioError];
        if(audioError != nil){
            NSLog(@"Error : %@",audioError.localizedDescription);
        }
        
        self.audioPlayer.delegate = self;
        [self.audioPlayer play];
        
    }else [self.audioRecorder stop];
}

-(void)AudioStop{
    [self.audioPlayer pause];
}

#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"PLAY END");
    [self.audioPlayer stop];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"Error occured");
}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    NSLog(@"Recorded Successfully");
}


-(void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"Encode Error occurred");
}

- (void)uploadAudio:(NSString *)tId :(NSString*)pId {
    
    NSLog(@"----- Task Id : %@",tId);
    NSLog(@"----- Prob Id : %@",pId);
    
    /////////////------Uploading....-----------//////////
    _indicator.hidden = NO;
    [_indicator startAnimating];
    self.view.alpha = 10.6;
    
    NSData *audioData = [NSData dataWithContentsOfURL:self.recordedAudioURL];
    NSString *urlString = @"https://kuaile.hulalaedu.com/student/work/saveRecordedAudio";
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [request setTimeoutInterval:30.0];
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = @"---------------------------14737809831466499882746641449";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
    [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *body = [NSMutableData data];
    // text parameter
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"tId\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[tId dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // another text parameter
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"pId\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[pId dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // add audio data
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *header = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"answer_mp3\"; filename=\"%@.m4a\"", tId];
    [body appendData:[[NSString stringWithString:header] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[NSData dataWithData:audioData]];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:body];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSString *requestReply = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSLog(@"Request reply: %@", requestReply);
        dispatch_async(dispatch_get_main_queue(), ^{
            [_indicator stopAnimating];
            self.view.alpha = 1;
            _indicator.hidden = YES;
        });
    }] resume];
}

@end
