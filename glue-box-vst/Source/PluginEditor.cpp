#include "PluginEditor.h"

using namespace juce;

namespace
{
    const Colour kBg      (0xff0e1114);
    const Colour kPanel   (0xff171c21);
    const Colour kLine    (0xff2b343d);
    const Colour kFg      (0xffe7ecf0);
    const Colour kMuted   (0xff8896a3);
    const Colour kAccent  (0xff52b6ff);
    const Colour kGr      (0xffffa347);

    struct KnobSpec
    {
        const char* id;
        const char* label;
        std::function<String (double)> fmt;
    };

    const KnobSpec kKnobs[9] = {
        { "threshold",  "Threshold",  [] (double v) { return String (v, 1) + " dB"; } },
        { "ratio",      "Ratio",      [] (double v) { return String (v, 1) + ":1"; } },
        { "attack",     "Attack",     [] (double v) { return v < 1.0 ? String (v, 2) + " ms" : String (v, 1) + " ms"; } },
        { "release",    "Release",    [] (double v) { return v < 1.0 ? String (roundToInt (v * 1000.0)) + " ms" : String (v, 2) + " s"; } },
        { "knee",       "Knee",       [] (double v) { return v < 0.05 ? String ("Hard") : String (v, 1) + " dB"; } },
        { "makeup",     "Makeup",     [] (double v) { return "+" + String (v, 1) + " dB"; } },
        { "link",       "Link",       [] (double v) { return String (roundToInt (v)) + "%"; } },
        { "mix",        "Mix",        [] (double v) { return String (roundToInt (v)) + "%"; } },
        { "saturation", "Saturation", [] (double v) { return String (roundToInt (v)) + "%"; } },
    };

    const char* kChoiceIds[4]    = { "thrust", "tone", "type", "satchar" };
    const char* kChoiceLabels[4] = { "Thrust", "Tone", "Type", "Sat character" };
}

//==============================================================================
NeedleMeter::NeedleMeter (String titleText, float minValue, float maxValue, float zoneFromValue,
                          Colour zone, Colour needle, std::vector<Tick> tickList)
    : title (std::move (titleText)), minV (minValue), maxV (maxValue), zoneFrom (zoneFromValue),
      zoneColour (zone), needleColour (needle), ticks (std::move (tickList))
{
}

void NeedleMeter::setValue (float newValue, const String& readout)
{
    value = newValue;
    readoutText = readout;
    repaint();
}

void NeedleMeter::paint (Graphics& g)
{
    auto b = getLocalBounds().toFloat();
    g.setColour (Colour (0xff0a0d10));
    g.fillRoundedRectangle (b, 6.0f);
    g.setColour (kLine);
    g.drawRoundedRectangle (b.reduced (0.5f), 6.0f, 1.0f);

    const float w = b.getWidth(), h = b.getHeight();
    const float cx = w * 0.5f, cy = h - 8.0f;
    const float R = jmin ((w * 0.5f - 18.0f) / 0.766f, h - 56.0f);

    auto ang = [this] (float v)
    {
        return degreesToRadians (-50.0f + 100.0f * (jlimit (minV, maxV, v) - minV) / (maxV - minV));
    };
    auto pt = [cx, cy] (float a, float r) { return Point<float> (cx + r * std::sin (a), cy - r * std::cos (a)); };

    // heading and numeric readout
    g.setColour (kMuted);
    g.setFont (FontOptions (13.0f, Font::bold));
    g.drawText (title.toUpperCase(), 12, 8, (int) w / 2, 18, Justification::centredLeft);
    g.setColour (needleColour == kFg ? kAccent : needleColour);
    g.setFont (FontOptions (Font::getDefaultMonospacedFontName(), 14.0f, Font::plain));
    g.drawText (readoutText, (int) w / 2, 8, (int) w / 2 - 12, 18, Justification::centredRight);

    // scale arc and coloured zone
    Path arc;
    arc.addCentredArc (cx, cy, R, R, 0.0f, degreesToRadians (-50.0f), degreesToRadians (50.0f), true);
    g.setColour (Colour (0xff3a4651));
    g.strokePath (arc, PathStrokeType (2.0f));

    Path zone;
    zone.addCentredArc (cx, cy, R - 4.0f, R - 4.0f, 0.0f, ang (zoneFrom), degreesToRadians (50.0f), true);
    g.setColour (zoneColour);
    g.strokePath (zone, PathStrokeType (5.0f));

    // ticks and labels
    g.setFont (FontOptions (Font::getDefaultMonospacedFontName(), 11.0f, Font::plain));
    for (auto& t : ticks)
    {
        const float a = ang (t.value);
        g.setColour (Colour (0xff7d8b97));
        g.drawLine ({ pt (a, R - 13.0f), pt (a, R) }, 1.5f);
        g.setColour (kMuted);
        auto lp = pt (a, R - 25.0f);
        g.drawText (t.label, Rectangle<float> (30.0f, 14.0f).withCentre (lp), Justification::centred);
    }

    // needle
    auto tip = pt (ang (value), R - 6.0f);
    g.setColour (needleColour);
    g.drawLine ({ Point<float> (cx, cy), tip }, 2.0f);
    g.fillEllipse (cx - 5.0f, cy - 5.0f, 10.0f, 10.0f);
}

