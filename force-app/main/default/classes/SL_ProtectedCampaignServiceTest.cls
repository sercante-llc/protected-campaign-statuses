@isTest
private class SL_ProtectedCampaignServiceTest {

    @isTest(seeAllData=true)
    static void shouldEnforceProtectedStatusesForCampaign() {
        //arrange
        Test.enableChangeDataCapture();
        SL_ProtectedCampaignService sut = SL_ProtectedCampaignService.getInstance();
        sut.repo = new SL_WebinarMock();

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
        Test.stopTest();

        //assert
        List<CampaignMemberStatus> results = [SELECT Id, Label, IsDefault, HasResponded FROM CampaignMemberStatus WHERE CampaignId = :campaign.Id ORDER BY Label];
        System.assertEquals('1Registered', results.get(0).Label);
        System.assertEquals(false, results.get(0).HasResponded);
        System.assertEquals('2Attended', results.get(1).Label);
        System.assertEquals('3Watched On Demand', results.get(2).Label);
        System.assertEquals('4Did Not Attend', results.get(3).Label);
    }

    private class SL_WebinarMock extends SL_ProtectedCampaignRepository {
    
        public override Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
            System.debug('overriding actually getting MDTs from Salesforce, using hard coded Webinar MDTs');
            Map<String, List<Protected_Campaign_Status__mdt>> response = new Map<String, List<Protected_Campaign_Status__mdt>>();
            List<Protected_Campaign_Status__mdt> values = new List<Protected_Campaign_Status__mdt>();
            Protected_Campaign_Status__mdt registered = new Protected_Campaign_Status__mdt();
            registered.DeveloperName = 'Webinar_Registered';
            registered.Label = 'Webinar-Registered';
            registered.Campaign_Type__c = 'Webinar';
            registered.Original_Campaign_Member_Status__c = 'Responded';
            registered.New_Campaign_Member_Status__c = '1Registered';
            registered.Is_Default__c = true;
            registered.Is_Responded__c = false;
            values.add(registered);

            Protected_Campaign_Status__mdt attended = new Protected_Campaign_Status__mdt();
            attended.DeveloperName = 'Webinar_Attended';
            attended.Label = 'Webinar-Attended';
            attended.Campaign_Type__c = 'Webinar';
            attended.Original_Campaign_Member_Status__c = 'Sent';
            attended.New_Campaign_Member_Status__c = '2Attended';
            attended.Is_Default__c = false;
            attended.Is_Responded__c = true;
            values.add(attended);

            Protected_Campaign_Status__mdt watchedOnDemand = new Protected_Campaign_Status__mdt();
            watchedOnDemand.DeveloperName = 'Webinar_WatchedOnDemand';
            watchedOnDemand.Label = 'Webinar-WatchedOnDemand';
            watchedOnDemand.Campaign_Type__c = 'Webinar';
            watchedOnDemand.New_Campaign_Member_Status__c = '3Watched On Demand';
            watchedOnDemand.Is_Default__c = false;
            watchedOnDemand.Is_Responded__c = true;
            values.add(watchedOnDemand);

            Protected_Campaign_Status__mdt didNotAttend = new Protected_Campaign_Status__mdt();
            didNotAttend.DeveloperName = 'Webinar_DidNotAttend';
            didNotAttend.Label = 'Webinar-DidNotAttend';
            didNotAttend.Campaign_Type__c = 'Webinar';
            didNotAttend.New_Campaign_Member_Status__c = '4Did Not Attend';
            didNotAttend.Is_Default__c = false;
            didNotAttend.Is_Responded__c = false;
            values.add(didNotAttend);


            response.put('Webinar', values);
            return response;
        }
    }
}
