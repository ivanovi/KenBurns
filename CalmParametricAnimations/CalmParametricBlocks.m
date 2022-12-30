#import "CalmParametricBlocks.h"

@implementation CalmParametricBlocks

#pragma mark - bezier helpers

double bezier(double time, double A, double B, double C) {
    return time * (C + time * (B + time * A)); //A t^3 + B t^2 + C t
}

double bezier_der(double time, double A, double B, double C) {
    return C + time * (2 * B + time * 3 * A); //3 A t^2 + 2 B t + C
}

double xForTime(double time, double ctx1, double ctx2) {
    double x = time, z;

    double C = 3 * ctx1;
    double B = 3 * (ctx2 - ctx1) - C;
    double A = 1 - C - B;

    NSInteger i = 0;
    while (i < 5) {
        z = bezier(x, A, B, C) - time;
        if (fabs(z) < 0.001) {
            break;
        }

        x = x - z / bezier_der(x, A, B, C);
        i++;
    }

    return x;
}

const double (^kParametricAnimationBezierEvaluator)(double, CGPoint, CGPoint) = ^(double time, CGPoint ct1, CGPoint ct2) {
    double Cy = 3 * ct1.y;
    double By = 3 * (ct2.y - ct1.y) - Cy;
    double Ay = 1 - Cy - By;

    return bezier(xForTime(time, ct1.x, ct2.x), Ay, By, Cy);
};


#pragma mark - time blocks

const ParametricTimeBlock kParametricTimeBlockLinear = ^(double time) {
    return time;
};

const ParametricTimeBlock kParametricTimeBlockAppleIn = ^(double time) {
    CGPoint ct1 = CGPointMake(0.42, 0.0), ct2 = CGPointMake(1.0, 1.0);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};
