trigger SL_CampaignMemberStatusEventTrigger on CampaignMemberStatusChangeEvent (after insert) {
    SL_CampaignStatusEventTriggerHandler.getInstance().afterInsert(Trigger.new);
}