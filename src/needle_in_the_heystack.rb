##
# special thanks to:
#  https://github.com/giogziro95
##

#  SYNOPSIS
#    *.rb ATTR OBJ ID FILES
#      E.g., kagetattr.rb title video carrying-when-adding-three-digit-numbers *.po

# test search
# რაციონალური გამოსახულებების გაყოფა
# მეტობის და ნაკლებობის ნიშნები

# multiplying-and-dividing-rational-expressions-3
# ruby needle_in_the_heystack.rb title video multiplying-and-dividing-rational-expressions-3
# ruby needle_in_the_heystack.rb title video ca-geometry-similar-triangles-1

# Get arguments from shell
# ATTR =  ARGV[0]     # Attribute                   (title, description)
# OBJ =   ARGV[1]     # Object                      (video, tutorial, topic, subject, domain)
# ID =    ARGV[2]     # Video slug ID               (after /v/ in URL)
# FILES = ARGV[3..-1] # List of filenames/filepaths (can be multiple or single file; can be specified via shell wildcards, e.g., *.po)

# https://ka.khanacademy.org/math/algebra2/rational-expressions-equations-and-functions/multiplying-and-dividing-rational-expressions/v/multiplying-and-dividing-rational-expressions-3

def get_attr(attr, obj, id)
  puts "number of files: #{Dir.glob('../i18n/ka/**/*.po').size}"

  Dir.glob("../i18n/ka/**/2_high_priority_content/*.po").each.with_index(1) do |file, index|
    $stdout.write "\n" if index.eql?(1)
    $stdout.write "\rSearching for video title in file: #{index} #{file} "

    str = IO.read(file)

    # Get content URL
    video_url_regex = Regexp.new('(?<=# Title of video <a href=")https?:\/\/translate\.khanacademy\.org\/(.+\/){4}v\/' + Regexp.escape(id) + '\/?(?=">)')

    next unless str.match?(/#{video_url_regex}/)
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
    unless str.match?(/#{paragraph_regex}/)
      $stdout.write "\n"
      puts "************* WARNING *************"
      puts "Translation Missing for video: #{id}"
      puts "***********************************"
      return false
    end

    paragraph = str.match(/#{paragraph_regex}/)[0]
     
    video_topic = ""
    video_topic_url = video_url.match(/http:\/\/translate\.khanacademy\.org(?:\/[^\/]+){2}/)[0]
    video_topic_regex = Regexp.new('(# Title of \w+ <a href="(' + Regexp.escape(video_topic_url) + '\/?)">\2<\/a>\n)+(?:.+\n)*msgstr "([^"\n]+)"$')

    Dir.glob("../i18n/ka/**/*.po").each.with_index(1) do |file1, index1|
      $stdout.write "\n" if index1.eql?(1)
      $stdout.write "\rSearching for topic in file: #{index1} "

      str1 = IO.read(file1)
      next unless str1.match?(/#{video_topic_regex}/)
      video_topic = str1.match(/#{video_topic_regex}/)[3]
    end

    return [video_topic, paragraph.match(/(?<=^msgstr ").*(?="$)/)[0]]
  end
end

# result = get_attr(ATTR, OBJ, ID)
