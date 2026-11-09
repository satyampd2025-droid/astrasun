#pragma once
#include "PluginProcessor.h"
#include <array>
#include <functional>

/** Analog-style needle meter (VU or gain reduction). */
class NeedleMeter : public juce::Component
{
public:
    struct Tick { float value; juce::String label; };

    NeedleMeter (juce::String titleText, float minValue, float maxValue, float zoneFromValue,
                 juce::Colour zone, juce::Colour needle, std::vector<Tick> tickList);

    void setValue (float newValue, const juce::String& readout);
    void paint (juce::Graphics&) override;

private:
    juce::String title, readoutText;
    float minV, maxV, zoneFrom, value = 0.0f;
    juce::Colour zoneColour, needleColour;
    std::vector<Tick> ticks;
};

class GlueBoxEditor : public juce::AudioProcessorEditor, private juce::Timer
{
public:
    explicit GlueBoxEditor (GlueBoxProcessor&);
    ~GlueBoxEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    void timerCallback() override;

    using SliderAtt = juce::AudioProcessorValueTreeState::SliderAttachment;
    using ComboAtt  = juce::AudioProcessorValueTreeState::ComboBoxAttachment;
    using ButtonAtt = juce::AudioProcessorValueTreeState::ButtonAttachment;

    struct Knob
    {
        juce::Slider slider;
        juce::Label label;
        std::unique_ptr<SliderAtt> attachment;
    };

    struct Choice
    {
        juce::ComboBox box;
        juce::Label label;
        std::unique_ptr<ComboAtt> attachment;
    };

    GlueBoxProcessor& proc;
    juce::LookAndFeel_V4 laf;

    NeedleMeter vu, gr;
    std::array<Knob, 9> knobs;
    std::array<Choice, 4> choices;
    juce::ToggleButton bypass { "Bypass" };
    std::unique_ptr<ButtonAtt> bypassAtt;

    float vuDisp = -60.0f, grDisp = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GlueBoxEditor)
};
