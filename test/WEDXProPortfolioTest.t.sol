// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/WEDXDeployerPro.sol";
import "../contracts/WEDXDeployerIndex.sol";
import "../contracts/WEDXProPortfolio.sol";
import "../contracts/WEDXIndexPortfolio.sol";
import "../contracts/WEDXGroup.sol";
import "../contracts/WEDXswap.sol";
import "../contracts/WEDXlender.sol";
import "../contracts/WEDXManager.sol";
import "../contracts/WEDXRanker.sol";
import "../contracts/WEDXTreasury.sol";
import "../contracts/WEDXConstants.sol";

contract WEDXProPortfolioTest is Test {
    WEDXDeployerPro deployerPro;
    WEDXDeployerIndex deployerIndex;
    WEDXGroup wedxGroup;
    WEDXswap wedxSwap;
    WEDXlender wedxLender;
    WEDXManager wedxManager;
    WEDXRanker wedxRanker;
    WEDXTreasury wedxTreasury;
    WEDXConstants wedxConstants;
    address proPortfolioAddress;
    address indexPortfolioAddress;
    MaliciousContract maliciousPro;
    address owner = address(this);

    function setUp() public {
        // Deploy the WEDXGroup contract
        wedxGroup = new WEDXGroup(owner);
        address wedxGroupAddress = address(wedxGroup);

        // Deploy the other necessary contracts
        wedxSwap = new WEDXswap();
        wedxLender = new WEDXlender();
        wedxManager = new WEDXManager();
        wedxRanker = new WEDXRanker();
        wedxTreasury = new WEDXTreasury();

        // Update WEDXGroup with the addresses of the deployed contracts
        wedxGroup.changeManagerAddress(address(wedxManager));
        wedxGroup.changeSwapContractAddress(address(wedxSwap));
        wedxGroup.changeLenderContractAddress(address(wedxLender));
        wedxGroup.changeRankAddress(address(wedxRanker));
        wedxGroup.changeTreasuryAddress(address(wedxTreasury));

        // Deploy the WEDXDeployerPro contract
        deployerPro = new WEDXDeployerPro();

        // Update WEDXGroup with the addresses of the deployer contracts
        wedxGroup.changeDeployerProAddress(address(deployerPro));

        // Create the pro portfolio using the deployerPro
        vm.startPrank(owner);
        deployerPro.createProPortfolio();
        proPortfolioAddress = deployerPro.getUserProPortfolioAddress(owner);
        vm.stopPrank();

        // Deploy the malicious contracts
        maliciousPro = new MaliciousContract(WEDXProPortfolio(payable(proPortfolioAddress)));

        // Deal Ether to the portfolios and malicious contracts for testing
        vm.deal(proPortfolioAddress, 10 ether);
        vm.deal(address(maliciousPro), 1 ether);
    }




    function testBasicDepositReflectsInCWETH() public {
        address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);
        uint256 depositAmount = 1 ether;

        console.log("Initial Balance in cWNATIVE:", initialBalance);

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result",result);

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertTrue(finalBalance > initialBalance, "Final balance in cWNATIVE should be greater than initial balance after deposit");
    }



    function testDepositWithSimpleFee() public {
        address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);
        uint256 depositAmount = 1 ether;

        console.log("Initial Balance in cWNATIVE:", initialBalance);

        uint256 feePercentage = 100; 
        uint256 distroNorm = 10000;  

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress(),
            abi.encodeWithSelector(IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee.selector),
            abi.encode(feePercentage)
        );

        uint256 fee = (depositAmount * feePercentage) / distroNorm;
        uint256 expectedDepositAmount = depositAmount - fee;

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getTreasuryAddress(),
            abi.encodeWithSelector(IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee.selector),
            abi.encode()
        );

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result", result);

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertApproxEqRel(result, expectedDepositAmount, 1e16); // 1% de tolerancia

        assertTrue(finalBalance > initialBalance, "Final balance in cWNATIVE should be greater than initial balance after deposit");
    }



    function testWithdraw() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        
        uint256 initialBalance = address(proPortfolioAddress).balance;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdraw(withdrawAmount);

        uint256 finalBalance = address(proPortfolioAddress).balance;

        // assertEq(finalBalance, initialBalance - withdrawAmount);
    }

    function testProWithdrawBruteForcedReentrancy() public {
        uint256 depositAmount = 1 ether;

        // Attempt to exploit reentrancy in pro portfolio
        // vm.expectRevert("Withdrawal failed");
        vm.prank(owner);
        maliciousPro.attack{value: depositAmount}();

        // Ensure the balance is not drained
        uint256 finalBalance = address(proPortfolioAddress).balance;
        assertEq(finalBalance, 10 ether);  // Ensure the balance is not drained
    }


    function testBasicWithdraw() public {
        address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        uint256 depositAmount = 2 ether;
        uint256 withdrawAmount = 1 ether;

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result", result);
        
        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Initial Balance in cWNATIVE:", initialBalance);

        uint256 feePercentage = 100; // Esto representa 1% cuando distroNorm = 10000
        uint256 distroNorm = 10000;  // Basado en tu contrato
        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress(),
            abi.encodeWithSelector(IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee.selector),
            abi.encode(feePercentage)
        );

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getTreasuryAddress(),
            abi.encodeWithSelector(IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee.selector),
            abi.encode()
        );

        vm.warp(block.timestamp + 30 days);
        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdraw(withdrawAmount);

        uint256 fee = (withdrawAmount * feePercentage) / distroNorm;
        uint256 expectedWithdrawAmount = withdrawAmount - fee;

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertTrue(finalBalance < initialBalance, "Final balance in cWNATIVE should be less than initial balance after withdrawal");

        assertApproxEqRel(finalBalance, initialBalance - withdrawAmount, 1e16); // 1% de tolerancia
    }




