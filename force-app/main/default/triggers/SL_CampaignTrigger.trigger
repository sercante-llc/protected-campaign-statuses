trigger SL_CampaignTrigger on Campaign (before insert, after insert, before update) {
    if(Trigger.isBefore) {
        if(Trigger.isInsert) {
            SL_CampaignTriggerHandler.onBeforeInsert(Trigger.new);
        }
        else if(Trigger.isUpdate) {
            SL_CampaignTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    else {
        if(Trigger.isInsert) {
            SL_CampaignTriggerHandler.onAfterInsert(Trigger.new);
        }
    }
}