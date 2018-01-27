require_relative "helpers"

# Setting up Transitional Video Download Dir for downloading Drive Videos
FileUtils.mkdir_p("#{Dir.home}#{Settings.tmp_video_download_path}")

# path to client_secrets.json & tokens.yaml & SCOPES
CLIENT_SECRETS_PATH =
  File.join(Dir.home, ".google_cred", "client_secrets_server.json")
YOUTUBE_CLIENT_SECRETS_PATH =
  File.join(Dir.home, ".google_cred", "youtube_client_secrets.json")
YOUTUBE_CREDENTIALS_PATH =
  File.join(Dir.home, ".google_cred", "youtube_tokens.yaml")

DRIVE_SHEETS_SCOPE = [
  Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
  Google::Apis::DriveV3::AUTH_DRIVE
].freeze
YOUTUBE_SCOPE = [
  Google::Apis::YoutubeV3::AUTH_YOUTUBE
].freeze
OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze # for youtube authorization

# Sheet V4 Service
sheets_service = Google::Apis::SheetsV4::SheetsService.new
sheets_service.authorization = Help.authorize(
  CLIENT_SECRETS_PATH, DRIVE_SHEETS_SCOPE
)
# Drive V3 Service
drive_service = Google::Apis::DriveV3::DriveService.new
drive_service.authorization = Help.authorize(
  CLIENT_SECRETS_PATH, DRIVE_SHEETS_SCOPE
)
# Youtube V3 Service
youtube_service = Google::Apis::YoutubeV3::YouTubeService.new
youtube_service.authorization = Help.authorize_youtube(
  YOUTUBE_CREDENTIALS_PATH, YOUTUBE_CLIENT_SECRETS_PATH, YOUTUBE_SCOPE
)

@playlist_names = [] # temporarily stores all channel playlist ids, names

# spreadsheet has many sheets
spreadsheet_id = /[-\w]{25,}/.match(Settings.gdoc_sheet_url).to_s
# sheet_id, in case it is needed
# sheet_id = Help.get_sheet_id(sheet_1_url)

# Column Letter to Coordinate
b_col = Help.char_to_ord(Settings.khan_academy_url_col) # Khan Academy URL
d_col = Help.char_to_ord(Settings.eng_youtube_url_col) # ENG Youtube URL
# k_col = Help.char_to_ord(Settings.ka_youtube_url_col) # Geo youtube URL
m_col = Help.char_to_ord(Settings.to_be_uploaded_status) # is not empty if ready for upload

range = Help.create_range( # Example: "Sheet1!A3:C10"
  Settings.range_starting_col,
  Settings.first_row,
  Settings.range_ending_col,
  Settings.last_row,
  Settings.sheet_name
)

# Rows that have videos that haven't been uploaded
response_range_array = Help.get_range(
  range,
  spreadsheet_id,
  sheets_service
).values

# [row_index, khan_url, eng_video_id]
selected_rows_array = []
response_range_array.each.with_index(Settings.first_row) do |row, index|
  # Ka Khan Academy Video URL
  khan_url = row[b_col] # Column B

  # Get english Video ID from Column D
  eng_video_regex = /.*\/(.+)/.match(row[d_col])
  eng_video_id = eng_video_regex.captures.first unless eng_video_regex.nil?

  # Add needed info to "selected_rows_array"
  unless (row[m_col].empty? unless row[m_col].nil?)
    selected_rows_array << [index, khan_url, eng_video_id]
  end
end

# List Playlists
def list_playlists(srvc, part, **params)
  params = params.delete_if { |_p, v| v == "" }
  resp = srvc.list_playlists(part, params)
  resp
end

def get_playlists_from_page(youtube_srvc, channel_id, next_page_token = nil)
  list_playlists(
    youtube_srvc,
    "snippet, contentDetails",
    max_results: 50,
    channel_id: channel_id,
    page_token: next_page_token,
    # on_behalf_of_content_owner: "",
    # on_behalf_of_content_owner_channel: ""
  ).to_h
end

# Recursively Get playlists if more than 50 on channel
def playlist_recursion(ytb_srvc, channel_id, nxt_pg_tok = nil)
  res = get_playlists_from_page(ytb_srvc, channel_id, nxt_pg_tok)
  @playlist_names << res[:items].map do |x| # [Playlist ID, Playlist Title]
    { id: x[:id], playlist_title: x[:snippet][:localized][:title] }
  end

  return @playlist_names unless res.include?(:next_page_token)
  playlist_recursion(ytb_srvc, channel_id, res[:next_page_token])
end

playlist_recursion(youtube_service, Settings.khan_youtube_id)
@playlist_names.flatten!

