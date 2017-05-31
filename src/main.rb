require "googleauth"
require "googleauth/stores/file_token_store"
require "signet"
require "google/apis/sheets_v4"
require "google/apis/youtube_v3"
require "google/apis/drive_v3"
require "json"
require "fileutils"
require "selenium-webdriver"
require "pp"
require "./helpers"

# Setting up Transitional Video Download Dir for Drive Videos
download_path = "#{Dir.home}/google-api-automation/video_transit_dir/"
FileUtils.mkdir_p(download_path)

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
].freeze #######################################################################
YOUTUBE_SCOPE = [
  Google::Apis::YoutubeV3::AUTH_YOUTUBE
].freeze #######################################################################
OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze # for youtube authorization

### Def ### spreadsheet: a gdoc spreadsheet document
### Def ### sheet: spreadsheet contains one more or sheets

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

# spreadsheet/sheet urls, first one will be used to determine the spreadsheet id
sheet_1_url = "https://docs.google.com/spreadsheets/d/1btbbWrx-i99BxMO0ml1IVM2MNvi5iyavJ-rcoL1RPFA/edit#gid=210742017"
# sheet_2_url = "https://docs.google.com/spreadsheets/d/1btbbWrx-i99BxMO0ml1IVM2MNvi5iyavJ-rcoL1RPFA/edit#gid=1393473034"
# if there are multiple sheets, assumes they are in the same spreadsheet
spreadsheet_id = /[-\w]{25,}/.match(sheet_1_url).to_s
# sheet_id s
# sheet_1_id = Help.get_sheet_id(sheet_1_url)
# sheet_2_id = Help.get_sheet_id(sheet_2_url)

# Column Letter to Coordinate
b_col = Help.char_to_ord("B") # Khan Academy URL
d_col = Help.char_to_ord("D") # ENG Youtube URL
m_col = Help.char_to_ord("M") # Geo youtube URL (for youtube upload status)

global_privacy = "public"
first_row = 2
range = Help.create_range("A", first_row, "W", 100) # Example: "Sheet1!A3:C10"

# Rows that have videos that haven't been uploaded
response_range_array = Help.get_range(
  range,
  spreadsheet_id,
  sheets_service
).values

# [row_index, khan_url, eng_video_id]
selected_rows_array = []
response_range_array.each.with_index(first_row) do |row, index|
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

def check_if_playlist_exists(playlist_nam, youtube_service)
  # LIST OWN PLAYLISTS
  list_own_playlists_resposne = Help.list_own_playlists(
    youtube_service,
    "contentDetails, snippet", # "contentDetails, snippet"
    # mine: true
    channel_id: "UCzehYjthdnt9QvoC_Hd6zcQ"
  ).to_h[:items].map do |x| # [Playlist ID, Playlist Title]
    [x[:id], x[:snippet][:localized][:title]]
  end
  list_own_playlists_resposne.select do |x|
    x if playlist_nam == x[1]
  end
end

pp selected_rows_array
# [row_index, [VIDEO NAME, TUTORIAL NAME, TOPIC NAME], eng_video_id, [playlist_id, playlist_title]]
selected_rows_array.each_with_index do |row|
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
  puts "Playlist name: #{playlist_name}"

  if check_if_playlist_exists(row[1][1], youtube_service).empty?
    Help.playlists_insert(
      youtube_service,
      Help.create_playlist_options(row[1][1], global_privacy),
      "snippet, status"
    )
  end
  row << check_if_playlist_exists(row[1][1], youtube_service)
end

puts "*************************************************************************"
puts "Starting to upload #{selected_rows_array.size} internationalized Videos."

def playlist_items_insert(srvc, properties, part, **params)
  resource = Help.create_resource(properties) # See full sample for function
  params = params.delete_if { |_p, v| v == "" }
  srvc.insert_playlist_item(part, resource, params)
end

