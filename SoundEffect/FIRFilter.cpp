//
//  ViewController.swift
//  SoundEffect
//
//  Created by Jelle De Vleeschouwer on 12/12/2016.
//  Copyright © 2016 Jelle De Vleeschouwer. All rights reserved.
//
#include <iostream>
#include <mutex>
#include "FIRFilter.h"

static mutex mtx;

//===-----------------------------------------------------------------===//
// Class implementation
//===-----------------------------------------------------------------===//

//
// Constructor
//
FIRFilter::FIRFilter(uint32_t frame_size, uint32_t filter_size, const float *_filter)
{
    filter.resize(filter_size);
    output.resize(frame_size);
    this->frame_size = (uint32_t)output.size();

    // Result of convolution is M + N - 1, where M is the size of the frame and N is the
    // size of order of the filter
    buffer.resize(output.size() + filter.size() - 1);

    // Copy filter-coefficients
    filter.assign(_filter, _filter + filter.size());

    cout << "Created FIR filter with M: " << output.size() << " N: " << filter.size() << endl;
}

//
// Update the coefficients
//
int
FIRFilter::setCoefficients(uint32_t filter_size, const float *_filter)
{
    if (!_filter)
        return -1;
    
    // Enter atomic section
    mtx.lock();
    
    filter.resize(filter_size);
    output.resize(frame_size);
    this->frame_size = (uint32_t)output.size();
    
    // Result of convolution is M + N - 1, where M is the size of the frame and N is the
    // size of order of the filter
    buffer.resize(output.size() + filter.size() - 1);
    
    // Copy filter-coefficients
    filter.assign(_filter, _filter + filter.size());
    
    // Leave atomic section
    mtx.unlock();
    
    return 0;
}

//
// Convolve a frame of size 'frame_size' with the filter-coefficients and return the result
// in a float-vector.
//
int
FIRFilter::process(const vector<float> frame)
{
    int i = 0, j = 0, start = (uint32_t)filter.size() - 1;
    uint32_t frame_size = (uint32_t)output.size();

    // Check whether or not passed fram is of same size as was set in the constructor, bail out if not
    if (frame.size() != frame_size) {
        cout << "frame.size() [" << frame.size() <<  "] != filter.frame_size [" << frame_size << "]" << endl;
        return -1;
    }

    // Enter atomic section
    mtx.lock();
    
    for (i = 0; i < frame_size; i++) {
        // Clear out output-buffer
        output.at(i) = 0;
        
        // Move latest filter.size() amount of samples at the beginning of buffer
        if (i < start)
            buffer.at(i) = buffer.at(i + frame_size);
        
        // Fill in newly retrieved samples in buffer
        buffer.at(i + start) = frame.at(i);
    }

    for (i = 0; i < frame_size; i++) {
        for (j = 0; j < filter.size(); j++) {
            int idx = start + (i - j);
            output.at(i) += buffer.at(idx) * filter.at(j);
        }
    }
    
    // Leave atomic section
    mtx.unlock();

    return 0;
}

//
// Gets the output buffer after a FIRFilter frame processing operation
//
const vector<float>
FIRFilter::getOutput(void)
{
    // Enter atomic section
    mtx.lock();
    
    vector<float> tmp = output;
    
    // Leave atomix section
    mtx.unlock();
    
    return tmp;
}

//===-----------------------------------------------------------------===//
//===-----------------------------------------------------------------===//