def check_if_playlist_exists(playlist_nam, playlist_array)
  # LIST OWN PLAYLISTS
  playlist_array.select do |x|
    x if playlist_nam == x[:playlist_title]
  end
end

pp "Selected Rows: #{selected_rows_array}"
# Array structure blueprint
# [row_index, [VIDEO NAME, TUTORIAL NAME, TOPIC NAME], eng_video_id, [playlist_id, playlist_title]]
selected_rows_array.each do |row|
  row[1] = Help.i18n_video_title(row[1])

  # Prepare playlist name & check if it already exists.
  playlist_name = if "#{row[1][1]} | #{row[1][2]}".length <= 150
                    "#{row[1][1]} | #{row[1][2]}"
                  elsif row[1][1].length <= 150
                    row[1][1]
                  else
                    row[1][2]
                  end
  row[1].delete_at(2)
  # [row_index, [VIDEO NAME, playlist_name], eng_video_id]
  row[1][1] = playlist_name
  puts "\nPlaylist name: #{playlist_name} \n\n"
  selected_playlist = check_if_playlist_exists(playlist_name, @playlist_names.flatten)

  # puts "#{selected_playlist.empty?} TRUE FALSE ? EMPTY? "
  if selected_playlist.empty?
    puts "selected_playlist.empty ********************************************"
    resp = Help.playlists_insert(
      youtube_service,
      Help.create_playlist_options(playlist_name, Settings.global_privacy),
      "snippet, status"
    ).to_h
    selected_playlist = [{
      id: resp[:id], playlist_title: resp[:snippet][:localized][:title]
    }]
  end

  row << selected_playlist.first
end

# Insert Videos in existing playlist
def playlist_items_insert(srvc, properties, part, **params)
  resource = Help.create_resource(properties) # See full sample for function
  params = params.delete_if { |_p, v| v == "" }
  srvc.insert_playlist_item(part, resource, params)
end

puts "*************************************************************************"
puts "Starting to upload #{selected_rows_array.size} internationalized Videos."

def generate_description(
  youtube_service,
  eng_video_id,
  ka_khan_url = "Ka Khan URL",
  eng_khan_url = "Eng Khan URL"
)

  video_text = Help.get_video(
    youtube_service, "snippet, contentDetails", id: eng_video_id
  ).to_h
  description_hash = video_text[:items].first[:snippet][:description] unless video_text[:items].nil?
  # description_regex_old = /^(?=Practice this lesson yourself on KhanAcademy\.org right now:|Watch the next lesson:|Missed the previous lesson\?)(?:Practice this lesson yourself on KhanAcademy\.org right now:\s*(?'practice'.*)\s*)?(?:Watch the next lesson:\s*(?'next'.*)\s*)?(?:Missed the previous lesson\?\s*(?'previous'.*))?/
  description_regex = /^(?:Practice this lesson yourself on KhanAcademy\.org right now:.*\b(?'practice'http\S+\/e\/\S+)|Watch the next lesson:.*\b(?'next'http\S+)|Missed the previous lesson\?.*\b(?'previous'http\S+))/

  # keys --- :practice / :next / :previous
  video_description_regex_hash = description_regex.match(description_hash)
  unless video_description_regex_hash.nil?
    ka_named_captures = video_description_regex_hash.named_captures.each_value do |v|
      v.gsub!(/(www)/, "ka") unless v.nil?
    end
  end

  ka_practice = unless ka_named_captures.nil? || ka_named_captures["practice"].nil?
                  "ივარჯიშე ამაში ხანის აკადემიაზე: #{ka_named_captures['practice']}"
                end
  ka_next_video = unless ka_named_captures.nil? || ka_named_captures["next"].nil?
                    "უყურე შემდეგ გაკვეთილს: #{ka_named_captures['next']}"
                  end
  ka_video_on_khan = "ეს ვიდეო ხანის აკადემიაზე: #{ka_khan_url}"
  eng_video_on_khan = "ინგლისური: #{eng_khan_url}"
  ka_prev_video = unless ka_named_captures.nil? || ka_named_captures["previous"].nil?
                    "წინა გაკვეთილი გამოტოვე? შეგიძლია აქ ნახო: #{ka_named_captures['previous']}"
                  end

  "#{ka_practice}

  #{ka_next_video}

  #{ka_video_on_khan}

  #{eng_video_on_khan}

  #{ka_prev_video}\n

  ---

  ხანის აკადემია გთავაზობთ პრაქტიკულ სავარჯიშოებს, ვიდეო ინსტრუქციებს და პერსონიფიცირებულ სასწავლო პლატფორმას, რაც მოსწავლეებს საშუალებას აძლევს ისწავლონ საკუთარ ტემპში საკლასო ოთახში და მის გარეთ. ჩვენთან შეგიძლიათ ისწავლოთ მათემატიკა, ზუსტი მეცნიერებები, პროგრამირება, ისტორია, ხელოვნების ისტორია, ეკონომიკა და ბევრი სხვა რამ. ჩვენი მათემათიკის პროგრამა საწყისი დონიდან კალკუსამდე მიგიყვანთ – თანამედროვე ადაპტური ტექნოლოგიის გამოყენებით, რომელიც განსაზღვრავს მოსწავლის ძლიერ და სუსტ მხარეებს. ჩვენ ასევე ვთანამშრომლობთ ისეთ ორგანიზაციებთან, როგორიცაა NASA, Pixar, თანამედროვე ხელოვნების მუზეუმი, მეცნიერებათა კალიფორნიული აკადემია და მასაჩუსეტსის ტექნოლოგიის ინსტიტუტი და შედეგად, გთავაზობთ მათ სპეციალიზირებულ რესურსებს.

  უფასოდ. ყველასთვის. ყოველთვის.

  გამოიწერე სიახლეები https://www.youtube.com/channel/UC5YZ8qFapX-kgmL4WTtvdWA?sub_confirmation=1"
