@isTest
public class SL_ProtectedCampaignServiceData {
    public static Protected_Campaign_Status__mdt newDefaultStatus(String type, String name) {
        return build(type, name, true, false);
    }

    public static Protected_Campaign_Status__mdt newRespondedStatus(String type, String name) {
        return build(type, name, false, true);
    }

    public static Protected_Campaign_Status__mdt newDefaultAndRespondedStatus(String type, String name) {
        return build(type, name, true, true);
    }

    public static Protected_Campaign_Status__mdt newStatus(String type, String name) {
        return build(type, name, false, false);
    }

    private static Protected_Campaign_Status__mdt build(String type, String name, Boolean defaultStatus, Boolean respondedStatus) {
        Protected_Campaign_Status__mdt item = new Protected_Campaign_Status__mdt();
        item.Label = type+'-'+name;
        item.DeveloperName = item.Label.replace(' ','_').replace('-','_');
        item.Campaign_Type__c = type;
        item.New_Campaign_Member_Status__c = name;
        item.Is_Default__c = defaultStatus;
        item.Is_Responded__c = respondedStatus;
        return item;
    }

    public class SL_WebinarMock extends SL_ProtectedCampaignRepository {
        private final List<Protected_Campaign_Status__mdt> values;

        public SL_WebinarMock(List<Protected_Campaign_Status__mdt> values) {
            this.values=values;
        }
    
        public override Map<String, List<Protected_Campaign_Status__mdt>> getGroupedProtectedStatuses() {
            System.debug('overriding actually getting MDTs from Salesforce, using hard coded Webinar MDTs');
            Map<String, List<Protected_Campaign_Status__mdt>> response = new Map<String, List<Protected_Campaign_Status__mdt>>();
            response.put(values.get(0).Campaign_Type__c, values);
            return response;
        }
    }
}