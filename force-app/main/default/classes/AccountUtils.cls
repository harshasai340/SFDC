public class AccountUtils {
  //Added comment for testing need to remove post testing 
    public static List<Account>accountsByState(String st){
       List<Account> acctList = [SELECT Id, Name FROM Account WHERE billingState = :st];
        system.debug(acctList);
	  return acctList;
       
	}
}