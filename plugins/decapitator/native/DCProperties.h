#pragma once
#include <AudioToolbox/AudioToolbox.h>
static const AudioUnitPropertyID kDCMeterProperty=0x44434d74;
struct DCMeterReading {float decibels;UInt32 sequence;};
