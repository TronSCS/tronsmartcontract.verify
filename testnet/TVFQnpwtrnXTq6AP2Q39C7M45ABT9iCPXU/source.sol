pragma solidity ^0.4.24;

contract Test {

    string public firstName;

    event LogEvent (string _log);

    function set(string memory _firstName) public  {
        firstName = _firstName;
        emit LogEvent(firstName);
        
    }
    // END SETERS ***********************************************

    // GETERS ***************************************************
    function get () public view returns (string memory) {
        return firstName;
    }


}