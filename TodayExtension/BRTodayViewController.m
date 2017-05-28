//
//  TodayViewController.m
//  TodayWidget
//
//  Created by Henry on 6/14/15.
//  Copyright (c) 2015 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BRTodayViewController.h"
#import "BRAppGroupConstants.h"
#import "BRBubbleView.h"
#import "UIImage+Utils.h"
#import <NotificationCenter/NotificationCenter.h>

#define SCAN_URL @"bread://x-callback-url/scanqr"
#define OPEN_URL @"bread://"

@interface BRTodayViewController () <NCWidgetProviding>

@property (nonatomic, weak) IBOutlet UIImageView *qrImage, *qrOverlay, *scanOverlay;
@property (nonatomic, weak) IBOutlet UILabel *addressLabel, *sendLabel, *receiveLabel, *scanLabel;
@property (nonatomic, weak) IBOutlet UIButton *scanButton;
@property (nonatomic, weak) IBOutlet UIVisualEffectView *qrView, *scanView;
@property (nonatomic, weak) IBOutlet UIView *noDataViewContainer;
@property (nonatomic, weak) IBOutlet UIView *topViewContainer;
@property (nonatomic, strong) NSData *qrCodeData;
@property (nonatomic, strong) NSUserDefaults *appGroupUserDefault;
@property (nonatomic, strong) BRBubbleView *bubbleView;

@end

@implementation BRTodayViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[self.extensionContext class] instancesRespondToSelector:@selector(widgetLargestAvailableDisplayMode)]) {
        self.extensionContext.widgetLargestAvailableDisplayMode = NCWidgetDisplayModeExpanded;
        self.addressLabel.textColor = self.sendLabel.textColor = self.receiveLabel.textColor =
            self.scanLabel.textColor = [UIColor darkGrayColor];
        self.qrView.effect = [UIVibrancyEffect
                              effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
        self.scanView.effect = [UIVibrancyEffect
                                effectForBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
        self.scanButton.alpha = 0.1;
        [self.scanButton setImage:[UIImage imageNamed:@"scanbutton-dark"] forState:UIControlStateNormal];
        self.scanOverlay.image = [UIImage imageNamed:@"scanbutton-dark"];
    }
    
    [self updateReceiveMoneyUI];
}

- (void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode withMaximumSize:(CGSize)maxSize
{
    if (activeDisplayMode == NCWidgetDisplayModeExpanded) {
        self.preferredContentSize = CGSizeMake(maxSize.width, maxSize.width*3/4);
    }
    else self.preferredContentSize = maxSize;
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler
{
    [self.bubbleView popOut];
    self.bubbleView = nil;
    if (! completionHandler) return;
    
    // Perform any setup necessary in order to update the view.
    NSData *data = [self.appGroupUserDefault objectForKey:APP_GROUP_REQUEST_DATA_KEY];

    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData
    if ([self.qrCodeData isEqualToData:data]) {
        self.noDataViewContainer.hidden = YES;
        self.topViewContainer.hidden = NO;
        completionHandler(NCUpdateResultNoData);
    }
    else if (self.qrCodeData) {
        self.qrCodeData = data;
        self.noDataViewContainer.hidden = YES;
        self.topViewContainer.hidden = NO;
        [self updateReceiveMoneyUI];
        completionHandler(NCUpdateResultNewData);
    }
    else {
        self.noDataViewContainer.hidden = NO;
        self.topViewContainer.hidden = YES;
        completionHandler(NCUpdateResultFailed);
    }
}

- (NSUserDefaults *)appGroupUserDefault
{
    if (! _appGroupUserDefault) _appGroupUserDefault = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP_ID];
    return _appGroupUserDefault;
}

- (void)updateReceiveMoneyUI
{
    self.qrCodeData = [self.appGroupUserDefault objectForKey:APP_GROUP_REQUEST_DATA_KEY];
    
    if (self.qrCodeData && self.qrImage.bounds.size.width > 0) {
        if ([[self.extensionContext class] instancesRespondToSelector:@selector(widgetLargestAvailableDisplayMode)]) {
            self.qrOverlay.image = [[UIImage imageWithQRCodeData:self.qrCodeData
                                    color:[CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0]]
                                    resize:CGSizeMake(240, 240)
                                    withInterpolationQuality:kCGInterpolationNone];
            self.qrImage.image = [[UIImage imageWithQRCodeData:self.qrCodeData
                                  color:[CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.3]]
                                  resize:CGSizeMake(240, 240)
                                  withInterpolationQuality:kCGInterpolationNone];
        }
        else {
            self.qrImage.image = self.qrOverlay.image = [[UIImage imageWithQRCodeData:self.qrCodeData
                                                         color:[CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.0]]
                                                         resize:CGSizeMake(240, 240)
                                                         withInterpolationQuality:kCGInterpolationNone];
        }
    }

    self.addressLabel.text = [self.appGroupUserDefault objectForKey:APP_GROUP_RECEIVE_ADDRESS_KEY];
}

// MARK: - NCWidgetProviding

- (UIEdgeInsets)widgetMarginInsetsForProposedMarginInsets:(UIEdgeInsets)defaultMarginInsets
{
    return UIEdgeInsetsZero;
}

// MARK: - UI Events

- (IBAction)scanButtonTapped:(UIButton *)sender
{
    [self.extensionContext openURL:[NSURL URLWithString:SCAN_URL] completionHandler:nil];
}

- (IBAction)openAppButtonTapped:(id)sender
{
    [self.extensionContext openURL:[NSURL URLWithString:OPEN_URL] completionHandler:nil];
}

- (IBAction)qrImageTapped:(id)sender
{
    // UIMenuControl doesn't seem to work in an NCWidget, so use a BRBubbleView that looks nearly the same
    if (self.bubbleView) {
        if (CGRectContainsPoint(self.bubbleView.frame,
                                [(UITapGestureRecognizer *)sender locationInView:self.bubbleView.superview])) {
            [UIPasteboard generalPasteboard].string = self.addressLabel.text;
        }
    
        [self.bubbleView popOut];
        self.bubbleView = nil;
    }
    else {
        self.bubbleView = [BRBubbleView viewWithText:NSLocalizedString(@"Copy", nil)
                           tipPoint:CGPointMake(self.addressLabel.center.x, self.addressLabel.frame.origin.y - 5.0)
                           tipDirection:BRBubbleTipDirectionDown];
        self.bubbleView.alpha = 0;
        self.bubbleView.font = [UIFont systemFontOfSize:14.0];
        self.bubbleView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        [self.addressLabel.superview addSubview:self.bubbleView];
        [self.bubbleView becomeFirstResponder]; //this will cause bubbleview to hide when it loses firstresponder status
        [UIView animateWithDuration:0.2 animations:^{ self.bubbleView.alpha = 1.0; }];
    }
}

- (IBAction)widgetTapped:(id)sender
{
    [self.bubbleView popOut];
    self.bubbleView = nil;
}

@end
