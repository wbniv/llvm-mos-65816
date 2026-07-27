# snes-gallery — 1 MiB LoROM child platform for the 20-work LZSS art gallery.
platform(snes-gallery COMPLETE PARENT snes)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES link.ld TYPE LIB)