end

# Main Loop
selected_rows_array.each do |row|
  puts
  puts "Searching for file on Drive by name: #{row[2]}"
  # Find Video on Drive to Upload on Youtube # fields: id, name, mimeType, owners
  response = drive_service.list_files(
    q: "name='#{row[2]}.mp4'",
    spaces: "drive",
    fields: "files(id, name, owners)"
  )
  puts
  puts "Found #{response.files.count} File(s)"
  response.files.each do |file|
    puts "-- ID: #{file.id}"
    puts "--- Name: #{file.name}"
    puts "---- Owner? #{file.owners.first.to_h[:me]}"
    puts
  end

  vid = response.files.map(&:to_h).select { |x| x[:owners].first unless x.nil? }
  vid_name = vid.first[:name]
  vid_id = vid.first[:id]
  puts "This is the name & ID of file owned by you: '#{vid_name}' - '#{vid_id}'"

  puts
  puts "Checking if '#{vid_name}' already exists in '#{download_path}'"
  puts
  if File.file?("#{download_path}#{vid_name}")
    puts "'#{vid_name}' already exists in '#{download_path}'"
  else
    puts "Started Downloading '#{vid_name}'"
    drive_service.get_file(vid_id, download_dest: "#{download_path}#{vid_name}")
    puts "Finished Downloading '#{vid_name}' to '#{download_path}'"
  end
  puts

  vid_title = row[1][0]
  ka_khan_url = row[1][2]
  eng_khan_url = row[1][2].gsub(/(\/\/ka)/, "//www")
  # eng_title = /<title>(.+?) \(video\)/.match(
  #   `curl #{eng_khan_url} | grep "<title>"`
  # ).captures.first

  vid_description = generate_description(youtube_service,
                                         row[2], # Eng video id
                                         ka_khan_url,
                                         eng_khan_url)

  begin
    puts "Started Uploading '#{vid_name}'"
    video_upload_resp = Help.insert_video(
      youtube_service,
      Help.create_video_options(vid_title, vid_description, Settings.global_privacy),
      "snippet, status",
      upload_source: "#{download_path}#{vid_name}",
      content_type: "video/mp4",
      options: {
        open_timeout_sec: 300
      }
    )
    puts "Finished Uploading '#{vid_name}'"
  rescue Google::Apis::TransmissionError
    puts "Failed to Upload #{vid_name}"
    next
  end

  uploaded_vid_id = video_upload_resp.to_h[:id]
  ka_vid_url = Settings.youtube_base_url + uploaded_vid_id

  playlist_items_insert(
    youtube_service,
    { "snippet.playlist_id" => row[3][:id],
      "snippet.resource_id.kind" => "youtube#video",
      "snippet.resource_id.video_id" => uploaded_vid_id,
      "snippet.position" => "" },
    "snippet",
    on_behalf_of_content_owner: ""
  )

  # UPDATE K Column (Geo youtube URL)
  k_col_temp = '=HYPERLINK("' + ka_vid_url + '","' + ka_vid_url + '")'
  k_col_data = Help.create_value_range([[k_col_temp]])
  Help.update_range("#{Settings.ka_youtube_url_col}#{row[0]}", k_col_data, spreadsheet_id, sheets_service, "USER_ENTERED")
  # UPDATE M Column (To Upload Status)
  m_col_data = Help.create_value_range([[""]])
  Help.update_range("#{Settings.to_be_uploaded_status}#{row[0]}", m_col_data, spreadsheet_id, sheets_service, "RAW")
end
# Main Loop

puts "Operation Finished."
puts "*************************************************************************"
