module Help
  # authorization method
  def self.authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPES, token_store)
    user_id = 1
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end ##########################################################################

  # authorization method
  def self.authorize2
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH2))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH2)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH2)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPES2, token_store)
    user_id = 1
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end ##########################################################################

  # Create Range. (FirstCol & FirstRow : LastCol & LastRow )
  def self.create_range(fc, rf, cl, rl, sheet_name = "Sheet1")
    "#{sheet_name}!#{fc}#{rf}:#{cl}#{rl}"
  end ##########################################################################

  # case insensitive char to ASCII
  def self.char_to_ord(char)
    case char
    when /[A-Z]/ then char.ord - "A".ord # 65
    when /[a-z]/ then char.ord - "a".ord # 97
    else raise "Pass only lower or uppercase English characters."
    end
  end ##########################################################################

  # return sheet id
  def self.get_sheet_id(sheet_url)
    /[#&]gid=([0-9]+)/.match(sheet_url).captures.first
  end ##########################################################################

  # create value range
  # 2D array of values, range (optional)
  def self.create_value_range(vals, rang = nil)
    Google::Apis::SheetsV4::ValueRange.new(values: vals, range: rang)
  end ##########################################################################

  # get method
  # range, spreadsheet_id, SheetsV4::SheetsServ, major_dimension (ROWS*/COLUMNS)
  def self.get_range(range, spr_id, srvc, major_dimension = "ROWS")
    puts "\nStarted Getting Range *********************************************"
    puts "Getting Range: #{range}"
    resp = srvc.get_spreadsheet_values(
      spr_id,
      range,
      major_dimension: major_dimension
    )
    puts "Got: #{resp.to_h[:values].length} Rows"
    puts "Finished Getting Range ********************************************\n"
    resp
  end ##########################################################################

  # update method
  # range, value_range (#create_value_range), spreadsheet_id, SheetsV4::SheetsSe
  def self.update_range(range, value_range, spr_id, srvc, val_inp_opts = "RAW")
    puts "\nStarted Update Range **********************************************"
    puts "Updating #{range}"
    resp = srvc.update_spreadsheet_value(
      spr_id,
      range,
      value_range,
      value_input_option: val_inp_opts
    )
    puts "Updated: #{resp.to_h[:updated_range]}"
    puts "Finished Update Range *********************************************\n"
  end ##########################################################################

  # batch update method
  # batch_data (array of value ranges), spreadsheet_id, SheetsV4::SheetsServ
  def self.batch_update_ranges(batch_data, spr_id, srvc, val_inp_opts = "RAW")
    puts "\nStarted Batch Update Ranges ***************************************"
    body = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new
    body.value_input_option = val_inp_opts
    body.data = batch_data
    resp = srvc.batch_update_values(
      spr_id,
      body
    )
    pp resp.to_h
    puts "Finished Batch Update Ranges **************************************\n"
  end ##########################################################################

  # batch clear method
  # [array of ranges], spreadsheet_id, SheetsV4::SheetsServ
  def self.batch_clear_ranges(ranges, spr_id, srvc)
    puts "\nStarted Batch Clear Ranges ****************************************"
    puts "Clearing Range(s): #{ranges}"
    body = Google::Apis::SheetsV4::BatchClearValuesRequest.new
    body.ranges = ranges
    resp = srvc.batch_clear_values(
      spr_id,
      body
    )
    pp resp.to_h
    puts "Finished Batch Clear Ranges ***************************************\n"
  end ##########################################################################

  # Nokogiri
  # Get Georgian title for the video from Khan Academy's website
  def self.i18n_video_title(khan_url)
    puts "\nStarted Getting Title from Khan ***********************************"
    page = Nokogiri::HTML(open(khan_url), nil, Encoding::UTF_8.to_s)

    title_text = page.css("title")[0].text
    regexed_title = /.*?(?= \()/.match(title_text).to_s
    regexed_title.slice!(0..99) if regexed_title.length > 100
    puts "KA Title: #{regexed_title}"
    puts "Finished Getting Title from Khan **********************************\n"
    regexed_title
  end ##########################################################################

  # Get Video by ID
  def self.get_video(srvc, part, **params)
    puts "\nStarted Getting Video by ID ***************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_videos(part, params)
    pp resp.to_h
    puts "Finished Getting Video by ID **************************************\n"
    resp
  end ##########################################################################

  # Batch Get Videos by IDs
  def self.batch_get_video(srvc, part, **params)
    puts "\nStarted Getting Videos by IDs *************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_videos(part, params)
    pp resp.to_h
    puts "Finished Getting Videos by IDs ************************************\n"
    resp
  end ##########################################################################

  # Delete Video by ID
  def self.delete_video(srvc, id, **params)
    puts "\nStarted Deleting Video by ID **************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.delete_video(id, params)
    puts "Deleted Video by ID: #{id}" if resp
    puts "Finished Deleting Video by ID *************************************\n"
  end ##########################################################################

  # Create Resource Helper for Insert Video Method
  def self.create_resource(properties)
    resource = {}
    properties.each do |prop, value|
      ref = resource
      prop_array = prop.to_s.split(".")
      for p in 0..(prop_array.size - 1)
        is_array = false
        key = prop_array[p]
        if key[-2, 2] == "[]"
          key = key[0...-2]
          is_array = true
        end
        if p == (prop_array.size - 1)
          if is_array
            if value == ""
              ref[key.to_sym] = []
            else
              ref[key.to_sym] = value.split(",")
            end
          elsif value != ""
            ref[key.to_sym] = value
          end
        elsif ref.include?(key.to_sym)
          ref = ref[key.to_sym]
        else
          ref[key.to_sym] = {}
          ref = ref[key.to_sym]
        end
      end
    end
    resource
  end

  # Upload Video
  def self.insert_video(srvc, properties, part, **params)
    puts "\nStarted Inserting Video *******************************************"
    resource = create_resource(properties)
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.insert_video(part, resource, params)
    pp resp.to_h
    puts "Finished Inserting Video ******************************************\n"
    resp
  end ##########################################################################

  # List Own Playlists
  def self.list_own_playlists(srvc, part, **params)
    puts "\nStarted Listing Own Playlists *************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_playlists(part, params)
    pp resp.to_h
    puts "Finished Listing Own Playlists ************************************\n"
    resp
  end ##########################################################################

  # Get Playlist Videos
  def self.list_videos_by_playlist_id(srvc, part, **params)
    puts "\nStarted Listing Playlist Videos ***********************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_playlist_items(part, params)
    pp resp.to_h
    puts "Finished Listing Playlist Videos **********************************\n"
    resp
  end ##########################################################################

end
