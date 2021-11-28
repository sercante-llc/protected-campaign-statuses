/***
 * This class handles the automation required on Adding/Editing Campaign records
 */
public without sharing class SL_CampaignTriggerHandler {
    //a little poor-man's dependency injection mixed with Singleton pattern
    @TestVisible
    private static SL_CampaignTriggerHandler instance;
    
    private SL_ProtectedCampaignService protectedCampaignService;
    
    public static Boolean bypass=false;

    public static SL_CampaignTriggerHandler getInstance() {
        if(instance==null) instance = new SL_CampaignTriggerHandler();
        return instance;
    }

    public SL_CampaignTriggerHandler() {
        this.protectedCampaignService = SL_ProtectedCampaignService.getInstance();
    }

    public SL_CampaignTriggerHandler(SL_ProtectedCampaignService service) {
        this.protectedCampaignService = service;
    }

    /**
     * Make sure people aren't trying to mess with the value of our Custom Field
     */
    public void onBeforeInsert(List<Campaign> campaigns) {
        if(bypass) return;

        Map<String, List<Protected_Campaign_Status__mdt>> groupedProtectedStatuses = protectedCampaignService.getGroupedProtectedStatuses();

        for(Campaign campaign : campaigns) {
            if(campaign.isClone()) continue; //the rules for the cloned item should follow

            System.debug('Checking to see if the idiot checked it before hand');
            if(campaign.Has_Protected_Campaign_Member_Statuses__c) {
                System.debug('yup they gone done and did it');
                campaign.addError('Has_Protected_Campaign_Member_Statuses__c', 'Don\'t check this box silly');
                continue;
            }
            System.debug('Checking to see if ' + campaign.Name + ' has Protected Member Statuses');
            if(groupedProtectedStatuses.containsKey(campaign.Type)) {
                System.debug('This campaign does have Protected Member Statuses, checking the box');
                campaign.Has_Protected_Campaign_Member_Statuses__c = true;
            }
        }
    }

    /**
     * Let's actually go ahead and set up our new Campaign with the correct Statuses
     */
    public void onAfterInsert(List<Campaign> campaigns) {
        if(bypass) return;
        
        Map<String, List<Protected_Campaign_Status__mdt>> groupedProtectedStatuses = protectedCampaignService.getGroupedProtectedStatuses();
        Set<Id> campaignIdsNeedingStatuses = new Set<Id>();
        for(Campaign campaign : campaigns) {
            if(campaign.Has_Protected_Campaign_Member_Statuses__c) {
                campaignIdsNeedingStatuses.add(campaign.Id);
            }
        }
        
        if(campaignIdsNeedingStatuses.isEmpty()) {
            System.debug('There are no Campaigns being created that have a Protected Type');
            return;
        }
        System.debug('We need to process ' + campaignIdsNeedingStatuses.size() + ' Campaigns to have Protected statuses');

        //get our DML lists ready
        List<CampaignMemberStatus> toUpdate = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> toInsert = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> toDelete = new List<CampaignMemberStatus>();

        //get our Campaigns and CampaignMemberStatuses that Salesforce created
        List<Campaign> campaignsToProcess = protectedCampaignService.getCampaignsWithMemberStatuses(campaignIdsNeedingStatuses);

        for(Campaign campaign : campaignsToProcess) {
            System.debug('Campaign ' + campaign.Name + '\'s type is one that should have Protected statuses');
            List<CampaignMemberStatus> cmsList = campaign.CampaignMemberStatuses;
            System.debug('There are ' + cmsList.size() + ' existing CampaignMemberStatus records for the Campaign');

            //Salesforce Generates 2 by default. the cmsList is sorted DESC by IsDefault field
            //this code is a little brittle, however it should suffice for a while
            CampaignMemberStatus existingDefault   = cmsList.get(0);
            CampaignMemberStatus existingResponded = cmsList.get(1);

            List<Protected_Campaign_Status__mdt> expectedStatuses = groupedProtectedStatuses.get(campaign.Type);
            if(expectedStatuses.size()==1) {
                Protected_Campaign_Status__mdt expectedStatus = expectedStatuses.get(0);
                System.debug('There is only 1 expected CampaignMemberStatus, so it is easy to set this up');
                //we need to be careful about which record we keep, so that we can safely have only 1 record AND make
                //sure it is Default & Responded.

                CampaignMemberStatus desiredRecord = existingDefault;
                CampaignMemberStatus deletedRecord = existingResponded;

                if(expectedStatus.New_Campaign_Member_Status__c == 'Responded') {
                    //now if the only status we want to keep is Responded, we can't keep the "default" record,
                    //so we will keep the old "Responded" record and just set it as default
                    desiredRecord = existingResponded;
                    desiredRecord.IsDefault = true;

                    deletedRecord = existingDefault;
                }
                else {
                    desiredRecord.HasResponded = true;
                    desiredRecord.Label = expectedStatus.New_Campaign_Member_Status__c;
                }

                toUpdate.add(desiredRecord);
                toDelete.add(deletedRecord);
            }
            else {
                System.debug('There is more than 1 expected CampaignMemberStatus, so we need to figure things out');
                //First, process the Default Status
                Boolean processedSent = false;
                Integer sortOrder=3;
                for(Protected_Campaign_Status__mdt expected: expectedStatuses) {
                    System.debug('Checking to see what we need to do with expected status of ' + expected.Label);
                    if(expected.Is_Default__c) {
                        System.debug('It is the default status, updating the system-generated default status to match');
                        existingDefault.Label = expected.New_Campaign_Member_Status__c;
                        existingDefault.HasResponded = expected.Is_Responded__c;

                        System.debug(existingDefault);
                        toUpdate.add(existingDefault);
                    }
                    else {
                        System.debug('It is not the default status, checking to see what we need to do');
                        if(!processedSent) {
                            System.debug('We will update the existing Sent status to match');
                            existingResponded.Label = expected.New_Campaign_Member_Status__c;
                            existingResponded.HasResponded = expected.Is_Responded__c;
                            
                            System.debug(existingResponded);
                            toUpdate.add(existingResponded);
                            processedSent = true;
                        }
                        else {
                            System.debug('We need to create a new Status');
                            CampaignMemberStatus newStatus = new CampaignMemberStatus(
                                CampaignId=campaign.Id, 
                                Label=expected.New_Campaign_Member_Status__c,
                                HasResponded=expected.Is_Responded__c,
                                SortOrder=sortOrder++);
                            
                                System.debug(newStatus);
                            toInsert.add(newStatus);
                        }
                    }
                }
            }
        }

        if(!toUpdate.isEmpty()) {
            System.debug('We are updating ' + toUpdate.size() + ' Status records');
            update toUpdate;
        }
        if(!toInsert.isEmpty()) {
            System.debug('We are inserting ' + toInsert.size() + ' Status records');
            insert toInsert;
        }
        if(!toDelete.isEmpty()) {
            System.debug('We are deleting ' + toDelete.size() + ' Status records');
            delete toDelete;
        }
    }

    /**
     * Make sure people aren't messing with our Has_Protected_Campaign_Member_Statuses__c value.
     */
    public void onBeforeUpdate(List<Campaign> newValues, Map<Id, Campaign> oldValues) {
        if(bypass) return;
        
        for(Campaign campaign : newValues) {
            Campaign oldCampaign = oldValues.get(campaign.Id);
            if(campaign.Has_Protected_Campaign_Member_Statuses__c && (campaign.Type != oldCampaign.Type)) {
                System.debug('Someone tried to change the Type of a Campaign with Has_Protected_Campaign_Member_Statuses__c');
                campaign.addError('Type','Campaign has Protected Campaign Member Statuses. Don\'t change the type.');
            }

            if(campaign.Has_Protected_Campaign_Member_Statuses__c == true && !oldCampaign.Has_Protected_Campaign_Member_Statuses__c) {
                System.debug('Someone tried to re-enable Protected Campaign Member Statuses. We are not equipped to do that so we are preventing it');
                campaign.addError('Has_Protected_Campaign_Member_Statuses__c','Once disabled, cannot be re-enabled.');
            }
        }
    }
}
