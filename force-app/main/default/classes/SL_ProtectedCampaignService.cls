public without sharing class SL_ProtectedCampaignService {
    private static SL_ProtectedCampaignService instance;

    public static SL_ProtectedCampaignService getInstance() {
        if(instance==null) instance = new SL_ProtectedCampaignService();
        return instance;
    }

    public SL_ProtectedCampaignService() {
    }

    public Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
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

    public List<Campaign> getCampaignsWithMemberStatuses(Set<Id> campaignIds) {
        System.debug('Start getCampaignsWithMemberStatuses');
        return [
            SELECT ID, Name, Type, (
                SELECT Id, Label, CampaignId, HasResponded, IsDefault, SortOrder 
                FROM CampaignMemberStatuses
                ORDER BY IsDefault DESC
            )
            FROM Campaign
            WHERE Id IN :campaignIds
            AND Has_Protected_Campaign_Member_Statuses__c = true
        ];
    }

    public Set<Id> getCampaignsNeedingToBeFixed() {
        Set<Id> campaignIdsNeedingFixes = new Set<Id>();
        Map<String, List<Protected_Campaign_Status__mdt>> protectedStatuses = getGroupedProtectedStatuses();

        for(String type : protectedStatuses.keySet()) {
            List<String> expectedLabels = new List<String>();
            for(Protected_Campaign_Status__mdt expectedStatus : protectedStatuses.get(type)) {
                expectedLabels.add(expectedStatus.New_Campaign_Member_Status__c);
            }

            List<AggregateResult> groupedResults = [
                SELECT CampaignId, Count(Id)
                FROM CampaignMemberStatus
                WHERE CampaignId IN (
                    SELECT Id 
                    FROM Campaign 
                    WHERE Has_Protected_Campaign_Member_Statuses__c = true
                    AND Type= :type 
                    AND IsActive = true)
                AND Label IN :expectedLabels
                GROUP BY CampaignId
                HAVING Count(Id) != :expectedLabels.size()
            ];

            for(AggregateResult ar : groupedResults) {
                campaignIdsNeedingFixes.add((Id)ar.get('CampaignId'));
            }
        }

        return campaignIdsNeedingFixes;
    }

    public void enforceProtectedStatusesForCampaigns(Set<Id> campaignIds) {
        System.debug('Start enforceProtectedStatusesForCampaigns');
        List<Campaign> existingCampaigns = getCampaignsWithMemberStatuses(campaignIds);

        if(campaignIds.size() != existingCampaigns.size()) 
            System.debug('There are some Campaigns that are not protected, ignoring those');
        if(existingCampaigns.isEmpty()) {
            System.debug('There are no Campaigns to process');
            return;
        }

        Map<String, List<Protected_Campaign_Status__mdt>> protectedStatuses = getGroupedProtectedStatuses();
        Map<Id, CampaignMemberStatus> toUpdate = new Map<Id, CampaignMemberStatus>();
        List<CampaignMemberStatus> toInsert = new List<CampaignMemberStatus>();
        
        for(Campaign campaign : existingCampaigns) {
            System.debug('Processing Campaign: ' + campaign.Name);
            Boolean changeNeeded=false;
            List<CampaignMemberStatus> existingStatuses = campaign.CampaignMemberStatuses;
            Map<String, CampaignMemberStatus> statusesByLabel = new Map<String, CampaignMemberStatus>();
            Integer sortOrder = 0;
            for(CampaignMemberStatus status : existingStatuses) {
                statusesByLabel.put(status.Label, status);
                if(status.SortOrder > sortOrder) sortOrder = status.SortOrder;
            }

            for(Protected_Campaign_Status__mdt expected : protectedStatuses.get(campaign.Type)) {
                String expectedStatus = expected.New_Campaign_Member_Status__c;
                if(statusesByLabel.containsKey(expectedStatus)) {
                    System.debug('Status of ' + expectedStatus + ' is already there. Checking to see if it has the right checkboxes');
                    CampaignMemberStatus realStatus = statusesByLabel.get(expectedStatus);
                    if(realStatus.IsDefault != expected.Is_Default__c) {
                        System.debug('the Default checkbox was not as expected. Setting it now');
                        changeNeeded=true;
                        realStatus.IsDefault = expected.Is_Default__c;
                        toUpdate.put(realStatus.Id, realStatus);
                    }
                    if(realStatus.HasResponded != expected.Is_Responded__c) {
                        System.debug('the Responded checkbox was not as expected. Setting it now');
                        changeNeeded=true;
                        realStatus.HasResponded = expected.Is_Responded__c;
                        toUpdate.put(realStatus.Id, realStatus);
                    }
                }
                else {
                    System.debug('We detected that Status: ' + expectedStatus + ' is missing');
                    sortOrder++;
                    CampaignMemberStatus newStatus = new CampaignMemberStatus(
                        CampaignId=campaign.Id, 
                        Label=expected.New_Campaign_Member_Status__c,
                        HasResponded=expected.Is_Responded__c,
                        SortOrder=sortOrder);
                    
                    changeNeeded=true;
                    System.debug(newStatus);
                    toInsert.add(newStatus);
                }
            }
            if(!changeNeeded) {
                System.debug('This campaign looks good! No changes needed');
            }
        }

        if(!toUpdate.isEmpty()) {
            System.debug('We are updating ' + toUpdate.size() + ' Status records');
            update toUpdate.values();
        }
        if(!toInsert.isEmpty()) {
            System.debug('We are inserting ' + toInsert.size() + ' Status records');
            insert toInsert;
        }
    }
}
