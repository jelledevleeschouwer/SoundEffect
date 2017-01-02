//
//  ViewController.swift
//  SoundEffect
//
//  Created by Jelle De Vleeschouwer on 28/12/2016.
//  Copyright © 2016 Jelle De Vleeschouwer. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

class ViewController: UIViewController {
    
    //
    // Interface-Builder outlet for the waveform-view
    // https://github.com/mozilla-mobile/focus/tree/master/SCSiriWaveformView/Demo/SCSiriWaveformView
    //
    @IBOutlet var waveformView: SCSiriWaveformView!
    
    //
    // UITextField to set the maximum filterable frequency with
    //
    @IBOutlet weak var maxFreqField: UITextField!
    
    //
    // Audio engine is the container for all the AVAudioNodes
    //
    private let audioEngine = AVAudioEngine()
    
    //
    // Audio Player node is a AVAudioNode that can playback
    // audiobuffers, preferrably AVAudioPCMBuffers. We can 
    // manipulate these PCM-buffers to manipulate generate 
    // sound.
    //
    private let audioPlayer = AVAudioPlayerNode()
    
    //
    // Our own implementation of a FIR-Filter. The object is
    // an Objective-C++ wrapper around the actual C++-object.
    // The '!'-mark says this is an implicitally unwrapped 
    // optional. This means that the variable _always_ have a 
    // value since it is clear from the program flow. The value 
    // will always be set in the beginning of the program
    //
    private var filter: FIRFilterObjC!
    
    //
    // Toggle value to enable/disable the microphone signal
    //
    private var micDisabled: Bool = false
    
    //
    // Frequency sweep audio buffer
    //
    private var sweep: AVAudioPCMBuffer?

    //
    // Progress  in sweep signal buffer (x frames playbacked)
    //
    private var progress: Int = 0
    
    // 
    // Sampling frequency of audio files as well as filter
    //
    let fs: Float = 44100.0
    
    // 
    // Constant that specifies the maximum frame_size that can be 
    // passed to the FIR-filter.
    //
    private let frame_size: UInt32 = 4410
    
    // 
    // FIR Filter size
    //
    private let filter_taps: Int = 256
    
    //
    // Filter bandwidth
    //
    private let bw: Float = 200
    
    //
    // dB-level of the audio coming from the input. This is required
    // by the waveform-view to update it's awesome sine-wave.
    //
    private var db: Float = 0.0
    
    @IBAction func toggleSource(_ sender: UISwitch)
    {
        micDisabled = !micDisabled
        self.audioPlayer.stop()
        self.progress = 0
        if (micDisabled) {
            print("Disabled mic")
        } else {
            print("Enabled mic")
        }
    }
    
    //
    // Action to perform when the center-frequency slider is updated
    // Calculates new filter-coefficients for the FIR-filter
    //
    @IBAction func updateCenterFrequency(_ sender: UISlider)
    {
        var filter = [Float](repeating:0.0, count:filter_taps)
        
        self.waveformView.frequency = CGFloat((self.fs / 2) * sender.value);
        
        // Calculate new filter coefficients asynchronously
        DispatchQueue.main.async {
            filter = FilterDesign.designFilter(fc: (self.fs / 2) * sender.value, bw: self.bw, n: self.filter_taps, fs: self.fs)
            
            // Update the FIRFilter object with the new coefficients
            if self.filter.updateFilter(filter) != 0 {
                print("Could not update filter coefficients");
            }
        }
    }
    
