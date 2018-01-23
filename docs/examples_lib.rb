# YOUTUBE CALLS
################################################################################
# testing filename rmYlCuiC5uY.mp4

# # Upload Video
vid_title = "some title"
vid_description = "Description of uploaded video."
global_privacy = global_privacy # public/private

options = {
  "snippet.category_id" => "22",
  "snippet.default_language" => "",
  "snippet.description" => vid_description,
  "snippet.tags[]" => "",
  "snippet.title" => vid_title,
  "status.embeddable" => "",
  "status.license" => "",
  "status.privacy_status" => global_privacy,
  "status.public_stats_viewable" => ""
}

puts "Started Uploading 'rmYlCuiC5uY.mp4'"
video_upload_resp = Help.insert_video(
  youtube_service,
  options,
  "snippet, status",
  upload_source: "#{download_path}rmYlCuiC5uY.mp4",
  content_type: "video/mp4"
)
puts "Finished Uploading 'rmYlCuiC5uY.mp4'"

# Delete Video
Help.delete_video(youtube_service, "o_AxX-a5Ujs")

# List Videos by Playlist ID
Help.list_videos_by_playlist_id(
  youtube_service,
  "contentDetails",
  max_results: 25,
  playlist_id: "PLLEU65lrPs9dKZ9r_FoFsOJNpL2ZMbirM"
)

# LIST OWN PLAYLISTS
Help.list_own_playlists(
  youtube_service,
  "contentDetails",
  mine: true,
  max_results: 25,
  on_behalf_of_content_owner: "",
  on_behalf_of_content_owner_channel: ""
)

# list video
Help.get_video(youtube_service, "snippet, contentDetails", id: "-2QPNRY39aY")

# GOOGLE DRIVE CALLS
################################################################################
service = Google::Apis::DriveV3::DriveService.new
service.authorization = authorize
# List the 10 most recently modified files.
response = service.list_files
puts "Files:"
puts "No files found" if response.files.empty?

response.files.each do |file|
  puts "#{file.name} (#{file.id})"
end

response = service.list_files(
  q: "name='rmYlCuiC5uY.mp4'",
  spaces: "drive",
  fields: "files(id, name, mimeType, owners)"
)

response.files.each do |file|
  puts "Found file: #{file.name} #{file.id} #{file.mime_type}"
  puts "Owner? #{file.owners.first.to_h[:me]}"
end

content = service.get_file("0B_Pyk8zLdQSTT1hwSWxROE04dTA", download_dest: "/home/webgen/someFile.mp4")

################################################################################
# UPDATE RANGE
test_range = "Sheet1!A10:C10"
update_data = create_value_range([%w[hello hello hello]])
Help.update_range(test_range, update_data, spreadsheet_id, sheets_service)

################################################################################
# BATCH UPDATE RANGE
array = [["batch hello", "batch hello", "batch hello", 1, 2, 3, 4, 5], [1, "batch 2", "batch 2", "batch 2"]]
test_range2 = "Sheet1!A11:Z12"
batch_update_data = []
batch_update_data << create_value_range(array, test_range2)
Help.batch_update_ranges(batch_update_data, spreadsheet_id, sheets_service)

################################################################################
# BATCH CLEAR RANGE
batch_clear_array = ["A10:H13", "A10"] # array of ranges
Help.batch_clear_ranges(batch_clear_array, spreadsheet_id, sheets_service)

################################################################################
