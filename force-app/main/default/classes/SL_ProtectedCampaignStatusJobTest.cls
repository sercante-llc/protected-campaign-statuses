@isTest
private class SL_ProtectedCampaignStatusJobTest {
    public static Boolean gotProtectedStatuses=false;
    public static Boolean executed = false;

    @isTest
    static void shouldWork() {
        //arrange
        MockService mock = new MockService();
        SL_ProtectedCampaignService.instance = mock;

        //act
        Test.startTest();
            System.schedule('testJob', '0 0 23 * * ?', new SL_ProtectedCampaignStatusJob());
        Test.stopTest();

        //assert
        System.assert(gotProtectedStatuses);
        System.assert(executed);
    }

    private class MockService extends SL_ProtectedCampaignService {

        public override Set<Id> getCampaignsNeedingToBeFixed() {
            System.debug('called getCampaignsNeedingToBeFixed mock');
            SL_ProtectedCampaignStatusJobTest.gotProtectedStatuses=true;
            return new Set<Id>();
        }

        public override void enforceProtectedStatusesForCampaigns(Set<Id> campaignIds) {
            System.debug('called enforceProtectedStatusesForCampaigns mock');
            SL_ProtectedCampaignStatusJobTest.executed=true;
        }
    }
}
