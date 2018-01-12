pragma solidity^0.4.18;

/** @title Hot Potato Coin */
contract HotPotato {
    
    event Transfer(address _from, address _to, uint256 _value);
    event Approval(address _owner, address _spender, uint256 _value);
    

    mapping (address => mapping (address => uint256)) allowed;

    // Number of tokens per wallet
    mapping (address => uint256) balances;
    // Array of counters for cycleCounters for each wallet
    mapping (address => uint16) walletCycle;
    
    // Owner of the contract
    address owner;
    address payoutAddress;
    bool payoutAddressSet;

    // The amount of time a single token exists before it expires
    uint256 potatoLifespan;

    // The amount of time that needs to pass between two different price increases
    uint256 priceIncrementTimespan;

    // Number of tokens in circulation
    uint256 totalTokens;

    // Time at which the cycle ends
    uint256 deadline;

    // Current 30-day cycle counter
    uint16 cycleCounter;

    // Prices lookup table
    uint32[32] prices;

    // Contract balance - amount of ETH received
    uint256 weisum;
    
    // The amount that we have to multiply to get the correct price
    uint256 constant priceModifier = 1000000000;
    

    /** @dev The constructor - initializes the contract.
      */
    function HotPotato() public {
        
        owner = msg.sender;
        payoutAddress = msg.sender;
        payoutAddressSet = false;

        totalTokens = 0;
        cycleCounter = 0;
        weisum = 0;

        // Number of seconds in a 30-day period
        potatoLifespan = 3600 * 24 * 30;
        priceIncrementTimespan = potatoLifespan / 30;
        testNow = now;

        deadline = getNow() + potatoLifespan;
        
        prices = [
            1000, 1389, 1931, 2683, 3728, 5179, 7197, 
            10000, 13895, 19307, 26827, 37276, 51795, 71969, 
            100000, 138950, 193070, 268270, 372759, 517947, 719686, 
            1000000, 1389495, 1930698, 2682696, 3727594, 5179475, 7196857, 
            10000000, 13894955, 19306980
        ];

    }
    
    /** @dev Cycle Manager - Clears all the tokens from all the existing wallets if the cycle is over.
      * @param a Wallet address.
      */
    function cycleManager(address a) private {

        // If the deadline has expired
        if(getNow() > deadline) {
            // Wipe all the tokens
            totalTokens = 0;
            // Increment the deadline by the lifespan
            deadline = getNow() + potatoLifespan;
            // Increase the cycle counter - start new cycle
            cycleCounter++;
        }
        
        // Resets the cycles on the existing wallets
        if(walletCycle[a] != cycleCounter) {
            // Set the balance of the wallet to 0
            balances[a] = 0;
            walletCycle[a] = cycleCounter;
        }
        
        return;
    }
    
    /** @dev Calculates the price for a specific timestamp.
      * @param time Timestamp at which the price should be checked.
      * @return price The calculated price.
      */
    function calcPrice(uint256 time) private constant returns (uint256 price) {
        uint256 id;
        id = (potatoLifespan - (deadline - time)) / priceIncrementTimespan;
        id = id % 30;
        price = prices[id];
        return price;
    }
    
    /** @dev Gets called whenever a person wants to buy hot potatoes directly from the token sale.
      * @return boughtAmount The amount of tokens bought.
      * @return boughtAtPrice The price at which the token was bought.
      */
    function buy() public payable returns (uint256 boughtAmount, uint256 boughtAtPrice){

        // Check and update if any changes in the cycle happened
        cycleManager(msg.sender);

        uint256 amount;
        uint256 price;

        price = calcPrice(getNow());
        amount = (msg.value * priceModifier) / price;
        balances[msg.sender] += amount;
        totalTokens += amount;
        weisum += msg.value;

        return (amount,price);
    }
    
    /** @dev Returns the current price of a token on the token sale, price of a potato in wei.
      * @return currentPrice Current price.
      * @return nextPrice The price after the next price increase.
      */
    function getPrice() public constant returns (uint256 currentPrice, uint256 nextPrice) {
        uint256 curPrice = priceModifier * calcPrice(getNow());
        uint256 nxtPrice = priceModifier * calcPrice(getNow() + priceIncrementTimespan);
        return (curPrice, nxtPrice);
    }

    /** @dev Returns the timestamp of the deadline for the end of the current cycle.
      * @return deadlineTimestamp The timestamp.
      */
    function getDeadline() public constant returns (uint256 deadlineTimestamp) {
        return deadline;
    }

    /** @dev Returns the timestamp when the price of the tokens on the token sale will increase.
      * @return priceIncreaseTime The timestamp.
      */
    function getNextPriceIncreaseTime() public constant returns (uint256 priceIncreaseTime) {
        return ((deadline - getNow()) % priceIncrementTimespan);
    }

    /** @dev Returns the amount of ETH received during this token sale.
      * @return totalEthReceivedAmount The amount.
      */
    function getTotalEthReceived() public constant returns (uint256 totalEthReceivedAmount) {
        return weisum;
    }
    
    /** @dev Fetches the index of the current token sale cycle.
      * @return cycleIndex The cycle number.
      */
    function getCurrentCycle() public constant returns (uint16 cycleIndex) {
        return cycleCounter;
    }

    /** @dev Returns the lifespan of a token.
      * @return currentPotatoLifespan The lifespan (in seconds).
      */
    function getPotatoLifespan() public constant returns (uint256 currentPotatoLifespan) {
        return potatoLifespan;
    }
    
    // ************* FOR TESTING ONLY ***************
     
    uint256 testNow;
    
    function setTestNow(uint256 n) public {
        testNow = n;
    }
    
    function getNow() public constant returns (uint256 currentTime) {
        return now;
        // return testNow;
    }

    function cycleMe() public {
        cycleManager(msg.sender);
    }

    // ************* STANDARD ERC20 FUNCTIONS ***************
  
    function myBalance() public constant returns (uint256 userBalance) {

        //check if the wallet cycle matches the contract cycle
		if(walletCycle[msg.sender] != cycleCounter || getNow() > deadline)
			return 0;

        return balances[msg.sender];
    }
    
    function transfer(address _to, uint256 _value) public returns (bool success) {

        // Check and update if any changes in the cycle happened
        cycleManager(msg.sender);
        cycleManager(_to);

        if (balances[msg.sender] >= _value) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { 
            return false; 
        }
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {

        // Check and update if any changes in the cycle happened
        cycleManager(_from);
        cycleManager(_to);

        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { 
            return false; 
        }
    }
    
    function balanceOf(address _owner) public constant returns (uint256 balance) {

		//check if the wallet cycle matches the contract cycle
		if(walletCycle[_owner] != cycleCounter || getNow() > deadline)
			return 0;

        return balances[_owner];
    }
    
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public returns (uint256 remaining) {

        // Check and update if any changes in the cycle happened
        cycleManager(_spender);

        return allowed[_owner][_spender];
    }
    
    function name() public pure returns (string) {
        return "Hot Potato Coin";
    }
    
    function symbol() public pure returns (string) {
        return "HPO";
    }
    
    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public constant returns(uint256) {
        return totalTokens;
    }


    // ************** OWNER SPECIFIC FUNCTIONS ********************
    function initPayoutAddress(address designatedAddress) public {
        if (msg.sender == owner && !payoutAddressSet) {
            payoutAddressSet = true;
            payoutAddress = designatedAddress;
        }
    }
    function getPayoutAddress() public constant returns (address setAddress) {
        if(msg.sender == owner)
            return payoutAddress;
    }
    function getPayoutAddressSet() public constant returns (bool paSet) {
        if(msg.sender == owner) {
            return payoutAddressSet;
        } else {
            return true;
        }
    }
    function getContractBalance() public constant returns (uint256 contractBalance) {
        if(msg.sender == owner)
            return this.balance;
    }
    function withdrawAllEther() public payable {
        if(msg.sender == owner)
            payoutAddress.transfer(this.balance);
    }
    function withdrawEther(uint256 _value) public payable {
        if(msg.sender == owner)
            payoutAddress.transfer(_value); 
    }

}