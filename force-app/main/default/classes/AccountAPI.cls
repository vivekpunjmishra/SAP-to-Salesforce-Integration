@RestResource(urlMapping='/api/Account/*')
global class AccountAPI {
    private static void handleRequest(){
    	AccountRoute router = new AccountRoute();
      	router.execute();
    }

    @HttpPost
    global static void handlePost() {
        handleRequest();
    }
}