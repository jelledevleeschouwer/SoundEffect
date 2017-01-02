//
//  FilterDesign.swift
//  SoundEffect
//
//  Created by Jelle De Vleeschouwer on 30/12/2016.
//  Copyright © 2016 Jelle De Vleeschouwer. All rights reserved.
//

import UIKit

class FilterDesign: NSObject {
    
    //
    // @brief Calculates time-domain coefficients to convolve the frames
    //        with. Based on the procedure described in 'Quick & Dirty
    //        FIR filter generation' on:
    //        http://www.nicholson.com/rhn/dsp.html#2
    //
    // @param fc    Center-frequency (Hz) around which the filter should be tuned
    //              0               - Specifies a Low-Pass Filter
    //              fs/2            - Specifies a High-Pass Filter
    //              0 < fc < fs/2   - Specifies a Band-Pass Filter
    // @param bw    Cutoff-frequency (Hz) for LPF and HPF
    //              1 half of the -3dB passband
    // @param n     Amount of filter-taps of the FIR filter
    // @param fs    Sampling frequency of the FIR-filter design
    //
    class func designFilter(fc: Float, bw: Float, n: Int, fs: Float) -> [Float]
    {
        var filter = [Float](repeating: 0.0, count: n) // That's how we initialize an array in Swift -_-
        var ys, yw, yf: Float
        
        if (0 == fc) {
            print("Creating a LPF with cut-off: \(bw)");
        } else if (fc == (fs / 2)) {
            print("Creating a HPF with cut-off: \(fc - bw)");
        } else {
            print("Creating a BPF with center-frequency: \(fc) bw: \(bw)");
        }
        
        // Spacing between bins of filter in frequency domain
        let delta_f: Float = bw / fs
        // Center-bin
        let center_n: Int = n / 2
        // Correction of Hamming window gain
        let gain: Float = 4 * delta_f
        
        //
        // Now, calculate all the taps!
        //
        for i in 0 ..< n {
            // Shift to center of Sinc to center of filter-taps in time-domain
            let shift_t = i - center_n
            
            // Scale sinc-width with 2πΔft
            let a = Float(2.0) * Float.pi * delta_f * Float(shift_t)
            
            // Calculate actual sampled sinc-value when a != 0
            ys = (a == 0) ? 1 : sin(a) / a
            
            // Calculate hamming window value for tap
            yw = 0.54 - 0.46 * cos((Float(2.0) * Float.pi / Float(n)) * Float(i))
            
            // Shift in frequency domain by multiplying with another cosine
            yf = cos(Float(shift_t) * Float(2.0) * Float.pi * fc / fs)
            
            // Calculate current filter-tap
            filter[i] = yf * yw * gain * ys
            
            print("\(filter[i])", terminator:", ")
        }
        print("\nFilter: ")
        
        return filter
    }
    
}
