pragma solidity ^0.4.11;

/**
* @author Jefferson Davis
* ThankUcoin_ICO.sol creates the client's token for crowdsale and provides a mint token function
*   Crowdsale contracts edited from original contract code at https://www.ethereum.org/crowdsale#crowdfund-your-idea
*   Additional crowdsale contracts, functions, libraries from OpenZeppelin
*       at https://github.com/OpenZeppelin/zeppelin-solidity/tree/master/contracts/token
*   Token contract edited from original contract code at https://www.ethereum.org/token
*   ERC20 interface and certain token functions adapted from https://github.com/ConsenSys/Tokens
**/

contract ERC20 {
	//Sets events and functions for ERC20 token
	event Approval(address indexed _owner, address indexed _spender, uint _value);
	event Transfer(address indexed _from, address indexed _to, uint _value);
	
    function allowance(address _owner, address _spender) constant returns (uint remaining);
	function approve(address _spender, uint _value) returns (bool success);
    function balanceOf(address _owner) constant returns (uint balance);
    function transfer(address _to, uint _value) returns (bool success);
    function transferFrom(address _from, address _to, uint _value) returns (bool success);
}


contract Owned {
	//Public variable
    address public owner;

	//Sets contract creator as the owner
    function Owned() {
        owner = msg.sender;
    }
	
	//Sets onlyOwner modifier for specified functions
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

	//Allows for transfer of contract ownership
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}


library SafeMath {
    function add(uint256 a, uint256 b) internal returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }  

    function div(uint256 a, uint256 b) internal returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function max64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a >= b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a < b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a < b ? a : b;
    }
  
    function mul(uint256 a, uint256 b) internal returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function sub(uint256 a, uint256 b) internal returns (uint256) {
        assert(b <= a);
        return a - b;
    }
}


contract ThankUcoin is ERC20, Owned {
    //Applies SafeMath library to uint256 operations 
    using SafeMath for uint256;

	//Public variables
	string public name; 
	string public symbol; 
	uint256 public decimals;  
	uint256 public totalSupply; 

    //Variables
    uint256 multiplier; 
	
	//Creates arrays for balances
    mapping (address => uint256) balance;
    mapping (address => mapping (address => uint256)) allowed;

    //Creates modifier to prevent short address attack
    modifier onlyPayloadSize(uint size) {
        if(msg.data.length < size + 4) revert();
        _;
    }

	//Constructor
	function ThankUcoin(string tokenName, string tokenSymbol, uint8 decimalUnits, uint256 decimalMultiplier) {
		name = tokenName; 
		symbol = tokenSymbol; 
		decimals = decimalUnits; 
        multiplier = decimalMultiplier;  
	}
	
	//Provides the remaining balance of approved tokens from function approve 
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

	//Allows for a certain amount of tokens to be spent on behalf of the account owner
    function approve(address _spender, uint256 _value) returns (bool success) {
        uint256 amount = _value.mul(multiplier); 
        allowed[msg.sender][_spender] = amount;
        Approval(msg.sender, _spender, amount);
        return true;
    }

	//Returns the account balance 
    function balanceOf(address _owner) constant returns (uint256 remainingBalance) {
        return balance[_owner];
    }

    //Allows contract owner to mint new tokens, prevents numerical overflow
	function mintToken(address target, uint256 mintedAmount) onlyOwner returns (bool success) {
		require(mintedAmount > 0); 
        uint256 addTokens = mintedAmount.mul(multiplier); 
		balance[target] += addTokens;
		totalSupply += addTokens;
		Transfer(0, target, addTokens);
		return true; 
	}

	//Sends tokens from sender's account
    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) returns (bool success) {
        uint256 amount = _value.mul(multiplier); 
        if ((balance[msg.sender] >= amount) && (balance[_to] + amount > balance[_to])) {
            balance[msg.sender] -= amount;
            balance[_to] += amount;
            Transfer(msg.sender, _to, amount);
            return true;
        } else { 
			return false; 
		}
    }
	
	//Transfers tokens from an approved account 
    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) returns (bool success) {
        uint256 amount = _value.mul(multiplier); 
        if ((balance[_from] >= amount) && (allowed[_from][msg.sender] >= amount) && (balance[_to] + amount > balance[_to])) {
            balance[_to] += amount;
            balance[_from] -= amount;
            allowed[_from][msg.sender] -= amount;
            Transfer(_from, _to, amount);
            return true;
        } else { 
			return false; 
		}
    }
}


contract ThankUcoinICO is Owned, ThankUcoin {
    //Applies SafeMath library to uint256 operations 
    using SafeMath for uint256;

    //Public Variables
    address public multiSigWallet;                  
    uint256 public amountRaised; 
    uint256 public startTime; 
    uint256 public stopTime; 
    uint256 public price;                            

    //Variables
    bool crowdsaleClosed = true;                    
    string tokenName = "ThankUcoin"; 
    string tokenSymbol = "THKU"; 
    uint256 multiplier = 1000; 
    uint8 decimalUnits = 3;  

    

   	//Initializes the token
	function ThankUcoinICO() 
    	ThankUcoin(tokenName, tokenSymbol, decimalUnits, multiplier) {   
            multiSigWallet = msg.sender;        
    }

    //Fallback function creates tokens and sends to investor when crowdsale is open
    function () payable {
        require((!crowdsaleClosed) && (now < stopTime)); 
        address recipient = msg.sender; 
        amountRaised = amountRaised.add(msg.value.div(1 ether)); 
        uint256 tokens = msg.value.mul(getPrice()).mul(multiplier).div(1 ether);
        totalSupply = totalSupply.add(tokens);
        balance[recipient] = balance[recipient].add(tokens);
        require(multiSigWallet.send(msg.value)); 
        Transfer(0, recipient, tokens);
    }   

    //Returns the current price of the token for the crowdsale
    function getPrice() returns (uint256 result) {
        return price;
    }

    //Sets the multisig wallet for a crowdsale
    function setMultiSigWallet(address wallet) onlyOwner returns (bool success) {
        multiSigWallet = wallet; 
        return true; 
    }

    //Sets the token price 
    function setPrice(uint256 newPriceperEther) onlyOwner returns (uint256) {
        require(newPriceperEther > 0); 
        price = newPriceperEther; 
        return price; 
    }

    //Allows owner to start the crowdsale from the time of execution until a specified stopTime
    function startSale(uint256 price, uint256 saleStart, uint256 saleStop, address beneficiaryAccount) onlyOwner returns (bool success) {
        require(saleStop > now);     
        startTime = saleStart; 
        stopTime = saleStop; 
        price = setPrice(price); 
        crowdsaleClosed = false; 
        setMultiSigWallet(beneficiaryAccount); 
        return true; 
    }

    //Allows owner to stop the crowdsale immediately
    function stopSale() onlyOwner returns (bool success) {
        stopTime = now; 
        crowdsaleClosed = true;
        return true; 
    }
}