def generate_description(youtube_service,
                         eng_video_id,
                         ka_khan_url = "Ka Khan URL",
                         eng_khan_url = "Eng Khan URL",
                         eng_khan_name = "English Video Name")

  video_text = Help.get_video(
    youtube_service, "snippet, contentDetails", id: eng_video_id
  ).to_h
  description_hash = video_text[:items].first[:snippet][:description] unless video_text[:items].nil?
  description_regex = /^(?=Practice this lesson yourself on KhanAcademy\.org right now:|Watch the next lesson:|Missed the previous lesson\?)(?:Practice this lesson yourself on KhanAcademy\.org right now:\s*(?'practice'.*)\s*)?(?:Watch the next lesson:\s*(?'next'.*)\s*)?(?:Missed the previous lesson\?\s*(?'previous'.*))?/

  # keys --- :practice / :next / :previous
  video_description_regex_hash = description_regex.match(description_hash)

  unless video_description_regex_hash.nil?
    ka_named_captures = video_description_regex_hash.named_captures.each do |_k, v|
      v.gsub(/(www)/, "ka") unless v.nil?
    end
  end

  ka_practice = unless ka_named_captures.nil? || ka_named_captures["practice"].nil?
                  "ივარჯიშე ამაში ხანის აკადემიაზე: #{ka_named_captures['practice']}"
                end

  ka_next_video = unless ka_named_captures.nil? || ka_named_captures["next"].nil?
                    "უყურე შემდეგ გაკვეთილს: #{ka_named_captures['next']}"
                  end

  ka_video_on_khan = "ეს ვიდეო ხანის აკადემიაზე: #{ka_khan_url}"

  eng_video_on_khan = "ინგლისური: #{eng_khan_name} #{eng_khan_url}"

  ka_prev_video = unless ka_named_captures.nil? || ka_named_captures["previous"].nil?
                    "წინა გაკვეთილი გამოტოვე? შეგიძლია აქ ნახო: #{ka_named_captures['previous']}"
                  end

  "#{ka_practice}

  #{ka_next_video}

  #{ka_video_on_khan}

  #{eng_video_on_khan}

  #{ka_prev_video}

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
  pp response.to_h

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
  eng_title = /<title>(.+?) \(video\)/.match(
    `curl #{eng_khan_url} | grep "<title>"`
  ).captures.first

  vid_description = generate_description(youtube_service,
                                         row[2], # Eng video id
                                         ka_khan_url,
                                         eng_khan_url,
                                         eng_title)

  begin
    puts "Started Uploading '#{vid_name}'"
    video_upload_resp = Help.insert_video(
      youtube_service,
      Help.create_video_options(vid_title, vid_description, global_privacy),
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

  youtube_base_url = "https://youtu.be/"
  uploaded_vid_id = video_upload_resp.to_h[:id]
  ka_vid_url = youtube_base_url + uploaded_vid_id

  # UPDATE K Column (Geo youtube URL)
  k_col_temp = '=HYPERLINK("' + ka_vid_url + '","' + ka_vid_url + '")'
  k_col_data = Help.create_value_range([[k_col_temp]])
  Help.update_range("K#{row[0]}", k_col_data, spreadsheet_id, sheets_service, "USER_ENTERED")

  playlist_items_insert(
    youtube_service,
    { "snippet.playlist_id" => row[3][0],
      "snippet.resource_id.kind" => "youtube#video",
      "snippet.resource_id.video_id" => uploaded_vid_id,
      "snippet.position" => "" },
    "snippet",
    on_behalf_of_content_owner: ""
  )
end # Main Loop

puts "Operation Finished."
puts "*************************************************************************"

# YOUTUBE CALLS
################################################################################
# testing filename rmYlCuiC5uY.mp4

# # Upload Video
# vid_title = "some title"
# vid_description = "Description of uploaded video."
# global_privacy = global_privacy # public/private

# options = {
#   "snippet.category_id" => "22",
#   "snippet.default_language" => "",
#   "snippet.description" => vid_description,
#   "snippet.tags[]" => "",
#   "snippet.title" => vid_title,
#   "status.embeddable" => "",
#   "status.license" => "",
#   "status.privacy_status" => global_privacy,
#   "status.public_stats_viewable" => ""
# }

# puts "Started Uploading 'rmYlCuiC5uY.mp4'"
# video_upload_resp = Help.insert_video(
#   youtube_service,
#   options,
#   "snippet, status",
#   upload_source: "#{download_path}rmYlCuiC5uY.mp4",
#   content_type: "video/mp4"
# )
# puts "Finished Uploading 'rmYlCuiC5uY.mp4'"

# # Delete Video
# Help.delete_video(youtube_service, "o_AxX-a5Ujs")


# List Videos by Playlist ID
# Help.list_videos_by_playlist_id(
#   youtube_service,
#   "contentDetails",
#   max_results: 25,
#   playlist_id: "PLLEU65lrPs9dKZ9r_FoFsOJNpL2ZMbirM"
# )


# LIST OWN PLAYLISTS
# Help.list_own_playlists(youtube_service, 'contentDetails',
#   mine: true,
#   max_results: 25,
#   on_behalf_of_content_owner: '',
#   on_behalf_of_content_owner_channel: '')


# list video
# Help.get_video(youtube_service, "snippet, contentDetails", id: "-2QPNRY39aY")


# GOOGLE DRIVE CALLS
################################################################################
# service = Google::Apis::DriveV3::DriveService.new
# service.authorization = authorize
# List the 10 most recently modified files.
# response = service.list_files
# puts "Files:"
# puts "No files found" if response.files.empty?
#
# response.files.each do |file|
#   puts "#{file.name} (#{file.id})"
# end

# response = service.list_files(
#   q: "name='rmYlCuiC5uY.mp4'",
#   spaces: "drive",
#   fields: "files(id, name, mimeType, owners)"
# )
#
# response.files.each do |file|
#   puts "Found file: #{file.name} #{file.id} #{file.mime_type}"
#   puts "Owner? #{file.owners.first.to_h[:me]}"
# end

# content = service.get_file("0B_Pyk8zLdQSTT1hwSWxROE04dTA", download_dest: "/home/webgen/someFile.mp4")


################################################################################
# UPDATE RANGE
# test_range = "Sheet1!A10:C10"
# update_data = create_value_range([["hello", "hello", "hello"]])
# Help.update_range(test_range, update_data, spreadsheet_id, sheets_service)


################################################################################
# BATCH UPDATE RANGE
# array = [["batch hello", "batch hello", "batch hello", 1,2,3,4,5], [1, "batch 2", "batch 2", "batch 2"]]
# test_range2 = "Sheet1!A11:Z12"
# batch_update_data = []
# batch_update_data << create_value_range(array, test_range2)
# Help.batch_update_ranges(batch_update_data, spreadsheet_id, sheets_service)


################################################################################
# BATCH CLEAR RANGE
# batch_clear_array = ["A10:H13", "A10"] # array of ranges
# Help.batch_clear_ranges(batch_clear_array, spreadsheet_id, sheets_service)


################################################################################
