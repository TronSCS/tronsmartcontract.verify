pragma solidity ^0.4.25;

/**
 * @title EternalStorage
 * @dev This contract holds all the necessary state variables to carry out the storage of any contract.
 */
contract EternalStorage {
    mapping(bytes32 => uint256) internal uintStorage;
}

/**
 * @title Multi Sender,
 * @dev To Use this Dapp: https://iexbase.com
*/

library SafeMath {
    function mul(uint a, uint b) internal pure returns(uint) {
        uint c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }
    function div(uint a, uint b) internal pure returns(uint) {
        require(b > 0);
        uint c = a / b;
        require(a == b * c + a % b);
        return c;
    }
    function sub(uint a, uint b) internal pure returns(uint) {
        require(b <= a);
        return a - b;
    }
    function add(uint a, uint b) internal pure returns(uint) {
        uint c = a + b;
        require(c >= a);
        return c;
    }
    function max64(uint64 a, uint64 b) internal pure returns(uint64) {
        return a >= b ? a: b;
    }
    function min64(uint64 a, uint64 b) internal pure returns(uint64) {
        return a < b ? a: b;
    }
    function max256(uint256 a, uint256 b) internal pure returns(uint256) {
        return a >= b ? a: b;
    }
    function min256(uint256 a, uint256 b) internal pure returns(uint256) {
        return a < b ? a: b;
    }
}

/**
 * @title Multi Sender
 * @dev To Use this Dapp: https://iexbase.com
*/

