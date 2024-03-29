//
//  SKTransitionController.m
//  Skim
//
//  Created by Christiaan Hofman on 7/15/07.
/*
 This software is Copyright (c) 2007
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 This code is based partly on Apple's AnimatingTabView example code
 and Ankur Kothari's AnimatingTabsDemo application <http://dev.lipidity.com>
*/

#import "SKTransitionController.h"
#import "NSBitmapImageRep_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "SKStringConstants.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Quartz/Quartz.h>

#define kCIInputBacksideImageKey @"inputBacksideImage"

#define TRANSITIONS_PLUGIN @"SkimTransitions.plugin"

#define SKEnableCoreGraphicsTransitionsKey @"SKEnableCoreGraphicsTransitions"

#pragma mark Private Core Graphics types and functions

typedef int CGSConnection;
typedef int CGSWindow;

typedef enum _CGSTransitionType {
  CGSNone,
  CGSFade,
  CGSZoom,
  CGSReveal,
  CGSSlide,
  CGSWarpFade,
  CGSSwap,
  CGSCube,
  CGSWarpSwitch,
  CGSFlip
} CGSTransitionType;

typedef enum _CGSTransitionOption {
  CGSDown,
  CGSLeft,
  CGSRight,
  CGSInRight,
  CGSBottomLeft = 5,
  CGSBottomRight,
  CGSDownTopRight,
  CGSUp,
  CGSTopLeft,
  CGSTopRight,
  CGSUpBottomRight,
  CGSInBottom,
  CGSLeftBottomRight,
  CGSRightBottomLeft,
  CGSInBottomRight,
  CGSInOut
} CGSTransitionOption;

typedef struct _CGSTransitionSpec {
  uint32_t unknown1;
  CGSTransitionType type;
  CGSTransitionOption option;
  CGSWindow wid;     // Can be 0 for full-screen
  float *backColour; // Null for black otherwise pointer to 3 CGFloat array with
                     // RGB value
} CGSTransitionSpec;

static CGSConnection (*_CGSDefaultConnection_func)(void) = NULL;
static OSStatus (*CGSNewTransition_func)(const CGSConnection cid,
                                         const CGSTransitionSpec *spec,
                                         int *pTransitionHandle) = NULL;
static OSStatus (*CGSInvokeTransition_func)(const CGSConnection cid,
                                            int transitionHandle,
                                            float duration);
static OSStatus (*CGSReleaseTransition_func)(const CGSConnection cid,
                                             int transitionHandle);

