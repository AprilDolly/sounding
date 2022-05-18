require "sounding"
include Sounding

#ar=[[1,1],[2,2],[3,3],[4,4]]
#sd1=SampleData.from_array(ar)
#sd2=SampleData.from_array(ar)
#sd3=sd1+sd2
#puts sd3.samples
sf1=Sound.from_file("/home/huggypie/development/python/gtss_appimage_test/guitar_samples/b1_opc_29/b1_opc_29_01_4697.wav")
sf2=Sound.from_file("/home/huggypie/development/python/gtss_appimage_test/guitar_samples/b1_open_fallback/b1_open_fallback_01_683.wav")
sf2<<sf1
sf2.write("concat_test2.wav")
