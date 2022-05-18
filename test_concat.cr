require "sounding"
include Sounding

sf1=Sound.from_file("/home/huggypie/development/python/gtss_appimage_test/guitar_samples/a2_mute_fallback/a2_mute_fallback_01_4274.wav")
sf2=Sound.from_file("/home/huggypie/development/python/gtss_appimage_test/guitar_samples/b1_opc_29/b1_opc_29_01_4697.wav")

sf1<<sf2

sf1.write("concat_test.wave")
