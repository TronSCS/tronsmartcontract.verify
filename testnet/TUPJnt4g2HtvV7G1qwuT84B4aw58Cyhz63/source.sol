
// File: src\Owner\Ownable.sol

pragma solidity ^0.4.23;


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

// File: src\User\User.sol

pragma solidity ^0.4.23;


contract User is Ownable {

    string public mainInfo;
    string public stringifyData;

    event LogEvent (string _type, string _log);



    // SETERS ****************************************************
    function setMainInfo (string memory _mainInfo) public onlyOwner  {
        mainInfo = _mainInfo;
        emit LogEvent('Main info', _mainInfo);
    }

    function setStringifyData(string memory _stringifyData) public onlyOwner  {
        stringifyData = _stringifyData;
        emit LogEvent('All data', _stringifyData);
    }
    // END SETERS ***********************************************



    // GETERS ***************************************************
    function getMainInfo () public view returns (string memory) {
        return mainInfo;
    }


    function getStringifyData () public view returns (string memory) {
        return stringifyData;
    }
    // END GETERS ***********************************************


}
