trigger SL_CampaignTrigger on Campaign (before insert) {
    if(Trigger.isBefore && Trigger.isInsert) {
        SL_CampaignTriggerHandler.onBeforeInsert(Trigger.new);
    }
}