function testBasicWithdrawBruteForcedReflectsInCWETH() public {
    // Dirección de cWNATIVE según tu inicialización
    address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 depositAmount = 2 ether; // Primero, depositamos 2 ether para asegurarnos de tener suficiente balance para retirar.
    
    // Realizar el depósito inicial
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

    // Obtener el balance inicial en cWNATIVE después del depósito
    uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

    // Log del balance inicial en cWNATIVE después del depósito
    console.log("Initial Balance in cWNATIVE after deposit:", initialBalance);

    // Realizar la retirada forzada
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).withdrawBruteForced();

    uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

    // Log del balance final en cWNATIVE después de la retirada forzada
    console.log("Final Balance in cWNATIVE after withdrawBruteForced:", finalBalance);

    // Verificar que el balance final es menor que el balance inicial después de la retirada forzada
    assertTrue(finalBalance < initialBalance, "Final balance in cWNATIVE should be less than initial balance after withdrawBruteForced");
}


/* En el caso de que tenga liqueidez el pool seria correcto
Fail in:
 1. require( validArrays, "Arrays and Fees are not valid" ); 
 2. require( ex.liquidity > 0, "No valid pool to perform the compute amount" );
 */

function testSimpleSetPortfolio() public {

    address[] memory newAssets = new address[](4);
    newAssets[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    newAssets[1] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
    newAssets[2] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    newAssets[3] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT

    uint256[] memory newDistribution = new uint256[](5);
    newDistribution[0] = 250000; // 25% USDC
    newDistribution[1] = 250000; // 25% DAI
    newDistribution[2] = 250000; // 25% WETH
    newDistribution[3] = 250000; // 25% USDT
    // newDistribution[4] = 0;      // 0% Native asset

    uint256[] memory normalizedDistribution = distroMath.normalize(newDistribution);

    for (uint i = 0; i < newAssets.length; i++) {
        console.log("Asset", i, ":", newAssets[i]);
    }
    for (uint i = 0; i < normalizedDistribution.length; i++) {
        console.log("Distribution", i, ":", normalizedDistribution[i]);
    }

    vm.prank(owner);
    uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).setPortfolio(newAssets, normalizedDistribution);

    console.log("setPortfolio result:", result);

    console.log("Test setPortfolio completed successfully.");
}

/* Deposited 1 WETH into the portfolio.
Verified the balance after the deposit.
Lent out the deposited WETH using supplyLendToken.
Verified that the final balance in the portfolio is 0 after lending out the WETH.
 */
function testSupplyLendToken() public {
    address tokenAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH for example
    uint256 depositAmount = 1 ether; // 1 WETH deposit
    uint256 lendAmount = depositAmount;

    // Realizar el depósito inicial para asegurar que hay balance
    uint256 initialBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Initial Balance in proPortfolioAddress:", initialBalance);

    vm.prank(owner);
    uint256 depositResult = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
    console.log("Deposit result:", depositResult);

    uint256 balanceAfterDeposit = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Balance after deposit in proPortfolioAddress:", balanceAfterDeposit);

    // Mock the calls to verify that the loan is possible
    address lenderContractAddress = wedxGroup.getLenderContractAddress();

    // Call the function to test
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).supplyLendToken(tokenAddress);

    // Verify the final balance using IWETH9 interface
    uint256 finalBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Final Balance in proPortfolioAddress:", finalBalance);

    // Assert the totalAssets balance is 0 after lending
    assertEq(finalBalance, 0, "Token balance should be 0 after lending");

    // Simple assert to check if the function executed without reverting
    assert(true);

    // Log message to indicate the test completed successfully
    console.log("Test supplyLendToken completed successfully.");
}

