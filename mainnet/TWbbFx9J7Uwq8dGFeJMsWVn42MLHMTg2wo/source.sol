pragma solidity ^0.4.25;

contract Ownable {
    address public owner;

    event onOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        emit onOwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

contract aaa is Ownable {

  function getNumber(uint256 _start, uint256 _cnt, uint256 _range) public view returns(uint256 ret) {
        for (uint256 i = 0; i < _cnt; i++) {
            ret += uint256(keccak256(abi.encodePacked(blockhash(_start + i))));
        }
        ret = ret % _range;
        return ret;
    }

}
