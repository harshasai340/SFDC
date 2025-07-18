public class Email_Class {
    public static void sendsingleEmail(){
        Messaging.SingleEmailMessage sEmail = new Messaging.SingleEmailMessage();
        String[] sendingTo= new String[]{'harshasai340@gmail.com'};
        semail.setToAddresses(sendingTo);
        semail.setSubject('Test Email');
        semail.setPlainTextBody('Hai'+userInfo.getUserName()+ 'Thank You for your Bussiness');
        Messaging.SendEmail(new Messaging.SingleEmailMessage[]{semail});
    }
    
}