#define LOAD_FUNCTION(name, bundle)                                            \
  ((name##_func = (typeof(name##_func))CFBundleGetFunctionPointerForName(      \
        bundle, CFSTR(#name))) != NULL)

#pragma mark -

@protocol SKTransitionView <NSObject>
@property(nonatomic, strong) CIImage *image;
@property(nonatomic) CGRect extent;
@property(nonatomic, strong) CIFilter *filter;
@property(nonatomic) CGFloat progress;
@end

#pragma mark -

@interface SKTransitionView : NSView <SKTransitionView> {
  CIImage *image;
  CGRect extent;
  CIFilter *filter;
}
@end

#pragma mark -

@interface SKMetalTransitionView : NSView <SKTransitionView, MTKViewDelegate> {
  MTKView *metalView;
  CIImage *image;
  CGRect extent;
  CIFilter *filter;
  id<MTLCommandQueue> commandQueue;
  CIContext *context;
}
@end

#pragma mark -

// Core Graphics transitions
// this corresponds to the CGSTransitionType enum
enum {
  SKTransitionFade = 1,
  SKTransitionZoom,
  SKTransitionReveal,
  SKTransitionSlide,
  SKTransitionWarpFade,
  SKTransitionSwap,
  SKTransitionCube,
  SKTransitionWarpSwitch,
  SKTransitionFlip
};

static SKTransitionStyle SKCoreImageTransition = 1;

@implementation SKTransitionController

@synthesize view, transition, pageTransitions;
@dynamic hasTransition;

static NSDictionary *oldStyleNames = nil;

+ (void)initialize {
  SKINITIALIZE;
  oldStyleNames = [[NSDictionary alloc]
      initWithObjectsAndKeys:
          @"CoreGraphics SKTransitionFade", @"CIDissolveTransition",
          @"CoreGraphics SKTransitionZoom", @"SKTZoomTransition",
          @"CoreGraphics SKTransitionReveal", @"SKTRevealTransition",
          @"CoreGraphics SKTransitionSlide", @"SKTSlideTransition",
          @"CoreGraphics SKTransitionWarpFade", @"SKTWarpFadeTransition",
          @"CoreGraphics SKTransitionSwap", @"SKTSwapTransition",
          @"CoreGraphics SKTransitionCube", @"SKTCubeTransition",
          @"CoreGraphics SKTransitionWarpSwitch", @"SKTWarpSwitchTransition",
          @"CoreGraphics SKTransitionWarpFlip", @"SKTFlipTransition",
          @"SKPTAccelerationTransitionFilter", @"SKTAccelerationTransition",
          @"SKPTBlindsTransitionFilter", @"SKTBlindsTransition",
          @"SKPTBlurTransitionFilter", @"SKTBlurTransition",
          @"SKPTBoxInTransitionFilter", @"SKTBoxInTransition",
          @"SKPTBoxOutTransitionFilter", @"SKTBoxOutTransition",
          @"SKPTCoverTransitionFilter", @"SKTCoverTransition",
          @"SKPTHoleTransitionFilter", @"SKTHoleTransition",
          @"SKPTMeltdownTransitionFilter", @"SKTMeltdownTransition",
          @"SKPTPinchTransitionFilter", @"SKTPinchTransition",
          @"SKPTRadarTransitionFilter", @"SKTRadarTransition",
          @"SKPTSinkTransitionFilter", @"SKTSinkTransition",
          @"SKPTSplitInTransitionFilter", @"SKTSplitInTransition",
          @"SKPTSplitOutTransitionFilter", @"SKSplitOutTransition",
          @"SKPTStripsTransitionFilter", @"SKTStripsTransition",
          @"SKPTUncoverTransitionFilter", @"SKTRevealTransition", nil];
  if ([[NSUserDefaults standardUserDefaults]
          boolForKey:SKEnableCoreGraphicsTransitionsKey]) {
    CFBundleRef bundle =
        CFBundleGetBundleWithIdentifier(CFSTR("com.apple.CoreGraphics"));
    if (bundle && LOAD_FUNCTION(_CGSDefaultConnection, bundle) &&
        LOAD_FUNCTION(_CGSDefaultConnection, bundle) &&
        LOAD_FUNCTION(CGSNewTransition, bundle) &&
        LOAD_FUNCTION(CGSInvokeTransition, bundle) &&
        LOAD_FUNCTION(CGSReleaseTransition, bundle)) {
      SKCoreImageTransition = SKTransitionFlip + 1;
    }
  }
}

+ (NSArray *)transitionNames {
  static NSArray *transitionNames = nil;

  if (transitionNames == nil) {
    NSMutableArray *names = [NSMutableArray arrayWithObjects:@"", nil];
    if (SKCoreImageTransition > 1) {
      [names addObjectsFromArray:@[
        @"CoreGraphics SKTransitionFade", @"CoreGraphics SKTransitionZoom",
        @"CoreGraphics SKTransitionReveal", @"CoreGraphics SKTransitionSlide",
        @"CoreGraphics SKTransitionWarpFade", @"CoreGraphics SKTransitionSwap",
        @"CoreGraphics SKTransitionCube",
        @"CoreGraphics SKTransitionWarpSwitch",
        @"CoreGraphics SKTransitionWarpFlip"
      ]];
    }
    // get our transitions
    NSURL *transitionsURL = [[[NSBundle mainBundle] builtInPlugInsURL]
        URLByAppendingPathComponent:TRANSITIONS_PLUGIN
                        isDirectory:YES];
    [CIPlugIn loadPlugIn:transitionsURL allowExecutableCode:YES];
    // get all the transition filters
    [CIPlugIn loadAllPlugIns];
    [names
        addObjectsFromArray:[CIFilter
                                filterNamesInCategory:kCICategoryTransition]];
    transitionNames = [names copy];
  }

  return transitionNames;
}

+ (NSString *)nameForStyle:(SKTransitionStyle)style {
  if (style > SKNoTransition && style < [[self transitionNames] count])
    return [[self transitionNames] objectAtIndex:style];
  else
    return nil;
}

+ (SKTransitionStyle)styleForName:(NSString *)name {
  NSUInteger idx = [[self transitionNames] indexOfObject:name];
  if (idx == NSNotFound) {
    NSString *altName = [oldStyleNames objectForKey:name];
    if (altName)
      idx = [[self transitionNames] indexOfObject:altName];
  }
  return idx == NSNotFound ? SKNoTransition : idx;
}

+ (NSString *)localizedNameForStyle:(SKTransitionStyle)style {
  if (style == SKNoTransition) {
    return NSLocalizedString(@"No Transition", @"Transition name");
  } else if (style >= SKCoreImageTransition) {
    return [CIFilter localizedNameForFilterName:[self nameForStyle:style]];
  } else {
    static NSArray *localizedCoreGraphicsNames = nil;
    if (localizedCoreGraphicsNames == nil)
      localizedCoreGraphicsNames = [[NSArray alloc]
          initWithObjects:@"", NSLocalizedString(@"Fade", @"Transition name"),
                          NSLocalizedString(@"Zoom", @"Transition name"),
                          NSLocalizedString(@"Reveal", @"Transition name"),
                          NSLocalizedString(@"Reveal", @"Transition name"),
                          NSLocalizedString(@"Slide", @"Transition name"),
                          NSLocalizedString(@"Warp Fade", @"Transition name"),
                          NSLocalizedString(@"Swap", @"Transition name"),
                          NSLocalizedString(@"Cube", @"Transition name"),
                          NSLocalizedString(@"Warp Switch", @"Transition name"),
                          NSLocalizedString(@"Flip", @"Transition name"), nil];
    return [[localizedCoreGraphicsNames objectAtIndex:style]
        stringByAppendingString:@"*"];
  }
  return @"";
}

- (BOOL)hasTransition {
  return
      [transition transitionStyle] != SKNoTransition || pageTransitions != nil;
}

- (void)setTransition:(SKTransitionInfo *)newTransition {
  if (transition != newTransition) {
    [[[view undoManager] prepareWithInvocationTarget:self]
        setTransition:transition];
    transition = newTransition;
  }
}

- (void)setPageTransitions:(NSArray *)newPageTransitions {
  if (newPageTransitions != pageTransitions) {
    [[[view undoManager] prepareWithInvocationTarget:self]
        setPageTransitions:pageTransitions];
    pageTransitions = [newPageTransitions copy];
  }
}

static inline CGRect scaleRect(NSRect rect, CGFloat scale) {
  return CGRectMake(scale * NSMinX(rect), scale * NSMinY(rect),
                    scale * NSWidth(rect), scale * NSHeight(rect));
}

// rect and bounds are in pixels
- (CIFilter *)transitionFilterForTransition:(SKTransitionInfo *)info
                                       rect:(CGRect)rect
                                     bounds:(CGRect)bounds
                                    forward:(BOOL)forward
                               initialImage:(CIImage *)initialImage
                                 finalImage:(CIImage *)finalImage {
  NSString *filterName = [[self class] nameForStyle:[info transitionStyle]];
  CIFilter *transitionFilter = [CIFilter filterWithName:filterName];

  [transitionFilter setDefaults];

  for (NSString *key in [transitionFilter inputKeys]) {
    id value = nil;
    if ([key isEqualToString:kCIInputExtentKey]) {
      CGRect extent = [info shouldRestrict] ? rect : bounds;
      value = [CIVector vectorWithCGRect:extent];
    } else if ([key isEqualToString:kCIInputAngleKey]) {
      CGFloat angle = forward ? 0.0 : M_PI;
      if ([filterName hasPrefix:@"CIPageCurl"])
        angle = forward ? -M_PI_4 : -3.0 * M_PI_4;
      value = [NSNumber numberWithDouble:angle];
    } else if ([key isEqualToString:kCIInputCenterKey]) {
      value = [CIVector vectorWithX:CGRectGetMidX(rect) Y:CGRectGetMidY(rect)];
    } else if ([key isEqualToString:kCIInputImageKey]) {
      value = initialImage;
    } else if ([key isEqualToString:kCIInputTargetImageKey]) {
      value = finalImage;
    } else if ([key isEqualToString:kCIInputShadingImageKey]) {
      static CIImage *inputShadingImage = nil;
      if (inputShadingImage == nil)
        inputShadingImage = [[CIImage alloc]
            initWithContentsOfURL:[[NSBundle mainBundle]
                                      URLForResource:@"TransitionShading"
                                       withExtension:@"tiff"]];
      value = inputShadingImage;
    } else if ([key isEqualToString:kCIInputBacksideImageKey]) {
      value = initialImage;
    } else if ([[[[transitionFilter attributes] objectForKey:key]
                   objectForKey:kCIAttributeType]
                   isEqualToString:kCIAttributeTypeBoolean]) {
      if ([[NSSet setWithObjects:@"inputBackward", @"inputRight",
                                 @"inputReversed", nil] containsObject:key])
        value = [NSNumber numberWithBool:forward == NO];
      else if ([[NSSet setWithObjects:@"inputForward", @"inputLeft", nil]
                   containsObject:key])
        value = [NSNumber numberWithBool:forward];
    } else if ([[[[transitionFilter attributes] objectForKey:key]
                   objectForKey:kCIAttributeClass]
                   isEqualToString:@"CIImage"]) {
      // Scale and translate our mask image to match the transition area size.
      static CIImage *inputMaskImage = nil;
      if (inputMaskImage == nil)
        inputMaskImage = [[CIImage alloc]
            initWithContentsOfURL:[[NSBundle mainBundle]
                                      URLForResource:@"TransitionMask"
                                       withExtension:@"jpg"]];
      CGRect extent = [inputMaskImage extent];
      CGAffineTransform transform;
      if ((CGRectGetWidth(extent) < CGRectGetHeight(extent)) !=
          (CGRectGetWidth(rect) < CGRectGetHeight(rect))) {
        transform = CGAffineTransformMake(0.0, 1.0, 1.0, 0.0, 0.0, 0.0);
        transform = CGAffineTransformTranslate(
            transform, CGRectGetMinY(rect) - CGRectGetMinY(bounds),
            CGRectGetMinX(rect) - CGRectGetMinX(bounds));
        transform = CGAffineTransformScale(
            transform, CGRectGetHeight(rect) / CGRectGetWidth(extent),
            CGRectGetWidth(rect) / CGRectGetHeight(extent));
      } else {
        transform = CGAffineTransformMakeTranslation(
            CGRectGetMinX(rect) - CGRectGetMinX(bounds),
            CGRectGetMinY(rect) - CGRectGetMinY(bounds));
        transform = CGAffineTransformScale(
            transform, CGRectGetWidth(rect) / CGRectGetWidth(extent),
            CGRectGetHeight(rect) / CGRectGetHeight(extent));
      }
      value = [inputMaskImage imageByApplyingTransform:transform];
    } else
      continue;
    [transitionFilter setValue:value forKey:key];
  }

  return transitionFilter;
}

- (CIImage *)currentImageForRect:(NSRect)rect scale:(CGFloat *)scalePtr {
  NSRect bounds = [view bounds];
  NSBitmapImageRep *contentBitmap =
      [view bitmapImageRepCachingDisplayInRect:bounds];
  CIImage *tmpImage = [[CIImage alloc] initWithBitmapImageRep:contentBitmap];
  CGFloat scale = CGRectGetWidth([tmpImage extent]) / NSWidth(bounds);
  CIImage *image = [tmpImage
      imageByCroppingToRect:CGRectIntegral(scaleRect(
                                NSIntersectionRect(rect, bounds), scale))];
  NSArray *colorFilters = SKColorEffectFilters();
  if ([colorFilters count] > 0) {
    for (CIFilter *filter in colorFilters) {
      [filter setValue:image forKey:kCIInputImageKey];
      image = [filter outputImage];
    }
  }
  if (scalePtr)
    *scalePtr = scale;
  return image;
}

- (void)showTransitionViewForRect:(NSRect)rect
                            image:(CIImage *)image
                           extent:(CGRect)extent {
  if (transitionView == nil) {
    transitionView = [[SKMetalTransitionView alloc] init];
    [transitionView
        setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    CAAnimation *animation = [CABasicAnimation animation];
    [animation setTimingFunction:
                   [CAMediaTimingFunction
                       functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [transitionView setAnimations:@{@"progress" : animation}];
  }

  [transitionView setImage:image];
  [transitionView setExtent:extent];
  [transitionView setNeedsDisplay:YES];

  [transitionView setFrame:rect];
  [view addSubview:transitionView positioned:NSWindowAbove relativeTo:nil];
}

- (void)removeTransitionView {
  [transitionView removeFromSuperview];
  [transitionView setFilter:nil];
  [transitionView setImage:nil];
}

- (void)showTransitionWindowForRect:(NSRect)rect
                              image:(CIImage *)image
                             extent:(CGRect)extent {
  SKTransitionView *tView = (SKTransitionView *)[window contentView];
  if (window == nil) {
    tView = [[SKTransitionView alloc] init];
    window = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                         styleMask:NSWindowStyleMaskBorderless
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setIgnoresMouseEvents:YES];
    [window setBackgroundColor:[NSColor blackColor]];
    [window setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [window setContentView:tView];
  }

  [tView setImage:image];
  [tView setExtent:extent];
  [tView setNeedsDisplay:YES];

  [window setFrame:[view convertRectToScreen:rect] display:NO];
  [window orderBack:nil];
  [[view window] addChildWindow:window ordered:NSWindowAbove];
}

- (void)removeTransitionWindow {
  SKTransitionView *tView = (SKTransitionView *)[window contentView];
  [[window parentWindow] removeChildWindow:window];
  [window orderOut:nil];
  [tView setImage:nil];
}

- (void)animateForRect:(NSRect)rect
                  from:(NSUInteger)fromIndex
                    to:(NSUInteger)toIndex
                change:(NSRect (^)(void))change {
  if (animating) {
    change();
    return;
  }

  SKTransitionInfo *currentTransition = transition;
  NSUInteger idx = MIN(fromIndex, toIndex);
  if (fromIndex != NSNotFound && toIndex != NSNotFound &&
      idx < [pageTransitions count])
    currentTransition = [[SKTransitionInfo alloc]
        initWithProperties:[pageTransitions objectAtIndex:idx]];

  if ([currentTransition transitionStyle] == SKNoTransition) {

    change();

  } else if ([currentTransition transitionStyle] >= SKCoreImageTransition) {

    animating = YES;

    CIImage *initialImage = [self currentImageForRect:rect scale:NULL];

    NSRect toRect = change();

    NSRect bounds = [view bounds];
    CGFloat imageScale = 1.0;
    CIImage *finalImage = [self currentImageForRect:toRect scale:&imageScale];
    CGRect cgRect = CGRectIntegral(scaleRect(
        NSIntersectionRect(NSUnionRect(rect, toRect), bounds), imageScale));
    CGRect cgBounds = scaleRect(bounds, imageScale);
    CIFilter *transitionFilter =
        [self transitionFilterForTransition:currentTransition
                                       rect:cgRect
                                     bounds:cgBounds
                                    forward:toIndex >= fromIndex
                               initialImage:initialImage
                                 finalImage:finalImage];
    [self showTransitionViewForRect:bounds image:initialImage extent:cgBounds];

    // Update the view and its window, so it shows the correct state when it is
    // shown.
    [view display];

    [transitionView setFilter:transitionFilter];
    [NSAnimationContext
        runAnimationGroup:^(NSAnimationContext *context) {
          [context setDuration:[currentTransition duration]];
          [[transitionView animator] setProgress:1.0];
        }
        completionHandler:^{
          [self removeTransitionView];
          animating = NO;
        }];

  } else {

    animating = YES;

    NSWindow *viewWindow = [view window];
    CIImage *initialImage = nil;
    if ([currentTransition shouldRestrict])
      initialImage = [self currentImageForRect:rect scale:NULL];

    // We don't want the window to draw the next state before the animation is
    // run
    [viewWindow disableFlushWindow];

    NSRect toRect = change();

    CIImage *finalImage = nil;

    if ([currentTransition shouldRestrict]) {
      CGFloat imageScale = 1.0;

      finalImage = [self currentImageForRect:toRect scale:&imageScale];

      rect = NSIntegralRect(
          NSIntersectionRect(NSUnionRect(rect, toRect), [view bounds]));

      [self showTransitionWindowForRect:rect
                                  image:initialImage
                                 extent:scaleRect(rect, imageScale)];
    }

    // declare our variables
    int handle = -1;
    CGSTransitionSpec spec;
    // specify our specifications
    spec.unknown1 = 0;
    spec.type = (CGSTransitionType) [currentTransition transitionStyle];
    spec.option = toIndex >= fromIndex ? CGSLeft : CGSRight;
    spec.backColour = NULL;
    spec.wid = (CGSWindow) [([currentTransition shouldRestrict] ? window
                                                    : viewWindow) windowNumber];

    // Let's get a connection
    CGSConnection cgs = _CGSDefaultConnection_func();

    // Create a transition
    CGSNewTransition_func(cgs, &spec, &handle);

    if ([currentTransition shouldRestrict]) {
      [(SKTransitionView *)[window contentView] setImage:finalImage];
      [[window contentView] display];
    }

    // Redraw the window
    [viewWindow display];
    // Remember we disabled flushing in the previous method, we need to balance
    // that.
    [viewWindow enableFlushWindow];
    [viewWindow flushWindow];

    CGSInvokeTransition_func(cgs, handle, [currentTransition duration]);

    DISPATCH_MAIN_AFTER_SEC([currentTransition duration], ^{
      CGSReleaseTransition_func(cgs, handle);

      if ([currentTransition shouldRestrict])
        [self removeTransitionWindow];

      animating = NO;
    });
  }
}

@end

#pragma mark -

@implementation SKTransitionView

@synthesize image, extent, filter;
@dynamic progress;

- (BOOL)isOpaque {
  return YES;
}

- (CGFloat)progress {
  NSNumber *number = [filter valueForKey:kCIInputTimeKey];
  return number ? [number doubleValue] : 0.0;
}

- (void)setProgress:(CGFloat)newProgress {
  if (filter) {
    [filter setValue:[NSNumber numberWithDouble:newProgress]
              forKey:kCIInputTimeKey];
    [self setImage:[filter outputImage]];
    [self setNeedsDisplay:YES];
  }
}

- (void)drawRect:(NSRect)rect {
  [[NSColor blackColor] setFill];
  NSRectFill(rect);
  [image drawInRect:[self bounds]
           fromRect:extent
          operation:NSCompositingOperationSourceOver
           fraction:1.0];
}

@end

#pragma mark -

@implementation SKMetalTransitionView

@synthesize image, extent, filter;
@dynamic progress;

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self && [MTKView class]) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    metalView = [[MTKView alloc] initWithFrame:[self bounds] device:device];
    [metalView setFramebufferOnly:NO];
    [metalView setEnableSetNeedsDisplay:YES];
    [metalView setPaused:YES];
    [metalView setClearColor:MTLClearColorMake(0.0, 0.0, 0.0, 1.0)];
    [metalView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [metalView setDelegate:self];
    [self addSubview:metalView];
    commandQueue = [device newCommandQueue];
    context = [CIContext contextWithMTLDevice:device];
  }
  return self;
}

- (CGFloat)progress {
  NSNumber *number = [filter valueForKey:kCIInputTimeKey];
  return number ? [number doubleValue] : 0.0;
}

- (void)setProgress:(CGFloat)newProgress {
  if (filter) {
    [filter setValue:[NSNumber numberWithDouble:newProgress]
              forKey:kCIInputTimeKey];
    image = [filter outputImage];
    if ([metalView alphaValue] <= 0.0) {
      [self setNeedsDisplay:YES];
      [metalView setAlphaValue:1.0];
    }
    [metalView setNeedsDisplay:YES];
  }
}

- (void)setImage:(CIImage *)newImage {
  if (newImage != image) {
    image = newImage;
    [metalView setAlphaValue:0.0];
    [metalView setNeedsDisplay:YES];
  }
}

- (void)drawInMTKView:(MTKView *)view {
  if (image == nil)
    return;

  id<CAMetalDrawable> drawable = [view currentDrawable];
  id<MTLCommandBuffer> commandBuffer =
      [commandQueue commandBufferWithUnretainedReferences];
  id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer
      renderCommandEncoderWithDescriptor:[view currentRenderPassDescriptor]];

  [commandEncoder endEncoding];

  CGRect bounds = {CGPointZero, [view drawableSize]};
  CIImage *img = image;
  CGColorSpaceRef cs = [image colorSpace] ?: [(CIImage *)[filter valueForKey:kCIInputImageKey] colorSpace] ?: (CGColorSpaceRef)CFAutorelease(CGColorSpaceCreateDeviceRGB());

  if (CGRectEqualToRect(extent, bounds) == NO) {
    CGAffineTransform t = CGAffineTransformMakeScale(
        CGRectGetWidth(bounds) / CGRectGetWidth(extent),
        CGRectGetHeight(bounds) / CGRectGetHeight(extent));
    t = CGAffineTransformTranslate(t, -CGRectGetMinX(extent),
                                   -CGRectGetMinY(extent));
    img = [image imageByApplyingTransform:t];
  }

  [context render:img
       toMTLTexture:[drawable texture]
      commandBuffer:commandBuffer
             bounds:bounds
         colorSpace:cs];

  [commandBuffer presentDrawable:drawable];
  [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

- (void)drawRect:(NSRect)rect {
  if ([metalView alphaValue] <= 0.0) {
    [[NSColor blackColor] setFill];
    NSRectFill(rect);
    [image drawInRect:[self bounds]
             fromRect:extent
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
  }
}

@end
