# Protected Campaign Statuses
This Unlocked Package was developed for Marketing Admins who want to enforce the Campaign Member Status options for Campaigns of certain types.

> This application is designed to run on the Salesforce Platform

## Table of contents
- [What You Get](#what-you-get)
- [Installing the Unlocked Package Directly (Recommended)](#installing-the-unlocked-package-directly)
- [Pushing Code to a Sandbox org](#pushing-code-to-a-sandbox-org)
- [Post-Install Configuration](#post-install-configuration)
- [Installing into a Scratch Org](#installing-into-a-scratch-org)
- [How it Works](#how-it-works)
## What You Get
When deploying this package to your org, you will get:
- 1 Custom Metadata Type (and page layout)
- 1 Campaign Custom Field
- 1 ChangeDataCapture configuration
- 2 APEX Triggers
- 5 Production APEX Classes
- 3 APEX Test Classes

## Installing the Unlocked Package Directly
Setup is a bit more of a breeze when you install the Package.

1. Install Unlocked Package (for Admins Only)
    - [Product Installation URL](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t5G000004J3FnQAK)
    - [Sandbox Installation URL](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t5G000004J3FnQAK)

1. Continue with [Post-Install Configuration](#post-install-configuration)
## Pushing Code to a Sandbox org

Follow this set of instructions if you want to deploy the solution into your org without using an Unlocked Package. This will require a Sandbox, and then a ChangeSet to deploy into Production.

1. If you know about and use `git`, clone this repository

    ```
    git clone https://github.com/sercante-llc/protected-campaign-statuses.git
    cd protected-campaign-statuses
    ```

    **or**

    1. [Download a zip file](https://github.com/sercante-llc/protected-campaign-statuses/archive/master.zip)
    1. Extract the contents
    1. Navigate to the directory (sample commands below, though it may be different for you depending where you downlaod things)

    ```
    cd Downloads/protected-campaign-statuses-master/protected-campaign-statuses-master
    ```
    4. Verify you are in the same directory as the sfdx-project.json file
    ```
    # mac or Linux
    ls 

    # windows
    dir
    ```

1. Setup your environment
    - [Install Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm)

1. Authorize your Salesforce org and provide it with an alias (**myorg** in the commands below)
    ```
    # Connect SFDX to a Sandbox Org
    sfdx force:auth:web:login -s -a myorg -r https://test.salesforce.com

    # if for some reason you need to specify a specific URL, use this slightly altered command, making the correct adjustments
    sfdx force:auth:web:login -s -a myorg -r https://mycompanyloginurl.my.salesforce.com
    ```

1. Run this command in a terminal to deploy the reports and dashboards
    ```
    sfdx force:source:deploy -p "force-app/main/default" -u myorg
    ```
1. Continue with [Post-Install Configuration](#post-install-configuration)
## Post-Install Configuration

1. Once installed, create some Protected Statuses
    1. Log in to Salesforce Lightning, go to Setup
    1. Navigate to Custom Metadata Types, click Manage Records for Protected Campaign Status
    1. To create your first ones, click New
    1. Fill in the various fields
        1. Label: Used in the List of Campaign Statuses in the Setup view in step 3 above. Recommended convention:  TYPE-STATUS
        1. Name: This is an API name that can be used by developers. Not required by this package. Recommended: let this autofill after you type in the Label
        1. Campaign Type: This is the actual value for the Campaign’s Type field.
        1. Protected Status: This is the Status value that will become protected
        1. Is Default: Select this if this Status should be the default (please pick only 1 per Type)
        1. Is Responded: Select this if this Status should be marked as Responded
    1. Click Save (or Save & New) and repeat a whole bunch
1. Create a scheduled job to restore deleted protected statuses
    1. Back in Setup, go to Apex Classes and click Schedule Apex
    1. Fill in the few fields
        1. Job Name: give this a nice descriptive name so you remember what it is in 3 months
        1. Apex Class: SL_ProtectedCampaignStatusJob
        1. Frequency: set this to what works for you. We recommend running this daily during off-peak hours
        1. Start: today
        1. End: some time in the distant future
        1. Preferred Start Time: off peak hours

Once you have provided your statuses, you are good to go. Give it a whirl by creating a new Campaign with the Type that you have set up. Then take a look at the Statuses already created.

## Installing into a Scratch Org
1. Set up your environment. The steps include:

    - Enable Dev Hub in your org
    - [Install Salesforce CLI](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm)

1. If you haven't already done so, authorize your hub org and provide it with an alias (**myhuborg** in the command below):

    ```
    sfdx force:auth:web:login -d -a myhuborg
    ```

1. If you know about and use `git`, clone this repository

    ```
    git clone https://github.com/sercante-llc/protected-campaign-statuses.git
    cd protected-campaign-statuses
    ```

    **or**

    1. [Download a zip file](https://github.com/sercante-llc/protected-campaign-statuses/archive/master.zip)
    1. Extract the contents
    1. Navigate to the directory (sample commands below, though it may be different for you depending where you downlaod things)

    ```
    cd Downloads/protected-campaign-statuses-master/protected-campaign-statuses-master
    ```
    4. Verify you are in the same directory as the sfdx-project.json file
    ```
    # mac or Linux
    ls 

    # windows
    dir
    ```

1. Create a scratch org and provide it with an alias (**protectedstatuses** in the command below):

    ```
    sfdx force:org:create -s -f config/project-scratch-def.json -a protectedstatuses
    ```

1. Push the Source to the org
    ```
    sfdx force:source:push -u protectedstatuses
    ```

1. Open the scratch org:

    ```
    sfdx force:org:open
    ```

1. Continue with [Post-Install Configuration](#post-install-configuration)

## How it Works
Once everything is set up (above), Campaigns should maintain a consistent set of Campaign Member Statuses. Here's how we accomplish that.

### New Campaign Created
When a new Campaign is created, we check to see if the Type of Campaign is defined in any of the Protected Campaign Member Status records (the Custom Metadata Type that was set up earlier). If there is a match, the solution will:
1. Automatically add a checkbox to the Campaign Custom Field "Has Protected Campaign Statuses".
1. Automatically adjust the CampaignMemberStatus records to match all Protected Campaign Member Statuses expected

### Editing a Protected Campaign Status
For a Campaign that "Has Protected Campaign Statuses", when one of the CampaignMemberStatus records is edited we will double check all statuses of that Campaign to make sure that all Protected ones still exist. If there are any missing, they will be recreated almost instantly (you may need to refresh the page for them to show up if there's a delay).

### Removing a Protected Campaign Status
If a user removes a Protected Campaign Status, the Scheduled Job (that was created as part of [Post-Install Configuration](#post-install-configuration)) will search for Campaigns missing a Status and recreate it.

## FAQ

### Why Don't you just prevent people from messing around with Protected Statuses?
We really wish we could. A "before update" and "before delete" APEX Trigger would be the simplest way to handle this. Unfortunately, APEX Triggers are not (yet) possible on CampaignMemberStatus records, so we end up having to fix it after-the-fact.