/***
 * Some reusable logic for this solution
 */
public virtual without sharing class SL_ProtectedCampaignService {
    //singleton pattern
    @TestVisible
    private static SL_ProtectedCampaignService instance;
    @TestVisible
    private SL_ProtectedCampaignRepository repo;

    public static SL_ProtectedCampaignService getInstance() {
        if(instance==null) {
            System.debug('creating new instance of SL_ProtectedCampaignService');
            instance = new SL_ProtectedCampaignService();
            instance.repo = new SL_ProtectedCampaignRepository(); 
        }
        return instance;
    }

    protected SL_ProtectedCampaignService() { }

    public List<Campaign> getCampaignsWithMemberStatuses(Set<Id> campaignIds) {
        System.debug('Start getCampaignsWithMemberStatuses');
        return [
            SELECT ID, Name, Type, (
                SELECT Id, Label, CampaignId, HasResponded, IsDefault, SortOrder 
                FROM CampaignMemberStatuses
                ORDER BY IsDefault DESC, HasResponded DESC
            )
            FROM Campaign
            WHERE Id IN :campaignIds
            AND Has_Protected_Campaign_Member_Statuses__c = true
        ];
    }
    public virtual Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
        return repo.getGroupedProtectedStatuses();
    }

    public virtual Set<Id> getCampaignsNeedingToBeFixed() {
        System.debug('looking for Campaigns that might need to be fixed');
        Set<Id> campaignIdsNeedingFixes = new Set<Id>();
        Map<String, List<Protected_Campaign_Status__mdt>> protectedStatuses = repo.getGroupedProtectedStatuses();

        for(String type : protectedStatuses.keySet()) {
            System.debug('Checking campaigns of type ' + type);
            List<String> expectedLabels = new List<String>();
            for(Protected_Campaign_Status__mdt expectedStatus : protectedStatuses.get(type)) {
                expectedLabels.add(expectedStatus.New_Campaign_Member_Status__c);
            }

            System.debug('expecting ' + expectedLabels.size() + ' specific Statuses');
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
        System.debug('found ' + campaignIdsNeedingFixes.size() + ' Campaigns that are missing at least 1 of the mandatory Statuses');
        return campaignIdsNeedingFixes;
    }

    public virtual void enforceProtectedStatusesForCampaigns(Set<Id> campaignIds) {
        System.debug('Start enforceProtectedStatusesForCampaigns');
        List<Campaign> existingCampaigns = getCampaignsWithMemberStatuses(campaignIds);

        if(campaignIds.size() != existingCampaigns.size()) 
            System.debug('There are some Campaigns that are not protected, ignoring those');
        if(existingCampaigns.isEmpty()) {
            System.debug('There are no Campaigns to process');
            return;
        }

        Map<String, List<Protected_Campaign_Status__mdt>> protectedStatuses = repo.getGroupedProtectedStatuses();
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
