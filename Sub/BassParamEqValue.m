//
//  EqualizerValue.m
//  Anghami
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "BassParamEqValue.h"

@implementation BassParamEqValue

- (id)initWithParameters:(BASS_DX8_PARAMEQ)params handle:(HFX)theHandle arrayIndex:(NSUInteger)index
{
	if ((self = [super init]))
	{
		_parameters = params;
		_handle = theHandle;
		_arrayIndex = index;
	}
	
	return self;
}

+ (BassParamEqValue *)valueWithParams:(BASS_DX8_PARAMEQ)params handle:(HFX)theHandle arrayIndex:(NSUInteger)index
{
	return [[BassParamEqValue alloc] initWithParameters:params handle:theHandle arrayIndex:index];
}

- (id)initWithParameters:(BASS_DX8_PARAMEQ)params
{
	return [self initWithParameters:params handle:0 arrayIndex:NSUIntegerMax];
}

+ (BassParamEqValue *)valueWithParams:(BASS_DX8_PARAMEQ)params
{
	return [[BassParamEqValue alloc] initWithParameters:params handle:0 arrayIndex:NSUIntegerMax];
}

- (id)initWithParameters:(BASS_DX8_PARAMEQ)params arrayIndex:(NSUInteger)index
{
	return [self initWithParameters:params handle:0 arrayIndex:index];
}

+ (BassParamEqValue *)valueWithParams:(BASS_DX8_PARAMEQ)params arrayIndex:(NSUInteger)index
{
	return [[BassParamEqValue alloc] initWithParameters:params handle:0 arrayIndex:index];
}

- (float)frequency
{
	return _parameters.fCenter;
}

- (void)setFrequency:(float)frequency
{
	_parameters.fCenter = frequency;
}

- (float)gain
{
	return _parameters.fGain;
}

- (void)setGain:(float)gain
{
	_parameters.fGain = gain;
}

- (float)bandwidth
{
	return _parameters.fBandwidth;
}

- (void)setBandwidth:(float)bandwidth
{
	_parameters.fBandwidth = bandwidth;
}

BASS_DX8_PARAMEQ BASS_DX8_PARAMEQMake(float center, float gain, float bandwidth)
{
	BASS_DX8_PARAMEQ p;
	p.fCenter = center;
	p.fGain = gain;
	p.fBandwidth = bandwidth;
	
	return p;
}

BASS_DX8_PARAMEQ BASS_DX8_PARAMEQFromPoint(float percentX, float percentY, float bandwidth)
{	
	BASS_DX8_PARAMEQ p;
	p.fCenter = exp2f((percentX * RANGE_OF_EXPONENTS) + 5);
	p.fGain = (.5 - percentY) * (CGFloat)(MAX_GAIN * 2);;
	p.fBandwidth = bandwidth;
	
	return p;
}

- (NSUInteger)hash
{
    return (int)fabsf(self.parameters.fCenter) + (int)fabsf(self.parameters.fGain) + (int)fabsf(self.parameters.fBandwidth) + self.handle;
}

- (BOOL)isEqualToBassParamEqValue:(BassParamEqValue *)otherValue
{
	if (self == otherValue)
        return YES;
	
	if (self.parameters.fCenter == otherValue.parameters.fCenter &&
		self.parameters.fGain == otherValue.parameters.fGain &&
		self.parameters.fBandwidth == otherValue.parameters.fBandwidth &&
		self.handle == otherValue.handle)
		return YES;
	
	return NO;
}

- (BOOL)isEqual:(id)other
{
	if (other == self)
        return YES;
	
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
	
    return [self isEqualToBassParamEqValue:other];
}

@end
