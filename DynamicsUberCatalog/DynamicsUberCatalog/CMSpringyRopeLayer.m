//
//  CMSpringyRopeLayer.m
//  DynamicsUberCatalog
//
//  Created by Chris Miles on 30/09/13.
//  Copyright (c) 2013 Chris Miles. All rights reserved.
//
//  Based on CMTraerPhysics demo by Chris Miles, https://github.com/chrismiles/CMTraerPhysics
//  Based on traerAS3 example by Arnaud Icard, https://github.com/sqrtof5/traerAS3
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
//

#import "CMSpringyRopeLayer.h"
#import "CMSpringyRopeParticle.h"
#import "CMSpringyRopeSmoothedPath.h"
@import CoreMotion;

#import <DynamicsXRay/DynamicsXRay.h>


/*
    Physics Configuration
 */
static CGFloat const CMSpringyRopeDamping = 1.0f;
static CGFloat const CMSpringyRopeFrequency = 5.0f;
static CGFloat const CMSpringyRopeParticleDensity = 0.5f;
static CGFloat const CMSpringyRopeParticleResistance = 0.5f;

/*
    Visual Configuration
 */
static CGFloat const CMSpringyRopeLayerHandleRadius = 5.0f;


/*
    Utility Functions
 */
static CGFloat CGPointDistance(CGPoint userPosition, CGPoint prevPosition)
{
    CGFloat dx = prevPosition.x - userPosition.x;
    CGFloat dy = prevPosition.y - userPosition.y;
    return sqrtf(dx*dx + dy*dy);
}


/*
    CMSpringyRopeLayer
 */
@interface CMSpringyRopeLayer ()

@property (assign, nonatomic) float spring_length;
@property (assign, nonatomic) NSUInteger subdivisions;

@property (assign, nonatomic) BOOL isDragging;
@property (assign, nonatomic) CGSize lastSize;

@property (assign, nonatomic) float gravityScale;
@property (strong, nonatomic) CMMotionManager *motionManager;

// Physics
@property (strong, nonatomic) UIDynamicAnimator *animator;
@property (strong, nonatomic) UIGravityBehavior *gravityBehavior;
@property (strong, nonatomic) NSArray *particles;
@property (strong, nonatomic) UIAttachmentBehavior *anchorSpringBehavior;
@property (strong, nonatomic) CMSpringyRopeParticle *handleParticle;
@property (strong, nonatomic) UIAttachmentBehavior *handleSpringBehavior;
@property (strong, nonatomic) UIDynamicItemBehavior *particleBehavior;

// FPS
@property (assign, nonatomic) double fps_prev_time;
@property (assign, nonatomic) NSUInteger fps_count;

@end


@implementation CMSpringyRopeLayer

- (id)init
{
    self = [super init];
    if (self) {
	self.contentsScale = [UIScreen mainScreen].scale;
	
	_lastSize = self.bounds.size;
	
	_spring_length = 25.0;
	_subdivisions = 8;
	
	_motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 0.02; // 50 Hz
	
	_animator = [[UIDynamicAnimator alloc] init];
	_gravityBehavior = [[UIGravityBehavior alloc] initWithItems:nil];
	_gravityBehavior.gravityDirection = CGVectorMake(0, 1.0f);
	
	__weak CMSpringyRopeLayer *weakSelf = self;
	_gravityBehavior.action = ^{
	    __strong CMSpringyRopeLayer *strongSelf = weakSelf;
	    [strongSelf drawFrame];
	};
	[_animator addBehavior:_gravityBehavior];
	
	_particleBehavior = [[UIDynamicItemBehavior alloc] initWithItems:nil];
	_particleBehavior.density = CMSpringyRopeParticleDensity;
	_particleBehavior.resistance = CMSpringyRopeParticleResistance;
	
	[_animator addBehavior:_particleBehavior];

	/*
	    Dynamics Xray
	 */
	DynamicsXRay *xray = [[DynamicsXRay alloc] init];
	[_animator addBehavior:xray];
    }
    return self;
}

