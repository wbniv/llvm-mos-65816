# snes-gallery — 512 KiB LoROM child platform for the ten-bank LZSS art gallery.
platform(snes-gallery COMPLETE PARENT snes)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES link.ld TYPE LIB)