const ParametricTimeBlock kParametricTimeBlockAppleOut = ^(double time) {
    CGPoint ct1 = CGPointMake(0.0, 0.0), ct2 = CGPointMake(0.58, 1.0);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockAppleInOut = ^(double time) {
    CGPoint ct1 = CGPointMake(0.42, 0.0), ct2 = CGPointMake(0.58, 1.0);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockEaseOutDramatic = ^(double time) {
    CGPoint ct1 = CGPointMake(0.2, 0.7), ct2 = CGPointMake(0.2, 1.0);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockBackIn = ^(double time) {
    CGPoint ct1 = CGPointMake(0.6, -0.28), ct2 = CGPointMake(0.735, 0.045);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockEaseInBackOut = ^(double time) {
    CGPoint ct1 = CGPointMake(0.43, 0.095), ct2 = CGPointMake(0.375, 1.23);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockBackOut = ^(double time) {
    CGPoint ct1 = CGPointMake(0.175, 0.885), ct2 = CGPointMake(0.32, 1.275);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockBackInOut = ^(double time) {
    CGPoint ct1 = CGPointMake(0.68, -0.55), ct2 = CGPointMake(0.265, 1.55);
    return kParametricAnimationBezierEvaluator(time, ct1, ct2);
};

const ParametricTimeBlock kParametricTimeBlockQuadraticIn = ^(double time) {
    return pow(time, 2);
};

const ParametricTimeBlock kParametricTimeBlockQuadraticOut = ^(double time) {
    return 1 - pow(1 - time, 2);
};

const ParametricTimeBlock kParametricTimeBlockCubicIn = ^(double time) {
    return pow(time, 3);
};

const ParametricTimeBlock kParametricTimeBlockCubicOut = ^(double time) {
    return pow(time, 3);
};

const ParametricTimeBlock kParametricTimeBlockCubicInOut = ^(double time) {
    time *= 2.0;
    if (time < 1) {
        return 0.5 * pow(time, 3);
    }

    time -= 2;
    return 0.5 * pow(time, 3) + 1;
};

const ParametricTimeBlock kParametricTimeBlockExpoIn = ^(double time) {
    if (time == 0.0) {
        return 0.0;
    }
    return pow(2, 10 * (time - 1));
};

const ParametricTimeBlock kParametricTimeBlockExpoOut = ^(double time) {
    if (time == 1.0) {
        return 1.0;
    }
    return -pow(2, -10 * time) + 1;
};

const ParametricTimeBlock kParametricTimeBlockExpoInOut = ^(double time) {
    if (time == 0) {
        return 0.0;
    }
    if (time == 1) {
        return 1.0;
    }
    time *= 2;
    if (time < 1) {
        return 0.5 * pow(2, 10 * (time - 1));
    }
    --time;
    return 0.5 * (-pow(2, -10 * time) + 2);
};

const ParametricTimeBlock kParametricTimeBlockCircularIn = ^(double time) {
    return 1 - sqrt(1 - time * time);
};

const ParametricTimeBlock kParametricTimeBlockCircularOut = ^(double time) {
    return sqrt(1 - pow(time - 1, 2));
};

const ParametricTimeBlock kParametricTimeBlockSineIn = ^(double time) {
    return -cos(time * M_PI / 2) + 1;
};

const ParametricTimeBlock kParametricTimeBlockSineOut = ^(double time) {
    return -cos(time * M_PI / 2) + 1;
};

const ParametricTimeBlock kParametricTimeBlockSineInOut = ^(double time) {
    return -0.5 * cos(time * M_PI) + 0.5;
};

const ParametricTimeBlock kParametricTimeBlockSquashedSineInOut = ^(double time) {
    double squashFactor = 0.75;
    return squashFactor * (-0.5 * cos(time * M_PI) + 0.5) + 0.5 * squashFactor;
};

#define kDefaultElasticPeriod 0.3
#define kMutedElasticPeriod 0.5
#define kDefaultElasticAmplitude 1.0
#define kDefaultElasticShiftRatio 0.25
const ParametricTimeBlock kParametricTimeBlockElasticIn = ^(double time) {
    if (time <= 0.0) {
        return 0.0;
    }
    if (time >= 1.0) {
        return 1.0;
    }
    double period = kDefaultElasticPeriod;
    double amplitude = kDefaultElasticAmplitude;
    double shift = period * kDefaultElasticShiftRatio;

    double result = -amplitude * pow(2, 10 * (time - 1)) * // amplitude growth
    sin((time - 1 - shift) * 2 * M_PI / period);

    return result;
};

const ParametricTimeBlock kParametricTimeBlockElasticOut = ^(double time) {
    return kParametricTimeBlockVariableElasticOut(kDefaultElasticPeriod)(time);
};

const ParametricTimeBlock (^kParametricTimeBlockVariableElasticOut)(double) = ^(double inverseIntensity) {
    ParametricTimeBlock elasticOut = ^(double time) {
        if (time <= 0.0) {
            return 0.0;
        }
        if (time >= 1.0) {
            return 1.0;
        }
        double period = inverseIntensity;
        double amplitude = kDefaultElasticAmplitude;
        double shift = period * kDefaultElasticShiftRatio;

        double result = amplitude * pow(2, -10 * time) * // amplitude decay
        sin((time - shift) * 2 * M_PI / period) + 1;

        return result;
    };
    return elasticOut;
};

+ (ParametricTimeBlock)elasticParametricTimeBlockWithEaseIn:(BOOL)easeIn
                                                     period:(double)period
                                                  amplitude:(double)amplitude
{
    return [self elasticParametricTimeBlockWithEaseIn:easeIn
                                               period:period
                                            amplitude:amplitude
                                        andShiftRatio:kDefaultElasticShiftRatio];
}

+ (ParametricTimeBlock)elasticParametricTimeBlockWithEaseIn:(BOOL)easeIn
                                                     period:(double)period
                                                  amplitude:(double)amplitude
                                                    bounded:(BOOL)bounded
{
    return [self elasticParametricTimeBlockWithEaseIn:easeIn
                                               period:period
                                            amplitude:amplitude
                                        andShiftRatio:kDefaultElasticShiftRatio
                                              bounded:bounded];
}

+ (ParametricTimeBlock)elasticParametricTimeBlockWithEaseIn:(BOOL)easeIn
                                                     period:(double)period
                                                  amplitude:(double)amplitude
                                              andShiftRatio:(double)shiftRatio
{
    return [self elasticParametricTimeBlockWithEaseIn:easeIn
                                               period:period
                                            amplitude:amplitude
                                        andShiftRatio:shiftRatio
                                              bounded:NO];
}

+ (ParametricTimeBlock)elasticParametricTimeBlockWithEaseIn:(BOOL)easeIn
                                                     period:(double)period
                                                  amplitude:(double)amplitude
                                              andShiftRatio:(double)shiftRatio
                                                    bounded:(BOOL)bounded
{
    ParametricTimeBlock elasticBlock = ^(double time) {
        if (time <= 0) {
            return 0.0;
        }
        if (time >= 1) {
            return 1.0;
        }
        double shift = period * shiftRatio;

        double result;
        if (easeIn) { // amplitude growth
            result = -amplitude * pow(2, 10 * (time - 1)) * sin((time - 1 - shift) * 2 * M_PI / period);
        } else { // amplitude decay
            result = amplitude * pow(2, -10 * time) * sin((time - shift) * 2 * M_PI / period) + 1;
        }

        return bounded ? MAX(0.0, MIN(1.0, result)) : result;
    };

    return [elasticBlock copy];
}


#pragma mark - value blocks

const ParametricValueBlock kParametricValueBlockDouble = ^(double progress, id fromValue, id toValue) {
    NSValue *value;
    double from, to;
    [fromValue getValue:&from];
    [toValue getValue:&to];
    value = @(from + (to - from) * progress);
    return value;
};

@end
