require "googleauth"
require "googleauth/stores/file_token_store"
require "google/apis/sheets_v4"
require "google/apis/youtube_v3"
require "google/apis/drive_v3"

require "json"

require "fileutils"

require "rubygems"
require "nokogiri"
require "open-uri"

require "pp"
require "./helpers"

# path to client_secrets.json & tokens.yaml & SCOPES
CLIENT_SECRETS_PATH = File.join(Dir.home, "client_secrets.json")
CLIENT_SECRETS_PATH2 = File.join(Dir.home, "educare-test-credentials.json")
CREDENTIALS_PATH = File.join(Dir.home, ".google_credentials", "tokens.yaml")
CREDENTIALS_PATH2 = File.join(Dir.home, "tokens.yaml")
OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze

SCOPES = [
  Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
  Google::Apis::YoutubeV3::AUTH_YOUTUBE_UPLOAD,
  Google::Apis::DriveV3::AUTH_DRIVE
].freeze #######################################################################

SCOPES2 = [
  Google::Apis::YoutubeV3::AUTH_YOUTUBE
].freeze #######################################################################

# Setting up Transitional Video Download Dir
download_dir_path = "/Downloads"
download_path = "#{Dir.home}#{download_dir_path}/VideoTransitDir/"
FileUtils.mkdir_p(download_path)

### Def ### spreadsheet: a gdoc spreadsheet document
### Def ### sheet: spreadsheet contains one more or sheets
### Range Example: "Sheet1!A3:C10"

# Sheet V4 Service
sheets_service = Google::Apis::SheetsV4::SheetsService.new
sheets_service.authorization = Help.authorize

# Drive V3 Service
drive_service = Google::Apis::DriveV3::DriveService.new
drive_service.authorization = Help.authorize

# Youtube V3 Service
youtube_service = Google::Apis::YoutubeV3::YouTubeService.new
youtube_service.authorization = Help.authorize2

# spreadsheet/sheet urls, first one will be used to determine the spreadsheet id
sheet_1_url = "https://docs.google.com/spreadsheets/d/1btbbWrx-i99BxMO0ml1IVM2MNvi5iyavJ-rcoL1RPFA/edit#gid=210742017"
sheet_2_url = "https://docs.google.com/spreadsheets/d/1btbbWrx-i99BxMO0ml1IVM2MNvi5iyavJ-rcoL1RPFA/edit#gid=1393473034"
# if there are multiple sheets, assumes they are in the same spreadsheet
spreadsheet_id = /[-\w]{25,}/.match(sheet_1_url).to_s
# sheet_id s
sheet_1_id = Help.get_sheet_id(sheet_1_url)
sheet_2_id = Help.get_sheet_id(sheet_2_url)

# Column Letter to Coordinate
b_col = Help.char_to_ord("B") # Khan Academy URL
d_col = Help.char_to_ord("D") # ENG Youtube URL
m_col = Help.char_to_ord("M") # upload status

first_row = 2
range = Help.create_range("A", first_row, "W", 100)

# Rows that have videos that haven't been uploaded
response_range_array = Help.get_range(
  range,
  spreadsheet_id,
  sheets_service
).values

# 0:index 1:khan_url 2:eng_video_id
selected_rows_array = []
response_range_array.each.with_index(first_row) do |row, index|
  # Ka Khan Academy Video URL
  khan_url = row[b_col] # Column B

  # Get english Video ID from Column D
  eng_video_regex = /.*\/(.+)/.match(row[d_col])
  eng_video_id = eng_video_regex.captures.first unless eng_video_regex.nil?

  # Add needed info to "selected_rows_array"
  if (row[m_col].empty? unless row[m_col].nil?)
    selected_rows_array << [index, khan_url, eng_video_id]
  end
end

puts "*************************************************************************"
puts "Starting to upload #{selected_rows_array.size} internationalized Videos."
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
  puts "Found #{response.files.count} Files"
  response.files.each do |file|
    puts "-- ID: #{file.id}"
    puts "--- Name: #{file.name}"
    puts "---- Owner? #{file.owners.first.to_h[:me]}"
    puts
  end

  vid = response.files.map(&:to_h).select { |x| x[:owners].first[:me] }
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

  vid_title = Help.i18n_video_title(row[1])
  vid_description = "Description of uploaded video."
  vid_privacy_status = "private" # public/private

  options = {
    "snippet.category_id" => "22",
    "snippet.default_language" => "",
    "snippet.description" => vid_description,
    "snippet.tags[]" => "",
    "snippet.title" => vid_title,
    "status.embeddable" => "",
    "status.license" => "",
    "status.privacy_status" => vid_privacy_status,
    "status.public_stats_viewable" => ""
  }

  begin
    puts "Started Uploading '#{vid_name}'"
    video_upload_resp = Help.insert_video(
      youtube_service,
      options,
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

  # UPDATE M Column (Video Upload Status)
  m_col_data = Help.create_value_range([["✓"]])
  Help.update_range("M#{row[0]}", m_col_data, spreadsheet_id, sheets_service, "RAW")
end # Main Loop

puts "Operation Finished."
puts "*************************************************************************"

# YOUTUBE CALLS
################################################################################
# testing filename rmYlCuiC5uY.mp4

# # Upload Video
# vid_title = "some title"
# vid_description = "Description of uploaded video."
# vid_privacy_status = "private" # public/private

# options = {
#   "snippet.category_id" => "22",
#   "snippet.default_language" => "",
#   "snippet.description" => vid_description,
#   "snippet.tags[]" => "",
#   "snippet.title" => vid_title,
#   "status.embeddable" => "",
#   "status.license" => "",
#   "status.privacy_status" => vid_privacy_status,
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
# GET GEORGIAN NAME OF THE VIDEO
# khan_url = "https://ka.khanacademy.org/math/algebra2/rational-expressions-equations-and-functions/multiplying-and-dividing-rational-expressions/v/multiplying-and-dividing-rational-expressions-3"
# EducareHelper.i18n_video_title(khan_url)
