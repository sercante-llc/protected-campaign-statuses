global class SL_ProtectedCampaignStatusJob implements Schedulable {
    private SL_ProtectedCampaignService sut = SL_ProtectedCampaignService.getInstance();

    global void execute(SchedulableContext SC) {
        System.debug('Starting Scheduled Job SL_ProtectedCampaignStatusJob');
        Set<Id> campaignIdsNeedingFixed = sut.getCampaignsNeedingToBeFixed();
        sut.enforceProtectedStatusesForCampaigns(campaignIdsNeedingFixed);
    }
}