/*Deposited 1 WETH into the portfolio.
Lent out the WETH using supplyLendToken.
Withdrawn the lent WETH using withdrawLendToken.
Verified that the final balance in the portfolio is almost equal to the initial deposit, accounting for a small fee.
 */
function testWithdrawLendToken() public {
    address tokenAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH for example
    uint256 depositAmount = 1 ether; // 1 WETH deposit
    uint256 lendAmount = depositAmount;

    // Step 1: Deposit the initial amount
    uint256 initialBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Initial Balance in proPortfolioAddress:", initialBalance);

    vm.prank(owner);
    uint256 depositResult = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
    console.log("Deposit result:", depositResult);

    uint256 balanceAfterDeposit = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Balance after deposit in proPortfolioAddress:", balanceAfterDeposit);

    // Mock the calls to verify that the loan is possible
    address lenderContractAddress = wedxGroup.getLenderContractAddress();

    // Step 2: Lend the token
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).supplyLendToken(tokenAddress);

    // Verify the balance after lending
    uint256 balanceAfterLending = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Balance after lending in proPortfolioAddress:", balanceAfterLending);
    assertEq(balanceAfterLending, 0, "Token balance should be 0 after lending");

    // Step 3: Withdraw the lent token
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).withdrawLendToken(tokenAddress);

    // Verify the final balance using IWETH9 interface
    uint256 finalBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
    console.log("Final Balance in proPortfolioAddress:", finalBalance);

    // Assert the totalAssets balance is equal to the initial amount after withdrawing
    uint256 tolerance = 0.01 ether; // Set tolerance to 0.01 ether (1% tolerance)
    assertApproxEqRel(finalBalance, depositAmount, tolerance);
    // Simple assert to check if the function executed without reverting
    assert(true);

    // Log message to indicate the test completed successfully
    console.log("Test withdrawLendToken completed successfully.");
}

function testRankMe() public {
    // Mock the call to computeRanking to ensure it is called with the correct parameters
    address assetManagerAddress = wedxGroup.getAssetManagerAddress();
    vm.mockCall(
        assetManagerAddress,
        abi.encodeWithSelector(IWEDXManager.computeRanking.selector, owner),
        abi.encode()
    );

    // Call the function to test
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).rankMe();

    // Log message to indicate the test completed successfully
    console.log("Test rankMe completed successfully.");
}

function testSetMinPercAllowance() public {
    uint256 newPerc = 5000; // Example new percentage

    // Call the function to test
    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).setMinPercAllowance(newPerc);

    // Log message to indicate the test completed successfully
    console.log("Test setMinPercAllowance completed successfully.");
}

