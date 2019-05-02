# lita-slack-jira-hockeyapp
A Lita plugin to respond to hockeyapp webhook crashes and find duplicates via slack.

### Make sure to setup these configs:
```
export SLACK_TOKEN=<slack token>

export HOCKEYAPP_TOKEN=<hockeyapp token>
export HOCKEYAPP_URL=<hockeyapp site url>
export HOCKEYAPP_TOPN_CRASHES=number <top number of crashes to update counts for>
export HOCKEYAPP_MASTER_APP_IDS='{"app1_id": "id1", "app2_id": "id2"}' <app ids of master app version>
export PACKAGE_APPS='{"app1": "package-app1", "app2": "package-app2"}' <name package apps of project>
export JIRA_SITE=<jira site url>
export JIRA_TIMEOUT=<read timeout>
export JIRA_USERNAME=<jira username>
export JIRA_PASSWORD=<jira password>
export JIRA_COMPONENTS="crashes,errors,release checklist"
export JIRA_PROJECTS="{'TestApp1'=>'TA1','TestApp2'=>'TA2',}" <hash of HockeyApp project to JIRA project Keys>
export JIRA_PROJECT_OPEN_TRANSITIONS="{'TA1'=>'101','TA2'=>'341',}"
export JIRA_PROJECT_CLOSE_TRANSITIONS="{'TA1'=>'101','TA2'=>'341',}"
export STR_EXCLUDES="this piece of text, that piece of text" <any location or reason strings you want to exlcude>
export CLOSE_TICKET_TIMEOUT="7"
export JIRA_MAX_RESULTS="1000"
export VIP_CATEGORY_COLUMN="{'name'=>'NAME','value1'=>['VALUE_ID1','VALUE_ID2']}" <name of vip category field on jira and its value>
export CRASHES_FILTER="{'crash-name1'=>id1,'crash-name2'=>id2}" <the filtered issues name and its id>
export EZ_SITE=<ezofficeinventory site url>
export EZ_TOKEN=<ezofficeinventory token>

#For cherry_pick functionality
export GIT_URI_OD=<git overdrive>
export GIT_URI_COZMO=<git cozmo>
export GIT_TOKEN=<token of github>
export GIT_API_URI_VECTOR=<git api vector>

export TEAMCITY_URI=<link build teamcity>
export TEAMCITY_INFO="{'TestApp1'=>['TA1','TA2','TA3'], 'TestApp2'=>['TA1','TA2','TA3'],}"

export MODE_TOKEN=<mode token>
export MODE_PASSWORD=<mode password>
export MODE_TIME_WAIT="5400"
export EMAIL_USERNAME="<gmail username, the results reports will be sent from this email address>
export EMAIL_PASSWORD=<anki gmail password>
export LABELS="triage"
export LOG_WARNING="NO"
export OD_PROD_OCCURENCE_THRESHOLD="1000"
export OD_DEV_OCCURENCE_THRESHOLD="1000"
export COZMO_PROD_OCCURENCE_THRESHOLD="1000"
export COZMO_DEV_OCCURENCE_THRESHOLD="1000"
export OD_DEV_MODE_URL="https://modeanalytics.com/anki/reports/deb8d35a9ac1?param_period=PERIOD&run=now"
export OD_PROD_MODE_URL="https://modeanalytics.com/anki/reports/30dd44e348c0?param_period=PERIOD&run=now"
export COZMO_DEV_MODE_URL="https://modeanalytics.com/anki/reports/26ede1626769?param_period=PERIOD&run=now"
export COZMO_PROD_MODE_URL="https://modeanalytics.com/anki/reports/170693d790ba?param_period=PERIOD&run=now"
export COZMO_DEV_MODE_URL_SPECIFIC_ERROR="https://modeanalytics.com/anki/reports/7c043203af6c"
export OD_DEV_MODE_URL_SPECIFIC_ERROR="https://modeanalytics.com/anki/reports/7c043203af6c"
export TO_EMAIL=<list of emails that you want to sent results reports>
export CC_EMAIL=<list of emails that you want to CC results reports, example "email1@gmail.com, email2.gmail.com">
export MODE_REPORT_TIMEOUT="1200"
export DEV_DAS_VERSION_MODE_URL="https://modeanalytics.com/anki/reports/88d38b9bf27c"
export PROD_DAS_VERSION_MODE_URL="https://modeanalytics.com/anki/reports/007c2ebacf18"
export BETA_DAS_VERSION_MODE_URL="https://modeanalytics.com/anki/reports/d8dd0c05c8a4"
export DAS_TABLE_NAME='{"OD": "das.odmessage", "Cozmo": "das.cozmomessage"}'
export QUERY_TIMEOUT="30"
export VECTOR_EVENTS='{"event_1": "mode_link_1", "event_2": "mode_link_2"}'

export UPDATE_SCRIPT="/srv/repos/ansible-bot-deployment/self_update.sh" <location of local update script for the update_bots command>
export ALLOWED_UPDATE_USERS="U17B8V7CZ,U040HGVJJ" <JL and SC unique slack IDs>

export URL_GOOGLEPLAY_API="http://carreto.pt/tools/android-store-version/?package="
export URL_APPLESTORE_API="http://itunes.apple.com/lookup?bundleId="
export RELEASE_PAGE_ID="release page id"
```

### Run mode report for week or day by curl:
```
curl -X POST --data-urlencode 'payload={"channel": "#general", "username": "webhookbot", "parse": "full", "link_names": "1", "text": "<@U0B6Z2K16> mode_report cozmo dev week", "icon_emoji": ":ghost:"}' https://hooks.slack.com/services/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
```

### Sample of Slack commands:
```
@hockey-bot: mode_report overdrive dev day OR mode_report overdrive dev week - Generate Mode email report and log bugs accordingly.
jira <issue> - Shows detailed information for <issue>
@hockey-bot: update_crash_counts - Updates JIRA crash counts for the top crashes in HockeyApp.
@hockey-bot: list_prod_affects_versions - Lists the current Cozmo and Overdrive production app versions
@hockey-bot: update_prod_affects_versions - Updates what Hockeybot thinks the Cozmo and Overdrive production app versions are
```

### Run rspec to execute unit test against specific function:
```
Step 1. Access vagrant ssh in VM
Step 2. Cd to workspace folder: /srv/repos/lita-slack-jira-hockeyapp-mode/workspace
Step 3. Run: bin/rspec <path-to-rpsec-file>
```
