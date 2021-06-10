public without sharing class SL_ProtectedCampaignService {


    public static Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
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

    public static Map<Id, List<CampaignMemberStatus>> getGroupedCampaignMemberStatusesByCampaignId(List<Id> campaignIds) {
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
