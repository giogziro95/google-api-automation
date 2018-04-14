##
#  SYNOPSIS
#    *.rb ATTR OBJ ID FILES
#      E.g., kagetattr.rb title video carrying-when-adding-three-digit-numbers *.po
#

# Get arguments from shell
ATTR =  ARGV[0] # Attribute (e.g., title, description)
OBJ =   ARGV[1] # Object (e.g., video, topic, etc.)
ID =    ARGV[2] # Video slug ID (e.g., carrying-when-adding-three-digit-numbers)
FILES = ARGV[3..-1] # List of filenames/filepaths (can be multiple or single file; can be specified via shell wildcards, e.g., *.po)

def get_attr(attr, obj, id, files)
  # Get string from files
  str = ""
  files.each do |file|
    str = str + IO.read(file) + "\n\n"
  end
  # Get content URL
  video_url_regex = Regexp.new('(?<=<a href=")https?:\/\/translate\.khanacademy\.org\/(.+\/){4}v\/' + Regexp.escape(id) + '\/?(?=">)')
  video_url = str.match(/#{video_url_regex}/)[0]
  url = ""
  case obj
  when "video"
    url = video_url.match(/^.+\/v\/[^\/\n]+/)[0]
  when "tutorial"
    url = video_url.match(/^.+(?=\/v\/)/)[0]
  when "topic"
    url = video_url.match(/^.+(?=\/.+\/v\/)/)[0]
  when "subject"
    url = video_url.match(/^.+(?=(\/.+){2}\/v\/)/)[0]
  when "domain"
    url = video_url.match(/^.+(?=(\/.+){3}\/v\/)/)[0]
  else
    puts "OBJ unknown. Exiting."
    exit 1
  end
  # Get paragraph regex patern
  paragraph_regex = ""
  case attr
  when "title"
    paragraph_regex = Regexp.new('(^# Title of \w+ <a href="(' + Regexp.escape(url) + '\/?)">\2<\/a>\n)+(.+\n)*msgstr ".+"$')
  when "description"
    paragraph_regex = Regexp.new('(^# Description of \w+ <a href="(' + Regexp.escape(url) + '\/?)">\2<\/a>\n)+(.+\n)*msgstr ".+"$')
  else
    puts "ATTR unknown. Exiting."
    exit 1
  end
  # Get paragraph
  paragraph = str.match(/#{paragraph_regex}/)[0]
  # Get ATTR value
  paragraph.match(/(?<=^msgstr ").*(?="$)/)[0]
end

puts get_attr(ATTR, OBJ, ID, FILES)

exit 0
