package com.example.camel_code.utils;

import org.springframework.stereotype.Component;

@Component
public class HelloUtils {

    public String toLower(String input){
        return input.toLowerCase();
    }
}
