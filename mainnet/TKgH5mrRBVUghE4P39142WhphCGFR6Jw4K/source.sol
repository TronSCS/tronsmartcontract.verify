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

pragma solidity ^0.4.23;

/// @author https://BlockChainArchitect.iocontract Bank is CutiePluginBase
contract PluginInterface
{
    /// @dev simply a boolean to indicate this is the contract we expect to be
    function isPluginInterface() public pure returns (bool);

    function onRemove() public;

    /// @dev Begins new feature.
    /// @param _cutieId - ID of token to auction, sender must be owner.
    /// @param _parameter - arbitrary parameter
    /// @param _seller - Old owner, if not the message sender
    function run(
        uint40 _cutieId,
        uint256 _parameter,
        address _seller
    ) 
    public
    payable;

    /// @dev Begins new feature, approved and signed by COO.
    /// @param _cutieId - ID of token to auction, sender must be owner.
    /// @param _parameter - arbitrary parameter
    function runSigned(
        uint40 _cutieId,
        uint256 _parameter,
        address _owner
    )
    external
    payable;

    function withdraw() public;
}

pragma solidity ^0.4.23;

pragma solidity ^0.4.23;

/// @title BlockchainCuties: Collectible and breedable cuties on the Ethereum blockchain.
/// @author https://BlockChainArchitect.io
/// @dev This is the BlockchainCuties configuration. It can be changed redeploying another version.
interface ConfigInterface
{
    function isConfig() external pure returns (bool);

    function getCooldownIndexFromGeneration(uint16 _generation, uint40 _cutieId) external view returns (uint16);
    
    function getCooldownEndTimeFromIndex(uint16 _cooldownIndex, uint40 _cutieId) external view returns (uint40);

    function getCooldownIndexCount() external view returns (uint256);

    function getBabyGenFromId(uint40 _momId, uint40 _dadId) external view returns (uint16);
    function getBabyGen(uint16 _momGen, uint16 _dadGen) external pure returns (uint16);

    function getTutorialBabyGen(uint16 _dadGen) external pure returns (uint16);

    function getBreedingFee(uint40 _momId, uint40 _dadId) external view returns (uint256);
}


contract CutieCoreInterface
{
    function isCutieCore() pure public returns (bool);

    ConfigInterface public config;

    function transferFrom(address _from, address _to, uint256 _cutieId) external;
    function transfer(address _to, uint256 _cutieId) external;

    function ownerOf(uint256 _cutieId)
        external
        view
        returns (address owner);

    function getCutie(uint40 _id)
        external
        view
        returns (
        uint256 genes,
        uint40 birthTime,
        uint40 cooldownEndTime,
        uint40 momId,
        uint40 dadId,
        uint16 cooldownIndex,
        uint16 generation
    );

    function getGenes(uint40 _id)
        public
        view
        returns (
        uint256 genes
    );


    function getCooldownEndTime(uint40 _id)
        public
        view
        returns (
        uint40 cooldownEndTime
    );

    function getCooldownIndex(uint40 _id)
        public
        view
        returns (
        uint16 cooldownIndex
    );


    function getGeneration(uint40 _id)
        public
        view
        returns (
        uint16 generation
    );

    function getOptional(uint40 _id)
        public
        view
        returns (
        uint64 optional
    );


    function changeGenes(
        uint40 _cutieId,
        uint256 _genes)
        public;

    function changeCooldownEndTime(
        uint40 _cutieId,
        uint40 _cooldownEndTime)
        public;

    function changeCooldownIndex(
        uint40 _cutieId,
        uint16 _cooldownIndex)
        public;

    function changeOptional(
        uint40 _cutieId,
        uint64 _optional)
        public;

    function changeGeneration(
        uint40 _cutieId,
        uint16 _generation)
        public;

    function createSaleAuction(
        uint40 _cutieId,
        uint128 _startPrice,
        uint128 _endPrice,
        uint40 _duration
    )
    public;

    function getApproved(uint256 _tokenId) external returns (address);
    function totalSupply() view external returns (uint256);
    function createPromoCutie(uint256 _genes, address _owner) external;
    function checkOwnerAndApprove(address _claimant, uint40 _cutieId, address _pluginsContract) external view;
}


