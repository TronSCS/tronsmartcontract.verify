pragma solidity ^0.4.25;

interface HourglassInterfaceDiv {
    function donate() public payable;
}

contract LamboLottoGameTokenFunds{

    struct UserRecord {
        address referrer;
        uint tokens;
        uint gained_funds;
        uint ref_funds;
        uint game_funds;
        int funds_correction;
    }
    
    modifier onlyAdministrator(){
        
        require(msg.sender == admins_wallet);
        _;
    }
    
    modifier onlyOurGameContract(){
        
        address _contract_address = msg.sender;
        require(our_contract[_contract_address]);
        _;
    }    
    
    using SafeMath for uint;
    using SafeMathInt for int;
    using Fee for Fee.fee;
    
    string constant public name = "Lambo Lotto Game Token Fund";
    string constant public symbol = "LLGTF";
    uint8 constant public decimals = 6;
    
    Fee.fee private fee_purchase = Fee.fee(1, 10);
    Fee.fee private fee_selling  = Fee.fee(1, 20); 
    Fee.fee private fee_transfer = Fee.fee(1, 100);
    Fee.fee private fee_admin    = Fee.fee(6, 100); 
    Fee.fee private fee_referral = Fee.fee(33, 100);
        
    address private admins_wallet = msg.sender;
    uint private for_admin = 0;
        
    uint private price = 1e10; 
    uint private total_supply = 0;
    uint private for_old_token = 0; 
    uint constant private minimal_stake = 1e8;   
    uint constant private precision_factor = 1e6;
    uint constant private price_offset = 1e7;
    
    uint private shared_profit = 0;   
    uint public shared_profit_all = 0; 
    uint public shared_profit_day = 0;
    uint public shared_profit_day_timestamp = now;

    mapping(address => UserRecord) private user_data;
    mapping(address => bool) public our_contract;

    modifier onlyValidTokenAmount(uint tokens) {
        require(tokens > 0, "Amount of tokens must be greater than zero");
        require(tokens <= user_data[msg.sender].tokens, "You have not enough tokens");
        _;
    }
    
    address public constant _div_contract_address = 0x8e3dd86cecbbace8169650197aee87fba2b86b27; 
    HourglassInterfaceDiv constant div_contract = HourglassInterfaceDiv(_div_contract_address);

    function buy(address referrer) public payable {

        (uint fee_funds, uint taxed_funds) = fee_purchase.split(msg.value);
        require(fee_funds != 0, "Incoming funds is too small");
                
        UserRecord storage user = user_data[msg.sender];
        if (referrer != 0x0 && referrer != msg.sender && user.referrer == 0x0) {
            user.referrer = referrer;
        }

        if (user.referrer != 0x0) {
            fee_funds = rewardReferrer(msg.sender, user.referrer, fee_funds, msg.value);
            require(fee_funds != 0, "Incoming funds is too small");
        }

        for_old_token += fee_funds.div(2); 
        
        if(for_old_token >= 1e8)    
        { 
            div_contract.donate.value(for_old_token)();
            for_old_token = 0;
        }  
                
        (uint admin_fee_funds, ) = fee_admin.split(msg.value);
        
        for_admin += admin_fee_funds;
        
        if(for_admin >= 1e8) {    
            admins_wallet.transfer(for_admin);
            for_admin = 0;
        }
        
        (uint tokens, uint _price) = fundsToTokens(taxed_funds);
        require(tokens != 0, "Incoming funds is too small");
               
        price = _price;

        mintTokens(msg.sender, tokens);
        
        shared_profit = shared_profit.add(fee_funds.div(2));
        shared_profit_day = shared_profit_day.add(fee_funds);
        shared_profit_all = shared_profit_all.add(fee_funds);
        
        if(shared_profit_day_timestamp + 24 hours < now)
            {
                shared_profit_day = 0;
                shared_profit_day_timestamp = now;
            }        
        
        emit Purchase(msg.sender, msg.value, tokens, price / precision_factor, now);
    }

    function sell(uint tokens) public onlyValidTokenAmount(tokens) {
        
        (uint funds, uint _price) = tokensToFunds(tokens);
        require(funds != 0, "Insufficient tokens to do that");
        price = _price;

        (uint fee_funds, uint taxed_funds) = fee_selling.split(funds);
        require(fee_funds != 0, "Insufficient tokens to do that");

        burnTokens(msg.sender, tokens);
        UserRecord storage user = user_data[msg.sender];
        user.gained_funds = user.gained_funds.add(taxed_funds);

        shared_profit = shared_profit.add(fee_funds);

        emit Selling(msg.sender, tokens, funds, price / precision_factor, now);
    }

    function transfer(address to_addr, uint tokens) public onlyValidTokenAmount(tokens) returns (bool success) {

        require(to_addr != msg.sender, "You cannot transfer tokens to yourself");

        (uint fee_tokens, uint taxed_tokens) = fee_transfer.split(tokens);
        require(fee_tokens != 0, "Insufficient tokens to do that");

        (uint funds, ) = tokensToFunds(fee_tokens);
        require(funds != 0, "Insufficient tokens to do that");

        burnTokens(msg.sender, tokens);
        mintTokens(to_addr, taxed_tokens);

        shared_profit = shared_profit.add(funds);
        shared_profit_day = shared_profit_day.add(funds);
        shared_profit_all = shared_profit_all.add(funds);
        if(shared_profit_day_timestamp + 24 hours < now) {
                shared_profit_day = 0;
                shared_profit_day_timestamp = now;
            } 
        
        emit Transfer(msg.sender, to_addr, tokens);
        return true;
    }

    function reinvest() public {

        uint funds = dividendsOf(msg.sender);
        require(funds > 0, "You have no dividends");

        UserRecord storage user = user_data[msg.sender];
        user.funds_correction = user.funds_correction.add(int(funds));

        (uint fee_funds, uint taxed_funds) = fee_purchase.split(funds);
        require(fee_funds != 0, "Insufficient dividends to do that");

        if (user.referrer != 0x0) {
            fee_funds = rewardReferrer(msg.sender, user.referrer, fee_funds, funds);
            require(fee_funds != 0, "Insufficient dividends to do that");
        }

        (uint tokens, uint _price) = fundsToTokens(taxed_funds);
        require(tokens != 0, "Insufficient dividends to do that");
        
        price = _price;

        mintTokens(msg.sender, tokens);
        
        shared_profit = shared_profit.add(fee_funds);
        shared_profit_day = shared_profit_day.add(fee_funds);
        shared_profit_all = shared_profit_all.add(fee_funds);
        if(shared_profit_day_timestamp + 24 hours < now) {
                shared_profit_day = 0;
                shared_profit_day_timestamp = now;
            } 
        
        emit Reinvestment(msg.sender, funds, tokens, price / precision_factor, now);
    }

    function withdraw() public {
        
        uint funds = dividendsOf(msg.sender);
        require(funds > 0, "You have no dividends");

        UserRecord storage user = user_data[msg.sender];
        user.funds_correction = user.funds_correction.add(int(funds));

        msg.sender.transfer(funds);

        emit Withdrawal(msg.sender, funds, now);
    }

    function exit() public {

        uint tokens = user_data[msg.sender].tokens;
        if (tokens > 0) {
            sell(tokens);
        }

        withdraw();
    }

    function donate() public payable {
        shared_profit = shared_profit.add(msg.value);
        shared_profit_day = shared_profit_day.add(msg.value);
        shared_profit_all = shared_profit_all.add(msg.value);
        if(shared_profit_day_timestamp + 24 hours < now) {
                shared_profit_day = 0;
                shared_profit_day_timestamp = now;
            }         
        
        emit Donation(msg.sender, msg.value, now);
    }

    function totalSupply() public view returns (uint) {
        return total_supply;
    }

    function balanceOf(address addr) public view returns (uint) {
        return user_data[addr].tokens;
    }

    function dividendsOf(address addr) public view returns (uint) {

        UserRecord memory user = user_data[addr];

        int d = int(user.gained_funds.add(user.ref_funds));
        require(d >= 0);

        if (total_supply > 0) {
            d = d.add(int(shared_profit.mul(user.tokens) / total_supply));
        }

        if (user.funds_correction > 0) {
            d = d.sub(user.funds_correction);
        }
        else if (user.funds_correction < 0) {
            d = d.add(-user.funds_correction);
        }

        require(d >= 0);

        return uint(d);
    }
    
    function dividendsFromPlayGame(address addr) public view returns (uint) {

        UserRecord memory user = user_data[addr];
        return user.game_funds;
    }    

    function expectedTokens(uint funds, bool apply_fee) public view returns (uint) {
        if (funds == 0) {
            return 0;
        }
        if (apply_fee) {
            (,uint _funds) = fee_purchase.split(funds);
            funds = _funds;
        }
        (uint tokens, ) = fundsToTokens(funds);
        return tokens;
    }

    function expectedFunds(uint tokens) public view returns (uint) {
        if (tokens == 0 || total_supply == 0) {
            return 0;
        }
        else if (tokens > total_supply) {
            tokens = total_supply;
        }
        (uint funds,) = tokensToFunds(tokens);
        
        return funds;
    }

    function buyPrice() public view returns (uint) {
        return price / precision_factor;
    }

    function sellPrice() public view returns (uint) {
         return price.sub(price_offset) / precision_factor;
    }

    function mintTokens(address addr, uint tokens) internal {
                
        UserRecord storage user = user_data[addr];

        bool not_first_minting = total_supply > 0;

        if (not_first_minting) {
            shared_profit = shared_profit.mul(total_supply.add(tokens)) / total_supply;
        }

        total_supply = total_supply.add(tokens);
        user.tokens = user.tokens.add(tokens);

        if (not_first_minting) {
            user.funds_correction = user.funds_correction.add(int(tokens.mul(shared_profit) / total_supply));
        }
    }  
    
    function burnTokens(address addr, uint tokens) internal {

        UserRecord storage user = user_data[addr];

        uint dividends_from_tokens = 0;
        if (total_supply == tokens) {
            dividends_from_tokens = shared_profit.mul(user.tokens) / total_supply;
        }

        shared_profit = shared_profit.mul(total_supply.sub(tokens)) / total_supply;

        total_supply = total_supply.sub(tokens);
        user.tokens = user.tokens.sub(tokens);

        if (total_supply > 0) {
            user.funds_correction = user.funds_correction.sub(int(tokens.mul(shared_profit) / total_supply));
        }        
        else if (dividends_from_tokens != 0) {
            user.funds_correction = user.funds_correction.sub(int(dividends_from_tokens));
        }
    }
    
    function addGameFunds(address player, uint value, address referrer) 
        onlyOurGameContract()
        external{
            
        require(value != 0, "Incoming funds is too small");            
        UserRecord storage user = user_data[player];            
       
        if (referrer != 0x0 && referrer != player && user.referrer == 0x0) {
            user.referrer = referrer;
        }   
            
        (uint fee_funds, ) = fee_purchase.split(value.div(10));
        uint taxed_funds = value;
        
        if (user.referrer != 0x0) {
            uint ref_funds = rewardReferrer(player, user.referrer, fee_funds, taxed_funds);            
            require(ref_funds != 0, "Incoming funds is too small");

            if(ref_funds!=fee_funds) {
                taxed_funds -= ref_funds;
                shared_profit -= ref_funds;
                }
        }            
            
        user.game_funds += taxed_funds;   
    }
  
    function buyGameToken() public {

        UserRecord storage user = user_data[msg.sender];
        require(user.game_funds != 0, "Incoming funds is too small");
        
        (uint tokens, uint _price) = fundsToTokens(user.game_funds.div(100));
        require(tokens != 0, "Incoming funds is too small");
        
        price = _price;
       
        user.game_funds = 0;
        mintTokens(msg.sender, tokens);
        emit Purchase(msg.sender, user.game_funds, tokens, price / precision_factor, now);
    }    
    
    function rewardReferrer(address addr, address referrer_addr, uint funds, uint full_funds) internal returns (uint funds_after_reward) {
        UserRecord storage referrer = user_data[referrer_addr];
        if (referrer.tokens >= minimal_stake) {
            (uint reward_funds, uint taxed_funds) = fee_referral.split(funds);
            referrer.ref_funds = referrer.ref_funds.add(reward_funds);
            emit ReferralReward(addr, referrer_addr, full_funds, reward_funds, now);
            return taxed_funds;
        }
        else {
            return funds;
        }
    }
    
    function fundsToTokens(uint funds) internal view returns (uint tokens, uint _price) {
        uint b = price.mul(2).sub(price_offset);
        uint D = b.mul(b).add(price_offset.mul(8).mul(funds).mul(precision_factor));
        uint n = D.sqrt().sub(b).mul(precision_factor) / price_offset.mul(2);
        uint anp1 = price.add(price_offset.mul(n) / precision_factor);
        return (n, anp1);
    }

    function tokensToFunds(uint tokens) internal view returns (uint funds, uint _price) {
        uint sell_price = price.sub(price_offset);
        uint an = sell_price.add(price_offset).sub(price_offset.mul(tokens) / precision_factor);
        uint sn = sell_price.add(an).mul(tokens) / precision_factor.mul(2);
        return (sn / precision_factor, an);
    }
    
    function setAdminWallet(address _newAdmW)
        onlyAdministrator()
        public{            
        admins_wallet =  _newAdmW;
    } 
    
    function setDayTimestamp(uint _newSPDT)
        onlyAdministrator()
        public{            
        shared_profit_day_timestamp =  _newSPDT;
    }   
    
    function setGameContract(address _identifier, bool _status)
        onlyAdministrator()
        public{
        our_contract[_identifier] = _status;
    }    


    event Purchase(address indexed addr, uint funds, uint tokens, uint price, uint time);
    event Selling(address indexed addr, uint tokens, uint funds, uint price, uint time);
    event Reinvestment(address indexed addr, uint funds, uint tokens, uint price, uint time);
    event Withdrawal(address indexed addr, uint funds, uint time);
    event Donation(address indexed addr, uint funds, uint time);
    event ReferralReward(address indexed referral_addr, address indexed referrer_addr, uint funds, uint reward_funds, uint time);
    event Transfer(address indexed from_addr, address indexed to_addr, uint tokens);

}

library SafeMath {

    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "mul failed");
        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        require(b <= a, "sub failed");
        return a - b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }

    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "add failed");
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    } 
    
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = add(x, 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = add(x / z, z) / 2;
        }
    }
}

library SafeMathInt {

    function sub(int a, int b) internal pure returns (int) {
        int c = a - b;
        require(c <= a, "sub failed");
        return c;
    }

    function add(int a, int b) internal pure returns (int) {
        int c = a + b;
        require(c >= a, "add failed");
        return c;
    }
}

library Fee {

    using SafeMath for uint;

    struct fee {
        uint num;
        uint den;
    }

    function split(fee memory f, uint value) internal pure returns (uint tax, uint taxed_value) {
        if (value == 0) {
            return (0, 0);
        }
        tax = value.mul(f.num) / f.den;
        taxed_value = value.sub(tax);
    }

    function get_tax(fee memory f, uint value) internal pure returns (uint tax) {
        if (value == 0) {
            return 0;
        }
        tax = value.mul(f.num) / f.den;
    }
}