//==============================================================================
GlueBoxEditor::GlueBoxEditor (GlueBoxProcessor& p)
    : AudioProcessorEditor (&p), proc (p),
      vu ("VU - output", -20.0f, 3.0f, 0.0f, Colour (0xffe5584f), kFg,
          { { -20, "-20" }, { -10, "-10" }, { -7, "-7" }, { -5, "-5" }, { -3, "-3" }, { 0, "0" }, { 3, "+3" } }),
      gr ("Gain reduction", 0.0f, 20.0f, 12.0f, kGr, kGr,
          { { 0, "0" }, { 2, "2" }, { 4, "4" }, { 6, "6" }, { 8, "8" }, { 10, "10" }, { 15, "15" }, { 20, "20" } })
{
    laf.setColour (Slider::rotarySliderFillColourId, kAccent);
    laf.setColour (Slider::rotarySliderOutlineColourId, Colour (0xff2a343d));
    laf.setColour (Slider::thumbColourId, kFg);
    laf.setColour (Slider::textBoxTextColourId, kFg);
    laf.setColour (Slider::textBoxOutlineColourId, Colours::transparentBlack);
    laf.setColour (Slider::textBoxBackgroundColourId, Colours::transparentBlack);
    laf.setColour (ComboBox::backgroundColourId, kPanel);
    laf.setColour (ComboBox::outlineColourId, kLine);
    laf.setColour (ComboBox::textColourId, kFg);
    laf.setColour (ComboBox::arrowColourId, kMuted);
    laf.setColour (PopupMenu::backgroundColourId, kPanel);
    laf.setColour (PopupMenu::textColourId, kFg);
    laf.setColour (PopupMenu::highlightedBackgroundColourId, kAccent);
    laf.setColour (PopupMenu::highlightedTextColourId, Colour (0xff05131d));
    laf.setColour (ToggleButton::textColourId, kFg);
    laf.setColour (ToggleButton::tickColourId, kGr);
    laf.setColour (ToggleButton::tickDisabledColourId, kMuted);
    laf.setColour (Label::textColourId, kMuted);
    setLookAndFeel (&laf);

    addAndMakeVisible (vu);
    addAndMakeVisible (gr);

    for (size_t i = 0; i < knobs.size(); ++i)
    {
        auto& k = knobs[i];
        const auto& spec = kKnobs[i];

        k.slider.setSliderStyle (Slider::RotaryHorizontalVerticalDrag);
        k.slider.setTextBoxStyle (Slider::TextBoxBelow, false, 80, 18);
        k.slider.setRotaryParameters (degreesToRadians (225.0f), degreesToRadians (495.0f), true);
        addAndMakeVisible (k.slider);

        k.label.setText (String (spec.label).toUpperCase(), dontSendNotification);
        k.label.setJustificationType (Justification::centred);
        k.label.setFont (FontOptions (12.0f, Font::bold));
        addAndMakeVisible (k.label);

        k.attachment = std::make_unique<SliderAtt> (proc.apvts, spec.id, k.slider);
        if (auto* param = proc.apvts.getParameter (spec.id))
            k.slider.setDoubleClickReturnValue (true, param->convertFrom0to1 (param->getDefaultValue()));

        const auto fmt = spec.fmt;
        k.slider.textFromValueFunction = [fmt] (double v) { return fmt (v); };
        k.slider.valueFromTextFunction = [] (const String& t) { return t.retainCharacters ("-0123456789.").getDoubleValue(); };
        k.slider.updateText();
    }

    for (size_t i = 0; i < choices.size(); ++i)
    {
        auto& c = choices[i];
        if (auto* param = dynamic_cast<AudioParameterChoice*> (proc.apvts.getParameter (kChoiceIds[i])))
            c.box.addItemList (param->choices, 1);
        addAndMakeVisible (c.box);

        c.label.setText (String (kChoiceLabels[i]).toUpperCase(), dontSendNotification);
        c.label.setFont (FontOptions (12.0f, Font::bold));
        addAndMakeVisible (c.label);

        c.attachment = std::make_unique<ComboAtt> (proc.apvts, kChoiceIds[i], c.box);
    }

    addAndMakeVisible (bypass);
    bypassAtt = std::make_unique<ButtonAtt> (proc.apvts, "bypass", bypass);

    setSize (780, 560);
    startTimerHz (30);
}

