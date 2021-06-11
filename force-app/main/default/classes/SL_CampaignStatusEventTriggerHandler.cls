public without sharing class SL_CampaignStatusEventTriggerHandler {
    private static SL_CampaignStatusEventTriggerHandler instance;

    private SL_CampaignStatusEventTriggerHandler() {}

    public static SL_CampaignStatusEventTriggerHandler getInstance() {
        if(instance==null) instance = new SL_CampaignStatusEventTriggerHandler();
        return instance;
    }

    public void afterInsert(List<CampaignMemberStatusChangeEvent> events) {
        System.debug('We are processing ' + events.size()+' Change events');
        Set<Id> campaignMemberIds = new Set<Id>();
    
        for(CampaignMemberStatusChangeEvent event : events) {
            EventBus.ChangeEventHeader header = event.ChangeEventHeader;
            System.debug('changeType = ' + header.changetype);
            
            if(header.changetype == 'UPDATE'){
                List<String> changedFields = header.changedfields; // list of fields updated
                System.debug('Update details: ');
                System.debug(event);
                for(String recordId : header.getRecordIds()) {
                    campaignMemberIds.add(Id.valueOf(recordId));
                }
            }
        }
        if(!campaignMemberIds.isEmpty()) {
            Set<Id> campaignIds = new Set<Id>();
            for(CampaignMemberStatus a : [SELECT CampaignId FROM CampaignMemberStatus WHERE Id IN :campaignMemberIds]) {
                campaignIds.add(a.CampaignId);
            }
            SL_ProtectedCampaignService.getInstance().enforceProtectedStatusesForCampaigns(campaignIds);
        }
    }
}
