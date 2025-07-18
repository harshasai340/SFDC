@IsTest
public class MyIterableTest {
    @IsTest
    public static void testIterableForLoop() {
        // Create a list of strings
        List<String> strings = new List<String>{'Hello', 'World'};

        // Create an instance of MyIterable with the list of strings
        MyIterable myIterable = new MyIterable(strings);

        // Use a for loop to iterate over the MyIterable instance
        for (String str : myIterable) {
            System.debug(str); // Expected output: DEBUG | Hello, DEBUG | World
        }
    }
}