public class AccountRoute  extends RestRoute  {
	 protected override Object doPost() {
        String requestBody = this.request.requestBody.toString();
        return setupAccounts(requestBody);
    }
    
    private List<Response> setupAccounts(String requestBody) {
        List<AccountRequest> requests = (List<AccountRequest>)JSON.deserialize(requestBody, List<AccountRequest>.class);
        System.debug('requests-->'+requests);
        Map<String, Account> accountMap = new Map<String, Account>();
        Map<String, String> userMap = new Map<String, String>(); //User Map
        Set<String> externalids = new Set<String>();
        Set<String> userAdId = new Set<String>(); //User Id set
        list<string> userLookUpFieldList = new list<string>();
        List<Account> updatedAccounts = new List<Account>();
        
        //Find the user look up field from account object
        string objName = 'Account'; // Object name you wish to extract lookup fields for
        map<string, Map<String, Schema.SObjectField>> objectFieldsMap = new map<string, Map<String, Schema.SObjectField>>(); //Object field schema map
        Map<String, Schema.SObjectField> objectFields = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap();
        for(Schema.SObjectField fld :objectFields.values()){
            schema.describeFieldResult dfield = fld.getDescribe();
            List<Schema.SObjectType> referenceToObjects = dfield.getReferenceTo();
            if (!referenceToObjects.isEmpty()) {
                Schema.SObjectType referencedObjectType = referenceToObjects[0];
                String referencedObjectAPIName = referencedObjectType.getDescribe().getName();
                if(referencedObjectAPIName == 'User'){
                    System.debug('UserLookup-->'+string.valueOf(dfield.Name));
                    userLookUpFieldList.add(string.valueOf(dfield.Name));
                }
            }
        }
        // Check if the user look up field present in request body, Get the value and put it in a list
        for(AccountRequest req : requests) {
            Map<String, Object> getpopulatedFields = req.header.getPopulatedFieldsAsMap();
            externalids.add(req.header.SAP_External_ID__c );
            for(string fldName : getpopulatedFields.keySet()){
                if(userLookUpFieldList.contains(fldName) && string.valueOf(getpopulatedFields.get(fldName)) != ''){
                    userAdId.add(string.valueOf(getpopulatedFields.get(fldName)));
                }
            }
        }
        
        // Query based on active directory id which is present on requestBody
        List<User> existingUser = [SELECT Id, Name, Active_Directory_ID__c FROM User WHERE isActive = true and  Active_Directory_ID__c != null and Active_Directory_ID__c IN:userAdId];
        for(User exitUser: existingUser){
            userMap.put(exitUser.Active_Directory_ID__c, exitUser.Id);
        }
        
        // Query all existing account
        List<Account> exisitngAccts = [SELECT Id, Company_Account_Number__c FROM Account WHERE Company_Account_Number__c IN: externalids];
        for(Account acc: exisitngAccts) {
            accountMap.put(acc.Company_Account_Number__c, acc);
        }
        
        //insert or update the account
        for(AccountRequest req : requests) {
            System.debug('req--->'+req);
            Global_Business_Unit__mdt mc = Global_Business_Unit__mdt.getInstance(req.other.get('Global_Business_Unit__c').replace(' ','_'));
            System.debug('mc-->'+mc);
            //Global_Business_Unit__mdt rgn = Global_Business_Unit__mdt.getInstance(req.header.ShippingCountry);
            //System.debug('rgn-->'+rgn);
            Id gbuRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(mc.Target_Value__c).getRecordTypeId();
            System.debug('gbuRecordTypeId--->'+gbuRecordTypeId);
            Map<String, Object> getpopulatedFields = req.header.getPopulatedFieldsAsMap();
            
            Account existingAccount = accountMap.containsKey(req.header.SAP_External_ID__c) ? accountMap.get(req.header.SAP_External_ID__c) : null;
            Account newAcc = new Account();
            if(existingAccount != null){
                newAcc.put('Id',existingAccount.Id);
            }
            newAcc.put(mc.Target_Field__c,gbuRecordTypeId);
            //newAcc.put(rgn.Target_Field__c,rgn.Target_Value__c); //Region mapping
            for(string fld : getpopulatedFields.keySet()){
                if(userLookUpFieldList.contains(fld)){
                    newAcc.put(fld,userMap.containsKey(string.valueOf(getpopulatedFields.get(fld))) ? userMap.get(string.valueOf(getpopulatedFields.get(fld))):'');    
                }else{
                    if(fld != 'Region__c'){
                        newAcc.put(fld,getpopulatedFields.get(fld));
                    }
                }     
            }
            updatedAccounts.add(newAcc);
           
        }
        List<Database.UpsertResult> upsertResults = Database.upsert(updatedAccounts, Schema.Account.SAP_External_ID__c, false);
        
        // Then send the response using Response
        List<Response> responses = new List<Response>();
        
        for(Database.UpsertResult upsertResult : upsertResults) {
            Response response = new Response();
            response.salesforceId = upsertResult.getId();
            response.success = upsertResult.isSuccess();
            if(!upsertResult.isSuccess()) {
                response.message = upsertResult.getErrors().get(0).getMessage();   
            }
            responses.add(response);
        }
        
        return responses;
    }
}