    //
    // Installs Audio-tap on microphone input and connects it through our
    // FIR Filter to the output which is the speaker on the top of the phone.
    //
    func installTapOnMic()
    {
        let bus = 0
        
        if let input = audioEngine.inputNode {
            //
            // Attach the audioPlayer-node to the audioEngine container and
            // connect it to the output node
            //
            audioEngine.attach(audioPlayer)
            audioEngine.connect(audioPlayer, to: audioEngine.outputNode, format: input.inputFormat(forBus: bus))
            
            //
            // AVAudioNodes potentially have multiple input and/or output busses. With
            // AVAudioNode.'installTap(...)' we can tap the audio on one of these busses.
            // This allows us to record, monitor, and observe the output of the node. We
            // receive AVAudioPCMBuffers of certain size that can be parsed in a closure
            //
            input.installTap(onBus: bus, bufferSize: self.frame_size, format: input.inputFormat(forBus: bus)) {
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in // Closure
                var avg: Float = 0.0
                if (!self.micDisabled) {
                    // Optionally binding of floatChannelData optional
                    if let buf = buffer.floatChannelData {
                        // Calculate next average power level for waveform-view (only for appearancen, no functional purpose)
                        if (!self.micDisabled) {
                            vDSP_meamgv(buf[0], 1, UnsafeMutablePointer<Float>(&avg), vDSP_Length(buffer.frameLength))
                            self.db = 20 * log10f(avg)
                        }
                        
                        // Process next frame in FIR-filter
                        self.filter.processFrame(buf[0], ofSize: buffer.frameLength)
                        
                        // Put the output back in the AudioPCMBuffer
                        if let output = self.filter.getOutput() {
                            if let dst = buffer.floatChannelData {
                                for i in 0 ..< Int(self.frame_size) {
                                    dst[0][i] = output[i]
                                }
                                self.filter.freeOutput(output)
                            }
                        }
                    }
                    
                    // Schedule AudioPCMBuffer in AVAudioPlayerNode
                    self.audioPlayer.play()
                    self.audioPlayer.scheduleBuffer(buffer, completionHandler: nil)
                }
            }
        }
    }
    
