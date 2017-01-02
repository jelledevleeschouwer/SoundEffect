//
//  ViewController.swift
//  SoundEffect
//
//  Created by Jelle De Vleeschouwer on 12/12/2016.
//  Copyright © 2016 Jelle De Vleeschouwer. All rights reserved.
//
#ifndef __INCLUDE_FIRFILTER_H_
#define __INCLUDE_FIRFILTER_H_

#include <vector>
#include <array>

using namespace std;

class FIRFilter
{
private:
    vector<float> buffer;
    vector<float> filter;
    vector<float> output;
    uint32_t frame_size;
    uint32_t bitmask;
    uint32_t writes;
    
public:
    
    //
    // Constructor
    //
    FIRFilter(uint32_t frame_size, uint32_t filter_size, const float *_filter);
    
    //
    // Set coefficients
    //
    int setCoefficients(uint32_t filter_size, const float *_filter);
    
    //
    // Convolve a frame of size 'frame_size' with the filter-coefficients and return the result
    // in a float-vector.
    //
    int process(const vector<float> frame);
    
    //
    // Get output vector after processing frame
    //
    const vector<float> getOutput(void);
};

#endif /* __INCLUDE_FIRFILTER_H_ */
