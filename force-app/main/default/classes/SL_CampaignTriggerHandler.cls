public without sharing class SL_CampaignTriggerHandler {
    public static void onBeforeInsert(List<Campaign> campaigns) {
        Map<String, List<Protected_Campaign_Status__mdt>> groupedProtectedStatuses = getGroupedProtectedStatuses();

        for(Campaign campaign : campaigns) {
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

    public static void onAfterInsert(List<Campaign> campaigns) {
        Map<String, List<Protected_Campaign_Status__mdt>> groupedProtectedStatuses = getGroupedProtectedStatuses();
        List<Id> campaignIdsNeedingStatuses = new List<Id>();
        for(Campaign campaign : campaigns) {
            if(campaign.Has_Protected_Campaign_Member_Statuses__c) {
                campaignIdsNeedingStatuses.add(campaign.Id);
            }
        }
        
        if(campaignIdsNeedingStatuses.isEmpty()) return;
        System.debug('We need to process ' + campaignIdsNeedingStatuses.size() + ' Campaigns to have Protected statuses');

        //get our DML lists ready
        List<CampaignMemberStatus> toUpdate = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> toInsert = new List<CampaignMemberStatus>();
        List<CampaignMemberStatus> toDelete = new List<CampaignMemberStatus>();
        Map<Id, List<CampaignMemberStatus>> existingStatuses = getGroupedCampaignMemberStatusesByCampaignId(campaignIdsNeedingStatuses);

        for(Campaign campaign : campaigns) {
            System.debug('Campaign ' + campaign.Name + '\' type is one that should have Protected statuses');
            List<CampaignMemberStatus> cmsList = existingStatuses.get(campaign.Id);
            System.debug('There are ' + cmsList.size() + ' existing CampaignMemberStatus records for the Campaign');

            //first lets see if the default status matches
            CampaignMemberStatus existingResponded = null;
            CampaignMemberStatus existingDefault = null;
            existingDefault=cmsList.get(0); //Salesforce Generates 2 by default. the cmsList is sorted DESC by IsDefault field
            existingResponded=cmsList.get(1);

            List<Protected_Campaign_Status__mdt> expectedStatuses = groupedProtectedStatuses.get(campaign.Type);
            if(expectedStatuses.size()==1) {
                System.debug('There is only 1 expected CampaignMemberStatus, so it is easy to set this up');
                CampaignMemberStatus desiredRecord = existingDefault;
                CampaignMemberStatus deletedRecord = existingResponded;

                if(expectedStatuses.get(0).New_Campaign_Member_Status__c == 'Responded') {
                    desiredRecord = existingResponded;
                    desiredRecord.IsDefault = true;

                    deletedRecord = existingDefault;
                }
                desiredRecord.HasResponded = true;
                desiredRecord.Label = expectedStatuses.get(0).New_Campaign_Member_Status__c;
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

    public static void onBeforeUpdate(List<Campaign> newValues, Map<Id, Campaign> oldValues) {
        System.debug('onBeforeUpdate?');
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

    private static Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
        List<Protected_Campaign_Status__mdt> protectedStatuses = [
            SELECT Label, Campaign_Type__c, Original_Campaign_Member_Status__c, New_Campaign_Member_Status__c, Is_Default__c, Is_Responded__c 
            FROM Protected_Campaign_Status__mdt
            ORDER BY Campaign_Type__c, Is_Default__c DESC, Is_Responded__c DESC];

        Map<String, List<Protected_Campaign_Status__mdt>> groupedProtectedStatuses = new Map<String, List<Protected_Campaign_Status__mdt>>();
        for(Protected_Campaign_Status__mdt status : protectedStatuses) {
            if(!groupedProtectedStatuses.containsKey(status.Campaign_Type__c)) {
                groupedProtectedStatuses.put(status.Campaign_Type__c, new List<Protected_Campaign_Status__mdt>());
            }
            groupedProtectedStatuses.get(status.Campaign_Type__c).add(status);
        }
        return groupedProtectedStatuses;
    }

    private static Map<Id, List<CampaignMemberStatus>> getGroupedCampaignMemberStatusesByCampaignId(List<Id> campaignIds) {
        List<CampaignMemberStatus> statusesInDb = [
            SELECT Id, Label, CampaignId, HasResponded, IsDefault, SortOrder
            FROM CampaignMemberStatus
            WHERE CampaignId IN :campaignIds
            ORDER BY IsDefault DESC];
        Map<Id, List<CampaignMemberStatus>> statusesByCampaignId = new Map<Id, List<CampaignMemberStatus>>();
        for(CampaignMemberStatus status : statusesInDb) {
            if(!statusesByCampaignId.containsKey(status.CampaignId)) 
                statusesByCampaignId.put(status.CampaignId, new List<CampaignMemberStatus>());
            statusesByCampaignId.get(status.CampaignId).add(status);
        }
        return statusesByCampaignId;
    }
}
