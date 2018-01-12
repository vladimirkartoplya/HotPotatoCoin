pragma solidity ^0.4.18;

import "truffle/Assert.sol";
import "../contracts/HotPotato.sol";

contract TestHotPotato {

    HotPotato instance = new HotPotato();
    Intruder intruderContract = new Intruder(instance);

    uint256 public initialBalance = 10 finney;
    uint256 public potatoLifespan;
    uint256 public potatoIncrement;
    uint256 public potatoPeriod;
    uint256 public potatoPrice;
    uint256 public potatoNextPrice;
    uint256 public potatoPreviousPrice;
    uint256 public expectedPotatoCycle = 0;
    address public newPayoutAdress;

    /* 
        Anything here will be executed before each test.
    */
    function beforeEach() public {
        potatoLifespan = instance.getPotatoLifespan();
        potatoPeriod = potatoLifespan / 30;
    }

    /* 
        Used to increment the time in the contract.
        Simulates time passing.
    */
    function incNow(uint256 t) public {
        instance.setTestNow(instance.getNow() + t);
    }

    // Get the balance of this contract
    function getMyBalance() public constant returns (uint256) {
        return this.balance;
    }
    

    /* ACTUAL TESTS START HERE */

    // PRICE CHECK TESTS

    // Tests that the decimals are set to 18
    function testDecimals() public {
        uint expectedDecimals = 18;
        Assert.equal(instance.decimals(), expectedDecimals, "The decimals should be set to 18.");
    }

    // Tests that the decimals are set to 18
    function testDecimalsInPrice() public {
        uint256 expectedPriceInWei = 1000000000000;
        (potatoPrice, potatoNextPrice) = instance.getPrice();
        Assert.equal(potatoPrice, expectedPriceInWei, "The price in wei should be 1 trillion.");
    }

    // PAYOUT INIT TESTS

    // Tests defaults for the payout address for the contract
    function testInitPayoutAddress() public {
        Assert.isFalse(instance.getPayoutAddressSet(), "The payout address should not be set.");
        Assert.equal(instance.getPayoutAddress(), this, "Contract address should be the default payout address.");
    }

    // Tests attacking the payout address for the contract
    function testIntruderPayoutAddress() public {
        intruderContract.attackPayoutAddress();

        Assert.isFalse(instance.getPayoutAddressSet(), "The payout address should not be set by an intruder.");
        Assert.equal(instance.getPayoutAddress(), this, "Contract address should still be the default payout address.");
    }

    // Tests setting the payout address for the contract
    function testInitPayoutAddressSet() public {
        newPayoutAdress = 0x71289705A402443CBe51Fa2C50FB8bA41133bce8;
        
        instance.initPayoutAddress(newPayoutAdress);

        Assert.isTrue(instance.getPayoutAddressSet(), "The payout address should now be set.");
        Assert.equal(instance.getPayoutAddress(), newPayoutAdress, "The new payout address is incorrect.");
    }

    // Tests re-setting the payout address for the contract
    function testReInitPayoutAddress() public {
        Assert.isTrue(instance.getPayoutAddressSet(), "The payout address should now be set.");
        Assert.equal(instance.getPayoutAddress(), newPayoutAdress, "The new payout address is incorrect.");

        address newpaddress = 0xFc783c33FB956a4F4b05a33d8315801b9E74DF35;
        instance.initPayoutAddress(newpaddress);

        Assert.isTrue(instance.getPayoutAddressSet(), "The payout address should still be set.");
        Assert.equal(instance.getPayoutAddress(), newPayoutAdress, "The payout address should not change.");
    }


    // CYCLE 1 TESTS

    // Tests if the ETH collected counter is 0 upon creation
    function testGetEthReceivedAtCreation() public {
        Assert.isZero(instance.getTotalEthReceived(), "The TotalEthReceived counter should be 0.");
    }

    // Tests if the next price increase happens in the future
    function testGetNextPriceIncreaseTime() public {
        uint256 expected = 0;
        incNow(23);
        Assert.isAbove(instance.getNextPriceIncreaseTime(), expected, "Next price increase should be higher than 0.");
    }

    // Tests buying some HPCs
    function testBuying() public {
        // Buy tokens and send gas and ether
        bool result = instance.call.gas(200000).value(1 finney)(bytes4(keccak256("buy()")));
        Assert.isTrue(result, "The result of the buy() should be True.");
        Assert.isNotZero(instance.getTotalEthReceived(), "TotalEthReceived should be higher than 0");
    }

    // Checks the lifespan a HPC token
    function testPotatoLifespan() public {
        Assert.equal(potatoLifespan, (3600 * 24 * 30), "The lifespan of one HPC should be 30 days");
    }

    // Tests if next price is greater than current price
    function testNextPrice() public {
        (potatoPrice, potatoNextPrice) = instance.getPrice();
        Assert.isBelow(potatoPrice, potatoNextPrice, "NextPrice should he higher than CurrentPrice");
    }

    // Tests incrementation of the price period
    function testPricePeriodIncrement() public {
        // Increment time by a price period;
        incNow(potatoPeriod);
        Assert.equal(instance.getCurrentCycle(), expectedPotatoCycle, "The cycle has to stay the same.");

        // Test if previous price is smaller than current price and next price
        potatoPreviousPrice = potatoPrice;
        potatoPrice = potatoNextPrice;
        (potatoPrice, potatoNextPrice) = instance.getPrice();

        Assert.isAbove(potatoPrice, potatoPreviousPrice, "The current price should be higher than the previous");
        Assert.isAbove(potatoNextPrice, potatoPrice, "Next price should be higher than CurrentPrice");
    }

    // Tests the end of a cycle
    function testCycleEnd() public {
        // Increment time by 28 price periods
        incNow(potatoPeriod * 28);
        
        // Test if previous price is smaller than current price and next price is reset due to end of the cycle
        potatoPreviousPrice = potatoPrice;
        potatoPrice = potatoNextPrice;
        (potatoPrice, potatoNextPrice) = instance.getPrice();

        Assert.isAbove(potatoPrice, potatoPreviousPrice, "The current price should be higher than the previous");
        Assert.isBelow(potatoNextPrice, potatoPrice, "Next price should be reset and be lower than CurrentPrice");
    }

    // Test price reset
    function testPriceReset() public {
        // Increment time by a price period;
        incNow(potatoPeriod + 1);
        
        // Test if previous price is smaller than current price and next price
        (potatoPrice, potatoNextPrice) = instance.getPrice();

        // The cycle should be greater than before
        Assert.isAbove(potatoNextPrice, potatoPrice, "Next price should be reset and be lower than CurrentPrice");
    }

    // Test that the tokens were destroyed
    function testTokenSelfDestruct() public {
        Assert.isZero(instance.myBalance(), "The balance should be 0 after a cycle reset");
    }

    // Test that the tokens were indeed destroyed and will not respawn
    function testTokenNotRespawn() public {
        instance.cycleMe();
        Assert.isZero(instance.myBalance(), "The balance should be 0");
    }

    // Test price reset
    function testCycleReset() public {
        // Invoke a cycle increment
        instance.cycleMe();

        Assert.equal(instance.getCurrentCycle(), expectedPotatoCycle + 1, "The cycle should increase by 1");
    }

    /* 
        Tests if the ETH collected counter persisted
        throughout the change of cycles.
    */
    function testGetEthReceivedAfterCycle() public {
        Assert.isNotZero(instance.getTotalEthReceived(), "The TotalEthReceived counter should be > 0.");
    }

    function testRetestCycle1() public {
        expectedPotatoCycle = 1;
        testGetNextPriceIncreaseTime();
        testBuying();
        testPotatoLifespan();
        testNextPrice();
        testPricePeriodIncrement();
        testCycleEnd();
        testPriceReset();
        testTokenSelfDestruct();
        testTokenNotRespawn();
        testGetEthReceivedAfterCycle();
    }

    function testRetestCycle2() public {
        expectedPotatoCycle = 2;
        testGetNextPriceIncreaseTime();
        testBuying();
        testPotatoLifespan();
        testNextPrice();
        testPricePeriodIncrement();
        testCycleEnd();
        testPriceReset();
        testTokenSelfDestruct();
        testTokenNotRespawn();
        testGetEthReceivedAfterCycle();
    }


}

contract Intruder {

    HotPotato instance;

    function Intruder(HotPotato contractInstance) public {
        instance = contractInstance;
    }

    function attackPayoutAddress() external {
        instance.initPayoutAddress(this);
    }

}