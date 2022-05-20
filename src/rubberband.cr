RUBBERBAND_NAME = "rubberband"

# "Crispness" levels:
#  -c 0   equivalent to --no-transients --no-lamination --window-long
#  -c 1   equivalent to --detector-soft --no-lamination --window-long (for piano)
#  -c 2   equivalent to --no-transients --no-lamination
#  -c 3   equivalent to --no-transients
#  -c 4   equivalent to --bl-transients
#  -c 5   default processing options
#  -c 6   equivalent to --no-lamination --window-short (may be good for drums)

# Wraps the rubberband cli itself since I can't wrap my head around the C interface, as usual :c
def rubberband_cli_wrapper(infile : String | Path, outfile : String | Path, pargs : Array(String) = [] of String, time = 0.0, tempo_multiplier = 0.0, initial_tempo = 0.0, final_tempo = 0.0, duration = 0.0, pitch_change = 0.0, frequency_multiplier = 0.0, crispness = 5, preserve_formants = true)
  args = [] of String
  if time != 0.0
    args << "-t"
    args << "#{time}"
  end
  if tempo_multiplier != 0
    args << "-T"
    args << "#{tempo_multiplier}"
  end
  if initial_tempo != 0 && final_tempo != 0
    args << "-T"
    args << "#{initial_tempo}:#{final_tempo}"
  end
  if duration != 0
    args << "-D"
    args << "#{duration}"
  end
  if pitch_change != 0
    args << "-p"
    args << "#{pitch_change}"
  end
  if frequency_multiplier != 0
    args << "-f"
    args << "#{frequency_multiplier}"
  end
  # TODO: implement pitch/stretch map
  if crispness != 5
    args << "-c"
    args << "#{crispness}"
  end
  if preserve_formants
    args << "-F"
  end
  pargs.each do |elem|
    args << elem
  end
  args << "#{infile}"
  args << "#{outfile}"
  Process.run(RUBBERBAND_NAME, args)
end
