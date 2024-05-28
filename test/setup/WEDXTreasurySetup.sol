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

// import "./interfaces/interface.sol";

contract WEDXTreasurySetup is Test {

    address payable thirdParty;
    address payable alice = payable(vm.addr(1));
    
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

    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

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

        thirdParty = payable(address(0x1234)); // Third party address
        vm.deal(proPortfolioAddress, 10 ether);
        vm.deal(address(wedxTreasury), 10 ether);
        deal(USDC, owner, 1000 * 1e6);

    }

}