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
            Integer respondedCount=0;
            Integer defaultCount=0;
            Integer totalCount = expectedStatuses.size();
            Boolean respondedIsAlsoDefault=false;

            for(Protected_Campaign_Status__mdt expected : expectedStatuses) {
                if(expected.Is_Default__c) defaultCount++;
                if(expected.Is_Responded__c) respondedCount++;
                if(expected.Is_Default__c && expected.Is_Responded__c) respondedIsAlsoDefault=true;
            }
            // a little validation
            if(defaultCount != 1) campaign.addError('There should be only 1 expected default status, please adjust Protected Campaign Member Status configuration');
            if(respondedCount < 0) campaign.addError('There should be at least 1 responded status, please adjust Protected Campaign Member Status configuration');
            Integer sortOrder=3;

            for(Protected_Campaign_Status__mdt expected: expectedStatuses) {
                System.debug('Checking to see what we need to do with expected status of ' + expected.Label);
                if(totalCount==1) {
                    System.debug('There is only 1 expected CampaignMemberStatus, so it is easy to set this up');
                    
                    existingResponded.IsDefault = true;
                    existingResponded.Label = expected.New_Campaign_Member_Status__c;
                    System.debug(existingResponded);
                    toUpdate.add(existingResponded);
                    toDelete.add(existingDefault);
                    break; // there are no more expected statuses, break out of the for loop
                }

                if(totalCount>1 && respondedIsAlsoDefault && toUpdate.isEmpty()) {
                    System.debug('There is more than 1 expected status, and this status is both responded & default');
                    existingResponded.isDefault=true;
                    existingResponded.Label = expected.New_Campaign_Member_Status__c;
                    existingResponded.HasResponded = true;
                    System.debug(existingResponded);
                    toUpdate.add(existingResponded);
                    continue;//we want to process the next expected status
                }
                else if(totalCount > 1 && toUpdate.isEmpty()) {
                    System.debug('There is more than 1 expected status, and this one is default and not responded');
                    existingDefault.Label = expected.New_Campaign_Member_Status__c;
                    System.debug(existingDefault);
                    toUpdate.add(existingDefault);
                    continue;//we want to process the next expected status
                }

                // this record doesn't fall into either of the special scenarios above
                // but may be impacted by one of them
                System.debug('It is not the default status, checking to see what we need to do');
                if(toUpdate.size()==1) { // the default record has already been processed
                    System.debug('We will update the other pre-made status to match');
                    CampaignMemberStatus targetRecord = respondedIsAlsoDefault?existingDefault:existingResponded;
                    targetRecord.Label = expected.New_Campaign_Member_Status__c;
                    targetRecord.HasResponded = expected.Is_Responded__c;
                    targetRecord.IsDefault=false;
                    
                    System.debug(targetRecord);
                    toUpdate.add(targetRecord);
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
