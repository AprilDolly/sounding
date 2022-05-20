# TODO: Write documentation for `Sounding`
#TODO: Reduce the reliance on nested arrays for sound processing due to the insane amount of memory they take up

require "soundfile"
include SoundFile

require "signal_processing"
#require "sampledata"
require "uuid"
require "file_utils"


module Sounding
  VERSION = "0.1.0"
  INT_MAX=2147483647
#  #function for using the rubberband CLI to perform operations on Sound objects
#  def rubberband_temp(sound : Sound,args : Array(String))
#    begin
#      rubberband_cli_wrapper("","")
#      id=UUID.random()
#      in_path="#{TMPFILE_DIRECTORY}/#{id}_in.wav"
#      out_path="#{TMPFILE_DIRECTORY}/#{id}_out.wav"
#      sound.write(in_path)
#      rubberband_cli_wrapper(in_path,out_path,args)
#      sound_out=Sound.from_file(out_path)
#      FileUtils.rm(in_path)
#      FileUtils.rm(out_path)
#      return sound_out
#    rescue ex
#      if ex.message.to_s.includes? "Error executing process"
#        puts "WARNING: rubberband could not be found. Please make sure it is installed, or is located in your system $PATH"
#      else
#        puts ex.message
#      end
#      return sound
#    end
#  end
  
  ##########################
  #slice operations
  ##########################
  
  #sum two slices
  def add_slices(slc1 : Slice(Int32),slc2 : Slice(Int32))
    new_size=slc1.size
    if slc1.size<slc2.size
      #slc2 is larger
      new_size=slc2.size
    end
    slc_new=Slice.new(new_size,Int32.new(0))
    (0...slc1.size).each do |i|
      slc_new[i]+=slc1[i]
    end
    (0...slc2.size).each do |i|
      
      if (slc_new[i]>0 && slc2[i]<0) || (slc_new[i]<0 && slc2[i]>0)
        slc_new[i]+=slc2[i]
      elsif slc_new[i].abs>INT_MAX-slc2[i].abs
        if slc_new[i]>0
          slc_new[i]=INT_MAX
        elsif slc_new[i]<0
          slc_new[i]=-1*INT_MAX
        end
      else #sometimes the above statements don't add, and im lazy, so screw it
        begin
          slc_new[i]+=slc2[i]
        rescue
          if slc_new[i]>0
            slc_new[i]=INT_MAX
          elsif slc_new[i]<0
            slc_new[i]=-1*INT_MAX
          end
        end
      end
      
    end
    return slc_new
  end
  
  #concatenate 2 slices
  def concatenate_slices(slc1 : Slice(Int32),slc2 : Slice(Int32))
    new_size=slc1.size+slc2.size
    slc_new=Slice.new(new_size,Int32.new(0))
    (0...slc1.size).each do |i|
      slc_new[i]+=slc1[i]
    end
    (0...slc2.size).each do |i|
      slc_new[i+slc1.size]+=slc2[i]
    end
    return slc_new
  end
  
  
  ##############################
  #main Sound class
  ##############################
  class Sound
    
    
    def initialize(@samples : Slice(Int32),@info : LibSndFile::SFInfo)
    end
    
    #create new Sound object from file
    def self.from_file(filepath : String)
      SFile.open(filepath, :read) do |f|
        ptr=Slice.new(f.size,Int32.new(0))
        f.read_int(ptr,f.size)
        return new(ptr.clone,f.info)
      end
    end
    
    #write sound object to file
    def write(filepath : String)
      SFile.open(filepath, :write,@info) do |f|
        f.write_int(@samples,@samples.size)
      end
    end
    
    #create new Sound object from slice
    def self.from_slice(slice : Slice(Int32),sr : Int32, n_channels=2)
      sfinfo=LibSndFile::SFInfo.new
      sfinfo.frames=slice.size/n_channels
      sfinfo.samplerate=sr
      sfinfo.channels=n_channels
      return new(slice,sfinfo)
    end
    #superimposition
    def +(sound : Sound)
      if sound.channels !=@info.channels
        #TODO: implement addition of samples with multiple channel counts
        raise "Cannot add 2 sounds with different channel counts."
      end
      return Sound.new(add_slices(@samples,sound.samples).clone,@info)
    end
    #concatenation
    def <<(sound : Sound)
      if sound.channels !=@info.channels
        #TODO: implement addition of samples with multiple channel counts
        raise "Cannot add 2 sounds with different channel counts."
      end
      @samples=concatenate_slices(@samples,sound.samples)
    end
    
    #########################
    #PROPERTIES
    #########################
    
    def samples
      @samples
    end
    def samples=(slice : Slice(Int32))
      @samples=slice
    end
    
    ##SFInfo parameters
    #
    def frames
      @info.frames
    end
    
    #samplerate, in Hz
    def samplerate
      @info.samplerate
    end
    
    #set sample rate and resample the sound object
    def samplerate=(new_sr : Int32)
      if new_sr!=@info.samplerate
        @samples=slice_resample(@samples,@info.channels,@info.samplerate,new_sr)
        @info.samplerate=new_sr
      end
    end
    
    def channels
      @info.channels
    end
    def format
      @info.format
    end
    def sections
      @info.sections
    end
    def seekable
      @info.seekable
    end
    
    ##########################################
    #channel operations
    ##########################################
    def to_mono
      frame_count=(@samples.size/@info.channels).to_i
      new_slc=Slice.new(frame_count,Int32.new(0))
      (0...frame_count).each do |iframe|
        new_val=0
        (0...@channels).each do |ichannel|
          new_val+=@samples[iframe*@channels+ichannel]/@channels
        end
        new_slc[iframe]=new_val
      end
      @samples=new_slc
    end
    
    
    ##########################################
    #position operations, i guess
    ##########################################
    def shift_by_samples(samplecount : Int32)
      if samplecount>=0
        @samples=concatenate_slices(Slice.new(samplecount*@info.channels,Int32.new(0)),@samples)
      else
        raise "Shifting by negative amount of time has not been implemented"
      end
    end
    def shift_by_sec(time : Float64 | Float32)
      samplecount=(time*@info.samplerate).to_i
      shift_by_samples(samplecount)
    end
    def shift_by_ms(time : Float64 | Float32 | Int32)
      samplecount=(time*@info.samplerate/1000).to_i
      shift_by_samples(samplecount)
    end
  end
end
