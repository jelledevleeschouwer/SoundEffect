//
//  FIRFilterObjC.m
//  SoundEffect
//
//  Created by Jelle De Vleeschouwer on 28/12/2016.
//  Copyright © 2016 Jelle De Vleeschouwer. All rights reserved.
//

#import "FIRFilterObjC.h"
#import "FIRFilter.h"
#import <iostream>

//===-----------------------------------------------------------------===//
// Class extension
//===-----------------------------------------------------------------===//
@interface FIRFilterObjC ()

    //
    // Declare extra methods and properties here...
    //

@end

//===-----------------------------------------------------------------===//
// Class implementation
//===-----------------------------------------------------------------===//
@implementation FIRFilterObjC { // ivar block
    
    //
    // Wrapper variable for the C++ class
    //
    FIRFilter *filter;
    
}

//
// Initialises the C++ FIRFilter object with a
//
- (id) initWithFrameSize:(uint32_t)frame_size withFilter:(NSArray *)filter_c
{
    self = [super init];
    if (self) {
        float *filter_cf = (float *)malloc(sizeof(float) * [filter_c count]);
        if (filter_cf) {
            for (int i = 0; i < [filter_c count]; i++) {
                filter_cf[i] = [[filter_c objectAtIndex:i] floatValue];
            }
            filter = new FIRFilter(frame_size, (uint32_t)[filter_c count], filter_cf);
            free(filter_cf);
            if (!filter) {
                self = nil;
            }
        } else {
            self = nil;
        }
    }
    return self;
}

//
// Updates the filter coefficients of the FIRFilter
//
- (int) updateFilter:(NSArray *)filter_c
{
    if (!filter)
        return -1;
    
    float *filter_cf = (float *)malloc(sizeof(float) * [filter_c count]);
    
    if (filter_cf) {
        for (int i = 0; i < [filter_c count]; i++) {
            filter_cf[i] = [[filter_c objectAtIndex:i] floatValue];
        }
        int ret = filter->setCoefficients((uint32_t)[filter_c count], filter_cf);
        free(filter_cf);
        return ret;
    } else {
        return -1;
    }
}

//
// Add a new frame to the circular buffer and convolve it with the filter-
// coefficients
//
- (int) processFrame:(float *)frame ofSize:(uint32_t)size
{
    vector<float> frame_f;
    
    if (!filter)
        return -1;
    frame_f.resize(size);
    
    for (int i = 0; i < size; i++) {
        frame_f.at(i) = frame[i];
    }
    
    return filter->process(frame_f);
}

- (float *) getOutput
{
    vector<float> output = filter->getOutput();
    float *out_array = (float *)malloc(sizeof(float) * output.size());
    if (!out_array) {
        return NULL;
    }
    for (int i = 0; i < output.size(); i++) {
        out_array[i] = output.at(i);
    }
    return out_array;
}

- (void) freeOutput:(float *)ptr
{
    free(ptr);
}

@end

//===-EOF-------------------------------------------------------------===//
//===-----------------------------------------------------------------===//
