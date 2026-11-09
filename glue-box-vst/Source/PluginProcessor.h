#pragma once
#include <juce_audio_processors/juce_audio_processors.h>
#include <atomic>

/** Glue Box: stereo bus compressor with sidechain "Thrust" filter, detector "Tone",
    feed-forward / feed-back detection and a post-gain saturation stage.
    This is a port of the DSP in the browser prototype. */
class GlueBoxProcessor : public juce::AudioProcessor
{
public:
    GlueBoxProcessor();
    ~GlueBoxProcessor() override = default;

    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override {}
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return "Glue Box"; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram (int) override {}
    const juce::String getProgramName (int) override { return {}; }
    void changeProgramName (int, const juce::String&) override {}

    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    juce::AudioProcessorValueTreeState apvts;

    // Read by the editor's meters (written on the audio thread).
    std::atomic<float> meterRms { 0.0f };       // linear RMS of the output
    std::atomic<float> meterReduction { 0.0f }; // gain reduction in dB, 0 or positive

private:
    static juce::AudioProcessorValueTreeState::ParameterLayout createLayout();

    void resetState();

    // Per-channel state
    float gs[2] {}, prevOut[2] {}, hpX[2] {}, hpY[2] {}, lpS[2] {}, dcX[2] {}, dcY[2] {};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GlueBoxProcessor)
};
