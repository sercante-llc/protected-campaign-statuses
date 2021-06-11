trigger SL_CampaignMemberStatusEventTrigger on CampaignMemberStatusChangeEvent (after insert) {
    System.debug('We are processing Change events');
    Set<Id> campaignMemberIds = new Set<Id>();

    for(CampaignMemberStatusChangeEvent event : Trigger.new) {
        EventBus.ChangeEventHeader header = event.ChangeEventHeader;
        
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