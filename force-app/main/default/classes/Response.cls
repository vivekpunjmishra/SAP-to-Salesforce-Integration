public class Response { 
    public String salesforceId { get; set; }
    public Boolean success { get; set; }
    public String message { get; set; }        
    public List<Response> itemResponses { get; set; }
}