@IsTest
public class MyIterableTest {
    
    @IsTest
    static void testIterableForLoop() {
        // Step 1: Create a list of strings
        List<String> strings = new List<String>{'Hello', 'World'};
        
        // Step 2: Create an instance of MyIterable
        MyIterable myIterable = new MyIterable(strings);
        
        // Step 3: Iterate using for-each loop
        for (String s : myIterable) {
            System.debug(s);
        }
    }
}