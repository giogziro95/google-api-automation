require "rubygems"
require "bundler"
Bundler.require(:default)
require "googleauth/stores/file_token_store"
require "google/apis/sheets_v4"
require "google/apis/youtube_v3"
require "google/apis/drive_v3"
require "bundler/setup"
require "pp"

module Help
  Config.load_and_set_settings(
    "#{Dir.home}/www/google-api-automation/config/settings.yml"
  )

  def self.authorize_youtube(tokens_file, credentials_file, scope)
    client_id = Google::Auth::ClientId.from_file(credentials_file)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: tokens_file)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
    user_id = 1
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " \
           "resulting code after authorization: "
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end
  ##############################################################################

  # authorization method
  def self.authorize(credentials_file, scope)
    credentials = JSON.parse(File.open(credentials_file, "rb").read)
    authorization = Signet::OAuth2::Client.new(
      token_credential_uri: "https://accounts.google.com/o/oauth2/token",
      audience: "https://accounts.google.com/o/oauth2/token",
      scope: scope,
      issuer: credentials["client_id"],
      signing_key: OpenSSL::PKey::RSA.new(credentials["private_key"], nil)
    )
    authorization.fetch_access_token!
    authorization
  end
  ##############################################################################

  # Get Georgian title for the video from Khan Academy's website
  def self.i18n_video_title(khan_url)
    firefox_path = "#{Dir.home}/bin/firefox-nightly"
    firefox_version = `#{firefox_path} -v`.strip
    puts "\nStarted Getting Title from Khan ***********************************"

    Selenium::WebDriver::Firefox.path = firefox_path
    # caps = Selenium::WebDriver::Remote::Capabilities.firefox(
    #   "moz:firefoxOptions" => { args: ["--headless"] }
    # )
    options = Selenium::WebDriver::Firefox::Options.new(args: ["-headless"])

    puts "-Launched headless #{firefox_version} from: #{firefox_path}"

    # headless_gecko = Selenium::WebDriver.for :firefox, desired_capabilities: caps
    headless_gecko = Selenium::WebDriver.for(:firefox, options: options)
    headless_gecko.get(khan_url)

    wait = Selenium::WebDriver::Wait.new(timeout: 20) # seconds

    # VIDEO NAME | TUTORIAL NAME | TOPIC NAME
    topic_tutorial_names = []
    begin
      wait.until do
        topic_tutorial_names << headless_gecko.find_element(
          tag_name: "h1", class: "title_k2aiyo"
        ).text

        topic_tutorial_names << headless_gecko.find_element(
          css: ".navHeader_yr446g"
        ).text.split(/\n+/)[1, 2]
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError => e
      begin
        warn "***Warning, first name fetching method failed, trying second one."
        warn e
        topic_tutorial_names << headless_gecko.find_element(
          css: "#tutorial-content div div div div div div"
        ).text.split(/\n+/)[1, 2]
      rescue Selenium::WebDriver::Error::NoSuchElementError => e
        warn "*********************************************"
        warn "*** warning second name fetching method failed."
        warn e
        warn "*** Contact the local administrator"
      end
    ensure
      headless_gecko.quit
    end

    topic_tutorial_names.flatten!
    topic_tutorial_names[1], topic_tutorial_names[2] =
      topic_tutorial_names[2], topic_tutorial_names[1]

    puts "-Closed headless #{firefox_version} from: #{firefox_path}"
    puts "-Video Name: #{topic_tutorial_names[0]}"
    puts "-SubTopic Name: #{topic_tutorial_names[1]}"
    puts "-------Topic Name: #{topic_tutorial_names[2]}"
    puts "Finished Getting Title from Khan **********************************\n"
    # Insert Ka Khan URL back to array
    topic_tutorial_names << khan_url
  end
  ##############################################################################

  # Create Range. (FirstCol & FirstRow : LastCol & LastRow )
  def self.create_range(fc, rf, cl, rl, sheet_name = "Sheet1")
    "#{sheet_name}!#{fc}#{rf}:#{cl}#{rl}"
  end
  ##############################################################################

  # case insensitive char to ASCII
  def self.char_to_ord(char)
    case char
    when /[A-Z]/ then char.ord - "A".ord # 65
    when /[a-z]/ then char.ord - "a".ord # 97
    else raise "Pass only lower or uppercase English characters."
    end
  end
  ##############################################################################

  # return sheet id
  def self.get_sheet_id(sheet_url)
    /[#&]gid=([0-9]+)/.match(sheet_url).captures.first
  end
  ##############################################################################

  # create value range
  # 2D array of values, range (optional)
  def self.create_value_range(vals, rang = nil)
    Google::Apis::SheetsV4::ValueRange.new(values: vals, range: rang)
  end
  ##############################################################################

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
  end
  ##############################################################################

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
  end
  ##############################################################################

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
  end
  ##############################################################################

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
  end
  ##############################################################################

  # Get Video by ID
  def self.get_video(srvc, part, **params)
    puts "\nStarted Getting Video by ID ***************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_videos(part, params)
    # pp resp.to_h
    puts "Finished Getting Video by ID **************************************\n"
    resp
  end
  ##############################################################################

  # Batch Get Videos by IDs
  def self.batch_get_video(srvc, part, **params)
    puts "\nStarted Getting Videos by IDs *************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_videos(part, params)
    pp resp.to_h
    puts "Finished Getting Videos by IDs ************************************\n"
    resp
  end
  ##############################################################################

  # Delete Video by ID
  def self.delete_video(srvc, id, **params)
    puts "\nStarted Deleting Video by ID **************************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.delete_video(id, params)
    puts "Deleted Video by ID: #{id}" if resp
    puts "Finished Deleting Video by ID *************************************\n"
  end
  ##############################################################################

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

  # CREATE PLAYLIST OPTIONS snippet[description, tags, default_language,
  # embeddable, license, public_stats_viewable...]
  def self.create_video_options(vid_title,
                                vid_description,
                                vid_privacy_status = "private",
                                category_id = "22")
    { "snippet.category_id" => category_id,
      "snippet.description" => vid_description,
      "snippet.title" => vid_title,
      "status.privacy_status" => vid_privacy_status }
  end
  ##############################################################################

  # Upload Video
  def self.insert_video(srvc, properties, part, **params)
    puts "\nStarted Inserting Video *******************************************"
    resource = create_resource(properties)
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.insert_video(part, resource, params)
    # pp resp.to_h
    puts "Finished Inserting Video ******************************************\n"
    resp
  end
  ##############################################################################

  # Get Playlist Videos
  def self.list_videos_by_playlist_id(srvc, part, **params)
    puts "\nStarted Listing Playlist Videos ***********************************"
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.list_playlist_items(part, params)
    # pp resp.to_h
    puts "Finished Listing Playlist Videos **********************************\n"
    resp
  end
  ##############################################################################

  # CREATE PLAYLIST OPTIONS snippet[description, tags, default_language...]
  def self.create_playlist_options(pl_lst_name, prvcy_stat = "private")
    { "snippet.title" => pl_lst_name, "status.privacy_status" => prvcy_stat }
  end
  ##############################################################################

  # Create Playlist
  def self.playlists_insert(srvc, properties, part, **params)
    puts "\nStarted creating Playlist *****************************************"
    resource = Help.create_resource(properties) # See full sample for function
    params = params.delete_if { |_p, v| v == "" }
    resp = srvc.insert_playlist(part, resource, params)
    puts "Finished creating Playlist ****************************************\n"
    resp
  end
  ##############################################################################
end
