//
//  FIRFilterObjC.h
//  SoundEffect
//
//  Created by Jelle De Vleeschouwer on 28/12/2016.
//  Copyright © 2016 Jelle De Vleeschouwer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FIRFilterObjC : NSObject

//
// Constructor of the wrapper object
//
- (id) initWithFrameSize:(uint32_t)frame_size withFilter:(NSArray *)filter_c;

//
// Set coefficients
//
- (int) updateFilter:(NSArray *)filter_c;

//
// Convolve a frame of size 'frame_size' with the filter-coefficients and return the result
// in a float-vector.
//
- (int) processFrame:(float *)frame ofSize:(uint32_t)size;

//
// Get output vector after processing frame
//
- (float *) getOutput;

//
// Free the output buffer
//
- (void) freeOutput:(float *)ptr;

@end
