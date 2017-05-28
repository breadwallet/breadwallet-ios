//
//  BRBubbleView.m
//  BreadWallet
//
//  Created by Aaron Voisine on 3/10/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
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

#import "BRBubbleView.h"

#define RADIUS       8.0
#define MARGIN_X    16.0
#define MARGIN_Y     9.0
#define MARGIN_EDGE 10.0
#define MAX_WIDTH  300.0

@interface BRBubbleView ()

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) CAShapeLayer *arrow;

@end

@implementation BRBubbleView

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)resignFirstResponder
{
    if ([super resignFirstResponder]) {
        [self popOut];
        return YES;
    }
    else return NO;
}

+ (instancetype)viewWithText:(NSString *)text center:(CGPoint)center
{
    BRBubbleView *v = [[self alloc] initWithFrame:CGRectMake(center.x - MARGIN_X, center.y - MARGIN_Y, MARGIN_X*2,
                                                             MARGIN_Y*2)];

    v.text = text;
    return v;
}

+ (instancetype)viewWithText:(NSString *)text tipPoint:(CGPoint)point tipDirection:(BRBubbleTipDirection)direction
{
    BRBubbleView *v = [[self alloc] initWithFrame:CGRectMake(0, 0, MARGIN_X*2, MARGIN_Y*2)];

    v.text = text;
    v.tipDirection = direction;
    v.tipPoint = point;
    return v;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (! (self = [super initWithFrame:frame])) return nil;

    self.layer.cornerRadius = RADIUS;
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(MARGIN_X, MARGIN_Y, frame.size.width - MARGIN_X*2,
                                                           frame.size.height - MARGIN_Y*2)];
    self.label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.textColor = [UIColor whiteColor];
    self.label.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:17.0];
    self.label.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15];
    self.label.shadowOffset = CGSizeMake(0.0, 1.0);
    self.label.numberOfLines = 0;
    [self addSubview:self.label];

    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)setText:(NSString *)text
{
    self.label.text = text;
    [self setNeedsLayout];
}

- (NSString *)text
{
    return self.label.text;
}

- (void)setFont:(UIFont *)font
{
    self.label.font = font;
    [self setNeedsLayout];
}

- (UIFont *)font
{
    return self.label.font;
}

- (void)setTipPoint:(CGPoint)tipPoint
{
    _tipPoint = tipPoint;
    [self setNeedsLayout];
}

- (void)setTipDirection:(BRBubbleTipDirection)tipDirection
{
    _tipDirection = tipDirection;
    [self setNeedsLayout];
}

- (void)setCustomView:(UIView *)customView
{
    if (_customView) [_customView removeFromSuperview];
    _customView = customView;
    customView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                  UIViewAutoresizingFlexibleBottomMargin;
    if (customView) [self addSubview:customView];
    [self setNeedsLayout];
}

- (instancetype)popIn
{
    self.alpha = 0.0;
    self.transform = CGAffineTransformMakeScale(0.75, 0.75);

    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.5 initialSpringVelocity:0
     options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformMakeScale(1.0, 1.0);
        self.alpha = 1.0;
    } completion:nil];

    return self;
}

- (instancetype)popOut
{
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeScale(0.75, 0.75);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];

    return self;
}

- (instancetype)popOutAfterDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(popOut) withObject:nil afterDelay:delay];
    return self;
}

- (void)layoutSubviews
{
    CGPoint center = self.center;
    CGRect rect = [self.label textRectForBounds:CGRectMake(0.0, 0.0, MAX_WIDTH - MARGIN_X*2, CGFLOAT_MAX)
                   limitedToNumberOfLines:0];

    if (self.customView) {
        if (rect.size.width < self.customView.frame.size.width) rect.size.width = self.customView.frame.size.width;
        rect.size.height += self.customView.frame.size.height + (self.text.length > 0 ? MARGIN_Y : 0);
    }

    if (self.tipPoint.x > 1) { // position bubble to point to tipPoint
        center.x = self.tipPoint.x;

        if (center.x + rect.size.width/2 > self.superview.frame.size.width - MARGIN_EDGE) {
            center.x = (self.superview.frame.size.width - MARGIN_EDGE) - rect.size.width/2;
        }
        else if (center.x - rect.size.width/2 < MARGIN_EDGE + MARGIN_X) {
            center.x = MARGIN_EDGE + MARGIN_X + rect.size.width/2;
        }

        center.y = self.tipPoint.y;
        center.y += (self.tipDirection == BRBubbleTipDirectionUp ? 1 : -1)*((rect.size.height + MARGIN_Y*2)/2 + RADIUS);
    }

    self.frame = CGRectMake(center.x - (rect.size.width + MARGIN_X*2)/2, center.y - (rect.size.height + MARGIN_Y*2)/2,
                            rect.size.width + MARGIN_X*2, rect.size.height + MARGIN_Y*2);

    if (self.customView) { // layout customView and label
        self.customView.center = CGPointMake((rect.size.width + MARGIN_X*2)/2,
                                             self.customView.frame.size.height/2 + MARGIN_Y);
        self.label.frame = CGRectMake(MARGIN_X, self.customView.frame.size.height + MARGIN_Y*2,
                                      self.label.frame.size.width,
                                      self.frame.size.height - (self.customView.frame.size.height + MARGIN_Y*3));
    }
    else {
        self.label.frame = CGRectMake(MARGIN_X, MARGIN_Y, self.label.frame.size.width,
                                      self.frame.size.height - MARGIN_Y*2);
    }

    if (self.tipPoint.x > 1) { // draw tip arrow
        CGMutablePathRef path = CGPathCreateMutable();
        CGFloat x = self.tipPoint.x - (center.x - (rect.size.width + MARGIN_X*2)/2);

        if (! self.arrow) self.arrow = [[CAShapeLayer alloc] init];
        if (x > rect.size.width + MARGIN_X*2 - (RADIUS + 7.5)) x = rect.size.width + MARGIN_X*2 - (RADIUS + 7.5);
        if (x < self.layer.cornerRadius + 7.5) x = self.layer.cornerRadius + 7.5;

        if (self.tipDirection == BRBubbleTipDirectionUp) {
            CGPathMoveToPoint(path, NULL, 0.0, 7.5);
            CGPathAddLineToPoint(path, NULL, 7.5, 0.0);
            CGPathAddLineToPoint(path, NULL, 15.0, 7.5);
            CGPathAddLineToPoint(path, NULL, 0.0, 7.5);
            self.arrow.position = CGPointMake(x, 0.5);
            self.arrow.anchorPoint = CGPointMake(0.5, 1.0);
        }
        else {
            CGPathMoveToPoint(path, NULL, 0.0, 0.0);
            CGPathAddLineToPoint(path, NULL, 7.5, 7.5);
            CGPathAddLineToPoint(path, NULL, 15.0, 0.0);
            CGPathAddLineToPoint(path, NULL, 0.0, 0.0);
            self.arrow.position = CGPointMake(x, rect.size.height + MARGIN_Y*2 - 0.5);
            self.arrow.anchorPoint = CGPointMake(0.5, 0.0);
        }

        self.arrow.path = path;
        self.arrow.strokeColor = [UIColor clearColor].CGColor;
        self.arrow.fillColor = self.backgroundColor.CGColor;
        self.arrow.bounds = CGRectMake(0.0, 0.0, 15.0, 7.5);
        [self.layer addSublayer:self.arrow];
        CGPathRelease(path);
    }
    else if (self.arrow) { // remove tip arrow
        [self.arrow removeFromSuperlayer];
        self.arrow = nil;
    }

    [super layoutSubviews];
}

@end