contract ERC20Basic {
    uint public totalSupply;
    function balanceOf(address who) public constant returns(uint);
    function transfer(address to, uint value) public;
    event Transfer(address indexed from, address indexed to, uint value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public constant returns(uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
    event Approval(address indexed owner, address indexed spender, uint value);
}

/**
 * @title Multi Sender
 * @dev To Use this Dapp: https://iexbase.com
*/

contract BasicToken is ERC20Basic {

    using SafeMath
    for uint;

    mapping(address => uint) balances;

    function transfer(address _to, uint _value) public {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
    }

    function balanceOf(address _owner) public constant returns(uint balance) {
        return balances[_owner];
    }
}

/**
 * @title Multi Sender
 * @dev To Use this Dapp: https://iexbase.com
*/

contract StandardToken is BasicToken, ERC20 
{
    mapping(address => mapping(address => uint)) allowed;

    function transferFrom(address _from, address _to, uint _value) public {
        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
    }

    function approve(address _spender, uint _value) public {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _owner, address _spender) public constant returns(uint remaining) {
        return allowed[_owner][_spender];
    }
}

/**
 * @title Multi Sender
 * @dev To Use this Dapp: https://iexbase.com
*/

contract Ownable is EternalStorage
{
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
	
    function transferOwnership(address newOwner) onlyOwner public {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

/**
 * @title Multi Sender
 * @dev To Use this Dapp: https://iexbase.com
*/

contract iEXMultiSender is Ownable 
{
    using SafeMath
    for uint;

    event LogMultisended(address token, uint256 total);
    event LogGetToken(address token, address receiver, uint256 balance);
    address public receiverAddress;
    uint public txFee = 1;
    uint public VIPFee = 1000;
    uint256 public arrayLimit = 300;

	/**
	 * VIP List addresses
	 */
    mapping(address => bool) public vipList;

	/**
	 * Get balance
	 */
    function getBalance(address _tokenAddress) onlyOwner public {
        address _receiverAddress = getReceiverAddress();
        if (_tokenAddress == address(0)) {
            require(_receiverAddress.send(address(this).balance));
            return;
        }
        StandardToken token = StandardToken(_tokenAddress);
        uint256 balance = token.balanceOf(this);
        token.transfer(_receiverAddress, balance);
        emit LogGetToken(_tokenAddress, _receiverAddress, balance);
    }

	/**
	 * Register VIP
 	 */
    function registerVIP() payable public {
        require(msg.value >= VIPFee);
        address _receiverAddress = getReceiverAddress();
        require(_receiverAddress.send(msg.value));
        vipList[msg.sender] = true;
    }

	/**
	 * added VIP list
	 */
    function addToVIPList(address[] _vipList) onlyOwner public {
        for (uint i = 0; i < _vipList.length; i++) {
            vipList[_vipList[i]] = true;
        }
    }

	/**
	 * Remove address from VIP List by Owner
	 */
    function removeFromVIPList(address[] _vipList) onlyOwner public {
        for (uint i = 0; i < _vipList.length; i++) {
            vipList[_vipList[i]] = false;
        }
    }

	/**
	 * Check if the address is available in the "VIP" list
	 */
    function isVIP(address _addr) public view returns(bool) {
        return _addr == owner || vipList[_addr];
    }

    /**
     * Set a new limit
     */
    function setArrayLimit(uint256 _newLimit) onlyOwner public {
        require(_newLimit != 0);
        arrayLimit = _newLimit;
    }

	/**
	 * Set receiver address
	 */
    function setReceiverAddress(address _addr) onlyOwner public {
        require(_addr != address(0));
        receiverAddress = _addr;
    }

	/**
	 * Get receiver address
	 */
    function getReceiverAddress() public view returns(address) {
        if (receiverAddress == address(0)) {
            return owner;
        }
        return receiverAddress;
    }

    /**
     * set vip fee 
     */
    function setVIPFee(uint _fee) onlyOwner public {
        VIPFee = _fee;
    }

    /**
     * set tx fee
     */
    function setTxFee(uint _fee) onlyOwner public {
        txFee = _fee;
    }

    function trxSendSameValue(address[] _to, uint _value) internal 
    {
        uint sendAmount = _to.length.sub(1).mul(_value);
        uint256 total = msg.value;

        // Checking VIP status
        bool vip = isVIP(msg.sender);
        if (vip) {
            require(total >= sendAmount);
        } else {
            require(total >= sendAmount.add(txFee));
        }

        // Set limits
        require(_to.length <= arrayLimit);

        for (uint8 i = 1; i < _to.length; i++) {
            require(total >= _value);
            total = total.sub(_value);
            _to[i].transfer(_value);
        }

        emit LogMultisended(0x0, msg.value);
    }

    /**
     * We send money to several addresses with the same balance
     */
    function trxSendDifferentValue(address[] _to, uint256[] _value) internal {
        uint256 total = msg.value;
        uint sendAmount = _value[0];


        // Checking VIP status
        bool vip = isVIP(msg.sender);
        if (vip) {
            require(total >= sendAmount);
        } else {
            require(total >= sendAmount.add(txFee));
        }

        require(_to.length == _value.length);
        require(_to.length <= arrayLimit);


        uint256 i = 0;
        for (i; i < _to.length; i++) {
            require(total >= _value[i]);
            total = total.sub(_value[i]);
            _to[i].transfer(_value[i]);
        }

        setTxCount(msg.sender, txCount(msg.sender).add(1));
        emit LogMultisended(0x0, msg.value);
    }

	/**
	 * Send trx with the same value by a explicit call method
	 */
    function sendTrx(address[] _to, uint _value) payable public {
        trxSendSameValue(_to, _value);
    }

	/**
	 * Send trx with the different value by a explicit call method
	 */
    function multisend(address[] _to, uint[] _value) payable public {
        trxSendDifferentValue(_to, _value);
    }

	/**
	 * Send trx with the different value by a implicit call method
	 */
    function multiSendTRXWithDifferentValue(address[] _to, uint[] _value) payable public {
        trxSendDifferentValue(_to, _value);
    }

	/**
	 * Send trx with the same value by a implicit call method
	 */
    function multiSendTRXWithSameValue(address[] _to, uint _value) payable public {
        trxSendSameValue(_to, _value);
    }

    /**
     * We get a tx counter
     */
    function txCount(address customer) public view returns(uint256) {
        return uintStorage[keccak256(abi.encodePacked("txCount", customer))];
    }

    /**
     * Increase tx count
     */
    function setTxCount(address customer, uint256 _txCount) private {
        uintStorage[keccak256(abi.encodePacked("txCount", customer))] = _txCount;
    }

}