cmake_minimum_required(VERSION 3.22)
project(GlueBox VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(APPLE)
  set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "")
  set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "")
endif()

include(FetchContent)
# Point FETCHCONTENT_SOURCE_DIR_JUCE at a local JUCE checkout to build offline.
FetchContent_Declare(JUCE
  GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
  GIT_TAG 8.0.9
  GIT_SHALLOW ON)
FetchContent_MakeAvailable(JUCE)

juce_add_plugin(GlueBox
  COMPANY_NAME "Astrasun"
  PLUGIN_MANUFACTURER_CODE Astr
  PLUGIN_CODE Gbx1
  FORMATS VST3
  PRODUCT_NAME "Glue Box"
  IS_SYNTH FALSE
  NEEDS_MIDI_INPUT FALSE
  NEEDS_MIDI_OUTPUT FALSE
  VST3_CATEGORIES Fx Dynamics
  COPY_PLUGIN_AFTER_BUILD FALSE
  NEEDS_CURL FALSE
  NEEDS_WEB_BROWSER FALSE)

target_sources(GlueBox PRIVATE
  Source/PluginProcessor.cpp
  Source/PluginEditor.cpp)

target_compile_definitions(GlueBox PUBLIC
  JUCE_WEB_BROWSER=0
  JUCE_USE_CURL=0
  JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(GlueBox
  PRIVATE
    juce::juce_audio_processors
  PUBLIC
    juce::juce_recommended_config_flags
    juce::juce_recommended_warning_flags)
