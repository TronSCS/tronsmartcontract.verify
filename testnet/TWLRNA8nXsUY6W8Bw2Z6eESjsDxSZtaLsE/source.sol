pragma solidity ^0.4.24;

contract Test {

    string public firstName;

    function set(string memory _firstName) public  {
        firstName = _firstName;
    }
    // END SETERS ***********************************************

    // GETERS ***************************************************
    function get () public view returns (string memory) {
        return firstName;
    }


}