function testGetActualDistribution() public {
    // Step 1: Set up initial assets
    address[] memory newAssets = new address[](1);
    newAssets[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC

    uint256 initialAmount = 250000 * 1e6; // 250,000 USDC

    // Step 2: Perform a deposit to ensure there is an initial balance
    address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WNATIVE address
    uint256 depositAmount = 1 ether;

    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

    // Step 3: Mock the totalAssets mapping
    bytes32 slot = keccak256(abi.encode(newAssets[0], uint256(2)));
    vm.store(proPortfolioAddress, slot, bytes32(initialAmount));

    // Step 4: Mock external contract calls
    vm.mockCall(
        wedxGroup.getLenderContractAddress(),
        abi.encodeWithSelector(IWEDXlender.getTokenBalance.selector, newAssets[0], proPortfolioAddress),
        abi.encode(initialAmount)
    );
    vm.mockCall(
        wedxGroup.getSwapContractAddress(),
        abi.encodeWithSelector(IWEDXswap.getTokenAmount.selector, newAssets[0], WNATIVE, initialAmount),
        abi.encode(initialAmount)
    );

    // Step 5: Call getActualDistribution
    vm.prank(owner);
    uint256[] memory actualDistribution = WEDXProPortfolio(payable(proPortfolioAddress)).getActualDistribution();

    // Step 6: Verify the distribution
    // Check that the length of the distribution is correct
    assertEq(actualDistribution.length, 1, "Distribution array length mismatch");

    // Check that the distribution value is non-zero
    assertTrue(actualDistribution[0] > 0, "Distribution value should be non-zero");
}



function testGetAssetsExtended() public {
    // Step 1: Set up initial assets and their amounts
    address[] memory newAssets = new address[](3);
    newAssets[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // cWNATIVEAddress


    uint256[] memory amounts = new uint256[](3);
    amounts[0] = 1000 * 1e6; // 1000 USDC
    amounts[1] = 2000 * 1e18; // 2000 DAI
    amounts[2] = 3 * 1e18; // 3 WETH

    // Step 2: Deposit ETH to the pro portfolio to simulate asset acquisition
    uint256 depositAmount = 1 ether;

    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

    // Step 4: Call getAssetsExtended
    vm.prank(owner);
    uint256[] memory extendedAssets = WEDXProPortfolio(payable(proPortfolioAddress)).getAssetsExtended();

    // Step 5: Verify the extended assets
    for (uint256 i = 0; i < amounts.length; i++) {
        assertEq(extendedAssets[i], amounts[i], "Extended asset value mismatch");
    }

    console.log("Test getAssetsExtended completed successfully.");
}






function testGetAmountLendToken() public {
    // Step 1: Set up the token address and amount
    address tokenAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    uint256 lendAmount = 1000 * 1e6; // 1000 USDC

    // Step 2: Deposit ETH to the pro portfolio to simulate asset acquisition
    uint256 depositAmount = 1 ether;

    vm.prank(owner);
    WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

    // Step 3: Mock the getTokenBalance call
    vm.mockCall(
        wedxGroup.getLenderContractAddress(),
        abi.encodeWithSelector(IWEDXlender.getTokenBalance.selector, tokenAddress, proPortfolioAddress),
        abi.encode(lendAmount)
    );

    // Step 4: Call getAmountLendToken
    vm.prank(owner);
    uint256 amountLendToken = WEDXProPortfolio(payable(proPortfolioAddress)).getAmountLendToken(tokenAddress);

    // Step 5: Verify the lend amount
    assertEq(amountLendToken, lendAmount, "Lend amount value mismatch");
}




////////////////////////////

//          FUZZ

////////////////////////////

    function testFuzzDepositWithSimpleFee(uint256 depositAmount, uint256 feePercentage) public {

        depositAmount = bound(depositAmount, 1 ether, 100 ether);
        feePercentage = bound(feePercentage, 0, 100);

        address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Initial Balance in cWNATIVE:", initialBalance);

        uint256 distroNorm = 10000;  

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress(),
            abi.encodeWithSelector(IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee.selector),
            abi.encode(feePercentage)
        );

        uint256 fee = (depositAmount * feePercentage) / distroNorm;
        uint256 expectedDepositAmount = depositAmount - fee;

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getTreasuryAddress(),
            abi.encodeWithSelector(IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee.selector),
            abi.encode()
        );

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result", result);

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertApproxEqRel(result, expectedDepositAmount, 1e16); // 1% de tolerancia

        assertTrue(finalBalance > initialBalance, "Final balance in cWNATIVE should be greater than initial balance after deposit");
    }



    function testFuzzWithdraw(uint256 depositAmount, uint256 withdrawAmount, uint256 feePercentage) public {
        depositAmount = bound(depositAmount, 1 ether, 100 ether); 
        withdrawAmount = bound(withdrawAmount, 1 ether, depositAmount); 
        feePercentage = bound(feePercentage, 0, 100); 

        address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        uint256 distroNorm = 10000;  
        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress(),
            abi.encodeWithSelector(IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee.selector),
            abi.encode(feePercentage)
        );

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getTreasuryAddress(),
            abi.encodeWithSelector(IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee.selector),
            abi.encode()
        );

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdraw(withdrawAmount);

        uint256 fee = (withdrawAmount * feePercentage) / distroNorm;
        uint256 expectedWithdrawAmount = withdrawAmount - fee;

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        assertTrue(finalBalance < initialBalance, "Final balance in cWNATIVE should be less than initial balance after withdrawal");

        assertApproxEqRel(finalBalance, initialBalance - expectedWithdrawAmount, 1e16); // 1% de tolerancia
    }
}




contract MaliciousContract {
    WEDXProPortfolio public proPortfolio;
    WEDXIndexPortfolio public indexPortfolio;
    uint256 public reentrancyCount;

    constructor(WEDXProPortfolio _proPortfolio) {
        proPortfolio = _proPortfolio;
    }

    // constructor(WEDXIndexPortfolio _indexPortfolio) {
    //     indexPortfolio = _indexPortfolio;
    // }

    receive() external payable {
        if (reentrancyCount < 1) {
            reentrancyCount++;
            proPortfolio.withdrawBruteForced();
        }
    }

    function attack() external payable {
        require(msg.value > 0, "Must send Ether to attack");
        proPortfolio.deposit{value: msg.value}();
        proPortfolio.withdrawBruteForced();
    }
}