    func loopAudioFile() {
        while true {
            if (self.micDisabled) {
                if let buffer = self.sweep {
                    
                    self.progress = Int(buffer.frameLength / self.frame_size)
                    let n = self.progress
                    
                    if let src = buffer.floatChannelData {
                        for i in 0 ..< n {
                            // Copy next chunk of audio file into output buffer
                            let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: self.frame_size)
                            
                            if let dst = out.floatChannelData {
                                memcpy(dst[0], src[0].advanced(by: i * Int(self.frame_size)), Int(self.frame_size) * MemoryLayout<Float32>.size)
                                out.frameLength = self.frame_size
                                
                                // Process next frame in FIR-filter
                                self.filter.processFrame(dst[0], ofSize: self.frame_size)
                                
                                // Calculate next average power level for waveform-view (only for appearancen, no functional purpose)
                                if (self.micDisabled) {
                                    var avg: Float = 0.0
                                    vDSP_meamgv(dst[0], 1, UnsafeMutablePointer<Float>(&avg), vDSP_Length(self.frame_size))
                                    self.db = 40 * log10f(avg) // Not correct! But is merely to update the sine-wave on screen..
                                } else {
                                    // Wait if mic is suddenly enabled again
                                    while !self.micDisabled {}
                                }
                                
                                // Put the output back in the AudioPCMBuffer
                                if let output = self.filter.getOutput() {
                                    for i in 0 ..< Int(self.frame_size) {
                                        dst[0][i] = output[i]
                                    }
                                    self.filter.freeOutput(output)
                                }
                                
                                // Schedule chunk
                                self.audioPlayer.play()
                                self.audioPlayer.scheduleBuffer(out) {
                                    if (self.progress != 0) {
                                        self.progress -= 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                while (self.progress != 0) {
                    // Wait
                }
            }
        }
    }
    
    //
    // First function that is called when the UIView is loaded in 
    // the hierarchy. Consider it as an initialisation or "main-routine" 
    // for a particular UIViewController
    //
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Resample the sweep audio-file at a sampling rate of 44100 Hz
        self.sweep = resampledSweep()
        
        // Set some parameters of the waveform view
        initGraph()
        
        // Reset the AVAudioEngine
        audioEngine.stop()
        audioEngine.reset()
        
        // Connect microphone input through our FIRFilter to the output
        installTapOnMic()
        
        // Try to start the AVAudioEngine-container
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed starting audio engine")
        }
        
        // Schedule updating of the waveform view
        let displaylink: CADisplayLink = CADisplayLink(target: self, selector: #selector(ViewController.updateGraph))
        displaylink.add(to: RunLoop.current, forMode: .commonModes)
        
        // Initialize the FIR-filter object
        filter = FIRFilterObjC(frameSize: frame_size, withFilter: [1]);
        
        DispatchQueue.global().async {
            self.loopAudioFile()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 
    // Normalize dB power level for Siri-waveform view
    // Derived from:
    // https://github.com/mozilla-mobile/focus/blob/master/SCSiriWaveformView/Demo/SCSiriWaveformView/SCViewController.m
    //
    func normalize(db: Float) -> Float {
        if (db < -60.0 || db == 0.0) {
            return 0.0
        }
        
        return powf((powf(10.0, 0.05 * db) - powf(10.0, 0.05 * -60.0)) * (1.0 / (1.0 - powf(10.0, 0.05 * -60.0))), 1.0 / 2.0);
    }
    
    //
    // Initialises some parameters of the Siri-waveform view
    //
    func initGraph()
    {
        self.waveformView.primaryWaveColor = UIColor(colorLiteralRed: 0.07, green: 0.49, blue: 0.96, alpha: 1.0)
        self.waveformView.primaryWaveLineWidth = 1.0
        self.waveformView.secondaryWaveColor = UIColor.lightGray
        self.waveformView.secondaryWaveLineWidth = 0.5
        self.waveformView.idleAmplitude = 0.15
        self.waveformView.frequency = 1.0
    }
    
    // 
    // Update the Siri-waveform view with a new power-level and redraw
    //
    func updateGraph()
    {
        self.waveformView.update(withLevel: CGFloat(normalize(db: db)))
    }
    
    //
    // Loads in a Audio File from the main bundled resources
    //
    func loadAudioFileIntoPCM(fromFile: String, ofType: String) -> AVAudioPCMBuffer?
    {
        let buffer: AVAudioPCMBuffer!
        let file: AVAudioFile!
        let fileURL: URL!
        
        // Try to build an URL to the specified file
        if let path = Bundle.main.path(forResource: fromFile, ofType: ofType) {
            fileURL = URL(fileURLWithPath: path)
        } else {
            return nil
        }
        
        // Try to load the file as an AVAudioFile-object
        do {
            file = try AVAudioFile(forReading: fileURL)
        } catch {
            print("Could not open file '\(fromFile).\(ofType)'")
            return nil
        }
        
        // Initialise buffer
        buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        
        // Try to read data from audio file into the PCM-buffer 
        do {
            try file.read(into: buffer)
        } catch {
            print("Could not read from file '\(fromFile).\(ofType)' with format \(buffer.format)")
            return nil
        }
        
        return buffer
    }
    
    //
    // Resample an Audio-buffer with another sampling rate
    //
    func resample(PCMBuffer src: AVAudioPCMBuffer, withSamplingRate sample_rate: Float) -> AVAudioPCMBuffer?
    {
        // Initalise resampled destination buffer
        let resample_ratio = Int(src.format.sampleRate / Double(sample_rate))
        let resampled_length = Int(Double(src.frameCapacity) / Double(resample_ratio))
        let resampled = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: AVAudioFrameCount(resampled_length) + 1)
        
        // Plain copy if there's no need for resampling
        if (resample_ratio == 1) {
            if let _src = src.floatChannelData {
                if let dst = resampled.floatChannelData {
                    memcpy(dst[0], _src[0], Int(src.frameLength) * MemoryLayout<Float32>.size)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        print("Resampling from \(src.format.sampleRate) to \(sample_rate), resampled length = \(resampled_length)")
        
        // Destination iterator
        var idx = 0
        
        // Resample
        for i in 0 ..< Int(src.frameLength) {
            if (i % resample_ratio == 0) {
                if let _src = src.floatChannelData {
                    if let dst = resampled.floatChannelData {
                        dst[0][idx] = _src[0][i]
                        idx += 1
                        resampled.frameLength += 1
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            }
        }
        
        return resampled
    }
    
    //
    // Resamples the 'sweep' audio file with a frequency of 44.1kHz and puts it 
    // in 'sweep'
    //
    func resampledSweep() -> AVAudioPCMBuffer?
    {
        if let sweep = loadAudioFileIntoPCM(fromFile: "sweep", ofType: "wav") {
            return resample(PCMBuffer: sweep, withSamplingRate: self.fs)
        } else {
            return nil
        }
    }
}

