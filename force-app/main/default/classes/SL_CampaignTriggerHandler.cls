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
}