- (void)layoutSublayers
{
    [super layoutSublayers];
    
    if (self.particles == nil) [self generateParticles];
}


#pragma mark - Set Up Physics

- (void)generateParticles
{
    NSMutableArray *particles = [NSMutableArray array];
    
    CGPoint anchorPoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetHeight(self.bounds)*0.2f);
    
    NSUInteger subdivisions = self.subdivisions;
    
    float sub_len = self.spring_length / subdivisions;
    for (NSUInteger i=1; i<=subdivisions; i++) {
	CMSpringyRopeParticle *p = [[CMSpringyRopeParticle alloc] initWithCenterPosition:CGPointMake(anchorPoint.x, anchorPoint.y + i*sub_len)];
	[particles addObject:p];
	
	[self.particleBehavior addItem:p];
	[self.gravityBehavior addItem:p];
    }
    
    self.handleParticle = [particles lastObject];
    NSUInteger particlesMaxIndex = [particles count] - 1;
    
    for (NSUInteger i=0; i<particlesMaxIndex; i++)  {
	if (i == 0) {
	    UIAttachmentBehavior *anchorSpringBehavior = [[UIAttachmentBehavior alloc] initWithItem:particles[i] attachedToAnchor:anchorPoint];
	    anchorSpringBehavior.length = sub_len;
	    anchorSpringBehavior.frequency = CMSpringyRopeFrequency;
	    anchorSpringBehavior.damping = CMSpringyRopeDamping;
	    [self.animator addBehavior:anchorSpringBehavior];
	    self.anchorSpringBehavior = anchorSpringBehavior;
	}
	
	UIAttachmentBehavior *springBehavior = [[UIAttachmentBehavior alloc] initWithItem:particles[i] attachedToItem:particles[i+1]];
	springBehavior.length = sub_len;
	springBehavior.frequency = CMSpringyRopeFrequency;
	springBehavior.damping = CMSpringyRopeDamping;
	[self.animator addBehavior:springBehavior];
	
	if (i == particlesMaxIndex - 1) {
	    self.handleSpringBehavior = springBehavior;
	}
    }
    
    self.particles = particles;
}



#pragma mark - Custom property accessors

- (BOOL)isDeviceMotionAvailable
{
    return self.motionManager.isDeviceMotionAvailable;
}

- (void)setGravityByDeviceMotionEnabled:(BOOL)gravityByDeviceMotionEnabled
{
    if (gravityByDeviceMotionEnabled) {
        if ([self.motionManager isDeviceMotionAvailable]) {
            [self.motionManager startDeviceMotionUpdates];
        }
    }
    else {
        if ([self.motionManager isDeviceMotionActive]) {
            [self.motionManager stopDeviceMotionUpdates];
        }
    }
}

- (BOOL)gravityByDeviceMotionEnabled
{
    return [self.motionManager isDeviceMotionActive];
}


#pragma mark - Handle touches

- (void)touchBeganAtLocation:(CGPoint)location
{
    if (CGPointDistance(location, self.handleParticle.center) <= 40.0f) {
	[self moveHandleToLocation:location];
	self.isDragging = YES;
    }
}

- (void)touchMovedAtLocation:(CGPoint)location
{
    if (self.isDragging) {
	[self moveHandleToLocation:location];
    }
}

- (void)touchEndedAtLocation:(CGPoint)location
{
    if (self.isDragging) {
	[self moveHandleToLocation:location];
	self.isDragging = NO;
    }
}

- (void)touchCancelledAtLocation:(__unused CGPoint)location
{
    if (self.isDragging) {
	self.isDragging = NO;
    }
}


#pragma mark - Dragging

- (void)setIsDragging:(BOOL)isDragging
{
    if (isDragging != _isDragging) {
	[self updateDynamicsWithHandleParticleDragging:isDragging];
	
	_isDragging = isDragging;
    }
}

