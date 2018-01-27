# Khan Academy video upload automation using Google API
This project helps automate the process of uploading Khan Academy internationalized videos to youtube.

## Getting Started
The project assumes the user has two google accounts:

* Google **Docs SpreadSheet** and **Google Drive** owner account
* **Youtube** Khan Channel owner account
* Debian based Linux distribution **(Ubuntu, Linux Mint ...)** (Although any OS will work, several steps in the guide are compatible with Debian based distribution)
* **RVM** and **Ruby** are not installed, installation script takes care of that.
* Following are part of the repository as required parts of the automation script. They will be moved to `~/bin` directory and `symlinked` accordingly:
  * `geckodriver 0.19.1`
  * `firefox 58.0`

##### Setup for Google Drive and Spreadsheet authentication
With first google account, which has access to Drive and SpreadSheet containing required assets, visit: https://console.developers.google.com/projectcreate
create project and name the project appropriately.

Make sure the newly created project is selected before activating these APIs.

* Activate Google Drive API: `https://console.developers.google.com/apis/library/drive.googleapis.com/`
* Activate Google Spreadsheet API: `https://console.developers.google.com/apis/library/sheets.googleapis.com/`

Next visit: `https://console.developers.google.com/apis/credentials` to create authentication credentials.

* Click Create credentials drop-down and select **Service account key**
* Select Service account drop-down and click **New Service Account**
* Input a descriptive **Service account name** and select **role** to be **Project > Owner**  
* Leave **JSON** radion button selected
* Click Create and save the JSON file.
* Rename downloaded JSON file to `client_secrets_server.json` and move it to `~/.google_cred`, where `~/` is the home directory of the linux user.
* Next go to `https://console.developers.google.com/iam-admin/serviceaccounts/`, select the appropriate project and copy the **Service account ID** of the service account, which is a generic email address.
* Now you need to share Google docs spreadsheet with this email the same way you would share any spreadsheet document with a real user, make sure it has edit permissions.
* You will also have to share a Google Drive directory containing internationalized Khan videos with this service account, which then would be temporarily downloaded locally and uploaded to Youtube.

##### Setup for Youtube authentication
With second google account, which has access to Khan Youtube channel, visit: `https://console.developers.google.com/projectcreate`
create project and name the project appropriately.
Make sure the newly created project is selected before activating these APIs.

* Activate Youtube Data API: `https://console.developers.google.com/apis/library/youtube.googleapis.com`

Next visit: `https://console.developers.google.com/apis/credentials` to create authentication credentials.

* Click Create credentials drop-down and select **Service account key**
* Select Service account drop-down and click **New Service Account**
* Input a descriptive **Service account name** and select **role** to be **Project > Owner**  
* Leave **JSON** radion button selected
* Click Create and save the JSON file.
* Rename downloaded JSON file to `youtube_client_secrets_server.json` and move it to `~/.google_cred`, where `~/` is the home directory of the linux user.
* Next go to you will have to setup OAuth credentials for the Youtube authentication. Visit:   `https://console.developers.google.com/apis/credentials/oauthclient`
*
  * If you see this note: `To create an OAuth client ID, you must first     
    set a product name on the consent screen`
  * click `Configure consent screen`
    input Product name into `Product name shown to users` field to be something descriptive, for example: `youtube access for Khan academy's internationalization`.
  * Click `Save`
* Now select `other` under `Application type` radio button list and name it for example `Automation script`
* Click `create` and when you are presented `Oauth client` screen click ok to close it.
* Now a credential should have been added under `OAuth 2.0 client ID`.
* At the end of the row of newly added `OAuth 2.0 client ID` credential, should be a download button that looks like a down arrow, click it and download the file.
* Rename downloaded JSON file to `youtube_client_secrets.json` and move it to `~/.google_cred`, where `~/` is the home directory of the linux user.

### Prerequisites
If sudo sudo is not installed
```
apt-get install sudo
```

Install `wget` so we download installation script
```
sudo apt-get install wget
```

### Installing
Go to home directory, download installation script, make it executable and run it.
<br>
To read more about what the installation script does, please take a look at Installation file: [Install]("docs/install")
```
cd ~/
wget https://github.com/webzorg/google-api-automation/blob/master/docs/install
chmod +x install
./install

```

## Usage
#### Playlist naming rules