GlueBoxEditor::~GlueBoxEditor()
{
    stopTimer();
    setLookAndFeel (nullptr);
}

void GlueBoxEditor::paint (Graphics& g)
{
    g.fillAll (kBg);

    g.setColour (kFg);
    g.setFont (FontOptions (26.0f, Font::bold));
    g.drawText ("GLUE BOX", 20, 12, 300, 32, Justification::centredLeft);

    g.setColour (kMuted);
    g.setFont (FontOptions (13.0f));
    g.drawText ("Bus compressor  |  0 VU = -18 dBFS", 20, 12, getWidth() - 40, 32, Justification::centredRight);

    g.setColour (kLine);
    g.drawHorizontalLine (50, 20.0f, (float) getWidth() - 20.0f);
}

void GlueBoxEditor::resized()
{
    auto area = getLocalBounds().reduced (20);
    area.removeFromTop (40);

    auto meters = area.removeFromTop (180);
    const int mw = (meters.getWidth() - 14) / 2;
    vu.setBounds (meters.removeFromLeft (mw));
    meters.removeFromLeft (14);
    gr.setBounds (meters);

    area.removeFromTop (18);

    auto row = area.removeFromTop (140);
    const int kw = row.getWidth() / (int) knobs.size();
    for (auto& k : knobs)
    {
        auto cell = row.removeFromLeft (kw);
        k.label.setBounds (cell.removeFromTop (18));
        k.slider.setBounds (cell);
    }

    area.removeFromTop (14);

    auto row2 = area.removeFromTop (60);
    const int cw = (row2.getWidth() - 110) / (int) choices.size();
    for (auto& c : choices)
    {
        auto cell = row2.removeFromLeft (cw).reduced (6, 0);
        c.label.setBounds (cell.removeFromTop (18));
        c.box.setBounds (cell.removeFromTop (30));
    }
    bypass.setBounds (row2.reduced (6, 0).withTrimmedTop (18).withHeight (30));
}

void GlueBoxEditor::timerCallback()
{
    constexpr float dt = 1.0f / 30.0f;

    // VU ballistics: ~300 ms to reach 99%. 0 VU = -18 dBFS.
    const float rms = proc.meterRms.load();
    const float vuTarget = rms > 1.0e-5f ? 20.0f * std::log10 (rms) + 18.0f : -60.0f;
    vuDisp += (vuTarget - vuDisp) * (1.0f - std::exp (-dt / 0.065f));

    // Gain reduction: fast attack, slower release, shows exactly what is being removed.
    const float grTarget = proc.meterReduction.load();
    grDisp += (grTarget - grDisp) * (1.0f - std::exp (-dt / (grTarget > grDisp ? 0.02f : 0.12f)));

    vu.setValue (vuDisp, vuDisp < -30.0f ? String ("< -30 VU") : String (vuDisp > 0 ? "+" : "") + String (vuDisp, 1) + " VU");
    gr.setValue (grDisp, (grDisp < 0.05f ? String ("0.0") : "-" + String (grDisp, 1)) + " dB");
}
