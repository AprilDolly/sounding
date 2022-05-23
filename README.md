# sounding

A library for audio waveform manipulation

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     sounding:
       github: aprildolly/sounding
   ```

2. Run `shards install`

3. Install libsndfile development files. The package name is usually `libsndfile1-dev`

4. Install rubberband if you want to use the pitch shifting or time stretching capabilities. You can either get the binaries [here](https://breakfastquay.com/rubberband/) or install `rubberband-cli` via your package manager.

## Usage

```crystal
require "sounding"
include Sounding

#load sound from file
sound1=Sound.from_file("your_file.wav")

#create sound from slice
slice=Slice.new(3000,Int32.new(80000))
sample_rate=44100
channels=2
sound2=Sound.from_slice(slice,sample_rate,channels)


#superimpose multiple sound objects. sample rates are automatically changed to the first operand (in this case, that of sound1
sound3=sound1+sound2

#concatenate sound objects.
sound2<<sound1

#sample rates can also be changed manually. resampling is done automagically c:
sound3.samplerate=48000

#write sound to a new file
sound2.write("your_new_file.wav")
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/sounding/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [April Dolly](https://github.com/aprildolly) - creator and maintainer