Playlist names are created according to the following rules. This is generic structure of the playlist name:

```
TUTORIAL NAME | TOPIC NAME
```

If the resulting name is shorter or equal to 150 characters, than it is left as is and used as a playlist name. If the above condition fails, then if `tutorial name` is less than or equal to 150 characters, it is used as a playlist name. If both of above conditions fail, then `topic name` is used as a playlist name.

  #### Configuring settings
  Edit [settings]("config/settings.yml") file and change the configuration for your needs, it is located in `~/www/google-api-automation/config/settings.yml`. It will serve as a template with existing data.

* #### Unlikely to need customization
  * **tmp_video_download_path:** "/www/google-api-automation/video_transit_dir/"
    <br>`Relative Path to where the videos will be downloaded before being uploaded`
  * **global_privacy:** "public"
    <br>`Scope of the playlists and videos inserted on youtube (public or private)`
  * **youtube_base_url:** "https://youtu.be/"
    <br>`Base URL for the youtube videos`
* #### Likely to need customization
  * **khan_youtube_id:** "UC5YZ8qFapX-kgmL4WTtvdWA"
    <br>`You can extract youtube channel id by going to your Khan channel and copying last part of the url.`
  * **gdoc_sheet_url:**       
    "https://docs.google.com/spreadsheets/d/1XDTcT-w72wnPnXJ0qvc3aFc5fiajrkrf9laaBeUy42w/edit#gid=572850187"
    <br>`Just open the google doc spreadsheet with the right sheet and copy its URL.`
  * **khan_academy_url_col:** "B"
    <br>`Contains link to translated KhanAcademy video page`
  * **eng_youtube_url_col:** "D"
    <br>`Contains link to english version youtube video`
  * **ka_youtube_url_col:** "K"
    <br>`Uploaded translated youtube video link will be inserted here`
  * **to_be_uploaded_status:** "M"
    <br>`Videos to be uploaded will be determined by this column. Only non-empty rows in this column will be selected`
  * **sheet_name:** "new videos to dub"
    <br>`Put name of the appropriate sheet here`

* #### Sheet dimensions
  * **range_starting_col:** "A"
    <br>`First column of the sheet (needs to be first)`
  * **first_row:** 2
    <br>`First row of the sheet (assuming first one is for labels, put 2 here)`
  * **range_ending_col:** "W"
    <br>`Put last column letter here so the needed data is included in the range`
  * **last_row:** 6000
    <br>`Put last row number here, if for example you have 1000 rows of videos, you can put 1001 here, don't forget to change this if you add rows later`

  #### Running Script
  Assuming that you have read project *README*, run script:
  ```
  ruby ~/www/google-api-automation/src/main.rb
  ```   

  Although highly unlikely, if after installing rvm and rebooting pc, ruby is not detected in the terminal. Run this: `source ~/.profile`

## Troubleshooting
  If you have problems using this script that you cannot resolve alone, please open an issue [here]("https://github.com/webzorg/google-api-automation/issues") and I will try help as soon as I can.
  If you think you have found a bug in the program, please read the *Contributing* section.

## Contributing
  As this project is built around pretty custom task and there maybe lots of potential bugs in variety of circumstances, everyone is welcome to contribute to the repository in order to make translated Khan Academy video uploads less tedious. Even if it is just a README optimization/suggestion, please don't hesitate to send a *Pull Request!* or open an [issue]("https://github.com/webzorg/google-api-automation/issues").

## Built With
* * Any OS will work but script is adapted specifically to Debian based distributions     
    ([Ubuntu](https://www.ubuntu.com/download/desktop) is recommended for simplicity)
  * If Running Linux is not viable for you, it is also possible to run this setup script using either [virtualbox]("https://www.virtualbox.org/") or [vmware]("https://www.vmware.com/")
* [RVM](https://rvm.io/) - Ruby Version Manager
* [Ruby](https://www.ruby-lang.org/) - The coolest programming language
* [google-api-client](https://github.com/google/google-api-ruby-client) Ruby gem as a Google API client
* [Firefox](http://firefox.com) Web Browser
* [selenium-webdriver](https://github.com/SeleniumHQ/selenium/tree/master/rb) Ruby gem for programmatically controlling Firefox

## Contributors

## License
This project is licensed under the GNU GENERAL PUBLIC License - see the [LICENSE.md](LICENSE.md) file for details