- (void)updateDynamicsWithHandleParticleDragging:(BOOL)isDragging
{
    [self.animator removeBehavior:self.handleSpringBehavior];
    
    NSUInteger particlesMaxIndex = [self.particles count] - 1;
    float sub_len = self.spring_length / self.subdivisions;
    
    UIAttachmentBehavior *springBehavior;
    
    if (isDragging) {
	// Create item<->anchor spring behavior
	
	springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.particles[particlesMaxIndex-1]
						   attachedToAnchor:self.handleParticle.center];
	
	[self.gravityBehavior removeItem:self.handleParticle];
	[self.particleBehavior removeItem:self.handleParticle];
    }
    else {
	// Create item<->item spring behavior
	
	[self.animator updateItemUsingCurrentState:self.handleParticle];
	
	springBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.particles[particlesMaxIndex-1]
						     attachedToItem:self.handleParticle];
	
	[self.gravityBehavior addItem:self.handleParticle];
	[self.particleBehavior addItem:self.handleParticle];
    }
    
    springBehavior.length = sub_len;
    springBehavior.frequency = CMSpringyRopeFrequency;
    springBehavior.damping = CMSpringyRopeDamping;
    [self.animator addBehavior:springBehavior];
    self.handleSpringBehavior = springBehavior;
}


#pragma mark - Move Handle

- (void)moveHandleToLocation:(CGPoint)location
{
    self.handleParticle.center = location;
    self.handleSpringBehavior.anchorPoint = location;
    
    [self.animator updateItemUsingCurrentState:self.handleParticle];
}


#pragma mark - Draw Frame

- (void)drawFrame
{
    if (self.motionManager.isDeviceMotionActive) {
        CMAcceleration gravity = self.motionManager.deviceMotion.gravity;
	CGVector gravityVector = CGVectorMake((float)(gravity.x) * self.gravityScale, (float)(-gravity.y) * self.gravityScale);
	self.gravityBehavior.gravityDirection = gravityVector;
    }
    
    [self setNeedsDisplay];      // draw layer
    
    /* FPS */
    if (self.fpsLabel) {
	double curr_time = CACurrentMediaTime();
	if (curr_time - self.fps_prev_time >= 0.2) {
	    double delta = (curr_time - self.fps_prev_time) / self.fps_count;
	    self.fpsLabel.text = [NSString stringWithFormat:@"%0.0f fps", 1.0/delta];
	    self.fps_prev_time = curr_time;
	    self.fps_count = 1;
	}
	else {
	    self.fps_count++;
	}
    }
}


#pragma mark - CALayer methods

- (void)drawInContext:(CGContextRef)ctx
{
    if (!CGSizeEqualToSize(self.bounds.size, self.lastSize)) {
	self.gravityScale = 1.0f * CGRectGetHeight(self.frame) / 320.0f;
        self.lastSize = self.bounds.size;
    }

    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPoint anchorPoint = self.anchorSpringBehavior.anchorPoint;
    CGPathMoveToPoint(path, NULL, anchorPoint.x, anchorPoint.y);
    for (NSUInteger i=0; i<[self.particles count]; i++) {
	CMSpringyRopeParticle *p = [self.particles objectAtIndex:i];
	CGPathAddLineToPoint(path, NULL, p.center.x, p.center.y);
    }
    
    UIGraphicsPushContext(ctx);
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithCGPath:path];
    if (self.smoothed) {
	bezierPath = smoothedPath(bezierPath, 8);
    }
    //    [bezierPath stroke]; // CMDEBUGGING disabled stroke
    UIGraphicsPopContext();
    
    CGPathRelease(path);
    
    // Draw handle
    CGPoint handlePoint = self.handleParticle.center;
    CGContextAddEllipseInRect(ctx, CGRectMake(handlePoint.x-CMSpringyRopeLayerHandleRadius, handlePoint.y-CMSpringyRopeLayerHandleRadius, CMSpringyRopeLayerHandleRadius*2, CMSpringyRopeLayerHandleRadius*2));
    CGContextStrokePath(ctx);
}

@end
