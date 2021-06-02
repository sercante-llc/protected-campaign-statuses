public without sharing class SL_CampaignTriggerHandler {
    public static void onBeforeInsert(List<Campaign> campaigns) {
        List<Protected_Campaign_Status__mdt> protectedStatuses = [
            SELECT Campaign_Type__c, Original_Campaign_Member_Status__c, New_Campaign_Member_Status__c, Is_Default__c, Is_Responded__c 
            FROM Protected_Campaign_Status__mdt];

        Map<String, List<Protected_Campaign_Status__mdt>> groupedProtectedStatuses = new Map<String, List<Protected_Campaign_Status__mdt>>();
        for(Protected_Campaign_Status__mdt status : protectedStatuses) {
            if(!groupedProtectedStatuses.containsKey(status.Campaign_Type__c)) {
                groupedProtectedStatuses.put(status.Campaign_Type__c, new List<Protected_Campaign_Status__mdt>());
            }
            groupedProtectedStatuses.get(status.Campaign_Type__c).add(status);
        }


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

    public static void onBeforeUpdate(List<Campaign> newValues, Map<Id, Campaign> oldValues) {
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
