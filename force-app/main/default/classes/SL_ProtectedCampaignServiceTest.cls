@isTest
private class SL_ProtectedCampaignServiceTest {

    @isTest(seeAllData=true)
    static void shouldEnforceProtectedStatusesForCampaign() {
        //arrange
        Test.enableChangeDataCapture();
        SL_ProtectedCampaignService sut = SL_ProtectedCampaignService.getInstance();
        sut.repo = new SL_ProtectedCampaignServiceData.SL_WebinarMock(
            new List<Protected_Campaign_Status__mdt> {
                SL_ProtectedCampaignServiceData.newDefaultStatus('Webinar','1Registered'),
                SL_ProtectedCampaignServiceData.newRespondedStatus('Webinar','2Attended'),
                SL_ProtectedCampaignServiceData.newRespondedStatus('Webinar','3Watched On Demand'),
                SL_ProtectedCampaignServiceData.newStatus('Webinar','4Did Not Attend')
        });

        Campaign campaign = new Campaign(
            Name='MyTest', 
            Type='Webinar',
            IsActive=true);
        insert campaign;
        Test.getEventBus().deliver(); //clear the bus so that we later get Update events

        //act
        Test.startTest();
            System.debug('start of test');
            
            //here we mess up our data
            delete [SELECT Id FROM CampaignMemberStatus WHERE Label='3Watched On Demand'];
            CampaignMemberStatus registered =  [SELECT Id FROM CampaignMemberStatus WHERE Label='1Registered'];
            registered.HasResponded=true;
            update registered;
            System.assert(sut.getCampaignsNeedingToBeFixed().contains(campaign.Id));
        Test.stopTest();

        //assert
        List<CampaignMemberStatus> results = [SELECT Id, Label, IsDefault, HasResponded FROM CampaignMemberStatus WHERE CampaignId = :campaign.Id ORDER BY Label];
        System.assertEquals('1Registered', results.get(0).Label);
        System.assertEquals(false, results.get(0).HasResponded);
        System.assertEquals('2Attended', results.get(1).Label);
        System.assertEquals('3Watched On Demand', results.get(2).Label);
        System.assertEquals('4Did Not Attend', results.get(3).Label);
    }
}
