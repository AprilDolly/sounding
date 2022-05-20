def slice_resample(slc_in : Slice(Int32), channels : Int32, initial_rate : Int32, target_rate : Int32)
  # TODO: implement interpolation
  s_count_ini = slc_in.size/channels
  duration = s_count_ini/initial_rate
  s_count_fin = (duration*target_rate).to_i
  slc_new = Slice.new(s_count_fin*channels, Int32.new(0))
  (0...channels).each do |c_offset|
    (0...s_count_fin).each do |s_index_fin|
      seconds_in = s_index_fin/target_rate
      s_index_ini = ((seconds_in*initial_rate).round_even).to_i
      if s_index_ini >= s_count_fin
        s_index_ini = s_count_fin - 1
      end
      slc_new[s_index_fin*channels + c_offset] += slc_in[s_index_ini*channels + c_offset]
    end
  end
  return slc_new
end
