public class AccountHandler {
    public static Account insertNewAccount(String Name){
        Account acct = new Account();
        try{
     	acct.Name = Name;       
        insert acct;
        }
        catch(Exception e ){
            return null;
        }
        return acct;
        
   }
}