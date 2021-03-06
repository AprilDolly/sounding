# TODO: Write documentation for `Sounding`

require "soundfile"
include SoundFile

require "./signal_processing"
require "./rubberband"
require "uuid"
require "file_utils"

module Sounding
  VERSION = "0.1.0"
  INT_MAX = 2147483647

  #function for using the rubberband CLI to perform operations on Sound objects
  def rubberband_temp(sound : Sound,args : Array(String))
    begin
      rubberband_cli_wrapper("","")
      id=UUID.random()
      in_path="#{TMPFILE_DIRECTORY}/#{id}_in.wav"
      out_path="#{TMPFILE_DIRECTORY}/#{id}_out.wav"
      sound.write(in_path)
      rubberband_cli_wrapper(in_path,out_path,args)
      sound_out=Sound.from_file(out_path)
      FileUtils.rm(in_path)
      FileUtils.rm(out_path)
      return sound_out
    rescue ex
      if ex.message.to_s.includes? "Error executing process"
        puts "WARNING: rubberband could not be found. Please make sure it is installed, or is located in your system $PATH"
      else
        puts ex.message
      end
      return sound
    end
  end

  

  ##############################
  # main Sound class
  ##############################
  class Sound(T)
    def initialize(@samples : Slice, @info : LibSndFile::SFInfo)
      @dtype=T
    end
    
    # create new Sound object from file
    def self.from_file(filepath : String,type : Class=Int32)
      acceptable_classes=[Int16,Int32,Float32,Float64]
      if !acceptable_classes.includes?(type)
        raise "type parameter must be one of the following: #{acceptable_classes}"
      end
      SFile.open(filepath, :read) do |f|
        if type==Int32
          ptr = Slice.new(f.size, Int32.new(0))
          f.read_int(ptr, f.size)
          return Sound(Int32).new(ptr.clone, f.info)
        elsif type==Int16
          ptr = Slice.new(f.size, Int16.new(0))
          f.read_short(ptr,f.size)
          return Sound(Int16).new(ptr.clone, f.info)
        elsif type==Float32
          ptr = Slice.new(f.size, Float32.new(0))
          f.read_float(ptr,f.size)
          return Sound(Float32).new(ptr.clone, f.info)
        elsif type==Float64
          ptr = Slice.new(f.size, Float64.new(0))
          f.read_double(ptr,f.size)
          return Sound(Float64).new(ptr.clone, f.info)
        end
      end
      sf_info=LibSndFile::SFInfo.new
      return Sound(Int32).new(Slice.new(1,Int32.new(0)),sf_info)
    end

    # write sound object to file
    def write(filepath : String)
      SFile.open(filepath, :write, @info) do |f|
        if T==Int32
          f.write_int(change_slice_type(@samples,Int32), @samples.size)
        elsif T==Int16
          f.write_short(change_slice_type(@samples,Int16),@samples.size)
        elsif T==Float32
          f.write_float(change_slice_type(@samples,Float32),@samples.size)
        elsif T==Float64
          f.write_double(change_slice_type(@samples,Float64),samples.size)
        end
      end
    end

    # create new Sound object from slice
    def self.from_slice(slice : Slice, sr : T, n_channels = 2)
      sfinfo = LibSndFile::SFInfo.new
      sfinfo.frames = slice.size/n_channels
      sfinfo.samplerate = sr
      sfinfo.channels = n_channels
      return Sound(typeof(slice[0])).new(slice, sfinfo)
    end

    # superimposition
    def +(sound : Sound)
      input_slice=sound.samples
      if sound.channels != @info.channels
        # TODO: implement addition of samples with multiple channel counts
        raise "Cannot add 2 sounds with different channel counts."
      end
      if sound.samplerate>@info.samplerate
        #new sound has a larger samplerate, resample this one to be larger
        @samples = slice_resample(@samples, @info.channels, @info.samplerate, sound.samplerate)
        @info.samplerate = sound.samplerate
      elsif sound.samplerate<@info.samplerate
        #self has larger samplerate, change the input sound's samplerate
        input_slice = slice_resample(input_slice, sound.channels, sound.samplerate, @info.samplerate)
      end
      return Sound.new(add_slices(@samples, input_slice).clone, @info)
    end

    # concatenation
    def <<(sound : Sound)
      if sound.channels != @info.channels
        # TODO: implement addition of samples with multiple channel counts
        raise "Cannot add 2 sounds with different channel counts."
      end
      input_slice=sound.samples
      if sound.samplerate>@info.samplerate
        #new sound has a larger samplerate, resample this one to be larger
        @samples = slice_resample(@samples, @info.channels, @info.samplerate, sound.samplerate)
        @info.samplerate = sound.samplerate
      elsif sound.samplerate<@info.samplerate
        #self has larger samplerate, change the input sound's samplerate
        input_slice = slice_resample(input_slice, sound.channels, sound.samplerate, @info.samplerate)
      end
      @samples = concatenate_slices(@samples, input_slice)
    end

    #########################
    # PROPERTIES
    #########################

    def samples
      @samples
    end

    def samples=(slice : Slice(T))
      @samples = slice
    end

    # SFInfo parameters
    def frames
      @info.frames
    end

    # samplerate, in Hz
    def samplerate
      @info.samplerate
    end

    # set sample rate and resample the sound object
    def samplerate=(new_sr : T)
      if new_sr != @info.samplerate
        @samples = slice_resample(@samples, @info.channels, @info.samplerate, new_sr)
        @info.samplerate = new_sr
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
    
    def info
      @info
    end
    
    def each
      (0...@info.frames).each do |iframe|
        yield @samples[iframe*@info.channels...iframe*@info.channels+@info.channels]
      end
    end

    ##########################################
    # channel operations
    ##########################################
    def to_mono
      frame_count = (@samples.size/@info.channels).to_i
      new_slc = Slice.new(frame_count, T.new(0))
      (0...frame_count).each do |iframe|
        new_val = 0
        (0...@channels).each do |ichannel|
          new_val += @samples[iframe*@channels + ichannel]/@channels
        end
        new_slc[iframe] = new_val
      end
      @samples = new_slc
    end

    ##########################################
    # position operations, i guess
    ##########################################
    def shift_by_samples(samplecount : T)
      if samplecount >= 0
        @samples = concatenate_slices(Slice.new(samplecount*@info.channels, T.new(0)), @samples)
      else
        raise "Shifting by negative amount of time has not been implemented"
      end
    end

    def shift_by_sec(time : Float64 | Float32)
      samplecount = (time*@info.samplerate).to_i
      shift_by_samples(samplecount)
    end

    def shift_by_ms(time : Float64 | Float32 | T)
      samplecount = (time*@info.samplerate/1000).to_i
      shift_by_samples(samplecount)
    end
    
    ####################################
    #rubberband-based operations
    ####################################
    def rubberband(args : Array(String))
      newfile=rubberband_temp(self,args)
      @samples=newfile.samples
      @info=newfile.info
    end
    def shift_pitch(semitones : Float64 | Float32 | Int64 | T,preserve_formants : Bool=false)
      args=["-p","#{semitones}"]
      if preserve_formants
        args<<"-F"
      end
      rubberband(args)
    end
    
    ##########################
    # slice operations
    ##########################

    # sum two slices
    def add_slices(slc1 : Slice(T), slc2 : Slice(T))
      new_size = slc1.size
      if slc1.size < slc2.size
        # slc2 is larger
        new_size = slc2.size
      end
      slc_new = Slice.new(new_size, T.new(0))
      (0...slc1.size).each do |i|
        slc_new[i] += slc1[i]
      end
      (0...slc2.size).each do |i|
        if (slc_new[i] > 0 && slc2[i] < 0) || (slc_new[i] < 0 && slc2[i] > 0)
          slc_new[i] += slc2[i]
        elsif slc_new[i].abs > INT_MAX - slc2[i].abs
          if slc_new[i] > 0
            slc_new[i] = INT_MAX
          elsif slc_new[i] < 0
            slc_new[i] = -1*INT_MAX
          end
        else # sometimes the above statements don't add, and im lazy, so screw it
          begin
            slc_new[i] += slc2[i]
          rescue
            if slc_new[i] > 0
              slc_new[i] = INT_MAX
            elsif slc_new[i] < 0
              slc_new[i] = -1*INT_MAX
            end
          end
        end
      end
      return slc_new
    end

    # concatenate 2 slices
    def concatenate_slices(slc1 : Slice(T), slc2 : Slice(T))
      new_size = slc1.size + slc2.size
      slc_new = Slice.new(new_size, T.new(0))
      (0...slc1.size).each do |i|
        slc_new[i] += slc1[i]
      end
      (0...slc2.size).each do |i|
        slc_new[i + slc1.size] += slc2[i]
      end
      return slc_new
    end
    
    # change type of slice
    def change_slice_type(input : Slice,type : Class)
      output=Slice.new(input.size,type.new(0))
      (0...input.size).each do |i|
        output[i]=type.new(input[i])
      end
      return output
    end
  end
end
