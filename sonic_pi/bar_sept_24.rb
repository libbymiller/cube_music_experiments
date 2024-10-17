## This:
# Reads in an events file, a raw data file and a musical key file
# converts the raw data to the key
# plays a tune
# exports a lilypond file https://lilypond.org/

## Files
# all inputs are numbers
# one line per day
# events is master list and must have a line for all days

events_fn = "events_sep_24.txt"
raw_data_fn = "raw_bar_sep_24.txt"
key_fn = "C.txt"
raw_name = "Bar"
title = "Cube Accounts 1 September - 30 September 2024."
composer = "The Cube"

data_dir = "/Users/libby/cube/music/data"
out_dir = "/Users/libby/cube/music/lilypond"
lilyfile = "#{out_dir}/sonicpi_lilypond_sep_24.lp"

# key uses midi numbers https://computermusicresource.com/midikeys.html
# min 0, max 127
# in this case restrict to right handish piano
# both used later on

key_start = 60 # middle C
key_end = 96

# list of events, one per line representing a day, 0 if no event, int > 1 if there is
events = IO.read("#{data_dir}/#{events_fn}").lines.map(&:chomp).map(&:to_i)

# a list of raw data, one per line per day, 0 if nothing 
# floats but call 'em ints
raw_data = IO.read("#{data_dir}/#{raw_data_fn}").lines.map(&:chomp).map(&:to_i)
print raw_data

# key value numbers e.g. for C, one per line
key = IO.read("#{data_dir}/#{key_fn}").lines.map(&:chomp).map(&:to_i)

lilypond_part2 = "\\version \"2.24.4\"\n<<\n\\new Staff \\with {instrumentName = #\"#{raw_name}\"} { \\time 7/4 "
lilypond_part1 = "\\new Staff \\with {instrumentName = #\"Events\"}{ \\time 7/4 "
lilypond_part0 = "\\new Staff \\with {instrumentName = #\"Days\"} { \\clef bass \\time 7/4 "

# pre-process raw values
# to normalise raw data

# filter key to high and low values as specified
key_selected = key.select {|x| ( x >= key_start) }
key_selected = key_selected.select {|x| ( x <= key_end) }
puts "key_selected #{key_selected}"

# map raw values to selected key
# first find the factor
factor = (raw_data.max - raw_data.min)/(key_selected.max - key_selected.min)
puts "factor is #{factor}"

# then create a temporary mapping
# from raw values to key-mapped values
tmp_data = []
c = 0 #counter

puts "key is #{key_selected}"
raw_data.length.times do
  d = (raw_data[c]/factor)
  if(d == 0)
    # sometimes we'll get zero values here, ignore them
    tmp_data[c] = 0
  else
    # adjust to our key starting point
    d = d + key_start
    z1 = key_selected.find { |e| e == d }
    z2 = key_selected.reverse.find { |e| e < d } 
    z3 = key_selected.find { |e| e > d }
    closest_or_exact_number = z1 || z3 || z2
    #puts "exact #{z1} smaller #{z2} greater #{z3} chosen #{closest_or_exact_number}"
    tmp_data[c] = closest_or_exact_number
  end
  puts "day #{c} data is #{tmp_data[c]} raw is #{raw_data[c]}"
  c = c+1
end

# more preprocessing
# tmp_data may have other empty days
# so we fill it in using events
# this is quite confusing
# but that's the data I'm working with
c = 0  # events counter, our master list
cc = 0 # raw data counter, potentially with missing days
final_data = []
tmp_raw_plus_blanks = []

puts "events #{events}"

events.length.times do
  day = events[c]
  puts "day is #{day}"
  if(day > 0)
    final_data[c] = tmp_data[cc]
    tmp_raw_plus_blanks[c] = raw_data[cc]
    cc = cc +1
  else
    final_data[c] = 0
    tmp_raw_plus_blanks[c] = 0
  end
  c = c + 1
end

puts "FINAL DATA #{final_data}"
puts "FINAL RAW DATA PLUS BLANKS #{tmp_raw_plus_blanks}"

# play the tune
in_thread do
  count = 0
  events.length.times do

    # a drumbeat of days
    #sample :drum_heavy_kick
    lilypond_part0 = lilypond_part0+"c "

    ee = events[count].to_i
    if(ee > 0)

      # a baseline of events
      play :C
      lilypond_part1 = lilypond_part1 +"c' "

      fd_c = final_data[count]
      if(fd_c && fd_c > 0)

        # a tune of data
        play fd_c.to_f

        # midi string means we can convert it to lilypond easily
        notename = note_info(fd_c.to_f).midi_string.downcase
        nn = notename.chars
        suffix = ""

        # lilypond syntax https://lilypond.org/doc/v2.24/Documentation/learning/simple-notation
        # no suffix means octave below middle C aka 3 
        # Midi can have 3 items, if a sharp or flat
        # so we ake the last to get the number
        midi_num = nn[-1].to_i
        if(midi_num > 3)
           s = midi_num - 3
           # 1 octave above is 1 -> '
           # 2 octaves above is 2 -> ''
           # 3 octaves above is 3 -> '''
           suffix = "'"*s
        elsif (midi_num < 3)
           # 1 octave below is 2 -> ,
           # 2 octaves below is 1 -> ,,
           # 3 octaves below is 0 -> ,,,
           print "midi_num" 
           print midi_num.class 
           s = 3 - midi_num
           print "S is "+s.to_s 
           suffix = ","*s
        end
        # todo fix for sharps / flats (nn[1]
        lily_notename = nn[0]+suffix
        
        lilypond_part2 = lilypond_part2 + lily_notename + " "
      else
        # r is rest
        lilypond_part2 = lilypond_part2 + "r "
      end
    else
      # r is rest
      lilypond_part1 = lilypond_part1 + "r "
      lilypond_part2 = lilypond_part2 + "r "
    end
    sleep 0.1
    count = count+1
    
  end
  
  # last bit of lilypond boilerplate
  lilypond_part0 = lilypond_part0 + "}"
  lilypond_part1 = lilypond_part1 + "}"
  lilypond_part2 = lilypond_part2 + "}"
  
  
  # generate lilypond output

  lilyheader = "\\header { title = \"#{title}\"  composer = \"#{composer}\"\}"

  File.open(lilyfile, 'w') { |file| file.write(lilyheader + lilypond_part2+"\n"+lilypond_part1+"\n"+lilypond_part0+"\n>>\n") }
  
end




