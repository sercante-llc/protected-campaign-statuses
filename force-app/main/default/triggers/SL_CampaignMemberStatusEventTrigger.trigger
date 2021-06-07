trigger SL_CampaignMemberStatusEventTrigger on CampaignMemberStatusChangeEvent (after insert) {
    System.debug('We are processing Change events');
    List<Id> campaignMemberIds = new List<Id>();

    for(CampaignMemberStatusChangeEvent event : Trigger.new) {
        EventBus.ChangeEventHeader header = event.ChangeEventHeader;
        
        if(header.changetype == 'UPDATE'){
            List<String> changedFields = header.changedfields; // list of fields updated
            System.debug('Update details: ');
            System.debug(event);
            campaignMemberIds.addAll(header.getRecordIds());
        }
        else if(header.changetype == 'DELETE'){
            System.debug('Delete details: ');
            System.debug(event);
            campaignMemberIds.addAll(header.getRecordIds());
        }
    }
}