// Specify version of solidity file (https://solidity.readthedocs.io/en/v0.4.24/layout-of-source-files.html#version-pragma)
pragma solidity ^0.4.0;

contract HelloWorld {
    // Define variable message of type string
    string message;

    // Write function to change the value of variable message
    function postMessage(string value) public returns (string) {
        message = value;
        return message;
    }
    
    // Read function to fetch variable message
    function getMessage() public view returns (string){
        return message;
    }
}