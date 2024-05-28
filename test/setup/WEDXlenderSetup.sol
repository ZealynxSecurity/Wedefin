// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/WEDXDeployerPro.sol";
import "../../contracts/WEDXDeployerIndex.sol";
import "../../contracts/WEDXProPortfolio.sol";
import "../../contracts/WEDXIndexPortfolio.sol";
import "../../contracts/WEDXGroup.sol";
import "../../contracts/WEDXswap.sol";
import "../../contracts/WEDXlender.sol";
import "../../contracts/WEDXManager.sol";
import "../../contracts/WEDXRanker.sol";
import "../../contracts/WEDXTreasury.sol";
import "../../contracts/WEDXConstants.sol";
import "../interfaces/interface.sol";

contract WEDXlenderSetup is Test {
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
    address owner = address(this);

    IWETH9 weth;
    IERC20 usdc;
    IWETH9 wnative;

    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address public WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public USDC_INITIAL_SUPPLY = 1000 * 1e6; // 1,000 USDC
    uint256 public WETH_INITIAL_SUPPLY = 1 * 1e18; // 1 WETH

    function setUp() public {
        weth = IWETH9(WETH);
        usdc = IERC20(USDC);
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

        // Deal Ether to the portfolios and malicious contracts for testing
        vm.deal(proPortfolioAddress, 10 ether);
        vm.deal(address(wedxLender), 10 ether);
        deal(USDC, owner, 100000 * 1e6);
    }
}