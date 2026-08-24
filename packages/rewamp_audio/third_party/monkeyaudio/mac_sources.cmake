# Curated Monkey's Audio (MACLib) compile set — mirrors Modizer's
# monkeyaudiocodec.xcodeproj Sources phase (26 files). Do NOT glob:
# src/MACLib/Old/* (legacy APE < 3.98 core), the Windows dialog/Unicows
# sources and Console/Examples are deliberately excluded.
# MAC_ROOT must point at third_party/monkeyaudio/mac-master.
set(MAC_SOURCES
  "${MAC_ROOT}/src/MACLib/APECompress.cpp"
  "${MAC_ROOT}/src/MACLib/APECompressCore.cpp"
  "${MAC_ROOT}/src/MACLib/APECompressCreate.cpp"
  "${MAC_ROOT}/src/MACLib/APEDecompress.cpp"
  "${MAC_ROOT}/src/MACLib/APEHeader.cpp"
  "${MAC_ROOT}/src/MACLib/APEInfo.cpp"
  "${MAC_ROOT}/src/MACLib/APELink.cpp"
  "${MAC_ROOT}/src/MACLib/APESimple.cpp"
  "${MAC_ROOT}/src/MACLib/APETag.cpp"
  "${MAC_ROOT}/src/MACLib/Assembly/common.cpp"
  "${MAC_ROOT}/src/MACLib/BitArray.cpp"
  "${MAC_ROOT}/src/MACLib/MACLib.cpp"
  "${MAC_ROOT}/src/MACLib/MACProgressHelper.cpp"
  "${MAC_ROOT}/src/MACLib/MD5.cpp"
  "${MAC_ROOT}/src/MACLib/NNFilter.cpp"
  "${MAC_ROOT}/src/MACLib/NewPredictor.cpp"
  "${MAC_ROOT}/src/MACLib/Prepare.cpp"
  "${MAC_ROOT}/src/MACLib/UnBitArray.cpp"
  "${MAC_ROOT}/src/MACLib/UnBitArrayBase.cpp"
  "${MAC_ROOT}/src/MACLib/WAVInputSource.cpp"
  "${MAC_ROOT}/src/Shared/CharacterHelper.cpp"
  "${MAC_ROOT}/src/Shared/CircleBuffer.cpp"
  "${MAC_ROOT}/src/Shared/GlobalFunctions.cpp"
  "${MAC_ROOT}/src/Shared/MACUtils.cpp"
  "${MAC_ROOT}/src/Shared/StdLibFileIO.cpp"
  "${MAC_ROOT}/src/Shared/WinFileIO.cpp"
)
