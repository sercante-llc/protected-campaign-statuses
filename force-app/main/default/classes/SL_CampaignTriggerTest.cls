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

    @isTest(seeAllData=true)
    static void shouldMakeCampaignProtectedIfItHasTheRightTypeForEmail() {
        // arrange
        Campaign record = new Campaign(
            Name='MyTest', 
            Type='Email');

        //act
        Test.startTest();
            insert record;
        Test.stopTest();

        //assert
        Campaign result = [SELECT Name, Type, Has_Protected_Campaign_Member_Statuses__c FROM Campaign WHERE Name='MyTest'];
        System.assertEquals(true, result.Has_Protected_Campaign_Member_Statuses__c);
        System.assertEquals('Email',result.Type);
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
    static void shouldCreateAllTheRightStatusesInWebinar() {
        // arrange
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
    static void shouldCreateAllTheRightStatusesInAdvertisement() {
        // arrange
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
}
