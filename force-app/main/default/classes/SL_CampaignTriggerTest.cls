@isTest
private class SL_CampaignTriggerTest {
    
    @isTest
    static void shouldPreventUsersFromMakingCampaignProtected() {
        // arrange
        Campaign record = new Campaign(
            Name='MyTest', 
            Has_Protected_Campaign_Member_Statuses__c=true);

        // act 
        Test.startTest();
            Database.SaveResult result = Database.insert(record, false);
        Test.stopTest();

        // assert
        System.assert(result.isSuccess() == false);
        System.assert(result.getErrors().size() == 1);
    }

    @isTest(seeAllData=true)
    static void shouldMakeCampaignProtectedIfItHasTheRightType() {
        // arrange
        SL_ProtectedCampaignService.getInstance().repo = new SL_WebinarMock();
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Webinar');

        //act
        Test.startTest();
            insert record;
        Test.stopTest();

        //assert
        Campaign result = [SELECT Name, Type, Has_Protected_Campaign_Member_Statuses__c FROM Campaign WHERE Name='MyTest'];
        System.assertEquals(true, result.Has_Protected_Campaign_Member_Statuses__c);
        System.assertEquals('Webinar',result.Type);
    }

    @isTest
    static void shouldAlowNewCampaignWithoutProtectedType() {
        // arrange
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Who Knows');

        //act
        Test.startTest();
            insert record;
        Test.stopTest();

        //assert
        Campaign result = [SELECT Name, Type, Has_Protected_Campaign_Member_Statuses__c FROM Campaign WHERE Name='MyTest'];
        System.assertEquals(false, result.Has_Protected_Campaign_Member_Statuses__c);
        System.assertEquals('Who Knows',result.Type);
    }


    @isTest(seeAllData=true)
    static void shouldCreateAllTheRightStatusesForSpecifiedType() {
        // arrange
        SL_ProtectedCampaignService.getInstance().repo = new SL_WebinarMock();
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Webinar');

        //act
        Test.startTest();
            insert record;
        Test.stopTest();

        //assert
        List<CampaignMemberStatus> results = [
            SELECT Id, Label, CampaignId, HasResponded, IsDefault, SortOrder 
            FROM CampaignMemberStatus 
            WHERE CampaignId = :record.Id];
        System.assertEquals(4, results.size());
    }


    @isTest(seeAllData=true)
    static void shouldCreateAllTheRightStatusesInSingleStatusType() {
        // arrange
        SL_ProtectedCampaignService.getInstance().repo = new SL_AdvertisementMock();
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Advertisement');

        //act
        Test.startTest();
            insert record;
        Test.stopTest();

        //assert
        List<CampaignMemberStatus> results = [
            SELECT Id, Label, CampaignId, HasResponded, IsDefault, SortOrder 
            FROM CampaignMemberStatus 
            WHERE CampaignId = :record.Id];
        System.assertEquals(1, results.size());
    }

    @isTest(seeAllData=true)
    static void shouldPreventChangingTypeForProtectedCampaign() {
        //arrange
        SL_ProtectedCampaignService.getInstance().repo = new SL_AdvertisementMock();
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Advertisement');
        insert record;

        //act
        Test.startTest();
            record.Type='Webinar';
            Database.SaveResult result = Database.update(record, false);
        Test.stopTest();

        // assert
        System.assert(result.isSuccess() == false);
        System.debug(result.getErrors());
        System.assertEquals(1, result.getErrors().size());
        System.assertEquals('Campaign has Protected Campaign Member Statuses. Don\'t change the type.', result.getErrors().get(0).getMessage());
    }

    @isTest(seeAllData=true)
    static void shouldPreventEnablingProtectedStatusAfterTheFact() {
        //arrange
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Who Cares');
        insert record;

        //act
        Test.startTest();
            record.Has_Protected_Campaign_Member_Statuses__c=true;
            Database.SaveResult result = Database.update(record, false);
        Test.stopTest();

        // assert
        System.assert(result.isSuccess() == false);
        System.debug(result.getErrors());
        System.assertEquals(1, result.getErrors().size());
        System.assertEquals('Once disabled, cannot be re-enabled.', result.getErrors().get(0).getMessage());
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
            registered.New_Campaign_Member_Status__c = '1Registered';
            registered.Is_Default__c = true;
            registered.Is_Responded__c = false;
            values.add(registered);

            Protected_Campaign_Status__mdt attended = new Protected_Campaign_Status__mdt();
            attended.DeveloperName = 'Webinar_Attended';
            attended.Label = 'Webinar-Attended';
            attended.Campaign_Type__c = 'Webinar';
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
    private class SL_AdvertisementMock extends SL_ProtectedCampaignRepository {
    
        public override Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
            System.debug('overriding actually getting MDTs from Salesforce, using hard coded Advertisement MDTs');
            Map<String, List<Protected_Campaign_Status__mdt>> response = new Map<String, List<Protected_Campaign_Status__mdt>>();
            List<Protected_Campaign_Status__mdt> values = new List<Protected_Campaign_Status__mdt>();
            Protected_Campaign_Status__mdt onlyStatus = new Protected_Campaign_Status__mdt();
            onlyStatus.DeveloperName = 'Advertisement_Responded';
            onlyStatus.Label = 'Advertisement-Responded';
            onlyStatus.Campaign_Type__c = 'Advertisement';
            onlyStatus.New_Campaign_Member_Status__c = 'Responded';
            onlyStatus.Is_Default__c = true;
            onlyStatus.Is_Responded__c = true;
            values.add(onlyStatus);

            response.put('Advertisement', values);
            return response;
        }
    }
}
