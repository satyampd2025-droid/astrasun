#include "PluginProcessor.h"
#include "PluginEditor.h"
#include <cmath>

using namespace juce;

static constexpr float kThrustHz[3] = { 0.0f, 90.0f, 160.0f };

AudioProcessorValueTreeState::ParameterLayout GlueBoxProcessor::createLayout()
{
    using P = AudioParameterFloat;
    using C = AudioParameterChoice;
    std::vector<std::unique_ptr<RangedAudioParameter>> p;

    auto skewed = [] (float lo, float hi, float centre)
    {
        NormalisableRange<float> r (lo, hi);
        r.setSkewForCentre (centre);
        return r;
    };

    p.push_back (std::make_unique<P> (ParameterID { "threshold", 1 }, "Threshold", NormalisableRange<float> (-40.0f, 0.0f, 0.1f), -18.0f,
                                      AudioParameterFloatAttributes().withLabel ("dB")));
    p.push_back (std::make_unique<P> (ParameterID { "ratio", 1 }, "Ratio", skewed (1.5f, 10.0f, 4.0f), 4.0f,
                                      AudioParameterFloatAttributes().withLabel (":1")));
    p.push_back (std::make_unique<P> (ParameterID { "attack", 1 }, "Attack", skewed (0.03f, 30.0f, 1.0f), 10.0f,
                                      AudioParameterFloatAttributes().withLabel ("ms")));
    p.push_back (std::make_unique<P> (ParameterID { "release", 1 }, "Release", skewed (0.05f, 3.0f, 0.3f), 0.3f,
                                      AudioParameterFloatAttributes().withLabel ("s")));
    p.push_back (std::make_unique<P> (ParameterID { "knee", 1 }, "Knee", NormalisableRange<float> (0.0f, 12.0f, 0.1f), 2.0f,
                                      AudioParameterFloatAttributes().withLabel ("dB")));
    p.push_back (std::make_unique<P> (ParameterID { "makeup", 1 }, "Makeup", NormalisableRange<float> (0.0f, 24.0f, 0.1f), 3.0f,
                                      AudioParameterFloatAttributes().withLabel ("dB")));
    p.push_back (std::make_unique<P> (ParameterID { "link", 1 }, "Link", NormalisableRange<float> (0.0f, 100.0f, 1.0f), 100.0f,
                                      AudioParameterFloatAttributes().withLabel ("%")));
    p.push_back (std::make_unique<P> (ParameterID { "mix", 1 }, "Mix", NormalisableRange<float> (0.0f, 100.0f, 1.0f), 100.0f,
                                      AudioParameterFloatAttributes().withLabel ("%")));
    p.push_back (std::make_unique<P> (ParameterID { "saturation", 1 }, "Saturation", NormalisableRange<float> (0.0f, 100.0f, 1.0f), 20.0f,
                                      AudioParameterFloatAttributes().withLabel ("%")));

    p.push_back (std::make_unique<C> (ParameterID { "thrust", 1 }, "Thrust", StringArray { "Normal", "Med", "Loud" }, 0));
    p.push_back (std::make_unique<C> (ParameterID { "tone", 1 }, "Tone", StringArray { "Old", "Normal", "New" }, 1));
    p.push_back (std::make_unique<C> (ParameterID { "type", 1 }, "Type", StringArray { "Feed-forward", "Feed-back" }, 0));
    p.push_back (std::make_unique<C> (ParameterID { "satchar", 1 }, "Sat character", StringArray { "Warm", "Clean", "Hard" }, 0));
    p.push_back (std::make_unique<AudioParameterBool> (ParameterID { "bypass", 1 }, "Bypass", false));

    return { p.begin(), p.end() };
}

GlueBoxProcessor::GlueBoxProcessor()
    : AudioProcessor (BusesProperties()
                          .withInput ("Input", AudioChannelSet::stereo(), true)
                          .withOutput ("Output", AudioChannelSet::stereo(), true)),
      apvts (*this, nullptr, "GlueBox", createLayout())
{
}

void GlueBoxProcessor::resetState()
{
    for (int c = 0; c < 2; ++c)
        gs[c] = prevOut[c] = hpX[c] = hpY[c] = lpS[c] = dcX[c] = dcY[c] = 0.0f;
}

void GlueBoxProcessor::prepareToPlay (double, int)
{
    resetState();
}

bool GlueBoxProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    const auto out = layouts.getMainOutputChannelSet();
    if (out != AudioChannelSet::mono() && out != AudioChannelSet::stereo())
        return false;
    return out == layouts.getMainInputChannelSet();
}