contract Plugins is Ownable
{
    event SignUsed(uint40 signId, address sender);
    event MinSignSet(uint40 signId);

    uint40 public minSignId;
    mapping(uint40 => address) public usedSignes;
    address public signerAddress;
    mapping (address=>bool) operatorAddress;

    mapping(address => PluginInterface) public plugins;
    PluginInterface[] public pluginsArray;
    CutieCoreInterface public coreContract;

    function setSigner(address _newSigner) public onlyOwner {
        signerAddress = _newSigner;
    }

    function setOperator(address _newOperator) public onlyOwner {
        require(_newOperator != address(0));

        operatorAddress[_newOperator] = true;
    }

    function removeOperator(address _newOperator) public onlyOwner {
        delete(operatorAddress[_newOperator]);
    }

    modifier onlyOperator() {
        require(operatorAddress[msg.sender] || msg.sender == owner);
        _;
    }

    /// @dev Sets the reference to the plugin contract.
    /// @param _address - Address of plugin contract.
    function addPlugin(address _address) public onlyOwner
    {
        PluginInterface candidateContract = PluginInterface(_address);

        // verify that a contract is what we expect
        require(candidateContract.isPluginInterface());

        // Set the new contract address
        plugins[_address] = candidateContract;
        pluginsArray.push(candidateContract);
    }

    /// @dev Remove plugin and calls onRemove to cleanup
    function removePlugin(address _address) public onlyOwner
    {
        plugins[_address].onRemove();
        delete plugins[_address];

        uint256 kindex = 0;
        while (kindex < pluginsArray.length)
        {
            if (address(pluginsArray[kindex]) == _address)
            {
                pluginsArray[kindex] = pluginsArray[pluginsArray.length-1];
                pluginsArray.length--;
            }
            else
            {
                kindex++;
            }
        }
    }

    /// @dev Common function to be used also in backend
    function hashArguments(
        address _pluginAddress,
        uint40 _signId,
        uint40 _cutieId,
        uint128 _value,
        uint256 _parameter)
    public pure returns (bytes32 msgHash)
    {
        msgHash = keccak256(abi.encode(_pluginAddress, _signId, _cutieId, _value, _parameter));
    }

    /// @dev Common function to be used also in backend
    function getSigner(
        address _pluginAddress,
        uint40 _signId,
        uint40 _cutieId,
        uint128 _value,
        uint256 _parameter,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
    public pure returns (address)
    {
        bytes32 msgHash = hashArguments(_pluginAddress, _signId, _cutieId, _value, _parameter);
        return ecrecover(msgHash, _v, _r, _s);
    }

    /// @dev Common function to be used also in backend
    function isValidSignature(
        address _pluginAddress,
        uint40 _signId,
        uint40 _cutieId,
        uint128 _value,
        uint256 _parameter,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
    public
    view
    returns (bool)
    {
        return getSigner(_pluginAddress, _signId, _cutieId, _value, _parameter, _v, _r, _s) == signerAddress;
    }

    /// @dev Put a cutie up for plugin feature with signature.
    ///  Can be used for items equip, item sales and other features.
    ///  Signatures are generated by Operator role.
    function runPluginSigned(
        address _pluginAddress,
        uint40 _signId,
        uint40 _cutieId,
        uint128 _value,
        uint256 _parameter,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
//        whenNotPaused
        payable
    {
        require (isValidSignature(_pluginAddress, _signId, _cutieId, _value, _parameter, _v, _r, _s));

        require(address(plugins[_pluginAddress]) != address(0));

        require (usedSignes[_signId] == address(0));

        require (_signId >= minSignId);
        // value can also be zero for free calls

        require (_value <= msg.value);

        usedSignes[_signId] = msg.sender;

        if (_cutieId > 0)
        {
            // If cutie is already on any auction or in adventure, this will throw
            // as it will be owned by the other contract.
            // If _cutieId is 0, then cutie is not used on this feature.

            coreContract.checkOwnerAndApprove(msg.sender, _cutieId, _pluginAddress);
        }

        emit SignUsed(_signId, msg.sender);

        // Plugin contract throws if inputs are invalid and clears
        // transfer after escrowing the cutie.
        plugins[_pluginAddress].runSigned.value(_value)(
            _cutieId,
            _parameter,
            msg.sender
        );
    }

    /// @dev Sets minimal signId, than can be used.
    ///       All unused signatures less than signId will be cancelled on off-chain server
    ///       and unused items will be transfered back to owner.
    function setMinSign(uint40 _newMinSignId)
        public
        onlyOperator
    {
        require (_newMinSignId > minSignId);
        minSignId = _newMinSignId;
        emit MinSignSet(minSignId);
    }

    /// @dev Put a cutie up for plugin feature.
    function runPlugin(
        address _pluginAddress,
        uint40 _cutieId,
        uint256 _parameter
    )
        public
//        whenNotPaused
        payable
    {
        // If cutie is already on any auction or in adventure, this will throw
        // because it will be owned by the other contract.
        // If _cutieId is 0, then cutie is not used on this feature.
        require(address(plugins[_pluginAddress]) != address(0));
        if (_cutieId > 0)
        {
            coreContract.checkOwnerAndApprove(msg.sender, _cutieId, _pluginAddress);
        }

        // Plugin contract throws if inputs are invalid and clears
        // transfer after escrowing the cutie.
        plugins[_pluginAddress].run.value(msg.value)(
            _cutieId,
            _parameter,
            msg.sender
        );
    }

    function isPlugin(address contractAddress) external view returns(bool)
    {
        return address(plugins[contractAddress]) != address(0);
    }

    function setup(address _address) public onlyOwner
    {
        coreContract = CutieCoreInterface(_address);
    }

    function withdraw() external
    {
        require(msg.sender == address(coreContract));
        for (uint32 i = 0; i < pluginsArray.length; ++i)
        {
            pluginsArray[i].withdraw();
        }
    }
}
