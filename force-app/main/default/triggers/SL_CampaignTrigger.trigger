trigger SL_CampaignTrigger on Campaign (before insert, after insert, before update) {
    SL_CampaignTriggerHandler handler = SL_CampaignTriggerHandler.getInstance();
    if(Trigger.isBefore) {
        if(Trigger.isInsert) {
            handler.onBeforeInsert(Trigger.new);
        }
        else if(Trigger.isUpdate) {
            handler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    else {
        if(Trigger.isInsert) {
            handler.onAfterInsert(Trigger.new);
        }
    }
}