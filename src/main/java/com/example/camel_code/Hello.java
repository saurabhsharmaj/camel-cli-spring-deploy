package com.example.camel_code;

import com.example.camel_code.utils.HelloUtils;
import org.apache.camel.builder.RouteBuilder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class Hello extends RouteBuilder {

    @Override
    public void configure() throws Exception {
        // Define the REST API endpoint: GET /hello
        rest("/hello")
                .get()
                .to("direct:helloWorld");

        // The route that processes the request and returns the response
        from("direct:helloWorld")
                .setBody(constant("HELLO WORLD"))
                .bean(HelloUtils.class, "toLower");
                //.transform(constant(helloUtils.toLower("Hello World")));
    }
}