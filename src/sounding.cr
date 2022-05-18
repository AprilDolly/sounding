# TODO: Write documentation for `Sounding`

require "soundfile"
include SoundFile

require "signal_processing"
require "sampledata"
require "uuid"
require "file_utils"


module Sounding
  VERSION = "0.1.0"
  
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
  
  #A class for creating, manipulating, and saving audio waveforms.
  class Sound
    @samples : SampleData
    @info : LibSndFile::SFInfo=LibSndFile::SFInfo.new
    
    ##############################
    #CONSTRUCTORS
    ##############################
    def initialize(@samples : SampleData,@samplerate : Int32,channels : Int32=0,@info=LibSndFile::SFInfo.new)
      if channels==0
        @info.channels=@info.channels
      else
        @info.channels=channels
      end
      @info.format=65538
      @info.seekable=1
    end
    
    def build_info()
    end
    
    #Constructs a sound object from a file
    def self.from_file(filename : String,unsafe : Bool=false)
      SFile.open(filename, :read) do |f|
        slc=Slice.new(f.size,Int32.new(0))
        f.read_int(slc,f.size)
        if !unsafe
          slc=slc.clone
        end
        return Sound.new(SampleData.new(slc,f.channels),f.sample_rate,f.info.channels,f.info)
      end
    end
    
    #Constructs a sound object from a 2-dimensional array of integers
    def self.from_array(arr : Array(Array(Int32)), sample_rate)
      sd=SampleData.from_array(arr)
      return Sound.new(sd,sample_rate,sd[0].size)
    end
    
    ####################################
    #WRITING
    ####################################
    #writes sound to file
    def write(filename : String)
      SFile.open(filename, :write,@info) do |sf|
        sf.write_int(@samples.samples,@samples.size*@info.channels)
      end
    end
    
    
    ########################################
    #PROPERTIES
    ########################################
    #The samples themselves
    def samples=(s_samples : SampleData)
      @samples=s_samples
      @info.frames=@samples.size
    end
    def samples
      @samples
    end
    
    #samplerate
    def sample_rate
      @info.samplerate
    end
    def sample_rate=(sr : Int32)
      if sr!=@info.samplerate
        resampled_arr=ar_resample(@samples.to_a,@info.samplerate,sr)
        @samples=SampleData.from_array(resampled_arr)
        @info.samplerate=sr
        @info.frames=@samples.size
      end
    end
    
    #returns @info.channels
    def channels
      @info.channels
    end
    
    #returns info itself
    def info
      @info
    end
    
    ####################################
    #generic operators
    ####################################
    
    #concatenate other sound objects
    #TODO: make more efficient by screwing with the underlying slice eventually
    def <<(sound : Sound)
      if @info.channels!=sound.channels
        raise "Concatenation of sound objects with different amounts of channels has yet to be implemented"
      end
      sound.sample_rate=@info.samplerate
      @samples=SampleData.from_array(@samples.to_a.concat(sound.samples.to_a))
    end
    #concatenate with arrays
    def <<(arr : Array(Int32))
      @samples=SampleData.from_array(@samples.to_a.concat(arr))
    end
    
    #Sum waveforms, return new sound object
    def +(sound : Sound)
      sound.samplerate=@info.samplerate
      new_samples=sound.samples+@samples
      new_info=@info
      new_info.frames=new_samples.size
      return Sound.new(new_samples,new_info.samplerate,@info.channels,new_info)
    end
    #sum with array, return new sound object
    def +(arr : Array(Int32))
      new_samples=@samples+SampleData.from_array(arr)
      new_info=@info
      new_info.frames=new_samples.size
      return Sound.new(new_samples,new_info.samplerate,@info.channels,new_info)
    end
    
    ####################################
    #CHANNEL OP
    ####################################
    
    #will add a channel to a wave file
    def add_channels()
      #TODO: implement
      #arr=samples.to_a
    end
    
    #turns a multichannel track into a mono track
    #TODO: make more efficient, it is pretty slow for larger sound clips
    def make_mono(use_avg : Bool=true)
      arr=@samples.to_a
      new_a=[] of Array(Int32)
      arr.each do |elem|
        new_value=Int32.new(0)
        (0...@info.channels).each do |i|
          if use_avg
            new_value+=Int32.new(elem[i]/@info.channels)
          else
            new_value+=elem[i]
          end
        end
        new_a<<[new_value]
      end
      @info.channels=1
      @samples=SampleData.from_array(new_a)
    end
    
    #makes a mono track stereo
    #TODO: optimize
    def make_stereo(half : Bool=true)
      arr=@samples.to_a
      arr.each do |frame|
        if half
          frame[0]=Int32.new(frame[0]/2)
        end
        frame<<frame[0]
      end
      @samples=SampleData.from_array(arr)
    end
    
    ######################################################################
    #Stretching, pitch shifting, and other rubberband-dependent operations
    ######################################################################
    
    #Apply rubberband operation, keeping public in case somebody wants to use custom rubberband commands
    def rubberband(args : Array(String))
      tmpsound=rubberband_temp(self,args)
      @samples=tmpsound.samples
      @info=tmpsound.info
    end
    
    #shifts pitch by given semitones
    def shift_pitch(semitones : Int32 | Float32 | String,preserve_formants : Bool=true)
      args=["-p",semitones.to_s]
      if preserve_formants
        args<<"-F"
      end
      rubberband(args)
    end
    
    #shifts formants by given semitones. kind of a hacky way of doing it lol
    def shift_formants(semitones : Int32 | Float32 | String)
      st=semitones.to_f
      #first shift pitch without preserving formants,then shift back while preserving
      shift_pitch(st)
      shift_pitch(-1*st,false)
    end
    
    #stretches the sound by multiple
    def stretch(multiple)
      args=["-t",multiple.to_s]
      rubberband(args)
    end
    
    #changes tempo from initial tempo to final tempo
    def change_tempo(tempo_initial,tempo_final)
      args=["-T","#{tempo_initial}:#{tempo_final}"]
      rubberband(args)
    end
  end
end