void GlueBoxProcessor::processBlock (AudioBuffer<float>& buffer, MidiBuffer&)
{
    ScopedNoDenormals noDenormals;

    const int n = buffer.getNumSamples();
    const int nch = jmin (2, buffer.getNumChannels());
    if (nch == 0 || n == 0)
        return;

    auto get = [this] (const char* id) { return apvts.getRawParameterValue (id)->load(); };

    float* x[2] = { buffer.getWritePointer (0), nch > 1 ? buffer.getWritePointer (1) : nullptr };

    float sumSq = 0.0f, gmin = 0.0f;

    if (get ("bypass") > 0.5f)
    {
        for (int c = 0; c < nch; ++c)
            for (int i = 0; i < n; ++i)
                sumSq += x[c][i] * x[c][i];

        gs[0] = gs[1] = 0.0f;
        meterRms.store (std::sqrt (sumSq / (float) (nch * n)));
        meterReduction.store (0.0f);
        return;
    }

    const double sr = getSampleRate();
    const float T = get ("threshold"), Rt = get ("ratio"), W = get ("knee");
    const float mk = std::pow (10.0f, get ("makeup") / 20.0f);
    const float mix = get ("mix") / 100.0f, link = get ("link") / 100.0f;
    const float color = get ("saturation") / 100.0f;
    const float drv = 1.0f + color * 6.0f;
    const int satMode = (int) get ("satchar");
    const float bias = 0.3f * color, tb = std::tanh (bias), nrm = 1.0f / (drv * (1.0f - tb * tb));
    const float aA = (float) std::exp (-1.0 / ((double) get ("attack") * 0.001 * sr));
    const float aR = (float) std::exp (-1.0 / ((double) get ("release") * sr));
    const float f = kThrustHz[jlimit (0, 2, (int) get ("thrust"))];
    const float hpA = f > 0.0f ? (float) std::exp (-2.0 * MathConstants<double>::pi * f / sr) : 0.0f;
    const float lpK = (float) (1.0 - std::exp (-2.0 * MathConstants<double>::pi * 3000.0 / sr));
    const bool feedback = (int) get ("type") == 1;
    const int tone = (int) get ("tone");
    const float slope = 1.0f / Rt - 1.0f;

    float det[2] = { 0.0f, 0.0f };

    for (int i = 0; i < n; ++i)
    {
        // Detector signal per channel
        for (int c = 0; c < nch; ++c)
        {
            float d = feedback ? prevOut[c] : x[c][i];
            if (hpA > 0.0f)
            {
                const float y = hpA * (hpY[c] + d - hpX[c]);
                hpX[c] = d;
                hpY[c] = y;
                d = y;
            }
            lpS[c] += lpK * (d - lpS[c]);
            if (tone == 0)      d = 0.4f * d + 0.6f * lpS[c];
            else if (tone == 2) d = d + 0.6f * (d - lpS[c]);
            det[c] = std::abs (d);
        }

        const float m = nch > 1 ? jmax (det[0], det[1]) : det[0];

        for (int c = 0; c < nch; ++c)
        {
            const float lv = 20.0f * std::log10 (det[c] + (m - det[c]) * link + 1.0e-9f);
            const float over = lv - T;
            float gr;
            if (W < 0.05f)                          gr = over > 0.0f ? over * slope : 0.0f;
            else if (2.0f * over < -W)              gr = 0.0f;
            else if (2.0f * std::abs (over) <= W)   { const float q = over + W * 0.5f; gr = slope * q * q / (2.0f * W); }
            else                                    gr = over * slope;

            const float coef = gr < gs[c] ? aA : aR;
            gs[c] = coef * gs[c] + (1.0f - coef) * gr;
            gmin = jmin (gmin, gs[c]);

            const float xi = x[c][i];
            const float red = xi * std::pow (10.0f, gs[c] / 20.0f);
            prevOut[c] = red;
            float wet = red * mk;

            if (color > 0.0f)
            {
                const float s = wet * drv;
                float sy;
                if (satMode == 0)      sy = (std::tanh (s + bias) - tb) * nrm;
                else if (satMode == 1) sy = std::tanh (s) / drv;
                else                   { const float as = std::abs (s), a2 = as * as; sy = s / std::sqrt (std::sqrt (1.0f + a2 * a2)) / drv; }

                const float dy = sy - dcX[c] + 0.995f * dcY[c];
                dcX[c] = sy;
                dcY[c] = dy;
                wet = dy;
            }

            const float out = xi * (1.0f - mix) + wet * mix;
            x[c][i] = out;
            sumSq += out * out;
        }
    }

    meterRms.store (std::sqrt (sumSq / (float) (nch * n)));
    meterReduction.store (-gmin);
}

AudioProcessorEditor* GlueBoxProcessor::createEditor()
{
    return new GlueBoxEditor (*this);
}

void GlueBoxProcessor::getStateInformation (MemoryBlock& destData)
{
    if (auto xml = apvts.copyState().createXml())
        copyXmlToBinary (*xml, destData);
}

void GlueBoxProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    if (auto xml = getXmlFromBinary (data, sizeInBytes))
        if (xml->hasTagName (apvts.state.getType()))
            apvts.replaceState (ValueTree::fromXml (*xml));
}

AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new GlueBoxProcessor();
}
